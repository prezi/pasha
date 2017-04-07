{constant, roleDescriptions} = require '../pasha_modules/constant'

_           = require 'lodash'
async       = require 'async'
{scribeLog} = require '../pasha_modules/scribe_log'
https       = require 'https'
http        = require 'http'
qs          = require 'querystring'
{State}     = require '../pasha_modules/model'
nodemailer  = require "nodemailer"
moment      = require 'moment'
request     = require 'request'

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
    if not pashaState.emergencyContacts?
        pashaState.emergencyContacts = {}
    return pashaState

saveState = (robot, pashaState) ->
    robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))

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
        try
            body = JSON.parse(body)
        catch error
            scribeLog "failed to parse Slack API response: #{error}. Body:\n#{body}"
        callback?(err, res, body)
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

relay = (message) ->
    scribeLog "relaying: #{message}"
    try
        if constant.hipchatRelayRooms?.length > 0 && constant.hipchatApiToken
            for room in constant.hipchatRelayRooms
                postToHipchat(room, message)
                scribeLog "sending #{message} to #{room}"
        if constant.slackRelayChannels?.length > 0 && constant.slackApiToken
            for channel in constant.slackRelayChannels
                postToSlack(channel, message)
                scribeLog "sending #{message} to ##{channel}"
    catch error
        scribeLog "ERROR relay #{error}"

inviteUsersToSlackChannel = (robot, channelId, userNames, cb) ->
    pashaState = getOrInitState(robot)
    users = _.filter(getUser(name, null, pashaState.users) for name in userNames)
    invite = (user) -> (cb) ->
        slackApi("channels.invite", {token: constant.slackApiNonbotToken, channel: channelId, user: user.id}, cb)
    async.parallel(
        (invite(user) for user in users),
        cb
    )

invitePrio1RolesToPrio1SlackChannel = (robot, cb) ->
    pashaState = getOrInitState(robot)
    return unless pashaState.prio1.channel?
    usersToInvite = [constant.botName]
    for own role, name of pashaState.prio1.role when name?
        usersToInvite.push name if usersToInvite.indexOf(name) == -1
    inviteUsersToSlackChannel(robot, pashaState.prio1.channel.id, usersToInvite, cb)

generatePrio1Description = (prio1) ->
    return """
        Outage '#{prio1.title}'
        #{generatePrio1Status(prio1)}
    """

setSlackChannelTopic = (channel, topic) ->
    slackApi("channels.setTopic", {channel:channel, token:constant.slackApiToken, topic:topic}, cb = (e,r,b) ->
          scribeLog "slack response: #{JSON.stringify(b)}"
    )

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

generateEmergencyContactList = () ->
    try
        pashaState = util.getOrInitState(robot)
        ec = pashaState.emergencyContacts
        response = ''
        for key of ec
          response += "#{key}: @" + ec[key].join(", @")+"\n"
        return response
    catch error
      scribeLog "ERROR couldnt list emergency contacts #{error} #{error.stack}"

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


describeCurrentRoles = (robot) ->
    pashaState = getOrInitState(robot)
    return "There's no prio1 in progress" unless pashaState.prio1?
    lines = []
    for role, roleDescription of roleDescriptions
        username = pashaState.prio1.role[role]
        if username
            lines.push "#{roleDescription} is @#{username}"
        else
            lines.push "#{roleDescription} is not set"
    return lines.join("\n")

hasValue = (str) ->
    str? and str

module.exports = {
    getUser: getUser
    downloadUsers : downloadUsers
    getOrInitState: getOrInitState
    saveState: saveState
    ack: ack
    updateHipchatTopic: updateHipchatTopic
    postToHipchat: postToHipchat
    postToSlack: postToSlack
    sendEmail: sendEmail
    sendConfirmEmail: sendConfirmEmail
    sendStatusEmail: sendStatusEmail
    generateEmergencyContactList: generateEmergencyContactList
    pagerdutyAlert: pagerdutyAlert
    hasValue: hasValue
    slackApi: slackApi
    relay: relay
    invitePrio1RolesToPrio1SlackChannel: invitePrio1RolesToPrio1SlackChannel
    setSlackChannelTopic: setSlackChannelTopic
    describeCurrentRoles: describeCurrentRoles
}
