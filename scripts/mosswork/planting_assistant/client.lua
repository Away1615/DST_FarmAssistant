local Mosswork = require("mosswork")
local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local I18N = require("mosswork/planting_assistant/i18n")
local Callback = Mosswork.Callback
local Log = Mosswork.Log.Create(Shared.MOD_ID)
local MossworkProfile = require("mosswork/profile")
local Values = Mosswork.Values

local M = {}

Mosswork.AssertAPIVersion(
    Shared.MOSSWORK_API_VERSION,
    "Planting Assistant"
)

local function GetDefaultLocalSettings()
    return {
        default_rows = Shared.DEFAULT_ROWS,
        default_columns = Shared.DEFAULT_COLUMNS,
        placement_grid_opacity = Shared.PLACEMENT_GRID_OPACITY,
    }
end

local function NormalizeLocalSettings(settings)
    settings = type(settings) == "table" and settings or {}
    local defaults = GetDefaultLocalSettings()

    return {
        default_rows = Shared.ClampDimension(
            settings.default_rows or defaults.default_rows
        ),
        default_columns = Shared.ClampDimension(
            settings.default_columns or defaults.default_columns
        ),
        placement_grid_opacity = Values.ClampNumber(
            settings.placement_grid_opacity,
            0,
            1,
            defaults.placement_grid_opacity
        ),
    }
end

local function NormalizeSettingsValues(settings)
    return NormalizeLocalSettings(settings)
end

local profile_store = MossworkProfile.CreateOfficial(
    Shared.MOD_ID,
    {
        defaults = GetDefaultLocalSettings,
        normalize = NormalizeLocalSettings,
    }
)

local local_settings = profile_store:Load()

local state = {
    player = nil,
    update_task = nil,
    listener_player = nil,
    rows = local_settings.default_rows,
    columns = local_settings.default_columns,
    local_settings = local_settings,
    plant_markers = {},
    tile_markers = {},
    current = nil,
    handlers_installed = false,
    request_id = 0,
    active_request_id = nil,
    movement_deadline = 0,
    server_deadline = 0,
    request_phase = nil,
    plan_action_seen = false,
    plan_action_missing_since = 0,
    plan_action_grace_until = 0,
    hidden_native_placer = nil,
    hidden_native_placer_scale = nil,
    cached_plant_item = nil,
    cached_plant_spacing = nil,
    cached_native_spacing = nil,
    cached_plant_checked_at = -math.huge,
    cached_plant_slow = false,
    last_undo_request_time = -math.huge,
}

local FAILURE_MESSAGE_KEYS = {
    rate_limited = "failure.rate_limited",
    busy = "failure.busy",
    server_busy = "failure.server_busy",
    no_inventory = "failure.no_inventory",
    no_plantable_positions = "failure.no_positions",
    too_far = "failure.too_far",
    not_at_target = "failure.too_far",
    moved_away = "failure.too_far",
    active_item_changed = "failure.selection_changed",
    spacing_changed = "failure.selection_changed",
    target_changed = "failure.selection_changed",
    request_expired = "failure.timeout",
    batch_timeout = "failure.timeout",
    player_unavailable = "failure.unavailable",
    action_interrupted = "failure.interrupted",
    layout_too_large = "failure.layout_too_large",
    invalid_request = "failure.invalid",
    not_deployable = "failure.invalid",
    invalid_ground = "failure.invalid",
    internal_error = "failure.internal",
    deploy_failed = "failure.internal",
    deploy_state_unknown = "failure.internal",
    remove_failed = "failure.internal",
    rollback_failed = "failure.internal",
    action_unavailable = "failure.internal",
    plantable_unavailable = "failure.plantable_unavailable",
}

local SILENT_FAILURE_REASONS = {
    no_inventory = true,
    no_plantable_positions = true,
    too_far = true,
    not_at_target = true,
    moved_away = true,
}

