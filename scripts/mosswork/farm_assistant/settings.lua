local Mosswork = require("mosswork")
local Shared = require("mosswork/farm_assistant/shared")
local Storage = Mosswork.Storage
local Values = Mosswork.Values

local M = {}
local features = {}
local feature_ids = {}
local built = false
local store = nil
local current = nil

local function IsFeatureId(value)
    return type(value) == "string"
        and value ~= ""
        and #value <= 64
        and value:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function RootKey(feature_id, key)
    return feature_id .. "." .. key
end

local function GetFeatureDefaults(feature)
    local defaults = feature.get_defaults()
    assert(type(defaults) == "table", "feature settings defaults must be a table")
    return defaults
end

local function GetDefaults()
    local result = {}
    for _, feature in ipairs(features) do
        for key, value in pairs(GetFeatureDefaults(feature)) do
            result[RootKey(feature.id, key)] = Values.CopyTable(value)
        end
    end
    return result
end

local function ExtractFeatureValues(feature, values)
    values = type(values) == "table" and values or {}
    local extracted = {}
    for key in pairs(GetFeatureDefaults(feature)) do
        extracted[key] = Values.CopyTable(
            rawget(values, RootKey(feature.id, key))
        )
    end
    return extracted
end

local function Normalize(values)
    local normalized = {}
    for _, feature in ipairs(features) do
        local feature_values = feature.normalize(
            ExtractFeatureValues(feature, values)
        )
        assert(
            type(feature_values) == "table",
            "feature settings normalizer must return a table"
        )
        for key, default in pairs(GetFeatureDefaults(feature)) do
            local value = rawget(feature_values, key)
            normalized[RootKey(feature.id, key)] = Values.CopyTable(
                value ~= nil and value or default
            )
        end
    end
    return normalized
end

local function ApplyFeatures(values)
    for _, feature in ipairs(features) do
        feature.apply(ExtractFeatureValues(feature, values))
    end
end

local function BuildFields()
    local result = {}
    for _, feature in ipairs(features) do
        local defaults = GetFeatureDefaults(feature)
        for _, field in ipairs(feature.fields) do
            assert(
                type(field) == "table"
                    and type(field.key) == "string"
                    and rawget(defaults, field.key) ~= nil,
                "feature settings field must match a default value"
            )
            local copied = Values.CopyTable(field)
            copied.key = RootKey(feature.id, field.key)
            result[#result + 1] = copied
        end
    end
    return result
end

function M.RegisterFeature(definition)
    assert(not built, "Farm settings are already built")
    assert(type(definition) == "table", "feature settings must be a table")
    local id = rawget(definition, "id")
    assert(IsFeatureId(id), "feature settings require a bounded lowercase id")
    assert(not feature_ids[id], "duplicate feature settings id: " .. id)
    assert(
        type(rawget(definition, "get_defaults")) == "function"
            and type(rawget(definition, "normalize")) == "function"
            and type(rawget(definition, "apply")) == "function"
            and type(rawget(definition, "fields")) == "table",
        "feature settings require defaults, normalize, apply, and fields"
    )

    feature_ids[id] = true
    features[#features + 1] = definition
end

function M.GetDefinition(title)
    assert(not built, "Farm settings definition was already requested")
    built = true
    store = Storage.CreateOfficialProfile(Shared.MOD_ID, {
        defaults = GetDefaults,
        normalize = Normalize,
    })
    current = store:Load()
    ApplyFeatures(current)

    return {
        title = title,
        get_values = function()
            return Values.CopyTable(current)
        end,
        get_defaults = GetDefaults,
        normalize = Normalize,
        apply = function(values)
            current = store:Save(values)
            ApplyFeatures(current)
        end,
        fields = BuildFields(),
    }
end

return M
