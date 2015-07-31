module.exports = {
    constant: {
        botName: process.env.BOT_NAME

        pashaStateKey: 'PASHA_STATE'

        hipchatApiToken: process.env.HIPCHAT_API_TOKEN
        hipchatRelayRooms: (process.env.HIPCHAT_RELAY_ROOMS || '').split(',')
            .filter (x) -> x.trim().length > 0
        hipchatMessageLimit: 10000
        hangoutUrl: process.env.HANGOUT_URL

        httpBasicAuthUser: process.env.HTTP_BASIC_AUTH_USER
        httpBasicAuthPassword: process.env.HTTP_BASIC_AUTH_PASSWORD

        pashaEmailAddress: process.env.PASHA_EMAIL_ADDRESS
        outageEmailAddress: process.env.OUTAGE_EMAIL_ADDRESS

        changelogHostname: process.env.CHANGELOG_HOST_NAME
        changelogPort: process.env.CHANGELOG_PORT

        pagerdutyApiKey: process.env.PAGERDUTY_SERVICE_API_KEY
        pagerdutyHostname: process.env.PAGERDUTY_HOST_NAME
        pagerdutyPort: process.env.PAGERDUTY_PORT
        pagerdutyServiceKeys: (process.env.PAGERDUTY_SERVICE_KEYS).split(',')
            .filter (x) -> x.trim().length > 0

        provisionHostname: process.env.PROVISION_HOST_NAME
        provisionPort: process.env.PROVISION_PORT

        playbookUrl: process.env.PRIO1_PLAYBOOK_URL
        prio1MonitoredWebsite: process.env.PRIO1_MONITORED_WEBSITE
        prio1Room: process.env.PRIO1_ROOM

        twilioPhoneNumber: process.env.TWILIO_PHONE_NUMBER
        twilioAccountSid: process.env.TWILIO_ACCOUNT_SID
        twilioAuthToken: process.env.TWILIO_AUTH_TOKEN
    }
}
