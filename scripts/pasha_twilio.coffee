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
client = require('twilio')(twilioAccountSid, twilioAuthToken)

# Helpers
standardizePhoneNumber = (number) ->
  n = number.replace(/\+/g, "").replace(/\ /g, "").replace(/\(/g, "").replace(/\)/g, "").replace(/-/g, "")
  return "+#{n}"

sendSms = (number, reason, roomName, msg, name) ->

  smsReason = "You have been summon by #{botName}. " +
      "Join the #{roomName} HipChat room. The reason is: #{reason}."
  smsPayload = {
     to: number,
     from: twilioPhoneNumber,
     body: smsReason,
  }
  smsCallback = (err, message) ->
     scribeLog "twilio response Sid: #{message.sid}"
  client.messages.create(smsPayload, smsCallback)

phoneCall = (number, reason, roomName, msg, name) ->
  message = "You have been summon by #{botName}." +
      "Join the #{roomName} HipChat room. The reason is: #{reason}. I repeat. " +
      "Join the #{roomName} HipChat room. The reason is: #{reason}."
  encodedMessage = encodeURIComponent(message)
  twimletUrl = "http://twimlets.com/message?Message%5B0%5D=#{encodedMessage}&"
  callPayload = {
     to: number,
     from: twilioPhoneNumber,
     url: twimletUrl,
     IfMachine: "Continue"
  }
  sid = null
  callCallback = (err, call) ->
     scribeLog "call sid: #{call.sid}"
     sid = call.sid
  client.makeCall(callPayload, callCallback)
  callStatusCallbackId = null
  callStatusCallback = () ->
    client.calls(sid).get((err, call) ->
      wasPickedUp = ""
      if (call.status != "completed" or call.answeredBy != "human")
        wasPickedUp = "not "
      callStatus = "the call to #{name} (#{number}) was #{wasPickedUp}picked up"
      msg.reply callStatus
      scribeLog callStatus
    )
    clearInterval callStatusCallbackId
  callStatusCallbackId = setInterval(callStatusCallback, 1000 * 90)

smsAndCall = (phoneNumber, reason, roomName, msg, name) ->
  sendSms(phoneNumber, reason, roomName, msg, name)
  scribeLog "sent SMS to: #{name} (#{phoneNumber})"
  if name == "?"
    msg.reply "sent SMS to: #{phoneNumber}"
  else
    msg.reply "sent SMS to: #{name} (#{phoneNumber})"

  phoneCall(phoneNumber, reason, roomName, msg, name)
  scribeLog "initiated phone call to: #{name} (#{phoneNumber})"
  if name == "?"
    msg.reply "initiated phone call to: #{phoneNumber}"
  else
    msg.reply "initiated phone call to: #{name} (#{phoneNumber})"

summonByName = (msg, robot) ->
  try
    pdModulePath = path.join __dirname, "..", "scripts", "pasha_pagerduty.coffee"
    if (Fs.existsSync(pdModulePath))
        pagerduty = require('../scripts/pasha_pagerduty')
        name = msg.match[1]
        reason = msg.match[2]
        roomName = msg.message.room
        pashaState = util.getOrInitState(robot)
        u = util.getUser(name, msg.message.user.name, pashaState.users)
        if u
          pagerduty.phone(u.email, (numbers) ->
              for number in numbers
                  phoneNumber = standardizePhoneNumber(number)

                  smsAndCall(phoneNumber, reason, roomName, msg, name)
          )
        else
          msg.reply "no such user: #{name}"
    else
        msg.reply "PagerDuty module is not present, use '#{botName} summon phone_number text'"
  catch error
    scribeLog "ERROR #{error}"

summonByPhoneNumber = (msg, robot) ->
  try
    phoneNumber = standardizePhoneNumber(msg.match[1])
    reason = msg.match[2]
    roomName = msg.message.room
    smsAndCall(phoneNumber, reason, roomName, msg, "?")
  catch error
    scribeLog "ERROR #{error}"

# Commands
summonByPhoneNumberRe = /summon (\+?[0-9\ \-\(\)]*) (.+)$/i
summonByNameRe = /summon ([^\+^0-9^\ ^\(^\)]*) (.+)$/i
summonHelpRe = /summon help$/i
summonHelpFromMainRe = /summon help_from_main$/i

commands =
    summon: [
        summonByPhoneNumberRe,
        summonByNameRe,
        summonHelpRe,
        summonHelpFromMainRe
    ]

# Module exports
module.exports = (robot) ->

    registerModuleCommands(robot, commands)

    robot.respond summonByNameRe, (msg) ->
      summonByName(msg, robot)

    robot.respond summonByPhoneNumberRe, (msg) ->
      summonByPhoneNumber(msg, robot)

    robot.respond summonHelpRe, (msg) ->
      try
        response = "#{botName} summon <phone_number> <reason>: " +
            "Summons the owner of the specified <phone_number> with a <reason>\n" +
            "#{botName} summon <name> <reason>: " +
            "Summons <name> with a <reason>"
        msg.reply response
      catch error
        scribeLog "ERROR #{error}"

    robot.respond summonHelpFromMainRe, (msg) ->
      try
        msg.send "#{botName} summon: summons people via Twilio, " +
            "see '#{botName} summon help' for details"
      catch error
        scribeLog "ERROR #{error}"

module.exports.commands = commands
