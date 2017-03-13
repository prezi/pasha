dateformat  = require 'dateformat'
constant    = require './constant'
util        = require './util'
{scribeLog} = require '../pasha_modules/scribe_log'

class Workflow
    constructor: (@robot, @confirmMsg) ->
        @state = null
        @nextTimeoutId = null
        @tenMinuteIntervalId = null

    loadState: () =>
        @state = util.getOrInitState(@robot)
        return @state

    saveState: () =>
        @robot.brain.set(constant.pashaStateKey, JSON.stringify(@state))

    send: (message) =>
        if @state.prio1?.channel?.name?
            @robot.messageRoom @state.prio1.channel.name, message
        else
            @confirmMsg.send message

    remind: (role, message) =>
        @send "@#{@state.prio1.role[role]}: #{message}"

    next: (fun, minutes) =>
        @nextTimeoutId = setTimeout(fun, minutes * 60 * 1000)

    start: () => @zeroMinutes()

    welcome: () =>
        @send "The prio1 is: *#{@state.prio1.title}*. Good luck."
        @send util.describeCurrentRoles(@robot)
        @send "---"
        @remind 'leader', "Please share our best current estimate of impact; " +
            "\"don't know yet\" is fine.\nRemember, you can set a dedicated " +
            "Engineer point of contact at any time with '#{constant.botName} " +
            "role comm \<name\>'"
        # TODO: once support contact is automatically set, remind them to
        # share incoming ticket volume

    zeroMinutes: () =>
        @loadState()
        return unless @state.prio1?
        util.sendConfirmEmail(@state.prio1)
        util.pagerdutyAlert("outage: #{@state.prio1.title}")
        # TODO: auto-assign support lead
        createChannel = (baseName, tryNum = 0) =>
            if tryNum > 0
                channelName = "#{baseName}-#{tryNum}"
            else
                channelName = baseName

            scribeLog "creating channel #{channelName}"

            createParams = {
                name:  channelName
                token: constant.slackApiNonbotToken
            }
            util.slackApi "channels.create", createParams, (err, res, data) =>
                if !err && data.ok
                    scribeLog "created channel #{data.channel.name}"
                    @state.prio1.channel = {id: data.channel.id, name: channelName}
                    @saveState()
                    @confirmMsg.send("Created channel <##{data.channel.id}>, please join and keep all prio1 communication there.")
                    util.invitePrio1RolesToPrio1SlackChannel(@robot, () =>
                        @welcome()
                        @next @fiveMinutes, 5
                    )
                    util.setSlackChannelTopic(@state.prio1.channel.id, "Hangout: " + constant.hangoutUrl)
                    util.relay "Prio1 channel opened <##{@state.prio1.channel.id}>"
                else
                    scribeLog "failed to create channel #{channelName}"
                    @confirmMsg.send("Failed to create channel #{channelName}: #{err || data.error}")
                    if data?.error == 'name_taken'
                        createChannel(baseName, tryNum + 1)
        # TODO: on other errors, default to #developers
        createChannel "prio1-#{dateformat(new Date(), 'yyyy-mm-dd')}"
        @confirmMsg.send("Don't forget to invite emergency contacts:\n #{generateEmergencyContactList()}.")

    fiveMinutes: () =>
        @loadState()
        return unless @state.prio1?
        # TODO: configurable link to the status page admin interface
        @remind 'comm', 'Please update the green/yellow/red status of components on the status page.'
        @remind 'support', 'Please double-check the updates on the status page, and start public communication if you have a relevant pre-approved message.'
        @next @tenMinutes, 5

    tenMinutes: () =>
        @loadState()
        @remind 'comm', "Please provide an ETA and a simple status update with '#{constant.botName} status ...'\nBad example: packet loss between data centers.\nGood example: network issues, it may be out of our control."
        # TODO: auto-assign marketing lead
        @remind 'support', "Ask for clarifications if needed. If the ETA is above 5 minutes, please alert marketing and start textual public communication. Work with @#{@state.prio1.role.comm} to make sure the communicated information is accurate."
        @tenMinuteIntervalId = setInterval(@everyTenMinutes, 10 * 60 * 1000)
        @next @sixtyMinutes, 50

    everyTenMinutes: () =>
        @loadState()
        @remind 'comm', "Please provide an ETA and a simple status update with '#{constant.botName} status ...'"
        @remind 'support', "Ask for clarifications if needed. Work with marketing and @#{@state.prio1.role.comm} to provide a public update."

    sixtyMinutes: () =>
        @loadState()
        @remind 'marketing', "The prio1 has been going on for an hour. It's time to call a crisis communication meeting, prepare a reactive statement and messaging."
        @next @twoHours, 60

    twoHours: () =>
        @loadState()
        @remind 'marketing', "The prio1 has been going on for two hours. It's time to work with our Brand Communications director to alert HOX."

    stop: () =>
        @loadState()
        @remind 'support', 'If possible, please verify that the prio1 is over. If not possible, please acknowledge that you understand engineering believes the prio1 is over.'
        @remind 'support', "Please work with @#{@state.prio1.role.marketing} to update public communications channels, resolve the outstanding issue and update the green/yellow/red status on the status page. Ask @#{@state.prio1.role.comm} for clarifications as needed."
        clearTimeout @nextTimeoutId if @nextTimeoutId?
        clearInterval @tenMinuteIntervalId if @tenMinuteIntervalId?

module.exports = Workflow
