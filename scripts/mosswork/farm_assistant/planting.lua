local Mosswork = require("mosswork")
local Shared = require("mosswork/farm_assistant/planting/shared")
local I18N = require("mosswork/farm_assistant/planting/i18n")
local Server = require("mosswork/farm_assistant/planting/server")
local RPC = Mosswork.RPC.Create(Shared.RPC_NAMESPACE)

local M = {}
local Client = nil
local registered = false

local function RegisterRPC()
    RPC:RegisterServer(
        Shared.RPC_PLANT,
        function(
            player,
            request_id,
            x,
            z,
            rows,
            columns,
            prefab,
            execution_mode
        )
            Server.HandlePlantRequest(
                player,
                request_id,
                x,
                z,
                rows,
                columns,
                prefab,
                execution_mode
            )
        end
    )
    RPC:RegisterServer(
        Shared.RPC_CONTROLLER_PLANT,
        function(
            player,
            request_id,
            x,
            z,
            rows,
            columns,
            prefab,
            source_guid,
            execution_mode
        )
            Server.HandleControllerPlantRequest(
                player,
                request_id,
                x,
                z,
                rows,
                columns,
                prefab,
                source_guid,
                execution_mode
            )
        end
    )
    RPC:RegisterClient(
        Shared.RPC_RESULT,
        function(request_id, reason)
            if Client ~= nil then
                Client.ReceiveResult(request_id, reason)
            end
        end
    )
end

local function SubmitControllerPlantRequest(request)
    if request == nil then
        return
    end
    RPC:SendToServer(
        Shared.RPC_CONTROLLER_PLANT,
        request.request_id,
        request.x,
        request.z,
        request.rows,
        request.columns,
        request.prefab,
        request.source_guid,
        request.execution_mode
    )
end

local function RegisterAction(env)
    local function ExecutePlantAction(action)
        return Server.BeginPlantRequest(action)
    end

    local PlantAction = env.AddAction(
        Shared.ACTION_PLANT_ID,
        I18N.Translate("action.layout"),
        ExecutePlantAction
    )
    PlantAction.priority = 10
    PlantAction.rmb = true
    PlantAction.distance = Shared.ACTION_ARRIVE_DISTANCE
    PlantAction.mount_valid = false
    PlantAction.invalid_hold_action = true

    I18N.AddListener(function()
        PlantAction.str = I18N.Translate("action.layout")
    end)

    local function ExecutePlantOneAction(action)
        return Server.PerformSequentialPlantAction(action)
    end

    local PlantOneAction = env.AddAction(
        Shared.ACTION_PLANT_ONE_ID,
        I18N.Translate("action.plant_one"),
        ExecutePlantOneAction
    )
    PlantOneAction.priority = 10
    PlantOneAction.distance = Shared.PLANT_ONE_ARRIVE_DISTANCE
    PlantOneAction.mount_valid = false
    PlantOneAction.invalid_hold_action = true

    I18N.AddListener(function()
        PlantOneAction.str = I18N.Translate("action.plant_one")
    end)

    local function SendPlantRequest(action)
        if Client == nil
            or action == nil
            or action.doer ~= ThePlayer
            or (action.options ~= nil
                and action.options.mosswork_server_initiated) then
            return
        end

        local request = Client.PreparePlantRequest(action)
        if request ~= nil then
            RPC:SendToServer(
                Shared.RPC_PLANT,
                request.request_id,
                request.x,
                request.z,
                request.rows,
                request.columns,
                request.prefab,
                request.execution_mode
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

    env.AddStategraphActionHandler(
        "wilson",
        env.ActionHandler(PlantAction, GetPlantActionState)
    )
    env.AddStategraphActionHandler(
        "wilson_client",
        env.ActionHandler(PlantAction, GetPlantActionState)
    )
    env.AddStategraphActionHandler(
        "wilson",
        env.ActionHandler(PlantOneAction, GetPlantActionState)
    )
    env.AddStategraphActionHandler(
        "wilson_client",
        env.ActionHandler(PlantOneAction, GetPlantActionState)
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
        for _, action in ipairs({ PlantAction, PlantOneAction }) do
            if stategraph.actionhandlers[action] == nil then
                stategraph.actionhandlers[action] = env.ActionHandler(
                    action,
                    GetPlantActionState
                )
            end
        end
    end

    env.AddPlayerPostInit(function(player)
        player:DoTaskInTime(0, InstallPlantActionHandler)
    end)

    env.AddComponentAction(
        "POINT",
        "deployable",
        function(item, doer, point, actions, right)
            if right
                and point ~= nil
                and Shared.IsInventoryPlantable(item) then
                table.insert(actions, PlantAction)
            end
        end
    )
end

local function RegisterClient(env)
    if Client == nil then
        return nil
    end

    env.AddClassPostConstruct("widgets/controls", function(controls)
        Client.Attach(controls.owner)

        local OnUpdate = controls.OnUpdate
        function controls:OnUpdate(dt)
            if OnUpdate ~= nil then
                OnUpdate(self, dt)
            end
            Client.UpdateControllerHint(self)
        end
    end)

    Client.InstallInputHandlers(SubmitControllerPlantRequest)
    return Client.GetSettingsContribution()
end

function M.Register(env)
    assert(not registered, "planting feature is already registered")
    assert(type(env) == "table", "planting feature requires a mod environment")
    for _, name in ipairs({
        "AddAction",
        "AddStategraphActionHandler",
        "AddPlayerPostInit",
        "AddComponentAction",
        "AddClassPostConstruct",
        "ActionHandler",
    }) do
        assert(type(env[name]) == "function", "missing mod API: " .. name)
    end
    registered = true

    if not TheNet:IsDedicated() then
        Client = require("mosswork/farm_assistant/planting/client")
    end
    RegisterRPC()
    RegisterAction(env)

    return {
        settings = RegisterClient(env),
    }
end

return M
