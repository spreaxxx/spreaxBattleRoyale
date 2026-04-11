local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  SERVER STATE VARIABLES
--  These values are stored on the server and shared to clients
--  via network events. They reset when the resource restarts.
-- ============================================================

-- Is the battle zone currently running? (true/false)
local zoneActive = false

-- The game timer value (in milliseconds) at the moment the zone started.
-- Used to calculate how much time has passed since the event began.
local zoneStartTime = 0

-- The current zone radius in meters. Shrinks over time from
-- Config.InitialRadius down to Config.FinalRadius.
local currentRadius = Config.InitialRadius

-- Has the zone reached its smallest allowed size? (true/false)
-- Once true, the zone stops shrinking.
local minRadiusReached = false

-- The game timer value at the moment the zone stopped shrinking.
-- Kept for reference; not actively used in current logic.
local minRadiusReachedTime = 0


-- ============================================================
--  FUNCTION: IsPlayerInCayo
--  Returns true if the given player is on Cayo Perico island.
--  Players outside the island are ignored by the zone entirely.
--
--  playerId = the server ID of the player to check
-- ============================================================
local function IsPlayerInCayo(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)

    -- Measure the straight-line distance from the player to the island center
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))

    -- The player is "in Cayo" if they are within the configured island radius
    return distance <= Config.CayoDistanceLimit
end


-- ============================================================
--  FUNCTION: CalculateCurrentRadius
--  Works out what the zone radius should be RIGHT NOW based on
--  how much time has passed since the event started.
--
--  The zone shrinks smoothly from InitialRadius to FinalRadius
--  over the full ZoneDuration. For example:
--    - At 0% through the event  → radius = InitialRadius (1500m)
--    - At 50% through the event → radius = ~762m
--    - At 100% through the event → radius = FinalRadius (25m)
-- ============================================================
local function CalculateCurrentRadius()
    -- If the zone isn't active, return the initial (full) radius
    if not zoneActive then return Config.InitialRadius end

    -- If we've already hit the minimum size, just keep it there
    if minRadiusReached and Config.StopAtMinRadius then
        return Config.FinalRadius
    end

    -- Calculate how many seconds have passed since the zone started
    local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000

    -- Convert elapsed time to a 0.0 → 1.0 progress value
    -- math.min ensures it never goes above 1.0 (100%)
    local progress = math.min(elapsedTime / Config.ZoneDuration, 1.0)

    -- Interpolate between the starting radius and the final radius
    -- At progress=0.0: radius = InitialRadius
    -- At progress=1.0: radius = FinalRadius
    local calculatedRadius = Config.InitialRadius - (Config.InitialRadius - Config.FinalRadius) * progress

    -- Check if we've reached or gone below the minimum size
    if calculatedRadius <= Config.FinalRadius and not minRadiusReached then
        minRadiusReached = true
        minRadiusReachedTime = GetGameTimer()

        -- Notify all players that the zone has reached its final size
        TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_min_radius'], 'warning')

        if Config.Debug then
            print('[Battle Royale] Zone reached minimum radius: ' .. Config.FinalRadius .. 'm')
        end
        return Config.FinalRadius
    end

    return calculatedRadius
end


-- ============================================================
--  FUNCTION: IsPlayerInSafeZone
--  Returns true if the given player is INSIDE the current zone.
--  Players inside the zone are safe and take no damage.
--  Players outside the zone will receive damage.
--
--  A small buffer (SafeZoneDamageInterval) is subtracted from
--  the radius so players standing right on the edge of the zone
--  are not immediately hit — they need to be clearly outside.
--
--  playerId = the server ID of the player to check
-- ============================================================
local function IsPlayerInSafeZone(playerId)
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)

    -- Measure the distance from this player to the center of the zone
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))

    -- The player is safe if their distance is less than the zone radius minus the buffer.
    -- Example: if currentRadius = 500m and buffer = 8m, the player must be within 492m.
    return distance <= (currentRadius - Config.SafeZoneDamageInterval)
end


-- ============================================================
--  FUNCTION: EndZoneManually
--  Called when an admin uses the end command.
--  Resets all zone state and notifies all players.
--
--  source = the server ID of the admin who ran the command
-- ============================================================
local function EndZoneManually(source)
    -- Do nothing if no zone is currently running
    if not zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_zone_active'], 'error')
        return false
    end

    -- Reset all zone state variables
    zoneActive = false
    minRadiusReached = false
    minRadiusReachedTime = 0
    currentRadius = Config.InitialRadius

    -- Tell ALL clients to clean up their zone visuals
    TriggerClientEvent('spreaxBattleRoyale:endZone', -1)

    -- Broadcast a message to all players that the zone was ended by an admin
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended_manually'], 'success')

    if Config.Debug then
        local Player = QBCore.Functions.GetPlayer(source)
        print('[Battle Royale] Zone manually ended by: ' .. (Player and Player.PlayerData.name or 'Unknown'))
    end
    return true
end


