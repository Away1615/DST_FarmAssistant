local Shared = require("mosswork/planting_assistant/shared")

local function SetPlant(inst, prefab)
    if inst.current_prefab == prefab then
        return
    end

    local plant = Shared.GetPlant(prefab)
    if plant == nil then
        return
    end

    inst.current_prefab = prefab
    inst.AnimState:SetBank(plant.bank)
    inst.AnimState:SetBuild(plant.build)
    inst.AnimState:PlayAnimation(plant.animation, false)
    inst.Transform:SetScale(plant.scale, plant.scale, plant.scale)
end

local function SetPreviewState(inst, preview_state)
    if preview_state == "blocked" then
        inst.AnimState:SetMultColour(1, 0.18, 0.18, 0.68)
        inst.AnimState:SetAddColour(0.22, 0.02, 0.02, 0)
    elseif preview_state == "missing" then
        inst.AnimState:SetMultColour(0.48, 0.48, 0.48, 0.48)
        inst.AnimState:SetAddColour(0.04, 0.04, 0.04, 0)
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
