# Unit tests for pasha_commands module
# ------------------------------------

# Node imports
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
# Pasha imports
checker = require('../scripts/commands').checker
registerCommand = require('../scripts/commands').registerCommand
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands
constant = require('../pasha_modules/constant').constant

botName = constant.botName

describe 'registerCommand', () ->
    robot = null

    beforeEach () ->
        robot = new Robot(null, 'mock-adapter', false, botName)

    it 'should create robot.registeredCommands if it does not exist yet', () ->
        registerCommand robot, 'role', [/^role$/, /^role (.+)$/]
        assert.isDefined(robot.registeredCommands,
            'robot.registeredCommands should be created')

    it 'should insert commands with regexes into robot.commands', () ->
        registerCommand robot, 'role', [/^role$/, /^role (.+)$/]
        assert.isDefined(robot.registeredCommands['role'],
            'robot.registeredCommands should have key "role"')

        assert.equal(robot.registeredCommands['role'][0].toString(),
            /^role$/.toString(),
            'robot.registeredCommands should contain ' +
            'the registered "role" regexes')

        assert.equal(robot.registeredCommands['role'][1].toString(),
            /^role (.+)$/.toString(),
            'robot.registeredCommands should contain ' +
            'the registered "role" regexes')

describe 'registerModuleCommands', () ->
    robot = null
    commands =
        'good': [/good boy/, /good girl/]
        'bad': [/bad boy/, /bad girl/]

    beforeEach () ->
        robot = new Robot(null, 'mock-adapter', false, botName)
        registerModuleCommands robot, commands

    it 'should add all keys and values from commands object to ' +
    'robot.registeredCommands', () ->
        assert.property(robot.registeredCommands, 'good')
        assert.property(robot.registeredCommands, 'bad')
        assert.equal(robot.registeredCommands['good'], commands['good'])
        assert.equal(robot.registeredCommands['bad'], commands['bad'])

describe 'checker', () ->

    it 'should return a function', () ->
        assert.instanceOf(checker('good'), Function)

    it 'should return a function which for a regex match returns true', () ->
        assert.isTrue(checker('good')(/good/))

    it 'should return a function which for a regex fail returns false', () ->
        assert.isFalse(checker('bad')(/good/))
