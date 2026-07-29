local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local Common = require("mosswork/planting_assistant/server_common")
local Batch = require("mosswork/planting_assistant/server_batch")

local M = {}

local pending_requests = setmetatable({}, { __mode = "k" })
local last_requests = setmetatable({}, { __mode = "k" })
local last_ingress_requests = setmetatable({}, { __mode = "k" })
local last_rate_limit_notices = setmetatable({}, { __mode = "k" })

local function RejectPreparedRequest(player, request, reason)
    Common.RejectRequest(
        player,
        request ~= nil and request.request_id or 0,
        reason
    )
end

local function GetPlantableFailureReason(
    fallback,
    callback_scope
)
    return Common.GetCallbackFailure(callback_scope) or fallback
end

function M.HandlePlantRequest(
    player,
    request_id,
    x,
    z,
    rows,
    columns,
    prefab
)
    if player == nil then
        return
    end

    local now = GetTime()
    local last_ingress = last_ingress_requests[player] or -math.huge
    if now - last_ingress < Shared.RPC_INGRESS_INTERVAL then
        return
    end
    last_ingress_requests[player] = now

    if not Common.IsPlayerReadyToStart(player) then
        Common.RejectRequest(
            player,
            request_id,
            "player_unavailable",
            "debug"
        )
        return
    end

    if not Shared.IsValidRequestId(request_id) then
        Common.RejectRequest(player, request_id, "invalid_request", "debug")
        return
    end

    local last_request = last_requests[player] or -math.huge
    if now - last_request < Shared.REQUEST_COOLDOWN then
        local last_notice =
            last_rate_limit_notices[player] or -math.huge
        if now - last_notice >= Shared.REQUEST_COOLDOWN then
            last_rate_limit_notices[player] = now
            Common.RejectRequest(player, request_id, "rate_limited")
        end
        return
    end
    last_requests[player] = now

    if not Shared.IsFiniteCoordinate(x)
        or not Shared.IsFiniteCoordinate(z)
        or not Shared.IsValidDimension(rows)
        or not Shared.IsValidDimension(columns) then
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
    local item = inventory:GetActiveItem()
    local callback_scope = Common.CreateCallbackScope()
    local matches, match_reason = Common.IsMatchingDeployable(
        item,
        prefab
    )
    if not matches then
        Common.RejectRequest(
            player,
            request_id,
            GetPlantableFailureReason(
                match_reason or "active_item_changed",
                callback_scope
            )
        )
        return
    end
    local plant_metadata, metadata_reason = Common.GetPlantMetadata(
        item,
        callback_scope
    )
    if plant_metadata == nil then
        Common.RejectRequest(
            player,
            request_id,
            metadata_reason or "not_deployable"
        )
        return
    end
    local native_spacing = plant_metadata.native_spacing

    local spacing = Shared.ResolvePlantSpacing(native_spacing)
    if spacing == nil then
        Common.RejectRequest(player, request_id, "invalid_request")
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
        spacing = spacing,
        native_spacing = native_spacing,
        rows = tonumber(rows),
        columns = tonumber(columns),
        anchor_x = layout.anchor_x,
        anchor_z = layout.anchor_z,
        expires_at = now + Shared.REQUEST_TIMEOUT,
        callback_scope = callback_scope,
        plant_metadata = plant_metadata,
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

    if not Common.IsPlayerOperational(player) then
        RejectPreparedRequest(player, request, "player_unavailable")
        return false
    end

    if GetTime() > request.expires_at then
        RejectPreparedRequest(player, request, "request_expired")
        return false
    end

    if Batch.HasActiveBatch(player) then
        RejectPreparedRequest(player, request, "busy")
        return false
    end
    if not Batch.CanAcceptNewBatch(player) then
        RejectPreparedRequest(player, request, "server_busy")
        return false
    end
    local action_x, action_z = Common.ResolveActionPoint(action)
    if not Shared.IsFiniteCoordinate(action_x)
        or not Shared.IsFiniteCoordinate(action_z)
        or not Common.IsPlayerNearPoint(
            player,
            action_x,
            action_z,
            Shared.ACTION_EXECUTION_DISTANCE
        ) then
        RejectPreparedRequest(player, request, "not_at_target")
        return false
    end

    local source_item, source_reason = Common.GetBoundActiveItem(
        player,
        action.invobject,
        request.prefab
    )
    if source_item == nil then
        RejectPreparedRequest(
            player,
            request,
            GetPlantableFailureReason(
                source_reason or "active_item_changed",
                request.callback_scope
            )
        )
        return false
    end

    local plant_metadata, metadata_reason = Common.GetPlantMetadata(
        source_item,
        request.callback_scope,
        request.plant_metadata
    )
    if plant_metadata == nil then
        RejectPreparedRequest(player, request, metadata_reason)
        return false
    end
    local native_spacing = plant_metadata.native_spacing
    if native_spacing == nil
        or math.abs(native_spacing - request.native_spacing)
            > Shared.LAYOUT_EPSILON then
        RejectPreparedRequest(player, request, "spacing_changed")
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
            > Shared.LAYOUT_EPSILON then
        layout = nil
    end

    if layout == nil then
        RejectPreparedRequest(player, request, "target_changed")
        return false
    end

    local available = Common.CountDeployableItems(player, request.prefab)
    if available <= 0 then
        RejectPreparedRequest(
            player,
            request,
            GetPlantableFailureReason(
                "no_inventory",
                request.callback_scope
            )
        )
        return false
    end

    local batch = {
        request_id = request.request_id,
        prefab = request.prefab,
        source_item = source_item,
        native_spacing = native_spacing,
        layout = layout,
        stage = "preflight",
        scan_index = 1,
        pending_point = nil,
        action_x = action_x,
        action_z = action_z,
        action = nil,
        watchdog_task = nil,
        failure_reason = nil,
        callback_scope = request.callback_scope,
        plant_metadata = plant_metadata,
        candidate_count = layout.candidate_count,
        preflight_blocked_count = 0,
        runtime_blocked_count = 0,
        planted_count = 0,
        registered = false,
    }
    return Batch.Start(player, batch)
end

return M
