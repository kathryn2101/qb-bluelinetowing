local QBCore = exports['qb-core']:GetCoreObject()


local function GetCurrentTows()
    local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "bltowing" and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    return amount
end

QBCore.Commands.Add("callsign", "Give Yourself A Callsign", {{name = "name", help = "Name of your callsign"}}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.SetMetaData("callsign", table.concat(args, " "))
end)

RegisterNetEvent('bltowing:server:UpdateCurrentTows', function()
    local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "bltowing" and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    TriggerClientEvent("bltowing:SetTowCount", -1, amount)
end)


CreateThread(function()
    while true do
        Wait(1000 * 60 * 10)
        local curTows = GetCurrentTows()
        TriggerClientEvent("bltowing:SetTowCount", -1, curTows)
    end
end)

QBCore.Commands.Add("depot", "Impound With Price", {{name = "price", help = "Price for how much the person has to pay (may be empty)"}}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "bltowing" and Player.PlayerData.job.onduty then
        TriggerClientEvent("bltowing:client:ImpoundVehicle", src, false, tonumber(args[1]))
    else
        TriggerClientEvent('QBCore:Notify', src, 'For on-duty tow or mechanic only', 'error')
    end
end)
