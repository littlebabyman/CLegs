local ENTITY = FindMetaTable("Entity")
local entityGetModel = ENTITY.GetModel

local function GetLegModel(ply, plyTable)
    if CLIENT then
        local client = LocalPlayer()

        if plyTable.enforce_model then
            return plyTable.enforce_model
        end
    end

    return entityGetModel(ply)
end

function GetPlayerLegs(ply)
    local client = LocalPlayer()

    if ply and ply != client then
        return ply
    end

    local legEnt = ply.LegEnt

    if IsValid(legEnt) then
        return legEnt:ShouldDraw() and legEnt or client
    end
end

local eGetTable = ENTITY.GetTable

local function ConstructLegsEnt(ply, legModel)
    local plyTable = eGetTable(ply)
    local oldLegEnt = plyTable.LegEnt

    if IsValid(oldLegEnt) then
        oldLegEnt:Remove()
    end

    legModel = legModel or GetLegModel(ply, plyTable)

    local legEnt = ents.CreateClientside("firstperson_legs")
    legEnt:SetModel(legModel)
    legEnt:Spawn()

    plyTable.LegEnt = legEnt
end

local legsEnabled = CreateClientConVar("cl_legs", 1, true, false, "Enable/Disable the rendering of the legs", 0, 1)

hook.Add("InitPostEntity", "CLegs:LegInitialize", function()
    timer.Simple(0, function()
        if !legsEnabled:GetBool() then
            return
        end

        ConstructLegsEnt(LocalPlayer())
    end)
end)

local PLAYER = FindMetaTable("Player")
local plyAlive = PLAYER.Alive
local aIsValid = IsValid
local client = nil
local wasAlive = false

hook.Add("Think", "CLegs:ChangeModel", function()
    client = client or LocalPlayer()

    local plyTable = eGetTable(client)
    local legEnt, legModel = plyTable.LegEnt, GetLegModel(client, plyTable)
    local legsValid = aIsValid(legEnt)

    if legsValid and legModel != entityGetModel(legEnt) then
        ConstructLegsEnt(client, legModel)

        return
    end

    local isAlive = plyAlive(client)

    -- COMMENT
    if wasAlive and !isAlive then
        if legsValid then
            legEnt:Remove()
        end
    elseif !wasAlive and isAlive then
        ConstructLegsEnt(client, legModel)
    end

    wasAlive = isAlive
end)

hook.Add("PlayerSwitchWeapon", "CLegs:PlayerSwitchWeapon", function(ply, oldWep, newWep)
    if ply != LocalPlayer() then
        return
    end

    timer.Simple(0, function()
        if oldWep == newWep then
            return
        end

        local legEnt = ply.LegEnt

        if !aIsValid(legEnt) then
            return
        end

        legEnt:DoBoneManipulation()
    end)
end)

hook.Add("PlayerEnteredVehicle", "CLegs:VehicleSwitch", function(ply, veh)
    local legEnt = ply.LegEnt

    if !aIsValid(legEnt) then
        return
    end

    legEnt:DoBoneManipulation()
end)

hook.Add("PlayerLeaveVehicle", "CLegs:VehicleSwitch", function(ply, veh)
    local legEnt = ply.LegEnt

    if !aIsValid(legEnt) then
        return
    end

    legEnt:DoBoneManipulation()
end)

local pInVehicle = PLAYER.InVehicle

hook.Add("RenderScreenspaceEffects", "CLegs:Render::Vehicle", function()
    client = client or LocalPlayer()

    if pInVehicle(client) then
        local plyTable = eGetTable(client)
        local legEnt = plyTable.LegEnt

        if aIsValid(legEnt) then
            legEnt:DoRender(true, plyTable)
        end
    end
end)

concommand.Add("cl_togglelegs", function(ply, cmd, args, argStr)
    local newToggle = legsEnabled:GetBool() and 0 or 1

    RunConsoleCommand("cl_legs", newToggle)
end)

concommand.Add("cl_togglevlegs", function(ply, cmd, args, argStr)
    local newToggle = vLegsEnabled:GetBool() and 0 or 1

    RunConsoleCommand("cl_vehlegs", newToggle)
end)

concommand.Add("cl_refreshlegs", function(ply, cmd, args, argStr)
    ConstructLegsEnt(ply)
end)

local function LegsSettings(panel)
    panel:Help("Toggles - [CLIENT]")

    panel:CheckBox("Enable rendering of Legs?", "cl_legs")
    panel:CheckBox("Enable rendering of Legs in vehicles?", "cl_vehlegs")

    panel:Help("Offsets - [CLIENT]")

    panel:NumSlider("Camera Offset", "cl_legs_offset", 10, 30, 1)
    panel:NumSlider("Legs Angle", "cl_legs_angle", 0, 15, 1)
end

hook.Add("PopulateToolMenu", "CLegsMenuAdd", function()
    spawnmenu.AddToolMenuOption("Options", "CLegs", "CLegsSettings", "Settings", "", "", function(panel)
        panel:ClearControls()

        LegsSettings(panel)
    end)
end)