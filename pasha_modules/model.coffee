class State

    constructor: ->
        @prio1 = null
        @users = []


class Channel

    constructor: (topic) ->
        @savedTopic = topic


class Prio1

    constructor: (starter, startedTimestamp, status) ->
        @title = status
        @time = {
            start: startedTimestamp
            confirm: null
            lastStatus: startedTimestamp
            recoveryEta: null
        }
        @status = status
        @role = {
            starter: starter
            confirmer: null
            leader: starter
            comm: null
        }
        @counter = {
            commUnsetMinutes: 0
            statusUnsetMinutes: 0
            revoceryEtaUnsetMinutes: 0
        }
        @url = {
            hangout: null
        }
        @channel = {}


module.exports = {
    State: State
    Channel: Channel
    Prio1: Prio1
}

