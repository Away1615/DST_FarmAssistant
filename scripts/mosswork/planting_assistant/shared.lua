local Mosswork = require("mosswork")
local Callback = Mosswork.Callback
local Values = Mosswork.Values

local M = {}

M.MOD_ID = "mosswork.planting_assistant"
M.MOD_VERSION = "0.2.0"
M.MOSSWORK_API_VERSION = 1

M.RPC_NAMESPACE = "mosswork.planting_assistant"
M.RPC_PLANT = "plant"
M.RPC_RESULT = "result"
M.RPC_UNDO = "undo"
M.RPC_UNDO_RESULT = "undo_result"
M.ACTION_PLAN_ID = "MOSSWORK_PA_PLAN_PLANT"
M.ACTION_BATCH_ID = "MOSSWORK_PA_BATCH_PLANT"
M.ACTION_MOVE_ID = "MOSSWORK_PA_MOVE_TO_PLANT"
M.PREFAB_PLANT_MARKER = "mosswork_pa_plant_marker"
M.PREFAB_TILE_MARKER = "mosswork_pa_tile_marker"

M.TILE_SIZE = 4
M.DEFAULT_ROWS = 1
M.DEFAULT_COLUMNS = 1
M.MIN_DIMENSION = 1
M.MAX_LAYOUT_TILES_PER_AXIS = 9
M.MAX_PLANTS_PER_TILE = 4
M.MAX_DIMENSION =
    M.MAX_LAYOUT_TILES_PER_AXIS * M.MAX_PLANTS_PER_TILE
M.MAX_REQUEST_DISTANCE = 8
M.PLACEMENT_GRID_OPACITY = 0.25
M.MIN_LAYOUT_SPACING = M.TILE_SIZE / M.MAX_PLANTS_PER_TILE
M.MAX_LAYOUT_SPACING = M.TILE_SIZE
M.REQUEST_COOLDOWN = 1
M.REQUEST_TIMEOUT = 30
M.CLIENT_SERVER_SILENCE_TIMEOUT = 30
M.BATCH_HEARTBEAT_INTERVAL = 5
M.PREVIEW_INTERVAL = 0.1
M.VALIDATION_INTERVAL = 0.75
M.CLIENT_PREVIEW_MARKER_LIMIT = 256
M.CLIENT_MARKERS_PER_TICK = 32
M.CLIENT_VALIDATION_POINTS_PER_TICK = 16
M.CLIENT_PREVIEW_TIME_BUDGET_MS = 4
M.CLIENT_PLANT_METADATA_CACHE_TIME = 0.5
M.CLIENT_PLANT_METADATA_RETRY_TIME = 5
M.GLOBAL_PREFLIGHT_POINTS_PER_TICK = 8
M.PREFLIGHT_POINTS_PER_BATCH_TURN = 1
M.GLOBAL_PLANTS_PER_TICK = 4
M.PLANTS_PER_BATCH_TURN = 1
M.SCHEDULER_TIME_BUDGET_MS = 8
M.MAX_ACTIVE_BATCHES = 8
M.BATCH_WATCHDOG_INTERVAL = 1
M.BATCH_STALL_TIMEOUT = 20
M.PLANT_QUERY_CALLBACK_SLOW_THRESHOLD_MS = 6
M.DEPLOY_CALLBACK_SLOW_THRESHOLD_MS = 16
M.PLANT_QUERY_CALLBACK_TIMEOUT_MS = 50
M.PLANT_QUERY_CALLBACK_INSTRUCTION_LIMIT = 500000
M.PLANT_CALLBACK_HOOK_INTERVAL = 10000
M.BATCH_ACTION_STATE = "mosswork_pa_batch_plant"
M.BATCH_ACTION_PERFORM_FRAME = 10
M.BATCH_ACTION_DURATION_FRAMES = 16
M.ACTION_ARRIVE_DISTANCE = 1.5
M.ACTION_EXECUTION_DISTANCE = 4
M.BATCH_LEASH_DISTANCE = 6
M.LAYOUT_EPSILON = 0.0001
M.MAX_DEPLOY_SPACING = 4
M.RPC_INGRESS_INTERVAL = 0.1
M.REJECTION_LOG_REPEAT_INTERVAL = 5
M.UNDO_WINDOW = 5
M.UNDO_REQUEST_INTERVAL = 0.25
M.UNDO_CAPTURE_RADIUS = 0.25
M.UNDO_POSITION_EPSILON = 0.1

M.PLANT_VISUALS = {
    dug_berrybush = {
        bank = "berrybush",
        build = "berrybush",
        animation = "dead",
        scale = 0.72,
    },
    dug_berrybush2 = {
        bank = "berrybush2",
        build = "berrybush2",
        animation = "dead",
        scale = 0.72,
    },
    dug_berrybush_juicy = {
        bank = "berrybush_juicy",
        build = "berrybush_juicy",
        animation = "dead",
        scale = 0.68,
    },
    dug_grass = {
        bank = "grass",
        build = "grass1",
        animation = "idle",
        scale = 0.72,
    },
    dug_sapling = {
        bank = "sapling",
        build = "sapling",
        animation = "idle",
        scale = 0.72,
    },
    dug_sapling_moon = {
        bank = "sapling_moon",
        build = "sapling_moon",
        animation = "idle",
        scale = 0.72,
    },
    dug_marsh_bush = {
        bank = "marsh_bush",
        build = "marsh_bush",
        animation = "idle",
        scale = 0.72,
    },
}

