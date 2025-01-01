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

    self.RenderPos = Vector(0, 0, 3)
    self.RenderAng = Angle(-3, 0, 0)

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
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:SetMoveType(MOVETYPE_NONE)
    self:DestroyShadow()

    -- The bone manipulation below can fail if we don't setup our bones immediately. Whoops.
    self:SetupBones()
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
local eSetNextClientThink = ENTITY.SetNextClientThink
local aCurTime = CurTime
local haveLayeredSequencesBeenFixed = false
local lastBodygroupApply = 0
local lastModelScale = nil

function ENT:Think()
    local curModelScale = eGetModelScale(ply)

    if curModelScale != lastModelScale then
        eSetModelScale(self, curModelScale)
    end

    eSetRenderFX(self, eGetRenderFX(ply))
    eSetPos(self, eGetPos(ply))
    eSetAngles(self, pGetRenderAngles(ply))
    eSetSequence(self, eGetSequence(ply))

    -- COMMENT
    eSnatchModelInstance(self, ply)

    -- ISSUE: https://github.com/Facepunch/garrysmod-requests/issues/1723
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

    if curModelScale != lastModelScale then
        eInvalidateBoneCache(self)
    end

    lastModelScale = curModelScale

    local curTime = aCurTime()

    if lastBodygroupApply + 1.0 < curTime then
        for i = 1, eGetNumBodyGroups(ply) do
            eSetBodygroup(self, i, eGetBodygroup(ply, i))
        end

        lastBodygroupApply = curTime
    end

    -- Set the next think to run as soon as possible, i.e. the next frame.
    eSetNextClientThink(self, curTime)

    -- Apply NextThink call
    return true
end

local holster = GetConVar("holsterweapon_weapon")
local pInVehicle = PLAYER.InVehicle
local pGetAllowWeaponsInVehicle = PLAYER.GetAllowWeaponsInVehicle
local pGetActiveWeapon = PLAYER.GetActiveWeapon
local eGetClass = ENTITY.GetClass

local function IsHoldingWeaponInVehicle(ply)
    if !pInVehicle(ply) or !pGetAllowWeaponsInVehicle(ply) then
        return false
    end

    local wep = pGetActiveWeapon(ply)

    if !wep or wep == NULL then
        return false
    end

    if !holster then
        return true
    end

    local holsterClass = holster:GetString()

    if holsterClass == "" then
        holsterClass = "weaponholster"
    end

    return eGetClass(wep) != holsterClass
end

local legsEnabled = GetConVar("cl_legs")
local vLegsEnabled = CreateClientConVar("cl_vehlegs", 1, true, false, "Enable/Disable the rendering of the legs in vehicles", 0, 1)
local wLegsEnabled = CreateClientConVar("cl_legs_inwall", 1, true, false, "Enable/Disable the rendering ghostly legs inside walls.", 0, 1)
local pInVehicle = PLAYER.InVehicle

local function ShouldDrawInVehicle()
    if pInVehicle(ply) then
        return legsEnabled:GetBool() and vLegsEnabled:GetBool()
    end

    return true
end

local function ExternalShouldDraw(plyTable)
    -- TODO: Is prone mod compatible?
    return VWallrunning or inmantle or (pk_pills and pk_pills.getMappedEnt(ply)) or (plyTable.IsProne and plyTable.IsProne(ply)) or (VManip and VMLegs:IsActive())
end

local pAlive = PLAYER.Alive
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
                !IsHoldingWeaponInVehicle(ply)                                       and
                !pShouldDrawLocalPlayer(ply)                                         and
                !aIsValid(pGetObserverTarget(ply))                                   and
                !ExternalShouldDraw(plyTable)                                        and
                !plyTable.ShouldDisableLegs
    else
        return false
    end
end

local headBones = {
    ["ValveBiped.Bip01_Head1"] = true,
    ["ValveBiped.Bip01_Neck1"] = true
}

