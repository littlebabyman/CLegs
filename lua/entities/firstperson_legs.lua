AddCSLuaFile()

ENT.Type            = "anim"
ENT.PrintName       = "Firstperson Legs"
ENT.Author          = "afxnatic"
ENT.Information     = ""
ENT.Category        = "chicagoRP"

ENT.Spawnable       = false
ENT.AdminSpawnable  = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local ply = ply or nil

function ENT:Initialize()
    -- COMMENT
    ply = LocalPlayer()

    self:SetRenderMode(RENDERMODE_NORMAL)

    local materials = ply:GetMaterials()

    for i = 1, #materials do
        self:SetSubMaterial(i - 1, ply:GetSubMaterial(i - 1))
    end

    self:SetSkin(ply:GetSkin())
    self:SetMaterial(ply:GetMaterial())
    self:SetColor(ply:GetColor())
    self.GetPlayerColor = function()
        return ply:GetPlayerColor()
    end

    self:DrawShadow(false)
    self:SetAutomaticFrameAdvance(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:DestroyShadow()

    -- COMMENT
    self:DoBoneManipulation()
end

local haveLayeredSequencesBeenFixed = false
local wasAlive = false
local lastBodygroupApply = 0

function ENT:Think()
    self:SetModelScale(ply:GetModelScale())
    self:SetRenderFX(ply:GetRenderFX())
    self:SetPos(ply:GetPos())
    self:SetAngles(ply:GetRenderAngles())
    self:SetSequence(ply:GetSequence())

    -- COMMENT
    self:SnatchModelInstance(ply)

    -- FIXME: https://github.com/Facepunch/garrysmod-requests/issues/1723
    if haveLayeredSequencesBeenFixed then
        self:CopyLayerSequenceInfo(0, ply)
        self:CopyLayerSequenceInfo(1, ply)
        self:CopyLayerSequenceInfo(2, ply)
        self:CopyLayerSequenceInfo(3, ply)
        self:CopyLayerSequenceInfo(4, ply)
        self:CopyLayerSequenceInfo(5, ply)
    end

    self:SetCycle(ply:GetCycle())

    for i = 0, ply:GetNumPoseParameters() - 1 do
        local min, max = ply:GetPoseParameterRange(i)

        self:SetPoseParameter(i, math.Remap(ply:GetPoseParameter(i), 0, 1, min, max))
    end

    self:InvalidateBoneCache()

    local curTime = CurTime()

    if lastBodygroupApply + 1.0 < curTime then
        for i = 1, ply:GetNumBodyGroups() do
            self:SetBodygroup(i, ply:GetBodygroup(i))
        end

        lastBodygroupApply = curTime
    end

    local isAlive = ply:Alive()

    if !wasAlive and isAlive then
        self:DoBoneManipulation()
    end

    wasAlive = isAlive

    -- Set the next think to run as soon as possible, i.e. the next frame.
    self:NextThink(curTime)

    -- Apply NextThink call
    return true
end

local legsEnabled = GetConVar("cl_legs")
local vLegsEnabled = CreateClientConVar("cl_vehlegs", 0, true, false, "Enable/Disable the rendering of the legs in vehicles", 0, 1)

local function ShouldDrawInVehicle(isExternalDraw)
    if ply:InVehicle() and isExternalDraw then
        return legsEnabled:GetBool() and !vLegsEnabled:GetBool()
    end

    return false
end

local function ExternalShouldDraw()
    return VWallrunning or inmantle or (pk_pills and pk_pills.getMappedEnt(ply)) or (ply.IsProne and ply:IsProne())
end

function ENT:ShouldDraw(isExternalDraw)
    local shouldDisable = hook.Run("ShouldDisableLegs")

    if shouldDisable then
        return false
    end

    if legsEnabled:GetBool() then
        return  (ply:Alive() or (ply.IsGhosted and ply:IsGhosted()))    and
                !ShouldDrawInVehicle(isExternalDraw)                    and
                GetViewEntity() == ply                                  and
                !ply:ShouldDrawLocalPlayer()                            and
                !IsValid(ply:GetObserverTarget())                       and
                !ExternalShouldDraw()                                   and
                !ply.ShouldDisableLegs
    else
        return false
    end
end

local headBone = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_Neck1"
}

local bodyBones = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_L_Upperarm",
    "ValveBiped.Bip01_L_Clavicle",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_R_Upperarm",
    "ValveBiped.Bip01_R_Clavicle",
    "ValveBiped.Bip01_L_Finger4",
    "ValveBiped.Bip01_L_Finger41",
    "ValveBiped.Bip01_L_Finger42",
    "ValveBiped.Bip01_L_Finger3",
    "ValveBiped.Bip01_L_Finger31",
    "ValveBiped.Bip01_L_Finger32",
    "ValveBiped.Bip01_L_Finger2",
    "ValveBiped.Bip01_L_Finger21",
    "ValveBiped.Bip01_L_Finger22",
    "ValveBiped.Bip01_L_Finger1",
    "ValveBiped.Bip01_L_Finger11",
    "ValveBiped.Bip01_L_Finger12",
    "ValveBiped.Bip01_L_Finger0",
    "ValveBiped.Bip01_L_Finger01",
    "ValveBiped.Bip01_L_Finger02",
    "ValveBiped.Bip01_R_Finger4",
    "ValveBiped.Bip01_R_Finger41",
    "ValveBiped.Bip01_R_Finger42",
    "ValveBiped.Bip01_R_Finger3",
    "ValveBiped.Bip01_R_Finger31",
    "ValveBiped.Bip01_R_Finger32",
    "ValveBiped.Bip01_R_Finger2",
    "ValveBiped.Bip01_R_Finger21",
    "ValveBiped.Bip01_R_Finger22",
    "ValveBiped.Bip01_R_Finger1",
    "ValveBiped.Bip01_R_Finger11",
    "ValveBiped.Bip01_R_Finger12",
    "ValveBiped.Bip01_R_Finger0",
    "ValveBiped.Bip01_R_Finger01",
    "ValveBiped.Bip01_R_Finger02",
    "ValveBiped.Bip01_Neck1",
    "ValveBiped.Bip01_Spine4"--,
    -- "ValveBiped.Bip01_Spine2"
}

