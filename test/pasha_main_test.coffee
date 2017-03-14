# Integration tests for pasha_main module
# ---------------------------------------

# Node imports
path = require('path')
_ = require('underscore')
chai = require('chai')
assert = chai.assert
expect = chai.expect
nock = require('nock')
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
Prio1 = require('../pasha_modules/model').Prio1
State = require('../pasha_modules/model').State
constant = require('../pasha_modules/constant').constant
pashaMain = require('../scripts/pasha_main')
pashaMainCommands = pashaMain.commands
util = require('../pasha_modules/util')
hasValue = util.hasValue

botName = constant.botName
playbookUrl = process.env.PRIO1_PLAYBOOK_URL
prio1MonitoredWebsite = process.env.PRIO1_MONITORED_WEBSITE
changelogHostname = constant.changelogHostname
timeoutDuration = 500

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
            pashaMain robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register prio1 commands in robot.registeredCommands', () ->
        for command, regexes of pashaMainCommands
            assert(command of robot.registeredCommands)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)

describe 'prio1 command', () ->
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
            pashaMain robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should accept start if there is no prio1 and show Playbook url', (done) ->
        robot.brain.set(constant.pashaStateKey, JSON.stringify(new State()))
        prio1Room = constant.prio1Room
        roomConfirmationMsg = ''
        if (prio1Room?)
            roomConfirmationMsg = " you can confirm it by joining the " +
                "'#{prio1Room}' room and saying '#{botName} prio1 confirm'"
        hipchatApiMessage1 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                "room_id=room1&from=Pasha&message=mocha started a prio1: " +
                "big trouble.#{roomConfirmationMsg}&notify=1"
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                "room_id=room2&from=Pasha&message=mocha started a prio1: " +
                "big trouble.#{roomConfirmationMsg}&notify=1"
            ).reply(200, '{"status":"sent"}')
        adapter.on "send", (envelope, responseLines) ->
            firstLine = responseLines[0].split("\n")[0]
            assert.equal(firstLine, 'mocha started the prio1: big trouble',
                'should accept start if there is no prio1')
            if hasValue(playbookUrl)
                expected = "Prio1 Playbook URL = #{playbookUrl}"
                expect(responseLines.toString()).to.contain(expected);
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} prio1 start big trouble"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState?)
        assert(pashaState.prio1?)
        assert(pashaState.prio1.time?)
        assert(pashaState.prio1.time.start?)
        timestamp = pashaState.prio1.time.start
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', timestamp,
            'big trouble')))
        assert(_.isEqual(prio1, pashaState.prio1))

    it 'should not accept start if there is a prio1', (done) ->
        pashaState = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert.equal(firstLine, 'you cannot start a prio1: ' +
                'there is one currently going on',
                'should not accept start if there is a prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} prio1 start big trouble"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(_.isEqual(prio1, pashaState.prio1))

    it 'should show url-specific infos in the prio1 help message', (done) ->
        pashaState = new State()
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'send', (envelope, responseLines) ->
            expected = "Prio1 Playbook URL = #{playbookUrl}"
            expect(responseLines.toString()).to.contain(expected);
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 help"))

    it 'should show url-specific infos in the prio1 start message', (done) ->
        pashaState = new State()
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'send', (envelope, responseLines) ->
            if hasValue(playbookUrl)
                expected = "Prio1 Playbook URL = #{playbookUrl}"
                expect(responseLines.toString()).to.contain(expected)
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 start"))

    it 'should accept confirm if there is an unconfirmed prio1', (done) ->
        pashaState = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        hipchatApiRoomlist = nock('https://api.hipchat.com')
            .get('/v1/rooms/list?format=json&auth_token=test-hipchat-token')
            .reply(200, '{"rooms": [{"room_id": 0, "name": "mocha", ' +
                '"topic": "foo"}]}')
        hipchatApiMessage1 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room1&from=Pasha&message=mocha confirmed the prio1' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room2&from=Pasha&message=mocha confirmed the prio1' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        pagerdutyApi = nock('https://events.pagerduty.com')
        .post('/generic/2010-04-15/create_event.json',
            {
                service_key: "pdkey"
                event_type: "trigger"
                description: "outage: big trouble"
            }).reply(200, '{"status":"success","message":"Event processed",' +
                '"incident_key":"pdkey"}')
        slackApi = nock('https://slack.com')
        .get('/api/channels.create').query(true)
        .reply(200, JSON.stringify({ok: true, channel: {}}))

        adapter.on "send", (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            expectedLine = 'mocha confirmed the prio1'
            done() if firstLine == expectedLine
        adapter.receive(new TextMessage(user, "#{botName} prio1 confirm"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState?)
        assert(pashaState.prio1?)
        assert(pashaState.prio1.time?)
        assert(pashaState.prio1.time.start?)
        timestamp = pashaState.prio1.time.confirm
        prio1.time.confirm = timestamp
        prio1.role.confirmer = 'mocha'
        assert(_.isEqual(prio1, pashaState.prio1))

    it 'should not accept confirm if there is no prio1', (done) ->
        robot.brain.set(constant.pashaStateKey, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert.equal(firstLine, 'you cannot confirm the prio1: ' +
                'there is no prio1 going on',
                'should not accept confirm if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 confirm"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        emptyState = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(emptyState, pashaState))

    it 'should not accept confirm if the prio1 already is confirmed', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        prio1.time.confirm = '1234'
        prio1.role.confirmer = 'mocha'
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.equal(responseLines[0], 'the prio1 already is confirmed',
                'should not accept confirm if the prio1 already is confirmed')
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 confirm"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should accept stop if there is an unconfirmed prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        hipchatApiMessage1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room1&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock("https://api.hipchat.com")
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room2&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        adapter.on "send", (envelope, responseLines) ->
            firstLine = responseLines[0].split("\n")[0]
            assert.equal(firstLine, 'mocha stopped the prio1: big trouble',
                'should accept stop if there is an unconfirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 stop"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should accept stop if there is a confirmed prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        prio1.time.confirm = 1234
        prio1.role.confirmer = 'mocha'
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        hipchatApiMessage1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room1&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room2&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        adapter.on 'send', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert.equal(firstLine, 'mocha stopped the prio1: big trouble',
                'should accept stop if there is a confirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 stop"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should not accept stop if there is no prio1', (done) ->
        pashaState = new State()
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert (firstLine == 'you cannot stop the prio1: ' +
                'there is no prio1 going on'),
                'should not accept confirm if there is no prio1'
            done()
        adapter.receive(new TextMessage(user, "#{botName} prio1 stop"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should set comm role if there is a prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState = new State()
        pashaState.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'send', (envelope, responseLines) ->
            assert.equal(responseLines[0], 'Engineer point of contact is now ' +
                "@Clint Eastwood, you can change it with " +
                "'#{botName} role comm <name>'",
                'should set comm role if there is a prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} role comm clint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        pashaState.prio1.role.comm = 'Clint Eastwood'
        assert(_.isEqual(newPashaState, pashaState))

    it 'should not set comm role if there is no prio1', (done) ->
        pashaState = new State()
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.equal(responseLines[0],
                'There\'s no prio1 in progress',
                'should not set comm role if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} role comm clint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should not set comm role if there is no matching user', (done) ->
        pashaState = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.equal(responseLines[0], 'no such user: klint',
                'should not set comm role if there is no matching user')
            done()
        adapter.receive(new TextMessage(user, "#{botName} role comm klint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should set leader role if there is a prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState = new State()
        pashaState.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on "send", (envelope, responseLines) ->
            assert.equal(responseLines[0], "Engineer lead is now " +
                "@Clint Eastwood, you can change it with " +
                "'#{botName} role leader <name>'",
                'should set comm role if there is a prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} role leader clint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        pashaState.prio1.role.leader = "Clint Eastwood"
        assert(_.isEqual(newPashaState, pashaState))

    it 'should not set leader role if there is no prio1', (done) ->
        pashaState = new State()
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.equal(responseLines[0],
                'There\'s no prio1 in progress',
                'should not set leader role if there is no prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} role leader clint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should not set leader role if there is no matching user', (done) ->
        pashaState = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pashaState.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pashaState.users = users
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.equal(responseLines[0], 'no such user: klint',
                'should not set leader role if there is no matching user')
            done()
        adapter.receive(new TextMessage(user, "#{botName} role comm klint"))
        newPashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        pashaState = JSON.parse(JSON.stringify(pashaState))
        assert(_.isEqual(newPashaState, pashaState))

    it 'should find the user by full name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        getUser = util.getUser
        assert(_.isEqual(user, getUser('Clint Eastwood', 'foo', users)))

    it 'should find the user by mention name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        getUser = util.getUser
        assert(_.isEqual(user, getUser('clint', 'foo', users)))

    it 'should find the user by partial name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        getUser = util.getUser
        assert(_.isEqual(user, getUser('East', 'foo', users)))

    it 'should not find the user if there is no matching name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        getUser = util.getUser
        assert(_.isEqual(null, getUser('John', 'foo', users)))

    it 'should not find the user if there are multiple matching names', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user, user]
        getUser = util.getUser
        assert(_.isEqual(null, getUser('East', 'foo', users)))

    it 'should download the users from hipchat', ->
        setUsers = (users) ->
            assert(_.isEqual([{"name": "Clint Eastwood"}], users))
        slackApiUsers = nock('https://slack.com')
            .get('/api/users.list?token=')
            .reply(200, '{"ok": true, "members": [{"name": "Clint Eastwood"}]}')
        downloadUsers = util.downloadUsers
        downloadUsers('', setUsers)

    it 'should display status if there is an unconfirmed prio1', ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0].split("\n")
            assert.equal(lines[0], 'Prio1 status: big trouble',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[1], 'Started: mocha at 1970-01-01T03:25:45.000Z',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[2], 'Confirmed: null at null',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[3], 'Leader: mocha',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[4], 'Communication: null',
                'should display status if there is an unconfirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} status"))

    it 'should display status if there is a confirmed prio1', ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        prio1.time.confirm = '12346'
        prio1.role.confirmer = 'yeti'
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.on 'send', (envelope, responseLines) ->
            lines = responseLines[0].split('\n')
            assert.equal(lines[0], 'Prio1 status: big trouble',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[1], 'Started: mocha at 1970-01-01T03:25:45.000Z',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[2],
                'Confirmed: yeti at 1970-01-01T03:25:46.000Z',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[3], 'Leader: mocha',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[4], 'Communication: null',
                'should display status if there is a confirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} status"))
        
    it 'should not display status if there is no prio1', (done) ->
        robot.brain.set(constant.pashaStateKey, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert.equal(firstLine, 'cannot display prio1 status: ' +
                'there is no prio1 going on',
                'should not display status if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} status"))

    it 'should set status if there is an unconfirmed prio1', ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock(changelogHostname).post('/api/events',
            {"criticality": 1, "unix_timestamp": timestamp,
            "category": "pasha", "description": "mocha set status to foo"})
            .reply(200, 'OK')
        hipchatApiMessage1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room1&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room2&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.receive(new TextMessage(user, "#{botName} status foo"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState?)
        assert(pashaState.prio1?)
        assert(pashaState.prio1.status?)
        assert.equal(pashaState.prio1.status, 'foo')

    it 'should set status if there is a confirmed prio1', ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelogApi = nock(changelogHostname).post('/api/events',
            {"criticality": 1, "unix_timestamp": timestamp,
            "category": "pasha", "description": "mocha set status to foo"})
            .reply(200, 'OK')
        hipchatApiMessage1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                "room_id=room1&from=Pasha&message=mocha set status to foo" +
                "&notify=1"
            ).reply(200, '{"status":"sent"}')
        hipchatApiMessage2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=test-hipchat-token',
                'room_id=room2&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345, +
            'big trouble')))
        prio1.time.confirm = '12346'
        prio1.role.confirmer = 'yeti'
        pashaState = new State()
        pashaState.prio1 = prio1
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        adapter.receive(new TextMessage(user, "#{botName} status foo"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState?)
        assert(pashaState.prio1?)
        assert(pashaState.prio1.status?)
        assert.equal(pashaState.prio1.status, 'foo')

    it 'should not set status if there is no prio1', (done) ->
        robot.brain.set(constant.pashaStateKey, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, responseLines) ->
            firstLine = responseLines[0].split('\n')[0]
            assert.equal(firstLine,
                'cannot set prio1 status: there is no prio1 going on',
                'should not display status if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{botName} status foo"))

describe 'emergencyContacts', () ->
    robot = null
    user = null
    adapter = null
    pashaState = null
    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join("node_modules/hubot-scripts/src/scripts")
                ),
                'auth.coffee'
            )
            pashaMain robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        pashaState=new State()
        pashaState.emergencyContacts = {
          captain: ['kirk', 'picard'],
          engineer: ['scotty', 'laforge'],
          ambassador: ['troy']
          }
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))
        robot.run()

    afterEach ->
        robot.shutdown()


    it 'should list contacts', (done) ->
        expected ="Emergency Contacts: "
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, expected)
            done()
        adapter.receive(new TextMessage(user, "#{botName} contacts"))

    it 'should add contact to empty role', (done) ->
        [role, who] = ['testRole', 'testWho']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "@#{who} is now added to Emergency Contacts as #{role}.")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact add #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState.emergencyContacts?)
        assert(pashaState.emergencyContacts[role]?)
        assert.equal(pashaState.emergencyContacts[role], who)

    it 'should add contact to existing role', (done) ->
        [role, who] = ['engineer', 'testWho']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "@#{who} is now added to Emergency Contacts as #{role}.")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact add #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(pashaState.emergencyContacts?)
        assert(pashaState.emergencyContacts[role]?)
        assert.equal(pashaState.emergencyContacts[role].length, 3)
        assert.equal(pashaState.emergencyContacts[role], "scotty,laforge,#{who}")

    it 'shouldn\'t remove contact from role it is not in', (done) ->
        [role, who] = ['captain', 'laforge']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "@#{who} wasn't even in the list of #{role} contacts")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact remove #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert.equal(pashaState.emergencyContacts[role].length, 2)
        assert.equal(pashaState.emergencyContacts[role].toString(), "kirk,picard")

    it 'shouldn\'t remove contact from nonexisting role', (done) ->
        [role, who] = ['testRole', 'laforge']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "There arent any contacts for #{role}")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact remove #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert.equal(pashaState.emergencyContacts['engineer'].length, 2)
        assert.equal(pashaState.emergencyContacts['engineer'].toString(), "scotty,laforge")

    it 'should remove last contact from existing role', (done) ->
        [role, who] = ['ambassador', 'troy']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "Removed @#{who} from the list of #{role} emergency contacts")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact remove #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert(not pashaState.emergencyContacts[role]?)

    it 'should remove contact from existing role, if not last in that role', (done) ->
        [role, who] = ['engineer', 'laforge']
        adapter.on 'send', (envelope, responseLines) ->
            firstLine=responseLines[0].split("\n")[0]
            assert.equal(firstLine, "Removed @#{who} from the list of #{role} emergency contacts")
            done()
        adapter.receive(new TextMessage(user, "#{botName} contact remove #{role} #{who}"))
        pashaState = JSON.parse(robot.brain.get(constant.pashaStateKey))
        assert.equal(pashaState.emergencyContacts['engineer'].length, 1)
        assert.equal(pashaState.emergencyContacts[role].toString(), "scotty")

describe 'prio1 reminder', ->
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join("node_modules/hubot-scripts/src/scripts")
                ),
                'auth.coffee'
            )
            pashaMain robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    prio1Synonyms = ['prio1', 'prio 1', 'outage']
    if hasValue(prio1MonitoredWebsite)
        prio1Synonyms.push("#{prio1MonitoredWebsite} is down")
    for synonym in prio1Synonyms
        it "should be sent when there is no prio1 running " +
        "and #{synonym} is mentioned", (done) ->
            pashaState = new State()
            pashaState.prio1 = undefined
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))

            adapter.on 'send', (envelope, responseLines) ->
                firstLine = responseLines[0].split("\n")[0]
                expected = 'Is there a prio1? If yes, please register it ' +
                           'with "pasha prio1 start <description of the issue>"'
                assert.equal(firstLine, expected)
                done()
            adapter.receive(new TextMessage(user, "#{synonym} happening"))

    # TODO: change implementation
    for synonym in prio1Synonyms
        it "should not be sent if a prio1 has already been started," +
           " even if #{synonym} is mentioned", (done) ->
            pashaState = new State()
            prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0,
                'big trouble')))
            pashaState.prio1 = prio1
            robot.brain.set(constant.pashaStateKey,
                JSON.stringify(pashaState))

            error = 0
            adapter.on 'send', (envelope, responseLines) ->
                firstLine = responseLines[0].split("\n")[0]
                unexpected = 'Is there a prio1? If yes, please register it ' +
                           'with "pasha prio1 start <description of the issue>"'
                if firstLine == unexpected
                    error = 1
            adapter.receive(new TextMessage(user, "#{synonym} still running?"))
            setTimeout () ->
                if error == 1
                    throw new Error()
                done()
            , timeoutDuration

    # TODO: change implementation
    it 'should not be sent if the message is addressed to the robot', (done) ->
        pashaState = new State()
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))

        error = 0
        adapter.on 'send', (envelope, responseLines) ->
            firstLine = responseLines[0].split("\n")[0]
            unexpected = 'Is there a prio1? If yes, please register it ' +
                       'with "pasha prio1 start <description of the issue>"'
            if firstLine == unexpected
                error = 1
        adapter.receive(new TextMessage(user, "#{botName} prio1 start"))
        setTimeout () ->
            if error == 1
                throw new Error()
            done()
        , timeoutDuration

    # TODO: change implementation
    it 'should not be sent if a message contains no prio1 synonyms', (done) ->
        pashaState = new State()
        robot.brain.set(constant.pashaStateKey, JSON.stringify(pashaState))

        error = 0
        adapter.on 'send', (envelope, responseLines) ->
            firstLine = responseLines[0].split("\n")[0]
            unexpected = 'Is there a prio1? If yes, please register it ' +
                       'with "pasha prio1 start <description of the issue>"'
            if firstLine == expected
                error = 1
        adapter.receive(new TextMessage(user, 'hello world'))
        setTimeout () ->
            if error == 1
                throw new Error()
            done()
        , timeoutDuration