local bodyBones = {
    ["ValveBiped.Bip01_L_Hand"] = true,
    ["ValveBiped.Bip01_L_Forearm"] = true,
    ["ValveBiped.Bip01_L_Upperarm"] = true,
    ["ValveBiped.Bip01_L_Clavicle"] = true,
    ["ValveBiped.Bip01_R_Hand"] = true,
    ["ValveBiped.Bip01_R_Forearm"] = true,
    ["ValveBiped.Bip01_R_Upperarm"] = true,
    ["ValveBiped.Bip01_R_Clavicle"] = true,
    ["ValveBiped.Bip01_L_Finger4"] = true,
    ["ValveBiped.Bip01_L_Finger41"] = true,
    ["ValveBiped.Bip01_L_Finger42"] = true,
    ["ValveBiped.Bip01_L_Finger3"] = true,
    ["ValveBiped.Bip01_L_Finger31"] = true,
    ["ValveBiped.Bip01_L_Finger32"] = true,
    ["ValveBiped.Bip01_L_Finger2"] = true,
    ["ValveBiped.Bip01_L_Finger21"] = true,
    ["ValveBiped.Bip01_L_Finger22"] = true,
    ["ValveBiped.Bip01_L_Finger1"] = true,
    ["ValveBiped.Bip01_L_Finger11"] = true,
    ["ValveBiped.Bip01_L_Finger12"] = true,
    ["ValveBiped.Bip01_L_Finger0"] = true,
    ["ValveBiped.Bip01_L_Finger01"] = true,
    ["ValveBiped.Bip01_L_Finger02"] = true,
    ["ValveBiped.Bip01_R_Finger4"] = true,
    ["ValveBiped.Bip01_R_Finger41"] = true,
    ["ValveBiped.Bip01_R_Finger42"] = true,
    ["ValveBiped.Bip01_R_Finger3"] = true,
    ["ValveBiped.Bip01_R_Finger31"] = true,
    ["ValveBiped.Bip01_R_Finger32"] = true,
    ["ValveBiped.Bip01_R_Finger2"] = true,
    ["ValveBiped.Bip01_R_Finger21"] = true,
    ["ValveBiped.Bip01_R_Finger22"] = true,
    ["ValveBiped.Bip01_R_Finger1"] = true,
    ["ValveBiped.Bip01_R_Finger11"] = true,
    ["ValveBiped.Bip01_R_Finger12"] = true,
    ["ValveBiped.Bip01_R_Finger0"] = true,
    ["ValveBiped.Bip01_R_Finger01"] = true,
    ["ValveBiped.Bip01_R_Finger02"] = true,
    ["ValveBiped.Bip01_L_Wrist"] = true,
    ["ValveBiped.Bip01_L_Ulna"] = true,
    ["ValveBiped.Bip01_R_Wrist"] = true,
    ["ValveBiped.Bip01_R_Ulna"] = true,
    ["ValveBiped.Bip01_Head1"] = true,
    ["ValveBiped.Bip01_Neck1"] = true,
    ["ValveBiped.Bip01_Spine4"] = true,
    ["ValveBiped.Bip01_Spine2"] = true
}

local legBones = {
    ["ValveBiped.Bip01_Pelvis"] = true,
    ["ValveBiped.Bip01_Spine"] = true,
    ["ValveBiped.Bip01_Spine1"] = true,
    ["ValveBiped.Bip01_L_Thigh"] = true,
    ["ValveBiped.Bip01_L_Calf"] = true,
    ["ValveBiped.Bip01_L_Foot"] = true,
    ["ValveBiped.Bip01_L_Toe0"] = true,
    ["ValveBiped.Bip01_R_Thigh"] = true,
    ["ValveBiped.Bip01_R_Calf"] = true,
    ["ValveBiped.Bip01_R_Foot"] = true,
    ["ValveBiped.Bip01_R_Toe0"] = true,
    ["ValveBiped.Cod"] = true
}

local safeScaleBones = {
    ["ValveBiped.Bip01_Spine4"] = true,
    ["ValveBiped.Bip01_Spine2"] = true,
    ["ValveBiped.Bip01_L_Clavicle"] = true,
    ["ValveBiped.Bip01_R_Clavicle"] = true,
    ["ValveBiped.Bip01_L_Elbow"] = true,
    ["ValveBiped.Bip01_L_Shoulder"] = true,
    ["ValveBiped.Bip01_R_Elbow"] = true,
    ["ValveBiped.Bip01_R_Shoulder"] = true,
    ["ValveBiped.Bip01_Head1"] = true,
    ["ValveBiped.Bip01_Neck1"] = true
}

