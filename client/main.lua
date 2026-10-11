ESX = exports['es_extended']:getSharedObject()

local uiOpen = false
local currentBenchId = nil
local queue = { benchId = nil, location = nil, jobs = {} }
local activeJobId = nil
local activeStart = 0
local cancelPending = false

local points = {}
for benchId, bench in pairs(Config.Workbenches) do
    for _, loc in ipairs(bench.locations) do
        points[#points + 1] = { benchId = benchId, coords = loc }
    end
end

local function toVector(location)
    return vector3(location.x, location.y, location.z)
end

local function pushHud()
    local first = queue.jobs[1]
    if not first or not Config.UI.hud then
        SendNUIMessage({ action = 'hud', show = false })
        return
    end
    SendNUIMessage({
        action = 'hud',
        show = true,
        label = first.label,
        icon = first.name,
        count = first.count,
        more = #queue.jobs - 1,
    })
end

local function refreshInventory()
    if not uiOpen then
        return
    end
    ESX.TriggerServerCallback('OwnCrafting:getInventory', function(inventory)
        SendNUIMessage({ action = 'inventory', inventory = inventory })
    end)
end

local function closeUI()
    if not uiOpen then
        return
    end
    uiOpen = false
    SetNuiFocus(false, false)
end

local function openCraftingMenu(benchId)
    if uiOpen then
        return
    end
    ESX.TriggerServerCallback('OwnCrafting:open', function(response)
        if not response or not response.ok or uiOpen then
            return
        end
        currentBenchId = benchId
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            texts = Locales[Config.Locale] or Locales.en,
            config = {
                iconPath = Config.IconPath,
                fallbackIcon = Config.FallbackIcon,
                maxQueue = Config.MaxQueueSize,
                maxAmount = Config.MaxCraftAmount,
                showLocked = Config.ShowLockedRecipes,
                accent = Config.UI.accent,
                danger = Config.UI.danger,
            },
            bench = response.bench,
            recipes = response.recipes,
            inventory = response.inventory,
            queue = response.queue,
        })
    end, benchId)
end

if Config.Blips.enabled then
    CreateThread(function()
        for _, bench in pairs(Config.Workbenches) do
            if bench.blip ~= false then
                for _, loc in ipairs(bench.locations) do
                    local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
                    SetBlipSprite(blip, Config.Blips.sprite)
                    SetBlipColour(blip, Config.Blips.color)
                    SetBlipScale(blip, Config.Blips.scale)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentSubstringPlayerName(Localize(bench.label))
                    EndTextCommandSetBlipName(blip)
                end
            end
        end
    end)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if not uiOpen then
            local coords = GetEntityCoords(PlayerPedId())
            for _, point in ipairs(points) do
                local dist = #(coords - point.coords)
                if dist < Config.MarkerDistance then
                    sleep = 0
                    local m = Config.Marker
                    DrawMarker(m.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.size.x, m.size.y, m.size.z, m.color.r, m.color.g, m.color.b, m.color.a, m.bob, true, 2, false, nil, nil, false)
                    if dist < Config.InteractDistance then
                        ESX.ShowHelpNotification(_L('help_open'))
                        if IsControlJustReleased(0, Config.InteractKey) then
                            openCraftingMenu(point.benchId)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local job = queue.jobs[1]
        if job and activeJobId then
            local progress = math.min((GetGameTimer() - activeStart) / math.max(job.duration, 1), 1.0)
            SendNUIMessage({ action = 'hudTick', progress = progress })
            Wait(100)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        if queue.location and #queue.jobs > 0 and not cancelPending then
            local dist = #(GetEntityCoords(PlayerPedId()) - queue.location)
            if dist > Config.MaxCraftDistance then
                cancelPending = true
                TriggerServerEvent('OwnCrafting:cancelQueue', 'distance')
            end
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('startCraft', function(data, cb)
    if currentBenchId then
        TriggerServerEvent('OwnCrafting:startCrafting', currentBenchId, data.recipe, data.count)
    end
    cb('ok')
end)

RegisterNUICallback('cancelQueue', function(_, cb)
    TriggerServerEvent('OwnCrafting:cancelQueue', 'manual')
    cb('ok')
end)

RegisterNetEvent('OwnCrafting:notify', function(message)
    ESX.ShowNotification(message)
end)

RegisterNetEvent('OwnCrafting:sync', function(state)
    queue.benchId = state.benchId
    queue.location = state.location and toVector(state.location) or nil
    queue.jobs = state.jobs or {}

    local first = queue.jobs[1]
    if first then
        if first.id ~= activeJobId then
            activeJobId = first.id
            activeStart = GetGameTimer()
        end
    else
        activeJobId = nil
        cancelPending = false
    end

    pushHud()
    if uiOpen then
        SendNUIMessage({ action = 'queue', jobs = queue.jobs })
        refreshInventory()
    end
end)

RegisterNetEvent('OwnCrafting:cancelled', function(reason)
    if reason == 'distance' and Config.UI.hud then
        SendNUIMessage({ action = 'hudCancel' })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
