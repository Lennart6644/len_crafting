ESX = exports['es_extended']:getSharedObject()

local queues = {}
local jobCounter = 0
local DISTANCE_TOLERANCE = 2.0
local startJob
local finishJob

local function notify(src, key, ...)
    TriggerClientEvent('OwnCrafting:notify', src, _L(key, ...))
end

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

local function hasRule(job, rule)
    if rule == nil or rule == 'all' then
        return true
    end
    if type(rule) == 'table' then
        local minGrade = rule[job.name]
        return minGrade ~= nil and job.grade >= minGrade
    end
    return false
end

local function benchAccess(job, bench)
    for _, name in ipairs(bench.excludeJobs or {}) do
        if job.name == name then
            return false
        end
    end
    return hasRule(job, bench.jobs)
end

local function recipeAccess(job, recipe)
    return hasRule(job, recipe.jobs)
end

local function getRecipe(bench, name)
    for _, recipe in ipairs(bench.recipes) do
        if recipe.name == name then
            return recipe
        end
    end
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

local function nearbyLocation(src, bench)
    local coords = playerCoords(src)
    if not coords then
        return nil
    end
    for _, loc in ipairs(bench.locations) do
        if #(coords - loc) <= Config.MaxCraftDistance then
            return loc
        end
    end
    return nil
end

local function isNear(src, location)
    local coords = playerCoords(src)
    return coords ~= nil and #(coords - location) <= Config.MaxCraftDistance + DISTANCE_TOLERANCE
end

