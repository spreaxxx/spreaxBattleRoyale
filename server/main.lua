local QBCore = exports['qb-core']:GetCoreObject()

-- Variáveis globais
local zoneActive = false
local zoneStartTime = 0
local currentRadius = Config.InitialRadius
-- Adicionando variável para controlar se a zona atingiu o raio mínimo
local minRadiusReached = false
local minRadiusReachedTime = 0

-- Função para verificar se o jogador está em Cayo Perico
local function IsPlayerInCayo(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    return distance <= 3000.0 -- Raio aproximado de Cayo Perico
end

-- Modificando função para parar no raio mínimo
-- Função para calcular o raio atual da zona
local function CalculateCurrentRadius()
    if not zoneActive then return Config.InitialRadius end
    
    -- Se já atingiu o raio mínimo e a configuração permite parar, manter o raio final
    if minRadiusReached and Config.StopAtMinRadius then
        return Config.FinalRadius
    end
    
    local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
    local progress = math.min(elapsedTime / Config.ZoneDuration, 1.0)
    
    local calculatedRadius = Config.InitialRadius - (Config.InitialRadius - Config.FinalRadius) * progress
    
    -- Verificar se atingiu o raio mínimo pela primeira vez
    if calculatedRadius <= Config.FinalRadius and not minRadiusReached then
        minRadiusReached = true
        minRadiusReachedTime = GetGameTimer()
        
        -- Notificar todos os jogadores que a zona atingiu o raio mínimo
        TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_min_radius'], 'warning')
        
        if Config.Debug then
            print('[Cayo Battle Royale] Zona atingiu o raio mínimo: ' .. Config.FinalRadius .. 'm')
        end
        
        return Config.FinalRadius
    end
    
    return calculatedRadius
end

-- Função para verificar se o jogador está na zona segura
local function IsPlayerInSafeZone(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    
    -- Adicionando margem de tolerância de 5 metros para evitar falsos positivos
    return distance <= (currentRadius + 8.0)
end

-- Adicionando função para finalizar zona manualmente
-- Função para finalizar a zona manualmente
local function EndZoneManually(source)
    if not zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_zone_active'], 'error')
        return false
    end
    
    zoneActive = false
    minRadiusReached = false
    minRadiusReachedTime = 0
    currentRadius = Config.InitialRadius
    
    TriggerClientEvent('cayo-battleroyale:endZone', -1)
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended_manually'], 'success')
    
    if Config.Debug then
        local Player = QBCore.Functions.GetPlayer(source)
        print('[Cayo Battle Royale] Zona finalizada manualmente por: ' .. (Player and Player.PlayerData.name or 'Desconhecido'))
    end
    
    return true
end

-- Comando para iniciar a zona
QBCore.Commands.Add(Config.Command, 'Iniciar zona de batalha em Cayo Perico', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end
    
    -- Verificar permissão
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end
    
    -- Verificar se o jogador está em Cayo Perico
    if not IsPlayerInCayo(source) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['not_in_cayo'], 'error')
        return
    end
    
    -- Verificar se já existe uma zona ativa
    if zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['zone_active'], 'error')
        return
    end
    
    -- Resetando variáveis de controle do raio mínimo
    -- Iniciar zona
    zoneActive = true
    zoneStartTime = GetGameTimer()
    currentRadius = Config.InitialRadius
    minRadiusReached = false
    minRadiusReachedTime = 0
    
    -- Notificar todos os jogadores
    TriggerClientEvent('cayo-battleroyale:startZone', -1)
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_started'], 'primary')
    
    if Config.Debug then
        print('[Cayo Battle Royale] Zona iniciada por: ' .. Player.PlayerData.name)
    end
end, Config.Permission)

-- Modificando thread principal para não finalizar automaticamente quando no raio mínimo
-- Thread principal do servidor
CreateThread(function()
    while true do
        if zoneActive then
            currentRadius = CalculateCurrentRadius()
            
            -- Removendo finalização automática quando StopAtMinRadius está ativo
            -- Só finalizar automaticamente se não estiver configurado para parar no raio mínimo
            if not Config.StopAtMinRadius then
                -- Verificar se a zona terminou (comportamento original)
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                if elapsedTime >= Config.ZoneDuration then
                    zoneActive = false
                    minRadiusReached = false
                    minRadiusReachedTime = 0
                    TriggerClientEvent('cayo-battleroyale:endZone', -1)
                    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended'], 'success')
                    
                    if Config.Debug then
                        print('[Cayo Battle Royale] Zona finalizada automaticamente')
                    end
                end
            end
            
            -- Calculando tempo restante baseado no estado da zona
            local timeRemaining = 0
            if not minRadiusReached then
                -- Se ainda não atingiu o raio mínimo, mostrar tempo restante normal
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                timeRemaining = math.max(Config.ZoneDuration - elapsedTime, 0)
            else
                -- Se já atingiu o raio mínimo, mostrar que está aguardando finalização manual
                timeRemaining = -1 -- Valor especial para indicar "aguardando finalização manual"
            end
            
            -- Atualizar zona para todos os clientes
            TriggerClientEvent('cayo-battleroyale:updateZone', -1, currentRadius, timeRemaining)
        end
        
        Wait(Config.UpdateInterval)
    end
end)

-- Thread de dano
CreateThread(function()
    while true do
        if zoneActive then
            local players = QBCore.Functions.GetQBPlayers()
            
            for playerId, player in pairs(players) do
                if IsPlayerInCayo(playerId) then
                    local isInSafeZone = IsPlayerInSafeZone(playerId)
                    
                    -- Removido SetEntityHealth do servidor e movido lógica para cliente
                    if not isInSafeZone then
                        -- Enviar evento para o cliente aplicar o dano
                        TriggerClientEvent('cayo-battleroyale:applyDamage', playerId, Config.DamageAmount)
                        
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

-- Eventos
RegisterNetEvent('cayo-battleroyale:requestZoneStatus', function()
    local source = source
    TriggerClientEvent('cayo-battleroyale:receiveZoneStatus', source, zoneActive, currentRadius)
end)

-- Adicionando comando para finalizar zona manualmente
QBCore.Commands.Add(Config.EndCommand, 'Finalizar zona de batalha em Cayo Perico manualmente', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end
    
    -- Verificar permissão
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end
    
    -- Finalizar zona manualmente
    EndZoneManually(source)
end, Config.Permission)