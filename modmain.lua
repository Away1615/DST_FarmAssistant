local require = GLOBAL.require

PrefabFiles = {
    "mosswork_pa_plant_marker",
    "mosswork_pa_tile_marker",
}

local Mosswork = require("mosswork")
local Shared = require("mosswork/planting_assistant/shared")
local I18N = require("mosswork/planting_assistant/i18n")
local MossworkRegistry = require("mosswork/registry")

Mosswork.AssertAPIVersion(
    Shared.MOSSWORK_API_VERSION,
    "Planting Assistant"
)

local Server = require("mosswork/planting_assistant/server")
local Client = nil

local function ExecutePlantAction(action)
    return Server.BeginPlantRequest(action)
end

local PlantAction = AddAction(
    Shared.ACTION_PLANT_ID,
    I18N.Translate("action.batch"),
    ExecutePlantAction
)
PlantAction.priority = 10
PlantAction.rmb = true
PlantAction.distance = Shared.ACTION_ARRIVE_DISTANCE
PlantAction.mount_valid = false
PlantAction.invalid_hold_action = true

local function RefreshActionString()
    PlantAction.str = I18N.Translate("action.batch")
end

I18N.AddListener(RefreshActionString)

local function SendPlantRequest(action)
    if Client == nil
        or action == nil
        or action.doer ~= GLOBAL.ThePlayer then
        return
    end

    local request = Client.PreparePlantRequest(action)
    if request == nil then
        return
    end

    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        Server.HandlePlantRequest(
            action.doer,
            request.request_id,
            request.x,
            request.z,
            request.rows,
            request.columns,
            request.prefab
        )
    else
        SendModRPCToServer(
            GetModRPC(Shared.RPC_NAMESPACE, Shared.RPC_PLANT),
            request.request_id,
            request.x,
            request.z,
            request.rows,
            request.columns,
            request.prefab
        )
    end
end

PlantAction.pre_action_cb = SendPlantRequest

local function GetPlantActionState(inst)
    local states = inst ~= nil
        and inst.sg ~= nil
        and inst.sg.sg ~= nil
        and inst.sg.sg.states
        or nil
    if states == nil then
        return nil
    end

    if states.doshortaction ~= nil then
        return "doshortaction"
    elseif states.domediumaction ~= nil then
        return "domediumaction"
    elseif states.dolongaction ~= nil then
        return "dolongaction"
    end
    return nil
end

AddStategraphActionHandler(
    "wilson",
    GLOBAL.ActionHandler(PlantAction, GetPlantActionState)
)
AddStategraphActionHandler(
    "wilson_client",
    GLOBAL.ActionHandler(PlantAction, GetPlantActionState)
)

local function InstallPlantActionHandler(player)
    local stategraph = player ~= nil
        and player.sg ~= nil
        and player.sg.sg
        or nil
    if stategraph == nil then
        return
    end

    stategraph.actionhandlers = stategraph.actionhandlers or {}
    if stategraph.actionhandlers[PlantAction] == nil then
        stategraph.actionhandlers[PlantAction] = GLOBAL.ActionHandler(
            PlantAction,
            GetPlantActionState
        )
    end
end

AddPlayerPostInit(function(player)
    player:DoTaskInTime(0, InstallPlantActionHandler)
end)

local function AddPlantPointAction(item, doer, point, actions, right)
    if right
        and point ~= nil
        and Shared.IsInventoryPlantable(item) then
        table.insert(actions, PlantAction)
    end
end

AddComponentAction(
    "POINT",
    "deployable",
    AddPlantPointAction
)

AddModRPCHandler(
    Shared.RPC_NAMESPACE,
    Shared.RPC_PLANT,
    function(
        player,
        request_id,
        x,
        z,
        rows,
        columns,
        prefab
    )
        Server.HandlePlantRequest(
            player,
            request_id,
            x,
            z,
            rows,
            columns,
            prefab
        )
    end
)

AddModRPCHandler(
    Shared.RPC_NAMESPACE,
    Shared.RPC_CONTROLLER_PLANT,
    function(
        player,
        request_id,
        x,
        z,
        rows,
        columns,
        prefab,
        source_guid
    )
        Server.HandleControllerPlantRequest(
            player,
            request_id,
            x,
            z,
            rows,
            columns,
            prefab,
            source_guid
        )
    end
)

if not GLOBAL.TheNet:IsDedicated() then
    Client = require("mosswork/planting_assistant/client")
end

AddClientModRPCHandler(
    Shared.RPC_NAMESPACE,
    Shared.RPC_RESULT,
    function(request_id, reason)
        if Client ~= nil then
            Client.ReceiveResult(request_id, reason)
        end
    end
)

if Client ~= nil then
    local function SubmitControllerPlantRequest(request)
        if request == nil then
            return
        end

        if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
            Server.HandleControllerPlantRequest(
                GLOBAL.ThePlayer,
                request.request_id,
                request.x,
                request.z,
                request.rows,
                request.columns,
                request.prefab,
                request.source_guid
            )
        else
            SendModRPCToServer(
                GetModRPC(
                    Shared.RPC_NAMESPACE,
                    Shared.RPC_CONTROLLER_PLANT
                ),
                request.request_id,
                request.x,
                request.z,
                request.rows,
                request.columns,
                request.prefab,
                request.source_guid
            )
        end
    end

    AddComponentPostInit("playercontroller", function(controller)
        local OnControl = controller.OnControl
        function controller:OnControl(control, down)
            local handled, request = Client.HandleControllerControl(
                self,
                control,
                down
            )
            if handled then
                SubmitControllerPlantRequest(request)
                return true
            end
            return OnControl(self, control, down)
        end
    end)

    AddClassPostConstruct("widgets/controls", function(controls)
        Client.Attach(controls.owner)

        local OnUpdate = controls.OnUpdate
        function controls:OnUpdate(dt)
            if OnUpdate ~= nil then
                OnUpdate(self, dt)
            end
            Client.UpdateControllerHint(self)
        end
    end)

    Client.InstallInputHandlers()
end

local registration = {
    id = Shared.MOD_ID,
    name = function()
        return I18N.Translate("mod.name")
    end,
    version = Shared.MOD_VERSION,
    api_version = Shared.MOSSWORK_API_VERSION,
    order = 100,
}
if Client ~= nil then
    registration.settings = Client.GetSettingsDefinition()
end
MossworkRegistry.RegisterOfficial(registration)
