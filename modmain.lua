local require = GLOBAL.require

PrefabFiles = {
    "mosswork_farm_assistant_plant_marker",
    "mosswork_farm_assistant_tile_marker",
}

require("mosswork/farm_assistant").Register({
    AddAction = AddAction,
    AddStategraphActionHandler = AddStategraphActionHandler,
    AddPlayerPostInit = AddPlayerPostInit,
    AddComponentAction = AddComponentAction,
    AddClassPostConstruct = AddClassPostConstruct,
    ActionHandler = function(...)
        return GLOBAL.ActionHandler(...)
    end,
})
