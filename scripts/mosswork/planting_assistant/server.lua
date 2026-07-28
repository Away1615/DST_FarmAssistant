local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}

local active_batches = setmetatable({}, { __mode = "k" })
local pending_requests = setmetatable({}, { __mode = "k" })
local last_requests = setmetatable({}, { __mode = "k" })
local batch_queue = {}
local scheduler_cursor = 1
local scheduler_task = nil
local batch_plant_action = nil

local FinishBatch
local StartBatchAction
local ProcessPreflightSlice
local ProcessPlantingSlice
local RunScheduler

local function SendResult(player, request_id, reason)
    if player == nil
        or not player:IsValid()
        or player.userid == nil then
        return
    end

    SendModRPCToClient(
        GetClientModRPC(Shared.RPC_NAMESPACE, Shared.RPC_RESULT),
        player.userid,
        tonumber(request_id) or 0,
        reason or "unknown"
    )
end

local function GetPlayerController(player)
    return player ~= nil
        and player.components ~= nil
        and player.components.playercontroller
        or nil
end

local function IsPlayerOperational(player)
    if player == nil
        or not player:IsValid()
        or player:HasTag("playerghost")
        or player.components == nil
        or player.components.health == nil
        or player.components.health:IsDead()
        or player.components.inventory == nil
        or player.components.locomotor == nil then
        return false
    end

    local controller = GetPlayerController(player)
    if controller == nil or controller.IsEnabled == nil or not controller:IsEnabled() then
        return false
    end

    return player.components.rider == nil or not player.components.rider:IsRiding()
end

local function IsPlayerBusy(player)
    local controller = GetPlayerController(player)
    if controller ~= nil and controller.IsBusy ~= nil and controller:IsBusy() then
        return true
    end

    return player ~= nil
        and player.sg ~= nil
        and (
            player.sg:HasStateTag("busy")
            or player.sg:HasStateTag("frozen")
            or player.sg:HasStateTag("sleeping")
        )
end

local function IsPlayerReadyToStart(player)
    return IsPlayerOperational(player) and not IsPlayerBusy(player)
end

local function IsPlayerNearPoint(player, x, z, distance)
    if player == nil or not player:IsValid() then
        return false
    end

    local target_x = tonumber(x)
    local target_z = tonumber(z)
    if target_x == nil or target_z == nil then
        return false
    end

    local player_x, _, player_z = player.Transform:GetWorldPosition()
    local delta_x = target_x - player_x
    local delta_z = target_z - player_z
    return delta_x * delta_x + delta_z * delta_z <= distance * distance
end

local function ResolveActionPoint(action)
    if action == nil then
        return nil, nil
    end

    local point = action:GetActionPoint()
    if point ~= nil then
        return point.x, point.z
    end

    local target = action.target
    if target ~= nil and target:IsValid() and target.Transform ~= nil then
        local x, _, z = target.Transform:GetWorldPosition()
        return x, z
    end

    return nil, nil
end

local function StackSize(item)
    if item ~= nil and item.components ~= nil and item.components.stackable ~= nil then
        return item.components.stackable:StackSize()
    end
    return item ~= nil and 1 or 0
end

local function IsMatchingDeployable(item, prefab)
    return item ~= nil
        and item:IsValid()
        and item.prefab == prefab
        and item.components ~= nil
        and item.components.deployable ~= nil
end

local function IsItemHeldByPlayer(item, player)
    local inventory_item = item ~= nil
        and item:IsValid()
        and item.components ~= nil
        and item.components.inventoryitem
        or nil
    return inventory_item ~= nil and inventory_item:GetGrandOwner() == player
end

local function GetBoundActiveItem(player, item, prefab)
    local inventory = player ~= nil
        and player.components ~= nil
        and player.components.inventory
        or nil
    if inventory == nil or inventory:GetActiveItem() ~= item then
        return nil
    end

    return IsMatchingDeployable(item, prefab) and item or nil
end

local function FindDeployableItem(player, prefab, preferred_item)
    if IsMatchingDeployable(preferred_item, prefab)
        and IsItemHeldByPlayer(preferred_item, player) then
        return preferred_item
    end

    return player.components.inventory:FindItem(function(item)
        return IsMatchingDeployable(item, prefab)
    end)
end

