local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local Common = require("mosswork/planting_assistant/server_common")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}

local active_batches = setmetatable({}, { __mode = "k" })
local batch_queue = {}
local scheduler_cursor = 1
local scheduler_task = nil
local batch_plant_action = nil

local FinishBatch
local StartBatchAction
local ProcessPreflightSlice
local ProcessPlantingSlice
local RunScheduler

local function GetPlantableFailureReason(
    fallback,
    callback_scope
)
    return Common.GetCallbackFailure(callback_scope) or fallback
end

local function HasSchedulerTime(started_at)
    return started_at == nil
        or type(GetTimeReal) ~= "function"
        or GetTimeReal() - started_at
            < Shared.SCHEDULER_TIME_BUDGET_MS
end

local function SendBatchHeartbeat(player, batch, now)
    now = now or GetTime()
    if batch.client_started
        and now - batch.last_client_heartbeat_time
            >= Shared.BATCH_HEARTBEAT_INTERVAL then
        batch.last_client_heartbeat_time = now
        Common.SendResult(player, batch.request_id, "progress")
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

local function GetActiveBatchCount()
    local count = 0
    for _ in pairs(active_batches) do
        count = count + 1
    end
    return count
end

local function HasAnyActiveBatch()
    return GetActiveBatchCount() > 0
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

    local log_message =
        "batch finished player=%s request=%s reason=%s"
        .. " planted=%d preflight_blocked=%d runtime_blocked=%d"
        .. " candidates=%d"
    local write_log
    if reason == "success" then
        write_log = Log.Debug
    elseif reason == "internal_error"
        or reason == "batch_timeout"
        or reason == "deploy_failed"
        or reason == "remove_failed"
        or reason == "rollback_failed"
        or reason == "deploy_state_unknown"
        or reason == "plantable_unavailable"
        or reason == "action_unavailable" then
        write_log = Log.Warn
    else
        write_log = Log.Info
    end
    write_log(
        Log,
        log_message,
        Common.GetPlayerLogId(player),
        batch.request_id,
        reason,
        batch.planted_count or 0,
        batch.preflight_blocked_count or 0,
        batch.runtime_blocked_count or 0,
        batch.candidate_count or 0
    )

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

    Common.SendResult(player, batch.request_id, reason)
    StopSchedulerIfIdle()
end

local function CheckBatchWatchdog(player, batch)
    if active_batches[player] ~= batch then
        CancelBatchTasks(batch)
        return
    end

    if not Common.IsPlayerOperational(player) then
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

    if not Common.IsPlayerReadyToStart(player) then
        FinishBatch(player, "player_unavailable")
        return
    end

    local source_item, source_reason = Common.GetBoundActiveItem(
        player,
        batch.source_item,
        batch.prefab
    )
    if source_item == nil then
        FinishBatch(
            player,
            GetPlantableFailureReason(
                source_reason or "active_item_changed",
                batch.callback_scope
            )
        )
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
        if active_batches[player] ~= batch
            or batch.stage ~= "action"
            or batch.action ~= buffered_action
            or not Common.IsPlayerOperational(player) then
            return false
        end
        local current_item, current_reason = Common.GetBoundActiveItem(
            player,
            batch.source_item,
            batch.prefab
        )
        if current_item == nil then
            batch.failure_reason = GetPlantableFailureReason(
                current_reason or "active_item_changed",
                batch.callback_scope
            )
            return false
        end
        return true
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

ProcessPreflightSlice = function(player, batch, limit)
    if active_batches[player] ~= batch or batch.stage ~= "preflight" then
        return 0
    end

    if not Common.IsPlayerReadyToStart(player) then
        FinishBatch(player, "player_unavailable")
        return 0
    end
    local item, item_reason = Common.GetBoundActiveItem(
        player,
        batch.source_item,
        batch.prefab
    )
    if item == nil then
        FinishBatch(
            player,
            GetPlantableFailureReason(
                item_reason or "active_item_changed",
                batch.callback_scope
            )
        )
        return 0
    end

    local plant_metadata, metadata_reason =
        Common.GetBatchPlantMetadata(batch, item)
    if plant_metadata == nil then
        FinishBatch(player, metadata_reason or "not_deployable")
        return 0
    end

    local processed = 0
    while processed < limit do
        local point = Layout.GetTraversalPoint(
            batch.layout,
            batch.scan_index
        )
        if point == nil then
            FinishBatch(player, "no_plantable_positions")
            return processed
        end
        batch.scan_index = batch.scan_index + 1

        local can_deploy, reason =
            Common.CanDeployItemAtPoint(
                plant_metadata,
                player,
                point,
                batch.callback_scope
            )
        processed = processed + 1
        if can_deploy then
            batch.pending_point = point
            TouchBatch(player, batch)
            StartBatchAction(player, batch)
            return processed
        elseif reason == "plantable_unavailable" then
            FinishBatch(player, reason)
            return processed
        else
            batch.preflight_blocked_count =
                batch.preflight_blocked_count + 1
        end

        TouchBatch(player, batch)
    end
    return processed
end

local function FinishCompletedPlanting(player, batch)
    local reason = "no_plantable_positions"
    if batch.planted_count > 0 then
        reason = "success"
    end
    FinishBatch(player, reason)
end

