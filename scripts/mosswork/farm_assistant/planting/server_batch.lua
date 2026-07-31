local Shared = require("mosswork/farm_assistant/planting/shared")
local Layout = require("mosswork/farm_assistant/planting/layout")
local Common = require("mosswork/farm_assistant/planting/server_common")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}

local active_batches = setmetatable({}, { __mode = "k" })
local batch_queue = {}
local scheduler_cursor = 1
local scheduler_task = nil

local RunScheduler
local FinishBatch
local QueueSequentialStep
local ScheduleSequentialStep

local function GetActiveBatchCount()
    local count = 0
    for _ in pairs(active_batches) do
        count = count + 1
    end
    return count
end

local function HasSchedulerTime(started_at)
    return started_at == nil
        or type(GetTimeReal) ~= "function"
        or GetTimeReal() - started_at
            < Shared.SCHEDULER_TIME_BUDGET_MS
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

local function StopSchedulerIfIdle()
    for _, batch in ipairs(batch_queue) do
        if batch.registered
            and active_batches[batch.player] == batch then
            return
        end
    end

    if scheduler_task ~= nil then
        scheduler_task:Cancel()
        scheduler_task = nil
    end
    batch_queue = {}
    scheduler_cursor = 1
end

FinishBatch = function(player, batch, reason)
    if active_batches[player] ~= batch then
        return
    end

    active_batches[player] = nil
    batch.registered = false
    if batch.next_task ~= nil then
        batch.next_task:Cancel()
        batch.next_task = nil
    end
    batch.current_action = nil
    batch.current_point = nil

    local message =
        "batch finished player=%s request=%s reason=%s"
        .. " planted=%d blocked=%d candidates=%d"
    if reason == "success" then
        Log:Debug(
            message,
            Common.GetPlayerLogId(player),
            batch.request_id,
            reason,
            batch.planted_count,
            batch.blocked_count,
            batch.layout.candidate_count
        )
    elseif reason == "no_plantable_positions"
        or reason == "no_inventory"
        or reason == "moved_away"
        or reason == "player_unavailable" then
        Log:Info(
            message,
            Common.GetPlayerLogId(player),
            batch.request_id,
            reason,
            batch.planted_count,
            batch.blocked_count,
            batch.layout.candidate_count
        )
    else
        Log:Warn(
            message,
            Common.GetPlayerLogId(player),
            batch.request_id,
            reason,
            batch.planted_count,
            batch.blocked_count,
            batch.layout.candidate_count
        )
    end

    Common.SendResult(player, batch.request_id, reason)
    StopSchedulerIfIdle()
end

local function FinishCompletedBatch(player, batch)
    FinishBatch(
        player,
        batch,
        batch.planted_count > 0
                and "success"
            or "no_plantable_positions"
    )
end

local function DeploySequentialPoint(
    player,
    batch,
    point,
    item,
    metadata
)
    local success, reason, terminal_reason = Common.DeployOne(
        player,
        batch,
        point,
        item,
        metadata
    )
    if success then
        batch.remaining_plants = batch.remaining_plants - 1
        batch.planted_count = batch.planted_count + 1
    elseif reason == "blocked" then
        batch.blocked_count = batch.blocked_count + 1
    end
    return success, reason, terminal_reason
end

local function OnSequentialActionFinished(
    player,
    batch,
    action,
    failed
)
    if active_batches[player] ~= batch
        or batch.current_action ~= action then
        return
    end

    batch.current_action = nil
    batch.current_point = nil
    if failed then
        local reason = action.mosswork_failure_reason
            or "action_interrupted"
        if reason ~= "blocked" then
            FinishBatch(player, batch, reason)
            return
        end
    end
    ScheduleSequentialStep(player, batch)
end

ScheduleSequentialStep = function(player, batch)
    if active_batches[player] ~= batch or batch.next_task ~= nil then
        return
    end

    batch.next_task = player:DoTaskInTime(0, function()
        batch.next_task = nil
        QueueSequentialStep(player, batch)
    end)
