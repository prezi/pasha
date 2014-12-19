# Description
#   Adds/removes graphs to/from a dashboard through Pasha commands.
#   Updates graph metrics(targets) and lists all graphs and their metrics.
#
# Dependencies
#   None
#
# Commands:
#   <bot name> graph/graphite add <graph_name> <graph_url>:
#       adds a graph to the dashboard
#   <bot name> graph/graphite remove <graph_name>:
#       removes a graph from the dashboard
#   <bot_name> graph/graphite list:
#        lists all names and urls of the graphs in the dashboard
#   <bot_name> graph/graphite target add <graph_name> <target>:
#       adds a target (metric) to certain graph
#   <bot_name> graph/graphite target remove <graph_name> <target>:
#       removes a target (metric) from certain graph
#   <bot_name> graph/graphite target <graph_name> list:
#       lists all metrics of certain graph
#   <bot_name> graph/graphite help:
#       lists the available commands to manipulate the dashboard

# Pasha imports
Graphite =  require('../pasha_modules/graphite_model').Graphite
graphiteUtil = require('../pasha_modules/graphite_util')
registerModuleCommands =
    require('../scripts/commands').registerModuleCommands
constant = require('../pasha_modules/constant').constant

botName = constant.botName

# Commands
# --------

# TODO: Command regexes should be configurable

graphiteAddGraph = /graph(ite)? add ([^ ]+) (.+)/i
graphiteRemoveGraph = /graph(ite)? remove ([^ ]+)/i
graphiteListGraphs = /graph(ite)? list$/i
graphiteAddTarget = /graph(ite)? target add ([^ ]+) (.+)$/i
graphiteRemoveTarget = /graph(ite)? target remove ([^ ]+) (.+)$/i
graphiteListTargets = /graph(ite)? target list ([^ ]+)$/i
graphiteHelp = /graph(ite)? help$/i
graphHelpMain = /graph help_from_main/i

graphiteCommands = [graphiteAddGraph,
                    graphiteRemoveGraph,
                    graphiteListGraphs,
                    graphiteAddTarget,
                    graphiteRemoveTarget,
                    graphiteListTargets,
                    graphiteHelp,
                    graphHelpMain]

commands =
    "graphite" : graphiteCommands
    "graph" : graphiteCommands

#Register commands for the error-handling module
registerGraphiteCommands = (robot) ->

    registerCommand(robot, commands)

module.exports = (robot) ->

    graphiteUtil.getOrInitGraphite(robot)
    registerModuleCommands(robot, commands)

    robot.respond graphiteAddGraph, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        chartName = msg.match[2]
        chartTargets = msg.match[3]
        isReplacement = graphite.hasChart(chartName)
        graphite.addChart(chartName, chartTargets)
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        if isReplacement
            msg.reply "Replaced chart #{chartName}"
        else
            msg.reply "Successfully added #{chartName}"

    robot.respond graphiteRemoveGraph, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        chartName = msg.match[2]
        chartTargets = msg.match[3]
        chartIsRemoved = graphite.removeChart(chartName, chartTargets)
        if chartIsRemoved
            robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
            msg.reply "Successfully deleted #{chartName}"
        else
            msg.reply "No chart with name '#{chartName}' exists"

    robot.respond graphiteListGraphs, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        charts = graphite.getCharts()
        if Object.keys(charts).length == 0
            msg.reply 'There are no charts to display'
        else
            chartsStr = ''
            for chartName, chart of charts
                chartsStr += "#{chartName} -> #{chart}\n\n"
            msg.reply chartsStr

    robot.respond graphiteAddTarget, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        chartName = msg.match[2]
        target = msg.match[3]
        url = graphite.addTarget chartName, target
        robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
        if url?
            msg.reply "Added a target. The new url is: #{url}"
        else
            msg.reply "No chart with name #{chartName} is found"

    robot.respond graphiteRemoveTarget, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        chartName = msg.match[2]
        target = msg.match[3]
        response = graphite.removeTarget chartName, target
        if response.success
            robot.brain.set(Graphite.graphiteKey, JSON.stringify(graphite))
            msg.reply "Removed a target. The new url is: #{response.url}"
        else
            msg.reply response.errorMsg

    robot.respond graphiteListTargets, (msg) ->
        graphite = graphiteUtil.getOrInitGraphite(robot)
        chartName = msg.match[2]
        graphiteChart = graphite.getChart chartName
        if graphiteChart?
            targets =
                graphiteUtil.getParameterByName "target", graphiteChart
            if targets instanceof Array
                targets = targets.join("\n\n")
            msg.reply targets
        else
            msg.reply "No chart with name '" + chartName + "' exists"

    robot.respond graphiteHelp, (msg) ->
        response = "#{botName} graph/graphite add <graph_name> <graph_url>: " +
            "adds a graph to the Prio1-dashboard\n" +
            
            "#{botName} graph/graphite remove <graph_name>: " +
            "removes a graph from the Prio1-dashboard\n" +
            
            "#{botName} graph/graphite list: " +
            "lists all names and urls of the graphs in the Prio1-dashboard\n" +

            "#{botName} graph/graphite target add <graph_name> <target>: " +
            "adds a target (metric) to certain graph\n" +

            "#{botName} graph/graphite target remove <graph_name> <target>: " +
            "removes a target (metric) from certain graph\n" +

            "#{botName} graph/graphite target <graph_name> list: " +
            "lists all metrics of certain graph\n" +

            "Notes: <graph_name> cannot contain spaces\n"

        msg.reply response

    robot.respond graphHelpMain, (msg) ->
        msg.send "#{botName} graph/graphite <subcommand>: " +
            "manages Prio1-dashboard graphs, " +
            "see '#{botName} graph/graphite help' for details"

module.exports.commands = commands
