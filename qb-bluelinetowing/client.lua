local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = {}
local JobsDone = 0
local NpcOn = false
local CurrentLocation = {}
local CurrentBlip = nil
local LastVehicle = 0
local VehicleSpawned = false
local selectedVeh = nil
local curentGarage = 2

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

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations["vehicle"][currentGarage]
    QBCore.Functions.SpawnVehicle(vehicleInfo, function(veh)
        SetVehicleNumberPlateText(veh, "BLTW"..tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        exports['LegacyFuel']:SetFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, coords, true)
end

function MenuGarage()
    local vehicleMenu = {
        {
            header = "Blue Line Towing Vehicles",
            isMenuHeader = true
        }
    }

    local authorizedVehicles = Config.AuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]
    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu+1] = {
            header = label,
            txt = "",
            params = {
                event = "bltowing:client:TakeOutVehicle",
                args = {
                    vehicle = veh
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu+1] = {
        header = "⬅ Close Menu",
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu"
        }

    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

RegisterNetEvent('bltowing:client:TakeOutVehicle', function(data)
    local vehicle = data.vehicle
    TakeOutVehicle(vehicle)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    onDuty = player.job.onduty
    TriggerServerEvent("police:server:UpdateBlips")
    TriggerServerEvent("bltowing:server:UpdateCurrentTows")

    if PlayerJob and PlayerJob.name ~= "bltowing" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent("bltowing:server:UpdateCurrentTows")
    onDuty = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    if DutyBlips then
        for k, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    TriggerServerEvent("police:server:UpdateBlips")
    if JobInfo.name == "bltowing" then
        if PlayerJob.onduty then
            TriggerServerEvent("QBCore:ToggleDuty")
            onDuty = false
        end
    end

    if (PlayerJob ~= nil) and PlayerJob.name ~= "bltowing" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('bltowing:client:ImpoundVehicle', function(fullImpound, price)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
    local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
    local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
    if vehicle ~= 0 and vehicle then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehpos = GetEntityCoords(vehicle)
        if #(pos - vehpos) < 5.0 and not IsPedInAnyVehicle(ped) then
            local plate = QBCore.Functions.GetPlate(vehicle)
            TriggerServerEvent("bltowing:server:Impound", plate, fullImpound, price, bodyDamage, engineDamage, totalFuel)
            QBCore.Functions.DeleteVehicle(vehicle)
        end
    end
end)



CreateThread(function()
    while true do
        sleep = 1000
        if LocalPlayer.state['isLoggedIn'] then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            if PlayerJob.name =="bltowing" then
                for k, v in pairs(Config.Locations["duty"]) do
                    local dist = #(pos - v)
                    if dist < 5 then
                        sleep = 0
                        if dist < 1.5 then
                            if onDuty then
                                DrawText3D(v.x, v.y, v.z, "~r~E~w~ - Go Off Duty")
                            else
                                DrawText3D(v.x, v.y, v.z, "~g~E~w~ - Go On Duty")
                            end
                            if IsControlJustReleased(0, 38) then
                                onDuty = not onDuty
                                TriggerServerEvent("QBCore:ToggleDuty")
                                TriggerServerEvent("police:server:UpdateBlips")
                            end
                        elseif dist < 4.5 then
                            DrawText3D(v.x, v.y, v.z, "On/Off Duty")
                        end
                    end
                end

                for k, v in pairs(Config.Locations["stash"]) do
                    local dist = #(pos - v)
                    if dist < 4.5 then
                        if onDuty then
                            if dist < 1.5 then
                                sleep = 0
                                DrawText3D(v.x, v.y, v.z, "~g~E~w~ - Personal Stash")
                                if IsControlJustReleased(0, 38) then
                                    TriggerServerEvent("inventory:server:OpenInventory", "stash", "bluelinetowingstash_"..QBCore.Functions.GetPlayerData().citizenid)
                                    TriggerEvent("inventory:client:SetCurrentStash", "bluelinetowingstash_"..QBCore.Functions.GetPlayerData().citizenid)
                                end
                            elseif dist < 2.5 then
                                DrawText3D(v.x, v.y, v.z, "Personal Stash")
                            end
                        end
                    end
                end

                for k, v in pairs(Config.Locations["parts"]) do
                    local dist = #(pos - v)
                    if dist < 4.5 then
                        if onDuty then
                            if dist < 1.5 then
                                sleep = 0
                                DrawText3D(v.x, v.y, v.z, "~g~E~w~ - Car Parts")
                                if IsControlJustReleased(0, 38) then
                                    TriggerServerEvent("inventory:server:OpenInventory", "shop", "bluelinetowing", Config.Items)
                                end
                            elseif dist < 2.5 then
                                DrawText3D(v.x, v.y, v.z, "Car Parts")
                            end
                        end
                    end
                end

                for k, v in pairs(Config.Locations["vehicle"]) do
                    local dist = #(pos - vector3(v.x, v.y, v.z))
                    if dist < 4.5 then
                        sleep = 0
                        DrawMarker(2, v.x, v.y, v.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)
                        if dist < 1.5 then
                            if IsPedInAnyVehicle(ped, false) then
                                DrawText3D(v.x, v.y, v.z, "~g~E~w~ - Store vehicle")
                            else
                                DrawText3D(v.x, v.y, v.z, "~g~E~w~ - Vehicles")
                            end
                            if IsControlJustReleased(0, 38) then
                                if IsPedInAnyVehicle(ped, false) then
                                    QBCore.Functions.DeleteVehicle(GetVehiclePedIsIn(ped))
                                else
                                    MenuGarage()
                                    currentGarage = k
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
        

CreateThread(function()
    for k, station in pairs(Config.Locations["stations"]) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 566)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 38)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)