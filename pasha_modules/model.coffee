class State

    constructor: ->
        @prio1 = null
        @users = []
        @emergencyContacts = {}


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
        }
        @status = status
        @role = {
            starter: starter
            confirmer: null
            leader: starter
            comm: starter
        }
        @workflow = {}
        @url = {
            hangout: null
        }
        @channel = {}


module.exports = {
    State: State
    Channel: Channel
    Prio1: Prio1
}