local function CountDeployableItems(player, prefab)
    local inventory = player.components.inventory
    local total = 0
    local seen = {}
    local function CountItem(item)
        if item == nil
            or seen[item]
            or not IsMatchingDeployable(item, prefab)
            or not IsItemHeldByPlayer(item, player) then
            return
        end

        seen[item] = true
        total = total + StackSize(item)
    end

    CountItem(inventory:GetActiveItem())
    local items = inventory:FindItems(function(item)
        return IsMatchingDeployable(item, prefab)
    end)

    for _, item in ipairs(items) do
        CountItem(item)
    end

    return total
end

local function GetDeploySpacing(item)
    local deployable = item ~= nil
        and item.components ~= nil
        and item.components.deployable
        or nil
    if deployable == nil or deployable.DeploySpacingRadius == nil then
        return nil
    end

    local spacing = deployable:DeploySpacingRadius()
    return Shared.IsValidSpacing(spacing) and spacing or nil
end

local function CanDeployItemAtPoint(item, player, point)
    if item == nil
        or item.components == nil
        or item.components.deployable == nil then
        return false
    end

    return item.components.deployable:CanDeploy(
        Vector3(point.x, 0, point.z),
        nil,
        player,
        0
    )
end

local function ReturnRemovedItem(inventory, item, previous_container, previous_slot)
    if item == nil or not item:IsValid() then
        return
    end

    if previous_container ~= nil
        and previous_container.GiveItem ~= nil
        and previous_container.inst ~= nil
        and previous_container.inst:IsValid() then
        previous_container:GiveItem(item, previous_slot)
        return
    end

    inventory:GiveItem(item, previous_slot)
end

local function DeployOne(player, batch, point)
    local inventory = player.components.inventory
    local item = FindDeployableItem(player, batch.prefab, batch.source_item)
    if item == nil then
        return false, "no_inventory"
    end

    if not CanDeployItemAtPoint(item, player, point) then
        return false, "blocked"
    end

    local deployable = item.components.deployable
    local deploy_point = Vector3(point.x, 0, point.z)
    if deployable.keep_in_inventory_on_deploy then
        local ok, success = pcall(deployable.Deploy, deployable, deploy_point, player, 0)
        if not ok then
            Log:Error("deploy callback failed: %s", tostring(success))
            return false, "internal_error"
        end
        return success and true or false, success and nil or "deploy_failed"
    end

    local removed = inventory:RemoveItem(item, false, false)
    if removed == nil
        or removed.components == nil
        or removed.components.deployable == nil then
        return false, "remove_failed"
    end

    local previous_container = removed.prevcontainer
    local previous_slot = removed.prevslot
    removed.prevcontainer = nil
    removed.prevslot = nil

    local removed_deployable = removed.components.deployable
    local ok, success = pcall(
        removed_deployable.Deploy,
        removed_deployable,
        deploy_point,
        player,
        0
    )
    if not ok then
        Log:Error("deploy callback failed: %s", tostring(success))
        ReturnRemovedItem(inventory, removed, previous_container, previous_slot)
        return false, "internal_error"
    end
    if success then
        return true
    end

    ReturnRemovedItem(inventory, removed, previous_container, previous_slot)
    return false, "deploy_failed"
end

local function SendBatchHeartbeat(player, batch, now)
    now = now or GetTime()
    if batch.client_started
        and now - batch.last_client_heartbeat_time
            >= Shared.BATCH_HEARTBEAT_INTERVAL then
        batch.last_client_heartbeat_time = now
        SendResult(player, batch.request_id, "progress")
    end
end

local function TouchBatch(player, batch)
    local now = GetTime()
    batch.last_progress_time = now
    SendBatchHeartbeat(player, batch, now)
end

local function CancelBatchTasks(batch)
    if batch.watchdog_task ~= nil then
        batch.watchdog_task:Cancel()
        batch.watchdog_task = nil
    end
end

local function HasAnyActiveBatch()
    for _ in pairs(active_batches) do
        return true
    end
    return false
end

local function StopSchedulerIfIdle()
    if HasAnyActiveBatch() then
        return
    end

    if scheduler_task ~= nil then
        scheduler_task:Cancel()
        scheduler_task = nil
    end
    batch_queue = {}
    scheduler_cursor = 1
end

