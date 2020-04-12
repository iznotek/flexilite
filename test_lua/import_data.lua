---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-01-21 12:37 PM
---

-- to run:  /torch/luajit/bin/busted --lua=/torch/luajit/bin/luajit ./import_data.lua

local os = require 'os'
local util = require 'test_util'
local path = require 'pl.path'
local SqliteTable = require 'SqliteTable'

describe('Loading entire database from JSON and verifies accuracy of imported data', function()

    local dbChinook, dbNorthwind

    setup(function()
        local dbChinookPath = path.abspath(path.relpath('../data/Chinook-flexi.db3'))
        os.remove(dbChinookPath)

        dbChinook = util.openFlexiDatabase(dbChinookPath)
        --dbChinook = util.openFlexiDatabaseInMem()

        print('Chinook: opened')
        util.createChinookSchema(dbChinook)
        print('Chinook: schema created')

        util.importChinookData(dbChinook)
        print('Chinook: data imported')

        local dbNorthwindPath = path.abspath(path.relpath('../data/Northwind-flexi.db3'))

        os.remove(dbNorthwindPath)

        --dbNorthwind = util.openFlexiDatabaseInMem()
        dbNorthwind = util.openFlexiDatabase(dbNorthwindPath)
        print('Northwind: opened')

        util.createNorthwindSchema(dbNorthwind)
        print('Northwind: schema created')

        util.importNorthwindData(dbNorthwind)
        print('Northwind: data imported')

        -- Create views to test sql generation

    end)

    it('verify Northwind', function()

    end)

    it('verify Chinook', function()

    end)

    it('SqliteTable:_appendWhere: updatable view', function()
        --local ss = SqliteTable(dbNorthwind, 'EmployeesTerritories')
        --local sql, params = ss:_generate_insert_sql_and_params({
        --    Employees = 1, Territories = 2
        --})

        --print ('##### SqliteTable:_appendWhere: updatable view', sql, params)

        -- assert sql and params
    end)

    it('SqliteTable:_appendWhere: table with one column primary key', function()
    end)

    it('SqliteTable:_appendWhere: table with multi primary key', function()
    end)

    it('SqliteTable:_appendWhere: table with single column primary key', function()
    end)

    it('SqliteTable:_appendWhere: string where', function()
    end)


end)
