local QBCore = exports['qb-core']:GetCoreObject()

-- Variáveis locais
local zoneActive = false
local currentRadius = Config.InitialRadius
local timeRemaining = 0
local zoneBlip = nil
local radiusBlip = nil
local minimapBlips = {}
local worldMarkers = {}
local lastMinimapUpdate = 0

-- Função para criar blips da zona
local function CreateZoneBlips()
    -- Remover blips existentes
    if zoneBlip then
        RemoveBlip(zoneBlip)
    end
    if radiusBlip then
        RemoveBlip(radiusBlip)
    end
    
    -- Criar blip central
    -- zoneBlip = AddBlipForCoord(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z)
    -- SetBlipSprite(zoneBlip, 84)
    -- SetBlipColour(zoneBlip, 1)
    -- SetBlipScale(zoneBlip, 1.0)
    -- SetBlipAsShortRange(zoneBlip, false)
    -- BeginTextCommandSetBlipName("STRING")
    -- AddTextComponentString("Zona de Batalha")
    -- EndTextCommandSetBlipName(zoneBlip)
    
    -- Criar blip de raio
    radiusBlip = AddBlipForRadius(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z, currentRadius)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 100)
end

-- Função para remover blips
local function RemoveZoneBlips()
    if zoneBlip then
        RemoveBlip(zoneBlip)
        zoneBlip = nil
    end
    if radiusBlip then
        RemoveBlip(radiusBlip)
        radiusBlip = nil
    end
end

-- Função para verificar se o jogador está na zona segura
local function IsPlayerInSafeZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    -- Adicionando margem de tolerância de 5 metros para evitar falsos positivos
    return distance <= (currentRadius + 15.0)
end

-- Função para verificar se o jogador está em Cayo Perico
local function IsPlayerInCayo()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    return distance <= 3000.0
end

