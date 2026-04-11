local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  LOCAL VARIABLES
--  These are values stored in memory while the script is running.
--  They reset when the resource restarts or the player reconnects.
-- ============================================================

-- Is the battle zone currently active? (true/false)
local zoneActive = false

-- The current radius of the safe zone in meters.
-- Starts at the initial radius and shrinks over time.
local currentRadius = Config.InitialRadius

-- How many seconds are left until the zone stops shrinking.
-- -1 is a special value meaning "final zone" (zone has stopped shrinking).
local timeRemaining = 0

-- Reference to the blip (icon) at the center of the zone on the map.
-- nil means no blip exists yet.
local zoneBlip = nil

-- Reference to the blip that draws the zone circle on the map.
local radiusBlip = nil

-- A list of all the small dot blips that draw the zone ring on the minimap.
local minimapBlips = {}

-- (Reserved for future use) List of world markers drawn in the 3D world.
local worldMarkers = {}

-- Tracks when the minimap was last updated (in game milliseconds).
-- Used to avoid updating too frequently.
local lastMinimapUpdate = 0


-- ============================================================
--  FUNCTION: CreateZoneBlips
--  Creates the map blips that show the zone boundary.
--  Called when the zone starts or when this player connects
--  while a zone is already running.
-- ============================================================
local function CreateZoneBlips()
    -- Remove any existing blips first to avoid duplicates
    if zoneBlip then
        RemoveBlip(zoneBlip)
    end
    if radiusBlip then
        RemoveBlip(radiusBlip)
    end

    -- (Optional) Uncomment the block below to also show a blip
    -- at the exact center of the zone on the map:
    -- zoneBlip = AddBlipForCoord(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z)
    -- SetBlipSprite(zoneBlip, 84)
    -- SetBlipColour(zoneBlip, 1)
    -- SetBlipScale(zoneBlip, 1.0)
    -- SetBlipAsShortRange(zoneBlip, false)
    -- BeginTextCommandSetBlipName("STRING")
    -- AddTextComponentString("Battle Zone")
    -- EndTextCommandSetBlipName(zoneBlip)

    -- Draw a circle on the map showing the current zone boundary.
    -- AddBlipForRadius draws a shaded circle, not just a dot.
    radiusBlip = AddBlipForRadius(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z, currentRadius)
    SetBlipColour(radiusBlip, 1)   -- 1 = red
    SetBlipAlpha(radiusBlip, 100)  -- Semi-transparent
end


-- ============================================================
--  FUNCTION: RemoveZoneBlips
--  Cleans up all zone map blips when the event ends.
-- ============================================================
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


-- ============================================================
--  FUNCTION: IsPlayerInSafeZone
--  Returns true if THIS player is currently inside the safe zone.
--  Uses a small buffer (SafeZoneDamageInterval) so players right
--  on the edge aren't falsely flagged as outside.
-- ============================================================
local function IsPlayerInSafeZone()
    -- Get where this player is standing right now
    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Calculate the straight-line distance from the player to the zone center
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))

    -- The player is safe if they are inside the zone, with a small buffer margin.
    -- Subtracting the buffer means players need to be clearly inside the zone,
    -- not just touching the very edge, to be counted as safe.
    return distance <= (currentRadius - Config.SafeZoneDamageInterval)
end


-- ============================================================
--  FUNCTION: IsPlayerInCayo
--  Returns true if this player is anywhere on Cayo Perico island.
--  Used to decide whether to draw the zone visuals at all.
-- ============================================================
local function IsPlayerInCayo()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))
    return distance <= Config.CayoDistanceLimit
end


