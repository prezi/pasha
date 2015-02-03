# Description
#   Uses Twilio to summon people when they are needed
#   because of an emergency situation.
#
# Dependencies
#   This module can work without the PagerDuty module
#   but it is more useful with it.
#
# Configuration
#   TWILIO_SOMETHING
#
# Commands:
#   <bot_name> summon <phone_number> <reason>
#       Summons a person based on the phone number using Twilio.
#   <bot_name> summon <name> <reason>
#       Summons a person based on the name using Twilio.
#       This module gets <name>'s phone number from the
#       PagerDuty API, if that module is not loaded this feature
#       does not work.
#   <bot_name> summon help
#        Responds with a description of the summon subcommands.

# Hubot imports
TextMessage = require('hubot/src/message').TextMessage

# Node imports
https = require('https')
http = require('http')
Fs = require('fs')
path = require('path')

# Pasha imports
scribeLog = require('../pasha_modules/scribe_log').scribeLog
constant = require('../pasha_modules/constant').constant
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands
util = require('../pasha_modules/util')

botName = constant.botName

# Commands
summonByPhoneNumber = /summon (\+?[0-9\ \-\(\)]*) (.+)$/i
summonByName = /summon ([^\+^0-9^\ ^\(^\)]*) (.+)$/i
summonHelp = /summon help$/i
summonHelpFromMain = /summon help_from_main$/i

commands =
    summon: [
        summonByPhoneNumber,
        summonByName,
        summonHelp,
        summonHelpFromMain
    ]

# Module exports
module.exports = (robot) ->

    registerModuleCommands(robot, commands)

    robot.respond summonByPhoneNumber, (msg) ->
        phone_number = msg.match[1]
        reason = msg.match[2]
        # TODO implement this
        msg.reply "phone number: #{phone_number}\n" +
          "reason: #{reason}"

    robot.respond summonByName, (msg) ->
        pdModulePath = path.join __dirname, "..", "scripts", "pasha_pagerduty.coffee"
        if (Fs.existsSync(pdModulePath))
            pagerduty = require('../scripts/pasha_pagerduty')
            name = msg.match[1]
            reason = msg.match[2]
            pashaState = util.getOrInitState(robot)
            u = util.getUser(name, msg.message.user.name, pashaState.users)
            pagerduty.phone(u.email, (phones) ->
                for phone in phones
                    robot.receive(new TextMessage(msg.message.user, "#{botName} summon #{phone} #{reason}"))
                    # TODO handle call success/failure
            )
        else
            msg.reply "PagerDuty module is not present, use '#{botName} summon phone_number text'"


    robot.respond summonHelp, (msg) ->
        response = "#{botName} summon <phone_number> <reason>: " +
            "Summons the owner of the specified <phone_number> with a <reason>\n" +
            "#{botName} summon <name> <reason>: " +
            "Summons <name> with a <reason>"
        msg.reply response

    robot.respond summonHelpFromMain, (msg) ->
        msg.send "#{botName} summon: summons people via Twilio, " +
            "see '#{botName} summon help' for details"

module.exports.commands = commands
