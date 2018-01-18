---
--- Created by slanska
--- DateTime: 2017-11-06 11:03 PM
---

--[[
Enums in Flexilite is pretty much the same as references. When property is declared as enum,
new enum class may be automatically created, or existing enum class will
be used if classRef has valid class name.

Auto created enum class will have 2 special properties: uid (type will be based on type of id values in items list
- so it will be either integer or string), and name, type of 'symbol'

Optional item list will be used to populate data in the enum class. Existing items may be replaced, if their IDs match.

Enums are very similar to foreign key relation in standard RDBMS in sense that they store user defined ID,
not internal object ID, and do not support many-to-many relationship.

Any existing class can be used as enum class, if it has id and text special properties.
Also, auto created enum classes can be extended/modified like regular classes

Differences between enum and regular classes:
1) Enum property will be scalar or array of ID values from referenced enum item (not object ID). It will not be
defined as reference value, but as field value. So, JSON output will have values like "Status": "A"
or "Status": ["A", "B"], not like "Status": 123456
2) Implicit property 'text' will be supplied. So for enum property Order.Status there will be also
implicit property Order.Status.text. Value of this property will be taken from name and possibly
translated based on current user culture.

Enum can be defined in enumDef or refDef. Only one of those is allowed, supplying both will throw an error.
There are few differences in how enumDef and refDef are handled.
enumDef's purpose is for pure enum, i.e. enum value based on item list. refDef is for foreign keys.

For enumDef: classRef can be omitted, if not set, className_propertyName will be used to create a new enum class.
If class is not set, items are mandatory. If class set and already exists, items will be appended to existing
(if any) enum's items. If class set and does not yet exist, it will be created immediately.

For refDef: class is required. If it does not exist, it will be resolved at the end of request processing
(so that multiple classes, referencing each other can be created). Class will NOT be created automatically.
]]

local ClassCreate = require('flexi_CreateClass').CreateClass
local json = require 'cjson'
local NameRef = require 'NameRef'
local class = require 'pl.class'
local DBObject = require 'DBObject'

-- Implements enum storage
---@class EnumManager
local EnumManager = class()

---@param DBContext DBContext
function EnumManager:_init(DBContext)
    ---@type DBContext
    self.DBContext = DBContext
end

---@param self EnumManager
local function upsertEnumItem(self, propDef, item)
    ---@type ClassDef
    local classDef = self.DBContext:getClassDef(propDef.D.enumDef.id)
    local obj = self.DBContext:NewObject(classDef)
    if classDef.D.specialProperties.uid.id then
        obj:setProperty(classDef.D.specialProperties.uid.id, item.id)
    end
    if classDef.D.specialProperties.text.id then
        obj:setProperty(classDef.D.specialProperties.text.id, item.text)
    end
    if classDef.D.specialProperties.icon.id then
        obj:setProperty(classDef.D.specialProperties.icon.id, item.icon)
    end
    if classDef.D.specialProperties.imageUrl.id then
        obj:setProperty(classDef.D.specialProperties.imageUrl.id, item.imageUrl)
    end

    obj:saveToDB()
end

-- Upserts enum item
---@param propDef EnumPropertyDef
---@param item table @comment with fields: id, text, icon, imageUrl
function EnumManager:upsertEnumItem(propDef, item)
    -- Check if item can be added/updated now or must be deferred
    if propDef.D.enumDef.id then
        upsertEnumItem(self, propDef, item)
    else
        propDef.ClassDef.DBContext.DeferredActions:Add(nil, upsertEnumItem, self, propDef, item)
    end
end

---@param propDef EnumPropertyDef
function EnumManager:ApplyEnumPropertyDef(propDef)
    assert(propDef:is_a(self.DBContext.PropertyDef.Classes.EnumPropertyDef))

    if propDef.D.enumDef then
        -- Process as pure enum
        local refClsName
        if propDef.D.enumDef.classRef then
            refClsName = propDef.D.enumDef.classRef.text
        else
            refClsName = string.format('%s_%s', propDef.ClassDef.Name.text, propDef.Name.text)
        end
        local refCls = self.DBContext:getClassDef(propDef.D.enumDef.classRef.text)
        if not refCls then
            refCls = self:CreateEnumClass(refClsName)
        end

        if propDef.enumDef.items then
            self:UpsertEnumItems(refCls, propDef.D.enumDef.items)
        end
    elseif propDef.D.refDef then
        -- Process as foreign key
        local refCls = self.DBContext:getClassDef(propDef.D.refDef.classRef.text)
        if refCls then

        else
            -- Defer resolving
        end
    else
        error('Neither enumDef nor refDef set')
    end
end

-- Creates class for enum type, if needed.
---@param className string
---@param items table @comment (optional) array of EnumItem
function EnumManager:CreateEnumClass(className, items)
    -- Determine id type
    local idType = 'integer'
    if items and #items > 0 then
        for i, v in ipairs(items) do
            if type(v.id) ~= 'number' then
                idType = type(v.id)
                break
            end
        end
    end

    local def = {
        properties = {
            id = {
                rules = {
                    type = idType,
                    minOccurrences = 1,
                    maxOccurrences = 1,
                },
                index = 'unique'
            },
            name = {
                rules = {
                    type = 'symbol',
                    minOccurrences = 1,
                    maxOccurrences = 1,
                }
            },
        },

        specialProperties = {
            uid = { text = 'id' },
            name = { text = 'name' }
        }
    }

    -- Check if class already exists
    local cls = ClassCreate(self.DBContext, className, json.encode(def), false)

    -- Upsert items to enum class
    if items and #items > 0 then
        self:UpsertEnumItems(cls, items)
    end
end

---@param className string
function EnumManager:IsClassEnum(className)
    local cls = self.DBContext:LoadClassDefinition(className)
    if not cls then
        return false, 'Class [' .. className .. '] does not exist'
    end

    local result = cls.D.specialProperties.id and cls.D.specialProperties.text

    return result
end

function EnumManager:UpsertEnumItems(cls, items)
    if not items then
        return
    end

    -- use flexi_DataUpdate
    local stmt = self.DBContext:getStatement '' -- TODO SQL
    for i, v in ipairs(items) do
        local nameRef = { text = v.name }
        setmetatable(nameRef, NameRef)
        nameRef:resolve(cls)

        stmt:reset()
        stmt:bind { [1] = v.id, [2] = nameRef.id }
        stmt:exec()
    end
end

return EnumManager