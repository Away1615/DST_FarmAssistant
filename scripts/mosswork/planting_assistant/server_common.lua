local Shared = require("mosswork/planting_assistant/shared")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}

local rejection_log_state = setmetatable({}, { __mode = "k" })

local REQUEST_WARNING_REASONS = {
    invalid_request = true,
    layout_too_large = true,
    not_deployable = true,
    invalid_ground = true,
}

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

local function GetPlayerController(player)
    return player ~= nil
        and player.components ~= nil
        and player.components.playercontroller
        or nil
end

local function IsPlayerBusy(player)
    local controller = GetPlayerController(player)
    if controller ~= nil
        and controller.IsBusy ~= nil
        and controller:IsBusy() then
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
    if item ~= nil
        and item.components ~= nil
        and item.components.stackable ~= nil then
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
    return inventory_item ~= nil
        and inventory_item:GetGrandOwner() == player
end

function M.GetOwnedItemByGUID(player, guid)
    guid = tonumber(guid)
    if guid == nil
        or guid ~= math.floor(guid)
        or guid <= 0
        or type(Ents) ~= "table" then
        return nil
    end

    local item = Ents[guid]
    return IsItemHeldByPlayer(item, player) and item or nil
end

local function LogPlantableError(item, callback_name, failure)
    Log:Error(
        "plantable callback failed prefab=%s callback=%s error=%s",
        item ~= nil and tostring(item.prefab) or "unknown",
        tostring(callback_name),
        SafeToString(failure)
    )
end

function M.SendResult(player, request_id, reason)
    if player == nil
        or not player:IsValid()
        or player.userid == nil
        or player.userid == "" then
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

        if log_level == "debug" then
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
    if controller == nil
        or controller.IsEnabled == nil
        or not controller:IsEnabled() then
        return false
    end

    return player.components.rider == nil
        or not player.components.rider:IsRiding()
end

function M.IsPlayerReadyToStart(player)
    return M.IsPlayerOperational(player) and not IsPlayerBusy(player)
end

function M.IsPlayerNearPoint(player, x, z, distance)
    if player == nil or not player:IsValid() then
        return false
    end

    x = tonumber(x)
    z = tonumber(z)
    if x == nil or z == nil then
        return false
    end

    local player_x, _, player_z = player.Transform:GetWorldPosition()
    local delta_x = x - player_x
    local delta_z = z - player_z
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
    if target ~= nil
        and target:IsValid()
        and target.Transform ~= nil then
        local x, _, z = target.Transform:GetWorldPosition()
        return x, z
    end

    return nil, nil
end

function M.GetPlantMetadata(item, prefab, cached_metadata)
    local deployable = item ~= nil
        and item:IsValid()
        and item.components ~= nil
        and item.components.deployable
        or nil

    if cached_metadata ~= nil
        and cached_metadata.item == item
        and cached_metadata.deployable == deployable
        and cached_metadata.prefab == prefab then
        return cached_metadata, nil
    end

    if item == nil
        or not item:IsValid()
        or item.prefab ~= prefab
        or item.components == nil
        or item.components.inventoryitem == nil
        or deployable == nil
        or type(deployable.GetDeployMode) ~= "function"
        or type(deployable.DeploySpacingRadius) ~= "function"
        or type(deployable.CanDeploy) ~= "function"
        or type(deployable.Deploy) ~= "function" then
        return nil, "not_deployable"
    end

    local mode_ok, deploy_mode = pcall(
        deployable.GetDeployMode,
        deployable
    )
    if not mode_ok then
        LogPlantableError(item, "GetDeployMode", deploy_mode)
        return nil, "plantable_unavailable"
    end
    if deploy_mode ~= DEPLOYMODE.PLANT then
        return nil, "not_deployable"
    end

    local spacing_ok, native_spacing = pcall(
        deployable.DeploySpacingRadius,
        deployable
    )
    if not spacing_ok then
        LogPlantableError(item, "DeploySpacingRadius", native_spacing)
        return nil, "plantable_unavailable"
    end
    if not Shared.IsValidSpacing(native_spacing) then
        return nil, "not_deployable"
    end

    return {
        item = item,
        prefab = prefab,
        deployable = deployable,
        native_spacing = native_spacing,
    }, nil
end

