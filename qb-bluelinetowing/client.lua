local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = {}
local JobsComplete = 0
local NpcOn = false
local CurrentDestination = {}
local CurrentBlip = nil
local LastVehicle = 0
local VehicleSpawn = false
local selectedVeh = nil
local ranWorkThread = false

local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)

    if not DoesBlipExist(blip) then

        if GetBlipFromEntity(PlayerPedId()) ~= blip then    --Don't insert our own blip
            if NetworkIsPlayerActive(playerId) then
                blip = AddBlipForEntity(ped)
            else
                blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
            end
            SetBlipSprite(blip, 477)
            ShowHeadingIndicatorOnBlip(blip, true)
            SetBlipRotation(blip, math.ceil(playerLocation.w))
            SetBlipScale(blip, 1.0)
            if playerJob == "bltowing" then
                SetBlipColour(blip, 42)
            else
                SetBlipColour(blip, 5)
            end
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(playerLabel)
            EndTextCommandSetBlipName(blip)
            DutyBlips[#DutyBlips+1] = blip
        end
    end
end

RegisterNetEvent('qb-bluelinetowing:personalStash')
AddEventHandler('qb-bluelinetowing:personalStash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "bluelinetowstash_"..QBCore.Functions.GetPlayerData().citizenid)
    TriggerEvent("inventory:client:SetCurrentStash", "bluelinetowstash_"..QBCore.Functions.GetPlayerData().citizenid)
end)

RegisterNetEvent('qb-bluelinetowing:toggleDuty', function()
    onDuty = not onDuty
    TriggerServerEvent("QBCore:ToggleDuty")
    TriggerServerEvent("police:server:UpdateBlips")
end)

CreateThread(function()
    exports['qb-target']:AddTargetModel("p_amb_clipboard_01", {
        options = {
            {
                type = "client",
                event = "qb-bluelinetowing:toggleDuty",
                icon = "fas fa-sign-in-alt",
                label = "On/Off Duty",
                job = "bltowing"
            },
        },
        distance = 1.5
    })
end)

CreateThread(function()
    exports['qb-target']:AddBoxZone("BLTClothingStash", vector3(1765.33, 3321.72, 41.44), 1.6, 1.0, { name="BLTClothingStash", heading = 300, debugPoly=false, minZ=38.64, maxZ=42.64 },
        { options = { 
            { 
                type = "client",
                event = "qb-clothing:bltowing", 
                icon = "fas fa-male", 
                label = "Open Clothing Menu", 
                job = "bltowing"
            },
            { 
                type = "client",
                event = "qb-bluelinetowing:personalStash",
                icon = "fas fa-door-closed", 
                label = "Access Personal Stash", 
                job = "bltowing" 
            },
        }, 
        distance = 1.5
    })
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    onDuty = player.job.onduty

    if PlayerJob.name == "bltowing" then
        local TowVehBlip = AddBlipForCoord(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)
        SetBlipSprite(TowVehBlip, 326)
        SetBlipDisplay(TowVehBlip, 4)
        SetBlipScale(TowVehBlip, 0.6)
        SetBlipAsShortRange(TowVehBlip, true)
        SetBlipColour(TowVehBlip, 15)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Locations["vehicle"].label)
        EndTextCommandSetBlipName(TowVehBlip)

        RunWorkThread()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo

    if PlayerJob.name == "bltowing" then
        local TowVehBlip = AddBlipForCoord(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)
        SetBlipSprite(TowVehBlip, 326)
        SetBlipDisplay(TowVehBlip, 4)
        SetBlipScale(TowVehBlip, 0.6)
        SetBlipAsShortRange(TowVehBlip, true)
        SetBlipColour(TowVehBlip, 15)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Locations["vehicle"].label)
        EndTextCommandSetBlipName(TowVehBlip)

        RunWorkThread()
    end
end)