FinishBatch = function(player, reason)
    local batch = active_batches[player]
    if batch == nil then
        return
    end

    active_batches[player] = nil
    batch.registered = false
    CancelBatchTasks(batch)

    local action = batch.action
    batch.action = nil
    local player_valid = player ~= nil and player:IsValid()
    local locomotor = player_valid
        and player.components ~= nil
        and player.components.locomotor
        or nil
    if action ~= nil
        and player_valid
        and player.bufferedaction == action
        and player.ClearBufferedAction ~= nil then
        player:ClearBufferedAction()
    end
    if action ~= nil
        and locomotor ~= nil
        and locomotor.bufferedaction == action then
        locomotor:Clear()
        locomotor:Stop()
    end

    SendResult(player, batch.request_id, reason)
    StopSchedulerIfIdle()
end

local function CheckBatchWatchdog(player, batch)
    if active_batches[player] ~= batch then
        CancelBatchTasks(batch)
        return
    end

    if not IsPlayerOperational(player) then
        FinishBatch(player, "player_unavailable")
        return
    end

    local now = GetTime()
    if now - batch.last_progress_time >= Shared.BATCH_STALL_TIMEOUT then
        FinishBatch(player, "batch_timeout")
        return
    end
    SendBatchHeartbeat(player, batch, now)
end

local function OnActionSucceeded(player, batch, action)
    if active_batches[player] ~= batch or batch.action ~= action then
        return
    end

    batch.action = nil
    if batch.stage ~= "planting" then
        FinishBatch(player, "deploy_failed")
    end
end

local function OnActionFailed(player, batch, action)
    if active_batches[player] ~= batch or batch.action ~= action then
        return
    end

    batch.action = nil
    local reason = batch.failure_reason
        or (action.reason ~= nil and "deploy_failed" or "action_interrupted")
    FinishBatch(player, reason)
end

StartBatchAction = function(player, batch)
    if active_batches[player] ~= batch or batch.stage ~= "preflight" then
        return
    end

    if batch_plant_action == nil then
        FinishBatch(player, "action_unavailable")
        return
    end

    if not IsPlayerReadyToStart(player) then
        FinishBatch(player, "player_unavailable")
        return
    end

    local source_item = GetBoundActiveItem(player, batch.source_item, batch.prefab)
    if source_item == nil then
        FinishBatch(player, "active_item_changed")
        return
    end

    batch.stage = "action"
    local action = BufferedAction(
        player,
        nil,
        batch_plant_action,
        source_item
    )
    action.validfn = function(buffered_action)
        return active_batches[player] == batch
            and batch.stage == "action"
            and batch.action == buffered_action
            and IsPlayerOperational(player)
            and GetBoundActiveItem(player, batch.source_item, batch.prefab) ~= nil
    end
    action:AddSuccessAction(function()
        OnActionSucceeded(player, batch, action)
    end)
    action:AddFailAction(function()
        OnActionFailed(player, batch, action)
    end)

    batch.action = action
    local valid, reason = action:TestForStart()
    if not valid then
        batch.action = nil
        FinishBatch(
            player,
            reason ~= nil and "deploy_failed" or "action_interrupted"
        )
        return
    end

    TouchBatch(player, batch)
    local player_controller = player.components.playercontroller
    if player_controller ~= nil then
        player_controller:RemotePausePrediction(
            Shared.BATCH_ACTION_DURATION_FRAMES
        )
    end
    player.components.locomotor:PushAction(action, true)
    local current_action = player.GetBufferedAction ~= nil
        and player:GetBufferedAction()
        or player.components.locomotor.bufferedaction
    if active_batches[player] == batch
        and batch.stage == "action"
        and batch.action == action
        and current_action ~= action then
        batch.action = nil
        FinishBatch(player, "action_interrupted")
    end
end

local function FinishPreflight(player, batch)
    batch.layout_points = nil

    if #batch.points <= 0 then
        FinishBatch(player, "no_plantable_positions")
        return
    end

    if CountDeployableItems(player, batch.prefab) <= 0 then
        FinishBatch(player, "no_inventory")
        return
    end

    StartBatchAction(player, batch)
end

