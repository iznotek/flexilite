/**
 * Created by slanska on 2016-03-26.
 */

/// <reference path="../../typings/lib.d.ts" />

'use strict';

import sqlite3 = require('sqlite3');
var Sync = require('syncho');
import _ = require('lodash');
import orm = require('orm');

/*
 Converts node-orm2 schema definition as it is passed to sync method,
 to Flexilite class and schema definitions
 */
export interface IShemaHelper
{
    targetSchema:ISchemaPropertyDictionary;
    targetClassProps:IClassPropertyDictionaryByName;
    getNameID:(name:string)=>number;
    getClassIDbyName:(className:string)=>number;
    convertFromNodeOrmSync();
}


export class SchemaHelper implements IShemaHelper
{
    constructor(private db:sqlite3.Database, public sourceSchema:ISyncOptions)
    {
    }

    private _targetSchema = {} as ISchemaPropertyDictionary;

    public get targetSchema()
    {
        return this._targetSchema
    };

    private _targetClassProps = {} as IClassPropertyDictionaryByName;

    public get targetClassProps()
    {
        return this._targetClassProps;
    }

    /*
     Callback to return ID for the given name value
     */
    public getNameID:(name:string)=>number;

    /*
     Callback to get class ID by class' name
     */
    public getClassIDbyName:(className:string)=>number;

    public static nodeOrmTypeToFlexiliteType(ormType:string):PROPERTY_TYPE
    {
        var result:string;
        switch (ormType.toLowerCase())
        {
            case 'serial':
            case 'integer':
                return PROPERTY_TYPE.INTEGER;

            case 'number':
                return PROPERTY_TYPE.NUMBER;

            case'binary':
                return PROPERTY_TYPE.BINARY;

            case 'text':
                return PROPERTY_TYPE.TEXT;

            case 'boolean':
                return PROPERTY_TYPE.BOOLEAN;

            case 'object':
                return PROPERTY_TYPE.JSON;

            case 'date':
                return PROPERTY_TYPE.DATETIME;

            case 'enum':
                return PROPERTY_TYPE.ENUM;

            default:
                throw new Error(`Not supported property type: ${ormType}`);
        }
    }

    /*
     Converts node-orm2 model definition as it is passed to sync() method,
     to Flexilite structure. Result is placed to targetClass and targetSchema properties
     which are dictionaries set property name.
     NOTE: Expects to be running inside of Syncho call
     */
    public convertFromNodeOrmSync()
    {
        let self = this;

        if (!_.isFunction(self.getNameID))
            throw new Error('getNameID() is not assigned');
        if (!_.isFunction(self.getClassIDbyName))
            throw new Error('getClassIDbyName() is not assigned');

        self._targetClassProps = {} as IClassPropertyDictionaryByName;
        self._targetSchema = {} as ISchemaPropertyDictionary;

        var s = self._targetSchema;
        var c = self._targetClassProps;

        _.forEach(this.sourceSchema.allProperties, (item:IORMPropertyDef, propName:string) =>
            {
                let propID = self.getNameID(propName);
                let sProp = item.ext || {} as ISchemaPropertyDefinition;
                let cProp = {} as IClassProperty;
                cProp.rules = cProp.rules || {} as IPropertyRulesSettings;
                sProp.map = sProp.map || {} as IPropertyMapSettings;
                cProp.ui = cProp.ui || {} as IPropertyUISettings;

                switch (item.klass)
                {
                    case 'primary':
                        cProp.rules.type = SchemaHelper.nodeOrmTypeToFlexiliteType(item.type);
                        if (item.size)
                            cProp.rules.maxLength = item.size;

                        if (item.defaultValue)
                            cProp.defaultValue = item.defaultValue;

                        if (item.unique || item.indexed)
                        {
                            cProp.unique = item.unique;
                            cProp.indexed = true;
                        }

                        // mapsTo allows to apply basic customization to schema mapping
                        if (!_.isEmpty(item.mapsTo) && !_.isEqual(item.mapsTo, propName))
                            sProp.map.jsonPath = `.${String(item.mapsTo)}`;
                        else sProp.map.jsonPath = `.${propID}`;

                        switch (cProp.rules.type)
                        {
                            case PROPERTY_TYPE.DATETIME:

                                if (item.time === false)
                                {
                                    cProp.dateTime = 'dateOnly';
                                }
                                else
                                {
                                    cProp.dateTime = 'dateTime';
                                }
                                break;

                            case PROPERTY_TYPE.ENUM:
                                cProp.enumDef = {items: []} as IEnumPropertyDefinition;
                                _.forEach(item.items, (enumItem)=>
                                {
                                    let name = self.getNameID(enumItem);
                                    cProp.enumDef.items.push({ID: name, TextID: name});
                                });
                                break;
                        }

                        break;

                    case 'hasOne':
                        // Generate relation
                        cProp.rules.type = PROPERTY_TYPE.OBJECT;
                        let oneRel = self.sourceSchema.one_associations[propName];
                        cProp.reference = {} as IObjectPropertyDefinition;
                        cProp.reference.autoFetch = oneRel.autoFetch;
                        cProp.reference.autoFetchLimit = oneRel.autoFetchLimit;
                        cProp.reference.classID = self.getClassIDbyName(oneRel.model.table);
                        cProp.reference.reversePropertyID = oneRel.reverse;

                        break;

                    case 'hasMany':
                        // Generate relation
                        cProp.rules.type = PROPERTY_TYPE.OBJECT;
                        let manyRel = self.sourceSchema.many_associations[propName];
                        cProp.reference = {} as IObjectPropertyDefinition;
                        cProp.reference.autoFetch = manyRel.autoFetch;
                        cProp.reference.autoFetchLimit = manyRel.autoFetchLimit;

                        cProp.reference.classID = self.getClassIDbyName(manyRel.model.table);
                        break;
                }

                s[item.name] = sProp;
                c[item.name] = cProp;

            }
        );
    }
}

