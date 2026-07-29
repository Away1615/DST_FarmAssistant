local require = GLOBAL.require
local setmetatable = GLOBAL.setmetatable

PrefabFiles = {
    "mosswork_pa_plant_marker",
    "mosswork_pa_tile_marker",
}

local Mosswork = require("mosswork")
local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local I18N = require("mosswork/planting_assistant/i18n")
local Callback = Mosswork.Callback
local Log = Mosswork.Log.Create(Shared.MOD_ID)
local MossworkRegistry = require("mosswork/registry")

Mosswork.AssertAPIVersion(
    Shared.MOSSWORK_API_VERSION,
    "Planting Assistant"
)

local Server = require("mosswork/planting_assistant/server")
local Client = nil

local function ExecutePlanAction(action)
    return Server.BeginPlantRequest(action)
end

local function ExecuteBatchPlantAction(action)
    return Server.ExecuteBatchAction(action)
end

local function ExecuteMoveAction(action)
    return Server.BeginPlantRequest(action)
end

local PlanAction = AddAction(
    Shared.ACTION_PLAN_ID,
    I18N.Translate("action.plan"),
    ExecutePlanAction
)
PlanAction.priority = 10
PlanAction.rmb = true
PlanAction.distance = Shared.ACTION_ARRIVE_DISTANCE
PlanAction.mount_valid = false
PlanAction.invalid_hold_action = true

local BatchPlantAction = AddAction(
    Shared.ACTION_BATCH_ID,
    I18N.Translate("action.batch"),
    ExecuteBatchPlantAction
)
BatchPlantAction.priority = 10
BatchPlantAction.distance = Shared.ACTION_ARRIVE_DISTANCE
BatchPlantAction.do_not_locomote = true
BatchPlantAction.mount_valid = false
BatchPlantAction.invalid_hold_action = true

local MoveAction = AddAction(
    Shared.ACTION_MOVE_ID,
    I18N.Translate("action.move"),
    ExecuteMoveAction
)
MoveAction.priority = 11
MoveAction.rmb = true
MoveAction.distance = Shared.ACTION_ARRIVE_DISTANCE
MoveAction.mount_valid = false
MoveAction.invalid_hold_action = true

local function RefreshActionStrings()
    PlanAction.str = I18N.Translate("action.plan")
    BatchPlantAction.str = I18N.Translate("action.batch")
    MoveAction.str = I18N.Translate("action.move")
end

I18N.AddListener(RefreshActionStrings)

local function PreparePlanAction(action)
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
PlanAction.pre_action_cb = PreparePlanAction
MoveAction.pre_action_cb = PreparePlanAction

Server.SetBatchAction(BatchPlantAction)

local function PlayBatchPlantAnimation(inst, preview)
    if inst:HasTag("beaver") then
        inst.AnimState:PlayAnimation("atk_pre")
        inst.AnimState:PushAnimation(preview and "atk_lag" or "atk", false)
    else
        inst.AnimState:PlayAnimation("pickup")
        inst.AnimState:PushAnimation(
            preview and "pickup_lag" or "pickup_pst",
            false
        )
    end
end

local function EnterBatchPlantState(inst)
    inst.components.locomotor:Stop()
    PlayBatchPlantAnimation(inst, false)
    inst.sg.statemem.action = inst:GetBufferedAction()
    inst.sg:SetTimeout(
        Shared.BATCH_ACTION_DURATION_FRAMES * GLOBAL.FRAMES
    )
end

local function PerformBatchPlantStateAction(inst)
    inst:PerformBufferedAction()
end

local function ExitBatchPlantState(inst)
    local action = inst.sg.statemem.action
    if action ~= nil and inst:GetBufferedAction() == action then
        inst:ClearBufferedAction()
    end
end

AddStategraphState(
    "wilson",
    GLOBAL.State({
        name = Shared.BATCH_ACTION_STATE,
        tags = { "doing", "busy", "pausepredict" },
        onenter = EnterBatchPlantState,
        timeline = {
            GLOBAL.TimeEvent(
                Shared.BATCH_ACTION_PERFORM_FRAME * GLOBAL.FRAMES,
                PerformBatchPlantStateAction
            ),
        },
        ontimeout = function(inst)
            inst.sg:GoToState("idle", true)
        end,
        onexit = ExitBatchPlantState,
    })
)

