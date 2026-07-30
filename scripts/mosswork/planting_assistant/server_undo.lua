local Shared = require("mosswork/planting_assistant/shared")
local Log = require("mosswork").Log.Create(Shared.MOD_ID)

local M = {}

local histories = setmetatable({}, { __mode = "k" })
local last_requests = setmetatable({}, { __mode = "k" })
local registered_players = setmetatable({}, { __mode = "k" })
local active_capture = nil

local function HasReferences(references)
    return type(references) == "table" and next(references) ~= nil
end

local function CopyValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, nested_value in pairs(value) do
        copy[CopyValue(key, seen)] = CopyValue(nested_value, seen)
    end
    return copy
end

local function GetSaveRecord(inst)
    if inst == nil
        or not inst:IsValid()
        or type(inst.GetSaveRecord) ~= "function" then
        return nil
    end

    local completed, record, references = pcall(
        inst.GetSaveRecord,
        inst
    )
    if not completed
        or type(record) ~= "table"
        or HasReferences(references) then
        return nil
    end
    return CopyValue(record)
end

local function SendUndoResult(player, reason)
    if player == nil
        or not player:IsValid()
        or player.userid == nil then
        return
    end

    SendModRPCToClient(
        GetClientModRPC(
            Shared.RPC_NAMESPACE,
            Shared.RPC_UNDO_RESULT
        ),
        player.userid,
        reason or "undo_internal"
    )
end

local function CancelExpiry(history)
    if history ~= nil and history.expire_task ~= nil then
        history.expire_task:Cancel()
        history.expire_task = nil
    end
end

function M.ClearHistory(player)
    local history = player ~= nil and histories[player] or nil
    if history == nil then
        return
    end

    histories[player] = nil
    CancelExpiry(history)
end

local function OnPlayerRemoved(player)
    M.ClearHistory(player)
    last_requests[player] = nil
    registered_players[player] = nil
end

local function RegisterPlayer(player)
    if registered_players[player] then
        return
    end

    registered_players[player] = true
    player:ListenForEvent("onremove", OnPlayerRemoved)
end

local function ExpireHistory(player)
    local history = histories[player]
    if history == nil then
        return
    end

    history.expire_task = nil
    if GetTime() >= history.expires_at then
        histories[player] = nil
    end
end

function M.CreateBatchHistory()
    return {
        entries = {},
        supported = true,
    }
end

function M.MarkBatchUnsupported(batch)
    local history = batch ~= nil and batch.undo_history or nil
    if history ~= nil then
        history.supported = false
    end
end

local function IsCapturedEntity(inst, capture)
    if inst == nil
        or not inst:IsValid()
        or inst.GUID == nil
        or inst.Transform == nil
        or inst.persists == false
        or inst:HasTag("INLIMBO") then
        return false
    end

    local x, _, z = inst.Transform:GetWorldPosition()
    local dx = x - capture.x
    local dz = z - capture.z
    return dx * dx + dz * dz
        <= Shared.UNDO_CAPTURE_RADIUS * Shared.UNDO_CAPTURE_RADIUS
end

local function BuildEntityRecord(inst)
    local save_record = GetSaveRecord(inst)
    if save_record == nil then
        return nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    return {
        guid = inst.GUID,
        entity = inst,
        prefab = inst.prefab,
        x = x,
        y = y,
        z = z,
    }
end

function M.BeginDeployment(
    batch,
    point,
    source_item,
    restore_item,
    previous_container,
    previous_slot
)
    local history = batch ~= nil and batch.undo_history or nil
    if history == nil or not history.supported then
        return nil
    end
    if active_capture ~= nil then
        history.supported = false
        active_capture.history.supported = false
        return nil
    end

    local source_record = nil
    if restore_item then
        source_record = GetSaveRecord(source_item)
        if source_record == nil then
            history.supported = false
            return nil
        end
    end

    local capture = {
        history = history,
        x = point.x,
        z = point.z,
        source_record = source_record,
        restore_item = restore_item == true,
        previous_container = previous_container,
        previous_slot = previous_slot,
        spawned = {},
    }
    active_capture = capture
    return capture
end