local UNDO_MESSAGE_KEYS = {
    undo_success = "undo.success",
    undo_unavailable = "undo.unavailable",
    undo_expired = "undo.expired",
    undo_changed = "undo.changed",
    undo_unsupported = "undo.unsupported",
    undo_busy = "undo.busy",
    undo_internal = "undo.internal",
}

local function ShowSystemMessage(key)
    local message = string.format(
        "%s: %s",
        I18N.Translate("mod.name"),
        I18N.Translate(key)
    )
    if type(Networking_SystemMessage) == "function" then
        Networking_SystemMessage(message)
    else
        print("[Mosswork] " .. message)
    end
end

local function ShowFailureMessage(reason)
    if SILENT_FAILURE_REASONS[reason] then
        return
    end

    local key = FAILURE_MESSAGE_KEYS[reason] or "failure.generic"
    ShowSystemMessage(key)
end

local function RemoveMarkers(markers)
    for index, marker in ipairs(markers) do
        if marker ~= nil and marker:IsValid() then
            marker:Remove()
        end
        markers[index] = nil
    end
end

local function RemoveWorldMarkers()
    RemoveMarkers(state.plant_markers)
    RemoveMarkers(state.tile_markers)
    state.current = nil
end

local function ClearRequestState()
    state.active_request_id = nil
    state.movement_deadline = 0
    state.server_deadline = 0
    state.request_phase = nil
    state.plan_action_seen = false
    state.plan_action_missing_since = 0
    state.plan_action_grace_until = 0
end

local function IsRequestPending()
    if state.active_request_id == nil then
        return false
    end

    if state.request_phase == "server" then
        if GetStaticTime() < state.server_deadline then
            return true
        end

        ShowFailureMessage("batch_timeout")
        ClearRequestState()
        return false
    end

    if GetStaticTime() < state.movement_deadline then
        return true
    end

    ShowFailureMessage("request_expired")
    ClearRequestState()
    return false
end

local function IsGameplayScreenAvailable()
    local player = state.player
    if player == nil or player.HUD == nil then
        return false
    end

    if player.HUD.HasInputFocus ~= nil and player.HUD:HasInputFocus() then
        return false
    end

    return TheFrontEnd:GetActiveScreen() == player.HUD
end

local function GetRealTimeMilliseconds()
    return type(GetTimeReal) == "function" and GetTimeReal() or nil
end

local function HasClientPreviewTime(started_at)
    return started_at == nil
        or type(GetTimeReal) ~= "function"
        or GetTimeReal() - started_at
            < Shared.CLIENT_PREVIEW_TIME_BUDGET_MS
end

