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
        rewire = require('rewire')
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