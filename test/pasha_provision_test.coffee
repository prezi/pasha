# Integration tests for pashaProvision module
# --------------------------------------------

# Node imports
path = require('path')
nock = nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pashaProvision = require('../scripts/pasha_provision')
pashaProvisionCommands = pashaProvision.commands

botName = constant.botName
provisionHostName = process.env.PROVISION_HOST_NAME

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
            pashaProvision robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register provision commands in robot.registeredCommands', () ->
        for command, regexes of pashaProvisionCommands
            assert.property(robot.registeredCommands, command)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)

describe 'provision commands', () ->
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
            pashaProvision robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it "should post runchef command to #{provisionHostName}", () ->
        provisionApi = nock("https://#{provisionHostName}")
            .post('/runchef/', 'data={"criteria": "role:foo"}')
            .reply(200, 'OK')
        adapter.receive(new TextMessage(user, "#{botName} runchef role:foo"))

    it "should post runchef command to #{provisionHostName}", () ->
        provisionApi = nock("https://#{provisionHostName}")
            .post('/reboot/', 'data={"criteria": "role:foo"}')
            .reply(200, 'OK')
        adapter.receive(new TextMessage(user, "#{botName} reboot role:foo"))