-- ============================================================
--  FUNCTION: UpdateMinimapZone
--  Draws a ring of small dots on the minimap to show where the
--  zone boundary is. The dots are recalculated and redrawn on
--  a regular interval to follow the shrinking zone.
-- ============================================================
local function UpdateMinimapZone()
    -- Skip if minimap zone is disabled in config
    if not Config.MinimapZone.enabled then return end

    -- Only update if enough time has passed since the last update
    local currentTime = GetGameTimer()
    if currentTime - lastMinimapUpdate < Config.MinimapZone.updateInterval then
        return
    end
    lastMinimapUpdate = currentTime

    -- Remove all old minimap dots before drawing new ones
    for _, blip in pairs(minimapBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    minimapBlips = {}

    -- Don't draw anything if the zone isn't active
    if not zoneActive then return end

    -- Place 32 evenly spaced dots in a circle to represent the zone boundary.
    -- More segments = smoother circle, but more blips = more memory used.
    local segments = 32
    for i = 1, segments do
        -- Calculate the angle for this dot (in radians, going around the full circle)
        local angle = (i / segments) * 2 * math.pi

        -- Convert the angle and radius into X/Y world coordinates
        local x = Config.CayoCenter.x + math.cos(angle) * currentRadius
        local y = Config.CayoCenter.y + math.sin(angle) * currentRadius

        -- Create a blip at this position and style it as a small dot
        local blip = AddBlipForCoord(x, y, Config.CayoCenter.z)
        SetBlipSprite(blip, 1)       -- Sprite 1 = plain dot
        SetBlipColour(blip, 1)       -- Red
        SetBlipScale(blip, 0.3)      -- Small size
        SetBlipAlpha(blip, Config.MinimapZone.blipAlpha)
        SetBlipAsShortRange(blip, false) -- Always visible, even when zoomed out

        -- Keep track of this blip so we can remove it later
        table.insert(minimapBlips, blip)
    end
end


-- ============================================================
--  FUNCTION: RenderWorldZone
--  Draws coloured polygons in the 3D game world to show:
--    - A RED area between the current zone edge and the original
--      starting boundary (the dangerous/closed area)
--    - A GREEN area inside the current zone (the safe area)
--  This uses DrawPoly which draws flat triangles in the world.
--  Called every frame (inside the main render loop).
-- ============================================================
local function RenderWorldZone()
    -- Skip if world zone visuals are disabled or the event isn't running
    if not Config.WorldZone.enabled or not zoneActive then return end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z))

    -- Only render if the player is close enough to see it (saves GPU performance)
    if distance > Config.WorldZone.renderDistance then return end

    -- We split the circle into 64 triangle slices.
    -- More segments = smoother looking circle.
    local segments = 64
    local maxRadius = Config.InitialRadius  -- The original starting radius

    for i = 1, segments do
        -- Calculate the two angles that form the edges of this triangle slice
        local angle1 = (i / segments) * 2 * math.pi
        local angle2 = ((i + 1) / segments) * 2 * math.pi

        -- Draw the DANGER (red) zone — the area between current radius and starting radius
        -- Only draw this if the zone has shrunk at all from its starting size
        if currentRadius < maxRadius then
            -- Inner edge points (on the current zone boundary)
            local x1_inner = Config.CayoCenter.x + math.cos(angle1) * currentRadius
            local y1_inner = Config.CayoCenter.y + math.sin(angle1) * currentRadius
            local x2_inner = Config.CayoCenter.x + math.cos(angle2) * currentRadius
            local y2_inner = Config.CayoCenter.y + math.sin(angle2) * currentRadius

            -- Outer edge points (on the original starting boundary)
            local x1_outer = Config.CayoCenter.x + math.cos(angle1) * maxRadius
            local y1_outer = Config.CayoCenter.y + math.sin(angle1) * maxRadius
            local x2_outer = Config.CayoCenter.x + math.cos(angle2) * maxRadius
            local y2_outer = Config.CayoCenter.y + math.sin(angle2) * maxRadius

            -- Each quad (4-sided shape) is drawn as two triangles.
            -- Triangle 1 of the danger quad
            DrawPoly(
                x1_inner, y1_inner, playerCoords.z + 50.0,
                x2_inner, y2_inner, playerCoords.z + 50.0,
                x1_outer, y1_outer, playerCoords.z + 50.0,
                Config.WorldZone.closedZoneColor.r,
                Config.WorldZone.closedZoneColor.g,
                Config.WorldZone.closedZoneColor.b,
                Config.WorldZone.closedZoneColor.a
            )
            -- Triangle 2 of the danger quad
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

        -- Draw the SAFE (green) zone — the area inside the current boundary.
        -- Each triangle goes from the center of the island out to the zone edge.
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
end