local function getRandomVehicleLocation()
    local randomVehicle = math.random(1, #Config.Locations["pickup"])
    while (randomVehicle == LastVehicle) do
        Wait(10)
        randomVehicle = math.random(1, #Config.Locations["pickup"])
    end
    return randomVehicle
end

local function deliverVehicle(vehicle)
    DeleteVehicle(vehicle)
    RemoveBlip(CurrentBlip2)
    --QBCore.Functions.Notify("You Have Delivered A Vehicle")
    JobsComplete = JobsComplete + 1
    VehicleSpawned = false
    NpcOn = false
    exports['okokNotify']:Alert("Nice!", "You Have Delivered A Vehicle", 5000, 'success')
    exports['okokNotify']:Alert("Time to get going!", "A New Vehicle Can Be Picked Up", 5000, 'info')

    local randomLocation = getRandomVehicleLocation()
    CurrentDestination.x = Config.Locations["pickup"][randomLocation].coords.x
    CurrentDestination.y = Config.Locations["pickup"][randomLocation].coords.y
    CurrentDestination.z = Config.Locations["pickup"][randomLocation].coords.z
    CurrentDestination.model = Config.Locations["pickup"][randomLocation].model
    CurrentDestination.id = randomLocation

    CurrentBlip = AddBlipForCoord(CurrentDestination.x, CurrentDestination.y, CurrentDestination.z)
    SetBlipColour(CurrentBlip, 3)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
end

local function getVehicleInDirection(coordFrom, coordTo)
	local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, PlayerPedId(), 0)
	local a, b, c, d, vehicle = GetRaycastResult(rayHandle)
	return vehicle
end

local function isFlatbedVehicle(vehicle)
    local retval = false
    for k, v in pairs(Config.Vehicles) do
        if GetEntityModel(vehicle) == GetHashKey(k) then
            retval = true
        end
    end
    return retval
end

local function DrawText3D(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function doCarDamage(currentVehicle)
	local smash = false
	local damageOutside = false
	local damageOutside2 = false
	local engine = 199.0
	local body = 149.0
	if engine < 200.0 then
		engine = 200.0
    end

    if engine  > 1000.0 then
        engine = 950.0
    end

	if body < 150.0 then
		body = 150.0
	end
	if body < 950.0 then
		smash = true
	end

	if body < 920.0 then
		damageOutside = true
	end

	if body < 920.0 then
		damageOutside2 = true
	end

    Wait(100)
    SetVehicleEngineHealth(currentVehicle, engine)
	if smash then
		SmashVehicleWindow(currentVehicle, 0)
		SmashVehicleWindow(currentVehicle, 1)
		SmashVehicleWindow(currentVehicle, 2)
		SmashVehicleWindow(currentVehicle, 3)
		SmashVehicleWindow(currentVehicle, 4)
	end
	if damageOutside then
		SetVehicleDoorBroken(currentVehicle, 1, true)
		SetVehicleDoorBroken(currentVehicle, 6, true)
		SetVehicleDoorBroken(currentVehicle, 4, true)
	end
	if damageOutside2 then
		SetVehicleTyreBurst(currentVehicle, 1, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 2, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 3, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 4, false, 990.0)
	end
	if body < 1000 then
		SetVehicleBodyHealth(currentVehicle, 985.1)
	end
end

-- Old Menu Code (being removed)

function utilmenu()
    local vehicleMenu = {
        {
            header = "Utility Truck Garage",
            isMenuHeader = true
        }
    }

    for k, v in pairs(Config.Vehicles) do
        vehicleMenu[#vehicleMenu+1] = {
            header = Config.Vehicles[k],
            params = {
                event = "bltowing:utilgarage",
                args = {
                    vehicle = k
                }
            }
        }
    end

    vehicleMenu[#vehicleMenu+1] = {
        header = "⬅ Close Menu",
        params = {
            event = "qb-menu:client:closeMenu"
        }

    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

local function CloseMenuFull()
    exports['qb-menu']:closeMenu()
end

-- Events

RegisterNetEvent('bltowing:client:utilmenu', function()
    utilmenu()
end)

RegisterNetEvent('bltowing:utilgarage')
AddEventHandler('bltowing:utilgarage', function(util)
    local vehicle = util.vehicle
    local coords = { ['x'] = 1733.74, ['y'] = 3300.81, ['z'] = 41.22, ['h'] = 189.04 } 
    QBCore.Functions.SpawnVehicle(vehicle, function(veh)
        SetVehicleNumberPlateText(veh, "BLTW"..tostring(math.random(1000, 9999)))
        exports['LegacyFuel']:SetFuel(veh, 100.0)
        SetEntityHeading(veh, coords.h)
        TaskWarpPedIntoVehicle(GetPlayerPed(-1), veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, coords, true)     
end)

RegisterNetEvent('bltowing:storevehicle')
AddEventHandler('bltowing:storevehicle', function()
    QBCore.Functions.Notify('Vehicle Stored!')
    local car = GetVehiclePedIsIn(PlayerPedId(),true)
    DeleteVehicle(car)
    DeleteEntity(car)
end)

RegisterNetEvent('bltowing:client:collectPayslip', function()
    if JobsComplete > 0 then
        RemoveBlip(CurrentBlip)
        TriggerServerEvent("bltowing:server:payslipInfo", JobsComplete)
        JobsComplete = 0
        NpcOn = false
    else
        QBCore.Functions.Notify("You didn't do any work.", "error")
    end
end)

RegisterNetEvent('jobs:client:ToggleNpc', function()
    if QBCore.Functions.GetPlayerData().job.name == "bltowing" then
        if CurrentTow ~= nil then
            exports['okokNotify']:Alert("Ooops!", "First Finish Your Work", 5000, 'error')
            return
        end
        NpcOn = true
        if NpcOn then
            RunWorkThread()
            local randomLocation = getRandomVehicleLocation()
            CurrentDestination.x = Config.Locations["pickup"][randomLocation].coords.x
            CurrentDestination.y = Config.Locations["pickup"][randomLocation].coords.y
            CurrentDestination.z = Config.Locations["pickup"][randomLocation].coords.z
            CurrentDestination.model = Config.Locations["pickup"][randomLocation].model
            CurrentDestination.id = randomLocation

            CurrentBlip = AddBlipForCoord(CurrentDestination.x, CurrentDestination.y, CurrentDestination.z)
            SetBlipColour(CurrentBlip, 3)
            SetBlipRoute(CurrentBlip, true)
            SetBlipRouteColour(CurrentBlip, 3)
        else
            if DoesBlipExist(CurrentBlip) then
                RemoveBlip(CurrentBlip)
                --CurrentDestination = {}
                CurrentBlip = nil
            end
            VehicleSpawned = false
        end
    end
end)

RegisterCommand("bltow", function(source,arg) 
TriggerEvent("bltowing:client:PutOnFlatbed")

end, false)

RegisterNetEvent('bltowing:client:PutOnFlatbed', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), true)
    if isFlatbedVehicle(vehicle) then
        if CurrentCar == nil then
            local playerped = PlayerPedId()
            local coordA = GetEntityCoords(playerped, 1)
            local coordB = GetOffsetFromEntityInWorldCoords(playerped, 0.0, 5.0, 0.0)
            local targetVehicle = getVehicleInDirection(coordA, coordB)

            if NpcOn and CurrentDestination ~= nil then
                if GetEntityModel(targetVehicle) ~= GetHashKey(CurrentDestination.model) then
                    exports['okokNotify']:Alert("Ooops!", "This Is Not The Right Vehicle", 5000, 'error')
                    return
                end
            end
            if not IsPedInAnyVehicle(PlayerPedId()) then
                if vehicle ~= targetVehicle then
                    NetworkRequestControlOfEntity(targetVehicle)
                    local towPos = GetEntityCoords(vehicle)
                    local targetPos = GetEntityCoords(targetVehicle)
                    if #(towPos - targetPos) < 11.0 then
                        QBCore.Functions.Progressbar("Towing_vehicle", "Hoisting the Vehicle...", 5000, false, true, {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        }, {
                            animDict = "mini@repair",
                            anim = "fixing_a_ped",
                            flags = 16,
                        }, {}, {}, function() -- Done
                            StopAnimTask(PlayerPedId(), "mini@repair", "fixing_a_ped", 1.0)
                            AttachEntityToEntity(targetVehicle, vehicle, GetEntityBoneIndexByName(vehicle, 'bodyshell'), 0.0, -1.5 + -0.85, 0.0 + 1.15, 0, 0, 0, 1, 1, 0, 1, 0, 1)
                            FreezeEntityPosition(targetVehicle, true)
                            CurrentCar = targetVehicle
                            if NpcOn then
                                RemoveBlip(CurrentBlip)
                                exports['okokNotify']:Alert("Time to move out!", "Take The Vehicle To Blue Line Towing Impound Lot", 5000, 'success')
                                CurrentBlip2 = AddBlipForCoord(Depots["bltowingimpound"].takeVehicle)
                                SetBlipColour(CurrentBlip2, 3)
                                SetBlipRoute(CurrentBlip2, true)
                                SetBlipRouteColour(CurrentBlip2, 3)
                                local chance = math.random(1,100)
                                if chance < 26 then
                                    TriggerServerEvent('bltowing:server:crypto')
                                end
                            end
                            exports['okokNotify']:Alert("Nice!", "Vehicle Towed", 5000, 'success')
                        end, function() -- Cancel
                            StopAnimTask(PlayerPedId(), "mini@repair", "fixing_a_ped", 1.0)
                            exports['okokNotify']:Alert("Sorry!", "Failed", 5000, 'error')
                        end)
                    end
                end
            end
        else
            QBCore.Functions.Progressbar("untowing_vehicle", "Removing The Vehicle", 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = "mini@repair",
                anim = "fixing_a_ped",
                flags = 16,
            }, {}, {}, function() -- Done
                StopAnimTask(PlayerPedId(), "mini@repair", "fixing_a_ped", 1.0)
                
                if NpcOn then
                    local targetPos = GetEntityCoords(CurrentCar)


                    if #(targetPos - vector3(Depots["bltowingimpound"].takeVehicle.x,Depots["bltowingimpound"].takeVehicle.y,Depots["bltowingimpound"].takeVehicle.z)) < 20.0 then
                        FreezeEntityPosition(CurrentCar, false)
                        Wait(250)
                        AttachEntityToEntity(CurrentCar, vehicle, 20, -0.0, -15.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
                        DetachEntity(CurrentCar, true, true)
                        SetVehicleOnGroundProperly(CurrentCar)
                        deliverVehicle(CurrentCar)
                        Wait(100)
                        if not DoesEntityExist(CurrentCar) then -- if the car doesnt exist, just then set it to nil
                            CurrentDestination = {}
                            CurrentCar = nil
                        end
                    else
                        exports['okokNotify']:Alert(("This is not the place where you need to put the vehicle you are %s meter away"):format(math.floor(#(targetPos - vector3(Depots["bltowingimpound"].takeVehicle.x, Depots["bltowingimpound"].takeVehicle.y, Depots["bltowingimpound"].takeVehicle.z)))), "Failed", 5000, 'error')
                    end
                end
              
            
                exports['okokNotify']:Alert("Nice!", "Vehicle Taken Off", 5000, 'success')
            end, function() -- Cancel
                StopAnimTask(PlayerPedId(), "mini@repair", "fixing_a_ped", 1.0)
                exports['okokNotify']:Alert("Sorry!", "Failed", 5000, 'error')
            end)
        end
    else
        exports['okokNotify']:Alert("Erm....!", "You Must Have Been In A Tow Vehicle First", 5000, 'error')
    end
end)

-- Threads
function RunWorkThread()
    CreateThread(function()
      
        local shownHeader = false
        -- while true and PlayerJob.name == "qb-bluelinetowing" do
        if PlayerJob.name == "bltowing" then
            local pos = GetEntityCoords(PlayerPedId())

            if NpcOn then
                print("not reading")
                VehicleSpawn = true
                QBCore.Functions.SpawnVehicle(CurrentDestination.model, function(veh)
                    exports['LegacyFuel']:SetFuel(veh, 0.0)
                    doCarDamage(veh)
                    print("spawned")
                end, CurrentDestination, true)

            end
        end
    end)
end
