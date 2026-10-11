fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'OwnCrafting'
author 'OwnCrafting'
description 'Glassmorphism crafting system with multilingual NUI'
version '2.0.0'

shared_scripts {
    'locales/init.lua',
    'config.lua',
    'locales/de.lua',
    'locales/en.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