ProcessPreflightSlice = function(player, batch, limit)
    if active_batches[player] ~= batch or batch.stage ~= "preflight" then
        return 0
    end

    if not IsPlayerReadyToStart(player) then
        FinishBatch(player, "player_unavailable")
        return 0
    end

    local item = GetBoundActiveItem(player, batch.source_item, batch.prefab)
    if item == nil then
        FinishBatch(player, "active_item_changed")
        return 0
    end

    local native_spacing = GetDeploySpacing(item)
    if native_spacing == nil
        or math.abs(native_spacing - batch.native_spacing)
            > Shared.LAYOUT_EPSILON then
        FinishBatch(player, "spacing_changed")
        return 0
    end

    local processed = 0
    while processed < limit do
        local point = batch.layout_points[batch.preflight_index]
        if point == nil then
            FinishPreflight(player, batch)
            return processed
        end

        if CanDeployItemAtPoint(item, player, point) then
            batch.points[#batch.points + 1] = point
        end

        batch.preflight_index = batch.preflight_index + 1
        processed = processed + 1
        TouchBatch(player, batch)
    end

    if batch.layout_points[batch.preflight_index] == nil then
        FinishPreflight(player, batch)
    end
    return processed
end

ProcessPlantingSlice = function(player, batch, limit)
    if active_batches[player] ~= batch or batch.stage ~= "planting" then
        return 0
    end

    if not IsPlayerOperational(player) then
        FinishBatch(player, "player_unavailable")
        return 0
    end

    if not IsPlayerNearPoint(
        player,
        batch.action_x,
        batch.action_z,
        Shared.BATCH_LEASH_DISTANCE
    ) then
        FinishBatch(player, "moved_away")
        return 0
    end

    local processed = 0
    while processed < limit do
        if batch.remaining_plants <= 0 then
            FinishBatch(player, "success")
            return processed
        end

        local point = batch.points[batch.next_index]
        if point == nil then
            FinishBatch(player, "success")
            return processed
        end

        local item = FindDeployableItem(player, batch.prefab, batch.source_item)
        if item == nil then
            FinishBatch(player, "no_inventory")
            return processed
        end

        local native_spacing = GetDeploySpacing(item)
        if native_spacing == nil
            or math.abs(native_spacing - batch.native_spacing)
                > Shared.LAYOUT_EPSILON then
            FinishBatch(player, "spacing_changed")
            return processed
        end

        local success, reason = DeployOne(player, batch, point)
        if not success and reason ~= "blocked" then
            FinishBatch(player, reason or "deploy_failed")
            return processed
        end
        if success then
            batch.remaining_plants = batch.remaining_plants - 1
        end

        batch.next_index = batch.next_index + 1
        processed = processed + 1
        TouchBatch(player, batch)
    end

    if batch.remaining_plants <= 0
        or batch.next_index > #batch.points then
        FinishBatch(player, "success")
    end
    return processed
end

local function CompactBatchQueue()
    local compacted = {}
    for _, batch in ipairs(batch_queue) do
        if batch.registered
            and active_batches[batch.player] == batch then
            compacted[#compacted + 1] = batch
        end
    end

    batch_queue = compacted
    if scheduler_cursor > #batch_queue then
        scheduler_cursor = 1
    end
end

local function RunBatchSlice(processor, player, batch, limit)
    local ok, used = pcall(processor, player, batch, limit)
    if not ok then
        Log:Error("batch scheduler failed: %s", tostring(used))
        FinishBatch(player, "internal_error")
        return 0
    end
    return tonumber(used) or 0
end

RunScheduler = function()
    CompactBatchQueue()
    if #batch_queue == 0 then
        StopSchedulerIfIdle()
        return
    end

    local preflight_budget = Shared.GLOBAL_PREFLIGHT_POINTS_PER_TICK
    local planting_budget = Shared.GLOBAL_PLANTS_PER_TICK
    local consecutive_idle = 0

    while (preflight_budget > 0 or planting_budget > 0)
        and consecutive_idle < #batch_queue do
        if scheduler_cursor > #batch_queue then
            scheduler_cursor = 1
        end

        local batch = batch_queue[scheduler_cursor]
        scheduler_cursor = scheduler_cursor + 1
        local player = batch.player
        local previous_stage = batch.stage
        local was_active = active_batches[player] == batch
        local used = 0

        if was_active and not IsPlayerOperational(player) then
            FinishBatch(player, "player_unavailable")
        elseif was_active
            and batch.stage == "preflight"
            and preflight_budget > 0 then
            local allowance = math.min(
                preflight_budget,
                Shared.PREFLIGHT_POINTS_PER_BATCH_TURN
            )
            used = RunBatchSlice(
                ProcessPreflightSlice,
                player,
                batch,
                allowance
            )
            preflight_budget = preflight_budget - used
        elseif was_active
            and batch.stage == "planting"
            and planting_budget > 0 then
            local allowance = math.min(
                planting_budget,
                Shared.PLANTS_PER_BATCH_TURN
            )
            used = RunBatchSlice(
                ProcessPlantingSlice,
                player,
                batch,
                allowance
            )
            planting_budget = planting_budget - used
        end

        local progressed = used > 0
            or active_batches[player] ~= batch
            or batch.stage ~= previous_stage
        if progressed then
            consecutive_idle = 0
        else
            consecutive_idle = consecutive_idle + 1
        end
    end

    CompactBatchQueue()
    StopSchedulerIfIdle()
end

local function EnsureScheduler()
    if scheduler_task == nil and TheWorld ~= nil and TheWorld.ismastersim then
        scheduler_task = TheWorld:DoPeriodicTask(FRAMES, RunScheduler)
    end
end

local function RegisterBatch(player, batch)
    batch.player = player
    batch.registered = true
    batch.last_progress_time = GetTime()
    batch.last_client_heartbeat_time = batch.last_progress_time
    batch.client_started = false
    batch_queue[#batch_queue + 1] = batch
    batch.watchdog_task = player:DoPeriodicTask(
        Shared.BATCH_WATCHDOG_INTERVAL,
        CheckBatchWatchdog,
        Shared.BATCH_WATCHDOG_INTERVAL,
        batch
    )
    EnsureScheduler()
end

local function RejectPreparedRequest(player, request, reason)
    SendResult(player, request ~= nil and request.request_id or 0, reason)
end

function M.HandlePlantRequest(
    player,
    request_id,
    x,
    z,
    rows,
    columns,
    prefab,
    plant_spacing
)
    if not IsPlayerReadyToStart(player) then
        SendResult(player, request_id, "player_unavailable")
        return
    end

    if not Shared.IsValidRequestId(request_id) then
        SendResult(player, request_id, "invalid_request")
        return
    end

    local now = GetTime()
    local last_request = last_requests[player] or -math.huge
    if now - last_request < Shared.REQUEST_COOLDOWN then
        SendResult(player, request_id, "rate_limited")
        return
    end
    last_requests[player] = now

    if not Shared.IsFiniteCoordinate(x)
        or not Shared.IsFiniteCoordinate(z)
        or not Shared.IsValidDimension(rows)
        or not Shared.IsValidDimension(columns)
        or not Shared.IsValidPlantSpacingSetting(plant_spacing) then
        SendResult(player, request_id, "invalid_request")
        return
    end

    if not Shared.IsValidBatchSize(rows, columns) then
        SendResult(player, request_id, "too_many_plants")
        return
    end

    if active_batches[player] ~= nil then
        SendResult(player, request_id, "busy")
        return
    end

    if Shared.GetPlant(prefab) == nil then
        SendResult(player, request_id, "unsupported")
        return
    end

    local inventory = player.components.inventory
    local item = inventory:GetActiveItem()
    if not IsMatchingDeployable(item, prefab) then
        SendResult(player, request_id, "active_item_changed")
        return
    end

    local native_spacing = GetDeploySpacing(item)
    if native_spacing == nil then
        SendResult(player, request_id, "not_deployable")
        return
    end

    plant_spacing = Shared.NormalizePlantSpacingSetting(plant_spacing)
    local spacing = Shared.ResolvePlantSpacing(
        plant_spacing,
        native_spacing
    )
    if spacing == nil then
        SendResult(player, request_id, "invalid_request")
        return
    end

    if not Shared.IsValidLayoutFootprint(rows, columns, spacing) then
        SendResult(player, request_id, "layout_too_large")
        return
    end

    local layout = Layout.Build(
        tonumber(x),
        tonumber(z),
        tonumber(rows),
        tonumber(columns),
        spacing
    )
    if layout == nil then
        SendResult(player, request_id, "invalid_ground")
        return
    end

    if #layout.points > Shared.MAX_PLANTS_PER_BATCH then
        SendResult(player, request_id, "too_many_plants")
        return
    end

    local planning_x = layout.anchor_x + Shared.TILE_SIZE * 0.5
    local planning_z = layout.anchor_z + Shared.TILE_SIZE * 0.5
    if not IsPlayerNearPoint(
        player,
        planning_x,
        planning_z,
        Shared.MAX_REQUEST_DISTANCE
    ) then
        SendResult(player, request_id, "too_far")
        return
    end

    pending_requests[player] = {
        request_id = tonumber(request_id),
        prefab = prefab,
        spacing = spacing,
        native_spacing = native_spacing,
        rows = tonumber(rows),
        columns = tonumber(columns),
        anchor_x = layout.anchor_x,
        anchor_z = layout.anchor_z,
        expires_at = now + Shared.REQUEST_TIMEOUT,
    }
end

function M.BeginPlantRequest(action)
    if TheWorld == nil or not TheWorld.ismastersim or action == nil then
        return false
    end

    local player = action.doer
    local request = pending_requests[player]
    pending_requests[player] = nil
    if request == nil then
        return false
    end

    if not IsPlayerOperational(player) then
        RejectPreparedRequest(player, request, "player_unavailable")
        return false
    end

    if GetTime() > request.expires_at then
        RejectPreparedRequest(player, request, "request_expired")
        return false
    end

    if active_batches[player] ~= nil then
        RejectPreparedRequest(player, request, "busy")
        return false
    end

    local action_x, action_z = ResolveActionPoint(action)
    if not Shared.IsFiniteCoordinate(action_x)
        or not Shared.IsFiniteCoordinate(action_z)
        or not IsPlayerNearPoint(
            player,
            action_x,
            action_z,
            Shared.ACTION_EXECUTION_DISTANCE
        ) then
        RejectPreparedRequest(player, request, "not_at_target")
        return false
    end

    local source_item = GetBoundActiveItem(
        player,
        action.invobject,
        request.prefab
    )
    if source_item == nil then
        RejectPreparedRequest(player, request, "active_item_changed")
        return false
    end

    local native_spacing = GetDeploySpacing(source_item)
    if native_spacing == nil
        or math.abs(native_spacing - request.native_spacing)
            > Shared.LAYOUT_EPSILON then
        RejectPreparedRequest(player, request, "spacing_changed")
        return false
    end

    local layout = Layout.Build(
        action_x,
        action_z,
        request.rows,
        request.columns,
        request.spacing
    )
    if layout == nil
        or math.abs(layout.anchor_x - request.anchor_x) > Shared.LAYOUT_EPSILON
        or math.abs(layout.anchor_z - request.anchor_z) > Shared.LAYOUT_EPSILON then
        RejectPreparedRequest(player, request, "target_changed")
        return false
    end

    local batch = {
        request_id = request.request_id,
        prefab = request.prefab,
        source_item = source_item,
        native_spacing = native_spacing,
        layout_points = Layout.BuildTraversalOrder(layout),
        points = {},
        stage = "preflight",
        preflight_index = 1,
        next_index = 1,
        action_x = action_x,
        action_z = action_z,
        action = nil,
        watchdog_task = nil,
        failure_reason = nil,
        registered = false,
    }
    active_batches[player] = batch
    local registered, register_error = pcall(RegisterBatch, player, batch)
    if not registered then
        Log:Error(
            "batch registration failed: %s",
            tostring(register_error)
        )
        FinishBatch(player, "internal_error")
        return false
    end
    batch.client_started = true
    SendResult(player, batch.request_id, "started")
    return true
end

function M.ExecuteBatchAction(action)
    if TheWorld == nil or not TheWorld.ismastersim or action == nil then
        return false
    end

    local player = action.doer
    local batch = active_batches[player]
    if batch == nil
        or batch.stage ~= "action"
        or batch.action ~= action then
        return false
    end

    if not IsPlayerOperational(player) then
        batch.failure_reason = "player_unavailable"
        return false
    end

    if not IsPlayerNearPoint(
        player,
        batch.action_x,
        batch.action_z,
        Shared.ACTION_EXECUTION_DISTANCE
    ) then
        batch.failure_reason = "not_at_target"
        return false
    end

    local source_item = GetBoundActiveItem(
        player,
        batch.source_item,
        batch.prefab
    )
    if source_item == nil or action.invobject ~= source_item then
        batch.failure_reason = "active_item_changed"
        return false
    end

    local native_spacing = GetDeploySpacing(source_item)
    if native_spacing == nil
        or math.abs(native_spacing - batch.native_spacing)
            > Shared.LAYOUT_EPSILON then
        batch.failure_reason = "spacing_changed"
        return false
    end

    local available = CountDeployableItems(player, batch.prefab)
    if available <= 0 then
        batch.failure_reason = "no_inventory"
        return false
    end

    batch.remaining_plants = math.min(#batch.points, available)
    batch.stage = "planting"
    batch.next_index = 1
    TouchBatch(player, batch)
    return true
end

function M.SetBatchAction(action)
    batch_plant_action = action
end

function M.HasActiveBatch(player)
    return active_batches[player] ~= nil
end

return M