function M.GetPlantVisual(prefab)
    return type(prefab) == "string" and M.PLANT_VISUALS[prefab] or nil
end

function M.IsInventoryPlantable(item)
    if item == nil or not item:IsValid() then
        return false
    end

    local components = item.components
    local deployable = components ~= nil and components.deployable or nil
    if components ~= nil
        and components.inventoryitem ~= nil
        and deployable ~= nil
        and deployable.GetDeployMode ~= nil then
        local completed, deploy_mode, issue = Callback.Run(
            "inventory plant GetDeployMode",
            deployable.GetDeployMode,
            {
                timeout_ms = M.PLANT_QUERY_CALLBACK_TIMEOUT_MS,
                instruction_limit =
                    M.PLANT_QUERY_CALLBACK_INSTRUCTION_LIMIT,
                hook_interval = M.PLANT_CALLBACK_HOOK_INTERVAL,
                quarantine_seconds = M.CLIENT_PLANT_METADATA_RETRY_TIME,
            },
            deployable
        )
        return completed
            and issue == nil
            and deploy_mode == DEPLOYMODE.PLANT
    end

    local inventory_item = item.replica ~= nil
        and item.replica.inventoryitem
        or nil
    if inventory_item == nil or inventory_item.GetDeployMode == nil then
        return false
    end

    local completed, deploy_mode, issue = Callback.Run(
        "inventory replica GetDeployMode",
        inventory_item.GetDeployMode,
        {
            timeout_ms = M.PLANT_QUERY_CALLBACK_TIMEOUT_MS,
            instruction_limit = M.PLANT_QUERY_CALLBACK_INSTRUCTION_LIMIT,
            hook_interval = M.PLANT_CALLBACK_HOOK_INTERVAL,
            quarantine_seconds = M.CLIENT_PLANT_METADATA_RETRY_TIME,
        },
        inventory_item
    )
    return completed
        and issue == nil
        and deploy_mode == DEPLOYMODE.PLANT
end

function M.ClampDimension(value)
    return Values.ClampInteger(
        value,
        M.MIN_DIMENSION,
        M.MAX_DIMENSION,
        M.MIN_DIMENSION
    )
end

function M.IsValidDimension(value)
    value = tonumber(value)
    return value ~= nil
        and value == math.floor(value)
        and value >= M.MIN_DIMENSION
        and value <= M.MAX_DIMENSION
end

function M.GetLayoutTileCount(dimension, spacing)
    dimension = tonumber(dimension)
    spacing = tonumber(spacing)
    if not Values.IsFiniteNumber(dimension)
        or not Values.IsFiniteNumber(spacing)
        or dimension < 1
        or spacing <= 0 then
        return nil
    end

    local footprint = dimension * spacing
    local adjusted_footprint = math.max(
        0,
        footprint - M.LAYOUT_EPSILON
    )
    return math.max(
        1,
        math.ceil(adjusted_footprint / M.TILE_SIZE)
    )
end

function M.IsValidLayoutFootprint(rows, columns, spacing)
    if not M.IsValidDimension(rows)
        or not M.IsValidDimension(columns)
        or not M.IsValidLayoutSpacing(spacing) then
        return false
    end

    local tile_rows = M.GetLayoutTileCount(rows, spacing)
    local tile_columns = M.GetLayoutTileCount(columns, spacing)
    return tile_rows ~= nil
        and tile_columns ~= nil
        and tile_rows <= M.MAX_LAYOUT_TILES_PER_AXIS
        and tile_columns <= M.MAX_LAYOUT_TILES_PER_AXIS
end

function M.GetMaximumDimensionForSpacing(spacing)
    if not M.IsValidLayoutSpacing(spacing) then
        return nil
    end

    return math.max(
        M.MIN_DIMENSION,
        math.min(
            M.MAX_DIMENSION,
            math.floor(
                (
                    M.MAX_LAYOUT_TILES_PER_AXIS * M.TILE_SIZE
                        + M.LAYOUT_EPSILON
                ) / tonumber(spacing)
            )
        )
    )
end

function M.ClampLayoutDimensions(rows, columns, spacing)
    rows = M.ClampDimension(rows)
    columns = M.ClampDimension(columns)
    local maximum = M.GetMaximumDimensionForSpacing(spacing)
    if maximum ~= nil then
        rows = math.min(rows, maximum)
        columns = math.min(columns, maximum)
    end
    return rows, columns
end

function M.IsFiniteCoordinate(value)
    value = tonumber(value)
    return value ~= nil
        and Values.IsFiniteNumber(value)
        and math.abs(value) < 100000
end

function M.IsValidSpacing(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value >= 0
        and value <= M.MAX_DEPLOY_SPACING
end

function M.IsValidLayoutSpacing(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value >= M.MIN_LAYOUT_SPACING
        and value <= M.MAX_LAYOUT_SPACING
end

function M.ResolvePlantSpacing(native_spacing)
    native_spacing = tonumber(native_spacing)
    if native_spacing == nil
        or not M.IsValidSpacing(native_spacing) then
        return nil
    end

    local native_plants_per_tile = math.floor(
        (M.TILE_SIZE + M.LAYOUT_EPSILON)
            / math.max(native_spacing, M.MIN_LAYOUT_SPACING)
    )
    local plants_per_tile = math.max(
        1,
        math.min(M.MAX_PLANTS_PER_TILE, native_plants_per_tile)
    )
    return M.TILE_SIZE / plants_per_tile
end

function M.IsValidRequestId(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value == math.floor(value)
        and value >= 1
        and value <= 2147483647
end

return M