-- Função para criar visualização no minimapa em tempo real
local function UpdateMinimapZone()
    if not Config.MinimapZone.enabled then return end
    
    local currentTime = GetGameTimer()
    if currentTime - lastMinimapUpdate < Config.MinimapZone.updateInterval then
        return
    end
    lastMinimapUpdate = currentTime
    
    -- Limpar blips antigos do minimapa
    for _, blip in pairs(minimapBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    minimapBlips = {}
    
    if not zoneActive then return end
    
    -- Criar múltiplos blips para formar um círculo no minimapa
    local segments = 32
    for i = 1, segments do
        local angle = (i / segments) * 2 * math.pi
        local x = Config.CayoCenter.x + math.cos(angle) * currentRadius
        local y = Config.CayoCenter.y + math.sin(angle) * currentRadius
        
        local blip = AddBlipForCoord(x, y, Config.CayoCenter.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.3)
        SetBlipAlpha(blip, Config.MinimapZone.blipAlpha)
        SetBlipAsShortRange(blip, false)
        
        table.insert(minimapBlips, blip)
    end
end

-- Função para renderizar zona no mundo 3D
local function RenderWorldZone()
    if not Config.WorldZone.enabled or not zoneActive then return end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    
    -- Só renderizar se estiver próximo o suficiente
    if distance > Config.WorldZone.renderDistance then return end
    
    -- Renderizar zona fechada (área vermelha fora da zona segura)
    local segments = 64
    local maxRadius = Config.InitialRadius
    
    for i = 1, segments do
        local angle1 = (i / segments) * 2 * math.pi
        local angle2 = ((i + 1) / segments) * 2 * math.pi
        
        -- Zona fechada (fora da zona segura)
        if currentRadius < maxRadius then
            -- Ponto interno (borda da zona segura)
            local x1_inner = Config.CayoCenter.x + math.cos(angle1) * currentRadius
            local y1_inner = Config.CayoCenter.y + math.sin(angle1) * currentRadius
            local x2_inner = Config.CayoCenter.x + math.cos(angle2) * currentRadius
            local y2_inner = Config.CayoCenter.y + math.sin(angle2) * currentRadius
            
            -- Ponto externo (borda máxima)
            local x1_outer = Config.CayoCenter.x + math.cos(angle1) * maxRadius
            local y1_outer = Config.CayoCenter.y + math.sin(angle1) * maxRadius
            local x2_outer = Config.CayoCenter.x + math.cos(angle2) * maxRadius
            local y2_outer = Config.CayoCenter.y + math.sin(angle2) * maxRadius
            
            -- Desenhar zona fechada (vermelha)
            DrawPoly(
                x1_inner, y1_inner, playerCoords.z + 50.0,
                x2_inner, y2_inner, playerCoords.z + 50.0,
                x1_outer, y1_outer, playerCoords.z + 50.0,
                Config.WorldZone.closedZoneColor.r,
                Config.WorldZone.closedZoneColor.g,
                Config.WorldZone.closedZoneColor.b,
                Config.WorldZone.closedZoneColor.a
            )
            
            DrawPoly(
                x2_inner, y2_inner, playerCoords.z + 50.0,
                x2_outer, y2_outer, playerCoords.z + 50.0,
                x1_outer, y1_outer, playerCoords.z + 50.0,
                Config.WorldZone.closedZoneColor.r,
                Config.WorldZone.closedZoneColor.g,
                Config.WorldZone.closedZoneColor.b,
                Config.WorldZone.closedZoneColor.a
            )
        end
        
        -- Zona segura (verde muito suave)
        local x1_safe = Config.CayoCenter.x + math.cos(angle1) * currentRadius
        local y1_safe = Config.CayoCenter.y + math.sin(angle1) * currentRadius
        local x2_safe = Config.CayoCenter.x + math.cos(angle2) * currentRadius
        local y2_safe = Config.CayoCenter.y + math.sin(angle2) * currentRadius
        
        DrawPoly(
            Config.CayoCenter.x, Config.CayoCenter.y, playerCoords.z + 10.0,
            x1_safe, y1_safe, playerCoords.z + 10.0,
            x2_safe, y2_safe, playerCoords.z + 10.0,
            Config.WorldZone.safeZoneColor.r,
            Config.WorldZone.safeZoneColor.g,
            Config.WorldZone.safeZoneColor.b,
            Config.WorldZone.safeZoneColor.a
        )
    end
    
    -- Removidos os pilares verdes da borda da zona segura
    -- Código dos DrawMarker removido completamente
end

-- Thread principal do cliente
CreateThread(function()
    while true do
        if zoneActive and IsPlayerInCayo() then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
            
            -- Renderizar zona no mundo 3D
            RenderWorldZone()
            
            -- Desenhar círculo da zona
            DrawMarker(1, Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z - 100.0, 
                      0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                      currentRadius * 2, currentRadius * 2, 200.0, 
                      Config.ZoneColor.r, Config.ZoneColor.g, Config.ZoneColor.b, Config.ZoneColor.a, 
                      false, true, 2, false, nil, nil, false)
            
            -- Movendo informações da zona para o centro da tela
            if timeRemaining > 0 then
                local minutes = math.floor(timeRemaining / 60)
                local seconds = math.floor(timeRemaining % 60)
                local timeText = string.format("%02d:%02d", minutes, seconds)
                
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.6, 0.6)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("Zona: " .. math.floor(currentRadius) .. "m | Tempo: " .. timeText)
                DrawText(0.5, 0.05)
            elseif timeRemaining == -1 then
                -- Caso especial: zona no raio mínimo aguardando finalização manual
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.6, 0.6)
                SetTextColour(255, 255, 0, 255) -- Amarelo para indicar estado especial
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("ZONA FINAL")
                DrawText(0.5, 0.05)
            end
            
            -- Avisar se o jogador está fora da zona
            if not IsPlayerInSafeZone() then
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.7, 0.7)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("ESTÁS FORA DA ZONA SEGURA!")
                DrawText(0.5, 0.1)
            end
        end
        
        Wait(0)
    end
end)

