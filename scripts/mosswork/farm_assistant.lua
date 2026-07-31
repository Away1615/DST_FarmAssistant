local Mosswork = require("mosswork")
local Shared = require("mosswork/farm_assistant/shared")
local I18N = require("mosswork/farm_assistant/i18n")
local Settings = require("mosswork/farm_assistant/settings")
local Planting = require("mosswork/farm_assistant/planting")

local M = {}
local registered = false

function M.Register(env)
    assert(
        not registered,
        I18N.Translate("mod.name") .. " is already registered"
    )
    registered = true

    Mosswork.AssertAPIVersion(
        Shared.MOSSWORK_API_VERSION,
        I18N.Translate("mod.name")
    )

    local planting = Planting.Register(env)
    local registration = {
        id = Shared.MOD_ID,
        name = function()
            return I18N.Translate("mod.name")
        end,
        version = Shared.MOD_VERSION,
        api_version = Shared.MOSSWORK_API_VERSION,
        order = 100,
    }
    if planting.settings ~= nil then
        Settings.RegisterFeature(planting.settings)
        registration.settings = Settings.GetDefinition(function()
            return I18N.Translate("settings.title")
        end)
    end

    return Mosswork.RegisterOfficialMod(registration)
end

return M
