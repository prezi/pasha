# Integration tests for pashaPagerduty module
# --------------------------------------------

# Node imports
path = require('path')
nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pashaPagerduty = require('../scripts/pasha_pagerduty')
pashaPagerdutyCommands = pashaPagerduty.commands
get_services_response = require('../test_files/services.json')
get_users_response = require('../test_files/users.json')
get_notifications_response = require('../test_files/notifications.json')

botName = constant.botName
pagerdutyHostName = process.env.PAGERDUTY_HOST_NAME

describe 'command registration', () ->
    robot = null
    user = null
    adapter = null
    pagerduty_get_services = null

    beforeEach (done) ->
        pagerduty_get_services = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/services')
            .reply(200, get_services_response)

        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pashaPagerduty robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register pagerduty commands in robot.registeredCommands', () ->
        for command, regexes of pashaPagerdutyCommands
            assert.property(robot.registeredCommands, command)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)

describe 'alert command', () ->
    robot = null
    user = null
    adapter = null
    pagerduty_get_services = null
    
    beforeEach (done) ->
        pagerduty_get_services = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/services')
            .reply(200, get_services_response)

        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pashaPagerduty robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should trigger an alert to a service using the service name', (done) ->

        pagerdutyAlertService = nock('https://events.pagerduty.com')
            .post('/generic/2010-04-15/create_event.json', {
                service_key: "92b0d9bc4729439dbb0ce0ac0d505a5c"
                event_type: "trigger"
                description: "Keep calm. There is no serious outage."
            }).reply(200, '{"status":"success","message":"Event processed",' +
            '"incidentKey":"pdkey"}')
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], 'pagerduty alert triggered: ' +
                'Keep calm. There is no serious outage.',
                'success message of triggering the service should be received')
            done()
        setTimeout () ->
            adapter.receive(new TextMessage(user,
                "#{botName} alert trigger Alaa_Shafaee_test Keep calm. " +
                "There is no serious outage.")
            )
        , 1000

    it 'should inform users on trying to alert a service that does not exist',
    (done) ->
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0],
                'No service with name "invalid_name" exists')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} alert trigger invalid_name Keep calm. " +
            "There is no serious outage."))

    it 'should list all active alerts', (done) ->
        getIncidentsResponse  = require('../test_files/incidents.json')
        pagerdutyGetActiveIncidents = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/incidents/?status=triggered,acknowledged')
            .reply(200, getIncidentsResponse)

        adapter.on 'reply', (envelope, response) ->
            incidents = response[0].split('\n\n')
            triggeredIncident = incidents[0]
            acknowledgedIncident = incidents[1]

            assert.match(triggeredIncident, /service name: Alaa_Shafaee_test/,
                'service name should show in active incident details')
            expectedDescription = /description: No outage, be positive. :\)/
            assert.match(triggeredIncident, expectedDescription,
                'outage description should show in active incident details')
            assert.match(triggeredIncident, /triggered at 2014-11-19T14:23:58/,
                'incident trigger time should show in active incident details')
            assert.match(triggeredIncident, /status: triggered/,
                'incident status should show in active incident details')
            assert.match(triggeredIncident, /incident number: 53779/,
                'incident number should show in active incident details')
            assert.match(acknowledgedIncident, /status: acknowledged/,
                'correct status should show for each active incident')
            assert.match(acknowledgedIncident,
                /acknowledged by: Alaa Shafaee at 2014-11-19T17:57:12Z/,
                'names of acknowledgers and acknowledgment time' + '
                should show in the details of acknowledged incidents')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} alert list"))

    it 'should inform users when there are no active incidents', (done) ->
        getIncidentsResponse = '{"incidents":[],"limit":100,' +
            '"offset":0,"total":0}'
        pagerdutyGetActiveIncidents = nock("https://#{pagerdutyHostName}")
            .get("/api/v1/incidents/?status=triggered,acknowledged")
            .reply(200, getIncidentsResponse)

        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], 'There are no active incidents',
                'should return "There are no active incidents" message when ' +
                'there are no active incidents')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} alert list"))

    it 'should return the user\'s phone number', (done) ->
        pagerduty_get_users = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/users/?query=test@example.com')
            .reply(200, get_users_response)

        pagerduty_get_notification = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/users/PX123PD/notification_rules')
            .reply(200, get_notifications_response)
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], 'Phone numbers of test@example.com: +36987654321,+36123456789')
            done()
        adapter.receive(new TextMessage(user,
          "#{botName} alert phone test@example.com"))