-- ============================================================
--  MAIN RENDER LOOP
--  Runs every single frame (Wait(0) = no delay between loops).
--  Draws zone visuals and HUD text while the event is active.
--  Only runs visuals if the player is on Cayo Perico island.
-- ============================================================
CreateThread(function()
    while true do
        if zoneActive and IsPlayerInCayo() then

            -- Draw the 3D world zone overlay (red/green coloured areas)
            RenderWorldZone()

            -- Draw the large cylindrical zone marker (the red pillar/disc in the world)
            -- Type 1 = flat cylinder. Positioned at island center, slightly underground.
            -- Size is based on current radius so it always matches the zone boundary.
            DrawMarker(1, Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z - 100.0,
                      0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                      currentRadius * 2, currentRadius * 2, 200.0,
                      Config.ZoneColor.r, Config.ZoneColor.g, Config.ZoneColor.b, Config.ZoneColor.a,
                      false, true, 2, false, nil, nil, false)

            -- Show the timer on screen (top center) while the zone is still shrinking
            if timeRemaining > 0 then
                local minutes = math.floor(timeRemaining / 60)
                local seconds = math.floor(timeRemaining % 60)
                -- Build the display string using the format from config
                -- Example: "Zone: 850m | Time: 42:17"
                local timerText = string.format(Config.Messages['zone_timer'], math.floor(currentRadius), minutes, seconds)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.6, 0.6)
                SetTextColour(255, 255, 255, 255) -- White text
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString(timerText)
                DrawText(0.5, 0.05) -- Position: center of screen, near the top

            -- Show "FINAL ZONE" text when the zone has stopped shrinking (timeRemaining = -1)
            elseif timeRemaining == -1 then
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.6, 0.6)
                SetTextColour(255, 255, 0, 255) -- Yellow text
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString(Config.Messages['zone_final'])
                DrawText(0.5, 0.05)
            end

            -- Show a danger warning if the player is currently outside the safe zone
            if not IsPlayerInSafeZone() then
                SetTextFont(4)
                SetTextProportional(1)
                SetTextScale(0.7, 0.7)
                SetTextColour(255, 0, 0, 255) -- Red text
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString(Config.Messages['zone_outside'])
                DrawText(0.5, 0.1) -- Slightly lower than the timer
            end
        end

        Wait(0) -- Run again on the very next frame
    end
end)


-- ============================================================
--  TIMER COUNTDOWN LOOP
--  Counts down timeRemaining by 1 every second.
--  Runs independently of the render loop so the timer
--  stays accurate even if the frame rate drops.
-- ============================================================
CreateThread(function()
    while true do
        if zoneActive and timeRemaining > 0 then
            timeRemaining = timeRemaining - 1
        end
        Wait(1000) -- Wait 1 second before running again
    end
end)


