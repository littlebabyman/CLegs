AddCSLuaFile()

ENT.Type            = "anim"
ENT.PrintName       = "Firstperson Legs"
ENT.Author          = "afxnatic"
ENT.Information     = ""
ENT.Category        = "chicagoRP"

ENT.Spawnable       = false
ENT.AdminSpawnable  = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local PLAYER = FindMetaTable("Player")
local pGetPlayerColor = PLAYER.GetPlayerColor
local ply = nil

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
        return pGetPlayerColor(ply)
    end

    self:DrawShadow(false)
    self:SetAutomaticFrameAdvance(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:DestroyShadow()

    -- COMMENT
    self:DoBoneManipulation()
end

local ENTITY = FindMetaTable("Entity")
local eGetModelScale, eSetModelScale = ENTITY.GetModelScale, ENTITY.SetModelScale
local eGetRenderFX, eSetRenderFX = ENTITY.GetRenderFX, ENTITY.SetRenderFX
local eGetPos, eSetPos = ENTITY.GetPos, ENTITY.SetPos
local pGetRenderAngles, eSetAngles = PLAYER.GetRenderAngles, ENTITY.SetAngles
local eGetSequence, eSetSequence = ENTITY.GetSequence, ENTITY.SetSequence
local eSnatchModelInstance = ENTITY.SnatchModelInstance
local eGetCycle, eSetCycle = ENTITY.GetCycle, ENTITY.SetCycle
local eGetNumPoseParameters = ENTITY.GetNumPoseParameters
local eGetPoseParameterRange = ENTITY.GetPoseParameterRange
local eGetPoseParameter, eSetPoseParameter = ENTITY.GetPoseParameter, ENTITY.SetPoseParameter
local eInvalidateBoneCache = ENTITY.InvalidateBoneCache
local eGetNumBodyGroups = ENTITY.GetNumBodyGroups
local eGetBodygroup, eSetBodygroup = ENTITY.GetBodygroup, ENTITY.SetBodygroup
local pAlive = PLAYER.Alive
local eSetNextClientThink = ENTITY.SetNextClientThink
local aCurTime = CurTime
local haveLayeredSequencesBeenFixed = false
local wasAlive = false
local lastBodygroupApply = 0

function ENT:Think()
    eSetModelScale(self, eGetModelScale(ply))
    eSetRenderFX(self, eGetRenderFX(ply))
    eSetPos(self, eGetPos(ply))
    eSetAngles(self, pGetRenderAngles(ply))
    eSetSequence(self, eGetSequence(ply))

    -- COMMENT
    eSnatchModelInstance(self, ply)

    -- FIXME: https://github.com/Facepunch/garrysmod-requests/issues/1723
    if haveLayeredSequencesBeenFixed then
        self:CopyLayerSequenceInfo(0, ply)
        self:CopyLayerSequenceInfo(1, ply)
        self:CopyLayerSequenceInfo(2, ply)
        self:CopyLayerSequenceInfo(3, ply)
        self:CopyLayerSequenceInfo(4, ply)
        self:CopyLayerSequenceInfo(5, ply)
    end

    eSetCycle(self, eGetCycle(ply))

    for i = 0, eGetNumPoseParameters(ply) - 1 do
        local min, max = eGetPoseParameterRange(ply, i)

        eSetPoseParameter(self, i, math.Remap(eGetPoseParameter(ply, i), 0, 1, min, max))
    end

    eInvalidateBoneCache(self)

    local curTime = aCurTime()

    if lastBodygroupApply + 1.0 < curTime then
        for i = 1, eGetNumBodyGroups(ply) do
            eSetBodygroup(self, i, eGetBodygroup(ply, i))
        end

        lastBodygroupApply = curTime
    end

    local isAlive = pAlive(ply)

    if !wasAlive and isAlive then
        self:DoBoneManipulation()
    end

    wasAlive = isAlive

    -- Set the next think to run as soon as possible, i.e. the next frame.
    eSetNextClientThink(self, curTime)

    -- Apply NextThink call
    return true
end

local legsEnabled = GetConVar("cl_legs")
local vLegsEnabled = CreateClientConVar("cl_vehlegs", 0, true, false, "Enable/Disable the rendering of the legs in vehicles", 0, 1)
local pInVehicle = PLAYER.InVehicle

local function ShouldDrawInVehicle()
    if pInVehicle(ply) then
        return legsEnabled:GetBool() and vLegsEnabled:GetBool()
    end

    return true
end

local function ExternalShouldDraw(plyTable)
    return VWallrunning or inmantle or (pk_pills and pk_pills.getMappedEnt(ply)) or (plyTable.IsProne and plyTable.IsProne(ply))
end

local pShouldDrawLocalPlayer = PLAYER.ShouldDrawLocalPlayer
local pGetObserverTarget = PLAYER.GetObserverTarget
local aGetViewEntity = GetViewEntity
local aIsValid = IsValid

function ENT:ShouldDraw(plyTable)
    local shouldDisable = hook.Run("ShouldDisableLegs")

    if shouldDisable then
        return false
    end

    if legsEnabled:GetBool() then
        return  (pAlive(ply) or (plyTable.IsGhosted and plyTable.IsGhosted(ply)))    and
                ShouldDrawInVehicle()                                                and
                aGetViewEntity() == ply                                              and
                !pShouldDrawLocalPlayer(ply)                                         and
                !aIsValid(pGetObserverTarget(ply))                                   and
                !ExternalShouldDraw(plyTable)                                        and
                !plyTable.ShouldDisableLegs
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
    "ValveBiped.Bip01_Spine4",
    "ValveBiped.Bip01_Spine2"
}

