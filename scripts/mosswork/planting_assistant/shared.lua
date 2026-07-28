local Values = require("mosswork").Values

local M = {}

M.MOD_ID = "mosswork.planting_assistant"
M.MOD_VERSION = "0.17.0"
M.MOSSWORK_API_VERSION = 3

M.RPC_NAMESPACE = "mosswork.planting_assistant"
M.RPC_PLANT = "plant"
M.RPC_RESULT = "result"
M.ACTION_PLAN_ID = "MOSSWORK_PA_PLAN_PLANT"
M.ACTION_BATCH_ID = "MOSSWORK_PA_BATCH_PLANT"
M.ACTION_MOVE_ID = "MOSSWORK_PA_MOVE_TO_PLANT"
M.PREFAB_PLANT_MARKER = "mosswork_pa_plant_marker"
M.PREFAB_TILE_MARKER = "mosswork_pa_tile_marker"

M.TILE_SIZE = 4
M.DEFAULT_ROWS = 1
M.DEFAULT_COLUMNS = 1
M.MIN_DIMENSION = 1
M.MAX_DIMENSION = 9
M.MAX_PLANTS_PER_BATCH = 81
M.MAX_REQUEST_DISTANCE = 8
M.PLACEMENT_GRID_OPACITY = 0.25
M.PLANT_SPACING_AUTO = "auto"
M.MIN_PLANT_SPACING = 1
M.MAX_PLANT_SPACING = 4
M.MAX_LAYOUT_EXTENT = M.MAX_DIMENSION * M.MAX_PLANT_SPACING
M.REQUEST_COOLDOWN = 1
M.REQUEST_TIMEOUT = 30
M.BATCH_HEARTBEAT_INTERVAL = 5
M.PREVIEW_INTERVAL = 0.1
M.VALIDATION_INTERVAL = 0.4
M.GLOBAL_PREFLIGHT_POINTS_PER_TICK = 16
M.PREFLIGHT_POINTS_PER_BATCH_TURN = 4
M.GLOBAL_PLANTS_PER_TICK = 8
M.PLANTS_PER_BATCH_TURN = 2
M.BATCH_WATCHDOG_INTERVAL = 1
M.BATCH_STALL_TIMEOUT = 20
M.BATCH_ACTION_STATE = "mosswork_pa_batch_plant"
M.BATCH_ACTION_PERFORM_FRAME = 10
M.BATCH_ACTION_DURATION_FRAMES = 16
M.ACTION_ARRIVE_DISTANCE = 1.5
M.ACTION_EXECUTION_DISTANCE = 4
M.BATCH_LEASH_DISTANCE = 6
M.LAYOUT_EPSILON = 0.0001
M.MIN_DEPLOY_SPACING = 0.1
M.MAX_DEPLOY_SPACING = 4

M.PLANTS = {
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

function M.GetPlant(prefab)
    return type(prefab) == "string" and M.PLANTS[prefab] or nil
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

function M.IsValidBatchSize(rows, columns)
    if not M.IsValidDimension(rows) or not M.IsValidDimension(columns) then
        return false
    end

    return tonumber(rows) * tonumber(columns) <= M.MAX_PLANTS_PER_BATCH
end

function M.IsValidLayoutFootprint(rows, columns, spacing)
    if not M.IsValidBatchSize(rows, columns)
        or not M.IsValidLayoutSpacing(spacing) then
        return false
    end

    spacing = tonumber(spacing)
    return tonumber(rows) * spacing
            <= M.MAX_LAYOUT_EXTENT + M.LAYOUT_EPSILON
        and tonumber(columns) * spacing
            <= M.MAX_LAYOUT_EXTENT + M.LAYOUT_EPSILON
end

function M.ClampLayoutDimensions(rows, columns, spacing, preferred)
    rows = M.ClampDimension(rows)
    columns = M.ClampDimension(columns)
    spacing = M.IsValidLayoutSpacing(spacing) and tonumber(spacing) or nil

    local function IsValid()
        return M.IsValidBatchSize(rows, columns)
            and (
                spacing == nil
                or M.IsValidLayoutFootprint(rows, columns, spacing)
            )
    end

    while not IsValid() do
        if preferred == "rows" and columns > M.MIN_DIMENSION then
            columns = columns - 1
        elseif preferred == "columns" and rows > M.MIN_DIMENSION then
            rows = rows - 1
        elseif columns >= rows and columns > M.MIN_DIMENSION then
            columns = columns - 1
        elseif rows > M.MIN_DIMENSION then
            rows = rows - 1
        elseif columns > M.MIN_DIMENSION then
            columns = columns - 1
        else
            break
        end
    end
    return rows, columns
end

function M.IsFiniteCoordinate(value)
    return Values.IsFiniteNumber(value)
        and math.abs(tonumber(value)) < 100000
end

function M.IsValidSpacing(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value >= M.MIN_DEPLOY_SPACING
        and value <= M.MAX_DEPLOY_SPACING
end

function M.IsValidPlantSpacingSetting(value)
    if value == M.PLANT_SPACING_AUTO then
        return true
    end

    value = tonumber(value)
    return value ~= nil
        and value == value
        and value == math.floor(value)
        and value >= M.MIN_PLANT_SPACING
        and value <= M.MAX_PLANT_SPACING
end

function M.NormalizePlantSpacingSetting(value)
    if not M.IsValidPlantSpacingSetting(value) then
        return M.PLANT_SPACING_AUTO
    end

    return value == M.PLANT_SPACING_AUTO
            and M.PLANT_SPACING_AUTO
        or tonumber(value)
end

function M.IsValidLayoutSpacing(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value >= M.MIN_PLANT_SPACING
        and value <= M.MAX_PLANT_SPACING
end

function M.ResolvePlantSpacing(setting, native_spacing)
    if not M.IsValidPlantSpacingSetting(setting) then
        return nil
    end

    if setting ~= M.PLANT_SPACING_AUTO then
        return tonumber(setting)
    end

    if not M.IsValidSpacing(native_spacing) then
        return nil
    end

    local maximum_plants_per_tile = math.max(
        1,
        math.floor(M.TILE_SIZE / M.MIN_PLANT_SPACING)
    )
    local native_plants_per_tile = math.floor(
        (M.TILE_SIZE + M.LAYOUT_EPSILON)
            / tonumber(native_spacing)
    )
    local plants_per_tile = math.max(
        1,
        math.min(maximum_plants_per_tile, native_plants_per_tile)
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