-- ============================================================
--  MINIMAP UPDATE LOOP
--  Periodically redraws the ring of dots on the minimap
--  to reflect the current zone size.
-- ============================================================
CreateThread(function()
    while true do
        if zoneActive then
            UpdateMinimapZone()
        end
        Wait(Config.MinimapZone.updateInterval)
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:startZone
--  Triggered by the SERVER when an admin starts the event.
--  Sets up the initial zone state on this client.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:startZone', function()
    zoneActive = true
    currentRadius = Config.InitialRadius  -- Reset to the full starting size
    timeRemaining = Config.ZoneDuration   -- Reset the countdown timer
    CreateZoneBlips()
    if Config.Debug then
        print('[Battle Royale] Zone started on client')
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:updateZone
--  Triggered by the SERVER every few seconds with the latest
--  zone radius and time remaining.
--  Keeps this client in sync with the server.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:updateZone', function(newRadius, newTimeRemaining)
    currentRadius = newRadius
    timeRemaining = newTimeRemaining

    -- Redraw the map blip circle to match the new radius
    if radiusBlip then
        RemoveBlip(radiusBlip)
        radiusBlip = AddBlipForRadius(Config.CayoCenter.x, Config.CayoCenter.y, Config.CayoCenter.z, currentRadius)
        SetBlipColour(radiusBlip, 1)
        SetBlipAlpha(radiusBlip, 100)
    end

    if Config.Debug then
        print('[Battle Royale] Zone updated: ' .. currentRadius .. 'm')
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:endZone
--  Triggered by the SERVER when the event ends (either by timer
--  running out or an admin manually ending it).
--  Cleans up all zone visuals and resets state.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:endZone', function()
    zoneActive = false
    currentRadius = Config.InitialRadius  -- Reset radius for next time
    timeRemaining = 0

    -- Remove the map blips
    RemoveZoneBlips()

    -- Remove all minimap ring dots
    for _, blip in pairs(minimapBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    minimapBlips = {}

    if Config.Debug then
        print('[Battle Royale] Zone ended on client')
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:receiveZoneStatus
--  Triggered when THIS player first connects or reconnects.
--  The server sends the current zone state so the player
--  is immediately in sync if an event is already running.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:receiveZoneStatus', function(active, radius)
    zoneActive = active
    currentRadius = radius
    if active then
        CreateZoneBlips()  -- Show the zone on map if it's already active
    else
        RemoveZoneBlips()
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:takeDamage
--  (Currently only used for debug logging)
--  Reserved for future use — could trigger visual/sound effects.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:takeDamage', function(damageAmount)
    if Config.Debug then
        print('[Battle Royale] Damage effect applied: ' .. damageAmount)
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:applyDamage
--  Triggered by the SERVER when this player is outside the zone
--  and should take damage. Reduces health directly on this client.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:applyDamage', function(damageAmount)
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)

    -- Only apply damage if the player is still alive
    if currentHealth > 0 then
        -- Subtract damage but never go below 0 (math.max prevents negative health)
        local newHealth = math.max(currentHealth - damageAmount, 0)
        SetEntityHealth(playerPed, newHealth)

        -- Uncomment below to add visual/audio damage effects:
        -- SetFlash(0, 0, 100, 500, 100)
        -- StartScreenEffect("DeathFailOut", 2000, false)

        -- Show a notification to the player telling them how much damage they took
        TriggerEvent('QBCore:Notify', string.format(Config.Messages['zone_damage_client'], damageAmount, newHealth), 'error')

        if Config.Debug then
            print('[Battle Royale] Damage applied to client:')
            print('  - Health before: ' .. currentHealth)
            print('  - Damage: ' .. damageAmount)
            print('  - Health after: ' .. newHealth)
        end
    end
end)


-- ============================================================
--  EVENT: spreaxBattleRoyale:forceHealthUpdate
--  Allows the server to directly set this player's health
--  to a specific value. Used for server-authoritative health sync.
-- ============================================================
RegisterNetEvent('spreaxBattleRoyale:forceHealthUpdate', function(newHealth)
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, newHealth)
    if Config.Debug then
        print('[Battle Royale] Health forced to: ' .. newHealth)
    end
end)


-- ============================================================
--  EVENT: QBCore:Client:OnPlayerLoaded
--  Runs automatically when this player finishes loading into
--  the server. Asks the server if a zone is currently active
--  so this player can sync up immediately.
-- ============================================================
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('spreaxBattleRoyale:requestZoneStatus')
end)