end

local function ProcessSequentialStep(player, batch)
    if active_batches[player] ~= batch or batch.current_action ~= nil then
        return
    end
    if not Common.IsPlayerOperational(player) then
        FinishBatch(player, batch, "player_unavailable")
        return
    end

    while batch.remaining_plants > 0
        and batch.scan_index <= batch.layout.candidate_count do
        local point = Layout.GetTraversalPoint(
            batch.layout,
            batch.scan_index
        )
        batch.scan_index = batch.scan_index + 1
        if point == nil then
            break
        end

        local item = Common.FindDeployableItem(
            player,
            batch.prefab,
            batch.source_item
        )
        if item == nil then
            FinishBatch(player, batch, "no_inventory")
            return
        end

        local metadata, metadata_reason =
            Common.GetBatchPlantMetadata(batch, item)
        if metadata == nil then
            FinishBatch(
                player,
                batch,
                metadata_reason or "not_deployable"
            )
            return
        end

        local can_deploy, can_deploy_reason =
            Common.CanDeployItemAtPoint(metadata, player, point)
        if not can_deploy then
            if can_deploy_reason == "blocked" then
                batch.blocked_count = batch.blocked_count + 1
            else
                FinishBatch(
                    player,
                    batch,
                    can_deploy_reason or "deploy_failed"
                )
                return
            end
        else
            local action_type = ACTIONS ~= nil
                and ACTIONS[Shared.ACTION_PLANT_ONE_ID]
                or nil
            if action_type == nil or BufferedAction == nil then
                FinishBatch(player, batch, "action_unavailable")
                return
            end

            batch.source_item = item
            local action = BufferedAction(
                player,
                nil,
                action_type,
                item,
                Vector3(point.x, 0, point.z)
            )
            action:AddSuccessAction(function()
                OnSequentialActionFinished(
                    player,
                    batch,
                    action,
                    false
                )
            end)
            action:AddFailAction(function()
                OnSequentialActionFinished(
                    player,
                    batch,
                    action,
                    true
                )
            end)

            batch.current_action = action
            batch.current_point = point
            local locomotor = player.components.locomotor
            local completed, failure = pcall(
                locomotor.PushAction,
                locomotor,
                action,
                true
            )
            if not completed then
                Log:Error(
                    "sequential action failed to start: %s",
                    tostring(failure)
                )
                batch.current_action = nil
                batch.current_point = nil
                FinishBatch(player, batch, "internal_error")
            elseif active_batches[player] == batch
                and batch.current_action == action
                and player:GetBufferedAction() ~= action then
                batch.current_action = nil
                batch.current_point = nil
                FinishBatch(player, batch, "action_interrupted")
            end
            return
        end
    end

    FinishCompletedBatch(player, batch)
end

QueueSequentialStep = function(player, batch)
    local completed, failure = pcall(
        ProcessSequentialStep,
        player,
        batch
    )
    if completed then
        return
    end

    Log:Error("sequential scheduler failed: %s", tostring(failure))
    FinishBatch(player, batch, "internal_error")
end

local function StartSequentialBatch(player, batch)
    local point = Layout.GetTraversalPoint(
        batch.layout,
        batch.scan_index
    )
    batch.scan_index = batch.scan_index + 1
    local item = Common.FindDeployableItem(
        player,
        batch.prefab,
        batch.source_item
    )
    if point == nil or item == nil then
        FinishBatch(
            player,
            batch,
            item == nil
                    and "no_inventory"
                or "not_deployable"
        )
        return false
    end

    local metadata, metadata_reason =
        Common.GetBatchPlantMetadata(batch, item)
    if metadata == nil then
        FinishBatch(
            player,
            batch,
            metadata_reason or "not_deployable"
        )
        return false
    end

    batch.source_item = item
    local success, reason, terminal_reason = DeploySequentialPoint(
        player,
        batch,
        point,
        item,
        metadata
    )
    if not success and reason ~= "blocked" then
        FinishBatch(
            player,
            batch,
            terminal_reason or reason or "deploy_failed"
        )
        return false
    end

    if batch.remaining_plants <= 0
        or batch.scan_index > batch.layout.candidate_count then
        FinishCompletedBatch(player, batch)
    else
        ScheduleSequentialStep(player, batch)
    end
    return true
