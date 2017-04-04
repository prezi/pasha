# Pasha prio1 related functionalities
# -----------------------------------

async      = require 'async'
_          = require 'lodash'

# Hubot imports
{TextMessage} = require('hubot/src/message')
# Pasha imports
{constant, roleDescriptions} = require '../pasha_modules/constant'

util                     = require '../pasha_modules/util'
{scribeLog}              = require '../pasha_modules/scribe_log'
{Prio1, State, Channel}  = require '../pasha_modules/model'
Workflow                 = require '../pasha_modules/workflow'
{registerModuleCommands} = require '../scripts/commands'

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
#contact
contactHelp = /contact$|contact help$/i
setEmergencyContact = /contact add (\w+) (.+)$/i
listEmergencyContacts = /contacts$/i
removeEmergencyContact = /contact remove (\w+) (.+)$/i
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
    roles: [
        cmdRoles,
    ]
    role: [
        roleHelp,
        cmdRole,
        cmdRoleParameters
    ]
    contacts: [
        contactHelp,
        setEmergencyContact,
        listEmergencyContacts,
        removeEmergencyContact
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
    robot.error (err, res) ->
        scribeLog "ERROR #{err} #{err.stack}"

    setUsers = (users) ->
        pashaState = util.getOrInitState(robot)
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        scribeLog "set #{users.length} users"

    registerModuleCommands(robot, commands)
    try
        scribeLog 'initializing prio1 module'
        if util.hasValue(constant.slackApiToken)
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
            "see '#{botName} status help' for details\n" +
            "#{botName} contact add|remove <contactRole> <contact>: add and remove emergency contacts\n" +
            "#{botName} contacts: list emergency contacts\n"
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
        if util.hasValue(playbookUrl)
            response += "\n#{playbookInfo}"
        msg.send response

    robot.respond prio1Start, (msg) ->
        response =  "#{botName} prio1 start <problem>: initiate prio1 mode"
        if util.hasValue(playbookUrl)
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
            if util.hasValue(playbookUrl)
                response += "\n#{playbookInfo}"
            msg.send response
            prio1Room = constant.prio1Room
            if prio1Room
                util.relay "#{user} started a prio1: #{status}. " +
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
            if util.hasValue(constant.hangoutUrl)
                newTopic += " | hangout url: #{constant.hangoutUrl}"
                msg.send "hangout url: #{constant.hangoutUrl}"
            util.updateHipchatTopic(constant.hipchatApiToken,
                updateHipchatTopicCallback, msg, newTopic)
            msg.send "#{user} confirmed the prio1\n" +
                "the leader of the prio1 is #{pashaState.prio1.role.leader}" +
                ", you can change it with '#{botName} role leader <name>'"
            util.relay "#{user} confirmed the prio1"
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{user} confirmed the prio1"))
            scribeLog "confirmed prio1"
            activeWorkflow = new Workflow(robot, msg)
            activeWorkflow.start()
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
            util.relay response
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
            scribeLog 'stopped prio1'
        catch error
            scribeLog "ERROR prio1Stop #{error}"

    assignableRoles = ['leader', 'comm', 'support', 'marketing']

    robot.respond roleHelp, (msg) ->
        pashaState = util.getOrInitState(robot)
        return msg.reply("There's no prio1 in progress") unless pashaState.prio1?
        rolesString = ("`#{role}` #{roleDescriptions[role]}" for role in assignableRoles).join('\n')
        msg.send "*#{botName} role <role> <name>*: assign prio1 role to a person. Roles:\n#{rolesString}"

    robot.respond cmdRoles, (msg) ->
        try
            msg.send util.describeCurrentRoles(robot)
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
            util.invitePrio1RolesToPrio1SlackChannel(robot)
        catch error
            scribeLog "ERROR cmdRoleParameters #{error} #{error.stack}"

    robot.respond contactHelp, (msg) ->
        msg.send "Use \"contact add|remove contactRole name\" to add or remove Emergency Contacts"

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

    robot.respond setEmergencyContact, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            contactRole = msg.match[1]
            who = msg.match[2]

            ec = pashaState.emergencyContacts

            if who[0]=="@"
              who=who.substr(1)

            if not ec[contactRole]?
                ec[contactRole]=[]

            ec[contactRole].push(who)
            util.saveState(robot, pashaState)

            msg.send "@#{who} is now added to Emergency Contacts as #{contactRole}."
        catch error
          scribeLog "ERROR couldnt set emergency contact #{error} #{error.stack}"

    robot.respond listEmergencyContacts, (msg) ->
        try
            response="Emergency Contacts: \n"
            msg.send response + generateEmergencyContactList()
        catch error
          scribeLog "ERROR couldnt list emergency contacts #{error} #{error.stack}"
    robot.respond removeEmergencyContact, (msg) ->
        try
            pashaState = util.getOrInitState(robot)
            contactRole = msg.match[1]
            who = msg.match[2]
            ec = pashaState.emergencyContacts

            if who[0]=="@"
              who=who.substr(1)

            if not ec["#{contactRole}"]?
              msg.send "There arent any contacts for #{contactRole}"
              return

            roleContacts = ec[contactRole]
            if who in roleContacts
                roleContacts.splice(roleContacts.indexOf(who), 1)
                if roleContacts.length == 0
                    delete pashaState.emergencyContacts[contactRole]
                else
                    pashaState.emergencyContacts[contactRole] = roleContacts
                util.saveState(robot,pashaState)
                msg.send "Removed @#{who} from the list of #{contactRole} emergency contacts"
            else
                msg.send "@#{who} wasn't even in the list of #{contactRole} contacts"
        catch error
            scribeLog "ERROR couldnt set emergency contact #{error} #{error.stack}"

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
            util.relay response + "\n prio1 channel: <##{pashaState.prio1.channel.id}>"
            util.sendStatusEmail(prio1)
            scribeLog response
            robot.receive(new TextMessage(msg.message.user,
                "#{botName} changelog addsilent #{msg.message.user.name} " +
                "set status to #{status}"))
            util.invitePrio1RolesToPrio1SlackChannel(robot)
        catch error
            scribeLog "ERROR statusText #{error}"

    robot.respond /healthcheck/i, (msg) ->
        msg.reply 'hello'

    prio1Synonyms =
        ['prio1', 'prio 1', 'outage']
    if util.hasValue(prio1MonitoredWebsite)
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
