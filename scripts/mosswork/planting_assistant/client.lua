local Mosswork = require("mosswork")
local Shared = require("mosswork/planting_assistant/shared")
local Layout = require("mosswork/planting_assistant/layout")
local I18N = require("mosswork/planting_assistant/i18n")
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
        plant_spacing = Shared.PLANT_SPACING_AUTO,
    }
end

local function GetSettingsFootprintSpacing(setting)
    return setting == Shared.PLANT_SPACING_AUTO and nil or tonumber(setting)
end

local function NormalizeLocalSettings(settings, changed_key)
    settings = type(settings) == "table" and settings or {}
    local defaults = GetDefaultLocalSettings()
    local plant_spacing = Shared.NormalizePlantSpacingSetting(
        settings.plant_spacing
    )
    local preferred = changed_key == "default_rows" and "rows"
        or changed_key == "default_columns" and "columns"
        or nil
    local rows, columns = Shared.ClampLayoutDimensions(
        settings.default_rows or defaults.default_rows,
        settings.default_columns or defaults.default_columns,
        GetSettingsFootprintSpacing(plant_spacing),
        preferred
    )

    return {
        default_rows = rows,
        default_columns = columns,
        placement_grid_opacity = Values.ClampNumber(
            settings.placement_grid_opacity,
            0,
            1,
            defaults.placement_grid_opacity
        ),
        plant_spacing = plant_spacing,
    }
end

local function NormalizeSettingsValues(settings, changed_key)
    return NormalizeLocalSettings(settings, changed_key)
end

local profile_store = Mosswork.Profile.Create(
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
    request_phase = nil,
    plan_action_seen = false,
    plan_action_missing_since = 0,
    plan_action_grace_until = 0,
    last_validation_time = -math.huge,
    hidden_native_placer = nil,
    hidden_native_placer_scale = nil,
}

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
    state.last_validation_time = -math.huge
end

local function ClearRequestState()
    state.active_request_id = nil
    state.movement_deadline = 0
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
        return true
    end

    if GetStaticTime() < state.movement_deadline then
        return true
    end

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

local function GetDeploySpacing(item)
    local inventory_item = item ~= nil
        and item.replica ~= nil
        and item.replica.inventoryitem
        or nil
    if inventory_item == nil or inventory_item.DeploySpacingRadius == nil then
        return nil
    end

    local spacing = inventory_item:DeploySpacingRadius()
    return Shared.IsValidSpacing(spacing) and spacing or nil
end

local function GetActivePlant()
    local player = state.player
    local inventory = player ~= nil and player.replica ~= nil and player.replica.inventory or nil
    local item = inventory ~= nil and inventory:GetActiveItem() or nil
    local native_spacing = item ~= nil
        and Shared.GetPlant(item.prefab) ~= nil
        and GetDeploySpacing(item)
        or nil
    local spacing = native_spacing ~= nil
        and Shared.ResolvePlantSpacing(
            state.local_settings.plant_spacing,
            native_spacing
        )
        or nil
    return item, spacing, native_spacing
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

local function CanClientDeploy(item, point)
    local inventory_item = item ~= nil
        and item.replica ~= nil
        and item.replica.inventoryitem
        or nil

    if inventory_item == nil or inventory_item.CanDeploy == nil then
        return false
    end

    return inventory_item:CanDeploy(
        Vector3(point.x, 0, point.z),
        nil,
        state.player,
        0
    ) == true
end

local function IsLayoutStartInRange(layout)
    local player = state.player
    if player == nil or layout == nil then
        return false
    end

    local player_x, _, player_z = player.Transform:GetWorldPosition()
    local target_x = layout.anchor_x + Shared.TILE_SIZE * 0.5
    local target_z = layout.anchor_z + Shared.TILE_SIZE * 0.5
    local delta_x = target_x - player_x
    local delta_z = target_z - player_z
    local max_distance = Shared.MAX_REQUEST_DISTANCE
    return delta_x * delta_x + delta_z * delta_z <= max_distance * max_distance
end

local function IsSameLayout(current, prefab, spacing, anchor_x, anchor_z)
    return current ~= nil
        and current.prefab == prefab
        and math.abs(current.layout.spacing - spacing) <= Shared.LAYOUT_EPSILON
        and current.layout.rows == state.rows
        and current.layout.columns == state.columns
        and math.abs(current.layout.anchor_x - anchor_x) <= Shared.LAYOUT_EPSILON
        and math.abs(current.layout.anchor_z - anchor_z) <= Shared.LAYOUT_EPSILON
end

