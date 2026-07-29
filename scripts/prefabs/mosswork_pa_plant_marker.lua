local Shared = require("mosswork/planting_assistant/shared")

local function GetSourceVisual(source_item)
    local anim_state = source_item ~= nil and source_item.AnimState or nil
    if anim_state == nil
        or anim_state.GetBankHash == nil
        or anim_state.GetBuild == nil then
        return nil
    end

    local build = anim_state:GetBuild()
    if build == nil or build == "" then
        return nil
    end

    return {
        bank = anim_state:GetBankHash(),
        build = build,
        animation = "idle",
        scale = 1,
    }
end

local function SetPlant(inst, prefab, source_item)
    local visual = Shared.GetPlantVisual(prefab) or GetSourceVisual(source_item)
    local signature = visual ~= nil
        and string.format(
            "%s:%s:%s",
            tostring(prefab),
            tostring(visual.bank),
            tostring(visual.build)
        )
        or tostring(prefab)
    if inst.current_signature == signature then
        inst:Show()
        return
    end

    inst.current_signature = signature
    if visual == nil then
        inst:Hide()
        return
    end

    inst:Show()
    inst.AnimState:SetBank(visual.bank)
    inst.AnimState:SetBuild(visual.build)
    inst.AnimState:PlayAnimation(visual.animation, false)
    inst.Transform:SetScale(visual.scale, visual.scale, visual.scale)
end

local function SetPreviewState(inst, preview_state)
    if preview_state == "blocked" then
        inst.AnimState:SetMultColour(1, 0.18, 0.18, 0.68)
        inst.AnimState:SetAddColour(0.22, 0.02, 0.02, 0)
    elseif preview_state == "unchecked" then
        inst.AnimState:SetMultColour(1, 0.78, 0.2, 0.5)
        inst.AnimState:SetAddColour(0.12, 0.08, 0.01, 0)
    else
        inst.AnimState:SetMultColour(0.25, 1, 0.25, 0.58)
        inst.AnimState:SetAddColour(0.03, 0.18, 0.03, 0)
    end
end

local function MakeMarker()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.entity:SetCanSleep(false)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetFinalOffset(12)

    inst.SetPlant = SetPlant
    inst.SetPreviewState = SetPreviewState

    return inst
end

return Prefab(Shared.PREFAB_PLANT_MARKER, MakeMarker)