local stretchWorkaround = GetConVar("cl_legs_safebones")
local eGetBoneCount = ENTITY.GetBoneCount
local eGetBoneName = ENTITY.GetBoneName
local eManipulateBoneScale = ENTITY.ManipulateBoneScale
local eManipulateBonePosition = ENTITY.ManipulateBonePosition
local eManipulateBoneAngles = ENTITY.ManipulateBoneAngles
local invalidBone = "__INVALIDBONE__"
local normalScale, hidePos = Vector(1, 1, 1), Vector(0, -32, 0)
local infScale = Vector(math.huge, math.huge, math.huge)

function ENT:DoBoneManipulation()
    local boneCount = eGetBoneCount(self)
    local inVehicle = pInVehicle(ply)
    local scaleSafely = stretchWorkaround:GetBool()

    for i = 0, boneCount do
        eManipulateBoneScale(self, i, normalScale)
        eManipulateBonePosition(self, i, vector_origin)

        local name = eGetBoneName(self, i)

        if !name or name == invalidBone then
            continue
        end

        if scaleSafely and !bodyBones[name] then
            continue
        end

        if !scaleSafely and !inVehicle and legBones[name] and !safeScaleBones[name] then
            continue
        end

        if inVehicle and !headBones[name] then
            continue
        end

        local scale = safeScaleBones[name] and vector_origin or infScale

        -- This improves bone hiding in vehicles.
        if inVehicle then
            scale = infScale
        end

        if scaleSafely then
            scale = vector_origin
        end

        eManipulateBoneScale(self, i, scale)

        if !inVehicle and (safeScaleBones[boneID] or scaleSafely) then
            eManipulateBonePosition(self, i, hidePos)
            eManipulateBoneAngles(self, i, angle_zero)
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

local pGetViewOffset = PLAYER.GetViewOffset
local pGetViewOffsetDucked = PLAYER.GetViewOffsetDucked
local pGetCurrentViewOffset = PLAYER.GetCurrentViewOffset

local function GetDuckFraction(ply)
    local standingViewOffset, currentViewOffset = pGetViewOffset(ply), pGetCurrentViewOffset(ply)
    local heightDifference = standingViewOffset.z - pGetViewOffsetDucked(ply).z

    return (standingViewOffset.z - currentViewOffset.z) / heightDifference
end

local eIsFlagSet = ENTITY.IsFlagSet
local pGetVehicle = PLAYER.GetVehicle
local eGetAngles = ENTITY.GetAngles
local eEyeAngles = ENTITY.EyeAngles
local eGetMoveType = ENTITY.GetMoveType
local legsOffset = CreateClientConVar("cl_legs_offset", 20, true, false, "Offset of legs from you.", 10, 45)
local legsAngle = CreateClientConVar("cl_legs_angle", 2.5, true, false, "Angle of legs.", 0, 15)

function ENT:ApplyRenderOffset(pos, ang)
    local inVehicle = pInVehicle(ply)
    local onGround = eIsFlagSet(ply, FL_ONGROUND)

    if !inVehicle then
        local crouchProgress = GetDuckFraction(ply)
        local angleOffset = legsAngle:GetFloat()

        ang.x = -angleOffset

        if !onGround then
            crouchProgress = 0
        end

        pos.z = Lerp(crouchProgress, (pos.z - angleOffset * 0.2) + 8, pos.z)
    end

    if inVehicle then
        ang:Set(eGetAngles(pGetVehicle(ply)))
        ang:RotateAroundAxis(ang:Up(), 90)
    else
        -- Stop using sharpeye it sucks
        -- If you are an idiot and want compatibility, replace with var = sharpeye_focus and sharpeye_focus.GetBiaisViewAngles and sharpeye_focus:GetBiaisViewAngles() or ply:EyeAngles()
        local eyeAngles = eEyeAngles(ply)

        ang.y = eyeAngles.y

        local radAngle = math.rad(eyeAngles.y)
        local forwardOffset = -legsOffset:GetFloat()

        pos.x = pos.x + math.cos(radAngle) * forwardOffset
        pos.y = pos.y + math.sin(radAngle) * forwardOffset

        local isCrouching = eIsFlagSet(ply, FL_DUCKING)

        -- If we're crouching in the air and not noclipped, apply our duck offset.
        -- This prevents our legs from shifting downwards a lot.
        if !onGround and isCrouching and eGetMoveType(ply) != MOVETYPE_NOCLIP then
            pos.z = pos.z - 28
        end
    end
