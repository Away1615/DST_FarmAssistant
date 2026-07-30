local Request = require("mosswork/planting_assistant/server_request")
local Batch = require("mosswork/planting_assistant/server_batch")
local Undo = require("mosswork/planting_assistant/server_undo")

local M = {}

M.HandlePlantRequest = Request.HandlePlantRequest
M.BeginPlantRequest = Request.BeginPlantRequest
M.ExecuteBatchAction = Batch.ExecuteBatchAction
M.SetBatchAction = Batch.SetBatchAction
M.HasActiveBatch = Batch.HasActiveBatch
M.TrackUndoSpawnedEntity = Undo.TrackSpawnedEntity

function M.HandleUndoRequest(player)
    return Undo.HandleUndoRequest(
        player,
        Batch.HasActiveBatch(player)
    )
end

return M
