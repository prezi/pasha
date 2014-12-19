# Integration tests for pasha_commands module
# -------------------------------------------

# Node imports
path = require('path')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
Message = require('hubot/src/message')
TextMessage = Message.TextMessage
# Pasha imports
commandsModule = require('../scripts/commands')
constant = require('../pasha_modules/constant').constant
mainModule = require('../scripts/pasha_main')

botName = constant.botName

# Integration tests
# -----------------

describe 'commands robot.respond listener', ->
    robot = null
    user = null
    adapter = null

    badCommandRegex = /^Command not found:/
    badArgumentRegex = /^Incorrect arguments for command:/

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
            commandsModule robot
            mainModule robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()

        # Register commands manually
        robot.registeredCommands =
            'good': [/^good$/, /^good girl$/, /^good year \d\d/]
            'cool': [/^cool$/, /^cool girl$/, /^cool year \d\d/]
            'healthcheck': [/healthcheck/]
        
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should show bad-command-message if input is not valid command',
    (done) ->
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            assert.match(response, badCommandRegex,
                'should show bad command message')
            assert.notMatch(response, badArgumentRegex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{botName} someBadCommand"))

    it 'should show bad-argument-message if input is not valid command',
    (done) ->
        adapter.on "reply", (envelope, responseLines) ->
            response = responseLines[0]
            assert.notMatch(response, badCommandRegex,
                'should not show bad command message')
            assert.match(response, badArgumentRegex,
                'should show bad argument message')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} good someBadArgument"))

    it 'should not return any error message in the help response ' +
    'if no command is passed to the bot', (done) ->
        adapter.on "send", (envelope, responseLines) ->
            response = responseLines[0]
            assert.notMatch(response, badCommandRegex,
                'should not show bad command message')
            assert.notMatch(response, badArgumentRegex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{botName}"))

    it 'should not return any error message in the help response ' +
    'if only whitespaces are addressed to the bot', (done) ->
        adapter.on 'send', (envelope, responseLines) ->
            response = responseLines[0]
            assert.notMatch(response, badCommandRegex,
                'should not show bad command message')
            assert.notMatch(response, badArgumentRegex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{botName}    "))

    it 'should not return any error message if the input is a valid command',
    (done) ->
        error = 0
        adapter.on "reply", (envelope, responseLines) ->
            response = responseLines[0]
            if response.match(badCommandRegex)
                error = 1
            if response.match(badArgumentRegex)
                error = 1
        adapter.receive(new TextMessage(user, "#{botName} healthcheck"))
        setTimeout () ->
            assert.equal(error, 0, 'should not return error message')
            done()
        , 500
