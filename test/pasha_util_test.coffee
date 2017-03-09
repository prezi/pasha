chai = require('chai')
expect = chai.expect
proxyquire = require('proxyquire')
nock = require('nock')
sinon = require('sinon')
assert = require('assert')
{constant} = require('../pasha_modules/constant')
util = require('../pasha_modules/util')

chai.use require('sinon-chai')


describe 'util', ->
    describe 'postToSlack', ->
        [previousToken] = []
        [token, message, channel, response] = [
            'slacktoken', 'mymessage', 'myslackchannel', 'slackresponse'
        ]

        beforeEach ->
            previousToken = constant.slackApiToken

        afterEach ->
            constant.slackApiToken = previousToken
            nock.cleanAll()

        it 'should post notification to Slack channel', ->
            constant.slackApiToken = token
            scribeLogStub = sinon.stub()

            nock('https://slack.com')
                .matchHeader('content-type', 'application/x-www-form-urlencoded')
                .post('/api/chat.postMessage',
                  token: token,
                  channel: channel,
                  text: message,
                  username: 'pasha')
                .reply(200, -> response)
            util = proxyquire('../pasha_modules/util', {
                '../pasha_modules/scribe_log': {
                    scribeLog: scribeLogStub
                }
            })

            util.postToSlack channel, message, ->
                expect(scribeLogStub).to.have.been.calledWith('slack response: slackresponse')

            expect(scribeLogStub).to.have.been.calledWith('request sent to slack.com')

    describe 'setSlackChannelTopic', ->
        [previousToken] = []
        [token, topic, channel, wrongchannel, response, error] = [
            'slacktoken', 'mytopic', 'myslackchannel', 'wrongchannel', 'slackresponse', 'slackerror'
        ]

        beforeEach ->
            previousToken = constant.slackApiToken

        afterEach ->
            constant.slackApiToken = previousToken
            nock.cleanAll()

        it 'should set topic of channel', ->
            constant.slackApiToken = token
            scribeLogStub = sinon.stub()

            nock('https://slack.com')
                .matchHeader('content-type', 'application/x-www-form-urlencoded')
                .post('/api/channel.setTopic',
                  token: token,
                  channel: channel,
                  topic: topic,
                  username: 'pasha')
                .reply(200, -> response)

                .post('/api/channel.setTopic',
                  token: token,
                  channel: wrongchannel,
                  topic: topic,
                  username: 'pasha')
                .reply(200, -> error)
            util = proxyquire('../pasha_modules/util', {
                '../pasha_modules/scribe_log': {
                    scribeLog: scribeLogStub
                }
            })

            util.setSlackChannelTopic channel, topic, ->
                expect(scribeLogStub).to.have.been.calledWith('slack response: slackresponse')

        it 'failing to set channel topic', ->
            constant.slackApiToken = token
            scribeLogStub = sinon.stub()

            nock('https://slack.com')
                .matchHeader('content-type', 'application/x-www-form-urlencoded')
                .post('/api/channel.setTopic',
                  token: token,
                  channel: channel,
                  topic: topic,
                  username: 'pasha')
                .reply(200, -> response)

                .post('/api/channel.setTopic',
                  token: token,
                  channel: wrongchannel,
                  topic: topic,
                  username: 'pasha')
                .reply(200, -> error)


            util = proxyquire('../pasha_modules/util', {
                '../pasha_modules/scribe_log': {
                    scribeLog: scribeLogStub
                }
            })

            util.setSlackChannelTopic wrongchannel, topic, ->
                expect(scribeLogStub).to.have.been.calledWith('slack response: slackerror')
