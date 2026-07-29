local Shared = require("mosswork/planting_assistant/shared")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}
local rejection_log_state = setmetatable({}, { __mode = "k" })
local slow_callback_log_state = {}

local REQUEST_WARNING_REASONS = {
    invalid_request = true,
    layout_too_large = true,
    not_deployable = true,
    invalid_ground = true,
}

local function GetPlayerController(player)
    return player ~= nil
        and player.components ~= nil
        and player.components.playercontroller
        or nil
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

local function StackSize(item)
    if item ~= nil and item.components ~= nil and item.components.stackable ~= nil then
        return item.components.stackable:StackSize()
    end
    return item ~= nil and 1 or 0
end

local function IsItemHeldByPlayer(item, player)
    local inventory_item = item ~= nil
        and item:IsValid()
        and item.components ~= nil
        and item.components.inventoryitem
        or nil
    return inventory_item ~= nil and inventory_item:GetGrandOwner() == player
end

local function SafeToString(value)
    local value_type = type(value)
    if value_type == "string"
        or value_type == "number"
        or value_type == "boolean"
        or value_type == "nil" then
        return tostring(value)
    end
    return "<" .. value_type .. ">"
end

local function GetRealTimeMilliseconds()
    return type(GetTimeReal) == "function" and GetTimeReal() or nil
end

local function ElapsedMilliseconds(started_at)
    local finished_at = GetRealTimeMilliseconds()
    return started_at ~= nil
            and finished_at ~= nil
            and finished_at >= started_at
            and finished_at - started_at
        or 0
end

local function RecordCallbackFault(callback_name, callback_scope)
    if callback_scope == nil then
        return
    end
    callback_scope.failed_callbacks[callback_name] = true
    callback_scope.failure_reason = "plantable_unavailable"
end

local function WarnSlowCallback(
    prefab,
    callback_name,
    elapsed_ms
)
    local key = tostring(prefab) .. ":" .. tostring(callback_name)
    local now = GetTime()
    local last_logged_at = slow_callback_log_state[key] or -math.huge
    if now - last_logged_at < Shared.REJECTION_LOG_REPEAT_INTERVAL then
        return
    end
    slow_callback_log_state[key] = now
    Log:Warn(
        "slow plantable callback prefab=%s callback=%s"
            .. " elapsed_ms=%.2f; result accepted",
        tostring(prefab),
        tostring(callback_name),
        tonumber(elapsed_ms) or 0
    )
end

local function RunPlantableCallback(
    prefab,
    callback_name,
    callback_scope,
    callback,
    ...
)
    if callback_scope ~= nil
        and callback_scope.failed_callbacks[callback_name] then
        return false, nil, "plantable_unavailable", "request_isolated"
    end

    local is_deploy = callback_name == "Deploy"
    local started_at = GetRealTimeMilliseconds()
    local completed, result = pcall(callback, ...)
    local elapsed_ms = ElapsedMilliseconds(started_at)
    if not completed then
        Log:Error(
            "plantable callback failed prefab=%s callback=%s"
                .. " error=%s",
            tostring(prefab),
            tostring(callback_name),
            SafeToString(result)
        )
        RecordCallbackFault(callback_name, callback_scope)
        return false, nil, "plantable_unavailable", "error"
    end

    local slow_threshold = is_deploy
            and Shared.DEPLOY_CALLBACK_SLOW_THRESHOLD_MS
        or Shared.PLANT_QUERY_CALLBACK_SLOW_THRESHOLD_MS
    if elapsed_ms >= slow_threshold then
        WarnSlowCallback(prefab, callback_name, elapsed_ms)
    end
    return true, result, nil, nil
end

function M.SendResult(player, request_id, reason)
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

function M.GetPlayerLogId(player)
    if player == nil then
        return "unknown"
    end
    return player.userid or player.name or player.prefab or "unknown"
end

function M.CreateCallbackScope()
    return {
        failed_callbacks = {},
        failure_reason = nil,
    }
end

function M.GetCallbackFailure(callback_scope)
    return callback_scope ~= nil and callback_scope.failure_reason or nil
end

