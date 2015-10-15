# Pasha prio1 related functionalities
# -----------------------------------

# Hubot imports
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
scribeLog = require('../pasha_modules/scribe_log').scribeLog
Prio1 = require('../pasha_modules/model').Prio1
State = require('../pasha_modules/model').State
Channel =  require('../pasha_modules/model').Channel
constant = require('../pasha_modules/constant').constant
util = require('../pasha_modules/util')
hasValue = util.hasValue
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands

botName = constant.botName

playbookUrl = constant.playbookUrl
playbookInfo = "I recommend to follow the steps in:\n" +
                "Prio1 Playbook URL = #{playbookUrl}"
prio1MonitoredWebsite = constant.prio1MonitoredWebsite

#Commands

#TODO: Command regexes should be configurable
# prio1
prio1Help = /prio1$|prio1 help$/i
prio1Start = /prio1 start$/i
prio1StartParameters = /prio1 start (.+)/i
prio1Confirm = /prio1 confirm$/i
prio1Stop = /prio1 stop$/i
roleHelp = /role$|role help$/i
# role
roleComm = /role comm$/i
roleCommParameters = /role comm (.+)/i
roleLeader = /role leader$/i
roleLeaderParameters = /role leader (.+)/i
# status
statusHelp = /status help$/i
statusParameters = /status (.+)/i
statusCore = /status$/i
# say
say = /say (.+)/i
# whois
whois = /whois (.+)/i
# help
help = /$| help$/i
# healthcheck
healthcheckCore = /healthcheck/i

commands =
    prio1: [
        prio1Help,
        prio1Start,
        prio1StartParameters,
        prio1Confirm,
        prio1Stop
    ]
    role: [
        roleHelp,
        roleComm,
        roleCommParameters,
        roleLeader,
        roleLeaderParameters
    ]
    status: [
        statusHelp,
        statusCore,
        statusParameters
    ]
    say: [say]
    whois: [whois]
    help: [help]
    healthcheck: [healthcheckCore]