-- Thread de atualização de tempo
CreateThread(function()
    while true do
        if zoneActive and timeRemaining > 0 then
            timeRemaining = timeRemaining - 1
        end
        -- Não decrementar quando timeRemaining == -1 (estado especial)
        Wait(1000)
    end
end)

-- Thread para atualização do minimapa
CreateThread(function()
    while true do
        if zoneActive then
            UpdateMinimapZone()
        end
        Wait(Config.MinimapZone.updateInterval)
    end
end)

-- Eventos do servidor
RegisterNetEvent('cayo-battleroyale:startZone', function()
    zoneActive = true
    currentRadius = Config.InitialRadius
    timeRemaining = Config.ZoneDuration
    CreateZoneBlips()
    
    if Config.Debug then
        print('[Cayo Battle Royale] Zona iniciada no cliente')
    end
end)

RegisterNetEvent('cayo-battleroyale:updateZone', function(newRadius, newTimeRemaining)
    currentRadius = newRadius
    timeRemaining = newTimeRemaining
    
    -- Atualizar blip de raio
    if radiusBlip then
        RemoveBlip(radiusBlip)
        radiusBlip = AddBlipForRadius(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z, currentRadius)
        SetBlipColour(radiusBlip, 1)
        SetBlipAlpha(radiusBlip, 100)
    end
    
    if Config.Debug then
        print('[Cayo Battle Royale] Zona atualizada: ' .. currentRadius .. 'm')
    end
end)

RegisterNetEvent('cayo-battleroyale:endZone', function()
    zoneActive = false
    currentRadius = Config.InitialRadius
    timeRemaining = 0
    RemoveZoneBlips()
    
    -- Limpar blips do minimapa
    for _, blip in pairs(minimapBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    minimapBlips = {}
    
    if Config.Debug then
        print('[Cayo Battle Royale] Zona finalizada no cliente')
    end
end)

RegisterNetEvent('cayo-battleroyale:receiveZoneStatus', function(active, radius)
    zoneActive = active
    currentRadius = radius
    
    if active then
        CreateZoneBlips()
    else
        RemoveZoneBlips()
    end
end)

-- Evento para efeito visual de dano
RegisterNetEvent('cayo-battleroyale:takeDamage', function(damageAmount)
    -- Removido todos os efeitos visuais e sonoros de dano
    -- Apenas manter o debug se necessário
    if Config.Debug then
        print('[Cayo Battle Royale] Efeito de dano aplicado: ' .. damageAmount)
    end
end)

-- Evento para aplicar dano no cliente
RegisterNetEvent('cayo-battleroyale:applyDamage', function(damageAmount)
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    
    if currentHealth > 0 then
        local newHealth = math.max(currentHealth - damageAmount, 0)
        
        -- Aplicar dano usando métodos do cliente
        SetEntityHealth(playerPed, newHealth)
        
        -- Removido todos os efeitos visuais e sonoros de dano
        -- SetFlash(0, 0, 100, 500, 100)
        -- PlaySoundFrontend(-1, "Bed", "WastedSounds", true)
        -- StartScreenEffect("DeathFailOut", 2000, false)
        
        -- Removida a notificação de dano na tela
        TriggerEvent('QBCore:Notify', string.format('Levaste %d de dano! Vida: %d', damageAmount, newHealth), 'error')
        
        if Config.Debug then
            print('[Cayo Battle Royale] Dano aplicado no cliente:')
            print('  - Vida antes: ' .. currentHealth)
            print('  - Dano: ' .. damageAmount)
            print('  - Vida depois: ' .. newHealth)
        end
    end
end)

-- Evento para forçar atualização de vida
RegisterNetEvent('cayo-battleroyale:forceHealthUpdate', function(newHealth)
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, newHealth)
    
    if Config.Debug then
        print('[Cayo Battle Royale] Vida forçada para: ' .. newHealth)
    end
end)

-- Solicitar status da zona ao conectar
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cayo-battleroyale:requestZoneStatus')
end)