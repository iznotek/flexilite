---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-08-06 9:03 AM
---

return (function()
    local in_file = io.open('../sql/dbschema.sql', 'r')
    local result = in_file:read("*all")
    in_file:close()

    -- Encode it as string
    return result
end)()