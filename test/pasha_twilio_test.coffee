# Integration tests for the twilio module
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
rewire = require("rewire");
pashaTwilio = rewire('../scripts/pasha_twilio')
pashaTwilioCommands = pashaTwilio.commands

botName = constant.botName

describe 'command registration', () ->
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pashaTwilio robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register twilio commands in robot.registeredCommands', () ->
        for command, regexes of pashaTwilioCommands
            assert.property(robot.registeredCommands, command)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)


    it 'should not summon by name if no pagerduty module is available', (done) ->
        fsStub = {
            existsSync: (path) ->
                return false
        }
        # mock fs lib
        pashaTwilio.__set__('Fs', fsStub)
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], "PagerDuty module is not present, use '#{botName} summon phone_number text'")
            done()
        adapter.receive(new TextMessage(user, "#{botName} summon lorem ipsum"))
        # revert mocks
        pashaTwilio.__set__('Fs', require('fs'))

    it 'should summon a phone number both over SMS and phone call', (done) ->
        sinon = require('sinon')
        constant = require('../pasha_modules/constant').constant
        twilioAccountSid = constant.twilioAccountSid
        twilioAuthToken = constant.twilioAuthToken
        twilio = require('twilio')(twilioAccountSid, twilioAuthToken)
        mockMessages = sinon.mock(twilio.messages)
        mockMessages.create = sinon.spy()
        mockCall = sinon.spy()
        pashaTwilio.__set__('client.messages', mockMessages)
        pashaTwilio.__set__('client.makeCall', mockCall)
        adapter.on 'reply', (envelope, response) ->
            sinon.assert.calledOnce(mockMessages.create)
            smsReason = "You have been summoned by pasha. Join the #mocha HipChat room. The reason is: lorem - (ip)sum!."
            smsPayload = {
                to: "+11234567890123",
                from: constant.twilioPhoneNumber,
                body: smsReason,
            }
            sinon.assert.calledWithExactly(mockMessages.create, smsPayload, sinon.match.any)
            assert(response[0] == "initiated phone call to: +11234567890123" or response[0] == "sent SMS to: +11234567890123")
            if response[0] == "initiated phone call to: +11234567890123"
                callPayload = {
                    to: "+11234567890123",
                    from: constant.twilioPhoneNumber,
                    url: sinon.match.any,
                    IfMachine: "Continue"
                }
                sinon.assert.calledOnce(mockCall)
                sinon.assert.calledWithExactly(mockCall, callPayload, sinon.match.any)
                done()
        adapter.receive(new TextMessage(user,
          "#{botName} summon +1 123(456)789-0123 lorem - (ip)sum!"))

    it 'should summon a person if a name is specified', (done) ->
        # Mock getUser utility function
        sinon = require('sinon')
        util = require('../pasha_modules/util')
        fakeUser = {
            email: "test@example.com"
        }
        getUserStub = sinon.stub().returns(fakeUser)
        util.getUser = getUserStub
        pashaTwilio.__set__("util", util)

        # Mock PagerDuty module
        get_users_response = require('../test_files/users.json')
        get_notifications_response = require('../test_files/notifications.json')
        pagerdutyHostName = process.env.PAGERDUTY_HOST_NAME
        pagerduty_get_users = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/users/?query=test@example.com')
            .reply(200, get_users_response)
        pagerduty_get_notification = nock("https://#{pagerdutyHostName}")
            .get('/api/v1/users/PX123PD/notification_rules')
            .reply(200, get_notifications_response)
        # Mock Sms and calling functions
        smsFunc = sinon.spy()
        callingFunc = sinon.spy()
        pashaTwilio.__set__('sendSms', smsFunc)
        pashaTwilio.__set__('phoneCall', callingFunc)
        # Assert
        adapter.on 'reply', (envelope, response) ->
            if response[0] == "initiated phone call to: lorem (+36123456789)" # this is the last reply
                sinon.assert.callCount(smsFunc, 2)
                sinon.assert.callCount(callingFunc, 2)
                sinon.assert.calledWith(smsFunc, "+36987654321", "ipsum", "#mocha", sinon.match.any, "lorem")
                sinon.assert.calledWith(smsFunc, "+36123456789", "ipsum", "#mocha", sinon.match.any, "lorem")
                sinon.assert.calledWith(callingFunc, "+36987654321", "ipsum", "#mocha", sinon.match.any, "lorem")
                sinon.assert.calledWith(callingFunc, "+36123456789", "ipsum", "#mocha", sinon.match.any, "lorem")
                done()
        adapter.receive(new TextMessage(user,
          "#{botName} summon lorem ipsum"))

      it 'should recognize phone numbers by regex', (done) ->
          # Mock getUser utility function
          sinon = require('sinon')

          # Mock summon functions
          summonByName = sinon.spy()
          pashaTwilio.__set__('summonByName', summonByName)
          summonByPhoneNumber = sinon.spy()
          pashaTwilio.__set__('summonByPhoneNumber', summonByPhoneNumber)
          adapter.receive(new TextMessage(user,
            "#{botName} summon +123456 foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon +(12) 34-56 foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon 12-3 4-5 6 foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon asd foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon @asd foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon a'sd foo"))
          adapter.receive(new TextMessage(user,
            "#{botName} summon asd: foo"))
          done()
          sinon.assert.callCount(summonByPhoneNumber, 3)
          sinon.assert.callCount(summonByName, 4)
