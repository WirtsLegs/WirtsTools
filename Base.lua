-----------------------------------------------------------------------
--Base.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
-----------------------------------------------------------------------
WT = {}
WT.utils = {}


local segment = {
    id = world.VolumeType.SEGMENT,
    params = {
        from = {},
        to = {}
    }
}

--add a startswith function to the lua string object
function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

--protected call (error handling)
function WT.utils.p(...)
    local status, retval = pcall(...)
    env.warning(retval, false)
    if not status then
        return nil
    end
    return retval
end

function WT.utils.TableConcat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

function WT.utils.getAvgPoint(group)
    local size = group:getSize()
    local x, y, z = 0, 0, 0
    local units = group:getUnits()
    for u = 1, size do
        local point = units[u]:getPoint()
        x = x + point.x
        y = y + point.y
        z = z + point.z
    end

    return { x = x / size, y = y / size, z = z / size }
end

function WT.utils.deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function WT.utils.isInList(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

--import zones from mission file
function WT.utils.getZones()
    WT.zones = {}
    local zones = nil
    local zones_in = nil
    if env.mission then
        zones = {}
        zones_in = env.mission.triggers.zones
        for z = 1, #zones_in do
            zones[zones_in[z]["name"]] = zones_in[z]
        end
    end
    WT.zones = zones
end

function WT.utils.polygon(points)
    local polygon = {}
    for i, p in ipairs(points) do
        if type(p) == "table" and p.x and p.y then
            table.insert(polygon, p)
        end
    end
    return polygon
end

function WT.utils.isInPolygon(p, polygon)
    -- Part 1, checking wheter point is not inside the bounding box of the polygon. (optional)
    local minX, minY, maxX, maxY = polygon[1].x, polygon[1].y, polygon[1].x, polygon[1].y
    for i, q in ipairs(polygon) do
        minX, maxX, minY, maxY = math.min(q.x, minX), math.max(q.x, maxX), math.min(q.y, minY), math.max(q.y, maxY)
    end
    if p.x < minX or p.x > maxX or p.y < minY or p.y > maxY then
        return false
    end
    -- If the point is not inside the bounding box of the polygon. it can't be in the polygon.
    -- You can delete this first part if you want, it's here just to improve performance.

    -- Part 2, logic behind this is explained here https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html
    -- it supports multiple components, concave components and holes in polygons as well
    local inside = false
    local j = #polygon
    for i, q in ipairs(polygon) do
        if (q.y > p.y) ~= (polygon[j].y > p.y) and p.x < (polygon[j].x - q.x) * (p.y - q.y) / (polygon[j].y - q.y) + q.x then
            inside = not (inside)
        end
        j = i
    end

    return inside
end

WT.utils.eventListeners = {}

-- Register a listener for one or more event IDs
-- WT.registerEventListener(world.event.S_EVENT_SHOT, function(event) ... end)
-- WT.registerEventListener({world.event.S_EVENT_HIT, world.event.S_EVENT_BIRTH}, function(event) ... end)
function WT.utils.registerEventListener(eventIDs, listener)
    if type(eventIDs) ~= "table" then eventIDs = { eventIDs } end
    for _, id in ipairs(eventIDs) do
        if not WT.utils.eventListeners[id] then WT.utils.eventListeners[id] = {} end
        table.insert(WT.utils.eventListeners[id], listener)
    end
end

-- Master event handler
function WT.utils.masterEventHandler(event)
    local listeners = WT.utils.eventListeners[event.id]
    if listeners then
        for _, listener in ipairs(listeners) do
            listener(event)
        end
    end
end

-- Register the master handler once using an object with onEvent method
local WT_eventHandler = {}
function WT_eventHandler:onEvent(event)
    WT.utils.masterEventHandler(event)
end
world.addEventHandler(WT_eventHandler)


function WT.utils.VecMag(vec)
    if vec.z == nil then
        return (vec.x ^ 2 + vec.y ^ 2) ^ 0.5
    else
        return (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
    end
end

WT.tasks = {}
WT.tasks.setInvisible = {
    id = 'SetInvisible',
    params = {
        value = true
    }
}
WT.tasks.setVisible = {
    id = 'SetInvisible',
    params = {
        value = false
    }
}
WT.tasks.groundMission = {
    id = 'Mission',
    params = {
        airborne = false,
        route = {
            points = {},
        }
    }
}
WT.tasks.airMission = {
    id = 'Mission',
    params = {
        airborne = true,
        route = {
            points = {},
        }
    }
}

function WT.utils.isInCircle(p, r, c)
    return WT.utils.VecMag({ x = p.x - c.x, y = 0, z = p.z - c.z }) < r
end

function WT.utils.explodePoint(args)
    trigger.action.explosion(args.point, args.power)
    return nil
end

function WT.utils.detonateUnit(args)
    local unit = args.unit
    if not power then
        power = 1000
    end
    if type(args.unit) == "string" then
        args.unit = Unit.getByName(unit)
    end
    if args.unit then
        local point = WT.utils.p(unit.getPoint, args.unit)
        if point then
            trigger.action.explosion(point, args.power)
        end
    end
end

--blows up all units in a group on slightly randomized delays (so not all perfectly in sync)
function WT.utils.detonateGroup(groupName, power)
    if not power then
        power = 1000
    end
    local group = Group.getByName(groupName)
    local units = group:getUnits()
    for i = 1, #units do
        timer.scheduleFunction(WT.utils.detonateUnit, { unit = units[i], power = power },
            timer.getTime() + 0.1 * i * math.random(1, 10))
    end
end

--will cleanup a sphere described by a Vec3 point (x,y,z) and a radius
function WT.utils.cleanupSphere(point, radius)
    point.y = land.getHeight({ x = point.x, y = point.z })
    local volS = {
        id = world.VolumeType.SPHERE,
        params = {
            point = point,
            radius = radius
        }
    }
    world.removeJunk(volS)
end

--will cleanup a sphere described by a circular zone
function WT.utils.cleanupZone(zone)
    local sphere = trigger.misc.getZone(zone)
    WT.utils.cleanupSphere(sphere.point, sphere.radius)
end

function WT.utils.inZone(point, zone)
    if zone.type == 2 then
        if WT.utils.isInPolygon(point, WT.utils.polygon(zone.verticies)) then --verticies
            return true
        end
    else
        if WT.utils.VecMag({ x = zone.x - point.x, y = zone.y - point.y }) < zone.radius then
            return true
        end
    end
    return false
end

WT.utils.getZones()