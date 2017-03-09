# Pasha prio1 related functionalities
# -----------------------------------

dateformat = require('dateformat')
async = require('async')
_ = require('lodash')
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
cmdRoles = /roles$/i
cmdRole = /role (\w+)$/i
cmdRoleParameters = /role (\w+) (.+)$/i
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
julitestStart = /julitest start/i
julitestStop = /julitest stop/i

commands =
    prio1: [
        prio1Help,
        prio1Start,
        prio1StartParameters,
        prio1Confirm,
        prio1Stop
    ]
    roles: [
        cmdRoles,
    ]
    role: [
        roleHelp,
        cmdRole,
        cmdRoleParameters
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
    julitest: [
          julitestStart,
          julitestStop
      ]


module.exports = (robot) ->
    robot.error (err, res) ->
        scribeLog "ERROR #{err} #{err.stack}"

    inviteUsersToSlackChannel = (channelId, userNames, cb) ->
        pashaState = util.getOrInitState(robot)
        users = _.filter(util.getUser(name, null, pashaState.users) for name in userNames)
        invite = (user) -> (cb) ->
            util.slackApi("channels.invite", {token: constant.slackApiNonbotToken, channel: channelId, user: user.id}, cb)
        async.parallel(
            (invite(user) for user in users),
            cb
        )

    invitePrio1RolesToPrio1SlackChannel = (cb) ->
        pashaState = util.getOrInitState(robot)
        return unless pashaState.prio1.channel?
        usersToInvite = [botName]
        for own role, name of pashaState.prio1.role when name?
            usersToInvite.push name if usersToInvite.indexOf(name) == -1
        inviteUsersToSlackChannel(pashaState.prio1.channel.id, usersToInvite, cb)

    setUsers = (users) ->
        pashaState = util.getOrInitState(robot)
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        scribeLog "set #{users.length} users"

    relay = (message) ->
        scribeLog "relaying: #{message}"
        try
            if constant.hipchatRelayRooms?.length > 0 && constant.hipchatApiToken
                for room in constant.hipchatRelayRooms
                    util.postToHipchat(room, message)
                    scribeLog "sending #{message} to #{room}"
            if constant.slackRelayChannels?.length > 0 && constant.slackApiToken
                for channel in constant.slackRelayChannels
                    util.postToSlack(channel, message)
                    scribeLog "sending #{message} to ##{channel}"
        catch error
            scribeLog "ERROR relay #{error}"

    class Workflow
        constructor: (robot, confirmMsg) ->
            @robot = robot
            @confirmMsg = confirmMsg
            @state = null
            @nextTimeoutId = null
            @tenMinuteIntervalId = null

        loadState: () =>
            @state = util.getOrInitState(@robot)
            return @state

        saveState: () =>
            @robot.brain.set(constant.pashaStateKey, JSON.stringify(@state))

        send: (message) =>
            if @state.prio1?.channel?.name?
                @robot.messageRoom @state.prio1.channel.name, message
            else
                @confirmMsg.send message

        remind: (role, message) =>
            @send "@#{@state.prio1.role[role]}: #{message}"

        next: (fun, minutes) =>
            @nextTimeoutId = setTimeout(fun, minutes * 60 * 1000)

        start: () => @zeroMinutes()

        welcome: () =>
            @send "The prio1 is: *#{@state.prio1.title}*. Good luck."
            @send describeCurrentRoles()
            @send "---"
            @remind 'leader', "Please share our best current estimate of impact; \"don't know yet\" is fine.\nRemember, you can set a dedicated Engineer point of contact at any time with '#{botName} role comm \<name\>'"
            # TODO: once support contact is automatically set, remind them to share incoming ticket volume

        zeroMinutes: () =>
            @loadState()
            return unless @state.prio1?
            util.sendConfirmEmail(@state.prio1)
            util.pagerdutyAlert("outage: #{@state.prio1.title}")
            # TODO: auto-assign support lead
            createChannel = (baseName, tryNum = 0) =>
                if tryNum > 0
                    channelName = "#{baseName}-#{tryNum}"
                else
                    channelName = baseName
                scribeLog "creating channel #{channelName}"
                util.slackApi "channels.create", {name: channelName, token: constant.slackApiNonbotToken}, (err, res, data) =>
                    if !err && data.ok
                        scribeLog "created channel #{data.channel.name}"
                        @state.prio1.channel = {id: data.channel.id, name: channelName}
                        @saveState()
                        @confirmMsg.send("Created channel <##{data.channel.id}>, please join and keep all prio1 communication there.")
                        invitePrio1RolesToPrio1SlackChannel(() =>
                            @welcome()
                            @next @fiveMinutes, 5
                        )
                    else
                        scribeLog "failed to create channel #{channelName}"
                        @confirmMsg.send("Failed to create channel #{channelName}: #{err || data.error}")
                        if data?.error == 'name_taken'
                            createChannel(baseName, tryNum + 1)
            # TODO: on other errors, default to #developers
            createChannel "prio1-#{dateformat(new Date(), 'yyyy-mm-dd')}"

        fiveMinutes: () =>
            @loadState()
            return unless @state.prio1?
            # TODO: configurable link to the status page admin interface
            @remind 'comm', 'Please update the green/yellow/red status of components on the status page.'
            @remind 'support', 'Please double-check the updates on the status page, and start public communication if you have a relevant pre-approved message.'
            @next @tenMinutes, 5

        tenMinutes: () =>
            @loadState()
            @remind 'comm', "Please provide an ETA and a simple status update with '#{botName} status ...'\nBad example: packet loss between data centers.\nGood example: network issues, it may be out of our control."
            # TODO: auto-assign marketing lead
            @remind 'support', "Ask for clarifications if needed. If the ETA is above 5 minutes, please alert marketing and start textual public communication. Work with @#{@state.prio1.role.comm} to make sure the communicated information is accurate."
            @tenMinuteIntervalId = setInterval(@everyTenMinutes, 10 * 60 * 1000)
            @next @sixtyMinutes, 50

        everyTenMinutes: () =>
            @loadState()
            @remind 'comm', "Please provide an ETA and a simple status update with '#{botName} status ...'"
            @remind 'support', "Ask for clarifications if needed. Work with marketing and @#{@state.prio1.role.comm} to provide a public update."

        sixtyMinutes: () =>
            @loadState()
            @remind 'marketing', "The prio1 has been going on for an hour. It's time to call a crisis communication meeting, prepare a reactive statement and messaging."
            @next @twoHours, 60

        twoHours: () =>
            @loadState()
            @remind 'marketing', "The prio1 has been going on for two hours. It's time to work with our Brand Communications director to alert HOX."

        stop: () =>
            @loadState()
            @remind 'support', 'If possible, please verify that the prio1 is over. If not possible, please acknowledge that you understand engineering believes the prio1 is over.'
            @remind 'support', "Please work with @#{@state.prio1.role.marketing} to update public communications channels, resolve the outstanding issue and update the green/yellow/red status on the status page. Ask @#{@state.prio1.role.comm} for clarifications as needed."
            clearTimeout @nextTimeoutId if @nextTimeoutId?
            clearInterval @tenMinuteIntervalId if @tenMinuteIntervalId?

    registerModuleCommands(robot, commands)
    try
        scribeLog 'initializing prio1 module'
        if hasValue(constant.slackApiToken)
            util.downloadUsers(constant.slackApiToken, setUsers)
    catch error
        scribeLog "ERROR initializing #{error}"

    robot.respond say, (msg) ->
        try
            msg.send msg.match[1]
        catch error
            scribeLog "ERROR say #{error}\n#{error.stack}"

    robot.respond whois, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            who = msg.match[1]
            u = util.getUser(who, msg.message.user.name, pashaState.users)
            if not u?
                msg.reply "no such user: #{who}"
            else
                msg.send "Full Name: #{u.profile.real_name}\n" +
                         "Username: @#{u.name}"
                robot.receive(new TextMessage(msg.message.user,
                  "#{botName} phone #{u.profile.email}"))
        catch error
            scribeLog "ERROR whois #{error}"

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
            if prio1Room
                relay "#{user} started a prio1: #{status}. " +
                    "you can confirm it by joining the '#{prio1Room}' room " +
                    "and saying '#{botName} prio1 confirm'"
            scribeLog "started prio1: #{status}"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} started the prio1: " +
                "#{status}"))
        catch error
            scribeLog "ERROR prio1Start #{error}"

    updateHipchatTopicCallback = (msg, oldTopic, newTopic) ->
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
            scribeLog "ERROR updateHipchatTopic #{error}"

    activeWorkflow = null

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
            util.updateHipchatTopic(constant.hipchatApiToken,
                updateHipchatTopicCallback, msg, newTopic)
            msg.send "#{user} confirmed the prio1\n" +
                "the leader of the prio1 is #{pashaState.prio1.role.leader}" +
                ", you can change it with '#{botName} role leader <name>'"
            relay "#{user} confirmed the prio1"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} confirmed the prio1"))
            scribeLog "confirmed prio1"
            activeWorkflow = new Workflow(robot, msg)
            activeWorkflow.start()
            util.slackApi("channels.info", {channel:prio1.channel.id, token:constant.slackApiToken}, (e, r, b) =>
              topic = b.channel.topic.value
              robot.brain.set(channel+"_topic", topic)
              util.slackApi("channels.setTopic", {channel:channel, token:constant.slackApiToken, topic:"Hangout: "+constant.hangoutUrl})
            )
        catch error
            scribeLog "ERROR prio1Confirm #{error} #{error.stack}"

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
            if pashaState.prio1.channel.name? && msg.envelope.room != pashaState.prio1.channel.name
                return msg.reply("Please use the channel <##{pashaState.prio1.channel.id}> for all communication")
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
            activeWorkflow?.stop()
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))
            util.slackApi("channels.setTopic", {channel:prio1.channel.id, token:constant.slackApiToken, topic:robot.brain.get(channel+"_topic")})
            scribeLog 'stopped prio1'
        catch error
            scribeLog "ERROR prio1Stop #{error}"

    roleDescriptions =
        starter: 'The one who reported the prio1'
        confirmer: 'The one who confirmed the prio1'
        leader: 'Engineer lead'
        comm: 'Engineer point of contact'
        support: 'Support lead'
        marketing: 'Marketing lead'

    assignableRoles = ['leader', 'comm', 'support', 'marketing']

    describeCurrentRoles = ->
        pashaState = util.getOrInitState(robot)
        return "There's no prio1 in progress" unless pashaState.prio1?
        lines = []
        for role, roleDescription of roleDescriptions
            username = pashaState.prio1.role[role]
            if username
                lines.push "#{roleDescription} is @#{username}"
            else
                lines.push "#{roleDescription} is not set"
        return lines.join("\n")

    robot.respond roleHelp, (msg) ->
        pashaState = util.getOrInitState(robot)
        return msg.reply("There's no prio1 in progress") unless pashaState.prio1?
        rolesString = ("`#{role}` #{roleDescriptions[role]}" for role in assignableRoles).join('\n')
        msg.send "*#{botName} role <role> <name>*: assign prio1 role to a person. Roles:\n#{rolesString}"

    robot.respond cmdRoles, (msg) ->
        try
            msg.send describeCurrentRoles()
        catch error
            scribeLog "ERROR cmdRoles #{error} #{error.stack}"

    robot.respond cmdRole, (msg) ->
        pashaState = util.getOrInitState(robot)
        return msg.reply("There's no prio1 in progress") unless pashaState.prio1?
        role = msg.match[1]
        msg.send "*#{botName} role #{role} <name>*: assign role `#{role}` to a person"

    robot.respond cmdRoleParameters, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            role = msg.match[1]
            who = msg.match[2]
            return msg.reply("There's no prio1 in progress") unless pashaState.prio1?
            if assignableRoles.indexOf(role) == -1
                return msg.reply("Unknown role `#{role}`. The available roles: #{assignableRoles.join(', ')}")
            if pashaState.prio1.channel.name? && msg.envelope.room != pashaState.prio1.channel.name
                return msg.reply("Please use the channel <##{pashaState.prio1.channel.id}> for all communication")
            scribeLog "setting #{role} role to: #{who}"
            prio1 = pashaState.prio1
            user = util.getUser(who, msg.message.user.name, pashaState.users)
            if not user?
                response = "no such user: #{who}"
                scribeLog response
                msg.reply response
                return
            name = user.name
            pashaState.prio1.role[role] = name
            robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
            msg.send "#{roleDescriptions[role]} is now @#{name}, " +
                "you can change it with '#{botName} role #{role} <name>'"
            scribeLog "#{msg.message.user.name} assigned #{role} role to #{name}"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{msg.message.user.name}" +
                " assigned #{role} role to #{name}"))
            invitePrio1RolesToPrio1SlackChannel()
            util.slackApi("channels.setTopic", {channel:channel, token:constant.slackApiToken, topic:describeCurrentroles() + "Hangout: "+constant.hangoutUrl})
        catch error
            scribeLog "ERROR cmdRoleParameters #{error} #{error.stack}"

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
            scribeLog "ERROR status #{error}"

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
            if pashaState.prio1.channel.name? && msg.envelope.room != pashaState.prio1.channel.name
                return msg.reply("Please use the channel <##{pashaState.prio1.channel.id}> for all communication")
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
            invitePrio1RolesToPrio1SlackChannel()
        catch error
            scribeLog "ERROR statusText #{error}"

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