-- ============================================================
--  COMMAND: Start Battle Zone
--  Registered as a QBCore command that admins can type in chat.
--  Checks permissions, location, and whether a zone is already
--  running before starting a new one.
-- ============================================================
QBCore.Commands.Add(Config.Command, Config.Messages['command_start_battleroyale'], {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Only allow players with the configured permission to run this command
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end

    -- The admin must be on Cayo Perico island to start the event
    if not IsPlayerInCayo(source) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['not_in_cayo'], 'error')
        return
    end

    -- Don't allow starting a second zone if one is already running
    if zoneActive then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['zone_active'], 'error')
        return
    end

    -- All checks passed — start the zone!
    zoneActive = true
    zoneStartTime = GetGameTimer()    -- Record the start time for radius calculations
    currentRadius = Config.InitialRadius
    minRadiusReached = false
    minRadiusReachedTime = 0

    -- Tell ALL clients to activate their zone visuals and HUD
    TriggerClientEvent('spreaxBattleRoyale:startZone', -1)

    -- Broadcast an announcement to all players
    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_started'], 'primary')

    if Config.Debug then
        print('[Battle Royale] Zone started by: ' .. Player.PlayerData.name)
    end
end, Config.Permission)


-- ============================================================
--  ZONE SHRINK + SYNC LOOP
--  Runs on the server every UpdateInterval milliseconds.
--  Recalculates the current zone radius and broadcasts the
--  updated size and time remaining to all connected clients.
-- ============================================================
CreateThread(function()
    while true do
        if zoneActive then

            -- Recalculate how large the zone should be right now
            currentRadius = CalculateCurrentRadius()

            -- If StopAtMinRadius is false, automatically end the zone
            -- when the full duration has elapsed
            if not Config.StopAtMinRadius then
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                if elapsedTime >= Config.ZoneDuration then
                    zoneActive = false
                    minRadiusReached = false
                    minRadiusReachedTime = 0

                    -- Tell all clients the event is over
                    TriggerClientEvent('spreaxBattleRoyale:endZone', -1)
                    TriggerClientEvent('QBCore:Notify', -1, Config.Messages['zone_ended'], 'success')

                    if Config.Debug then
                        print('[Battle Royale] Zone ended automatically')
                    end
                end
            end

            -- Calculate how many seconds remain until the zone stops shrinking.
            -- We send -1 as a special signal when the zone has reached final size.
            local timeRemaining = 0
            if not minRadiusReached then
                local elapsedTime = (GetGameTimer() - zoneStartTime) / 1000
                timeRemaining = math.max(Config.ZoneDuration - elapsedTime, 0)
            else
                timeRemaining = -1 -- Tells clients to show "FINAL ZONE" instead of a timer
            end

            -- Push the updated radius and time to all clients so their displays stay in sync
            TriggerClientEvent('spreaxBattleRoyale:updateZone', -1, currentRadius, timeRemaining)
        end

        Wait(Config.UpdateInterval) -- Wait before running this loop again
    end
end)


-- ============================================================
--  DAMAGE LOOP
--  Runs on the server every DamageInterval milliseconds.
--  Loops through every connected player on Cayo Perico and
--  sends a damage event to any player who is outside the zone.
-- ============================================================
CreateThread(function()
    while true do
        if zoneActive then
            -- Get a list of all currently connected players
            local players = QBCore.Functions.GetQBPlayers()

            for playerId, player in pairs(players) do
                -- Only care about players who are on the island
                if IsPlayerInCayo(playerId) then
                    local isInSafeZone = IsPlayerInSafeZone(playerId)

                    -- If the player is OUTSIDE the safe zone, send them a damage event.
                    -- The actual health reduction happens on the client side when it
                    -- receives the 'applyDamage' event.
                    if not isInSafeZone then
                        TriggerClientEvent('spreaxBattleRoyale:applyDamage', playerId, Config.DamageAmount)

                        if Config.Debug then
                            local playerPed = GetPlayerPed(playerId)
                            local playerCoords = GetEntityCoords(playerPed)
                            local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
                            print('[Battle Royale] Sending damage to player: ' .. playerId)
                            print('  - Name: ' .. GetPlayerName(playerId))
                            print('  - Distance from center: ' .. math.floor(distance) .. 'm')
                            print('  - Current zone radius: ' .. math.floor(currentRadius) .. 'm')
                            print('  - Safe threshold (radius - buffer): ' .. math.floor(currentRadius - Config.SafeZoneDamageInterval) .. 'm')
                        end
                    end
                end
            end
        end

        Wait(Config.DamageInterval) -- Wait before checking again
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:requestZoneStatus
--  Triggered by a CLIENT when a player loads in.
--  Replies to that specific player with the current zone state
--  so they are immediately in sync if an event is already running.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:requestZoneStatus', function()
    local source = source  -- 'source' is automatically set to the player who triggered the event
    TriggerClientEvent('spreaxBattleRoyale:receiveZoneStatus', source, zoneActive, currentRadius)
end)


-- ============================================================
--  COMMAND: End Battle Zone
--  Allows an admin to manually stop the event at any time.
-- ============================================================
QBCore.Commands.Add(Config.EndCommand, Config.Messages['command_end_battleroyale'], {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- Only allow players with the configured permission to run this command
    if not QBCore.Functions.HasPermission(source, Config.Permission) then
        TriggerClientEvent('QBCore:Notify', source, Config.Messages['no_permission'], 'error')
        return
    end

    EndZoneManually(source)
end, Config.Permission)