end

local function PerformSequentialPlantAction(action)
    local player = action ~= nil and action.doer or nil
    local batch = player ~= nil and active_batches[player] or nil
    if batch == nil
        or batch.execution_mode ~= Shared.EXECUTION_MODE_SEQUENTIAL
        or batch.current_action ~= action then
        return false, "action_interrupted"
    end
    if not Common.IsPlayerOperational(player) then
        action.mosswork_failure_reason = "player_unavailable"
        return false, "player_unavailable"
    end

    local point = batch.current_point
    local action_x, action_z = Common.ResolveActionPoint(action)
    if point == nil
        or not Shared.IsFiniteCoordinate(action_x)
        or not Shared.IsFiniteCoordinate(action_z)
        or math.abs(point.x - action_x) > Shared.LAYOUT_EPSILON
        or math.abs(point.z - action_z) > Shared.LAYOUT_EPSILON
        or not Common.IsPlayerNearPoint(
            player,
            point.x,
            point.z,
            Shared.ACTION_EXECUTION_DISTANCE
        ) then
        action.mosswork_failure_reason = "not_at_target"
        return false, "not_at_target"
    end

    local item = action.invobject
    local metadata, metadata_reason =
        Common.GetBatchPlantMetadata(batch, item)
    if metadata == nil then
        local reason = metadata_reason or "not_deployable"
        action.mosswork_failure_reason = reason
        return false, reason
    end

    batch.source_item = item
    local success, reason, terminal_reason = DeploySequentialPoint(
        player,
        batch,
        point,
        item,
        metadata
    )
    if not success then
        action.mosswork_failure_reason =
            terminal_reason or reason or "deploy_failed"
    end
    return success, reason
end

function M.PerformSequentialPlantAction(action)
    if TheWorld == nil or not TheWorld.ismastersim then
        return false
    end

    local completed, success, reason = pcall(
        PerformSequentialPlantAction,
        action
    )
    if completed then
        return success, reason
    end

    Log:Error("sequential planting action failed: %s", tostring(success))
    if action ~= nil then
        action.mosswork_failure_reason = "internal_error"
    end
    return false, "internal_error"
end

local function ProcessBatchSlice(player, batch, limit)
    if active_batches[player] ~= batch then
        return 0
    end
    if not Common.IsPlayerOperational(player) then
        FinishBatch(player, batch, "player_unavailable")
        return 0
    end
    if not Common.IsPlayerNearPoint(
        player,
        batch.action_x,
        batch.action_z,
        Shared.BATCH_LEASH_DISTANCE
    ) then
        FinishBatch(player, batch, "moved_away")
        return 0
    end

    local processed = 0
    while processed < limit do
        if batch.remaining_plants <= 0
            or batch.scan_index > batch.layout.candidate_count then
            FinishCompletedBatch(player, batch)
            return processed
        end

        local point = Layout.GetTraversalPoint(
            batch.layout,
            batch.scan_index
        )
        batch.scan_index = batch.scan_index + 1
        if point == nil then
            FinishCompletedBatch(player, batch)
            return processed
        end

        local item = Common.FindDeployableItem(
            player,
            batch.prefab,
            batch.source_item
        )
        if item == nil then
            FinishBatch(player, batch, "no_inventory")
            return processed
        end

        local metadata, metadata_reason =
            Common.GetBatchPlantMetadata(batch, item)
        if metadata == nil then
            FinishBatch(
                player,
                batch,
                metadata_reason or "not_deployable"
            )
            return processed
        end

        batch.source_item = item
        local success, reason, terminal_reason = Common.DeployOne(
            player,
            batch,
            point,
            item,
            metadata
        )
        processed = processed + 1

        if success then
            batch.remaining_plants = batch.remaining_plants - 1
            batch.planted_count = batch.planted_count + 1
        elseif reason == "blocked" then
            batch.blocked_count = batch.blocked_count + 1
        else
            FinishBatch(
                player,
                batch,
                terminal_reason or reason or "deploy_failed"
            )
            return processed
        end
    end

    if batch.remaining_plants <= 0
        or batch.scan_index > batch.layout.candidate_count then
        FinishCompletedBatch(player, batch)
    end
    return processed
