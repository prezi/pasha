urlModule = require('url')

class Graphite

    constructor: () ->
        # The keys of @charts denote the names of graphs and the corresponding
        # values are their urls
        @charts = {}

    setCharts: (charts) ->
        @charts = charts

    getCharts: () ->
        @charts

    getChart: (chartName) ->
        @charts[chartName]

    addChart: (chartName, chart) ->
        @charts[chartName] = chart

    removeChart: (chartName) ->
        if @charts[chartName] == undefined
            return false
        else
            delete @charts[chartName]
            return true

    # Adds a new metric (target) to the graph called chartName
    addTarget: (chartName, target) ->
        chartUrl = @getChart chartName
        url = null
        if chartUrl?
            url = appendTargetToUrl chartUrl, target
            @addChart chartName, url
        return url

    # Removes an existing metric (target) fom the graph called chartName
    removeTarget: (chartName, target) ->
        chartUrl = @getChart chartName
        if chartUrl == undefined
            return {
                success: false
                errorMsg: "No chart with name #{chartName} is found"
            }
        response = removeTargetFromUrl chartUrl, target
        if response.success
            @addChart chartName, response.url
        return response

    hasChart: (chartName) ->
        @charts[chartName]?

    # Adds one more value to the target parameter in a graph url
    # This is equivalent to adding a metric in a graph
    appendTargetToUrl = (url, target) ->
        urlParts = urlModule.parse(url, true)
        urlParams = urlParts.query
        if not urlParams.target?
            urlParams['target'] = target
        else
            urlParams['target'].push(target)
        # http://stackoverflow.com/questions/7517332/node-js-url-parse-result-back-to-string
        # When you modify urlparts.query, urlParts.search remains unchanged and
        # it is used in formatting the url. So to force it to use query, simply
        # remove search from the object:
        delete urlParts.search
        urlModule.format(urlParts)

    # Removes one metric (target) from a graph url if it already exists
    removeTargetFromUrl = (url, target) ->
        urlParts = urlModule.parse(url, true)
        urlParams = urlParts.query
        if not urlParams.target?
            return {
                success: false
                errorMsg: "The url of this graph does not contain any targets."
            }
        
        targetIndex = urlParams.target.indexOf target
        if targetIndex == -1
            return {
                success: false
                errorMsg: "No target with this name exists in this graph."
            }
                
        # The value of the target parameter is a String only if there is one
        # target in the graph. Otherwise, it is an array.
        if typeof urlParams.target == "string"
            return {
                success: false
                errorMsg: "You cannot remove the only target of this graph." +
                    " Please consider removing the whole graph instead."}
        
        urlParams.target.splice targetIndex, 1
        # http://stackoverflow.com/questions/7517332/node-js-url-parse-result-back-to-string
        # When you modify urlparts.query, urlParts.search remains unchanged and
        # it is used in formatting the url. So to force it to use query, simply
        # remove search from the object:
        delete urlParts.search
        {success: true, url: urlModule.format(urlParts)}


module.exports = {
    Graphite: Graphite
    graphiteKey: "GRAPHITE"
}
