# Pasha

![Smart Router](doc/pasha.jpg)

 Pasha is a chat bot that is designed to help during Prio1s with relaying information, improving communication and executing certain tasks. It is a Hubot mod and it was mainly inspired by Gitub's [Chat Ops](https://www.youtube.com/watch?v=NST3u-GjjFw).
 
At Prezi, Pasha has a crucial role during Prio1 situations and it helps us a lot to reduce outage time, increase the efficiency of the communication, to alert teams and people, to find relevant graphs and logs and to create the outage report by using Pasha’s logging functions. 
 
Pasha is designed to be easily extensible. Its modules work the same way as [Hubot modules work](https://github.com/github/hubot/blob/master/docs/README.md#scripting).

##Pasha’s functions
   * Declare and manage a prio1s
    * start, confirm and stop
    * assign roles (leader, communication officer)
    * set and update the current status
   * Reboot servers
   * Send an outage email
   * Check and add entries to [Changelog](https://github.com/prezi/changelog) pages
   * Alert teams and people by phone/email through [Pagerduty](http://www.pagerduty.com/)
   * Update dashboards by adding, editing and removing [graphite](http://graphite.wikidot.com/) graphs

##How to use/install it locally?

###Requirements
 * [Redis](#../../wiki/Setting-up-the-Development-Environment#redis)
 * [Node] (#../../wiki/Setting-up-the-Development-Environment#node)
 * [Configuring Pasha](#../../wiki/Setting-up-the-Development-Environment#configuration)
For more information, visit the [Setup wiki page](../../wiki/Setting-up-the-Development-Environment)!

## Try it ?

Run with an interactive bash adapter from Pasha's root dir: ```./run_scripts/run_bash_adapter.sh```

Run with a HipChat adapter from Pasha's root dir: ```./run_scripts/run_hipchat_adapter.sh```

Pasha also have tests. You can run the tests with this command: ``./run_scripts/run_tests.sh``

##Contribution
Found a bug? Made a fix? Implemented a cool new feature? Or you just have some idea how to make it better? We are very pleased to see it! We are very happy if you help us to make Pasha better!

For more information, visit the [contribution wiki page](../../wiki/Contribution)!

##Documentation
We created a [wiki](../../wiki) to describe how Pasha work.

