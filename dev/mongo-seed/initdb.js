#!/usr/bin/env node

var cp = require('child_process');
var MongoClient = require('mongodb').MongoClient;
var url = 'mongodb://db:27017/meteor';
var initCollectionName = '__dbinit';

function initDB(db, cb) {
    var cmd = 'mongorestore --host db --drop /opt/initdb/dump';

    cp.exec(cmd, function(err, stdout, stderr) {
        if (err) {
            console.log('Error executing `' + cmd + '`: ' + err);
        } else {
            db.collection(initCollectionName).insert({version: 1})
        }

        console.log(stdout);
        console.log(stderr);

        cb();
    });
}

MongoClient.connect(url, function(err, db) {
    if (err) {
        console.error(err);
        return;
    }

    var initCollection = db.collection(initCollectionName);
    initCollection.find({}).toArray(function(err, items) {
        if (err) {
            console.error(err);
            return;
        }

        if (items.length == 0) {
            console.log("Initializing database");
            initDB(db, function() {
                console.log("Done!");
            });
        } else {
            console.log("Skipping database initialization!");
        }
    });
})