local function EnterClientBatchPlantState(inst)
    inst.components.locomotor:Stop()
    PlayBatchPlantAnimation(inst, true)
    inst:PerformPreviewBufferedAction()
    inst.sg:SetTimeout(2)
end

local function UpdateClientBatchPlantState(inst)
    if inst.sg:ServerStateMatches() then
        if inst.entity:FlattenMovementPrediction() then
            inst.sg:GoToState("idle", "noanim")
        end
    elseif inst:GetBufferedAction() == nil then
        inst.sg:GoToState("idle")
    end
end

local function TimeoutClientBatchPlantState(inst)
    inst:ClearBufferedAction()
    inst.sg:GoToState("idle")
end

AddStategraphState(
    "wilson_client",
    GLOBAL.State({
        name = Shared.BATCH_ACTION_STATE,
        tags = { "doing", "busy" },
        server_states = { Shared.BATCH_ACTION_STATE },
        onenter = EnterClientBatchPlantState,
        onupdate = UpdateClientBatchPlantState,
        ontimeout = TimeoutClientBatchPlantState,
    })
)

local function AddImmediateActionHandlers(stategraph)
    AddStategraphActionHandler(
        stategraph,
        GLOBAL.ActionHandler(PlanAction, nil)
    )
    AddStategraphActionHandler(
        stategraph,
        GLOBAL.ActionHandler(MoveAction, nil)
    )
end

AddImmediateActionHandlers("wilson")
AddImmediateActionHandlers("wilson_client")
AddStategraphActionHandler(
    "wilson",
    GLOBAL.ActionHandler(BatchPlantAction, Shared.BATCH_ACTION_STATE)
)
AddStategraphActionHandler(
    "wilson_client",
    GLOBAL.ActionHandler(BatchPlantAction, Shared.BATCH_ACTION_STATE)
)

local function InstallActionHandlersForPlayer(player)
    local stategraph = player ~= nil
        and player.sg ~= nil
        and player.sg.sg
        or nil
    if stategraph == nil then
        return
    end

    stategraph.actionhandlers = stategraph.actionhandlers or {}
    if stategraph.actionhandlers[PlanAction] == nil then
        stategraph.actionhandlers[PlanAction] = GLOBAL.ActionHandler(
            PlanAction,
            nil
        )
    end
    if stategraph.actionhandlers[MoveAction] == nil then
        stategraph.actionhandlers[MoveAction] = GLOBAL.ActionHandler(
            MoveAction,
            nil
        )
    end
    if stategraph.actionhandlers[BatchPlantAction] == nil then
        local states = stategraph.states or {}
        local action_state = states[Shared.BATCH_ACTION_STATE] ~= nil
                and Shared.BATCH_ACTION_STATE
            or states.doshortaction ~= nil and "doshortaction"
            or states.domediumaction ~= nil and "domediumaction"
            or states.dolongaction ~= nil and "dolongaction"
            or nil
        stategraph.actionhandlers[BatchPlantAction] = GLOBAL.ActionHandler(
            BatchPlantAction,
            action_state
        )
    end
end

AddPlayerPostInit(function(player)
    player:DoTaskInTime(0, InstallActionHandlersForPlayer)
end)

local supported_plantable_cache =
    setmetatable({}, { __mode = "k" })

local function EvaluateSupportedPlantable(item)
    if not Shared.IsInventoryPlantable(item) then
        return false
    end

    local inventory_item = item.replica ~= nil
        and item.replica.inventoryitem
        or nil
    if inventory_item ~= nil
        and inventory_item.DeploySpacingRadius ~= nil then
        local completed, spacing, issue = Callback.Run(
            "action replica DeploySpacingRadius",
            inventory_item.DeploySpacingRadius,
            {
                timeout_ms = Shared.PLANT_QUERY_CALLBACK_TIMEOUT_MS,
                instruction_limit =
                    Shared.PLANT_QUERY_CALLBACK_INSTRUCTION_LIMIT,
                hook_interval = Shared.PLANT_CALLBACK_HOOK_INTERVAL,
                quarantine_seconds = Shared.CLIENT_PLANT_METADATA_RETRY_TIME,
            },
            inventory_item
        )
        if completed
            and issue == nil
            and Shared.IsValidSpacing(spacing) then
            return true
        end
    end

    local deployable = item.components ~= nil
        and item.components.deployable
        or nil
    if deployable == nil or deployable.DeploySpacingRadius == nil then
        return false
    end

    local completed, spacing, issue = Callback.Run(
        "action component DeploySpacingRadius",
        deployable.DeploySpacingRadius,
        {
            timeout_ms = Shared.PLANT_QUERY_CALLBACK_TIMEOUT_MS,
            instruction_limit = Shared.PLANT_QUERY_CALLBACK_INSTRUCTION_LIMIT,
            hook_interval = Shared.PLANT_CALLBACK_HOOK_INTERVAL,
            quarantine_seconds = Shared.CLIENT_PLANT_METADATA_RETRY_TIME,
        },
        deployable
    )
    return completed
        and issue == nil
        and Shared.IsValidSpacing(spacing)