local function inventoryList(xPlayer)
    local list = {}
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            list[#list + 1] = { name = item.name, label = item.label or item.name, count = item.count }
        end
    end
    return list
end

local function snapshotQueue(src)
    local queue = queues[src]
    if not queue then
        return { jobs = {}, benchId = nil, location = nil }
    end

    local jobs = {}
    for i, job in ipairs(queue.jobs) do
        jobs[i] = {
            id = job.id,
            name = job.recipe.name,
            label = Localize(job.recipe.label),
            count = job.count,
            duration = job.duration,
        }
    end

    return {
        jobs = jobs,
        benchId = queue.benchId,
        location = { x = queue.location.x, y = queue.location.y, z = queue.location.z },
    }
end

local function syncQueue(src)
    TriggerClientEvent('OwnCrafting:sync', src, snapshotQueue(src))
end

local function cancelQueue(src, reason)
    local queue = queues[src]
    if not queue then
        return
    end

    local xPlayer = getPlayer(src)
    if Config.RefundOnCancel and xPlayer then
        local refund = {}
        for _, job in ipairs(queue.jobs) do
            for _, input in ipairs(job.recipe.inputs) do
                refund[input.item] = (refund[input.item] or 0) + input.amount * job.count
            end
        end
        for item, amount in pairs(refund) do
            xPlayer.addInventoryItem(item, amount)
        end
    end

    queues[src] = nil
    syncQueue(src)
    TriggerClientEvent('OwnCrafting:cancelled', src, reason)

    local message = reason == 'distance' and _L('notify_cancelled_far') or _L('notify_cancelled')
    if Config.RefundOnCancel then
        message = message .. ' ' .. _L('notify_refunded')
    end
    TriggerClientEvent('OwnCrafting:notify', src, message)
end

startJob = function(src)
    local queue = queues[src]
    local job = queue and queue.jobs[1]
    if not job then
        return
    end
    SetTimeout(job.duration, function()
        finishJob(src, job.id)
    end)
end

finishJob = function(src, jobId)
    local queue = queues[src]
    local job = queue and queue.jobs[1]
    if not job or job.id ~= jobId then
        return
    end

    local xPlayer = getPlayer(src)
    if not xPlayer or not isNear(src, queue.location) then
        cancelQueue(src, 'distance')
        return
    end

    for _, output in ipairs(job.recipe.outputs) do
        xPlayer.addInventoryItem(output.item, output.amount * job.count)
    end
    notify(src, 'notify_done', Localize(job.recipe.label), job.count)
    table.remove(queue.jobs, 1)

    if #queue.jobs == 0 then
        queues[src] = nil
        syncQueue(src)
    else
        syncQueue(src)
        startJob(src)
    end
end

ESX.RegisterServerCallback('OwnCrafting:open', function(source, cb, benchId)
    local bench = Config.Workbenches[benchId]
    local xPlayer = getPlayer(source)
    if not bench or not xPlayer then
        return cb({ ok = false })
    end

    local job = xPlayer.getJob()
    if not benchAccess(job, bench) then
        notify(source, 'notify_no_access')
        return cb({ ok = false })
    end

    if not nearbyLocation(source, bench) then
        notify(source, 'notify_too_far')
        return cb({ ok = false })
    end

    local recipes = {}
    for _, recipe in ipairs(bench.recipes) do
        local locked = not recipeAccess(job, recipe)
        if not locked or Config.ShowLockedRecipes then
            recipes[#recipes + 1] = {
                name = recipe.name,
                label = Localize(recipe.label),
                duration = recipe.duration,
                inputs = recipe.inputs,
                outputs = recipe.outputs,
                locked = locked,
            }
        end
    end

    cb({
        ok = true,
        bench = { label = Localize(bench.label), description = Localize(bench.description) },
        recipes = recipes,
        inventory = inventoryList(xPlayer),
        queue = snapshotQueue(source).jobs,
    })
end)

ESX.RegisterServerCallback('OwnCrafting:getInventory', function(source, cb)
    local xPlayer = getPlayer(source)
    cb(xPlayer and inventoryList(xPlayer) or {})
end)

RegisterNetEvent('OwnCrafting:startCrafting', function(benchId, recipeName, count)
    local src = source
    local bench = Config.Workbenches[benchId]
    local xPlayer = getPlayer(src)
    if not bench or not xPlayer then
        return
    end

    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > Config.MaxCraftAmount then
        return notify(src, 'notify_invalid_amount')
    end

    local recipe = getRecipe(bench, recipeName)
    if not recipe then
        return notify(src, 'notify_invalid_recipe')
    end

    local job = xPlayer.getJob()
    if not benchAccess(job, bench) or not recipeAccess(job, recipe) then
        return notify(src, 'notify_no_access')
    end

    local location = nearbyLocation(src, bench)
    if not location then
        return notify(src, 'notify_too_far')
    end

    local queue = queues[src]
    if queue and queue.benchId ~= benchId then
        return notify(src, 'notify_other_bench')
    end
    if queue and #queue.jobs >= Config.MaxQueueSize then
        return notify(src, 'notify_queue_full', Config.MaxQueueSize)
    end

    for _, input in ipairs(recipe.inputs) do
        local item = xPlayer.getInventoryItem(input.item)
        if not item or item.count < input.amount * count then
            return notify(src, 'notify_no_materials')
        end
    end

    for _, input in ipairs(recipe.inputs) do
        xPlayer.removeInventoryItem(input.item, input.amount * count)
    end

    jobCounter = jobCounter + 1
    local entry = {
        id = jobCounter,
        recipe = recipe,
        count = count,
        duration = recipe.duration * count,
    }

    if not queue then
        queues[src] = { benchId = benchId, location = location, jobs = {} }
        queue = queues[src]
    end
    queue.jobs[#queue.jobs + 1] = entry

    notify(src, 'notify_started', Localize(recipe.label), count)
    syncQueue(src)

    if #queue.jobs == 1 then
        startJob(src)
    end
end)

RegisterNetEvent('OwnCrafting:cancelQueue', function(reason)
    local src = source
    if reason ~= 'distance' then
        reason = 'manual'
    end
    cancelQueue(src, reason)
end)

AddEventHandler('playerDropped', function()
    queues[source] = nil
end)
