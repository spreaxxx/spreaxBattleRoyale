local QBCore = exports['qb-core']:GetCoreObject()

local zoneActive = false
local zoneStartTime = 0
local currentRadius = Config.InitialRadius
local minRadiusReached = false
local minRadiusReachedTime = 0

local function IsPlayerInCayo(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    return distance <= 3000.0 -- Raio aproximado de Cayo Perico
end

local function CalculateCurrentRadius()
    if not zoneActive then return Config.InitialRadius end
    if minRadiusReached and Config.StopAtMinRadius then
        return Config.FinalRadius
    end
    local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
    local progress = math.min(elapsedTime / Config.ZoneDuration, 1.0)
    local calculatedRadius = Config.InitialRadius - (Config.InitialRadius - Config.FinalRadius) * progress
    if calculatedRadius <= Config.FinalRadius and not minRadiusReached then
        minRadiusReached = true
        minRadiusReachedTime = GetGameTimer()
        TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_min_radius'], 'warning')
        if Config.Debug then
            print('[Cayo Battle Royale] Zona atingiu o raio mínimo: ' .. Config.FinalRadius .. 'm')
        end
        return Config.FinalRadius
    end
    return calculatedRadius
end

local function IsPlayerInSafeZone(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    return distance <= (currentRadius + 8.0)
end

local function EndZoneManually(source)
    if not zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_zone_active'], 'error')
        return false
    end
    zoneActive = false
    minRadiusReached = false
    minRadiusReachedTime = 0
    currentRadius = Config.InitialRadius
    TriggerClientEvent('spreaxBattleRoyale:endZone', -1)
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended_manually'], 'success')
    if Config.Debug then
        local Player = QBCore.Functions.GetPlayer(source)
        print('[Cayo Battle Royale] Zona finalizada manualmente por: ' .. (Player and Player.PlayerData.name or 'Desconhecido'))
    end
    return true
end

QBCore.Commands.Add(Config.Command, 'Iniciar zona de batalha em Cayo Perico', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end
    if not IsPlayerInCayo(source) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['not_in_cayo'], 'error')
        return
    end
    if zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['zone_active'], 'error')
        return
    end
    zoneActive = true
    zoneStartTime = GetGameTimer()
    currentRadius = Config.InitialRadius
    minRadiusReached = false
    minRadiusReachedTime = 0
    TriggerClientEvent('spreaxBattleRoyale:startZone', -1)
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_started'], 'primary')
    if Config.Debug then
        print('[Cayo Battle Royale] Zona iniciada por: ' .. Player.PlayerData.name)
    end
end, Config.Permission)

CreateThread(function()
    while true do
        if zoneActive then
            currentRadius = CalculateCurrentRadius()
            if not Config.StopAtMinRadius then
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                if elapsedTime >= Config.ZoneDuration then
                    zoneActive = false
                    minRadiusReached = false
                    minRadiusReachedTime = 0
                    TriggerClientEvent('spreaxBattleRoyale:endZone', -1)
                    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended'], 'success')
                    
                    if Config.Debug then
                        print('[Cayo Battle Royale] Zona finalizada automaticamente')
                    end
                end
            end
            local timeRemaining = 0
            if not minRadiusReached then
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                timeRemaining = math.max(Config.ZoneDuration - elapsedTime, 0)
            else
                timeRemaining = -1 
            end
            TriggerClientEvent('spreaxBattleRoyale:updateZone', -1, currentRadius, timeRemaining)
        end
        Wait(Config.UpdateInterval)
    end
end)

CreateThread(function()
    while true do
        if zoneActive then
            local players = QBCore.Functions.GetQBPlayers()
            
            for playerId, player in pairs(players) do
                if IsPlayerInCayo(playerId) then
                    local isInSafeZone = IsPlayerInSafeZone(playerId)
                    if not isInSafeZone then
                        TriggerClientEvent('spreaxBattleRoyale:applyDamage', playerId, Config.DamageAmount)
                        if Config.Debug then
                            local playerPed = GetPlayerPed(playerId)
                            local playerCoords = GetEntityCoords(playerPed)
                            local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
                            print('[Cayo Battle Royale] Enviando dano para jogador: ' .. playerId)
                            print('  - Nome: ' .. GetPlayerName(playerId))
                            print('  - Distância: ' .. math.floor(distance) .. 'm')
                            print('  - Raio zona: ' .. math.floor(currentRadius) .. 'm')
                        end
                    end
                end
            end
        end
        Wait(Config.DamageInterval)
    end
end)

RegisterNetEvent('spreaxBattleRoyale:requestZoneStatus', function()
    local source = source
    TriggerClientEvent('spreaxBattleRoyale:receiveZoneStatus', source, zoneActive, currentRadius)
end)

QBCore.Commands.Add(Config.EndCommand, 'Finalizar zona de batalha em Cayo Perico manualmente', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end
    EndZoneManually(source)
end, Config.Permission)