end

local function IsSupportedPlantable(item)
    if item == nil then
        return false
    end

    local now = GetStaticTime()
    local cached = supported_plantable_cache[item]
    if cached ~= nil
        and (
            (
                cached.slow
                and now - cached.checked_at
                    < Shared.CLIENT_PLANT_METADATA_RETRY_TIME
            )
            or (
                not cached.slow
                and now - cached.checked_at
                    < Shared.CLIENT_PLANT_METADATA_CACHE_TIME
            )
        ) then
        return cached.supported
    end

    local started_at = type(GetTimeReal) == "function"
        and GetTimeReal()
        or nil
    local supported = EvaluateSupportedPlantable(item)
    local finished_at = type(GetTimeReal) == "function"
        and GetTimeReal()
        or nil
    local slow = started_at ~= nil
        and finished_at ~= nil
        and finished_at - started_at
            >= Shared.PLANT_QUERY_CALLBACK_SLOW_THRESHOLD_MS
    if slow then
        Log:Warn(
            "slow action plant metadata prefab=%s elapsed_ms=%.2f;"
                .. " result accepted",
            tostring(item.prefab),
            finished_at - started_at
        )
    end

    supported_plantable_cache[item] = {
        checked_at = now,
        slow = slow,
        supported = supported,
    }
    return supported
end

local function IsPlanningStartInRange(doer, x, z)
    local anchor_x, anchor_z = Layout.GetAnchorAtPoint(x, z)
    if anchor_x == nil or anchor_z == nil then
        return false
    end

    local target_x = anchor_x + Shared.TILE_SIZE * 0.5
    local target_z = anchor_z + Shared.TILE_SIZE * 0.5
    local doer_x, _, doer_z = doer.Transform:GetWorldPosition()
    local delta_x = target_x - doer_x
    local delta_z = target_z - doer_z
    local max_distance = Shared.MAX_REQUEST_DISTANCE
    return delta_x * delta_x + delta_z * delta_z
        <= max_distance * max_distance
end

local function ShouldPlanBatch(doer, x, z)
    if not IsPlanningStartInRange(doer, x, z) then
        return false
    end

    if Server.HasActiveBatch(doer) then
        return false
    end

    return Client == nil
        or doer ~= GLOBAL.ThePlayer
        or not Client.IsRequestPending()
end

local function AddPlantPointAction(item, doer, point, actions, right)
    if not right
        or not IsSupportedPlantable(item)
        or point == nil then
        return
    end

    InstallActionHandlersForPlayer(doer)
    table.insert(
        actions,
        ShouldPlanBatch(doer, point.x, point.z)
            and PlanAction
            or MoveAction
    )
end

local function AddPlantTargetAction(item, doer, target, actions, right)
    if not right
        or not IsSupportedPlantable(item)
        or target == nil
        or not target:IsValid()
        or target.Transform == nil then
        return
    end

    InstallActionHandlersForPlayer(doer)
    local x, _, z = target.Transform:GetWorldPosition()
    table.insert(
        actions,
        ShouldPlanBatch(doer, x, z)
            and PlanAction
            or MoveAction
    )
end

AddComponentAction(
    "POINT",
    "deployable",
    AddPlantPointAction
)
AddComponentAction(
    "USEITEM",
    "deployable",
    AddPlantTargetAction
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
    AddClassPostConstruct("widgets/controls", function(controls)
        Client.Attach(controls.owner)
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
