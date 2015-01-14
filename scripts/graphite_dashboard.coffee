# Description
#   A server that responds to GET requests with path '/graphs'.
#   It responds with the existing graphs on the server.
#
# Configuration:
#   Change port and host params to match your deployment settings.
#   Specify the appropriate 'Access-Control-Allow-Origin' in response headers.

graphiteUtil = require('../pasha_modules/graphite_util')
scribeLog = require('../pasha_modules/scribe_log').scribeLog
http = require('http')
fs = require('fs')
url = require('url')

module.exports = (robot) ->
  
    server = http.createServer((req, res) ->
        path = url.parse(req.url).pathname
        method = req.method
        if method is 'GET'
            switch path
                when '/graphs'
                    scribeLog 'Prio1-dashboard 200: GET /graphs'
                    resHead =
                        "Content-Type": "text/plain"
                    if process.env.DASHBOARD_ACCESS_CONTROL_ALLOW_ORIGIN
                        value = process.env.DASHBOARD_ACCESS_CONTROL_ALLOW_ORIGIN
                        resHead["Access-Control-Allow-Origin"] = value
                    if process.env.DASHBOARD_ACCESS_CONTROL_ALLOW_CREDENTIALS
                        value = process.env.DASHBOARD_ACCESS_CONTROL_ALLOW_CREDENTIALS
                        resHead["Access-Control-Allow-Credentials"] = value
                    res.writeHead 200, resHead
                    charts = graphiteUtil.getGraphiteCharts(robot)
                    res.write JSON.stringify(charts)
                    res.end()
                when '/healthcheck'
                    scribeLog 'Prio1-dashboard 200: GET /healthcheck'
                    res.writeHead 200,
                        "Content-Type": "text/plain",
                        "Access-Control-Allow-Origin": "*"
                    res.write "I'm healthy, thanks."
                    res.end()
                else
                    scribeLog "Prio1-dashboard 404: GET #{path}"
                    res.writeHead 404
                    res.write 'Not found'
                    res.end()
        else
            scribeLog "Prio1-dashboard 405: #{method} #{path}"
            res.writeHead 405
            res.write 'Bad method'
            res.end()
    )

    port = 8001
    host = '0.0.0.0'
    server.listen(port, host)
    scribeLog 'Prio1-dashboard server listening at http://' + host + ':' + port