end

local eGetNWEntity = ENTITY.GetNWEntity
local eGetNWInt = ENTITY.GetNWInt

function ENT:ApplyGlidePose(legsTable)
    if !Glide then
        return
    end

    local vehicle = eGetNWEntity(ply, "GlideVehicle", NULL)

    if IsValid(vehicle) and vehicle != NULL then
        local seatIndex = eGetNWInt(ply, "GlideSeatIndex", 1)
        local pose = vehicle:GetSeatBoneManipulations(seatIndex)

        if pose then
            Glide.ApplyBoneManipulations(self, pose)
        end
    elseif legsTable.GlideHasPose then
        Glide.ResetBoneManipulations(self)
    end
end

local sShouldDraw = nil
local sApplyRenderOffset = nil
local sApplyGlidePose = nil
local eGetTable = ENTITY.GetTable
local rGetName = FindMetaTable("ITexture").GetName
local sLower = string.lower
local eSetRenderOrigin = ENTITY.SetRenderOrigin
local eSetRenderAngles = ENTITY.SetRenderAngles
local eGetColor = ENTITY.GetColor
local eDrawModel = ENTITY.DrawModel
local clipVector = vector_up * -1
local blockedRTs = {
    _rt_waterreflection = true,
    _rt_shadowdummy = true,
    _rt_camera = true
}
local jews = CreateClientConVar("cl_legs_clip", 1, true, false)

function ENT:DoRender(plyTable)
    local rt = render.GetRenderTarget()
    local rtName
    -- WORKAROUND: https://github.com/Facepunch/garrysmod-requests/issues/1943#issuecomment-1039511256
    if rt then
        rtName = sLower(rGetName(rt))

        if blockedRTs[rtName] then
            return
        end
    end

    local legsTable = eGetTable(self)

    legsTable.RenderPos:Set(eGetPos(ply))
    legsTable.RenderAng:Zero()

    sApplyRenderOffset = sApplyRenderOffset or legsTable.ApplyRenderOffset
    sApplyRenderOffset(self, legsTable.RenderPos, legsTable.RenderAng)

    plyTable = plyTable or eGetTable(ply)

    -- COMMENT
    sShouldDraw = sShouldDraw or legsTable.ShouldDraw

    if !sShouldDraw(self, plyTable) then
        legsTable.DidDraw = false

        return
    end

    legsTable.DidDraw = true

    sApplyGlidePose = sApplyGlidePose or legsTable.ApplyGlidePose
    sApplyGlidePose(self, legsTable)

    eSetRenderOrigin(self, legsTable.RenderPos)
    eSetRenderAngles(self, legsTable.RenderAng)

    local inVehicle = !stretchWorkaround:GetBool() and pInVehicle(ply)
    local renderColor, eyePos = eGetColor(ply), EyePos()
    local bEnabled = render.EnableClipping(true)

    -- Clips the upper half of the model.
    -- Not applied in vehicles because we only hide the player's head and neck bones when in one.
    if !inVehicle then
        render.PushCustomClipPlane(clipVector, clipVector:Dot(eyePos))
    end

    render.SetColorModulation(renderColor.r / 255, renderColor.g / 255, renderColor.b / 255)
        render.SetBlend(renderColor.a / 255)

            -- honestly just took the funny example off gmod wiki for blending
            if wLegsEnabled:GetBool() then
                local water = rtName != "_rt_waterrefraction"
                render.DepthRange(0.1, water and 0.01 or 1) -- eh it looks good enough tbh
                render.OverrideColorWriteEnable( true, false )
                eDrawModel(self)
                render.OverrideColorWriteEnable( false )
                render.SetBlend(render.GetBlend() * 0.8)
                eDrawModel(self)
                render.DepthRange(0, 1)
            end

            render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    render.PopCustomClipPlane()
        -- Draw our final legs model.
        eDrawModel(self)

        render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)

    if !inVehicle then
        render.PopCustomClipPlane()
    end

    render.EnableClipping(bEnabled)

    eSetRenderOrigin(self)
    eSetRenderAngles(self)
end

function ENT:DrawTranslucent(flags)
end

function ENT:OnReloaded()
    ply = LocalPlayer()
end