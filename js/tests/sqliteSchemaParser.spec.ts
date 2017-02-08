/**
 * Created by slanska on 2017-01-30.
 */

/// <reference path="../../typings/tests.d.ts" />

import sqlite = require('sqlite3');
import {SQLiteSchemaParser} from '../flexish/sqliteSchemaParser';
import path = require('path');
import Promise =require( 'bluebird');
let jsBeautify = require('js-beautify');
import fs = require('fs');

describe('Parse SQLite schema and generate Flexilite model', () => {
    beforeEach((done) => {
        done();
    });

    it('Generate schema from Northwind DB', (done) => {
        let dbPath = path.resolve(__dirname, '../../data/Northwind.db3');
        let db = new sqlite.Database(dbPath, sqlite.OPEN_CREATE | sqlite.OPEN_READWRITE);
        let parser = new SQLiteSchemaParser(db);
        parser.parseSchema().then(model => {
            let out = jsBeautify(JSON.stringify(model));
            fs.writeFileSync(path.join(__dirname, '../../data/Northwind.db3.schema.json'), out);
            // console.log(out);
            done();
        });
    });


    afterEach((done) => {
        done();
    });
});