function M.RejectRequest(player, request_id, reason, log_level)
    local now = GetTime()
    local previous = player ~= nil and rejection_log_state[player] or nil
    local should_log = previous == nil
        or previous.reason ~= reason
        or now - previous.time >= Shared.REJECTION_LOG_REPEAT_INTERVAL
    if should_log then
        if player ~= nil then
            rejection_log_state[player] = {
                reason = reason,
                time = now,
            }
        end
        if log_level == "debug" or reason == "rate_limited" then
            Log:Debug(
                "request rejected player=%s request=%s reason=%s",
                M.GetPlayerLogId(player),
                request_id,
                reason
            )
        elseif REQUEST_WARNING_REASONS[reason] then
            Log:Warn(
                "request rejected player=%s request=%s reason=%s",
                M.GetPlayerLogId(player),
                request_id,
                reason
            )
        else
            Log:Info(
                "request rejected player=%s request=%s reason=%s",
                M.GetPlayerLogId(player),
                request_id,
                reason
            )
        end
    end
    M.SendResult(player, request_id, reason)
end

function M.IsPlayerOperational(player)
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

function M.IsPlayerReadyToStart(player)
    return M.IsPlayerOperational(player) and not IsPlayerBusy(player)
end

function M.IsPlayerNearPoint(player, x, z, distance)
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

function M.ResolveActionPoint(action)
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

function M.IsMatchingDeployable(item, prefab)
    if item == nil
        or not item:IsValid()
        or item.prefab ~= prefab
        or item.components == nil
        or item.components.inventoryitem == nil then
        return false, "not_deployable"
    end

    local deployable = item.components.deployable
    if deployable == nil
        or type(deployable.GetDeployMode) ~= "function"
        or type(deployable.DeploySpacingRadius) ~= "function"
        or type(deployable.CanDeploy) ~= "function"
        or type(deployable.Deploy) ~= "function" then
        return false, "not_deployable"
    end
    return true, nil
end

function M.GetPlantMetadata(item, callback_scope, cached_metadata)
    local deployable = item ~= nil
        and item:IsValid()
        and item.components ~= nil
        and item.components.deployable
        or nil
    if cached_metadata ~= nil
        and cached_metadata.item == item
        and cached_metadata.deployable == deployable
        and Shared.IsValidSpacing(cached_metadata.native_spacing) then
        return cached_metadata, nil
    end

    local matches, match_reason = M.IsMatchingDeployable(
        item,
        item ~= nil and item.prefab or nil
    )
    if not matches then
        return nil, match_reason
    end

    deployable = item.components.deployable

    local callback_ok, deploy_mode, reason = RunPlantableCallback(
        item.prefab,
        "GetDeployMode",
        callback_scope,
        deployable.GetDeployMode,
        deployable
    )
    if not callback_ok then
        return nil, reason
    end
    if deploy_mode ~= DEPLOYMODE.PLANT then
        return nil, "not_deployable"
    end

    local spacing_ok, native_spacing, spacing_reason =
        RunPlantableCallback(
            item.prefab,
            "DeploySpacingRadius",
            callback_scope,
            deployable.DeploySpacingRadius,
            deployable
        )
    if not spacing_ok then
        return nil, spacing_reason
    end
    if not Shared.IsValidSpacing(native_spacing) then
        return nil, "not_deployable"
    end

    return {
        item = item,
        deployable = deployable,
        native_spacing = native_spacing,
    }, nil
end

function M.GetBatchPlantMetadata(batch, item)
    local metadata, reason = M.GetPlantMetadata(
        item,
        batch.callback_scope,
        batch.plant_metadata
    )
    if metadata == nil then
        return nil, reason
    end
    if math.abs(metadata.native_spacing - batch.native_spacing)
        > Shared.LAYOUT_EPSILON then
        return nil, "spacing_changed"
    end

    batch.plant_metadata = metadata
    return metadata, nil
end

function M.GetBoundActiveItem(player, item, prefab)
    local inventory = player ~= nil
        and player.components ~= nil
        and player.components.inventory
        or nil
    if inventory == nil or inventory:GetActiveItem() ~= item then
        return nil
    end

    local matches, reason = M.IsMatchingDeployable(item, prefab)
    return matches and item or nil, reason
end

