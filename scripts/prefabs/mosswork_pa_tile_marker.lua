local assets = {
    Asset("ANIM", "anim/gridplacer.zip"),
}

local Shared = require("mosswork/planting_assistant/shared")

local function MakeMarker()
    local inst = CreateEntity()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim")
    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)

    return inst
end

return Prefab(Shared.PREFAB_TILE_MARKER, MakeMarker, assets)
