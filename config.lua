Config = {}

-- Configurações Gerais
Config.Debug = false -- Ativar mensagens de debug
Config.Command = 'startbattleroyale' -- Comando para iniciar a zona
Config.EndCommand = 'endbattleroyale' -- Comando para finalizar a zona manualmente
Config.Permission = 'admin' -- Permissão necessária para usar o comando

-- Configurações da Zona
Config.ZoneDuration = 3600 -- Duração total em segundos (1 hora = 3600)
Config.UpdateInterval = 2000 -- Intervalo de atualização em ms
Config.DamageInterval = 5000 -- Intervalo de dano em ms (3 segundos)
Config.DamageAmount = 10 -- Quantidade de dano por tick
Config.MaxHealth = 200 -- Vida máxima do jogador
Config.StopAtMinRadius = true -- Se true, a zona para de encolher ao atingir o raio final
Config.MinRadiusReachedTime = 0 -- Tempo quando a zona atingiu o raio mínimo (usado internamente)

-- Configurações específicas para o sistema de dano
Config.DamageSettings = {
    ignoreGodMode = false, -- Ignorar modo deus para teste
    forceHealthUpdate = true, -- Forçar atualização de vida
    showDamageEffects = false, -- Mostrar efeitos visuais de dano
    debugDamage = false -- Debug específico para dano
}

-- Coordenadas do Centro de Cayo Perico
Config.CayoCenter = { x = 4813.06, y = -4319.06, z = 2.0 } 

-- Raio inicial e final da zona
Config.InitialRadius = 1500.0 -- Raio inicial (metros)
Config.FinalRadius = 25.0 -- Raio final (metros)

-- Configurações Visuais
Config.ZoneColor = {
    r = 255,
    g = 0,
    b = 0,
    a = 100
}

Config.SafeZoneColor = {
    r = 0,
    g = 255,
    b = 0,
    a = 50
}

-- Configurações de Visualização Avançada
Config.MinimapZone = {
    enabled = true,
    updateInterval = 1000, -- Atualização do minimapa em ms
    blipAlpha = 150,
    safeZoneAlpha = 80,
    dangerZoneAlpha = 120
}

Config.WorldZone = {
    enabled = true,
    closedZoneColor = {
        r = 255,
        g = 0,
        b = 0,
        a = 30 -- Tom suave para zona fechada
    },
    safeZoneColor = {
        r = 0,
        g = 255,
        b = 0,
        a = 20 -- Tom muito suave para zona segura
    },
    renderDistance = 2000.0, -- Distância máxima para renderizar
    markerHeight = 300.0 -- Altura dos marcadores visuais
}

-- Mensagens
Config.Messages = {
    ['zone_started'] = 'A zona de batalha foi iniciada em Cayo Perico!',
    ['zone_shrinking'] = 'A zona está encolhendo! Tempo restante: %s',
    ['zone_damage'] = 'Você está fora da zona segura! Vida: %s',
    ['zone_ended'] = 'A zona de batalha terminou!',
    ['not_in_cayo'] = 'Você precisa estar em Cayo Perico para usar este comando!',
    ['no_permission'] = 'Você não tem permissão para usar este comando!',
    ['zone_active'] = 'Já existe uma zona ativa!',
    ['zone_min_radius'] = 'A zona atingiu o raio mínimo e permanecerá assim até ser finalizada manualmente!',
    ['zone_ended_manually'] = 'A zona de batalha foi finalizada manualmente por um administrador!',
    ['no_zone_active'] = 'Não há nenhuma zona ativa para finalizar!'
}