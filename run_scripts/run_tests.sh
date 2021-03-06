#! /bin/sh -ex

mv $(dirname $0)/../hubot-scripts.json $(dirname $0)/../hubot-scripts.json.bup
cp $(dirname $0)/../test_files/hubot-scripts.json $(dirname $0)/../hubot-scripts.json

BOT_NAME=pasha
HIPCHAT_API_TOKEN='test-hipchat-token'
HIPCHAT_RELAY_ROOMS=room1,room2
PAGERDUTY_SERVICE_KEYS=pdkey
CHANGELOG_HOST_NAME=changelog.organization.com
PAGERDUTY_HOST_NAME=organization.pagerduty.com
PROVISION_HOST_NAME=provision.organization.com
PRIO1_PLAYBOOK_URL=http://website.com/infra-prio1-playbook
PRIO1_MONITORED_WEBSITE=sample.website.com
PRIO1_ROOM=Ops
TWILIO_PHONE_NUMBER=
TWILIO_ACCOUNT_SID=123abc
TWILIO_AUTH_TOKEN=123abc

export BOT_NAME
export HIPCHAT_RELAY_ROOMS
export HIPCHAT_API_TOKEN
export PAGERDUTY_SERVICE_KEYS
export CHANGELOG_HOST_NAME
export PAGERDUTY_HOST_NAME
export PROVISION_HOST_NAME
export PRIO1_PLAYBOOK_URL
export PRIO1_MONITORED_WEBSITE
export PRIO1_ROOM
export TWILIO_PHONE_NUMBER
export TWILIO_ACCOUNT_SID
export TWILIO_AUTH_TOKEN

$(dirname $0)/../node_modules/.bin/mocha --compilers coffee:coffee-script/register -R spec "$@"

rm $(dirname $0)/../hubot-scripts.json
mv $(dirname $0)/../hubot-scripts.json.bup $(dirname $0)/../hubot-scripts.json
