----------------
--WirtsTools
--version 2.1.6
--Directions: load this script as Do Script File, then call setup fucntions in a do script action for the features
-- you wish to use (scroll to line 879 to see documentation on setup functions)
--Features:
--ImpactInZone
--ImpactNear
--PlayerNear
--coverMe
--invisAlt
--suppression
--missileDeath
--killswitch
--tasking
--stormtrooperAA
--shelling
--MLRS
--percentALive
--eject
--toggleStrobe
----------------
do
  WT = {}
  if idNum == nil then
    idNum = 0
  end


  --add a startswith function to the lua string object
  function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
  end

  --protected call (error handling)
  local function p(...)
    local status, retval = pcall(...)
    env.warning(retval, false)
    if not status then
      return nil
    end
    return retval
  end

  local function TableConcat(t1, t2)
    for i = 1, #t2 do
      t1[#t1 + 1] = t2[i]
    end
    return t1
  end

  local function deepCopy(object)
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


  --import zones from mission file
  local function getZones()
    WT.zones = {}
    --WT.zones.path =os.getenv('APPDATA').."\\..\\Local\\Temp\\DCS\\Mission\\mission"
    --p(dofile,WT.zones.path)
    local zones = nil
    local zones_in = nil
    if env.mission then
      zones = {}
      zones_in = env.mission.triggers.zones
      for z = 1, #zones_in do
        zones[zones_in[z]["name"]] = zones_in[z]
      end
    end
    WT.zones.zones = zones
  end


  local function Polygon(points)
    local polygon = {}
    for i, p in ipairs(points) do
      if type(p) == "table" and p.x and p.y then
        table.insert(polygon, p)
      end
    end
    return polygon
  end

  local function IsInPolygon(p, polygon)
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

  --create event handler
  local function newEventHandler(f)
    local handler = {}
    idNum = idNum + 1
    handler.id = idNum
    handler.f = f
    function handler:onEvent(event)
      self.f(event)
    end

    world.addEventHandler(handler)
    return handler.id
  end

  local function vecMag(vec)
    if vec.z == nil then
      return (vec.x ^ 2 + vec.y ^ 2) ^ 0.5
    else
      return (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
    end
  end

  local SetInvisible = {
    id = 'SetInvisible',
    params = {
      value = true
    }
  }
  local SetVisible = {
    id = 'SetInvisible',
    params = {
      value = false
    }
  }

  local function IsInCircle(p, r, c)
    return vecMag({x = p.x - c.x, y = 0, z = p.z - c.z}) < r
  end

  local function explodePoint(point, time)
    trigger.action.explosion(point, 1000)
    return nil
  end

  --blows up all units in a group on slightly randomized delays (so not all perfectly in sync)
  function WT.detonateGroup(groupName)
    local group = Group.getByName(groupName)
    local units = group:getUnits()
    for i = 1, #units do
      timer.scheduleFunction(explodePoint, units[i]:getPoint(), timer.getTime() + 0.1 * math.random(1, 10))
    end
  end

  --will cleanup a sphere described by a Vec3 point (x,y,z) and a radius
  function WT.cleanupPoint(point, radius)
    point.y = land.getHeight({x = point.x, y = point.z})
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
  function WT.cleanupZone(zone)
    local sphere = trigger.misc.getZone(zone)
    sphere.point.y = land.getHeight({x = sphere.point.x, y = sphere.point.z})
    local volS = {
      id = world.VolumeType.SPHERE,
      params = {
        point = sphere.point,
        radius = sphere.radius
      }
    }
    world.removeJunk(volS)
  end

  -----------------------------------------------------------------------
  --MissileDeath
  ----------------------------------------------------------------------
  WT.missileDeath = {}

  local function destroyIt(target)
    if target then
      if target:isExist() then
        local point = p(target.getPoint, target)
        trigger.action.explosion(point, 3000)
      end
    end
    return nil
  end

  --update weapon position and trigger impact checks
  function WT.missileDeath.updateWeapon(weapon, time)
    if p(weapon.weapon.isExist, weapon.weapon) then
      weapon.last_point = weapon.weapon:getPoint()
      return time + 0.05
    else
      if weapon.name then
        if weapon.target == nil then
          return nil
        end
        local tp = p(weapon.target.getPoint, weapon.target)
        if tp == nil then
          return nil
        end
        if vecMag({x = weapon.last_point.x - tp.x, y = weapon.last_point.y - tp.y, z = weapon.last_point.z - tp.z}) < 50 then
          trigger.action.explosion(tp, 3000)
        end
      end
      return nil
    end
  end

  function WT.missileDeath.handleShots(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired missiles
      local weapon_category = event.weapon:getDesc().category
      local weapon_name = event.weapon:getTypeName()
      if weapon_category == 1 then
        local weapon = {
          weapon = event.weapon,
          name = weapon_name,
          category = weapon_category,
          target = event.weapon
              :getTarget()
        }
        timer.scheduleFunction(WT.missileDeath.updateWeapon, weapon, timer.getTime() + 0.05)
      end
    end
  end

  -----------------------------------------------------------------------
  --ImpactInZone
  ----------------------------------------------------------------------

  WT.impactInZone = {}
  WT.impactInZone.interval = 0.05
  local impactInZone = {}
  WT.impactInZone.instances = {}
  --WT.impactInZone.trackedWeapons = {}
  WT.impactInZone.help = false
  WT.impactInZone.debug = false

  --check if shot munition is valid for any instances
  function impactInZone.checkShots(weapon, category)
    for i = 1, #WT.impactInZone.instances do
      if WT.impactInZone.debug then
        trigger.action.outText(weapon, 5, false)
        if WT.impactInZone.instances[i].munition then
          trigger.action.outText(WT.impactInZone.instances[i].munition, 5, false)
        end
      end
      if weapon == WT.impactInZone.instances[i].munition or (WT.impactInZone.instances[i].munition == 0 and (category == 3 or category == 2 or category == 1)) then
        return true
      end
    end
    return false
  end

  function impactInZone.inZone(point, zone)
    if zone.type == 2 then
      if IsInPolygon(point, Polygon(zone.verticies)) then --verticies
        return true
      end
    else
      if vecMag({x = zone.center.x - point.x, y = zone.center.y - point.y}) < zone.radius then
        return true
      end
    end
    return false
  end

  --check if a munition ceased existing in a zone
  function impactInZone.checkImpacts(point, alt, weapon, category)
    if WT.impactInZone.debug then
      trigger.action.outText("checking for impact " .. weapon, 5, false)
    end
    for i = 1, #WT.impactInZone.instances do
      if weapon == WT.impactInZone.instances[i].munition or (WT.impactInZone.instances[i].munition == 0 and (category == 3 or category == 2)) then
        if WT.impactInZone.debug then
          trigger.action.outText("instance found", 5, false)
        end
        --if vecMag({x=WT.impactInZone.instances[i].center.x-point.x,y=WT.impactInZone.instances[i].center.y-point.y})<WT.impactInZone.instances[i].radius then
        if impactInZone.inZone(point, WT.impactInZone.instances[i]) then
          if WT.impactInZone.debug then
            trigger.action.outText("range good", 5, false)
          end
          trigger.action.setUserFlag(WT.impactInZone.instances[i].flag,
            trigger.misc.getUserFlag(WT.impactInZone.instances[i].flag) + 1)
          if WT.impactInZone.debug then
            trigger.action.outText("impact detected", 5, false)
            trigger.action.outText(
              "flag " ..
              WT.impactInZone.instances[i].flag ..
              " incremented" .. trigger.misc.getUserFlag(WT.impactInZone.instances[i].flag), 5, false)
          end
        end
      end
    end
  end

  --update weapon position and trigger impact checks
  function impactInZone.updateWeapon(weapon, time)
    if p(weapon.weapon.isExist, weapon.weapon) then
      local loc = weapon.weapon:getPoint()
      weapon.last_point = {x = loc.x, y = loc.z}
      local grnd = land.getHeight(weapon.last_point)
      weapon.last_alt = loc.y - grnd
      return time + WT.impactInZone.interval
    else
      if weapon.name and weapon.last_point then
        if WT.impactInZone.debug then
          trigger.action.outText(
            "Weapon gone, checking impact location x=" .. weapon.last_point.x .. "y= " .. weapon.last_point.y, 5, false)
        end
        impactInZone.checkImpacts(weapon.last_point, weapon.last_alt, weapon.name, weapon.category)
      end
      return nil
    end
  end

  --event handler, checks new shots
  function impactInZone.handleShots(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired missiles
      local weapon_name = event.weapon:getTypeName()
      local weapon_category = event.weapon:getDesc().category
      if WT.impactInZone.debug then
        if WT.impactInZone.debug then
          trigger.action.outText(weapon_name .. " shot detected", 5, false)
        end
      end
      if WT.impactInZone.help then
        trigger.action.outText(weapon_name, 5, false)
      else
        if WT.impactInZone.debug then
          trigger.action.outText("checking for valid shot", 5, false)
        end
        if impactInZone.checkShots(weapon_name, weapon_category) then
          local weapon = {weapon = event.weapon, name = weapon_name, category = weapon_category}
          timer.scheduleFunction(impactInZone.updateWeapon, weapon, timer.getTime() + 0.05)
          if WT.impactInZone.debug then
            trigger.action.outText("valid shot detected", 5, false)
          end
        else
          if WT.impactInZone.debug then
            trigger.action.outText("shot invalid", 5, false)
          end
        end
      end
    end
  end

  -----------------------------------------------------------------------
  --ImpactNear
  ----------------------------------------------------------------------
  WT.impactNear = {}
  WT.impactNear.interval = 0.05
  WT.impactNear.instances = {}

  --check if shot munition is valid for any instances
  function WT.impactNear.checkShots(weapon, category)
    for i = 1, #WT.impactNear.instances do
      if weapon == WT.impactNear.instances[i].munition or (WT.impactNear.instances[i].munition == 0 and (category == 3 or category == 2 or category == 1)) then
        return true
      end
    end
    return false
  end

  function WT.impactNear.inZone(point, zone)
    local ref = nil
    for p = 1, #zone.u do
      ref = zone.lastLoc[zone.u[p]]
      if vecMag({x = ref.x - point.x, y = ref.z - point.y}) < zone.radius then
        return true
      end
    end

    return false
  end

  --check if a munition ceased existing in a zone
  function WT.impactNear.checkImpacts(point, alt, weapon, category)
    for i = 1, #WT.impactNear.instances do
      if weapon == WT.impactNear.instances[i].munition or (WT.impactNear.instances[i].munition == 0 and (category == 3 or category == 2)) then
        if point then
          if WT.impactNear.inZone(point, WT.impactNear.instances[i]) == true then
            trigger.action.setUserFlag(WT.impactNear.instances[i].flag,
              trigger.misc.getUserFlag(WT.impactNear.instances[i].flag) + 1)
          end
        end
      end
    end
  end

  function WT.impactNear.updateTarget(_, time)
    for i = 1, #WT.impactNear.instances do
      local loc = WT.impactNear.instances[i].lastLoc
      if loc == nil then
        loc = {}
      end

      for u = 1, #WT.impactNear.instances[i].u do
        local unit = Unit.getByName(WT.impactNear.instances[i].u[u])
        if unit then
          local point = p(unit.getPoint, unit)
          if point then
            loc[WT.impactNear.instances[i].u[u]] = point
          end
        end
      end
      WT.impactNear.instances[i].lastLoc = loc
    end
    return time + 1
  end

  --update weapon position and trigger impact checks
  function WT.impactNear.updateWeapon(weapon, time)
    if p(weapon.weapon.isExist, weapon.weapon) then
      local loc = weapon.weapon:getPoint()
      weapon.last_point = {x = loc.x, y = loc.z}
      local grnd = land.getHeight(weapon.last_point)
      weapon.last_alt = loc.y - grnd
      return time + WT.impactNear.interval
    else
      if weapon.name and weapon.last_point then
        WT.impactNear.checkImpacts(weapon.last_point, weapon.last_alt, weapon.name, weapon.category)
      end
      return nil
    end
  end

  --event handler, checks new shots
  function WT.impactNear.handleShots(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired missiles
      local weapon_name = event.weapon:getTypeName()
      local weapon_category = event.weapon:getDesc().category
      if WT.impactNear.checkShots(weapon_name, weapon_category) == true then
        local weapon = {weapon = event.weapon, name = weapon_name, category = weapon_category}
        timer.scheduleFunction(WT.impactNear.updateWeapon, weapon, timer.getTime() + 0.05)
      end
    end
  end

  -----------------------------------------------------------------------
  --PlayerNear
  ----------------------------------------------------------------------
  WT.playerNear = {}
  WT.playerNear.groups = {}
  local playerNear = {}

  function playerNear.checkGroups(g1, g2)
    local group1 = p(Group.getByName, g1)
    local group2 = p(Group.getByName, g2)
    if not (group1 and group2) then
      return -1
    end
    local g1_units = p(Group.getUnits, group1)
    local g2_units = p(Group.getUnits, group2)
    if not (g1_units and g2_units) then
      return -1
    end
    local shortest = -1

    for i = 1, #g1_units do
      local p1 = p(Unit.getPoint, g1_units[i])
      if p1 then
        for j = 1, #g2_units do
          local p2 = p(Unit.getPoint, g2_units[j])
          if p2 then
            local dist = vecMag({x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z})
            if shortest > -1 then
              if dist < shortest then
                shortest = dist
              end
            else
              shortest = dist
            end
          end
        end
      end
    end

    return shortest
  end

  function playerNear.getPlayerGroups(co)
    local players = coalition.getPlayers(co)
    local groups = {}
    for p = 1, #players do
      local grp = players[p]:getGroup()
      groups[grp:getName()] = 1
    end
    return groups
  end

  function playerNear.check(co, time)
    local validated = false
    for g = 1, #WT.playerNear.groups do
      validated = false
      if WT.playerNear.groups[g].player_groups == 0 then
        local grps = playerNear.getPlayerGroups(WT.playerNear.groups[g].co)
        for r, s in pairs(grps) do
          local dist = playerNear.checkGroups(WT.playerNear.groups[g].name, r)
          if dist ~= -1 then
            if dist <= WT.playerNear.groups[g].distance then
              validated = true
            end
          end
        end
      else
        if not WT.playerNear.groups[g].player_groups then
          return time + 1
        end
        for r = 1, #WT.playerNear.groups[g].player_groups do
          local dist = playerNear.checkGroups(WT.playerNear.groups[g].name, WT.playerNear.groups[g].player_groups[r])
          if dist ~= -1 then
            if dist <= WT.playerNear.groups[g].distance then
              validated = true
            end
          end
        end
      end
      if validated == true then
        trigger.action.setUserFlag(WT.playerNear.groups[g].flag, trigger.misc.getUserFlag(WT.playerNear.groups[g].flag) +
          1)
      else
        trigger.action.setUserFlag(WT.playerNear.groups[g].flag, 0)
      end
    end
    return time + 1
  end

  -----------------------------------------------------------------------
  --CoverMe
  ----------------------------------------------------------------------
  WT.coverMe = {}
  WT.coverMe.groups = {}
  WT.coverMe.status = {}
  local coverMe = {}


  function coverMe.getPlayerGroups(co)
    local players = coalition.getPlayers(co)
    local groups = {}
    for p = 1, #players do
      local grp = players[p]:getGroup()
      groups[grp:getName()] = 1
    end
    return groups
  end

  function coverMe.getAIUnits(co)
    local grps = coalition.getGroups(co, 0)
    local units = {}
    for g = 1, #grps do
      local gUnits = grps[g]:getUnits()
      for u = 1, #gUnits do
        if gUnits[u]:isActive() and gUnits[u]:getPlayerName() == nil then
          units[#units + 1] = gUnits[u]
        end
      end
    end
    return units
  end

  function coverMe.checkGroups(group, co)
    local group1 = p(Group.getByName, group)
    if not (group1) then
      return -1
    end
    local g1_units = p(Group.getUnits, group1)
    local g2_units = coverMe.getAIUnits(co) --p(Group.getUnits,group2)
    if not (g1_units and g2_units) then
      return -1
    end
    local shortest = -1

    for i = 1, #g1_units do
      local p1 = p(Unit.getPoint, g1_units[i])
      if p1 then
        for j = 1, #g2_units do
          local p2 = p(Unit.getPoint, g2_units[j])
          if p2 then
            local dist = vecMag({x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z})
            if shortest > -1 then
              if dist < shortest then
                shortest = dist
              end
            else
              shortest = dist
            end
          end
        end
      end
    end
    return shortest
  end

  function coverMe.check(co, time)
    for g = 1, #WT.coverMe.groups do
      if WT.coverMe.groups[g].group == 1 or WT.coverMe.groups[g].group == 2 then
        local grps = coverMe.getPlayerGroups(WT.coverMe.groups[g].group)
        for r, s in pairs(grps) do
          local dist = coverMe.checkGroups(r, WT.coverMe.groups[g].co)
          if dist ~= -1 then
            if dist <= WT.coverMe.groups[g].distance then
              Group.getByName(r):getController():setCommand(SetInvisible)
            else
              Group.getByName(r):getController():setCommand(SetVisible)
            end
          else
            Group.getByName(r):getController():setCommand(SetVisible)
          end
        end
      else
        if not WT.coverMe.groups[g].group then
          return time + 1
        end
        for r = 1, #WT.coverMe.groups[g].group do
          local dist = coverMe.checkGroups(WT.coverMe.groups[g].group[r], WT.coverMe.groups[g].co)
          if dist ~= -1 then
            if dist <= WT.coverMe.groups[g].distance then
              Group.getByName(r):getController():setCommand(SetInvisible)
            else
              Group.getByName(r):getController():setCommand(SetVisible)
            end
          else
            Group.getByName(r):getController():setCommand(SetVisible)
          end
        end
      end
    end
    return time + 1
  end

  ---------------------------------------------------------------------
  --  InvisAlt
  ---------------------------------------------------------------------
  WT.invisAlt = {}
  local invisAlt = {}
  invisAlt.triggerAlt = 0


  function invisAlt.checkPlayer(player, time)
    local p = p(player.getPoint, player)
    if p == nil then
      return nil
    end
    local s = land.getHeight({x = p.x, y = p.z})
    local alt = p.y - s
    if (invisAlt.higher == false and alt > invisAlt.triggerAlt) or (invisAlt.higher == true and alt < invisAlt.triggerAlt) then
      player:getGroup():getController():setCommand(SetVisible)
    else
      player:getGroup():getController():setCommand(SetInvisible)
    end
    return time + 0.5
  end

  function invisAlt.eventHandle(event)
    local name = ""
    if event.id == world.event.S_EVENT_BIRTH then
      name = event.initiator:getPlayerName()
      if name ~= nil then
        timer.scheduleFunction(invisAlt.checkPlayer, event.initiator, timer.getTime() + 1)
      end
    end
  end

  function invisAlt.initPlayers(players)
    if players == 1 or players == 2 then
      local players = coalition.getPlayers(players)
      for i = 1, #players do
        timer.scheduleFunction(invisAlt.checkPlayer, players[i], timer.getTime() + 1)
      end
    else
      local grp = Group.getByName(players)
      local un = grp:getUnits()
      for u = 1, #un do
        timer.scheduleFunction(invisAlt.checkPlayer, un[u], timer.getTime() + 1)
      end
    end
  end

  --------------------------------------------------------------------
  --Suppression
  --------------------------------------------------------------------
  WT.suppression = {}
  local suppression = {}
  suppression.suppressed_groups = {}
  suppression.time_on_kill = 5
  suppression.time_on_hit = 2
  suppression.coalition = -1
  suppression.all_ground = true
  suppression.ai_enable = true

  function suppression.suppress(dur, group)
    local found = false
    for g = 1, #suppression.suppressed_groups do
      if suppression.suppressed_groups[g].grp == group then
        found = true
        local timing = suppression.suppressed_groups[g].timing - timer.getTime()
        if timing < 4 * dur then
          if timing < 0 then
            suppression.suppressed_groups[g].timing = timer.getTime() + dur
            group:getController():setOption(0, 4) --weapons hold
            suppression.suppressed_groups[g].suppressed = true
          else
            suppression.suppressed_groups[g].timing = suppression.suppressed_groups[g].timing + dur
          end
        end
      end
    end
    if found == false then
      suppression.suppressed_groups[#suppression.suppressed_groups + 1] = {
        grp = group,
        timing = timer.getTime() + dur,
        suppressed = true,
        size =
            group:getSize()
      }
      group:getController():setOption(0, 4)
    end
  end

  function suppression.checkSuppression(bunk, time) --bunk is a placeholder because DCS lua is dumb
    local toRemove = {}
    for g = 1, #suppression.suppressed_groups do
      if suppression.suppressed_groups[g].grp:isExist() then
        if suppression.suppressed_groups[g].timing - timer.getTime() <= 0 and suppression.suppressed_groups[g].suppressed == true and suppression.suppressed_groups[g].grp:isExist() then
          suppression.suppressed_groups[g].grp:getController():setOption(0, 0) --weapons free
          suppression.suppressed_groups[g].suppressed = false
        end
        if suppression.suppressed_groups[g].size > suppression.suppressed_groups[g].grp:getSize() and suppression.time_on_kill > 0 then
          suppression.suppress(suppression.time_on_kill, suppression.suppressed_groups[g].grp)
          suppression.suppressed_groups[g].size = suppression.suppressed_groups[g].grp:getSize()
        end
      else
        --remove(suppressed_groups[g].gID)
        toRemove[#toRemove + 1] = g
      end
    end
    for r = 1, #toRemove do
      table.remove(suppression.suppressed_groups, toRemove[r])
    end
    if #suppression.suppressed_groups > 0 then
      return time + 0.10
    else
      return time + 1
    end
  end

  function suppression.handleEvents(event)
    if event.id == 2 then --hit
      if Object.getCategory(event.target) ~= 1 then
        return
      end
      if event.target:getDesc().Category ~= 2 and event.target:getDesc().Category ~= 3 then
        return
      end
      local grp = event.target:getGroup()
      if grp:isExist() and event.initiator then
        if event.initiator:getPlayerName() ~= nil or suppression.ai_enable == true then
          if grp:getSize() > 0 and grp:getCategory() == 2 then
            if suppression.all_ground == true then
              if coalition ~= nil or grp:getCoalition() == coalition then
                suppression.suppress(suppression.time_on_hit, grp)
              end
            else
              if string.starts(grp:getName(), "SUP_") then
                suppression.suppress(suppression.time_on_hit, grp)
              end
            end
          end
        end
      end
    end
  end

  -----------------------------------------------------
  --popFlare
  -----------------------------------------------------

  WT.popFlare = {}
  WT.popFlare.side = {0, 0}
  WT.popFlare.done = {}
  function WT.popFlare.popFlare(details, amount)
    local grp = Group.getByName(details.grp)
    local gid = grp:getID()
    local unit = p(grp.getUnit, grp, 1)
    if unit ~= nil then
      local target = unit:getPoint()
      trigger.action.signalFlare(target, details.colour, 0)
    end
  end

  function WT.popFlare.eventHandle(event)
    local name = ""
    if event.id == world.event.S_EVENT_BIRTH then
      local group = event.initiator:getGroup()
      local name = group:getName()
      if WT.popFlare.side[group:getCoalition()] == 1 and WT.popFlare.done[name] ~= 1 then
        WT.popFlare.done[name] = 1
        local grp = group:getID()
        missionCommands.addSubMenuForGroup(grp, "signal flares")
        missionCommands.addCommandForGroup(grp, "green flare", {[1] = "signal flares"}, WT.popFlare.popFlare,
          {grp = name, colour = 0})
        missionCommands.addCommandForGroup(grp, "red flare", {[1] = "signal flares"}, WT.popFlare.popFlare,
          {grp = name, colour = 1})
        missionCommands.addCommandForGroup(grp, "white flare", {[1] = "signal flares"}, WT.popFlare.popFlare,
          {grp = name, colour = 2})
        missionCommands.addCommandForGroup(grp, "yellow flare", {[1] = "signal flares"}, WT.popFlare.popFlare,
          {grp = name, colour = 3})
      end
    end
  end

  ---------------------------------------------------------------------
  --Killswitch
  ---------------------------------------------------------------------

  WT.killswitch = {}
  WT.killswitch.active = {}
  WT.killswitch.used = {}

  function WT.killswitch.killswitch(details)
    trigger.action.setUserFlag(details.flag, 1)
    if details.single == true then
      missionCommands.removeItemForGroup(details.id, {[1] = "killswitch"})
      WT.killswitch.used[details.name] = true
    end
  end

  function WT.killswitch.updateMenu(details, time)
    local cntgrp = p(Group.getByName, details.cName)
    local players = TableConcat(coalition.getPlayers(1), coalition.getPlayers(2))
    local group = nil
    for p = 1, #players do
      if string.match(players[p]:getPlayerName(), details.pname) then
        group = players[p]:getGroup():getName()
      end
    end

    if WT.killswitch.used[details.name] == true then
      return nil
    end

    if details.cName ~= group then
      if details.cID ~= nil then
        missionCommands.removeItemForGroup(details.cID, {[1] = "killswitch"})
        WT.killswitch.active[details.cID] = 0
      end
      if group then
        local gr = Group.getByName(group)
        local id = gr:getID()
        if WT.killswitch.active[id] ~= 1 then
          missionCommands.addSubMenuForGroup(gr:getID(), "killswitch")
          WT.killswitch.active[id] = 1
        end
        missionCommands.addCommandForGroup(gr:getID(), details.name, {[1] = "killswitch"}, WT.killswitch.killswitch,
          {flag = details.flag, single = details.single, name = details.name, id = details.cID})
        details.cID = gr:getID()
        details.cName = group
      end
    end
    return time + 5
  end

  -----------------------------
  --Tasking
  ----------------------------
  WT.tasking = {}
  WT.tasking.tasks = {}
  WT.tasking.ground = {
    id = 'Mission',
    params = {
      airborne = false,
      route = {
        points = {},
      }
    }
  }
  WT.tasking.air = {
    id = 'Mission',
    params = {
      airborne = true,
      route = {
        points = {},
      }
    }
  }

  function WT.tasking.relative(point, task, ground)
    local offsetX = point.x - task.params.route.points[1].x
    local offsetAlt = point.y - task.params.route.points[1].alt
    local offsetY = point.z - task.params.route.points[1].y
    for p = 2, task.params.route.points do
      task.params.route.points[p].x = task.params.route.points[p].x + offsetX
      task.params.route.points[p].y = task.params.route.points[p].y + offsetY

      if ground then
        task.params.route.points[p].alt = land.getHeight({
          x = task.params.route.points[p].x,
          y = task.params.route
              .points[p].y
        })
      else
        task.params.route.points[p].alt = task.params.route.points[p].alt + offsetAlt
      end
    end

    return task
  end

  function WT.tasking.getGroups()
    local grp_rt = env.mission['coalition']['blue']['country']
    local tgt = nil
    for c = 1, #grp_rt do
      if grp_rt[c]['vehicle'] then
        local grplocal = grp_rt[c]['vehicle']['group']
        for g = 1, #grplocal do
          if string.starts(grplocal[g]['name'], "TASK_") then
            WT.tasking.tasks[grplocal[g]['name']] = grplocal[g]["route"]["points"]
          end
        end
      end
      if grp_rt[c]['plane'] then
        local grplocal = grp_rt[c]['plane']['group']
        for g = 1, #grplocal do
          if string.starts(grplocal[g]['name'], "TASK_") then
            WT.tasking.tasks[grplocal[g]['name']] = grplocal[g]["route"]["points"]
          end
        end
      end
    end
  end

  ---------------------------------------------------------------------
  --StormtrooperAA
  ---------------------------------------------------------------------
  WT.stormtrooperAA = {}
  WT.stormtrooperAA.stormtroopers = {}

  local FireAtPoint = {
    id = 'FireAtPoint',
    params = {
      point = nil,
      radius = 10,
      expendQty = 10000,
      expendQtyEnabled = false,
      altitude = 0,
      alt_type = 0,
    }
  }

  local segment = {
    id = world.VolumeType.SEGMENT,
    params = {
      from = {},
      to = {}
    }
  }

  local function getAvgPoint(group)
    local size = group:getSize()
    local x, y, z = 0, 0, 0
    local units = group:getUnits()
    for u = 1, size do
      local point = units[u]:getPoint()
      x = x + point.x
      y = y + point.y
      z = z + point.z
    end

    return {x = x / size, y = y / size, z = z / size}
  end

  local function newStormtrooper()
    local stormtrooper = {

      coalition = nil,
      antiAir = nil,
      active_units = {},
      point = {},
      basic = false,
      --found = {};

      checkLOS = function(self, target, basic)
        local found = {}
        local ifFound = function(foundItem, val)
          found[#found + 1] = foundItem
          return true
        end

        local src = self.point
        src.y = land.getHeight({x = src.x, y = src.z})
        src.y = src.y + 5
        local vis = land.isVisible(src, target)
        if vis ~= true then
          return false
        end

        if basic == false then
          local vol = deepCopy(segment)

          vol.from = src
          vol.to = target

          world.searchObjects({1, 2, 3, 4, 5, 6}, vol, ifFound)

          for f = 1, #found do
            if found[f] ~= target then
              return false
            end
          end
          return true
        else
          return true
        end
      end,

      updateTarget = function(self, time)
        local players = coalition.getPlayers(self.coalition)
        local controller = nil
        local nearest = nil
        local nearest_d = nil
        local dist = nil
        local point = nil
        local ref = nil
        local task = nil
        if self.active_units:isExist() then
          self.point = getAvgPoint(self.active_units)
          ref = self.point
          nearest_d = 999999
          controller = self.active_units:getController()
          for i = 1, #players do
            --local detected = controller:isTargetDetected(players[i],1,2)
            --if detected  then
            point = players[i]:getPoint()
            local vel = players[i]:getVelocity()
            local temp_dist = vecMag({x = point.x - ref.x, y = point.y - ref.y, z = point.z - ref.z})
            point.x = point.x + (7 + 2 * (temp_dist / 3000)) * vel.x
            point.y = point.y + (7 + 2 * (temp_dist / 3000)) * vel.y
            point.z = point.z + (7 + 2 * (temp_dist / 3000)) * vel.z
            local height = land.getHeight({x = point.x, y = point.z})
            if point.y < height then
              point.y = height + 5
            end
            dist = vecMag({x = point.x - ref.x, y = point.y - ref.y, z = point.z - ref.z})
            if dist < nearest_d and self:checkLOS(point, self.basic) == true then
              nearest_d = dist
              nearest = point
            end
            --end
          end
          if nearest ~= nil and nearest_d < 8000 then
            task = FireAtPoint
            task.params.point = {x = nearest.x, y = nearest.z}
            task.params.altitude = nearest.y
            controller:pushTask(task)
          end
        end
        return time + 8
      end,

      getShooters = function(side)
        local allGround = coalition.getGroups(side) --,2)
        local shooters = {}
        for g = 1, #allGround do
          if string.starts(allGround[g]:getName(), "AA_") then
            shooters[#shooters + 1] = allGround[g]
          end
        end
        return shooters
      end,

      init = function(self, side, shooters, active, adv)
        self.coalition = side
        self.antiAir = shooters
        self.active_units = active
        if adv == true then
          self.basic = false
        else
          self.basic = true
        end
        timer.scheduleFunction(self.updateTarget, self, timer.getTime() + 1 + math.random(1, 100) / 100)
      end,

    }
    return stormtrooper;
  end
  ---------------------------------------------------------------------
  --Shelling
  ---------------------------------------------------------------------
  WT.shelling = {}

  function WT.shelling.selectPoint(zone)
    local z = trigger.misc.getZone(zone)
    local x = z.point.x
    local y = z.point.z
    local rad = z.radius

    local r = rad * math.sqrt(math.random())
    local theta = math.random() * 2 * math.pi

    local targX = x + r * math.cos(theta)
    local targY = y + r * math.sin(theta)

    return {x = targX, z = targY, y = land.getHeight({x = targX, y = targY})}
  end

  function WT.shelling.shell(details, time)
    if details.f ~= nil then
      local flag = trigger.misc.getUserFlag(details.f)
      if flag == 1 then
        return nil
      end
    end
    local target = WT.shelling.selectPoint(details.z)
    for s = 1, details.s do
      local safezone = trigger.misc.getZone(details.z .. "-safe-" .. tostring(s))
      if IsInCircle(target, safezone.radius, safezone.point) then
        return time + 0.01
      end
    end
    trigger.action.explosion(target, 50)
    return time + (math.random(1, 10) * details.r)
  end

  ---------------------------------------------------------------------
  --MLRS
  ---------------------------------------------------------------------

  WT.MLRS = {}
  WT.MLRS.types = {Smerch = 10, ["Uragan_BM-27"] = 10, ["Grad-URAL"] = 6, MLRS = 7, Smerch_HE = 10}

  function WT.MLRS.remove(weapon, time)
    p(weapon.destroy, weapon)
    return nil
  end

  function WT.MLRS.handleShots(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired missiles
      local type = event.initiator:getTypeName()
      local group = p(event.initiator.getGroup, event.initiator)
      local name = nil
      if group then
        name = group:getName()
      end
      if WT.MLRS.types[type] ~= nil then
        if #WT.MLRS.groups == 0 or WT.MLRS.groups[name] == 1 then
          timer.scheduleFunction(WT.MLRS.remove, event.weapon, timer.getTime() + WT.MLRS.types[type])
        end
      end
    end
  end

  ---------------------------------------------------------------------
  --percentAlive
  ---------------------------------------------------------------------
  WT.percentAlive = {}

  function WT.percentAlive.newTracker(groups, flag)
    local tracker = {
      grps = groups,
      full = 0,
      flg = flag,

      getFull = function(self)
        for g = 1, #self.grps do
          local grp = Group.getByName(self.grps[g])
          if grp then
            self.full = self.full + grp:getInitialSize()
          end
        end
      end,

      check = function(self, time)
        local current = 0
        for g = 1, #self.grps do
          local grp = Group.getByName(self.grps[g])
          if grp then
            current = current + grp:getSize()
          end
        end
        current = math.floor((current / self.full) * 100 + 0.5)
        trigger.action.setUserFlag(self.flg, current)
        if current > 0 then
          return time + 1
        end
        return nil
      end,
    }
    tracker:getFull()
    timer.scheduleFunction(tracker.check, tracker, timer.getTime() + 1)
  end

  ---------------------------------------------------------------------
  --Ejection Cleanup
  ---------------------------------------------------------------------
  WT.eject = {}
  idNum = 0
  function newEventHandler(f)
    local handler = {}
    idNum = idNum + 1
    handler.id = idNum
    handler.f = f

    function handler:onEvent(event)
      self.f(event)
    end

    world.addEventHandler(handler)
    return handler.id
  end

  local function cleanupEjection(pilot, time)
    if pilot then
      p(pilot.destroy, pilot)
    end
    return nil
  end

  local function handleEjects(event)
    if event.id then
      if event.id == 6 or event.id == 33 then
        if (math.random(1, 2)) == 2 then
          timer.scheduleFunction(cleanupEjection, event.target, timer.getTime() + 60)
        else
          event.target:destroy()
        end
      end
    end
  end

  ---------------------------------------------------------------------
  --IR STROBE
  ---------------------------------------------------------------------

  WT.strobe = {}
  WT.strobe.current = {}

  function WT.strobe.strobeOff(details, time)
    p(details.s.destroy, details.s)
    if (WT.strobe.current[details.d.g] == 0) then
      return nil
    end
    timer.scheduleFunction(WT.strobe.strobeOn, details.d, timer.getTime() + details.d.i)
    return nil
  end

  function WT.strobe.strobeOn(details, time)
    local pos = p(details.u.getPosition, details.u)
    if pos ~= nil then
      local to = {
        x = pos.p.x + pos.x.x * details.l.x + pos.y.x * details.l.y + pos.z.x * details.l.z,
        y = pos.p.y + pos.x.y * details.l.x + pos.y.y * details.l.y + pos.z.y * details.l.z,
        z = pos.p.z + pos.x.z * details.l.x + pos.y.z * details.l.y + pos.z.z * details.l.z
      }
      local spot = Spot.createInfraRed(details.u, details.l, to)
      timer.scheduleFunction(WT.strobe.strobeOff, {d = details, s = spot},
        timer.getTime() + details.i)
    end
    return nil
  end

  ---------------------------------------------------------------------
  --Setup Functions
  ---------------------------------------------------------------------

  -----------------------------
  --popFlare
  --Will give several command options to pop a signal flare at group lead for all groups
  --side: coaltion number for which side to apply to
  -----------------------------
  function WT.popFlare.setup(side)
    local groups = coalition.getGroups(side)
    newEventHandler(WT.popFlare.eventHandle)
    WT.popFlare.side[side] = 1

    for g = 1, #groups do
      if groups[g]:getCategory() == 0 then
        local grp = groups[g]:getID()
        if grp ~= nil then
          local name = groups[g]:getName()
          WT.popFlare.done[name] = 1
          missionCommands.addSubMenuForGroup(grp, "Signal Flares", nil)
          missionCommands.addCommandForGroup(grp, "green flare", {[1] = "Signal Flares"}, WT.popFlare.popFlare,
            {grp = name, colour = 0})
          missionCommands.addCommandForGroup(grp, "red flare", {[1] = "Signal Flares"}, WT.popFlare.popFlare,
            {grp = name, colour = 1})
          missionCommands.addCommandForGroup(grp, "white flare", {[1] = "Signal Flares"}, WT.popFlare.popFlare,
            {grp = name, colour = 2})
          missionCommands.addCommandForGroup(grp, "yellow flare", {[1] = "Signal Flares"}, WT.popFlare.popFlare,
            {grp = name, colour = 3})
        end
      end
    end
  end

  -----------------------------
  --impactInZone
  --munition: munition name
  --zone: zone name
  --flag: flag to increment
  --help: for finding munition names, set to true then drop munitions to get a message with the back-end name
  --debug: to get text debugging messages
  --WT.impactInZone.setup(nil,nil,nil,true,false) for getting munition names
  --WT.impactInZone.setup("AN_M64","target-1","flag2",false,true) for testing with debugging outputs (AN_M64 hitting in target-1 zone)
  --WT.impactInZone.setup("AN_M64","target-1","flag2",false,false) for actual mission use (no text outputs)
  --WT.impactInZone.setup(nil,"target-1","flag2",false,false) to function on all weapons of category "bomb" or "rocket"

  -----------------------------
  function WT.impactInZone.setup(munition, zone, flag, help, debug)
    WT.impactInZone.debug = debug
    if help then
      WT.impactInZone.help = true
      if #WT.impactInZone.instances < 1 then
        newEventHandler(impactInZone.handleShots)
      end
    else
      if #WT.impactInZone.instances < 1 then
        newEventHandler(impactInZone.handleShots)
      end
      trigger.action.setUserFlag(flag, 0)
      local z = nil
      if WT.zones.zones then
        z = WT.zones.zones[zone]
        if z["type"] == 2 then
          if munition then
            WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
              munition = munition,
              verticies = z.verticies,
              type = 2,
              flag =
                  flag
            }
          else
            WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
              munition = 0,
              verticies = z.verticies,
              type = 2,
              flag =
                  flag
            }
          end
        else
          if munition then
            WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
              munition = munition,
              center = {x = z.x, y = z.y},
              type = 0,
              radius =
                  z.radius,
              flag = flag
            }
          else
            WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
              munition = 0,
              center = {x = z.x, y = z.y},
              type = 0,
              radius =
                  z.radius,
              flag = flag
            }
          end
        end
      else
        z = trigger.misc.getZone(zone)
        if munition then
          WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
            munition = munition,
            center = {x = z.point.x, y = z.point.z},
            type = 0,
            radius =
                z.radius,
            flag = flag
          }
        else
          WT.impactInZone.instances[#WT.impactInZone.instances + 1] = {
            munition = 0,
            center = {x = z.point.x, y = z.point.z},
            type = 0,
            radius =
                z.radius,
            flag = flag
          }
        end
      end
    end
  end

  -----------------------------
  --impactNear: increments a flag when a munition lands near a unit or any unit in a group
  --munition: munition name
  --radius: radius of circle around units to check for impacts
  --group: name of group to check for impacts near
  --unit: name of unit to check for impacts near (if group has a value this will be ignored)
  --flag: flag to increment
  --WT.impactNear.setup("AN_M64",1000,"Group-1",nil,"flag1") detect AN_M64 impacts within 1000meters of any member of Group-1, increment flag1 when you do
  --WT.impactNear.setup("AN_M64",1000,nil,"Group-1-1","flag2") detect AN_M64 impacts within 1000meters of the unit named of Group-1-1, increment flag1 when you do
  -----------------------------
  function WT.impactNear.setup(munition, radius, group, unit, flag)
    if #WT.impactNear.instances < 1 then
      newEventHandler(WT.impactNear.handleShots)
    end
    trigger.action.setUserFlag(flag, 0)
    if group then
      local units = Group.getByName(group):getUnits()
      local unit = {}
      for u = 1, #units do
        unit[#unit + 1] = units[u]:getName()
      end
      if munition == nil then
        WT.impactNear.instances[#WT.impactNear.instances + 1] = {munition = 0, radius = radius, flag = flag, u = unit, lastLoc = {}}
      else
        WT.impactNear.instances[#WT.impactNear.instances + 1] = {
          munition = munition,
          radius = radius,
          flag = flag,
          u =
              unit,
          lastLoc = {}
        }
      end
    else
      if munition == nil then
        WT.impactNear.instances[#WT.impactNear.instances + 1] = {munition = 0, radius = radius, flag = flag, u = {unit}, lastLoc = {}}
      else
        WT.impactNear.instances[#WT.impactNear.instances + 1] = {munition = munition, radius = radius, flag = flag, u = {unit}, lastLoc = {}}
      end
    end

    timer.scheduleFunction(WT.impactNear.updateTarget, nil, timer.getTime() + 1)
  end

  ---------------------------
  --playerNear: increment a flag when a player is within a defined distance of a group
  --target_group: name of group you need to be near (in quotes)
  --player_groups: a list in the form {"name1","name2",...}, set to 2 for all blue players or 1 for all red
  --flag: flag name to increment when conditions met
  --distance: distance in meters to operate within
  --WT.playerNear.setup("target-1",2,"flag1",1000) this will increment flag1 whenever any players are near the group target-1
  --WT.playerNear.setup("target-1",{"player"},"flag2",500) this will increment the flag only when the specific given group is within range
  -----------------------------
  function WT.playerNear.setup(target_group, player_groups, flag, distance)
    trigger.action.setUserFlag(flag, 0)
    if #WT.playerNear.groups < 1 then
      timer.scheduleFunction(playerNear.check, 2, timer.getTime() + 1)
    end
    if player_groups == 1 then
      WT.playerNear.groups[#WT.playerNear.groups + 1] = {
        name = target_group,
        player_groups = 0,
        co = 1,
        flag = flag,
        distance =
            distance
      }
    elseif player_groups == 2 then
      WT.playerNear.groups[#WT.playerNear.groups + 1] = {
        name = target_group,
        player_groups = 0,
        co = 2,
        flag = flag,
        distance =
            distance
      }
    else
      WT.playerNear.groups[#WT.playerNear.groups + 1] = {
        name = target_group,
        player_groups = player_groups,
        flag = flag,
        distance =
            distance
      }
    end
  end

  -----------------------------
  --coverMe: renders players invisible when there is a allied AI aircraft within a defined range of the player
  --group: group that is covered by AI (1 or 2 for all player redfor or player blufor respectively)
  --coalition: coalition of AI players you want to be able to provide cover
  --distance: distance in meters they must be within to be covered
  --WT.playerNear.setup("target-1",2,"flag1",1000) this will increment flag1 whenever any players are near the group target-1
  --WT.playerNear.setup("target-1",{"player"},"flag2",500) this will increment the flag only when the specific given group is within range
  -----------------------------
  function WT.coverMe.setup(group, coalition, distance)
    if #WT.coverMe.groups < 1 then
      timer.scheduleFunction(coverMe.check, 2, timer.getTime() + 1)
    end
    WT.coverMe.groups[#WT.coverMe.groups + 1] = {group = group, co = coalition, distance = distance, covered = false}
  end

  ----------------------------------------------
  --InvisAlt: only works properly if each unit is their own group
  --alt: altitude (AGL) below which a group should be invisible
  --side: coalition enum (1 for red or 2 for blue) will apply to all players on that side
  ----------------------------------------------
  function WT.invisAlt.setup(alt, side, higher)
    invisAlt.triggerAlt = alt
    invisAlt.higher = higher
    invisAlt.initPlayers(side)
    newEventHandler(invisAlt.eventHandle)
  end

  ---------------------------------------------------------------------------
  --suppression: suppresses ground units when they are shot at, not that it has no wway of knowing the current ROEs so if they are already weapons hold they will go weapons free when shot, after suppression ends as a result
  --is extremely basic, all hits work so yes infantry can suppress a tank, will iterate on later
  --args are as follows
  --hit: suuppression time on hit in seconds
  --kill: suppression time on kill in seconds
  --all: should we apply to all ground units
  --side: 1 for red 2 for blue, nil for both
  --ai: if false then suppression only happens when shot by a player unit
  --WT.suppression.setup(2,5,true,1,false) 2 seconds suppression on hit, 5 on unit death, apply to all ground units, in red coalition, and only apply it if shot by a player
  --WT.suppression.setup(2,5,false,1,false) 2 seconds suppression on hit, 5 on unit death, apply to only ground units whose group name starts with SUP_, in red coalition, and only apply it if shot by a player
  ---------------------------------------------------------------------------
  function WT.suppression.setup(hit, kill, all, side, ai)
    suppression.time_on_kill = kill
    suppression.time_on_hit = hit
    suppression.ai_enable = ai
    suppression.all_ground = all
    newEventHandler(suppression.handleEvents)
    timer.scheduleFunction(suppression.checkSuppression, 1, timer.getTime() + 1)
  end

  ---------------------------------------------------------------------------
  --missileDeath
  --blows up any aircraft that a missile hits
  ---------------------------------------------------------------------------
  function WT.missileDeath.setup()
    newEventHandler(WT.missileDeath.handleShots)
  end

  ---------------------------------------------------------------------------
  --killSwitch
  --will only expose a radio f10 option to a given player-name's group
  --player: subname of the player (eg maple if the player's name will for sure contain maple)
  --name: name of the radio option
  --flag: flag to set when pressed
  ---------------------------------------------------------------------------
  function WT.killswitch.setup(player, name, flag, singleUse)
    local details = {pname = player, name = name, flag = flag, single = singleUse, cName = nil, cID = nil}
    timer.scheduleFunction(WT.killswitch.updateMenu, details, timer.getTime() + 1)
  end

  ---------------------------------------------------------------------------
  --Call when you want to drop a new mission into a group, designed to have taskings defined via late activation groups you never activate
  --group: name of the group you want to task
  --task: name of the group whose tasking you want to clone (must start with 'TASK_')
  ---------------------------------------------------------------------------

  function WT.tasking.task(group, task, relative)
    local grp = p(Group.getByName, group)
    if grp and grp:isExist() then
      local cat = grp:getCategory()
      local u = p(grp.getUnits, grp)
      if u and WT.tasking.tasks[task] then
        local u1 = u[1]:getPoint()
        local v1 = vecMag(u[1]:getVelocity())
        local tasking = nil
        if cat < 2 then
          tasking = deepCopy(WT.tasking.air)
        else
          tasking = deepCopy(WT.tasking.ground)
        end
        tasking.params['route']['points'] = deepCopy(WT.tasking.tasks[task])
        if relative then
          if cat < 2 then
            tasking = WT.tasking.relative(u1, tasking, false)
          else
            tasking = WT.tasking.relative(u1, tasking, true)
          end
        end
        tasking.params.route.points[1].alt = u1.y
        tasking.params.route.points[1].x = u1.x
        tasking.params.route.points[1].y = u1.z
        tasking.params.route.points[1].speed = v1

        local cnt = grp:getController()
        cnt:setTask(tasking)
      end
    end
  end

  ---------------------------------------------
  --StormtrooperAA: makes designated AA units shoot in the vincinity of valid targets instead of at them
  --note that at this time there is a bug where units tasked to fire at point will ignore that order if there is a valid target nearby
  --meaning to use this properly for now your targets need to be invisible
  --side: side of the expected targets (yes you can make blue shoot blue)
  --shooters: side of the AA you wish to control (all AA must be group name starts with AA_)
  --advanced: should advanced LOS detection be uysed (uses more CPU)
  --example: stormtrooperAA.setup(2,1,true) will give red shooting blue with advanced LOS use
  ---------------------------------------------
  function WT.stormtrooperAA.setup(side, shooters, advanced)
    local allGround = coalition.getGroups(shooters) --,2)
    local active = {}
    for g = 1, #allGround do
      if string.starts(allGround[g]:getName(), "AA_") then
        active[#active + 1] = allGround[g]
      end
    end
    for a = 1, #active do
      WT.stormtrooperAA.stormtroopers[#WT.stormtrooperAA.stormtroopers + 1] = newStormtrooper()
      WT.stormtrooperAA.stormtroopers[#WT.stormtrooperAA.stormtroopers]:init(side, shooters, active[a], advanced)
    end
  end

  ----------------------------------------------
  --Shelling: Like the vanilla shelling zone, but instead generates a sustained barrage within the target zone (only for circular zones)
  --zone: name of the zone you want to shell
  --rate: a number that when multiplied by a random value between 1 and 10 determines the delay between impacts, smaller number means faster barrage, try 0.03 to start
  --safe: how many safe zones (zones that shouldn't be shelled) there are, zones need to be named safe-1, safe-2, safe-3,... and are shared
  --between all instances of this function, so if in total you have 3 safe zones then if any of those zones overlap your target zone (even if only 1) put 3
  --flag: a flag to watch for and if set to true to stop the shelling
  --example:
  --WT.shelling.setup("target",0.03,1,"endit") will shell the zone named target, with a 0.03 rate modifier, there is 1 safe zone and shelling will stop when the flag "endit" is set
  ----------------------------------------------
  function WT.shelling.setup(zone, rate, safe, flag)
    timer.scheduleFunction(WT.shelling.shell, {z = zone, s = safe, r = rate, f = flag}, timer.getTime() + 1)
  end

  ----------------------------------------------
  --MLRS: Deletes MLRS rockets sometime after firing and after smoketrail is ended, for getting that MLRS launch visual effect without the lag of impact.
  --Obviously this does not work if you need the MLRS units to actually engage a target
  --Two ways to work, either specific groups or on all MLRS units
  --groups: a list of groupnames in the form {"name1","name2","name3"}
  --example:
  --WT.MLRS.setup({"SMERCH-1","SMERCH-2","SMERCH-3"}) will function only when units in groups names SMERCH-1, SMERCH-2, or SMERCH-3 fire
  --WT.MLRS.setup(nil) will function on all MLRS launches
  ----------------------------------------------
  function WT.MLRS.setup(groups)
    WT.MLRS.groups = {}
    if groups then
      for g = 1, #groups do
        groups[groups[g]] = 1
      end
    end
    newEventHandler(WT.MLRS.handleShots)
  end

  ----------------------------------------------
  --percentAlive: updates a provided flag with overall percent of indicated groups that are alive
  --groups: a list of groupnames in the form {"name1","name2","name3"}
  --flag: flag to populate with overal percent alive
  --example:
  ----------------------------------------------

  function WT.percentAlive.setup(groups, flag)
    WT.percentAlive.newTracker(groups, flag)
  end

  ----------------------------------------------
  --Ejection Cleanup: simple feature that deletes 50% of ejected pilots immediately and the rest after a minute
  ----------------------------------------------
  function WT.eject.init()
    newEventHandler(handleEjects)
  end

  ----------------------------------------------
  --IRstrobe: creates a blinking IR strobe on a unit
  --groups: can be either a reference to a group table, or the name of the group as a string
  --onoff: if true then sets the strobe on, if false sets it off, if nil then toggles it (on if currently off, off if currently on)
  --interval: time interval that the ir light is on/off eg a interval of 1 would be 1 seond on then 1 second off, personally I find 0.15 or 0.2 works well (note overly long intervals will look strange)
  --location: the strobe is attached at this Vec3 point in model local coordinates, nil for a default strobe above the unit
  --example:
  -- WT.strobe.toggleStrobe("infantry-1",true,0.2,nil) --will turn on a default strobe for a group named 'infantry-1' with a 0.2 second interval
  -- WT.strobe.toggleStrobe("infantry-2",nil,0.2,nil) --will toggle a default strobe on/off for 'infantry-2' if turning on it will use a interval of 0.2 seconds
  -- WT.strobe.toggleStrobe("Blackhawks",true,0.2,{x=-10.3,y=2.15,z=0}) --turn on strobes on top of the tail fins of all UH-60A Blackhawk units of the group
  -- WT.strobe.toggleStrobe("Kiowas",true,0.2,{x=-6.85,y=1.8,z=0.14}) --turn on strobes on top of the tail fins of all OH-58D Kiowa Warrior units of the group
  -- final example is meant to be used in a "do script" advanced waypoint action
  -- local grp = ... --this gets the current group
  -- WT.strobe.toggleStrobe(grp,true,0.2,{x=-1,y=1,z=0}) --toggles on a strobe 1 meter above and 1 meter back to the local coordinate origin of each unit of the group in question
  ----------------------------------------------
  function WT.strobe.toggleStrobe(group, onoff, interval, location)
    local units = nil
    local grp = nil
    if type(group) == "string" then
      grp = Group.getByName(group)
      if grp then
        units = grp:getUnits()
        grp = group
      else
        return
      end
    else
      units = group:getUnits()
      grp = group:getName()
    end

    if (WT.strobe.current[grp] == 1 and onoff == nil) or onoff == false then
      WT.strobe.current[grp] = 0
    elseif (WT.strobe.current[grp] == 0 or WT.strobe.current[grp] == nil) and (onoff ~= false) then
      WT.strobe.current[grp] = 1
      for u = 1, #units do
        if location == nil then
          local desc = units[u]:getDesc()
          location = {x = 0, y = desc.box.max.y - desc.box.min.y, z = 0}
        end
        timer.scheduleFunction(WT.strobe.strobeOn, {u = units[u], g = grp, l = location, i = math.max(0.15, interval)},
          timer.getTime() + 1 + (math.random(0, 100) / 100))
      end
    end
  end

  ------------------------------------------
  --System init calls here
  ------------------------------------------

  getZones()
  WT.tasking.getGroups()
end
