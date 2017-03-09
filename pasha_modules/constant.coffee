module.exports = {
    constant: {
        botName: process.env.BOT_NAME || 'pasha';

        pashaStateKey: 'PASHA_STATE'

        hipchatApiToken: process.env.HIPCHAT_API_TOKEN || ''
        hipchatRelayRooms: (process.env.HIPCHAT_RELAY_ROOMS || '').split(',')
            .filter (x) -> x.trim().length > 0
        hipchatMessageLimit: 10000

        slackApiToken: process.env.HUBOT_SLACK_TOKEN || ''
        slackApiNonbotToken: process.env.HUBOT_SLACK_NONBOT_TOKEN || ''
        slackRelayChannels: (process.env.SLACK_RELAY_CHANNELS || '').split(',')
            .filter (x) -> x.trim().length > 0
        testPrio1Channel: process.env.TEST_PRIO1_CHANNEL
        hangoutUrl: process.env.HANGOUT_URL || ''

        httpBasicAuthUser: process.env.HTTP_BASIC_AUTH_USER || ''
        httpBasicAuthPassword: process.env.HTTP_BASIC_AUTH_PASSWORD || ''

        pashaEmailAddress: process.env.PASHA_EMAIL_ADDRESS || ''
        outageEmailAddress: process.env.OUTAGE_EMAIL_ADDRESS || ''

        changelogHostname: process.env.CHANGELOG_HOST_NAME || ''
        changelogPort: process.env.CHANGELOG_PORT || '443'

        pagerdutyApiKey: process.env.PAGERDUTY_SERVICE_API_KEY || ''
        pagerdutyHostname: process.env.PAGERDUTY_HOST_NAME || ''
        pagerdutyPort: process.env.PAGERDUTY_PORT || '443'
        pagerdutyServiceKeys: (process.env.PAGERDUTY_SERVICE_KEYS || '').split(',')
            .filter (x) -> x.trim().length > 0

        provisionHostname: process.env.PROVISION_HOST_NAME || ''
        provisionPort: process.env.PROVISION_PORT || ''

        playbookUrl: process.env.PRIO1_PLAYBOOK_URL || ''
        prio1MonitoredWebsite: process.env.PRIO1_MONITORED_WEBSITE || ''
        prio1Room: process.env.PRIO1_ROOM || ''

        twilioPhoneNumber: process.env.TWILIO_PHONE_NUMBER || ''
        twilioAccountSid: process.env.TWILIO_ACCOUNT_SID || ''
        twilioAuthToken: process.env.TWILIO_AUTH_TOKEN || ''
    }
}
