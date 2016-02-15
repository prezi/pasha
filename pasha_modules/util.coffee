scribeLog = require('../pasha_modules/scribe_log').scribeLog
https = require('https')
http = require('http')
qs = require('querystring')
constant = require('../pasha_modules/constant').constant
State = require('../pasha_modules/model').State
nodemailer = require "nodemailer"
moment = require('moment')
request = require('request')

ack = ['roger', 'roger that', 'affirmative', 'ack', 'consider it done', 'done', 'aye captain']

downloadUsers = (token, setUsersCallback)->
    scribeLog "downloading users"
    slackApi("users.list", {token: constant.slackApiToken}, (err, res, data) ->
        if err || !data.ok
          scribeLog "ERROR downloadUsers #{err || data.error}"
          setUsersCallback([])
        else
          setUsersCallback(data.members)
          scribeLog "downloaded #{data.members.length} users"
    )

getUser = (who, myName, users) ->
    name = who?.toLowerCase().replace(/@/g, "").replace(/\s+$/g, "")
    if (name == "me")
        if not myName?
            scribeLog "cannot find 'me' because myName is not set"
            return null
        name = myName.toLowerCase().replace(/@/g, "").replace(/\s+$/g, "")
    matchedUsers = []
    for user in users
        if (user.name.toLowerCase() == name)
            scribeLog "user found: #{user.name}"
            return user
        if (user.name.toLowerCase().indexOf(name) != -1)
            matchedUsers.push user
    if (matchedUsers.length == 1)
        user = matchedUsers[0]
        scribeLog "user found: #{user.name}"
        return user
    scribeLog "no such user: #{name}"
    return null

getOrInitState = (adapter) ->
    pashaStateStr = adapter.brain.get(constant.pashaStateKey)
    if (not pashaStateStr? or pashaStateStr.length == 0)
        adapter.brain.set(constant.pashaStateKey, JSON.stringify(new State()))
        pashaStateStr = adapter.brain.get(constant.pashaStateKey)
        scribeLog "state was not found, successfully initialized it"
    pashaState = JSON.parse(pashaStateStr)
    return pashaState

updateHipchatTopic = (token, updateHipchatTopicCallback, msg, newTopic) ->
    try
        options = {
            hostname: "api.hipchat.com"
            port: 443
            path: "/v1/rooms/list?format=json&auth_token=#{token}"
            method: "GET"
        }
        https.get options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                rooms = JSON.parse(data)["rooms"]
                for room in rooms
                    if room.name == msg.message.room
                        updateHipchatTopicCallback(msg, room.topic, newTopic)
    catch error
        scribeLog "ERROR updateHipchatTopic #{error}"

postViaHttps = (postOptions, postData, callback) ->
    data = ''
    req = https.request postOptions, (res) ->
        res.on 'data', (chunk) ->
            data += chunk.toString()
        req.on 'error', (err) ->
            callback null, err if callback
        res.on 'end', ->
            callback data if callback
    req.on 'error', (err) ->
        callback null, err if callback
    req.write(postData)
    req.end()
    scribeLog "request sent to #{postOptions.hostname}"

postToHipchat = (channel, message) ->
    try
        postData = "room_id=#{channel}&from=Pasha&message=#{message}&notify=1"
        httpsPostOptions = {
            hostname: "api.hipchat.com"
            port: 443
            path: "/v1/rooms/message?format=json&auth_token=#{constant.hipchatApiToken}"
            method: "POST"
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(postData)
            }
        }
        response = postViaHttps httpsPostOptions, postData, (response, err) ->
            if err
                scribeLog "ERROR postToHipchat #{err}"
            else
                scribeLog "hipchat response: #{response}"
    catch error
        scribeLog "ERROR postToHipchat #{error}"

slackApi = (method, args, callback) ->
    request.get({
        url: "https://slack.com/api/#{method}",
        qs: args
    }, (err, res, body) ->
        if err
            callback?(err, res, body)
        else
            callback?(err, res, JSON.parse(body))
    )

