/**
 * Created by Ruslan Skorynin on 04.10.2015.
 */

/// <reference path="../typings/tsd.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts"/>
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts"/>

'use strict';

import chai = require('chai');

// TODO var expect = chai.expect;
//var Driver = require('../lib/FlexiliteAdapter').Driver;

import orm = require("orm");
var sqlite3 = require("sqlite3");
import util = require("util");
import path =require("path");
var shortid = require("shortid");
var faker = require("faker");
var Sync = require("syncho");

export function ConnectAndSave(done:Function)
{
    Sync(function ()
    {
        try
        {
            // Use URI file name with shared cache mode
            var fname = `${path.join(__dirname, "data", "test1.db")}`;
            var connString = util.format("flexilite://%s", fname);
            var db = (<any>orm.connect).sync(orm, connString);

            console.log('DB opened\n');
            var Person = db.define("person", {
                name: String,
                surname: String,
                age: {type: "integer", unique: false, ui: {view: "text", width: "150"}, ext: {mappedTo: "C"}},
                male: {type: "boolean"},
                continent: ["Europe", "America", "Asia", "Africa", "Australia", "Antartica"], // ENUM type
                photo: Buffer,
                data: Object // JSON encoded
            }, {
                methods: {
                    fullName: function ()
                    {
                        return this.name + ' ' + this.surname;
                    }
                }
            });

            var Car = db.define('car', {
                name: String,
                model: String,
                plateNumber: String,
                color: String
            });

            /*
             getCar
             hasCar
             removeCar

             == reverse:
             getOwners
             setOwners
             */
            Person.hasOne('car', Car, {reverse: 'owner'});
            /*

             */
            Person.hasMany('cars', Car, {}, {reverse: 'person', key: true});


            // add the table to the database
            db.sync.sync(db);

            // add a row to the person table

            Person.create.sync(Person, {
                name: faker.name.firstName(1),
                surname: faker.name.lastName(1),
                age: faker.random.number({min: 15, max: 60}),
                extra_field: faker.random.number(),
                age2: faker.random.number({min: 15, max: 60}),
                data: {City: faker.address.city(), Street: faker.address.streetName()}
            });
            // query the person table by surname
            var people = Person.find.sync(Person, {surname: "Doe"});

            //    // SQL: "SELECT * FROM person WHERE surname = 'Doe'"

            console.log("People found: %d", people.length);
            console.log("First person: %s, age %d", people[0].fullName(), people[0].age);
            people[0].age = 16;
            people[0].save.sync(people[0]);
        }
        catch (err)
        {
            console.log(err);
            throw err;
        }
        finally
        {
            db.close.sync(db);

            done();
        }

    });

}
