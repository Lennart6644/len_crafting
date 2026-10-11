Config = {}

Config.Locale = 'en'
Config.IconPath = 'nui://ox_inventory/web/images/'
Config.FallbackIcon = 'unknown.png'

Config.InteractKey = 38
Config.InteractDistance = 1.5
Config.MarkerDistance = 5.0
Config.MaxCraftDistance = 10.0
Config.MaxCraftAmount = 100
Config.MaxQueueSize = 5
Config.RefundOnCancel = true
Config.ShowLockedRecipes = true

Config.Marker = {
    type = 2,
    size = vector3(0.3, 0.3, 0.3),
    color = { r = 255, g = 255, b = 255, a = 150 },
    bob = false,
}

Config.Blips = {
    enabled = true,
    sprite = 566,
    color = 3,
    scale = 0.7,
}

Config.UI = {
    accent = '#00a2ff',
    danger = '#ff4d6d',
    hud = true,
}

Config.Workbenches = {
    ['drug_lab'] = {
        label = { de = 'Drogenlabor', en = 'Drug Lab' },
        description = { de = 'Chemische Verarbeitung unter Ausschluss der Öffentlichkeit.', en = 'Chemical processing away from prying eyes.' },
        locations = {
            vector3(2433.9658, 4968.8574, 42.3476),
        },
        jobs = 'all',
        excludeJobs = {},
        blip = false,
        recipes = {
            {
                name = 'meth',
                label = { de = 'Meth', en = 'Meth' },
                duration = 1500,
                inputs = { { item = 'rawmeth', amount = 1 }, { item = 'baggie', amount = 1 } },
                outputs = { { item = 'meth', amount = 1 } },
            },
            {
                name = 'kokain',
                label = { de = 'Kokain', en = 'Cocaine' },
                duration = 3500,
                inputs = { { item = 'cocainleave', amount = 5 }, { item = 'baggie', amount = 1 } },
                outputs = { { item = 'kokain', amount = 1 } },
            },
        },
    },
}