postToSlack = (channel, message) ->
    try
        postData = qs.stringify {
            token: constant.slackApiToken,
            channel: channel,
            text: message,
            username: 'pasha'
        }
        httpsPostOptions = {
            hostname: 'slack.com',
            port: 443,
            path: '/api/chat.postMessage',
            method: 'POST'
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(postData)
            }
        }
        postViaHttps httpsPostOptions, postData, (response, err) ->
            if err
                scribeLog "ERROR postToSlack #{err}"
            else
                scribeLog "slack response: #{response}"
    catch error
        scribeLog "ERROR postToSlack #{error}"

generatePrio1Description = (prio1) ->
    return """
        Outage '#{prio1.title}'
        #{generatePrio1Status(prio1)}
    """

generatePrio1Status = (prio1) ->
    detectTime = moment.unix(prio1.time.start)
    confirmTime = moment.unix(prio1.time.confirm)
    return """
        Latest status: #{prio1.status}
        Communication is handled by #{prio1.role.communication}
        Leader is #{prio1.role.leader}
        Detected by #{prio1.role.starter} at #{detectTime.calendar()} - #{detectTime.fromNow()}
        Confirmed by #{prio1.role.confirmer} at #{confirmTime.calendar()} - #{detectTime.fromNow()}
    """

sendStatusEmail = (prio1) ->
    try
        sendEmail(prio1.title, generatePrio1Status(prio1))
    catch error
        scribeLog "ERROR sendStatusEmail #{error}"

sendConfirmEmail = (prio1) ->
    try
        sendEmail(prio1.title, generatePrio1Description(prio1))
    catch error
        scribeLog "ERROR sendConfirmEmail #{error}"

sendEmail = (subject, text) ->
    try
        transporter = nodemailer.createTransport()
        transporter.sendMail({
            from: constant.pashaEmailAddress
            to: constant.outageEmailAddress
            subject: subject
            text: text
        })
        scribeLog "email sent to #{constant.outageEmailAddress} with subject: #{subject}"
    catch error
        scribeLog "ERROR sendMail #{error}"

pagerdutyAlert = (description) ->
    try
        for serviceKey in constant.pagerdutyServiceKeys
            postData = JSON.stringify({
                service_key: serviceKey
                event_type: "trigger"
                description: description
            })
            httpsPostOptions = {
                hostname: "events.pagerduty.com"
                port: 443
                path: "/generic/2010-04-15/create_event.json"
                method: "POST"
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData)
                }
            }
            req = https.request httpsPostOptions, (res) ->
                data = ''
                res.on 'data', (chunk) ->
                    data += chunk.toString()
                res.on 'end', () ->
                    scribeLog "pagerduty response: #{data}"
            req.write(postData)
            req.end()
            scribeLog "pagerduty alert triggered: #{description}"
    catch error
        scribeLog "ERROR pagerdutyAlert #{error}"


startNag = (adapter, msg) ->
    naggerCallbackId = null
    nagger = () ->
        state = getOrInitState(adapter)
        prio1 = state.prio1
        if not prio1?
            if (not naggerCallbackId?)
                scribeLog "nagger callback shouldn't be called but it was"
                return
            clearInterval naggerCallbackId
            scribeLog "stopped nagging #{prio1.title}"
            return
        try
            nagTarget = if prio1.role.comm then prio1.role.comm else prio1.role.starter
            message = "@#{getUser(nagTarget, null, state.users).name}, please use '#{constant.botName} status <some status update>' regularly, the last status update for the current outage was at #{moment.unix(prio1.time.lastStatus).fromNow()}"
            if prio1.channel.name?
                adapter.messageRoom prio1.channel.name, message
            else
                msg.send message
        catch error
            scribeLog "ERROR nagger #{error}"
    naggerCallbackId = setInterval(nagger, 10 * 60 * 1000)

hasValue = (str) ->
    str? and str

module.exports = {
    getUser: getUser
    downloadUsers : downloadUsers
    getOrInitState: getOrInitState
    ack: ack
    updateHipchatTopic: updateHipchatTopic
    postToHipchat: postToHipchat
    postToSlack: postToSlack
    sendEmail: sendEmail
    sendConfirmEmail: sendConfirmEmail
    sendStatusEmail: sendStatusEmail
    pagerdutyAlert: pagerdutyAlert
    startNag: startNag
    hasValue: hasValue
    slackApi: slackApi
}
