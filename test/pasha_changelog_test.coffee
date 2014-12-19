# Integration tests for pashaChangelog module
# ---------------------------------------

# Node imports
path = require('path')
nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pashaChangelog = require('../scripts/pasha_changelog')
splitMessages = pashaChangelog.splitMessages
pashaChangelogCommands = pashaChangelog.commands

botName = constant.botName
msgMax = constant.hipchatMessageLimit
changelogHostname = constant.changelogHostname
changelogPort = constant.changelogPort

describe 'command registration', () ->
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pashaChangelog robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach () ->
        robot.shutdown()

    it 'should register changelog commands in robot.registeredCommands', () ->
        for command, regexes of pashaChangelogCommands
            assert.property(robot.registeredCommands, command)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)

describe 'changelog command', () ->
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pashaChangelog robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach () ->
        robot.shutdown()

    it 'should post event to changelog', () ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .post('/api/events',
                criticality: 1
                unix_timestamp: timestamp
                category: "pasha"
                description: "mocha: foo"
            ).reply(200, 'OK')
        adapter.receive(new TextMessage(user,
            "#{botName} changelog add foo"))
        # TODO: test that post is sent to changelog
        #       (`postToChangelog` is called)
        # TODO: test that msg.reply happens

    it 'should silently post event to changelog', () ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .post('/api/events',
                criticality: 1
                unix_timestamp: timestamp
                category: "pasha"
                description: "foo"
            ).reply(200, 'OK')
        adapter.receive(new TextMessage(user,
            "#{botName} changelog addsilent foo"))
        # TODO: test that reply happens

    it 'should display changelog events', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,
                [{
                    category: "foo"
                    unix_timestamp: (timestamp - 12)
                    description: "hello"
                    criticality: 2
                },
                {
                    category: "bar"
                    unix_timestamp: (timestamp - 7)                    
                    description: "world"
                    criticality: 2
                }])
        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0].split("\n")
            assert.equal(lines[0],
                "#{(new Date((timestamp - 12) * 1000)).toISOString()} " +
                "- foo - hello",
                'should display changelog events')
            assert.equal(lines[1],
                "#{(new Date((timestamp - 7) * 1000)).toISOString()} " +
                "- bar - world",
                'should display changelog events')
            done()
        adapter.receive(new TextMessage(user, "#{botName} changelog 5m"))

    it 'should display "No entries to show" ' +
    'if there are no entries in the given period', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .get('/api/events?hours_ago=1&until=-1').reply(200, [])

        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0].split('\n')
            assert.equal(lines.length, 1, 'should send only one message')
            assert.equal(lines[0], 'No entries to show')
            done()

        adapter.receive(new TextMessage(user, "#{botName} changelog 5m"))

     it 'should display "The total lenghts of the entries is exceeds the limit"
        message if there are too many entries and no force-flag', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,
                [
                    category: "foo"
                    unix_timestamp: (timestamp - 12)
                    description: Array(msgMax).join('a')
                    criticality: 2
                ])
        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0].split('\n')
            assert.equal(lines.length, 2, 'should send 2 messages')
            assert.equal(lines[0], 'Too many entries to show')
            assert.equal(lines[1],
                'Add -f to get the entries in seperate messages')
            done()
        adapter.receive(new TextMessage(user, "#{botName} changelog 5m"))

     it 'should display the split entries if the force-flag is added', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock("https://#{changelogHostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,
                [
                    category: "foo"
                    unix_timestamp: (timestamp - 12)
                    description: Array(msgMax).join('a')
                    criticality: 2
                ])
        resp = "#{(new Date((timestamp - 12) * 1000)).toISOString()} " +
            "- foo - #{Array(msgMax).join("a")}\n"
        expectedMsg = splitMessages(resp)
        noMsgReceived = 0
        # console.log resp
        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0]
            assert.equal(lines, expectedMsg[noMsgReceived],
                'should display the relevant chunk of the full message')
            noMsgReceived++
            if(noMsgReceived == expectedMsg.length)
                done()
        adapter.receive(new TextMessage(user, "#{botName} changelog 5m -f"))
