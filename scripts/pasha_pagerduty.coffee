# Description
#   Alerts pagerduty services by specifying service names.
#   Lists the active incidents on Pagerduty.
#
# Dependencies
#   None
#
# Configuration
#   PAGERDUTY SERVICE_KEYS
#   PAGERDUTY_SERVICE_API_KEY
#
# Commands:
#   <bot name> alert trigger <service_name> <alert_description>:
#       triggers an alert to the specified service
#   <bot name> alert list:
#       lists the details of the active Pagerduty alerts
#   <bot_name> alert help:
#        responds with a description for alert subcommands

# Node imports
https = require('https')
http = require('http')
# Pasha imports
scribeLog = require('../pasha_modules/scribe_log').scribeLog
constant = require('../pasha_modules/constant').constant
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands

botName = constant.botName
pagerdutyApiKey = constant.pagerdutyApiKey
pagerdutyHostName = constant.pagerdutyHostname
pagerdutyPort = constant.pagerdutyPort
serviceNameKey = {}

# Helpers
# -------

#stores the mappings of service names and their keys in 'serviceNameKey' json
serviceNameKeyMapping = () ->
    auth = "Token token=#{pagerdutyApiKey}"

    try
        httpsGetOptions = {
            hostname: pagerdutyHostName
            port: pagerdutyPort
            path: "/api/v1/services"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
            }
        }

        req = https.request httpsGetOptions, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                services = JSON.parse(data)["services"]
                for service in services
                    serviceNameKey[service.name] = service.service_key
        req.end()
        scribeLog "Initialized the mappings between services names and keys"
    catch error
        scribeLog "ERROR #{error}"

#triggers an alert to a service given its serviceKey
pagerdutyAlertService = (msg, description, serviceKey) ->
    try
        postData = JSON.stringify({
            service_key: serviceKey
            event_type: "trigger"
            description: description
        })

        httpsPostOptions = {
            hostname: "events.pagerduty.com"
            port: pagerdutyPort
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
        msg.reply "pagerduty alert triggered: #{description}"
    catch error
        scribeLog "ERROR #{error}"

#replies to 'msg' with the details of all active pagerduty incidents
getActiveIncidents = (msg) ->
    auth = "Token token=#{pagerdutyApiKey}"
    try
        httpsGetOptions = {
            hostname: pagerdutyHostName
            port: pagerdutyPort
            path: "/api/v1/incidents/?status=triggered,acknowledged"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
            }
        }

        req = https.request httpsGetOptions, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                dataJson = JSON.parse(data)
                incidents = dataJson["incidents"]
                incidentsDetails = ''
                for incident in incidents
                    incidentsDetails += "\n#{getIncidentDetails(incident)}\n"
                if dataJson['total'] == 0
                    msg.reply 'There are no active incidents'
                else
                    msg.reply incidentsDetails
        req.end()
    catch error
        scribeLog "ERROR #{error}"

#<incident>: a json object returned by the Pagerduty api for one incident
#returns a description for <incident> that includes the most relevant parameters
getIncidentDetails = (incident) ->
    service = incident['service']
    triggerSummaryData = incident['trigger_summary_data']
    description = triggerSummaryData['description']
    assignedTo = incident['assigned_to']

    response = "service name: #{service.name}, "
    if(description?)
        response += "description: #{description},"
    response += "triggered at #{incident['created_on']}, " +
        "status: #{incident['status']}"

    acknowledgers = incident['acknowledgers']
    if acknowledgers?
        acknowledgerDetails = (acknowledger) ->
            "#{acknowledger.object.name} at #{acknowledger.at}"
        response += ', acknowledged by: ' +
            acknowledgers.map(acknowledgerDetails).join(', ')

    response += ", incident number: #{incident['incident_number']}"
    return response

#triggers an alert to a service given its service name
alertServiceByName = (msg, serviceName, description) ->
    auth = "Token token=#{pagerdutyApiKey}"
    if serviceNameKey[serviceName]?
        pagerdutyAlertService(msg, description,
            serviceNameKey[serviceName])
    else
        msg.reply "No service with name \"#{serviceName}\" exists"

# Commands
# --------

# TODO: Command regexes should be configurable

alertTriggerService = /alert trigger ([^ ]+) (.+)$/i
alertList = /alert list$/i
alertHelp = /alert help$/i
alerthelpFromMain = /alert help_from_main/i

commands =
    alert: [
        alertTriggerService,
        alertList,
        alertHelp,
        alerthelpFromMain
    ]

# Module exports
# --------------

module.exports = (robot) ->

    registerModuleCommands(robot, commands)
    serviceNameKeyMapping()

    robot.respond alertTriggerService, (msg) ->
        serviceName = msg.match[1]
        description = msg.match[2]
        alertServiceByName(msg, serviceName, description)

    robot.respond alertList, (msg) ->
        getActiveIncidents(msg)

    robot.respond alertHelp, (msg) ->
        response = "#{botName} alert trigger <service_name> <description>: " +
            "triggers an alert to the service with the specified name\n" +
            "#{botName} alert list: " +
            "lists the details of the active Pagerduty alerts"
        msg.reply response

    robot.respond alerthelpFromMain, (msg) ->
        msg.send "#{botName} alert <subcommand>: manages pagerduty alerts, " +
            "see '#{botName} alert help' for details"

module.exports.commands = commands