ProcessPlantingSlice = function(player, batch, limit)
    if active_batches[player] ~= batch or batch.stage ~= "planting" then
        return 0
    end

    if not Common.IsPlayerOperational(player) then
        FinishBatch(player, "player_unavailable")
        return 0
    end
    if not Common.IsPlayerNearPoint(
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
            FinishCompletedPlanting(player, batch)
            return processed
        end

        local point = batch.pending_point
        if point ~= nil then
            batch.pending_point = nil
        else
            point = Layout.GetTraversalPoint(
                batch.layout,
                batch.scan_index
            )
            batch.scan_index = batch.scan_index + 1
        end
        if point == nil then
            FinishCompletedPlanting(player, batch)
            return processed
        end

        local item, item_reason = Common.FindDeployableItem(
            player,
            batch.prefab,
            batch.source_item
        )
        if item == nil then
            FinishBatch(
                player,
                GetPlantableFailureReason(
                    item_reason or "no_inventory",
                    batch.callback_scope
                )
            )
            return processed
        end

        local plant_metadata, metadata_reason =
            Common.GetBatchPlantMetadata(batch, item)
        if plant_metadata == nil then
            FinishBatch(player, metadata_reason or "not_deployable")
            return processed
        end

        local success, reason, terminal_reason =
            Common.DeployOne(
                player,
                batch,
                point,
                item,
                plant_metadata
            )
        if not success and reason ~= "blocked" then
            FinishBatch(player, reason or "deploy_failed")
            return processed
        end
        if success then
            batch.remaining_plants = batch.remaining_plants - 1
            batch.planted_count = batch.planted_count + 1
        else
            batch.runtime_blocked_count =
                batch.runtime_blocked_count + 1
        end

        processed = processed + 1
        TouchBatch(player, batch)
        if terminal_reason ~= nil then
            FinishBatch(player, terminal_reason)
            return processed
        end
    end

    if batch.remaining_plants <= 0
        or (
            batch.pending_point == nil
            and batch.scan_index > batch.candidate_count
        ) then
        FinishCompletedPlanting(player, batch)
    end
    return processed
end

local function CompactBatchQueue()
    local write_index = 1
    local previous_count = #batch_queue
    for read_index = 1, previous_count do
        local batch = batch_queue[read_index]
        if batch.registered
            and active_batches[batch.player] == batch then
            batch_queue[write_index] = batch
            write_index = write_index + 1
        end
    end
    for index = previous_count, write_index, -1 do
        batch_queue[index] = nil
    end
    if scheduler_cursor > #batch_queue then
        scheduler_cursor = 1
    end
end

local function RunBatchSlice(processor, player, batch, limit)
    local ok, used = pcall(processor, player, batch, limit)
    if not ok then
        Log:Error("batch scheduler failed: %s", used)
        Common.ResetDeploymentCapture()
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
    local started_at = type(GetTimeReal) == "function"
        and GetTimeReal()
        or nil

    while (preflight_budget > 0 or planting_budget > 0)
        and consecutive_idle < #batch_queue
        and HasSchedulerTime(started_at) do
        if scheduler_cursor > #batch_queue then
            scheduler_cursor = 1
        end

        local batch = batch_queue[scheduler_cursor]
        scheduler_cursor = scheduler_cursor + 1
        local player = batch.player
        local previous_stage = batch.stage
        local was_active = active_batches[player] == batch
        local used = 0

        if was_active and not Common.IsPlayerOperational(player) then
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

function M.Start(player, batch)
    if active_batches[player] ~= nil then
        Common.RejectRequest(player, batch.request_id, "busy")
        return false
    end
    if GetActiveBatchCount() >= Shared.MAX_ACTIVE_BATCHES then
        Common.RejectRequest(player, batch.request_id, "server_busy")
        return false
    end

    active_batches[player] = batch
    local registered, register_error = pcall(RegisterBatch, player, batch)
    if not registered then
        Log:Error(
            "batch registration failed: %s",
            register_error
        )
        FinishBatch(player, "internal_error")
        return false
    end

    batch.client_started = true
    Common.SendResult(player, batch.request_id, "started")
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

    if not Common.IsPlayerOperational(player) then
        batch.failure_reason = "player_unavailable"
        return false
    end

    if not Common.IsPlayerNearPoint(
        player,
        batch.action_x,
        batch.action_z,
        Shared.ACTION_EXECUTION_DISTANCE
    ) then
        batch.failure_reason = "not_at_target"
        return false
    end

    local source_item, source_reason = Common.GetBoundActiveItem(
        player,
        batch.source_item,
        batch.prefab
    )
    if source_item == nil or action.invobject ~= source_item then
        batch.failure_reason = GetPlantableFailureReason(
            source_reason or "active_item_changed",
            batch.callback_scope
        )
        return false
    end

    local plant_metadata, metadata_reason =
        Common.GetBatchPlantMetadata(batch, source_item)
    if plant_metadata == nil then
        batch.failure_reason = metadata_reason or "not_deployable"
        return false
    end

    local available = Common.CountDeployableItems(player, batch.prefab)
    if available <= 0 then
        batch.failure_reason = GetPlantableFailureReason(
            "no_inventory",
            batch.callback_scope
        )
        return false
    end

    batch.remaining_plants = math.min(batch.candidate_count, available)
    batch.stage = "planting"
    TouchBatch(player, batch)
    return true
end

function M.SetBatchAction(action)
    batch_plant_action = action
end

function M.HasActiveBatch(player)
    return active_batches[player] ~= nil
end

function M.CanAcceptNewBatch(player)
    return active_batches[player] == nil
        and GetActiveBatchCount() < Shared.MAX_ACTIVE_BATCHES
end

return M
