local ENTITY = FindMetaTable("Entity")
local entityGetModel = ENTITY.GetModel
local eGetTable = ENTITY.GetTable
local client, legEnt = nil

local function GetLegModel(ply, plyTable)
    if CLIENT then
        plyTable = plyTable or eGetTable(ply)

        if plyTable.enforce_model then
            return plyTable.enforce_model
        end
    end

    return entityGetModel(ply)
end

function GetPlayerLegs(ply)
    client = client or LocalPlayer()

    if ply and ply != client then
        return
    end

    return legEnt
end

local function ConstructLegsEnt(ply, legModel, plyTable)
    client = ply

    plyTable = plyTable or eGetTable(ply)

    if IsValid(legEnt) then
        plyTable.LegEnt = nil

        legEnt:Remove()
        legEnt = nil
    end

    legModel = legModel or GetLegModel(ply, plyTable)

    legEnt = ents.CreateClientside("firstperson_legs")
    legEnt:SetModel(legModel)
    legEnt:Spawn()

    plyTable.LegEnt = legEnt
end

local enabled = CreateClientConVar("cl_legs", 1, true, false, "Enable/Disable the rendering of the legs", 0, 1)

hook.Add("InitPostEntity", "CLegs.Initialize", function()
    timer.Simple(0, function()
        if !enabled:GetBool() then
            return
        end

        ConstructLegsEnt(LocalPlayer())
    end)
end)

local PLAYER = FindMetaTable("Player")
local plyAlive = PLAYER.Alive
local aIsValid = IsValid
local wasAlive = false

hook.Add("Think", "CLegs.ChangeModel", function()
    client = client or LocalPlayer()

    if client == NULL then
        client = nil

        return
    end

    if !enabled:GetBool() then
        return
    end

    local plyTable = eGetTable(client)
    local legModel = GetLegModel(client, plyTable)
    local legsValid = aIsValid(legEnt)

    if legsValid and legModel != entityGetModel(legEnt) then
        ConstructLegsEnt(client, legModel, plyTable)

        return
    end

    local isAlive = plyAlive(client)

    -- COMMENT
    if wasAlive and !isAlive then
        if legsValid then
            plyTable.LegEnt = nil

            legEnt:Remove()
            legEnt = nil
        end
    elseif !wasAlive and isAlive then
        ConstructLegsEnt(client, legModel, plyTable)
    end

    wasAlive = isAlive
end)

hook.Add("PlayerSwitchWeapon", "CLegs.InvalidateBones", function(ply, oldWep, newWep)
    if ply != LocalPlayer() then
        return
    end

    timer.Simple(0, function()
        if oldWep == newWep then
            return
        end

        if !aIsValid(legEnt) then
            return
        end

        legEnt:DoBoneManipulation()
    end)
end)

local function OnVehicleChange()
    if !aIsValid(legEnt) then
        return
    end

    legEnt:DoBoneManipulation()
end

local hasEntered = false
local wasInVehicle = false
local pInVehicle = PLAYER.InVehicle

hook.Add("Tick", "CLegs.VehicleSwitch", function()
    client = client or LocalPlayer()

    if client == NULL then
        client = nil

        return
    end

    local inVehicle = pInVehicle(client)

    if inVehicle and !hasEntered then
        OnVehicleChange()

        hasEntered = true
        wasInVehicle = true
    end

    if hasEntered and wasInVehicle and !inVehicle then
        OnVehicleChange()

        hasEntered = false
        wasInVehicle = false
    end
end)

local doRenderFunc = nil

hook.Add("PostDrawTranslucentRenderables", "CLegs.DoRender", function(bDepth, bSkybox, b3dSkybox)
    -- If we are attempting to draw in the skybox, don't.
    -- We do not include our legs in the depth buffer because they were ALWAYS next to our EyePos.
    if bSkybox or b3dSkybox then
        return
    end

    client = client or LocalPlayer()

    local plyTable = eGetTable(client)

    if aIsValid(legEnt) then
        doRenderFunc = doRenderFunc or legEnt.DoRender
        doRenderFunc(legEnt, plyTable)
    end
end)

cvars.AddChangeCallback("cl_legs", function(name, old, new)
    if old == new then
        return
    end

    local bool = new == "1" and true or false

    if bool then
        ConstructLegsEnt(LocalPlayer())
    else
        if IsValid(legEnt) then
            client.LegEnt = nil

            legEnt:Remove()
            legEnt = nil
        end
    end
end)

concommand.Add("cl_legs_toggle", function(ply, cmd, args, argStr)
    local newToggle = enabled:GetBool() and 0 or 1

    RunConsoleCommand("cl_legs", newToggle)
end)

concommand.Add("cl_legs_refresh", function(ply, cmd, args, argStr)
    ConstructLegsEnt(ply)
end)

local function LegsSettings(panel)
    panel:Help("Toggles")
    panel:CheckBox("Enable legs rendering?", "cl_legs")
    panel:CheckBox("Enable legs rendering in vehicles?", "cl_vehlegs")

    panel:Help("Offsets")
    panel:NumSlider("Camera Offset", "cl_legs_offset", 15, 45, 1)
    panel:NumSlider("Legs Angle", "cl_legs_angle", 0, 15, 1)
end

hook.Add("PopulateToolMenu", "CLegs.Settings", function()
    spawnmenu.AddToolMenuOption("Options", "CLegs", "CLegs", "Settings", "", "", function(panel)
        panel:ClearControls()

        LegsSettings(panel)
    end)
end)