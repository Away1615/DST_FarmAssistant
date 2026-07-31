local Mosswork = require("mosswork")
local Values = Mosswork.Values
local FarmShared = require("mosswork/farm_assistant/shared")

local M = {}

M.MOD_ID = FarmShared.MOD_ID
M.MOD_VERSION = FarmShared.MOD_VERSION
M.MOSSWORK_API_VERSION = FarmShared.MOSSWORK_API_VERSION

M.RPC_NAMESPACE = "mosswork.farm_assistant.planting"
M.RPC_PLANT = "plant"
M.RPC_CONTROLLER_PLANT = "controller_plant"
M.RPC_RESULT = "result"
M.ACTION_PLANT_ID = "MOSSWORK_FARM_ASSISTANT_PLANT"
M.ACTION_PLANT_ONE_ID = "MOSSWORK_FARM_ASSISTANT_PLANT_ONE"
M.INPUT_ROWS_INCREASE = M.RPC_NAMESPACE .. ".rows_increase"
M.INPUT_ROWS_DECREASE = M.RPC_NAMESPACE .. ".rows_decrease"
M.INPUT_COLUMNS_INCREASE = M.RPC_NAMESPACE .. ".columns_increase"
M.INPUT_COLUMNS_DECREASE = M.RPC_NAMESPACE .. ".columns_decrease"
M.INPUT_CONFIRM = M.RPC_NAMESPACE .. ".confirm"
M.PREFAB_PLANT_MARKER = "mosswork_farm_assistant_plant_marker"
M.PREFAB_TILE_MARKER = "mosswork_farm_assistant_tile_marker"

M.TILE_SIZE = 4
M.DEFAULT_ROWS = 1
M.DEFAULT_COLUMNS = 1
M.MIN_DIMENSION = 1
M.MAX_DIMENSION = 9
M.MAX_LAYOUT_TILES_PER_AXIS = 9
M.MAX_PLANTS_PER_TILE = 4
M.PLACEMENT_GRID_OPACITY = 0.25
M.EXECUTION_MODE_BATCH = "batch"
M.EXECUTION_MODE_SEQUENTIAL = "sequential"
M.DEFAULT_EXECUTION_MODE = M.EXECUTION_MODE_BATCH
M.MIN_LAYOUT_SPACING = M.TILE_SIZE / M.MAX_PLANTS_PER_TILE
M.MAX_LAYOUT_SPACING = M.TILE_SIZE
M.MAX_DEPLOY_SPACING = 4
M.LAYOUT_EPSILON = 0.0001

M.REQUEST_TIMEOUT = 30
M.ACTION_ARRIVE_DISTANCE = 1.5
M.PLANT_ONE_ARRIVE_DISTANCE = 1.1
M.ACTION_EXECUTION_DISTANCE = 4
M.BATCH_LEASH_DISTANCE = 8

M.PREVIEW_INTERVAL = 0.1
M.VALIDATION_INTERVAL = 0.75
M.CLIENT_MARKERS_PER_TICK = 32
M.CLIENT_VALIDATION_POINTS_PER_TICK = 16
M.CLIENT_PREVIEW_TIME_BUDGET_MS = 4
M.CLIENT_VALIDATION_RETRY_TIME = 5
M.CLIENT_SLOW_CALLBACK_THRESHOLD_MS = 6

M.GLOBAL_PLANTS_PER_TICK = 4
M.PLANTS_PER_BATCH_TURN = 1
M.SCHEDULER_TIME_BUDGET_MS = 8
M.MAX_ACTIVE_BATCHES = 8
M.REJECTION_LOG_REPEAT_INTERVAL = 5

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

local function GetInventoryItemReplica(item)
    return item ~= nil
        and item:IsValid()
        and item.replica ~= nil
        and item.replica.inventoryitem
        or nil
end

function M.IsInventoryPlantable(item)
    local inventory_item = GetInventoryItemReplica(item)
    return inventory_item ~= nil
        and inventory_item:GetDeployMode() == DEPLOYMODE.PLANT
end

function M.GetInventoryPlantSpacing(item)
    local inventory_item = GetInventoryItemReplica(item)
    if inventory_item == nil
        or inventory_item:GetDeployMode() ~= DEPLOYMODE.PLANT then
        return nil
    end

    local spacing = inventory_item:DeploySpacingRadius()
    return M.IsValidSpacing(spacing) and spacing or nil
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

function M.ClampLayoutDimensions(rows, columns)
    return M.ClampDimension(rows), M.ClampDimension(columns)
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
    if not M.IsValidSpacing(native_spacing) then
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

function M.IsValidExecutionMode(value)
    return value == M.EXECUTION_MODE_BATCH
        or value == M.EXECUTION_MODE_SEQUENTIAL
end

function M.NormalizeExecutionMode(value)
    return M.IsValidExecutionMode(value)
            and value
        or M.DEFAULT_EXECUTION_MODE
end

return M