module.exports = (robot) ->

    registerModuleCommands(robot, commands)

    setUsers = (users) ->
        pashaState = util.getOrInitState(robot)
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        scribeLog "set #{users.length} users"

    try
        scribeLog 'initializing prio1 module'
        if hasValue(constant.hipchatApiToken)
            util.downloadUsers(constant.hipchatApiToken, setUsers)
    catch error
        scribeLog "ERROR #{error}"

    relay = (message) ->
        scribeLog "relaying: #{message}"
        try
            for room in constant.hipchatRelayRooms
                util.postToHipchat(room, message)
                scribeLog "sending #{message} to #{room}"
            for channel in constant.slackRelayChannels
                util.postToSlack(channel, message)
                scribeLog "sending #{message} to \##{channel}"
        catch error
            scribeLog "ERROR #{error}"

    robot.respond say, (msg) ->
        try
            msg.send msg.match[1]
        catch error
            scribeLog "ERROR #{error}"

    robot.respond whois, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            who = msg.match[1]
            u = util.getUser(who, msg.message.user.name, pashaState.users)
            if not u?
                msg.reply "no such user: #{who}"
            else
                msg.send "Full Name: #{u.name}\n" +
                         "Title: #{u.title}"
                robot.receive(new TextMessage(msg.message.user,
                  "#{botName} phone #{u.email}"))
        catch error
            scribeLog "ERROR #{error}"

    robot.respond help, (msg) ->
        msg.send "#{botName} prio1 <subcommand>: " +
            "manage prio1, see '#{botName} prio1 help' for details\n" +
            "#{botName} role <role> <name>: assign prio1 roles to people, " +
            "see '#{botName} role help' for details\n" +
            "#{botName} status: display or set prio1 status, " +
            "see '#{botName} status help' for details"
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} changelog help_from_main"))
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} runchef help"))
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} reboot help"))
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} alert help_from_main"))
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} graph help_from_main"))
        robot.receive(new TextMessage(msg.message.user,
            "#{botName} summon help_from_main"))


    robot.respond prio1Help, (msg) ->
        response = "#{botName} prio1 start <problem>: initiate prio1 mode\n" +
            "#{botName} prio1 confirm: confirm prio1\n" +
            "#{botName} prio1 stop: stop prio1"
        if hasValue(playbookUrl)
            response += "\n#{playbookInfo}"
        msg.send response

    robot.respond prio1Start, (msg) ->
        response =  "#{botName} prio1 start <problem>: initiate prio1 mode"
        if hasValue(playbookUrl)
            response += "\n#{playbookInfo}"
        msg.send response

    robot.respond prio1StartParameters, (msg) ->
        try
            status = msg.match[1]
            scribeLog "starting prio1: #{status}"
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if prio1?
                response = 'cannot start a prio1: ' +
                    'there is one currently going on'
                scribeLog response
                msg.reply "you #{response}"
                return
            user = msg.message.user.name
            timestamp = Math.floor((new Date()).getTime() / 1000)
            prio1 = new Prio1(user, timestamp, status)
            pashaState.prio1 = prio1
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            response = "#{user} started the prio1: #{status}\n" +
                "you can confirm the prio1 with '#{botName} prio1 confirm'"
            if hasValue(playbookUrl)
                response += "\n#{playbookInfo}"
            msg.send response
            prio1Room = constant.prio1Room
            if prio1Room?
                relay "#{user} started a prio1: #{status}. " +
                    "you can confirm it by joining the '#{prio1Room}' room " +
                    "and saying '#{botName} prio1 confirm'"
            scribeLog "started prio1: #{status}"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} started the prio1: " +
                "#{status}"))
            util.startNag robot, msg
        catch error
            scribeLog "ERROR #{error}"

    updateTopicCallback = (msg, oldTopic, newTopic) ->
        try
            pashaState = util.getOrInitState(robot)
            pashaState.prio1.channel[msg.message.room] =
                new Channel(oldTopic)
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            scribeLog "saved old channel topic: #{oldTopic}"
            msg.topic newTopic
            scribeLog "set new topic: #{newTopic}"
        catch error
            scribeLog "ERROR #{error}"

    robot.respond prio1Confirm, (msg) ->
        try
            scribeLog "confirming prio1"
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                response = 'cannot confirm the prio1: ' +
                    'there is no prio1 going on'
                scribeLog response
                msg.reply "you #{response}"
                return
            if prio1.role.confirmer?
                response = 'the prio1 already is confirmed'
                scribeLog response
                msg.reply response
                return
            user = msg.message.user.name
            pashaState.prio1.role.confirmer = user
            timestamp = Math.floor((new Date()).getTime() / 1000)
            pashaState.prio1.time.confirm = timestamp
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            newTopic = 'PRIO1_MODE=ON'
            if hasValue(constant.hangoutUrl)
                newTopic += " | hangout url: #{constant.hangoutUrl}"
                msg.send "hangout url: #{constant.hangoutUrl}"
            util.updateTopic(constant.hipchatApiToken,
                updateTopicCallback, msg, newTopic)
            msg.send "#{user} confirmed the prio1\n" +
                "the leader of the prio1 is #{pashaState.prio1.role.leader}" +
                ", you can change it with '#{botName} role leader <name>'"
            relay "#{user} confirmed the prio1"
            util.sendConfirmEmail(prio1)
            util.pagerdutyAlert("outage: #{pashaState.prio1.title}")
            scribeLog "confirmed prio1"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} confirmed the prio1"))
        catch error
            scribeLog "ERROR #{error}"

    robot.respond prio1Stop, (msg) ->
        try
            scribeLog "stopping prio1"
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                response = 'cannot stop the prio1: ' +
                    'there is no prio1 going on'
                scribeLog response
                msg.reply "you #{response}"
                return
            user = msg.message.user.name
            response = "#{user} stopped the prio1: #{prio1.title}"
            msg.send response
            relay response
            startTime = (new Date(prio1.time.start * 1000)).toISOString()
            confirmTime = (new Date(prio1.time.confirm * 1000)).toISOString()
            endTime = (new Date()).toISOString()
            util.sendEmail(prio1.title, "Outage over.")
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} stopped the prio1: " +
                "#{prio1.title}"))
            roomHasOldTopic = pashaState.prio1? and
                pashaState.prio1.channel[msg.message.room]?
            if roomHasOldTopic
                oldTopic =
                    pashaState.prio1.channel[msg.message.room].savedTopic
                msg.topic oldTopic
            pashaState.prio1 = null
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            scribeLog 'stopped prio1'
        catch error
            scribeLog "ERROR #{error}"

    robot.respond roleHelp, (msg) ->
        msg.send "#{botName} role leader <name>: " +
            "assign prio1 leader role to a person\n" +
            "#{botName} role comm <name>: " +
            "assign prio1 communication officer role to a person"

    robot.respond roleComm, (msg) ->
        msg.send "#{botName} role comm <name>: " +
            "assign prio1 communication officer role to a person"

    robot.respond roleCommParameters, (msg) ->
        try
            who = msg.match[1]
            scribeLog "setting comm role to: #{who}"
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                response = 'cannot set the comm role: ' +
                    'there is no prio1 going on'
                scribeLog response
                msg.reply "you #{response}"
                return
            user = util.getUser(who, msg.message.user.name, pashaState.users)
            if not user?
                response = "no such user: #{who}"
                scribeLog response
                msg.reply response
                return
            name = user.name
            pashaState.prio1.role.comm = name
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            msg.send "comm role is now assigned to #{name}, " +
                "you can change it with '#{botName} role comm <name>'"
            scribeLog "#{msg.message.user.name} assigned comm role to #{name}"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{msg.message.user.name} " +
                "assigned comm role to #{name}"))
        catch error
            scribeLog "ERROR #{error}"

    robot.respond roleLeader, (msg) ->
        msg.send "#{botName} role leader <name>: " +
            "assign prio1 leader role to a person"

    robot.respond roleLeaderParameters, (msg) ->
        try
            who = msg.match[1]
            scribeLog "setting leader role to: #{who}"
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                msg.reply 'you cannot set the leader role: ' +
                    'there is no prio1 going on'
                return
            user = util.getUser(who, msg.message.user.name, pashaState.users)
            if not user?
                response = "no such user: #{who}"
                scribeLog response
                msg.reply response
                return
            name = user.name
            pashaState.prio1.role.leader = name
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            msg.send "leader role is now assigned to #{name}, " +
                "you can change it with '#{botName} role leader <name>'"
            scribeLog "#{msg.message.user.name} assigned leader role to " +
                "#{name}"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{msg.message.user.name}" +
                " assigned leader role to #{name}"))
        catch error
            scribeLog "ERROR #{error}"

    robot.respond statusHelp, (msg) ->
        msg.send "#{botName} status: " +
            "display the status of the ongoing prio1\n" +
            "#{botName} status <status>: set status of the ongoing prio1"

    robot.respond statusCore, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                response = 'cannot display prio1 status: ' +
                    'there is no prio1 going on'
                scribeLog response
                msg.reply response
                return
            startTime = (new Date(prio1.time.start * 1000)).toISOString()
            confirmTime = null
            if prio1.time.confirm?
                confirmTime =
                    (new Date(prio1.time.confirm * 1000)).toISOString()
            msg.send "Prio1 status: #{prio1.status}\n" +
                "Started: #{prio1.role.starter} at #{startTime}\n" +
                "Confirmed: #{prio1.role.confirmer} at #{confirmTime}\n" +
                "Leader: #{prio1.role.leader}\n" +
                "Communication: #{prio1.role.comm}"
            scribeLog "#{msg.message.user.name} displayed status"
        catch error
            scribeLog "ERROR #{error}"

    robot.respond statusParameters, (msg) ->
        try
            status = msg.match[1]
            pashaState = util.getOrInitState(robot)
            prio1 = pashaState.prio1
            if not prio1?
                response = 'cannot set prio1 status: ' +
                    'there is no prio1 going on'
                scribeLog response
                msg.reply response
                return
            pashaState.prio1.status = status
            pashaState.prio1.time.lastStatus = new Date()
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            msg.reply msg.random util.ack
            response = "#{msg.message.user.name} set status to #{status}"
            relay response
            util.sendStatusEmail(prio1)
            scribeLog response
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{msg.message.user.name} " +
                "set status to #{status}"))
        catch error
            scribeLog "ERROR #{error}"

    robot.respond /healthcheck/i, (msg) ->
        msg.reply 'hello'

    prio1Synonyms =
        ['prio1', 'prio 1', 'outage']
    if hasValue(prio1MonitoredWebsite)
        prio1Synonyms.push("#{prio1MonitoredWebsite} is down")
    prio1SynonymsString = prio1Synonyms.join('|')
    prio1DetectorRegex =
        new RegExp("^(?!#{botName})(.* )?(#{prio1SynonymsString}).*$", "i")
    robot.hear prio1DetectorRegex, (msg) ->
        pashaState = util.getOrInitState(robot)
        prio1 = pashaState.prio1
        if not prio1?
            response = 'Is there a prio1? If yes, please register it ' +
                   'with "pasha prio1 start <description of the issue>"'
            msg.send response

# Export commands to make it testable
module.exports.commands = commands
