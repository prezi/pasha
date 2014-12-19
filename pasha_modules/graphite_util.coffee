scribeLog = require('../pasha_modules/scribe_log').scribeLog
Graphite =  require('../pasha_modules/graphite_model').Graphite

getOrInitGraphite = (adapter) ->
    pashaGraphiteKey = Graphite.graphiteKey
    pashaGraphite = new Graphite()
    pashaGraphiteStr = adapter.brain.get(pashaGraphiteKey)
    if not pashaGraphiteStr?
        adapter.brain.set(pashaGraphiteKey, JSON.stringify pashaGraphite)
        pashaGraphiteStr = adapter.brain.get(pashaGraphiteKey)
        scribeLog 'Graphite was not initialized, successfully initialized it'
    else
        pashaGraphite.setCharts JSON.parse(pashaGraphiteStr).charts
    return pashaGraphite

getGraphiteCharts = (adapter) ->
    graphiteStr = adapter.brain.get(Graphite.graphiteKey)
    graphite = JSON.parse(graphiteStr)
    try
        charts = graphite['charts']
    catch error
        scribeLog "getGraphiteCharts error caught: #{error}"
        charts = {}
    return charts

getParameterByName = (name, url) ->
    query = require('url').parse(url,true).query
    return query[name]


module.exports = {
    getOrInitGraphite: getOrInitGraphite
    getGraphiteCharts: getGraphiteCharts
    getParameterByName: getParameterByName
}
