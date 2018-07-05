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
querystring = require('querystring')
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
serviceNameKeyMapping = (offset = 0) ->
    auth = "Token token=#{pagerdutyApiKey}"

    try
        httpsGetOptions = {
            hostname: pagerdutyHostName
            port: pagerdutyPort
            path: "/services?include[]=integrations&offset=#{offset}"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
                'Accept': 'application/vnd.pagerduty+json;version=2'
            }
        }

        req = https.request httpsGetOptions, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                parsed_data = JSON.parse(data)
                services = parsed_data["services"]
                for service in services
                    for integration in service.integrations
                        serviceNameKey[service.name] = integration.integration_key
                        break
                scribeLog "Initialized service name to key mapping for offset #{offset}"
                has_more = parsed_data["more"]
                if has_more
                    new_offset = parsed_data["offset"] + parsed_data["limit"]
                    serviceNameKeyMapping(new_offset)
                else
                    scribeLog "Finished service name to key mapping initialization."
        req.end()
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
            path: "/incidents?statuses[]=triggered&statuses[]=acknowledged"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
                'Accept': 'application/vnd.pagerduty+json;version=2'
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
                if incidents.length == 0
                    msg.reply 'There are no active incidents'
                else
                    msg.reply incidentsDetails
        req.end()
    catch error
        scribeLog "ERROR #{error}"

#<email>: the email address of a user in PagerDuty
#<onSuccess>: event handler function which will be called with the phone numbers
#returns the user's phone numbers registered in PagerDuty in a list.
getPhoneNumberByEmail = (email, onSuccess) ->
    scribeLog "getPhoneNumberByEmail: #{email}"
    auth = "Token token=#{pagerdutyApiKey}"
    try
        httpsGetOptions = {
            hostname: pagerdutyHostName
            port: pagerdutyPort
            path: "/users/?query=#{querystring.escape(email)}&include[]=contact_methods"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
                'Accept': 'application/vnd.pagerduty+json;version=2'
            }
        }

        req = https.request httpsGetOptions, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                dataJson = JSON.parse(data)
                users = dataJson['users']
                if users.length == 0
                    scribeLog "User email (#{email}) is not set in PagerDuty"
                    scribeLog "pagerduty response: #{data}"
                else if users.length > 1
                    scribeLog "Multiple matches in PagerDuty (for #{email})"
                    scribeLog "pagerduty response: #{data}"
                else
                    user = users[0]
                    user_id = user["id"]
                    scribeLog "Found user in PagerDuty: #{email} => #{user_id}"
                    phone_numbers = []
                    for contact_method in user["contact_methods"]
                        if contact_method["type"] == "phone_contact_method" ||
                          contact_method["type"] == "sms_contact_method"
                            phone = "+#{contact_method["country_code"]}#{contact_method["address"]}"
                            if phone not in phone_numbers  # Don't add the same number twice
                                phone_numbers.push phone
                                scribeLog "Found phone number in PagerDuty: #{email} => #{phone}"
                    onSuccess(phone_numbers)
        req.on "error", (e) ->
            scribeLog "Error: #{e.message}"
        req.end()
    catch error
        scribeLog "ERROR #{error}"

#<incident>: a json object returned by the Pagerduty api for one incident
#returns a description for <incident> that includes the most relevant parameters
getIncidentDetails = (incident) ->
    service = incident['service']
    description = incident['description']
    assignedTo = incident['assigned_to']

    response = "service name: #{service.summary}, "
    if(description?)
        response += "description: #{description},"
    response += "triggered at #{incident['created_at']}, " +
        "status: #{incident['status']}"

    acknowledgements = incident['acknowledgements']
    if acknowledgements?
        acknowledgementDetails = (acknowledgement) ->
            "#{acknowledgement.acknowledger.summary} at #{acknowledgement.at}"
        response += ', acknowledged by: ' +
            acknowledgements.map(acknowledgementDetails).join(', ')

    response += ", incident number: #{incident['incident_number']}"
    return response

#triggers an alert to a service given its service name
alertServiceByName = (msg, serviceName, description) ->
    if serviceNameKey[serviceName]?
        pagerdutyAlertService(msg, description,
            serviceNameKey[serviceName])
    else
        msg.reply "No service with name \"#{serviceName}\" exists"

#<email>: the email address of the user
#prints the phone numbers of a user
phoneNumbers = (msg, email) ->
    getPhoneNumberByEmail(email, (phones) ->
        if phones == []
            msg.send "No phone numbers found"
        else
            msg.send "Phone numbers: #{phones}"
    )
# Commands
# --------

# TODO: Command regexes should be configurable

alertTriggerService = /alert trigger ([^ ]+) (.+)$/i
alertList = /alert list$/i
alertHelp = /alert help$/i
alerthelpFromMain = /alert help_from_main/i
getPhone = /phone (.+@.+)$/i

commands =
    alert: [
        alertTriggerService,
        alertList,
        alertHelp,
        alerthelpFromMain
    ],
    phone: [
        getPhone
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
            "lists the details of the active Pagerduty alerts\n" +
            "#{botName} phone <email>: " +
            "return the phone number of a user\n"
        msg.reply response

    robot.respond getPhone, (msg) ->
        email = msg.match[1]
        phoneNumbers(msg, email)

    robot.respond alerthelpFromMain, (msg) ->
        msg.send "#{botName} alert <subcommand>: manages pagerduty alerts, " +
            "see '#{botName} alert help' for details"

module.exports.commands = commands

module.exports.phone = (email, onSuccess) ->
    getPhoneNumberByEmail(email, onSuccess)
