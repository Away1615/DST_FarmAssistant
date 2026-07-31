local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local Common = require("mosswork/planting_assistant/server_common")
local Batch = require("mosswork/planting_assistant/server_batch")

local M = {}

local pending_requests = setmetatable({}, { __mode = "k" })

local function RejectRequest(player, request, reason, log_level)
    Common.RejectRequest(
        player,
        request ~= nil and request.request_id or 0,
        reason,
        log_level
    )
end

function M.HandlePlantRequest(
    player,
    request_id,
    x,
    z,
    rows,
    columns,
    prefab,
    source_guid
)
    if player == nil then
        return
    end

    pending_requests[player] = nil

    if not Shared.IsValidRequestId(request_id) then
        Common.RejectRequest(
            player,
            request_id,
            "invalid_request",
            "debug"
        )
        return
    end
    if not Common.IsPlayerReadyToStart(player) then
        Common.RejectRequest(
            player,
            request_id,
            "player_unavailable",
            "debug"
        )
        return
    end
    if not Shared.IsFiniteCoordinate(x)
        or not Shared.IsFiniteCoordinate(z)
        or not Shared.IsValidDimension(rows)
        or not Shared.IsValidDimension(columns)
        or type(prefab) ~= "string"
        or prefab == ""
        or #prefab > 128 then
        Common.RejectRequest(player, request_id, "invalid_request")
        return
    end
    if Batch.HasActiveBatch(player) then
        Common.RejectRequest(player, request_id, "busy")
        return
    end
    if not Batch.CanAcceptNewBatch(player) then
        Common.RejectRequest(player, request_id, "server_busy")
        return
    end

    local inventory = player.components.inventory
    local normalized_source_guid = source_guid ~= nil
        and tonumber(source_guid)
        or nil
    local source_item
    if source_guid ~= nil then
        source_item = Common.GetOwnedItemByGUID(
            player,
            normalized_source_guid
        )
    else
        source_item = inventory:GetActiveItem()
    end
    if source_item == nil or source_item.prefab ~= prefab then
        Common.RejectRequest(
            player,
            request_id,
            "active_item_changed"
        )
        return
    end

    local plant_metadata, metadata_reason =
        Common.GetPlantMetadata(source_item, prefab)
    if plant_metadata == nil then
        Common.RejectRequest(
            player,
            request_id,
            metadata_reason or "not_deployable"
        )
        return
    end

    local spacing = Shared.ResolvePlantSpacing(
        plant_metadata.native_spacing
    )
    if spacing == nil then
        Common.RejectRequest(player, request_id, "not_deployable")
        return
    end
    if not Shared.IsValidLayoutFootprint(rows, columns, spacing) then
        Common.RejectRequest(player, request_id, "layout_too_large")
        return
    end

    local layout = Layout.BuildSpec(
        tonumber(x),
        tonumber(z),
        tonumber(rows),
        tonumber(columns),
        spacing
    )
    if layout == nil then
        Common.RejectRequest(player, request_id, "invalid_ground")
        return
    end

    pending_requests[player] = {
        request_id = tonumber(request_id),
        prefab = prefab,
        native_spacing = plant_metadata.native_spacing,
        spacing = spacing,
        rows = layout.rows,
        columns = layout.columns,
        anchor_x = layout.anchor_x,
        anchor_z = layout.anchor_z,
        source_guid = normalized_source_guid,
        expires_at = GetTime() + Shared.REQUEST_TIMEOUT,
    }
end

local function BeginPreparedRequest(
    player,
    source_item,
    action_x,
    action_z
)
    local request = player ~= nil and pending_requests[player] or nil
    if request == nil then
        return false
    end

    if not Shared.IsFiniteCoordinate(action_x)
        or not Shared.IsFiniteCoordinate(action_z) then
        return false
    end

    local layout = Layout.BuildSpec(
        action_x,
        action_z,
        request.rows,
        request.columns,
        request.spacing
    )
    if layout == nil
        or math.abs(layout.anchor_x - request.anchor_x)
            > Shared.LAYOUT_EPSILON
        or math.abs(layout.anchor_z - request.anchor_z)
            > Shared.LAYOUT_EPSILON
        or source_item == nil
        or source_item.prefab ~= request.prefab then
        return false
    end

    pending_requests[player] = nil

    if not Common.IsPlayerOperational(player) then
        RejectRequest(player, request, "player_unavailable")
        return false
    end
    if GetTime() > request.expires_at then
        RejectRequest(player, request, "request_expired")
        return false
    end
    if Batch.HasActiveBatch(player) then
        RejectRequest(player, request, "busy")
        return false
    end
    if not Batch.CanAcceptNewBatch(player) then
        RejectRequest(player, request, "server_busy")
        return false
    end
    if not Common.IsPlayerNearPoint(
        player,
        action_x,
        action_z,
        Shared.ACTION_EXECUTION_DISTANCE
    ) then
        RejectRequest(player, request, "not_at_target")
        return false
    end

    local bound_item, source_reason, plant_metadata
    if request.source_guid ~= nil then
        bound_item, source_reason, plant_metadata =
            Common.GetBoundInventoryItem(
                player,
                source_item,
                request.prefab,
                request.source_guid
            )
    else
        bound_item, source_reason, plant_metadata =
            Common.GetBoundActiveItem(
                player,
                source_item,
                request.prefab
            )
    end
    if bound_item == nil then
        RejectRequest(
            player,
            request,
            source_reason or "active_item_changed"
        )
        return false
    end

    if math.abs(
        plant_metadata.native_spacing - request.native_spacing
    ) > Shared.LAYOUT_EPSILON then
        RejectRequest(player, request, "spacing_changed")
        return false
    end

    local available = Common.CountDeployableItems(
        player,
        request.prefab
    )
    if available <= 0 then
        RejectRequest(player, request, "no_inventory")
        return false
    end

    return Batch.Start(player, {
        request_id = request.request_id,
        prefab = request.prefab,
        source_item = bound_item,
        native_spacing = request.native_spacing,
        plant_metadata = plant_metadata,
        layout = layout,
        action_x = action_x,
        action_z = action_z,
        scan_index = 1,
        remaining_plants = math.min(
            layout.candidate_count,
            available
        ),
        planted_count = 0,
        blocked_count = 0,
        registered = false,
    })
end

function M.BeginPlantRequest(action)
    if TheWorld == nil or not TheWorld.ismastersim or action == nil then
        return false
    end

    local action_x, action_z = Common.ResolveActionPoint(action)
    return BeginPreparedRequest(
        action.doer,
        action.invobject,
        action_x,
        action_z
    )
end

function M.HandleControllerPlantRequest(
    player,
    request_id,
    x,
    z,
    rows,
    columns,
    prefab,
    source_guid
)
    if TheWorld == nil or not TheWorld.ismastersim then
        return false
    end

    M.HandlePlantRequest(
        player,
        request_id,
        x,
        z,
        rows,
        columns,
        prefab,
        source_guid
    )

    local request = player ~= nil and pending_requests[player] or nil
    local normalized_request_id = tonumber(request_id)
    local normalized_source_guid = tonumber(source_guid)
    if request == nil
        or request.request_id ~= normalized_request_id
        or request.source_guid ~= normalized_source_guid then
        return false
    end

    return BeginPreparedRequest(
        player,
        Common.GetOwnedItemByGUID(player, normalized_source_guid),
        tonumber(x),
        tonumber(z)
    )
end

return M