local eGetBoneCount = ENTITY.GetBoneCount
local eManipulateBoneScale = ENTITY.ManipulateBoneScale
local eManipulateBonePosition = ENTITY.ManipulateBonePosition
local eManipulateBoneAngles = ENTITY.ManipulateBoneAngles
local eLookupBone = ENTITY.LookupBone
local bodyBonesCount = #bodyBones
local scaleVector, posVector = Vector(1, 1, 1), Vector(0, -128, 0)

function ENT:DoBoneManipulation()
    for i = 0, eGetBoneCount(self) do
        -- print("reseting bone: ", i)

        eManipulateBoneScale(self, i, scaleVector)
        eManipulateBonePosition(self, i, vector_origin)
    end

    local inVehicle = pInVehicle(ply)
    local bonesToRemove, removeCount = bodyBones, bodyBonesCount

    if inVehicle then
        bonesToRemove, removeCount = headBone, 2
    end

    for i = 1, removeCount do
        local boneID = bonesToRemove[i]
        local bone = eLookupBone(self, boneID)

        -- FIXME: bone stretching sucks (do custom clip plane?)
        if bone then
            eManipulateBoneScale(self, bone, vector_origin)

            if !inVehicle then
                eManipulateBonePosition(self, bone, posVector)
                eManipulateBoneAngles(self, bone, angle_zero)
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

local eGetTable = ENTITY.GetTable
local sShouldDraw = nil
local eDrawShadow = ENTITY.DrawShadow
local eDestroyShadow = ENTITY.DestroyShadow
local rGetName = FindMetaTable("ITexture").GetName
local sLower = string.lower
local pCrouching = PLAYER.Crouching
local pGetVehicle = PLAYER.GetVehicle
local eGetAngles = ENTITY.GetAngles
local eEyeAngles = ENTITY.EyeAngles
local eGetGroundEntity = ENTITY.GetGroundEntity
local pKeyDown = PLAYER.KeyDown
local eSetRenderOrigin = ENTITY.SetRenderOrigin
local eSetRenderAngles = ENTITY.SetRenderAngles
local eSetupBones = ENTITY.SetupBones
local eDrawModel = ENTITY.DrawModel
local legsOffset = CreateClientConVar("cl_legs_offset", 17, true, false, "Offset of legs from you.", 10, 30)
local legsAngle = CreateClientConVar("cl_legs_angle", 5, true, false, "Angle of legs model.", 0, 10)
local renderPos = Vector(0, 0, 3)
local renderAng = Angle(-3, 0, 0)
local clipVector = vector_up * -1
local waterRT = "_rt_waterreflection"
local dummyRT = "_rt_shadowdummy"
local cameraRT = "_rt_camera"

function ENT:DoRender(plyTable)
    local rt = render.GetRenderTarget()

    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        local rtName = sLower(rGetName(rt))

        if rtName == waterRT or rtName == dummyRT or rtName == cameraRT then
            return
        end
    end

    plyTable = plyTable or eGetTable(ply)

    -- COMMENT
    sShouldDraw = sShouldDraw or self.ShouldDraw

    if !sShouldDraw(self, plyTable) then
        return
    end

    -- COMMENT
    eDrawShadow(self, false)
    eDestroyShadow(self)

    local inVehicle = pInVehicle(ply)
    local isCrouching = pCrouching(ply)

    renderPos:Set(eGetPos(ply))
    renderAng:Zero()

    if !isCrouching and !inVehicle then
        local angleOffset = legsAngle:GetFloat()

        renderAng.x = -angleOffset

        renderPos.z = (renderPos.z - angleOffset * 0.2) + 5
    end

    if inVehicle then
        renderAng:Set(eGetAngles(pGetVehicle(ply)))
        renderAng:RotateAroundAxis(renderAng:Up(), 90)
    else
        -- y'all need to stop using sharpeye holy shit
        -- Original code: sharpeye_focus and sharpeye_focus.GetBiaisViewAngles and sharpeye_focus:GetBiaisViewAngles() or ply:EyeAngles()
        local biaisAngles = eEyeAngles(ply)

        renderAng.y = biaisAngles.y

        local radAngle = math.rad(biaisAngles.y)
        local forwardOffset = -legsOffset:GetFloat()

        renderPos.x = renderPos.x + math.cos(radAngle) * forwardOffset
        renderPos.y = renderPos.y + math.sin(radAngle) * forwardOffset
        renderPos.z = renderPos.z + 4

        if eGetGroundEntity(ply) == NULL and pKeyDown(ply, IN_DUCK) then
            renderPos.z = renderPos.z - 28
        end
    end

    eSetRenderOrigin(self, renderPos)
    eSetRenderAngles(self, renderAng)

    -- We have to do this, probably due to us manually drawing the entity multiple times.
    eSetupBones(self)

    local eyePos = EyePos()

    -- When we're too close to camera, render our model as half-visible.
    if isCrouching then
        render.SetBlend(0.33)

        eDrawModel(self)

        -- clipOffset: Vector(0, 0, -12)
        eyePos.z = eyePos.z - 12
    end

    local renderColor = ply:GetColor()

    -- TODO: Improve clipping in vehicles?
    local bEnabled = render.EnableClipping(true)
    render.PushCustomClipPlane(clipVector, clipVector:Dot(eyePos))
    render.SetColorModulation(renderColor.r / 255, renderColor.g / 255, renderColor.b / 255)
    render.SetBlend(renderColor.a / 255)

    -- Draw our final legs model.
    eDrawModel(self)

    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)
    render.PopCustomClipPlane()
    render.EnableClipping(bEnabled)

    eSetRenderOrigin(self)
    eSetRenderAngles(self)
end

function ENT:DrawTranslucent(flags)
end