function M.FindDeployableItem(player, prefab, preferred_item)
    local preferred_matches = M.IsMatchingDeployable(
        preferred_item,
        prefab
    )
    if preferred_matches and IsItemHeldByPlayer(preferred_item, player) then
        return preferred_item, nil
    end

    local item = player.components.inventory:FindItem(function(candidate)
        local matches = M.IsMatchingDeployable(candidate, prefab)
        return matches and IsItemHeldByPlayer(candidate, player)
    end)
    return item, nil
end

function M.CountDeployableItems(player, prefab)
    local inventory = player.components.inventory
    local total = 0
    local seen = {}
    local function CountItem(item)
        if item == nil or seen[item] then
            return
        end

        local matches = M.IsMatchingDeployable(item, prefab)
        if not matches or not IsItemHeldByPlayer(item, player) then
            return
        end
        seen[item] = true
        total = total + StackSize(item)
    end

    CountItem(inventory:GetActiveItem())
    local items = inventory:FindItems(function(item)
        return item ~= nil and item.prefab == prefab
    end)

    for _, item in ipairs(items) do
        CountItem(item)
    end

    return total
end

function M.CanDeployItemAtPoint(
    metadata,
    player,
    point,
    callback_scope
)
    local item = metadata ~= nil and metadata.item or nil
    local deployable = metadata ~= nil and metadata.deployable or nil
    if item == nil
        or not item:IsValid()
        or deployable == nil
        or item.components == nil
        or item.components.deployable ~= deployable then
        return false, "not_deployable"
    end

    local callback_ok, can_deploy, reason = RunPlantableCallback(
        item.prefab,
        "CanDeploy",
        callback_scope,
        deployable.CanDeploy,
        deployable,
        Vector3(point.x, 0, point.z),
        nil,
        player,
        0
    )
    if not callback_ok then
        return false, reason
    end
    return can_deploy == true, can_deploy == true and nil or "blocked"
end

local function TryGiveItem(
    player,
    container,
    item,
    slot
)
    if container == nil or container.GiveItem == nil then
        return false
    end
    if container.inst ~= nil and not container.inst:IsValid() then
        return false
    end

    local completed, failure = pcall(
        container.GiveItem,
        container,
        item,
        slot
    )
    if not completed then
        Log:Warn(
            "deploy return GiveItem failed prefab=%s error=%s",
            tostring(item.prefab),
            SafeToString(failure)
        )
    end
    return not item:IsValid() or IsItemHeldByPlayer(item, player)
end

local function ReturnRemovedItem(
    player,
    inventory,
    item,
    previous_container,
    previous_slot
)
    if item == nil or not item:IsValid() then
        return false
    end
    if IsItemHeldByPlayer(item, player) then
        return true
    end

    if TryGiveItem(
        player,
        previous_container,
        item,
        previous_slot
    ) or TryGiveItem(player, inventory, item, previous_slot) then
        return true
    end

    if not item:IsValid() then
        return true
    end

    local x, y, z = player.Transform:GetWorldPosition()
    if item.ReturnToScene ~= nil then
        local completed, failure = pcall(
            item.ReturnToScene,
            item
        )
        if not completed then
            Log:Error(
                "deploy return ReturnToScene failed prefab=%s error=%s",
                tostring(item.prefab),
                SafeToString(failure)
            )
        end
    end
    if not item:IsValid() then
        return false
    end
    item.Transform:SetPosition(x, y, z)
    local inventory_item = item.components ~= nil
        and item.components.inventoryitem
        or nil
    if inventory_item ~= nil and inventory_item.OnDropped ~= nil then
        local completed, failure = pcall(
            inventory_item.OnDropped,
            inventory_item,
            true
        )
        if not completed then
            Log:Warn(
                "deploy return OnDropped failed prefab=%s error=%s",
                tostring(item.prefab),
                SafeToString(failure)
            )
        end
    end
    if item:IsValid() and not IsItemHeldByPlayer(item, player) then
        Log:Warn(
            "failed deploy dropped item at player prefab=%s player=%s",
            tostring(item.prefab),
            M.GetPlayerLogId(player)
        )
        return true
    end

    Log:Error(
        "failed deploy could not return item prefab=%s player=%s",
        tostring(item.prefab),
        M.GetPlayerLogId(player)
    )
    return false
