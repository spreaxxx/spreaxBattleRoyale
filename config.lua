Config = {}

-- ============================================================
--  GENERAL SETTINGS
-- ============================================================

-- Set to true to see extra messages in the server console that
-- help you understand what the script is doing behind the scenes.
-- Useful when something isn't working and you want to investigate.
-- Set to false when everything is working to keep the console clean.
Config.Debug = false

-- The chat command an admin types to START the battle zone.
-- Example: /startbattleroyale
Config.Command = 'startbattleroyale'

-- The chat command an admin types to STOP the battle zone early.
-- Example: /endbattleroyale
Config.EndCommand = 'endbattleroyale'

-- Which permission group is allowed to use the commands above.
-- Only players with this role will be able to start or stop the zone.
Config.Permission = 'admin'


-- ============================================================
--  ZONE TIMING & DAMAGE
-- ============================================================

-- How long the full battle royale event lasts, in seconds.
-- 3600 seconds = 1 hour. Change this to make it shorter or longer.
-- Examples: 1800 = 30 min | 900 = 15 min | 600 = 10 min
Config.ZoneDuration = 3600

-- How often (in milliseconds) the server sends zone updates to all players.
-- 2000 ms = every 2 seconds. Lower = smoother zone shrink, more server load.
Config.UpdateInterval = 1000

-- How often (in milliseconds) the server checks who is outside the zone
-- and deals damage to them.
-- 5000 ms = damage every 5 seconds.
Config.DamageInterval = 5000

-- How much health is taken from a player every damage tick
-- when they are standing outside the safe zone.
Config.DamageAmount = 10

-- The maximum health value players have on your server.
-- GTA uses a scale where 200 = full health (100 base + 100 armor by default).
-- Only used for reference; actual health changes are handled by GTA itself.
Config.MaxHealth = 200

-- If true: when the zone reaches its smallest size (FinalRadius),
-- it stops shrinking and stays that size forever until an admin ends it.
-- If false: the zone disappears automatically when the timer runs out.
Config.StopAtMinRadius = true

-- Internal variable — tracks the moment the zone stopped shrinking.
-- You do not need to change this; the script manages it automatically.
Config.MinRadiusReachedTime = 0

-- A small invisible buffer (in meters) applied INSIDE the zone boundary.
-- Players have to be at least this many meters inside the zone to be
-- considered "safe". This prevents players standing exactly on the
-- border from flickering between safe and damaged states.
-- Increase this if players on the edge report getting damaged unexpectedly.
Config.SafeZoneDamageInterval = 0.0