end

local function RunBatchSlice(player, batch, limit)
    local completed, used = pcall(
        ProcessBatchSlice,
        player,
        batch,
        limit
    )
    if not completed then
        Log:Error("batch scheduler failed: %s", tostring(used))
        FinishBatch(player, batch, "internal_error")
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

    local budget = Shared.GLOBAL_PLANTS_PER_TICK
    local consecutive_idle = 0
    local started_at = type(GetTimeReal) == "function"
        and GetTimeReal()
        or nil

    while budget > 0
        and consecutive_idle < #batch_queue
        and HasSchedulerTime(started_at) do
        if scheduler_cursor > #batch_queue then
            scheduler_cursor = 1
        end

        local batch = batch_queue[scheduler_cursor]
        scheduler_cursor = scheduler_cursor + 1
        local player = batch.player
        local was_active = active_batches[player] == batch
        local used = 0

        if was_active then
            used = RunBatchSlice(
                player,
                batch,
                math.min(budget, Shared.PLANTS_PER_BATCH_TURN)
            )
            budget = budget - used
        end

        if used > 0 or active_batches[player] ~= batch then
            consecutive_idle = 0
        else
            consecutive_idle = consecutive_idle + 1
        end
    end

    CompactBatchQueue()
    StopSchedulerIfIdle()
end

local function RunSchedulerSafely()
    local completed, failure = pcall(RunScheduler)
    if completed then
        return
    end

    Log:Error("batch scheduler crashed: %s", tostring(failure))
    local failed_batches = {}
    for player, batch in pairs(active_batches) do
        if batch.execution_mode ~= Shared.EXECUTION_MODE_SEQUENTIAL then
            failed_batches[#failed_batches + 1] = {
                player = player,
                batch = batch,
            }
        end
    end
    for _, entry in ipairs(failed_batches) do
        FinishBatch(entry.player, entry.batch, "internal_error")
    end
end

local function EnsureScheduler()
    if scheduler_task == nil
        and TheWorld ~= nil
        and TheWorld.ismastersim then
        scheduler_task = TheWorld:DoPeriodicTask(
            FRAMES,
            RunSchedulerSafely
        )
    end
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

    batch.player = player
    batch.registered = true
    active_batches[player] = batch
    Common.SendResult(player, batch.request_id, "started")

    if batch.execution_mode == Shared.EXECUTION_MODE_SEQUENTIAL then
        local completed, started = pcall(
            StartSequentialBatch,
            player,
            batch
        )
        if not completed then
            Log:Error(
                "sequential batch failed to start: %s",
                tostring(started)
            )
            FinishBatch(player, batch, "internal_error")
            return false
        end
        return started == true
    end

    batch_queue[#batch_queue + 1] = batch
    EnsureScheduler()
    return true
end

function M.HasActiveBatch(player)
    return active_batches[player] ~= nil
end

function M.CanAcceptNewBatch(player)
    return active_batches[player] == nil
        and GetActiveBatchCount() < Shared.MAX_ACTIVE_BATCHES
end

return M
