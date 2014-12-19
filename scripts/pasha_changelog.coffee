# Pasha changelog-related functionalities
# ---------------------------------------

# Node imports
https = require('https')
# Pasha imports
scribeLog = require('../pasha_modules/scribe_log').scribeLog
constant = require('../pasha_modules/constant').constant
State = require('../pasha_modules/model').State
util = require('../pasha_modules/util')
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands

msgMax = constant.hipchatMessageLimit
botName = constant.botName
user = constant.httpBasicAuthUser
password = constant.httpBasicAuthPassword
changelogHostname = constant.changelogHostname
changelogPort = constant.changelogPort

# Helpers
# -------

postToChangelog = (usr, pwd, change) ->
    httpsPostOptions =
        hostname: changelogHostname
        auth: "#{usr}:#{pwd}"
        port: changelogPort
        path: "/api/events"
        method: "POST"
        headers: { "Content-Type": "application/json" }
    
    req = https.request httpsPostOptions, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            scribeLog "changelog response: #{data}"
    timestamp = Math.floor((new Date()).getTime() / 1000)
    postData = "{\"criticality\": 1, \"unix_timestamp\": #{timestamp}, " +
        "\"category\": \"pasha\", \"description\": \"#{change}\"}"
    req.write(postData)
    req.end()
    scribeLog "added to changelog: #{change}"

getDataFromChangelog = (usr, pwd, hours, processEventsCallback) ->
    httpsGetOptions =
        hostname: changelogHostname
        auth: "#{usr}:#{password}"
        port: changelogPort
        path: "/api/events?hours_ago=#{hours}&until=-1"
        method: "GET"

    https.get httpsGetOptions, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            events = JSON.parse(data)
            events.sort (a, b) ->
                return if a.unix_timestamp <= b.unix_timestamp then 1 else -1
            processEventsCallback(events)

splitMessages = (message) ->
    currentPos = 0
    endPos = msgMax
    splittedMessages = []
    while currentPos < message.length - 1
        splittedMessages.push message.slice currentPos, endPos
        currentPos = endPos
        endPos = currentPos + msgMax
    return splittedMessages

# Commands
# --------

# TODO: Command regexes should be configurable
changelogAddParams = /changelog add (.+)/i
changelogAddsilentParams = /changelog addsilent (.+)/i
changelogParams  = /changelog -?(\d+)([smhd])( -f)?$/i
changelogHelpFromMain = /changelog help_from_main$/i
changelogHelp = /changelog help$/i

commands =
    changelog: [
        changelogAddParams,
        changelogAddsilentParams,
        changelogParams ,
        changelogHelpFromMain,
        changelogHelp
    ]

# Module exports
# --------------

module.exports = (robot) ->

    registerModuleCommands(robot, commands)

    robot.respond changelogAddParams, (msg) ->
        try
            change = msg.match[1].replace(/\"/g, "'")
            change = "#{msg.message.user.name}: #{change}"
            postToChangelog(user, password, change)
            msg.reply msg.random util.ack
        catch error
            scribeLog "ERROR #{error}"

    robot.respond changelogAddsilentParams, (msg) ->
        try
            change = msg.match[1].replace(/\"/g, "'")
            postToChangelog(user, password, change)
        catch error
            scribeLog "ERROR #{error}"

    robot.respond changelogParams , (msg) ->
        try
            number = parseInt(msg.match[1], 10)
            unit = msg.match[2]
            nowTs = Math.floor((new Date()).getTime() / 1000)
            unitMultiplier = switch unit
                when 's' then 1
                when 'm' then 60
                when 'h' then 3600
                when 'd' then 86400
            tsDifference = number * unitMultiplier
            fromTs = nowTs - tsDifference
            differenceHours = Math.ceil(tsDifference / 3600)
            forcePrinting = (msg.match[3] == ' -f')
            printEvents = (events) ->
                resp = ""
                for e in events.reverse()
                    if (e.unix_timestamp >= fromTs)
                        d = new Date(e.unix_timestamp * 1000)
                        resp += "#{d.toISOString()} - #{e.category} - " +
                            "#{e.description}\n"
                if (resp.length == 0)
                    msg.send 'No entries to show'
                else if !forcePrinting
                    if resp.length > msgMax
                        msg.send 'Too many entries to show\n' +
                            'Add -f to get the entries in seperate messages'
                    else
                        msg.send resp
                else if forcePrinting
                    splitMsg = splitMessages(resp)
                    for m in splitMsg
                        msg.send m
                scribeLog "queried #{events.length} events from changelog"
            getDataFromChangelog(user, password, differenceHours,
                printEvents)
        catch error
            scribeLog "ERROR #{error}"

    robot.respond changelogHelpFromMain, (msg) ->
        msg.send "#{botName} changelog <subcommand>: manage changelog, " +
            "see '#{botName} changelog help' for details"

    robot.respond changelogHelp, (msg) ->
        msg.send "#{botName} changelog add <event>: add event to changelog\n" +
            "#{botName} changelog <int>[smhd]: " +
            "list recent changelog events for the specified time interval"

module.exports.splitMessages = splitMessages
module.exports.commands = commands
