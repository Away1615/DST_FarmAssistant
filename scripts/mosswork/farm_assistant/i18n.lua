local Language = require("mosswork").Language
local DISPLAY_NAME = "丰耕助手 | Farm Assistant"

local STRINGS = {
    en = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = DISPLAY_NAME .. " Settings",
    },
    zh = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = DISPLAY_NAME .. " 设置",
    },
    es = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = "Configuración de " .. DISPLAY_NAME,
    },
    ru = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = "Настройки " .. DISPLAY_NAME,
    },
    fr = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = "Paramètres de " .. DISPLAY_NAME,
    },
    de = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = DISPLAY_NAME .. "-Einstellungen",
    },
    ja = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = DISPLAY_NAME .. " 設定",
    },
    ko = {
        ["mod.name"] = DISPLAY_NAME,
        ["settings.title"] = DISPLAY_NAME .. " 설정",
    },
}

return Language.Create(STRINGS, "mosswork.farm_assistant")