local bodyBonesCount = #bodyBones
local scaleVector, posVector = Vector(1, 1, 1), Vector(0, -128, 0)

function ENT:DoBoneManipulation()
    for i = 0, self:GetBoneCount() do
        -- print("reseting bone: ", i)

        self:ManipulateBoneScale(i, scaleVector)
        self:ManipulateBonePosition(i, vector_origin)
    end

    local inVehicle = ply:InVehicle()
    local bonesToRemove, removeCount = bodyBones, bodyBonesCount

    if inVehicle then
        bonesToRemove, removeCount = headBone, 2
    end

    for i = 1, removeCount do
        local boneID = bonesToRemove[i]
        local bone = self:LookupBone(boneID)

        -- FIXME: bone stretching sucks (do custom clip plane?)
        if bone then
            self:ManipulateBoneScale(bone, vector_origin)

            if !inVehicle then
                self:ManipulateBonePosition(bone, posVector)
                self:ManipulateBoneAngles(bone, angle_zero)
            end
        end
    end
end

function ENT:CopyLayerSequenceInfo(layer, fromEnt)
    self:SetLayerSequence(layer, fromEnt:GetLayerSequence(layer))
    self:SetLayerDuration(layer, fromEnt:GetLayerDuration(layer))
    self:SetLayerPlaybackRate(layer, fromEnt:GetLayerPlaybackRate(layer))
    self:SetLayerWeight(layer, fromEnt:GetLayerWeight(layer))
    self:SetLayerCycle(layer, fromEnt:GetLayerCycle(layer))
end

local legsOffset = CreateClientConVar("cl_legs_offset", 17, true, false, "Offset of legs from you.", 10, 30)
local legsAngle = CreateClientConVar("cl_legs_angle", 5, true, false, "Angle of legs model.", 0, 10)
local renderPos = Vector(0, 0, 3)
local renderAng = Angle(-3, 0, 0)
local clipVector = vector_up * -1
local waterRT = "_rt_waterreflection"
local dummyRT = "_rt_shadowdummy"
local cameraRT = "_rt_camera"

function ENT:DoRender(isExternalDraw)
    if !self:ShouldDraw(isExternalDraw) then
        return
    end

    -- COMMENT
    self:DrawShadow(false)
    self:DestroyShadow()

    local rt = render.GetRenderTarget()

    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        local rtName = string.lower(rt:GetName())

        if rtName == waterRT or rtName == dummyRT or rtName == cameraRT then
            return
        end
    end

    local inVehicle = ply:InVehicle()
    local isCrouching = ply:Crouching()

    renderPos:Set(ply:GetPos())
    renderAng:Zero()

    if !isCrouching and !inVehicle then
        local angleOffset = legsAngle:GetFloat()

        renderAng.x = -angleOffset

        renderPos.z = (renderPos.z - angleOffset * 0.2) + 5
    end

    if inVehicle then
        renderAng:Set(ply:GetVehicle():GetAngles())
        renderAng:RotateAroundAxis(renderAng:Up(), 90)
    else
        -- y'all need to stop using sharpeye holy shit
        -- Original code: sharpeye_focus and sharpeye_focus.GetBiaisViewAngles and sharpeye_focus:GetBiaisViewAngles() or ply:EyeAngles()
        local biaisAngles = ply:EyeAngles()

        renderAng.y = biaisAngles.y

        local radAngle = math.rad(biaisAngles.y)
        local forwardOffset = -legsOffset:GetFloat()

        renderPos.x = renderPos.x + math.cos(radAngle) * forwardOffset
        renderPos.y = renderPos.y + math.sin(radAngle) * forwardOffset

        if ply:GetGroundEntity() == NULL then
            renderPos.z = renderPos.z + 4

            if ply:KeyDown(IN_DUCK) then
                renderPos.z = renderPos.z - 28
            end
        end
    end

    self:SetRenderOrigin(renderPos)
    self:SetRenderAngles(renderAng)

    -- We have to do this, probably due to us manually drawing the entity multiple times.
    self:SetupBones()

    local eyePos = EyePos()

    -- When we're too close to camera, render our model as half-visible.
    if isCrouching then
        render.SetBlend(0.33)

        self:DrawModel()

        -- clipOffset: Vector(0, 0, -12)
        eyePos.z = eyePos.z - 12
    end

    local renderColor = ply:GetColor()

    -- TODO: Improve clipping in vehicles
    local bEnabled = render.EnableClipping(true)
    render.PushCustomClipPlane(clipVector, clipVector:Dot(eyePos))
            render.SetColorModulation(renderColor.r / 255, renderColor.g / 255, renderColor.b / 255)
                render.SetBlend(renderColor.a / 255)
                        self:DrawModel()
                render.SetBlend(1)
            render.SetColorModulation(1, 1, 1)
        render.PopCustomClipPlane()
    render.EnableClipping(bEnabled)

    self:SetRenderOrigin()
    self:SetRenderAngles()
end

function ENT:DrawTranslucent(flags)
    self:DoRender(false)
end