end

local function ConsumeDetachedItem(item)
    if item == nil or not item:IsValid() then
        return true
    end
    local prefab = item.prefab
    local completed, failure = pcall(
        item.Remove,
        item
    )
    if not completed then
        Log:Error(
            "deploy transaction Remove failed prefab=%s error=%s",
            tostring(prefab),
            SafeToString(failure)
        )
    end
    return not item:IsValid()
end

local function ResolveFailedDeploy(
    player,
    inventory,
    item,
    previous_container,
    previous_slot,
    failure_reason
)
    if item ~= nil and item:IsValid() then
        if ReturnRemovedItem(
            player,
            inventory,
            item,
            previous_container,
            previous_slot
        ) then
            return false, failure_reason
        end
        return false, "rollback_failed"
    end

    Log:Error(
        "deploy state unknown after item became invalid"
            .. " prefab=%s player=%s reason=%s; batch stopped",
        item ~= nil and tostring(item.prefab) or "unknown",
        M.GetPlayerLogId(player),
        tostring(failure_reason)
    )
    return false, "deploy_state_unknown"
end

function M.DeployOne(player, batch, point, item, metadata)
    local inventory = player.components.inventory
    if item == nil
        or not item:IsValid()
        or item.prefab ~= batch.prefab
        or not IsItemHeldByPlayer(item, player)
        or metadata == nil
        or metadata.item ~= item
        or metadata.deployable ~= item.components.deployable then
        return false, "no_inventory"
    end

    local can_deploy, deploy_reason =
        M.CanDeployItemAtPoint(
            metadata,
            player,
            point,
            batch.callback_scope
        )
    if not can_deploy then
        return false, deploy_reason or "blocked"
    end

    local deployable = metadata.deployable
    local deploy_point = Vector3(point.x, 0, point.z)
    if deployable.keep_in_inventory_on_deploy then
        local inventory_item = item.components.inventoryitem
        local previous_container = inventory_item:GetContainer()
        local previous_slot = inventory_item:GetSlotNum()

        local callback_ok, success, reason =
            RunPlantableCallback(
            item.prefab,
            "Deploy",
            batch.callback_scope,
            deployable.Deploy,
            deployable,
            deploy_point,
            player,
            0
        )
        if callback_ok and success then
            if item:IsValid()
                and not IsItemHeldByPlayer(item, player)
                and not ReturnRemovedItem(
                    player,
                    inventory,
                    item,
                    previous_container,
                    previous_slot
            ) then
                return true, nil, "rollback_failed"
            end
            return true, nil, nil
        end

        return ResolveFailedDeploy(
            player,
            inventory,
            item,
            previous_container,
            previous_slot,
            reason or "deploy_failed"
        )
    end

    local inventory_item = item.components.inventoryitem
    local previous_container = inventory_item:GetContainer()
    local previous_slot = inventory_item:GetSlotNum()
    local removed = inventory:RemoveItem(item, false, false)
    if removed == nil then
        return false, "remove_failed"
    end

    previous_container = removed.prevcontainer or previous_container
    previous_slot = removed.prevslot or previous_slot
    removed.prevcontainer = nil
    removed.prevslot = nil

    if removed.components == nil
        or removed.components.deployable == nil then
        local restored = ReturnRemovedItem(
            player,
            inventory,
            removed,
            previous_container,
            previous_slot
        )
        return false, restored and "remove_failed" or "rollback_failed"
    end

    local removed_deployable = removed.components.deployable
    local callback_ok, success, reason =
        RunPlantableCallback(
        removed.prefab,
        "Deploy",
        batch.callback_scope,
        removed_deployable.Deploy,
        removed_deployable,
        deploy_point,
        player,
        0
    )
    if callback_ok and success then
        if removed:IsValid()
            and not ConsumeDetachedItem(removed) then
            return true, nil, "rollback_failed"
        end
        return true, nil, nil
    end

    return ResolveFailedDeploy(
        player,
        inventory,
        removed,
        previous_container,
        previous_slot,
        reason or "deploy_failed"
    )
end

return M
