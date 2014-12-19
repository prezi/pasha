# Integration tests for pashaGraphite module
# ---------------------------------------

# Node imports
path = require('path')
urlModule = require('url')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
Message = require('hubot/src/message')
TextMessage = Message.TextMessage
# Pasha imports
pashaGraphite = require('../scripts/pasha_graphite')
pashaGraphiteCommands = pashaGraphite.commands
graphiteModel = require('../pasha_modules/graphite_model')
Graphite = graphiteModel.Graphite
constant = require('../pasha_modules/constant').constant

botName = constant.botName

# Integration tests
# -----------------

describe 'command registration', ->
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
            pashaGraphite robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register graphite commands in robot.registeredCommands', () ->
        for command, regexes of pashaGraphiteCommands
            assert.property(robot.registeredCommands, command)
            regexes = regexes.toString()
            registeredRegexes = robot.registeredCommands[command].toString()
            assert.equal(regexes, registeredRegexes)

describe 'graphite command', () ->
    robot = null
    user = null
    adapter = null
    graphName = 'error'
    graphUrl = 'https://graphite.organization.com/render/?width=450' +
    '&height=220&from=-4hours&template=plain' +
    '&title=Web+errors+and+warnings&' +
    'vtitle=events+per+min&drawNullAsZero=true&areaMode=stacked' +
    '&areaAlpha=0.3&target=alias(movingAverage(scale' +
    '(logster.error.all,60),5),%27%22Org%22%20log%20errors%27)' +
    '&target=alias(secondYAxis(movingAverage(scale' +
    '(logster.warning.all,60),5)),%27%22Org%22%20log%20warnings%27' +
    ')&colorList=%238c1e1d,%232323ff'
    existingGraphName = 'first_chart'

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join("node_modules/hubot-scripts/src/scripts")
                ),
                'auth.coffee'
            )
            pashaGraphite robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        graphite = new Graphite()
        graphite.charts[existingGraphName] = 'some url'
        graphite.charts['another_graphName'] = 'url 2'
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        robot.run()
    afterEach ->
        robot.shutdown()

    it 'should add a new graph to graphite ' +
    'if no graph with the same name already exists', (done) ->
        adapter.on "reply", (envelope, responseLines) ->
            response = responseLines[0]
            assert.equal(response, "Successfully added #{graphName}")
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph add #{graphName} #{graphUrl}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        assert(graphite?)
        assert(graphite.charts?)
        assert(graphite.charts[graphName]?)
        assert.equal(graphite.charts[graphName], graphUrl)
        
    it 'should replace an existing graph ' +
    'if a graph with the same name already exists', (done) ->
        newUrl = 'new url'
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            assert.equal(response, 'Replaced chart first_chart')
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph add #{existingGraphName} #{newUrl}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        assert(graphite?)
        assert(graphite.charts?)
        assert(graphite.charts[existingGraphName]?)
        assert(graphite.charts[existingGraphName], newUrl)

    it 'should be able to remove an existing graph', (done) ->
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            assert(response,
                "Successfully deleted #{existingGraphName}")
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph remove #{existingGraphName}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        assert(graphite?)
        assert(graphite.charts?)
        assert.isUndefined(graphite.charts[existingGraphName])

    it 'should reply with a descriptive message ' +
    'on removing a graph that does not exist', (done) ->
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            assert.equal(response,
                "No chart with name 'non-existing_name' exists")
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph remove non-existing_name"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        assert(graphite?)
        assert(graphite.charts?)

    it 'should be able to list the existing graphs', (done) ->
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            expectedPattern = "#{existingGraphName}(.*)some url(\n)+" +
                "another_graphName(.*)url 2"
            assert.match(response, new RegExp(expectedPattern))
            done()
        adapter.receive(new TextMessage(user, "#{botName} graph list"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
    
    it 'should reply with "There are no charts to display" ' +
    'on listing graphs if no graphs exist', (done) ->
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(new Graphite()))
        adapter.on 'reply', (envelope, responseLines) ->
            response = responseLines[0]
            assert.equal(response, "There are no charts to display")
            done()
        adapter.receive(new TextMessage(user, "#{botName} graph list"))

    it 'should be able to list the targets of an existing graph', (done) ->
        graphite = new Graphite()
        graphite.charts[graphName] = graphUrl
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on "reply", (envelope, response) ->
            responseLines = response[0].split('\n\n')
            target1 = "alias(movingAverage(scale" +
                "(logster.error.all,60),5),'\"Org\" log errors')"
            target2 = "alias(secondYAxis(movingAverage" +
                "(scale(logster.warning.all,60),5))," +
                "'\"Org\" log warnings')"
            assert.equal(responseLines[0], target1)
            assert.equal(responseLines[1], target2)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target list #{graphName}"))

    it 'should be able to add a target to an existing graph', (done) ->
        graphite = new Graphite()
        graphite.charts[graphName] = graphUrl
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0], /Added a target. The new url is/)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target add #{graphName} new_target"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        newGraphUrl = graphite.charts[graphName]
        urlParams = urlModule.parse(newGraphUrl,true).query
        assert(urlParams?)
        assert(urlParams.target?)
        assert.include(urlParams.target, 'new_target')

    it 'should remove an existing target of a graph ' +
    'if it is not the only target', (done) ->
        graphite = new Graphite()
        graphite.charts[graphName] = graphUrl
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        target = "alias(movingAverage(scale(logster.error.all,60),5)" +
                ",'\"Org\" log errors')"
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0], /Removed a target. The new url is/)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target remove #{graphName} #{target}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        newGraphUrl = graphite.charts[graphName]
        urlParams = urlModule.parse(newGraphUrl,true).query
        assert(urlParams.target?)
        assert.notInclude(urlParams.target, target)

    it 'should not remove an existing target of a graph ' +
    'if it is the only target', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0],
                /You cannot remove the only target of this graph/)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target remove sample t1"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphiteKey))
        newGraphUrl = graphite.charts['sample']
        urlParams = urlModule.parse(newGraphUrl,true).query
        assert(urlParams.target?)
        assert.include(urlParams.target, 't1')

    it 'should inform users on removing targets in a graph ' +
    'that does not have any targets', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/'
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0],
                /The url of this graph does not contain any targets/)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target remove sample t1"))

    it 'should inform users on removing targets ' +
    'that does not exist in a graph', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0],
                /No target with this name exists in this graph./)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target remove sample t2"))

    it 'should inform users on removing targets of non-existing graphs',
    (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, responseLines) ->
            assert.match(responseLines[0],
                /No chart with name wrong_name is found/)
            done()
        adapter.receive(new TextMessage(user,
            "#{botName} graph target remove wrong_name t1"))