function M.GetBatchPlantMetadata(batch, item)
    local metadata, reason = M.GetPlantMetadata(
        item,
        batch.prefab,
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
        return nil, "active_item_changed"
    end

    local metadata, reason = M.GetPlantMetadata(item, prefab)
    return metadata ~= nil and item or nil, reason, metadata
end

function M.GetBoundInventoryItem(player, item, prefab, guid)
    local bound_item = M.GetOwnedItemByGUID(player, guid)
    if bound_item == nil or bound_item ~= item then
        return nil, "active_item_changed"
    end

    local metadata, reason = M.GetPlantMetadata(item, prefab)
    return metadata ~= nil and item or nil, reason, metadata
end

function M.FindDeployableItem(player, prefab, preferred_item)
    if IsItemHeldByPlayer(preferred_item, player)
        and preferred_item.prefab == prefab then
        return preferred_item
    end

    local inventory = player.components.inventory
    local active_item = inventory:GetActiveItem()
    if IsItemHeldByPlayer(active_item, player)
        and active_item.prefab == prefab then
        return active_item
    end

    return inventory:FindItem(function(candidate)
        return candidate ~= nil
            and candidate.prefab == prefab
            and IsItemHeldByPlayer(candidate, player)
    end)
end

function M.CountDeployableItems(player, prefab)
    local inventory = player.components.inventory
    local total = 0
    local seen = {}

    local function CountItem(item)
        if item == nil
            or seen[item]
            or item.prefab ~= prefab
            or not IsItemHeldByPlayer(item, player) then
            return
        end

        seen[item] = true
        total = total + StackSize(item)
    end

    CountItem(inventory:GetActiveItem())
    for _, item in ipairs(inventory:FindItems(function(candidate)
        return candidate ~= nil and candidate.prefab == prefab
    end) or {}) do
        CountItem(item)
    end

    return total
end

function M.CanDeployItemAtPoint(metadata, player, point)
    local item = metadata ~= nil and metadata.item or nil
    local deployable = metadata ~= nil and metadata.deployable or nil
    if item == nil
        or not item:IsValid()
        or deployable == nil
        or item.components == nil
        or item.components.deployable ~= deployable then
        return false, "not_deployable"
    end

    local completed, can_deploy = pcall(
        deployable.CanDeploy,
        deployable,
        Vector3(point.x, 0, point.z),
        nil,
        player,
        0
    )
    if not completed then
        LogPlantableError(item, "CanDeploy", can_deploy)
        return false, "plantable_unavailable"
    end
    return can_deploy == true, can_deploy == true and nil or "blocked"
end

local function ReturnRemovedItem(player, item)
    if item == nil or not item:IsValid() then
        return false
    end
    if IsItemHeldByPlayer(item, player) then
        return true
    end

    local inventory = player.components.inventory
    local completed, failure = pcall(
        inventory.GiveItem,
        inventory,
        item
    )
    if not completed then
        Log:Error(
            "failed to return deploy item prefab=%s player=%s error=%s",
            tostring(item.prefab),
            M.GetPlayerLogId(player),
            SafeToString(failure)
        )
        return false
    end

    return not item:IsValid() or IsItemHeldByPlayer(item, player)
end

local function ResolveFailedRemovedDeploy(player, item, reason)
    if item ~= nil and item:IsValid() then
        if ReturnRemovedItem(player, item) then
            return false, reason
        end
        return false, "rollback_failed", "rollback_failed"
    end

    Log:Error(
        "deploy state unknown prefab=%s player=%s reason=%s",
        item ~= nil and tostring(item.prefab) or "unknown",
        M.GetPlayerLogId(player),
        tostring(reason)
    )
    return false, "deploy_state_unknown", "deploy_state_unknown"
end

local function ConsumeFailedDeployItem(item)
    if item == nil or not item:IsValid() then
        return true
    end

    local completed, failure = pcall(item.Remove, item)
    if not completed then
        Log:Error(
            "failed to consume errored deploy item prefab=%s error=%s",
            tostring(item.prefab),
            SafeToString(failure)
        )
    end
    return not item:IsValid()
end

function M.DeployOne(player, batch, point, item, metadata)
    if item == nil
        or not item:IsValid()
        or item.prefab ~= batch.prefab
        or not IsItemHeldByPlayer(item, player)
        or metadata == nil
        or metadata.item ~= item
        or metadata.deployable ~= item.components.deployable then
        return false, "no_inventory", "no_inventory"
    end

    local can_deploy, can_deploy_reason =
        M.CanDeployItemAtPoint(metadata, player, point)
    if not can_deploy then
        local terminal = can_deploy_reason ~= "blocked"
            and can_deploy_reason
            or nil
        return false, can_deploy_reason or "blocked", terminal
    end

    local deploy_point = Vector3(point.x, 0, point.z)
    local deployable = metadata.deployable
    if deployable.keep_in_inventory_on_deploy then
        local completed, success = pcall(
            deployable.Deploy,
            deployable,
            deploy_point,
            player,
            0
        )
        if not completed then
            LogPlantableError(item, "Deploy", success)
            return false, "plantable_unavailable", "plantable_unavailable"
        end
        return success == true, success == true and nil or "blocked", nil
    end

    local inventory = player.components.inventory
    local remove_ok, removed = pcall(
        inventory.RemoveItem,
        inventory,
        item,
        false,
        false
    )
    if not remove_ok then
        Log:Error(
            "inventory RemoveItem failed prefab=%s player=%s error=%s",
            tostring(item.prefab),
            M.GetPlayerLogId(player),
            SafeToString(removed)
        )
        return false, "remove_failed", "remove_failed"
    end
    if removed == nil then
        return false, "remove_failed", "remove_failed"
    end

    removed.prevcontainer = nil
    removed.prevslot = nil
    local removed_deployable = removed.components ~= nil
        and removed.components.deployable
        or nil
    if removed_deployable == nil
        or type(removed_deployable.Deploy) ~= "function" then
        return ResolveFailedRemovedDeploy(
            player,
            removed,
            "remove_failed"
        )
    end

    local deploy_ok, success = pcall(
        removed_deployable.Deploy,
        removed_deployable,
        deploy_point,
        player,
        0
    )
    if not deploy_ok then
        LogPlantableError(removed, "Deploy", success)
        if not ConsumeFailedDeployItem(removed) then
            return false, "rollback_failed", "rollback_failed"
        end
        return false,
            "plantable_unavailable",
            "plantable_unavailable"
    end
    if success == true then
        return true, nil, nil
    end

    return ResolveFailedRemovedDeploy(player, removed, "blocked")
end

return M
