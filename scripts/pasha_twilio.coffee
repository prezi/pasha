# Description
#   Uses Twilio to summon people when they are needed
#   because of an emergency situation.
#
# Dependencies
#   This module can work without the PagerDuty module
#   but it is more useful with it.
#
# Configuration
#   TWILIO_PHONE_NUMBER
#   TWILIO_ACCOUNT_SID
#   TWILIO_AUTH_TOKEN
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

# Constants
botName = constant.botName
twilioAccountSid = constant.twilioAccountSid
twilioAuthToken = constant.twilioAuthToken
twilioPhoneNumber = constant.twilioPhoneNumber

# Helpers
standardizePhoneNumber = (number) ->
  n = number.replace(/\+/g, "").replace(/\ /g, "").replace(/\(/g, "").replace(/\)/g, "").replace(/-/g, "")
  return "+#{n}"

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

    robot.respond summonByPhoneNumber, (msg) ->
      try
        phoneNumber = standardizePhoneNumber(msg.match[1])
        reason = msg.match[2]
        msg.reply "phone number: #{phoneNumber}\n" +
          "reason: #{reason}"
        client = require('twilio')(twilioAccountSid, twilioAuthToken)
        payload = {
	         to: phoneNumber,
	         from: twilioPhoneNumber,
	         body: reason,
        }
        callback = (err, message) ->
	         scribeLog "twilio response Sid: #{message.sid}"
        client.messages.create(payload, callback)
        scribeLog "sent SMS to: #{phoneNumber} with message: #{reason}"
      catch error
        scribeLog "ERROR #{error}"

    robot.respond summonHelp, (msg) ->
      try
        response = "#{botName} summon <phone_number> <reason>: " +
            "Summons the owner of the specified <phone_number> with a <reason>\n" +
            "#{botName} summon <name> <reason>: " +
            "Summons <name> with a <reason>"
        msg.reply response
      catch error
        scribeLog "ERROR #{error}"

    robot.respond summonHelpFromMain, (msg) ->
      try
        msg.send "#{botName} summon: summons people via Twilio, " +
            "see '#{botName} summon help' for details"
      catch error
        scribeLog "ERROR #{error}"

module.exports.commands = commands
