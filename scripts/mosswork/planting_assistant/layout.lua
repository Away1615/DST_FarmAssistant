local Shared = require("mosswork/planting_assistant/shared")

local M = {}

function M.GetAnchorAtPoint(x, z)
    if TheWorld == nil or TheWorld.Map == nil then
        return nil, nil
    end

    local center_x, _, center_z = TheWorld.Map:GetTileCenterPoint(x, 0, z)
    if center_x == nil or center_z == nil then
        return nil, nil
    end

    local half_tile = Shared.TILE_SIZE * 0.5
    return center_x - half_tile, center_z - half_tile
end

local function CalculateTileCount(dimension, spacing)
    local footprint = math.max(0, dimension * spacing)
    local adjusted_footprint = math.max(
        0,
        footprint - Shared.LAYOUT_EPSILON
    )
    return math.max(
        1,
        math.ceil(adjusted_footprint / Shared.TILE_SIZE)
    )
end

function M.BuildFromAnchor(anchor_x, anchor_z, rows, columns, spacing)
    rows = Shared.ClampDimension(rows)
    columns = Shared.ClampDimension(columns)
    spacing = tonumber(spacing)

    if not Shared.IsFiniteCoordinate(anchor_x)
        or not Shared.IsFiniteCoordinate(anchor_z)
        or not Shared.IsValidLayoutFootprint(rows, columns, spacing) then
        return nil
    end

    anchor_x = tonumber(anchor_x)
    anchor_z = tonumber(anchor_z)
    if anchor_x == nil or anchor_z == nil then
        return nil
    end

    local first_offset = spacing * 0.5
    local points = {}
    for row = 1, rows do
        for column = 1, columns do
            points[#points + 1] = {
                index = #points + 1,
                row = row,
                column = column,
                x = anchor_x + first_offset + (column - 1) * spacing,
                z = anchor_z + first_offset + (row - 1) * spacing,
            }
        end
    end

    local tile_rows = CalculateTileCount(rows, spacing)
    local tile_columns = CalculateTileCount(columns, spacing)
    local tiles = {}

    for tile_row = 1, tile_rows do
        for tile_column = 1, tile_columns do
            tiles[#tiles + 1] = {
                x = anchor_x + (tile_column - 0.5) * Shared.TILE_SIZE,
                z = anchor_z + (tile_row - 0.5) * Shared.TILE_SIZE,
            }
        end
    end

    return {
        anchor_x = anchor_x,
        anchor_z = anchor_z,
        rows = rows,
        columns = columns,
        spacing = spacing,
        points = points,
        tiles = tiles,
    }
end

function M.BuildTraversalOrder(layout)
    local points = {}
    if layout == nil then
        return points
    end

    for row = 1, layout.rows do
        local first_index = (row - 1) * layout.columns + 1
        local last_index = first_index + layout.columns - 1
        if row % 2 == 1 then
            for index = first_index, last_index do
                points[#points + 1] = layout.points[index]
            end
        else
            for index = last_index, first_index, -1 do
                points[#points + 1] = layout.points[index]
            end
        end
    end
    return points
end

function M.HasPlannedConflict(planted_points, point, minimum_spacing)
    if type(planted_points) ~= "table"
        or point == nil
        or not Shared.IsValidSpacing(minimum_spacing) then
        return true
    end

    local minimum_distance_sq = minimum_spacing * minimum_spacing
    for _, planted in ipairs(planted_points) do
        local delta_x = point.x - planted.x
        local delta_z = point.z - planted.z
        if delta_x * delta_x + delta_z * delta_z
                + Shared.LAYOUT_EPSILON < minimum_distance_sq then
            return true
        end
    end
    return false
end

function M.Build(x, z, rows, columns, spacing)
    local anchor_x, anchor_z = M.GetAnchorAtPoint(x, z)
    if anchor_x == nil or anchor_z == nil then
        return nil
    end

    return M.BuildFromAnchor(anchor_x, anchor_z, rows, columns, spacing)
end

return M
