---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-08-06 9:03 AM
---

return (function()
    local stringx = require 'pl.stringx'

    local in_file = io.open('../sql/dbschema.sql', 'r')
    local res_str = in_file:read("*all")
    in_file:close()

    -- Encode it as string
    local schema_sql = string.format('return %s', stringx.quote_string(res_str))
    return schema_sql
end)()