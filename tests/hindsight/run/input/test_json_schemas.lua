-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[[
# Runs the sample JSON through the generated schemas
--]]

require "io"
require "lfs"
require "rjson"
require "string"

local function read_file(fn)
    print("loading", fn)
    local fh = assert(io.input(fn))
    local s = fh:read("*a")
    fh:close()
    return s
end


local function load_doctypes(namespace, path, schemas)
    for dn in lfs.dir(path) do -- iterate the schema diretories
        local fqdn = string.format("%s/%s", path, dn)
        local mode = lfs.attributes(fqdn, "mode")
        if mode == "directory" and not dn:match("^%.") then
            for fn in lfs.dir(fqdn) do -- iterate the schema files
                local schema, version = fn:match("(.+)%.(%d+)%.schema.json$")
                if schema then
                    local fqfn = string.format("%s/%s", fqdn, fn)
                    local js = read_file(fqfn)
                    schemas[string.format("%s.%s.%s", namespace, schema, version)] = rjson.parse_schema(js)
                end
            end
        elseif mode == "file" then -- accept the new flattened generic ingestion directories
            local schema, version = dn:match("(.+)%.(%d+)%.schema.json$")
            if schema then
                local js = read_file(fqdn)
                schemas[string.format("%s.%s.%s", namespace, schema, version)] = rjson.parse_schema(js)
            end
        end
    end
end


local function load_schemas(path)
    local schemas = {}
    for dn in lfs.dir(path) do -- iterate the namespace directories
        local fqdn = string.format("%s/%s", path, dn)
        local mode = lfs.attributes(fqdn, "mode")
        if mode == "directory" and not dn:match("^%.") then
            load_doctypes(dn, fqdn, schemas)
        end
    end
    return schemas
end


function process_message()
    local schemas = load_schemas("../../schemas")
    local doc = rjson.parse("{}")
    local msg = {
        Type = nil,
        Payload = nil,
        Fields = {
            docType = nil,
            sourceVersion = 0
        }
    }

    local path = "../../validation"
    for namespace in lfs.dir(path) do
        local fqdn = string.format("%s/%s", path, namespace)
        local mode = lfs.attributes(fqdn, "mode")
        if mode == "directory" and not namespace:match("^%.") then
            for fn in lfs.dir(fqdn) do
                local schema, version, test  = fn:match("(.+)%.(%d+)%.(%w+)%.json$")
                if schema then
                    local fqfn = string.format("%s/%s", fqdn, fn)
                    local json = read_file(fqfn)
                    doc:parse(json, nil, nil, true)
                    local ok, err = doc:validate(schemas[string.format("%s.%s.%s", namespace, schema, version)])
                    if not ok then error(err) end

                    msg.Type = namespace
                    msg.Fields.docType = schema
                    msg.Fields.sourceVersion = tonumber(version)
                    msg.Payload = json
                    inject_message(msg)
                end
            end
        end
    end
    return 0
end