-- The maximum distance (in meters) from the island center that the script
-- considers "still on Cayo Perico". Players further than this are ignored
-- by the zone system entirely (they can't be on the island anyway).
Config.CayoDistanceLimit = 3000.0


-- ============================================================
--  ZONE LOCATION
-- ============================================================

-- The exact center point of the battle zone, placed at the
-- middle of Cayo Perico island.
-- x = left/right position | y = forward/back position | z = height
-- You can change these coordinates if you want the zone centered elsewhere.
Config.CayoCenter = { x = 4813.06, y = -4319.06, z = 2.0 }


-- ============================================================
--  ZONE SIZE
-- ============================================================

-- The zone starts this large (in meters radius) when the event begins.
-- 1500 meters means the circle is 3000 meters wide at the start.
Config.InitialRadius = 1500.0

-- The zone shrinks down to this size (in meters radius) by the end.
-- 25 meters is very small — about the size of a house.
Config.FinalRadius = 25.0


-- ============================================================
--  ZONE VISUAL COLOUR (the cylinder/disc shown in the world)
-- ============================================================

-- This is the colour of the big circular zone marker visible in the game world.
-- r = red | g = green | b = blue | a = opacity (0 = invisible, 255 = fully solid)
-- Default: red, semi-transparent
Config.ZoneColor = {
    r = 255,  -- Full red
    g = 0,    -- No green
    b = 0,    -- No blue
    a = 100   -- Semi-transparent
}

-- Colour used for the safe/green zone visual (kept here for future customisation).
Config.SafeZoneColor = {
    r = 0,
    g = 255,
    b = 0,
    a = 50
}


-- ============================================================
--  MINIMAP ZONE (the dots drawn around the zone on the minimap)
-- ============================================================

Config.MinimapZone = {
    -- Set to false to turn off the minimap zone ring entirely.
    enabled = true,

    -- How often (in milliseconds) the minimap ring is redrawn.
    -- 1000 ms = once per second. Lowering this makes it update faster.
    updateInterval = 1000,

    -- How visible the minimap dots are. 0 = invisible, 255 = fully visible.
    blipAlpha = 150,

    -- (Kept for future use) Transparency for the safe zone minimap area.
    safeZoneAlpha = 80,

    -- (Kept for future use) Transparency for the danger zone minimap area.
    dangerZoneAlpha = 120
}


-- ============================================================
--  WORLD ZONE OVERLAY (the coloured area drawn in the 3D world)
-- ============================================================

Config.WorldZone = {
    -- Set to false to hide the 3D coloured zone overlay in the world.
    enabled = true,

    -- Colour of the area OUTSIDE the zone (the danger/closed area).
    -- Shown as a red shaded region between the current zone edge and
    -- the original starting boundary.
    closedZoneColor = {
        r = 255,  -- Red
        g = 0,
        b = 0,
        a = 30    -- Very transparent so it doesn't block visibility too much
    },

    -- Colour of the area INSIDE the zone (the safe area).
    safeZoneColor = {
        r = 0,
        g = 255,  -- Green
        b = 0,
        a = 20    -- Even more transparent — just a subtle green tint on the ground
    },

    -- Players further than this distance (in meters) from the zone center
    -- will not see the 3D world overlay. Reduces GPU load for distant players.
    renderDistance = 2000.0,

    -- How tall the visual zone walls/markers are (in game units).
    markerHeight = 300.0
}


-- ============================================================
--  MESSAGES (all text shown to players)
--  You can edit any of the text inside the quotes below.
--  Do NOT change the keys (the part on the left of the = sign).
-- ============================================================

Config.Messages = {
    -- Shown at the top of the screen while the zone is active.
    -- %d = current zone radius in meters | %02d:%02d = minutes:seconds remaining
    -- Example output: "Zone: 850m | Time: 42:17"
    ['zone_timer'] = 'Zone: %dm | Time: %02d:%02d',

    -- Shown when the zone has reached its final (smallest) size.
    ['zone_final'] = 'FINAL ZONE',

    -- Warning shown to players who are standing outside the safe zone.
    ['zone_outside'] = 'YOU ARE OUTSIDE THE SAFE ZONE!',

    -- Damage notification shown to the player when they take zone damage.
    -- First %d = damage taken | second %d = health remaining after damage
    -- Example output: "You took 10 damage! Health: 140"
    ['zone_damage_client'] = 'You took %d damage! Health: %d',

    -- Broadcast to ALL players when the zone starts.
    ['zone_started'] = 'The battle zone has started at Cayo Perico!',

    -- (Available for future use) Shown when the zone is actively shrinking.
    -- %s = time remaining as a formatted string
    ['zone_shrinking'] = 'The zone is shrinking! Time remaining: %s',

    -- (Available for future use) Shown when a player takes zone damage (server side).
    -- %s = current health
    ['zone_damage'] = 'You are outside the safe zone! Health: %s',

    -- Broadcast to ALL players when the zone ends naturally (timer runs out).
    ['zone_ended'] = 'The battle zone has ended!',

    -- Broadcast to ALL players when the zone shrinks to its smallest size.
    ['zone_min_radius'] = 'The zone has reached its minimum radius and will stay this size until manually ended!',

    -- Broadcast to ALL players when an admin manually ends the event.
    ['zone_ended_manually'] = 'The battle zone was manually ended by an administrator!',

    -- Shown to the admin if they try to start a zone that is already running.
    ['zone_active'] = 'A battle zone is already active!',

    -- Shown to the admin if they try to end a zone that isn't running.
    ['no_zone_active'] = 'There is no active zone to end!',

    -- Shown to the admin if they try to use a command outside of Cayo Perico.
    ['not_in_cayo'] = 'You must be at Cayo Perico to use this command!',

    -- Shown to a player who tries to use a command without the required permission.
    ['no_permission'] = 'You do not have permission to use this command!',

    -- Description of the start command (shown in the F1 command list).
    ['command_start_battleroyale'] = 'Start the battle zone at Cayo Perico',

    -- Description of the end command (shown in the F1 command list).
    ['command_end_battleroyale'] = 'Manually end the battle zone at Cayo Perico',
}