fx_version 'cerulean'
game 'gta5'

author 'Spreax'
description 'A Battle Royale zone system for FiveM, with a shrinking safe zone and visual indicators.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
