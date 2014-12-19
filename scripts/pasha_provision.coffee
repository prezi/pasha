# Pasha provision-related functionalities
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

botName = constant.botName
user = constant.httpBasicAuthUser
password = constant.httpBasicAuthPassword
provisionHostname  = constant.provisionHostname 
provisionPort = constant.provisionPort
# Helpers
# -------

postToProvision = (usr, pwd, criteria, action) ->
    postData = "data={\"criteria\": \"#{criteria}\"}"
    httpsPostOptions = {
        hostname: provisionHostname 
        auth: "#{usr}:#{pwd}"
        port: provisionPort
        path: "/#{action}/"
        method: "POST"
        headers: {
            "Content-Type": "application/x-www-form-urlencoded"
            "Content-Length": Buffer.byteLength(postData)
        }
    }
    req = https.request httpsPostOptions, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            scribeLog "changelog response: #{data}"

    timestamp = Math.floor((new Date()).getTime() / 1000)
    req.write(postData)
    req.end()
    scribeLog "issued #{action} on chef nodes: #{criteria}"

# Commands
# --------

# TODO: Command regexes should be configurable
# runchef
runchefHelp = /runchef help$/i
runchefParams = /runchef (.+)/i
# reboot
rebootHelp = /reboot help$/i
rebootParams = /reboot (.+)/i

commands =
    runchef: [
        runchefHelp,
        runchefParams
    ]
    reboot: [
        rebootHelp,
        rebootParams
    ]

# Module exports
# --------------

module.exports = (robot) ->

    registerModuleCommands(robot, commands)

    robot.respond runchefHelp, (msg) ->
        msg.send "#{botName} runchef <knife_search_criteria>: " +
            "run chef on the specified nodes"

    robot.respond rebootHelp, (msg) ->
        msg.send "#{botName} reboot <knife_search_criteria>: " +
            "reboot the specified nodes"

    robot.respond runchefParams, (msg) ->
        try
            criteria = msg.match[1]
            if criteria == 'help'
                return
            postToProvision(user, password, criteria, "runchef")
            msg.reply msg.random util.ack
        catch error
            scribeLog "ERROR #{error}"

    robot.respond rebootParams, (msg) ->
        try
            criteria = msg.match[1]
            if criteria == 'help'
                return
            postToProvision(user, password, criteria, "reboot")
            msg.reply msg.random util.ack
        catch error
            scribeLog "ERROR #{error}"

module.exports.commands = commands
