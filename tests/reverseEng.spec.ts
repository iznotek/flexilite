/**
 * Created by slanska on 2016-03-04.
 */

/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />

'use strict';

var Flexilite = require('../lib/misc/reverseEng');
import mocha = require('mocha');
require('../lib/drivers/SQLite');
import path = require('path');
import orm = require("orm");
var Sync = require('syncho');
import _ = require('lodash');

describe('Reverse Engineering for existing SQLite databases', () =>
{
    beforeEach((done)=>
    {
        done();
    });

    it('Generate schema for Northwind database', (done)=>
    {
        Sync(()=>
        {
            var srcDBName = path.join(__dirname, './data/northwind.db');
            var re = new Flexilite.ReverseEngine(srcDBName);
            var schema = re.loadSchemaFromDatabase.sync(re);

            var destDBName = `${path.join(__dirname, "data", "json_flexi.db")}`;
            var connString = `flexilite://${destDBName}`;
            var db = orm.connect.sync<orm.ORM>(orm, connString);
            _.forEach(schema, (model:ISyncOptions, name:string) =>
            {
                var props = re.getPropertiesFromORMDriverSchema(model);
                var dataClass = db.define(name, props);
                db.sync.sync(db);

                // Define relations

                console.log(name, model);
            });
            done();
        });
    })
});