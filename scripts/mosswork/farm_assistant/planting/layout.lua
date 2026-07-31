local Shared = require("mosswork/farm_assistant/planting/shared")

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

function M.BuildSpecFromAnchor(
    anchor_x,
    anchor_z,
    rows,
    columns,
    spacing
)
    anchor_x = tonumber(anchor_x)
    anchor_z = tonumber(anchor_z)
    rows = tonumber(rows)
    columns = tonumber(columns)
    spacing = tonumber(spacing)
    if not Shared.IsFiniteCoordinate(anchor_x)
        or not Shared.IsFiniteCoordinate(anchor_z)
        or not Shared.IsValidLayoutFootprint(rows, columns, spacing) then
        return nil
    end

    local tile_rows = Shared.GetLayoutTileCount(rows, spacing)
    local tile_columns = Shared.GetLayoutTileCount(columns, spacing)
    if tile_rows == nil
        or tile_columns == nil
        or tile_rows > Shared.MAX_LAYOUT_TILES_PER_AXIS
        or tile_columns > Shared.MAX_LAYOUT_TILES_PER_AXIS then
        return nil
    end

    return {
        anchor_x = anchor_x,
        anchor_z = anchor_z,
        rows = rows,
        columns = columns,
        spacing = spacing,
        candidate_count = rows * columns,
        tile_rows = tile_rows,
        tile_columns = tile_columns,
        tile_count = tile_rows * tile_columns,
    }
end

function M.BuildSpec(x, z, rows, columns, spacing)
    local anchor_x, anchor_z = M.GetAnchorAtPoint(x, z)
    if anchor_x == nil or anchor_z == nil then
        return nil
    end

    return M.BuildSpecFromAnchor(
        anchor_x,
        anchor_z,
        rows,
        columns,
        spacing
    )
end

function M.GetTraversalPoint(layout, traversal_index)
    if layout == nil then
        return nil
    end

    traversal_index = tonumber(traversal_index)
    if traversal_index == nil
        or traversal_index ~= math.floor(traversal_index)
        or traversal_index < 1
        or traversal_index > layout.candidate_count then
        return nil
    end

    local row = math.floor((traversal_index - 1) / layout.columns) + 1
    local row_offset = (traversal_index - 1) % layout.columns
    local column = row % 2 == 1
        and row_offset + 1
        or layout.columns - row_offset
    local first_offset = layout.spacing * 0.5

    return {
        index = (row - 1) * layout.columns + column,
        traversal_index = traversal_index,
        row = row,
        column = column,
        x = layout.anchor_x
            + first_offset
            + (column - 1) * layout.spacing,
        z = layout.anchor_z
            + first_offset
            + (row - 1) * layout.spacing,
    }
end

function M.GetTile(layout, tile_index)
    if layout == nil then
        return nil
    end

    tile_index = tonumber(tile_index)
    if tile_index == nil
        or tile_index ~= math.floor(tile_index)
        or tile_index < 1
        or tile_index > layout.tile_count then
        return nil
    end

    local tile_row =
        math.floor((tile_index - 1) / layout.tile_columns) + 1
    local tile_column = (tile_index - 1) % layout.tile_columns + 1
    return {
        x = layout.anchor_x
            + (tile_column - 0.5) * Shared.TILE_SIZE,
        z = layout.anchor_z
            + (tile_row - 0.5) * Shared.TILE_SIZE,
    }
end

return M
