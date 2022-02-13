local QBCore = exports['qb-core']:GetCoreObject()
local PaymentTax = 10

RegisterNetEvent('bltowing:server:crypto', function()
    local xPlayer = QBCore.Functions.GetPlayer(tonumber(source))
	xPlayer.Functions.AddItem("cryptostick", 1, false)
	TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items["cryptostick"], "add")
end)

RegisterNetEvent('bltowing:server:payslipInfo', function(drops)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local drops = tonumber(drops)
    local bonus = 0
    local DropPrice = math.random(150, 170)
    if drops > 5 then
        bonus = math.ceil((DropPrice / 10) * 5)
    elseif drops > 10 then
        bonus = math.ceil((DropPrice / 10) * 7)
    elseif drops > 15 then
        bonus = math.ceil((DropPrice / 10) * 10)
    elseif drops > 20 then
        bonus = math.ceil((DropPrice / 10) * 12)
    end
    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * PaymentTax)
    local payment = price - taxAmount

    Player.Functions.AddJobReputation(1)
    Player.Functions.AddMoney("bank", payment, "bltowing-salary")
    TriggerClientEvent('chatMessage', source, "JOB", "warning", "You Received Your Salary From: $"..payment..", Gross: $"..price.." (From What $"..bonus.." Bonus) In $"..taxAmount.." Tax ("..PaymentTax.."%)")
end)

RegisterNetEvent('qb-tow:server:deliverVehicle', function(plate)
    local src = source
    local plate = QBCore.Shared.Trim(plate)
    local Player = QBCore.Functions.GetPlayer(src)
        DeleteVehicle(vehicle)
        RemoveBlip(CurrentBlip2)
        JobsDone = JobsDone + 1
        VehicleSpawned = false
end)

QBCore.Commands.Add("npc", "Toggle Npc Job", {}, false, function(source, args)
	TriggerClientEvent("jobs:client:ToggleNpc", source)
end)

QBCore.Commands.Add("putonflatbed", "Place A Car On The Back Of Your Flatbed", {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.name == "bltowing" then
        TriggerClientEvent("bltowing:client:PutOnFlatbed", source)
    end
end)