local function GetDeploySpacing(item)
    local inventory_item = item ~= nil
        and item.replica ~= nil
        and item.replica.inventoryitem
        or nil
    if inventory_item == nil or inventory_item.DeploySpacingRadius == nil then
        return nil
    end

    local completed, spacing, issue = Callback.Run(
        "client plant DeploySpacingRadius",
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
    return completed
        and issue == nil
        and Shared.IsValidSpacing(spacing)
        and spacing
        or nil
end

local function GetActivePlant()
    local player = state.player
    local inventory = player ~= nil and player.replica ~= nil and player.replica.inventory or nil
    local item = inventory ~= nil and inventory:GetActiveItem() or nil
    local now = GetStaticTime()
    if item == state.cached_plant_item
        and (
            (
                state.cached_plant_slow
                and now - state.cached_plant_checked_at
                    < Shared.CLIENT_PLANT_METADATA_RETRY_TIME
            )
            or (
                not state.cached_plant_slow
                and now - state.cached_plant_checked_at
                    < Shared.CLIENT_PLANT_METADATA_CACHE_TIME
            )
        ) then
        return item,
            state.cached_plant_spacing,
            state.cached_native_spacing
    end

    local started_at = GetRealTimeMilliseconds()
    local native_spacing = item ~= nil
        and Shared.IsInventoryPlantable(item)
        and GetDeploySpacing(item)
        or nil
    local spacing = native_spacing ~= nil
        and Shared.ResolvePlantSpacing(native_spacing)
        or nil
    local finished_at = GetRealTimeMilliseconds()
    local callback_was_slow = started_at ~= nil
        and finished_at ~= nil
        and finished_at - started_at
            >= Shared.PLANT_QUERY_CALLBACK_SLOW_THRESHOLD_MS
    if callback_was_slow then
        Log:Warn(
            "slow client plant metadata prefab=%s elapsed_ms=%.2f;"
                .. " result accepted",
            item ~= nil and tostring(item.prefab) or "unknown",
            finished_at - started_at
        )
    end

    state.cached_plant_item = item
    state.cached_plant_checked_at = now
    state.cached_plant_slow = callback_was_slow
    state.cached_native_spacing = native_spacing
    state.cached_plant_spacing = spacing
    return item,
        state.cached_plant_spacing,
        state.cached_native_spacing
end

local function ReplicaStackSize(item)
    if item == nil then
        return 0
    end

    if item.replica ~= nil and item.replica.stackable ~= nil then
        return item.replica.stackable:StackSize()
    end

    if item.components ~= nil and item.components.stackable ~= nil then
        return item.components.stackable:StackSize()
    end

    return 1
end

local function CountMatchingItem(item, prefab, seen)
    if item == nil or item.prefab ~= prefab or seen[item] then
        return 0
    end

    seen[item] = true
    return ReplicaStackSize(item)
end

local function CountClientInventory(prefab)
    local player = state.player
    local inventory = player ~= nil and player.replica ~= nil and player.replica.inventory or nil
    if inventory == nil then
        return 0
    end

    local seen = {}
    local total = 0

    for _, item in pairs(inventory:GetItems() or {}) do
        total = total + CountMatchingItem(item, prefab, seen)
    end

    total = total + CountMatchingItem(inventory:GetActiveItem(), prefab, seen)

    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil and overflow.GetItems ~= nil then
        for _, item in pairs(overflow:GetItems() or {}) do
            total = total + CountMatchingItem(item, prefab, seen)
        end
    end

    return total
end

local function EnsurePlantMarker(index)
    local marker = state.plant_markers[index]
    if marker ~= nil and marker:IsValid() then
        return marker
    end

    marker = SpawnPrefab(Shared.PREFAB_PLANT_MARKER)
    state.plant_markers[index] = marker
    return marker
end

local function EnsureTileMarker(index)
    local marker = state.tile_markers[index]
    if marker ~= nil and marker:IsValid() then
        return marker
    end

    marker = SpawnPrefab(Shared.PREFAB_TILE_MARKER)
    if marker ~= nil and marker.AnimState ~= nil then
        marker.AnimState:SetMultColour(0.15, 0.75, 1, 0.72)
        marker.AnimState:SetAddColour(0.04, 0.16, 0.22, 0)
        marker.AnimState:SetFinalOffset(6)
    end
    state.tile_markers[index] = marker
    return marker
end

local function TrimMarkers(markers, wanted)
    for index = #markers, wanted + 1, -1 do
        local marker = markers[index]
        if marker ~= nil and marker:IsValid() then
            marker:Remove()
        end
        markers[index] = nil
    end
end

local function HideMarkers(markers)
    for _, marker in ipairs(markers) do
        if marker ~= nil and marker:IsValid() then
            marker:Hide()
        end
    end
end

local function CanClientDeploy(item, point, current)
    local now = GetStaticTime()
    if current.validation_disabled_until ~= nil
        and now < current.validation_disabled_until then
        return nil
    end
    current.validation_disabled_until = nil

    local inventory_item = item ~= nil
        and item.replica ~= nil
        and item.replica.inventoryitem
        or nil

    if inventory_item == nil or inventory_item.CanDeploy == nil then
        return false
    end

    local started_at = GetRealTimeMilliseconds()
    local completed, can_deploy = pcall(
        inventory_item.CanDeploy,
        inventory_item,
        Vector3(point.x, 0, point.z),
        nil,
        state.player,
        0
    )
    local finished_at = GetRealTimeMilliseconds()
    if not completed then
        Log:Error(
            "client plant CanDeploy failed prefab=%s error=%s",
            item ~= nil and tostring(item.prefab) or "unknown",
            tostring(can_deploy)
        )
        current.validation_disabled_until =
            now + Shared.CLIENT_PLANT_METADATA_RETRY_TIME
        return nil
    end
    if started_at ~= nil
        and finished_at ~= nil
        and finished_at - started_at
            >= Shared.PLANT_QUERY_CALLBACK_SLOW_THRESHOLD_MS
        and now - current.last_slow_validation_log_time
            >= Shared.CLIENT_PLANT_METADATA_RETRY_TIME then
        current.last_slow_validation_log_time = now
        Log:Warn(
            "slow client plant CanDeploy prefab=%s elapsed_ms=%.2f;"
                .. " result accepted",
            item ~= nil and tostring(item.prefab) or "unknown",
            finished_at - started_at
        )
    end
    return can_deploy == true
end

local function IsSameLayout(
    current,
    item,
    spacing,
    inventory_count,
    anchor_x,
    anchor_z
)
    return current ~= nil
        and current.item == item
        and math.abs(current.layout.spacing - spacing) <= Shared.LAYOUT_EPSILON
        and current.layout.rows == state.rows
        and current.layout.columns == state.columns
        and current.inventory_count == inventory_count
        and math.abs(current.layout.anchor_x - anchor_x) <= Shared.LAYOUT_EPSILON
        and math.abs(current.layout.anchor_z - anchor_z) <= Shared.LAYOUT_EPSILON
end

local function RebuildLayout(
    item,
    spacing,
    inventory_count,
    anchor_x,
    anchor_z
)
    local layout = Layout.BuildSpecFromAnchor(
        anchor_x,
        anchor_z,
        state.rows,
        state.columns,
        spacing
    )
    if layout == nil then
        return false
    end

    local preview_count = math.min(
        layout.candidate_count,
        inventory_count,
        Shared.CLIENT_PREVIEW_MARKER_LIMIT
    )
    HideMarkers(state.plant_markers)
    HideMarkers(state.tile_markers)
    TrimMarkers(state.plant_markers, preview_count)
    TrimMarkers(state.tile_markers, layout.tile_count)

    for index = 1, layout.tile_count do
        local tile = Layout.GetTile(layout, index)
        local marker = EnsureTileMarker(index)
        if marker ~= nil and tile ~= nil then
            marker:Show()
            marker.Transform:SetPosition(tile.x, 0, tile.z)
        end
    end

    state.current = {
        item = item,
        prefab = item.prefab,
        layout = layout,
        inventory_count = inventory_count,
        preview_count = preview_count,
        marker_build_index = 1,
        validation_index = nil,
        validation_inventory_count = 0,
        simulated_plant_count = 0,
        next_validation_time = -math.huge,
        validation_disabled_until = nil,
        last_slow_validation_log_time = -math.huge,
        preview_states = {},
    }
    return true
end

local function BuildPlantMarkerSlice(item)
    local current = state.current
    if current == nil then
        return
    end

    local built = 0
    local started_at = GetRealTimeMilliseconds()
    while built < Shared.CLIENT_MARKERS_PER_TICK
        and current.marker_build_index <= current.preview_count
        and HasClientPreviewTime(started_at) do
        local preview_index = current.marker_build_index
        local point = Layout.GetTraversalPoint(
            current.layout,
            preview_index
        )
        local marker = EnsurePlantMarker(preview_index)
        if marker ~= nil and point ~= nil then
            marker:SetPlant(item.prefab, item)
            marker:Show()
            marker.Transform:SetPosition(point.x, 0, point.z)
            marker:SetPreviewState("unchecked")
        end

        current.marker_build_index = preview_index + 1
        built = built + 1
    end
end

local function StartValidationCycle(current, now)
    current.validation_index = 1
    current.validation_inventory_count =
        CountClientInventory(current.prefab)
    current.simulated_plant_count = 0
    current.next_validation_time = now
end

local function RefreshValidation(item, force)
    local current = state.current
    if current == nil
        or current.marker_build_index <= current.preview_count then
        return
    end

    local now = GetStaticTime()
    if force then
        StartValidationCycle(current, now)
    elseif current.validation_index == nil then
        if now < current.next_validation_time then
            return
        end
        StartValidationCycle(current, now)
    end

    local processed = 0
    local started_at = GetRealTimeMilliseconds()
    while processed < Shared.CLIENT_VALIDATION_POINTS_PER_TICK
        and current.validation_index <= current.preview_count
        and HasClientPreviewTime(started_at) do
        local preview_index = current.validation_index
        local point = Layout.GetTraversalPoint(
            current.layout,
            preview_index
        )
        ---@type boolean|nil
        local can_deploy = false
        if point ~= nil then
            can_deploy = CanClientDeploy(item, point, current)
        end
        local preview_state
        if not can_deploy then
            preview_state = can_deploy == nil and "unchecked" or "blocked"
        elseif current.simulated_plant_count
            >= current.validation_inventory_count then
            preview_state = "hidden"
        else
            current.simulated_plant_count =
                current.simulated_plant_count + 1
            preview_state = "valid"
        end

        if current.preview_states[preview_index] ~= preview_state then
            current.preview_states[preview_index] = preview_state
            local marker = state.plant_markers[preview_index]
            if marker ~= nil and marker:IsValid() then
                if preview_state == "hidden" then
                    marker:Hide()
                else
                    marker:Show()
                    marker:SetPreviewState(preview_state)
                end
            end
        end

        current.validation_index = preview_index + 1
        processed = processed + 1
    end

    if current.validation_index > current.preview_count then
        current.validation_index = nil
        current.next_validation_time = now + Shared.VALIDATION_INTERVAL
    end
end

local function RefreshPreview(force_validation)
    local player = state.player
    if player == nil or not player:IsValid() or not IsGameplayScreenAvailable() then
        RemoveWorldMarkers()
        return
    end

    if IsRequestPending() then
        RemoveWorldMarkers()
        return
    end

    local item, spacing, native_spacing = GetActivePlant()
    if item == nil or spacing == nil or native_spacing == nil then
        RemoveWorldMarkers()
        return
    end
    local inventory_count = CountClientInventory(item.prefab)
    state.rows, state.columns = Shared.ClampLayoutDimensions(
        state.rows,
        state.columns,
        spacing
    )

    local mouse_position = TheInput:GetWorldPosition()
    if mouse_position == nil then
        RemoveWorldMarkers()
        return
    end

    local anchor_x, anchor_z = Layout.GetAnchorAtPoint(
        mouse_position.x,
        mouse_position.z
    )
    if anchor_x == nil or anchor_z == nil then
        RemoveWorldMarkers()
        return
    end

    local layout_changed = not IsSameLayout(
        state.current,
        item,
        spacing,
        inventory_count,
        anchor_x,
        anchor_z
    )
    if layout_changed
        and not RebuildLayout(
            item,
            spacing,
            inventory_count,
            anchor_x,
            anchor_z
        ) then
        RemoveWorldMarkers()
        return
    end

    BuildPlantMarkerSlice(item)
    RefreshValidation(
        item,
        force_validation == true or layout_changed
    )
end

local function ApplyPlacementMarkerOpacity(marker)
    if marker == nil
        or not marker:IsValid()
        or marker.AnimState == nil then
        return
    end

    marker.AnimState:SetMultColour(
        1,
        1,
        1,
        state.local_settings.placement_grid_opacity
    )
end

local function RestoreNativePlacementVisuals()
    local placer = state.hidden_native_placer
    local scale = state.hidden_native_placer_scale
    if placer ~= nil
        and placer:IsValid()
        and placer.Transform ~= nil
        and scale ~= nil then
        placer.Transform:SetScale(scale.x, scale.y, scale.z)
    end
    state.hidden_native_placer = nil
    state.hidden_native_placer_scale = nil
end

local function RefreshNativePlacementVisuals()
    local player = state.player
    local controller = player ~= nil
        and player.components ~= nil
        and player.components.playercontroller
        or nil
    local deployplacer = controller ~= nil and controller.deployplacer or nil
    local item, spacing, native_spacing = GetActivePlant()
    if item == nil
        or spacing == nil
        or native_spacing == nil
        or deployplacer == nil
        or not deployplacer:IsValid() then
        RestoreNativePlacementVisuals()
        return
    end

    if state.hidden_native_placer ~= deployplacer then
        RestoreNativePlacementVisuals()
        local scale_x, scale_y, scale_z = 1, 1, 1
        if deployplacer.Transform ~= nil
            and deployplacer.Transform.GetScale ~= nil then
            scale_x, scale_y, scale_z = deployplacer.Transform:GetScale()
        end
        state.hidden_native_placer = deployplacer
        state.hidden_native_placer_scale = {
            x = scale_x,
            y = scale_y,
            z = scale_z,
        }
    end

    if deployplacer.Transform ~= nil then
        deployplacer.Transform:SetScale(0, 0, 0)
    end

    local placer = deployplacer.components ~= nil
        and deployplacer.components.placer
        or nil
    if placer == nil then
        return
    end

    ApplyPlacementMarkerOpacity(placer.gridinst)
    if type(placer.build_grid) == "table" then
        for _, row in pairs(placer.build_grid) do
            if type(row) == "table" then
                for _, marker in pairs(row) do
                    ApplyPlacementMarkerOpacity(marker)
                end
            end
        end
    end
end

local function HasBufferedPlanningAction()
    local player = state.player
    if player == nil or not player:IsValid() then
        return false
    end

    local action = player.GetBufferedAction ~= nil
        and player:GetBufferedAction()
        or nil
    if action == nil
        and player.components ~= nil
        and player.components.locomotor ~= nil then
        action = player.components.locomotor.bufferedaction
    end

    if action == nil or action.action == nil then
        return false
    end

    local action_id = action.action.id
    return action_id == Shared.ACTION_PLAN_ID
        or action_id == Shared.ACTION_MOVE_ID
end

local function UpdatePendingPlanAction()
    if state.active_request_id == nil or state.request_phase ~= "moving" then
        return
    end

    local now = GetStaticTime()
    if now >= state.movement_deadline then
        ShowFailureMessage("request_expired")
        ClearRequestState()
        return
    end

    if HasBufferedPlanningAction() then
        state.plan_action_seen = true
        state.plan_action_missing_since = 0
        return
    end

    if now < state.plan_action_grace_until then
        return
    end

    if state.plan_action_missing_since <= 0 then
        state.plan_action_missing_since = now
        return
    end

    local cancel_delay = state.plan_action_seen
            and Shared.BATCH_HEARTBEAT_INTERVAL * 2 + 1
        or 2
    if now - state.plan_action_missing_since >= cancel_delay then
        ShowFailureMessage("action_interrupted")
        ClearRequestState()
    end
end

local function OnPreviewTick()
    UpdatePendingPlanAction()
    RefreshPreview(false)
    RefreshNativePlacementVisuals()
end

local function OnPlayerRemoved(player)
    if player ~= state.player then
        return
    end

    if state.update_task ~= nil then
        state.update_task:Cancel()
    end
    RestoreNativePlacementVisuals()
    RemoveWorldMarkers()
    ClearRequestState()
    state.player = nil
    state.update_task = nil
    state.listener_player = nil
end

local DIMENSION_OPTIONS = {}
for value = Shared.MIN_DIMENSION, Shared.MAX_DIMENSION do
    DIMENSION_OPTIONS[#DIMENSION_OPTIONS + 1] = {
        text = tostring(value),
        data = value,
    }
end

local function BuildOpacityOptions()
    return {
        { text = I18N.Translate("opacity.hidden"), data = 0 },
        { text = I18N.Translate("opacity.very_low"), data = 0.15 },
        {
            text = I18N.Translate("opacity.low_recommended"),
            data = 0.25,
        },
        { text = I18N.Translate("opacity.medium"), data = 0.5 },
        { text = I18N.Translate("opacity.high"), data = 0.75 },
        { text = I18N.Translate("opacity.full"), data = 1 },
    }
end

local function Translated(key)
    return function()
        return I18N.Translate(key)
    end
end

local function IsModifierDown(key)
    return TheInput ~= nil and TheInput:IsKeyDown(key)
end

local function OnUndoKeyDown()
    if not IsModifierDown(KEY_CTRL)
        or not IsGameplayScreenAvailable()
        or IsRequestPending() then
        return
    end

    local now = GetStaticTime()
    if now - state.last_undo_request_time
        < Shared.UNDO_REQUEST_INTERVAL then
        return
    end
    state.last_undo_request_time = now

    SendModRPCToServer(
        GetModRPC(Shared.RPC_NAMESPACE, Shared.RPC_UNDO)
    )
end

local function CanHandlePlantingInput()
    if state.player == nil or state.player ~= ThePlayer or not IsGameplayScreenAvailable() then
        return false
    end

    local item, spacing = GetActivePlant()
    return item ~= nil and spacing ~= nil
end

local function OnMouseButton(button, down)
    if not down
        or (button ~= MOUSEBUTTON_SCROLLUP and button ~= MOUSEBUTTON_SCROLLDOWN)
        or not CanHandlePlantingInput() then
        return
    end

    if IsRequestPending() then
        return
    end

    local delta = button == MOUSEBUTTON_SCROLLUP and 1 or -1
    local adjusts_rows = IsModifierDown(KEY_CTRL)
    local adjusts_columns = not adjusts_rows and IsModifierDown(KEY_ALT)
    if not adjusts_rows and not adjusts_columns then
        return
    end

    local controller = state.player.components ~= nil
        and state.player.components.playercontroller
        or nil
    if controller ~= nil then
        controller.lastzoomtime = GetStaticTime()
    end

    local _, spacing = GetActivePlant()
    if adjusts_rows then
        local rows = Shared.ClampDimension(state.rows + delta)
        if not Shared.IsValidLayoutFootprint(
            rows,
            state.columns,
            spacing
        ) then
            RefreshPreview(false)
            return
        end
        state.rows = rows
        RefreshPreview(true)
    elseif adjusts_columns then
        local columns = Shared.ClampDimension(state.columns + delta)
        if not Shared.IsValidLayoutFootprint(
            state.rows,
            columns,
            spacing
        ) then
            RefreshPreview(false)
            return
        end
        state.columns = columns
        RefreshPreview(true)
    end
end

local function NextRequestId()
    state.request_id = state.request_id + 1
    if state.request_id > 2147483647 then
        state.request_id = 1
    end
    return state.request_id
end

local function ResolveActionPoint(action)
    local point = action ~= nil and action:GetActionPoint() or nil
    if point ~= nil then
        return point.x, point.z
    end

    local target = action ~= nil and action.target or nil
    if target ~= nil and target:IsValid() and target.Transform ~= nil then
        local x, _, z = target.Transform:GetWorldPosition()
        return x, z
    end

    return nil, nil
end

function M.PreparePlantRequest(action)
    if not CanHandlePlantingInput() then
        return nil
    end

    RefreshPreview(true)
    local active_item, spacing = GetActivePlant()
    if active_item == nil
        or spacing == nil
        or action == nil
        or action.invobject ~= active_item then
        return nil
    end

    local x, z = ResolveActionPoint(action)
    if not Shared.IsFiniteCoordinate(x) or not Shared.IsFiniteCoordinate(z) then
        return nil
    end

    local requested_layout = Layout.BuildSpec(
        x,
        z,
        state.rows,
        state.columns,
        spacing
    )
    if requested_layout == nil then
        return nil
    end

    local request_id = NextRequestId()
    local now = GetStaticTime()
    state.active_request_id = request_id
    state.movement_deadline = now + Shared.REQUEST_TIMEOUT
    state.server_deadline = 0
    state.request_phase = "moving"
    state.plan_action_seen = false
    state.plan_action_missing_since = 0
    state.plan_action_grace_until = now + 0.75

    return {
        request_id = request_id,
        x = x,
        z = z,
        rows = requested_layout.rows,
        columns = requested_layout.columns,
        prefab = active_item.prefab,
    }
end

function M.Attach(player)
    if player == nil then
        return
    end

    if state.player ~= nil and state.player ~= player then
        if state.update_task ~= nil then
            state.update_task:Cancel()
        end
        if state.listener_player ~= nil and state.listener_player:IsValid() then
            state.listener_player:RemoveEventCallback("onremove", OnPlayerRemoved)
        end
        RestoreNativePlacementVisuals()
        RemoveWorldMarkers()
        ClearRequestState()
    end

    state.player = player

    if state.update_task ~= nil then
        state.update_task:Cancel()
    end
    state.update_task = player:DoPeriodicTask(Shared.PREVIEW_INTERVAL, OnPreviewTick)
    RefreshNativePlacementVisuals()

    if state.listener_player ~= player then
        if state.listener_player ~= nil and state.listener_player:IsValid() then
            state.listener_player:RemoveEventCallback("onremove", OnPlayerRemoved)
        end
        state.listener_player = player
        player:ListenForEvent("onremove", OnPlayerRemoved)
    end
end

function M.ApplyLocalSettings(settings)
    state.local_settings = profile_store:Save(settings)
    state.rows = state.local_settings.default_rows
    state.columns = state.local_settings.default_columns

    RemoveWorldMarkers()
    RefreshPreview(true)
end

function M.InstallInputHandlers()
    if state.handlers_installed then
        return
    end

    state.handlers_installed = true
    TheInput:AddMouseButtonHandler(OnMouseButton)
    TheInput:AddKeyDownHandler(KEY_Z, OnUndoKeyDown)
end

function M.IsRequestPending()
    return IsRequestPending()
end

function M.ReceiveResult(request_id, reason)
    request_id = tonumber(request_id)
    if request_id == nil
        or state.active_request_id == nil
        or request_id ~= state.active_request_id then
        return
    end

    if reason == "started" or reason == "progress" then
        state.request_phase = "server"
        state.movement_deadline = 0
        state.server_deadline =
            GetStaticTime() + Shared.CLIENT_SERVER_SILENCE_TIMEOUT
        state.plan_action_missing_since = 0
        RefreshPreview(false)
        return
    end

    ClearRequestState()
    RefreshPreview(true)
    if reason ~= "success" then
        ShowFailureMessage(reason)
    end
end

function M.ReceiveUndoResult(reason)
    local key = UNDO_MESSAGE_KEYS[reason] or "undo.internal"
    ShowSystemMessage(key)
end

function M.GetSettingsDefinition()
    return {
        title = Translated("settings.title"),
        get_values = function()
            return Values.CopyTable(state.local_settings)
        end,
        get_defaults = GetDefaultLocalSettings,
        normalize = NormalizeSettingsValues,
        apply = M.ApplyLocalSettings,
        fields = {
            {
                key = "default_rows",
                label = Translated("settings.local_rows"),
                hover = Translated("settings.rows_tooltip"),
                options = DIMENSION_OPTIONS,
            },
            {
                key = "default_columns",
                label = Translated("settings.local_columns"),
                hover = Translated("settings.columns_tooltip"),
                options = DIMENSION_OPTIONS,
            },
            {
                key = "placement_grid_opacity",
                label = Translated("settings.grid_opacity"),
                hover = Translated("settings.opacity_tooltip"),
                options = BuildOpacityOptions,
            },
        },
    }
end

return M
