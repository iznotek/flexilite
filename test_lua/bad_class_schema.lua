---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-01-21 12:28 PM
---

--[[
This is set of tests to check various invalid class schema cases
]]

local path = require 'pl.path'
local schema = require 'schema'
local JSON = require 'cjson'
local ClassDef = require 'ClassDef'
local pretty = require 'pl.pretty'

describe('Bad Class schema', function()

    it('should fail: class name &782367', function()

    end)

    it('should fail: property name &782367', function()

    end)

    it('should fail: no properties in class', function()

    end)

    it('should fail: property has no type', function()

    end)

    it('should fail: property maxValue < minValue', function()

    end)

    it('should fail: property maxOccurrences < minOccurrences', function()

    end)

    it('should fail: enum property does not have enumDef or refDef', function()

    end)

    it('should fail: invalid property type', function()

    end)

    it('should fail: ref property does not have refDef', function()

    end)

    it('should fail: type of defaultValue does not match', function()

    end)

end)