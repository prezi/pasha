# Pasha command registration and error handling

constant = require('../pasha_modules/constant').constant

botName = constant.botName

# Helpers
# -------

# Register given main command with given regexes in robot.registeredCommands
# If robot.registeredCommands does not exist yet,
# initializes it to an empty list.
# command: string - e.g.: 'role'
# regexes: list of regexes - e.g.: [/'role'/, /'role comm (\.+)'/, ...]
registerCommand = (robot, command, regexes) ->
    if robot.registeredCommands == undefined
        robot.registeredCommands = []
    robot.registeredCommands[command] = regexes

registerModuleCommands = (robot, commands) ->
    for command, regexes of commands
        registerCommand(robot, command, regexes)

# Helper function for array.some method.
checker = (inp) ->
    (regex) ->
        (inp.match regex) != null

# Main
# ----

module.exports = (robot) ->

    if not process.env.PASHA_SKIP_COMMAND_NOT_FOUND?
        robot.respond /(.*)/, (msg) ->
            inp = msg.match[1]
            if not inp
                return

            words = inp.split(/\s+/)

            if robot.registeredCommands[words[0]] == undefined
                msg.reply "Command not found: " + words[0]
                return

            if not robot.registeredCommands[words[0]].some(checker(inp))
                msg.reply "Incorrect arguments for command: #{words[0]}\n" +
                          "Type '#{botName} #{words[0]} help' to see command usage"
                return

module.exports.registerCommand = registerCommand
module.exports.registerModuleCommands = registerModuleCommands
module.exports.checker = checker