local function RebuildLayout(item, spacing, anchor_x, anchor_z)
    local layout = Layout.BuildFromAnchor(
        anchor_x,
        anchor_z,
        state.rows,
        state.columns,
        spacing
    )
    if layout == nil then
        return false
    end

    for index, point in ipairs(layout.points) do
        local marker = EnsurePlantMarker(index)
        if marker ~= nil then
            marker:SetPlant(item.prefab)
            marker.Transform:SetPosition(point.x, 0, point.z)
        end
    end
    TrimMarkers(state.plant_markers, #layout.points)

    for index, tile in ipairs(layout.tiles) do
        local marker = EnsureTileMarker(index)
        if marker ~= nil then
            marker.Transform:SetPosition(tile.x, 0, tile.z)
        end
    end
    TrimMarkers(state.tile_markers, #layout.tiles)

    state.current = {
        prefab = item.prefab,
        layout = layout,
        traversal = Layout.BuildTraversalOrder(layout),
        preview_states = {},
    }
    state.last_validation_time = -math.huge
    return true
end

local function RefreshValidation(item, native_spacing, force)
    local current = state.current
    if current == nil or native_spacing == nil then
        return
    end

    local now = GetStaticTime()
    if not force and now - state.last_validation_time < Shared.VALIDATION_INTERVAL then
        return
    end

    local inventory_count = CountClientInventory(current.prefab)
    local simulated_plants = {}
    local simulated_plant_count = 0
    for _, point in ipairs(current.traversal) do
        local can_deploy = CanClientDeploy(item, point)
        local preview_state
        if not can_deploy then
            preview_state = "blocked"
        elseif simulated_plant_count >= inventory_count then
            preview_state = "missing"
        elseif Layout.HasPlannedConflict(
            simulated_plants,
            point,
            native_spacing
        ) then
            preview_state = "blocked"
        else
            simulated_plant_count = simulated_plant_count + 1
            simulated_plants[#simulated_plants + 1] = point
            preview_state = "valid"
        end

        local index = point.index
        if current.preview_states[index] ~= preview_state then
            current.preview_states[index] = preview_state
            local marker = state.plant_markers[index]
            if marker ~= nil and marker:IsValid() then
                marker:SetPreviewState(preview_state)
            end
        end
    end

    state.last_validation_time = now
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

    local anchor_x, anchor_z = Layout.GetAnchorAtPoint(mouse_position.x, mouse_position.z)
    if anchor_x == nil or anchor_z == nil then
        RemoveWorldMarkers()
        return
    end

    local layout_changed = not IsSameLayout(
        state.current,
        item.prefab,
        spacing,
        anchor_x,
        anchor_z
    )
    if layout_changed and not RebuildLayout(item, spacing, anchor_x, anchor_z) then
        RemoveWorldMarkers()
        return
    end

    RefreshValidation(
        item,
        native_spacing,
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

local function HasBufferedPlanAction()
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

    return action ~= nil
        and action.action ~= nil
        and action.action.id == Shared.ACTION_PLAN_ID
end

local function UpdatePendingPlanAction()
    if state.active_request_id == nil or state.request_phase ~= "moving" then
        return
    end

    local now = GetStaticTime()
    if HasBufferedPlanAction() then
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

    local cancel_delay = state.plan_action_seen and 5 or 2
    if now - state.plan_action_missing_since >= cancel_delay then
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

local function BuildSpacingOptions()
    local options = {
        {
            text = I18N.Translate("settings.spacing_auto"),
            data = Shared.PLANT_SPACING_AUTO,
        },
    }
    for value = Shared.MIN_PLANT_SPACING, Shared.MAX_PLANT_SPACING do
        options[#options + 1] = {
            text = tostring(value),
            data = value,
        }
    end
    return options
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

    local requested_layout = Layout.Build(
        x,
        z,
        state.rows,
        state.columns,
        spacing
    )
    if requested_layout == nil then
        return nil
    end

    local total = #requested_layout.points
    if total > Shared.MAX_PLANTS_PER_BATCH then
        return nil
    end

    if not IsLayoutStartInRange(requested_layout) then
        return nil
    end

    local request_id = NextRequestId()
    local now = GetStaticTime()
    state.active_request_id = request_id
    state.movement_deadline = now + Shared.REQUEST_TIMEOUT
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
        plant_spacing = state.local_settings.plant_spacing,
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
        state.plan_action_missing_since = 0
        RefreshPreview(false)
        return
    end

    ClearRequestState()
    RefreshPreview(true)
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
                key = "plant_spacing",
                label = Translated("settings.plant_spacing"),
                hover = Translated("settings.spacing_tooltip"),
                options = BuildSpacingOptions,
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