function M.TrackSpawnedEntity(inst)
    if active_capture ~= nil and inst ~= nil then
        active_capture.spawned[#active_capture.spawned + 1] = inst
    end
end

function M.EndDeployment(capture, succeeded)
    if capture == nil then
        return
    end
    if active_capture ~= capture then
        capture.history.supported = false
        return
    end

    active_capture = nil
    if not succeeded or not capture.history.supported then
        capture.history.supported = false
        return
    end

    local entities = {}
    local seen = {}
    for _, inst in ipairs(capture.spawned) do
        if IsCapturedEntity(inst, capture) and not seen[inst.GUID] then
            local entity_record = BuildEntityRecord(inst)
            if entity_record == nil then
                capture.history.supported = false
                return
            end
            seen[inst.GUID] = true
            entities[#entities + 1] = entity_record
        end
    end
    if #entities == 0 then
        capture.history.supported = false
        return
    end

    capture.history.entries[#capture.history.entries + 1] = {
        source_record = capture.source_record,
        restore_item = capture.restore_item,
        previous_container = capture.previous_container,
        previous_slot = capture.previous_slot,
        entities = entities,
    }
end

function M.FinalizeBatch(player, batch)
    local history = batch ~= nil and batch.undo_history or nil
    if batch ~= nil then
        batch.undo_history = nil
    end
    if history == nil or (batch.planted_count or 0) <= 0 then
        return
    end

    if not history.supported
        or #history.entries ~= batch.planted_count
        or player == nil
        or not player:IsValid() then
        SendUndoResult(player, "undo_unsupported")
        return
    end

    M.ClearHistory(player)
    RegisterPlayer(player)
    history.expires_at = GetTime() + Shared.UNDO_WINDOW
    histories[player] = history
    history.expire_task = player:DoTaskInTime(
        Shared.UNDO_WINDOW,
        ExpireHistory
    )
end

local function IsEntityStillPresent(entity_record)
    local inst = Ents ~= nil and Ents[entity_record.guid] or nil
    if inst == nil
        or inst ~= entity_record.entity
        or not inst:IsValid()
        or inst.prefab ~= entity_record.prefab
        or inst.Transform == nil then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local dx = x - entity_record.x
    local dy = y - entity_record.y
    local dz = z - entity_record.z
    return dx * dx + dy * dy + dz * dz
        <= Shared.UNDO_POSITION_EPSILON * Shared.UNDO_POSITION_EPSILON
end

local function ValidateHistory(history)
    local rollback_records = {}
    for _, entry in ipairs(history.entries) do
        for _, entity_record in ipairs(entry.entities) do
            if not IsEntityStillPresent(entity_record) then
                return nil, "undo_changed"
            end

            local save_record = GetSaveRecord(entity_record.entity)
            if save_record == nil then
                return nil, "undo_unsupported"
            end
            rollback_records[#rollback_records + 1] = {
                entity_record = entity_record,
                save_record = save_record,
            }
        end
    end
    return rollback_records, nil
end

local function PrepareRecordForPlayer(source_record, player)
    local record = CopyValue(source_record)
    local x, y, z = player.Transform:GetWorldPosition()
    record.x = x
    record.z = z
    record.y = y ~= 0 and y or nil
    record.puid = nil
    record.rx = nil
    record.ry = nil
    record.rz = nil
    return record
end

local function SpawnSourceItem(source_record, player)
    local record = PrepareRecordForPlayer(source_record, player)
    local completed, item = pcall(SpawnSaveRecord, record)
    if not completed
        or item == nil
        or not item:IsValid()
        or item.components == nil
        or item.components.inventoryitem == nil then
        if item ~= nil and item:IsValid() then
            item:Remove()
        end
        return nil
    end

    local removed = pcall(item.RemoveFromScene, item)
    if not removed then
        item:Remove()
        return nil
    end
    return item
end

local function RemoveItems(items)
    for _, value in ipairs(items) do
        local item = value.item or value
        if item ~= nil and item:IsValid() then
            item:Remove()
        end
    end
end

local function PrepareSourceItems(history, player)
    local items = {}
    for _, entry in ipairs(history.entries) do
        if entry.restore_item then
            local item = SpawnSourceItem(entry.source_record, player)
            if item == nil then
                RemoveItems(items)
                return nil
            end
            items[#items + 1] = {
                item = item,
                previous_container = entry.previous_container,
                previous_slot = entry.previous_slot,
            }
        end
    end
    return items
end

local function RestoreRemovedEntities(rollback_records)
    local restored_all = true
    for _, rollback in ipairs(rollback_records) do
        if not rollback.entity_record.entity:IsValid() then
            local completed, restored = pcall(
                SpawnSaveRecord,
                CopyValue(rollback.save_record)
            )
            if not completed
                or restored == nil
                or not restored:IsValid() then
                restored_all = false
            end
        end
    end
    return restored_all
end

local function RemoveHistoryEntities(rollback_records)
    for _, rollback in ipairs(rollback_records) do
        local inst = rollback.entity_record.entity
        local completed = pcall(inst.Remove, inst)
        if not completed or inst:IsValid() then
            return false
        end
    end
    return true
end

local function ContainerBelongsToPlayer(container, player)
    if container == nil or container.inst == nil then
        return false
    end
    if container.inst == player then
        return true
    end

    local inventory_item = container.inst.components ~= nil
        and container.inst.components.inventoryitem
        or nil
    return inventory_item ~= nil
        and inventory_item:GetGrandOwner() == player
end

local function IsHeldByPlayer(item, player)
    local inventory_item = item ~= nil
        and item:IsValid()
        and item.components ~= nil
        and item.components.inventoryitem
        or nil
    return inventory_item ~= nil
        and inventory_item:GetGrandOwner() == player
end

local function TryGiveItem(container, item, slot, player)
    if container == nil
        or type(container.GiveItem) ~= "function"
        or not ContainerBelongsToPlayer(container, player) then
        return false
    end

    local completed = pcall(
        container.GiveItem,
        container,
        item,
        slot
    )
    return completed
        and (not item:IsValid() or IsHeldByPlayer(item, player))
end

local function DropItemAtPlayer(item, player)
    if not item:IsValid() then
        return true
    end

    if type(item.ReturnToScene) == "function" then
        pcall(item.ReturnToScene, item)
    end
    if not item:IsValid() then
        return false
    end

    local x, y, z = player.Transform:GetWorldPosition()
    item.Transform:SetPosition(x, y, z)
    local inventory_item = item.components.inventoryitem
    if type(inventory_item.OnDropped) == "function" then
        pcall(inventory_item.OnDropped, inventory_item, true)
    end
    return item:IsValid() and not IsHeldByPlayer(item, player)
end

local function ReturnSourceItem(restored, player)
    local item = restored.item
    local inventory = player.components.inventory
    if TryGiveItem(
        restored.previous_container,
        item,
        restored.previous_slot,
        player
    ) or TryGiveItem(
        inventory,
        item,
        restored.previous_slot,
        player
    ) then
        return true
    end
    return DropItemAtPlayer(item, player)
end

local function ReturnSourceItems(items, player)
    local returned_all = true
    for _, restored in ipairs(items) do
        if not ReturnSourceItem(restored, player) then
            returned_all = false
        end
    end
    return returned_all
end

local function IsPlayerAvailable(player)
    return player ~= nil
        and player:IsValid()
        and player.Transform ~= nil
        and player.components ~= nil
        and player.components.inventory ~= nil
        and not player:HasTag("playerghost")
end

function M.HandleUndoRequest(player, planting_busy)
    if TheWorld == nil or not TheWorld.ismastersim or player == nil then
        return
    end

    local now = GetTime()
    local last_request = last_requests[player] or -math.huge
    if now - last_request < Shared.UNDO_REQUEST_INTERVAL then
        return
    end
    last_requests[player] = now

    if planting_busy then
        SendUndoResult(player, "undo_busy")
        return
    end
    if not IsPlayerAvailable(player) then
        SendUndoResult(player, "undo_unavailable")
        return
    end

    local history = histories[player]
    if history == nil then
        SendUndoResult(player, "undo_unavailable")
        return
    end
    if now > history.expires_at then
        M.ClearHistory(player)
        SendUndoResult(player, "undo_expired")
        return
    end

    local rollback_records, validation_reason =
        ValidateHistory(history)
    if rollback_records == nil then
        M.ClearHistory(player)
        SendUndoResult(player, validation_reason)
        return
    end

    local source_items = PrepareSourceItems(history, player)
    if source_items == nil then
        M.ClearHistory(player)
        Log:Error(
            "undo source restore preparation failed player=%s",
            tostring(player.userid or player.name or "unknown")
        )
        SendUndoResult(player, "undo_internal")
        return
    end

    M.ClearHistory(player)
    if not RemoveHistoryEntities(rollback_records) then
        local restored = RestoreRemovedEntities(rollback_records)
        RemoveItems(source_items)
        Log:Error(
            "undo entity removal failed player=%s rollback=%s",
            tostring(player.userid or player.name or "unknown"),
            tostring(restored)
        )
        SendUndoResult(player, "undo_internal")
        return
    end

    local returned = ReturnSourceItems(source_items, player)
    local result = returned and "undo_success" or "undo_internal"
    local write_log = returned and Log.Info or Log.Error
    write_log(
        Log,
        "undo finished player=%s result=%s plants=%d",
        tostring(player.userid or player.name or "unknown"),
        result,
        #history.entries
    )
    SendUndoResult(player, result)
end

return M
