----------------
--WirtsTools
--version 2.2.1
--Directions: load this script as Do Script File, then call setup functions in a do script action for the features
-- you wish to use (scroll to line 879 to see documentation on setup functions)
----------------
do
  WT = {}
  WT.utils={}


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

  local function isInList(list, value)
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

  --create event handler
  local function newEventHandler(f)
    local handler = {}
    handler.f = f
    function handler:onEvent(event)
      self.f(event)
    end

    world.addEventHandler(handler)
    return handler.id
  end

  function WT.utils.VecMag(vec)
    if vec.z == nil then
      return (vec.x ^ 2 + vec.y ^ 2) ^ 0.5
    else
      return (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
    end
  end

  WT.tasks={}
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
      local point = p(unit.getPoint, args.unit)
      if point then
        trigger.action.explosion(point, args.power)
      end
    end
  end

  --blows up all units in a group on slightly randomized delays (so not all perfectly in sync)
  function WT.utils.detonateGroup(groupName,power)
    if not power then
      power = 1000
    end
    local group = Group.getByName(groupName)
    local units = group:getUnits()
    for i = 1, #units do
      timer.scheduleFunction(WT.utils.detonateUnit, {unit=units[i],power=power}, timer.getTime() + 0.1*i* math.random(1, 10))
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

  function WT.inZone(point, zone)
    if zone.type == 2 then
      if WT.utils.isInPolygon(point, WT.utils.polygon(zone.verticies)) then   --verticies
        return true
      end
    else
      if WT.utils.VecMag({ x = zone.x - point.x, y = zone.y - point.y }) < zone.radius then
        return true
      end
    end
    return false
  end

  WT.weapon = {}
  WT.weapon.debug = false
  WT.weapon.instanceTypes = {
    IN_ZONE = 1,
    NEAR = 2,
    IMPACT_IN_ZONE = 3,
    IMPACT_NEAR = 4,
    HIT = 5,
    SHOT=6
  }

  WT.weapon.weapons = {}
  WT.weapon.instances = {}

  function WT.weapon.newFilter()
    local weaponFilter = {
      Category = {},
      GuidanceType = {},
      MissileCategory = {},
      WarheadType = {},
      Coalition = {},
      Name = {},
      Func = {},

      Category_neg = {},
      GuidanceType_neg = {},
      MissileCategory_neg = {},
      WarheadType_neg = {},
      Coalition_neg = {},
      Name_neg = {},
      Func_neg = {},

      terms = 0,

      addTerm = function(self, field, term, match)
        if WT.weapon.debug and WT.weapon.debug == true then
          trigger.action.outText("attempting to add term: " .. field .. "=" .. tostring(term), 5, false)
        end
        -- Validate the field name
        if not self[field] and not self[field .. "_neg"] then
          error(string.format(
          "Unknown filter field '%s'. Must be one of: Category, GuidanceType, MissileCategory, WarheadType, Name, or Func.",
            tostring(field)))
        end

        if match == false then
          table.insert(self[field .. "_neg"], term)
          self.terms = self.terms + 1
          if WT.weapon.debug and WT.weapon.debug == true then
            trigger.action.outText(field .. "_neg added: " .. tostring(term), 5, false)
          end
        else
          table.insert(self[field], term)
          self.terms = self.terms + 1
          if WT.weapon.debug and WT.weapon.debug == true then
            trigger.action.outText(field .. " added: " .. tostring(term), 5, false)
          end
        end
      end,

      checkFilter = function(self, weapon, debug)
        if not debug then
          local debug=false
        end
        local desc = weapon:getDesc()
        if not desc then
          -- If getDesc() returns nil for some reason, fail or pass as you see fit
          return false
        end
        if self.terms == 0 then
          if debug == true then
            if weapon then
              local name        = weapon:getTypeName()
              local side        = weapon:getCoalition()
              local cat         = desc.category             -- e.g. Weapon.Category.MISSILE
              local guidance    = desc.guidance             -- e.g. Weapon.GuidanceType.IR
              local missileCat  = desc.missileCategory      -- e.g. Weapon.MissileCategory.AAM
              local warheadType = desc.warheadType
              trigger.action.outText("Filter Check Weapon", 5, false)
              trigger.action.outText("name: " .. name, 5, false)
              trigger.action.outText("coalition: " .. side, 5, false)
              trigger.action.outText("category: " .. tostring(cat), 5, false)
              trigger.action.outText("guidance: " .. tostring(guidance), 5, false)
              trigger.action.outText("missile cat: " .. tostring(missileCat), 5, false)
              trigger.action.outText("warhead: " .. tostring(warheadType), 5, false)
            else
              trigger.action.outText("weapon nil")
            end
          end
          return true;
        end

        if weapon == nil then
          if debug == true then
            trigger.action.outText("weapon nil")
          end
          return false;
        end



        -- Pull out the values we'll check
        local name        = weapon:getTypeName()
        local side        = weapon:getCoalition()
        local cat         = desc.category             -- e.g. Weapon.Category.MISSILE
        local guidance    = desc.guidance             -- e.g. Weapon.GuidanceType.IR
        local missileCat  = desc.missileCategory      -- e.g. Weapon.MissileCategory.AAM
        local warheadType = desc.warheadType          -- e.g. Weapon.WarheadType.HE
        -- (Depending on DCS version, you might need to check desc.warhead or something else.)
        if debug == true then
          trigger.action.outText("Filter Check Weapon", 5, false)
          trigger.action.outText("name: " .. name, 5, false)
          trigger.action.outText("coalition: " .. side, 5, false)
          trigger.action.outText("category: " .. tostring(cat), 5, false)
          trigger.action.outText("guidance: " .. tostring(guidance), 5, false)
          trigger.action.outText("missile cat: " .. tostring(missileCat), 5, false)
          trigger.action.outText("warhead: " .. tostring(warheadType), 5, false)
        end
        -- 1) Check Name (positive)
        if self.Name and #self.Name > 0 then
          -- If we have a positive Category filter, the weapon's Name must be in that list
          if not isInList(self.Name, name) then
            if debug == true then
              trigger.action.outText("Name filter", 5, false)
            end
            return false
          end
        end
        -- 1b) Check Name (negative)
        if self.Name_neg and #self.Name_neg > 0 then
          -- If the weapon's Name is in our negative list, fail
          if isInList(self.Name_neg, name) then
            if debug == true then
              trigger.action.outText("Name neg filter", 5, false)
            end
            return false
          end
        end
        if self.Coalition and #self.Coalition > 0 then
          -- If we have a positive Category filter, the weapon's Name must be in that list
          if not isInList(self.Coalition, side) then
            if debug == true then
              trigger.action.outText("Coalition filter", 5, false)
            end
            return false
          end
        end
        -- 1b) Check Name (negative)
        if self.Coalition_neg and #self.Coalition_neg > 0 then
          -- If the weapon's Name is in our negative list, fail
          if isInList(self.Coalition_neg, side) then
            if debug == true then
              trigger.action.outText("Coalition neg filter", 5, false)
            end
            return false
          end
        end

        -- 1) Check Category (positive)
        if self.Category and #self.Category > 0 then
          -- If we have a positive Category filter, the weapon's category must be in that list
          if not isInList(self.Category, cat) then
            if debug == true then
              trigger.action.outText("Category filter", 5, false)
            end
            return false
          end
        end
        -- 1b) Check Category (negative)
        if self.Category_neg and #self.Category_neg > 0 then
          -- If the weapon's category is in our negative list, fail
          if isInList(self.Category_neg, cat) then
            if debug == true then
              trigger.action.outText("Category neg filter", 5, false)
            end
            return false
          end
        end

        -- 2) Check GuidanceType (positive)
        if self.GuidanceType and #self.GuidanceType > 0 then
          if not isInList(self.GuidanceType, guidance) then
            if debug == true then
              trigger.action.outText("Guidance filter", 5, false)
            end
            return false
          end
        end
        -- 2b) Negative
        if self.GuidanceType_neg and #self.GuidanceType_neg > 0 then
          if isInList(self.GuidanceType_neg, guidance) then
            if debug == true then
              trigger.action.outText("Guidance neg filter", 5, false)
            end
            return false
          end
        end

        -- 3) Check MissileCategory (positive)
        if self.MissileCategory and #self.MissileCategory > 0 then
          if not isInList(self.MissileCategory, missileCat) then
            if debug == true then
              trigger.action.outText("Missile Category filter", 5, false)
            end
            return false
          end
        end
        -- 3b) Negative
        if self.MissileCategory_neg and #self.MissileCategory_neg > 0 then
          if isInList(self.MissileCategory_neg, missileCat) then
            if debug == true then
              trigger.action.outText("Missile Category neg filter", 5, false)
            end
            return false
          end
        end

        -- 4) Check WarheadType (positive)
        if self.WarheadType and #self.WarheadType > 0 then
          if not isInList(self.WarheadType, warheadType) then
            if debug == true then
              trigger.action.outText("Warhead filter", 5, false)
            end
            return false
          end
        end
        -- 4b) Negative
        if self.WarheadType_neg and #self.WarheadType_neg > 0 then
          if isInList(self.WarheadType_neg, warheadType) then
            if debug == true then
              trigger.action.outText("Warhead neg filter", 5, false)
            end
            return false
          end
        end

        if self.Func and #self.Func > 0 then
          for _, func in ipairs(self.Function) do
            if func(weapon,debug)==false then
              if debug == true then
                trigger.action.outText("Function filter", 5, false)
              end
              return false
            end
          end
        end
        -- 4b) Negative
        if self.Func_neg and #self.Func_neg > 0 then
          for _, func in ipairs(self.Function_neg) do
            if func(weapon,debug)==true then
              if debug == true then
                trigger.action.outText("Function filter", 5, false)
              end
              return false
            end
          end
        end

        -- If we didn't fail any checks, it passes
        return true
      end,
    }
    return weaponFilter
  end

  WT.weapon.filters = {
    ALL = WT.weapon.newFilter(),
    MISSILES = WT.weapon.newFilter(),
    BOMBS = WT.weapon.newFilter(),
    ROCKETS = WT.weapon.newFilter(),
    SHELLS = WT.weapon.newFilter()
  }

  WT.weapon.filters.MISSILES:addTerm("Category", Weapon.Category.MISSILE)
  WT.weapon.filters.BOMBS:addTerm("Category", Weapon.Category.BOMB)
  WT.weapon.filters.ROCKETS:addTerm("Category", Weapon.Category.ROCKET)
  WT.weapon.filters.SHELLS:addTerm("Category", Weapon.Category.SHELL)

  function WT.weapon.updateWeapon(weapon, time)
    if p(weapon.weapon.isExist, weapon.weapon) then
      weapon.last_point = weapon.weapon:getPoint()
      for i = 1, #weapon.instances do
        weapon.instances[i]:weaponUpdate(weapon)
      end
      return time + 0.05
    else
      for i = 1, #weapon.instances do
        if weapon.instances[i].active == true then
          weapon.instances[i]:weaponGone(weapon)
        end
      end
      return nil
    end
  end

  function WT.weapon.handleEvents(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired weapons
      local valid_instances = {}
      for x = 1, #WT.weapon.instances do
        if WT.weapon.instances[x]:checkEvent(event) == true then
          valid_instances[#valid_instances + 1] = WT.weapon.instances[x]
        end
      end
      if #valid_instances > 0 then
        local weapon_category = event.weapon:getDesc().category
        local weapon_name = event.weapon:getTypeName()
        local p1 = event.weapon:getPoint()
        local id = tostring(p1.x + p1.y + p1.z)
        id = id .. event.weapon:getTypeName()
        id = id .. tostring(timer.getTime())
        id = id .. tostring(math.random())
        local weapon = { weapon = event.weapon, name = weapon_name, category = weapon_category, target = event.weapon
        :getTarget(), id = id, instances = valid_instances, last_point = p1 }
        timer.scheduleFunction(WT.weapon.updateWeapon, weapon, timer.getTime() + 0.05)
      end
    elseif event.id == world.event.S_EVENT_HIT then --check hit events
      if WT.weapon.debug == true then
        trigger.action.outText("Hit detected", 5, false)
      end
      for x = 1, #WT.weapon.instances do
        WT.weapon.instances[x]:checkEvent(event)
      end
    end
  end

  -----WEAPON INSTANCE TYPES HERE

  function WT.weapon.newNearInstance(filter, target, range, flag)
    local tgt_type = ""
    local tgt = p(Unit.getByName, target)
    if tgt == nil then
      tgt = p(Group.getByName, target)
      if tgt == nil then
        return nil
      end
      tgt_type = "group"
    else
      tgt_type = "unit"
    end

    local inst = {
      filter = filter,
      target = target,
      tgtType = tgt_type,
      range = range,
      flag = flag,
      active = true,
      present = {},
      updateFunc = {},
      changeFunc = {},

      type = WT.weapon.instanceTypes.NEAR,

      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.present = {}
      end,

      activate = function(self)
        self.active = true
      end,

      addUpdateFunc = function(self, func)
        self.updateFunc[#self.updateFunc + 1] = func
      end,

      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,

      triggerUpdate = function(self,wep)
        for i = 1, #self.updateFunc do
          self.updateFunc[i]({instance=self,weapon = wep})
        end
      end,

      checkEvent = function(self, event)
        if event.id == world.event.S_EVENT_SHOT then
          if self.active == true then
            if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
              return true
            end
          end
        end
        return false
      end,

      weaponGone = function(self, wep)
        for r = 1, #self.present do
          if self.present[r] == wep.id then
            table.remove(self.present, r)
            trigger.action.setUserFlag(self.flag, #self.present)
            self:triggerChange(wep)
            break
          end
        end
      end,

      weaponUpdate = function(self, wep)
        local ref = {}
        self:triggerUpdate(wep)
        if self.tgtType == "group" then
          local g = p(Group.getByName, self.target)
          if g then
            local u = p(Group.getUnit, g, 1)
            if u then
              ref = u:getPoint()
            else
              return
            end
          else
            return
          end
        else
          local u = p(Unit.getByName, self.target)
          if u then
            ref = u:getPoint()
          else
            return
          end
        end
        local pos = wep.last_point
        local dist = WT.utils.VecMag{ x = pos.x - ref.x, y = pos.y - ref.y, z = pos.z - ref.z }
        if dist <= self.range then
          if not isInList(self.present, wep.id) then
            self.present[#self.present + 1] = wep.id
            trigger.action.setUserFlag(self.flag, #self.present)
            self:triggerChange(wep)
          end
        else
          for r = 1, #self.present do
            if self.present[r] == wep.id then
              table.remove(self.present, r)
              trigger.action.setUserFlag(self.flag, #self.present)
              self:triggerChange(wep)
              break
            end
          end
        end
      end
    }
    return inst
  end

  function WT.weapon.newImpactNearInstance(filter, target, range, flag)
    local tgt_type = ""
    local tgt = p(Unit.getByName, target)
    if tgt == nil then
      tgt = p(Group.getByName, target)
      if tgt == nil then
        return nil
      end
      tgt_type = "group"
    else
      tgt_type = "unit"
    end

    local inst = {
      filter = filter,
      target = target,
      tgtType = tgt_type,
      range = range,
      flag = flag,
      active = true,
      impacts = 0,
      changeFunc = {},
      type = WT.weapon.instanceTypes.IMPACT_NEAR,


      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.impacts = 0
      end,

      activate = function(self)
        self.active = true
      end,

      weaponUpdate = function(self, wep)
        return false
      end,


      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,


      checkEvent = function(self, event)
        if event.id == world.event.S_EVENT_SHOT then
          if self.active == true then
            if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
              return true
            end
          end
        end
        return false
      end,

      weaponGone = function(self, wep)
        local ref = {}
        local pos = wep.last_point
        local ground = land.getHeight({ x = pos.x, y = pos.z })
        if pos.y - ground > 10 then
          return
        end
        if self.tgtType == "group" then
          local g = p(Group.getByName, self.target)
          if g then
            local u = p(Group.getUnits, g)
            if u then
              for j = 1, #u do
                ref[#ref + 1] = u[j]:getPoint()
              end
            else
              return
            end
          else
            return
          end
        else
          local u = p(Unit.getByName, self.target)
          if u then
            ref[#ref + 1] = u:getPoint()
          else
            return
          end
        end

        for p = 1, #ref do
          local dist = WT.utils.VecMag{ x = pos.x - ref[p].x, y = pos.y - ref[p].y, z = pos.z - ref[p].z }
          if dist <= self.range then
            self.impacts = self.impacts + 1
            trigger.action.setUserFlag(self.flag, self.impacts)
            self:triggerChange(wep)
            return
          end
        end
      end
    }
    return inst
  end

  function WT.weapon.newZoneInstance(filter, zone, flag)
    local inst = {
      filter = filter,
      zone = zone,
      flag = flag,
      active = true,
      present = {},
      updateFunc = {},
      changeFunc = {},
      type = WT.weapon.instanceTypes.IN_ZONE,


      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.present = {}
      end,

      activate = function(self)
        self.active = true
      end,

      addUpdateFunc = function(self, func)
        self.updateFunc[#self.updateFunc + 1] = func
      end,

      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,

      triggerUpdate = function(self,wep)
        for i = 1, #self.updateFunc do
          self.updateFunc[i]({instance=self,weapon = wep})
        end
      end,

      weaponGone = function(self, wep)
        for r = 1, #self.present do
          if self.present[r] == wep.id then
            table.remove(self.present, r)
            trigger.action.setUserFlag(self.flag, #self.present)
            self:triggerChange(wep)
            break
          end
        end
      end,

      checkEvent = function(self, event)
        if event.id == world.event.S_EVENT_SHOT then
          if self.active == true then
            if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
              return true
            end
          end
        end
        return false
      end,

      weaponUpdate = function(self, wep)
        local pos = wep.last_point
        self:triggerUpdate(wep)
        if WT.inZone({ x = pos.x, y = pos.z }, WT.zones[self.zone]) == true then
          if not isInList(self.present, wep.id) then
            self.present[#self.present + 1] = wep.id
            trigger.action.setUserFlag(self.flag, #self.present)
            self:triggerChange(wep)
          end
        else
          for r = 1, #self.present do
            if self.present[r] == wep.id then
              table.remove(self.present, r)
              trigger.action.setUserFlag(self.flag, #self.present)
              self:triggerChange(wep)
              break
            end
          end
        end
      end
    }
    return inst
  end

  function WT.weapon.newImpactZoneInstance(filter, zone, flag)
    local inst = {
      filter = filter,
      zone = zone,
      flag = flag,
      active = true,
      impacts = 0,
      changeFunc = {},
      type = WT.weapon.instanceTypes.IN_ZONE,


      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.impacts = 0
      end,

      activate = function(self)
        self.active = true
      end,

      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,

      weaponUpdate = function(self, wep)
        return false
      end,

      checkEvent = function(self, event)
        if event.id == world.event.S_EVENT_SHOT then
          if self.active == true then
            if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
              return true
            end
          end
        end
        return false
      end,

      weaponGone = function(self, wep)
        local pos = wep.last_point
        local ground = land.getHeight({ x = pos.x, y = pos.z })
        if pos.y - ground > 10 then
          return
        end
        if WT.inZone({ x = pos.x, y = pos.z }, WT.zones[self.zone]) == true then
          self.impacts = self.impacts + 1
          trigger.action.setUserFlag(self.flag, self.impacts)
          self:triggerChange(wep)
        end
      end
    }
    return inst
  end

  function WT.weapon.newShotInstance(filter, flag)
    local inst = {
      filter = filter,
      flag = flag,
      active = true,
      shots = 0,
      updateFunc = {},
      changeFunc = {},
      type = WT.weapon.instanceTypes.SHOT,


      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.shots = 0
      end,

      activate = function(self)
        self.active = true

        return
      end,

      addUpdateFunc = function(self, func)
        self.updateFunc[#self.updateFunc + 1] = func
      end,

      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,

      triggerUpdate = function(self,wep)
        for i = 1, #self.updateFunc do
          self.updateFunc[i]({instance=self,weapon = wep})
        end
      end,

      checkEvent = function(self, event)
        if event.id == world.event.S_EVENT_SHOT then
          self:triggerUpdate(event)
          if self.active == true then
            if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
              self.shots=self.shots+1
              trigger.action.setUserFlag(self.flag, self.shots)
              self:triggerChange(event)
            end
          end
        end
        return false
      end,

      weaponUpdate = function(self, wep)
        return false
      end,

      weaponGone = function(self, wep)
        return false
      end
    }
    return inst
  end

  function WT.weapon.newHitInstance(filter, target, flag)
    local inst = {
      filter = filter,
      target = target,
      flag = flag,
      active = true,
      hits = 0,
      updateFunc = {},
      changeFunc = {},
      type = WT.weapon.instanceTypes.HIT,


      deactivate = function(self)
        self.active = false
        trigger.action.setUserFlag(self.flag, 0)
        self.impacts = 0
      end,

      activate = function(self)
        self.active = true
      end,

      addUpdateFunc = function(self, func)
        self.updateFunc[#self.updateFunc + 1] = func
      end,

      addChangeFunc = function(self, func)
        self.changeFunc[#self.changeFunc + 1] = func
      end,

      triggerChange = function(self,wep)
        for i = 1, #self.changeFunc do
          self.changeFunc[i]({instance=self,weapon = wep})
        end
      end,

      triggerUpdate = function(self,wep)
        for i = 1, #self.updateFunc do
          self.updateFunc[i]({instance=self,weapon = wep})
        end
      end,

      checkEvent = function(self, event)
        if event.id == world.event.HIT then
          local weapon = event.weapon
          if event.target then
            local tgtName = p(Unit.getName, event.target)
            if tgtName ~= self.target then
              return
            end
            self:triggerUpdate(event)
          else
            return
          end
          local filter = self.filter:checkFilter(weapon, WT.weapon.debug)
          if filter == true then
            if WT.weapon.debug == true then
              trigger.action.outText("valid hit", 5, false)
            end
            self.hits = self.hits + 1
            trigger.action.setUserFlag(self.flag, self.hits)
            self:triggerChange(event)
          elseif WT.weapon.debug == true then
            trigger.action.outText("invalid hit", 5, false)
          end
        end
      end
    }
    return inst
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
        if WT.utils.VecMag({ x = weapon.last_point.x - tp.x, y = weapon.last_point.y - tp.y, z = weapon.last_point.z - tp.z }) < 50 then
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
            local dist = WT.utils.VecMag({ x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z })
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
            local dist = WT.utils.VecMag({ x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z })
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
              Group.getByName(r):getController():setCommand(WT.tasks.setInvisible)
            else
              Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
            end
          else
            Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
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
              Group.getByName(r):getController():setCommand(WT.tasks.setInvisible)
            else
              Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
            end
          else
            Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
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
    local s = land.getHeight({ x = p.x, y = p.z })
    local alt = p.y - s
    if (invisAlt.higher == false and alt > invisAlt.triggerAlt) or (invisAlt.higher == true and alt < invisAlt.triggerAlt) then
      player:getGroup():getController():setCommand(WT.tasks.setVisible)
    else
      player:getGroup():getController():setCommand(WT.tasks.setInvisible)
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
  WT.popFlare.side = { 0, 0 }
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
        missionCommands.addCommandForGroup(grp, "green flare", { [1] = "signal flares" }, WT.popFlare.popFlare,
          { grp = name, colour = 0 })
        missionCommands.addCommandForGroup(grp, "red flare", { [1] = "signal flares" }, WT.popFlare.popFlare,
          { grp = name, colour = 1 })
        missionCommands.addCommandForGroup(grp, "white flare", { [1] = "signal flares" }, WT.popFlare.popFlare,
          { grp = name, colour = 2 })
        missionCommands.addCommandForGroup(grp, "yellow flare", { [1] = "signal flares" }, WT.popFlare.popFlare,
          { grp = name, colour = 3 })
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
      missionCommands.removeItemForGroup(details.id, { [1] = "killswitch" })
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
        missionCommands.removeItemForGroup(details.cID, { [1] = "killswitch" })
        WT.killswitch.active[details.cID] = 0
      end
      if group then
        local gr = Group.getByName(group)
        local id = gr:getID()
        if WT.killswitch.active[id] ~= 1 then
          missionCommands.addSubMenuForGroup(gr:getID(), "killswitch")
          WT.killswitch.active[id] = 1
        end
        missionCommands.addCommandForGroup(gr:getID(), details.name, { [1] = "killswitch" }, WT.killswitch.killswitch,
          { flag = details.flag, single = details.single, name = details.name, id = details.cID })
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

    return { x = x / size, y = y / size, z = z / size }
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
        src.y = land.getHeight({ x = src.x, y = src.z })
        src.y = src.y + 5
        local vis = land.isVisible(src, target)
        if vis ~= true then
          return false
        end

        if basic == false then
          local vol = deepCopy(segment)

          vol.from = src
          vol.to = target

          world.searchObjects({ 1, 2, 3, 4, 5, 6 }, vol, ifFound)

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
            local temp_dist = WT.utils.VecMag({ x = point.x - ref.x, y = point.y - ref.y, z = point.z - ref.z })
            point.x = point.x + (7 + 2 * (temp_dist / 3000)) * vel.x
            point.y = point.y + (7 + 2 * (temp_dist / 3000)) * vel.y
            point.z = point.z + (7 + 2 * (temp_dist / 3000)) * vel.z
            local height = land.getHeight({ x = point.x, y = point.z })
            if point.y < height then
              point.y = height + 5
            end
            dist = WT.utils.VecMag({ x = point.x - ref.x, y = point.y - ref.y, z = point.z - ref.z })
            if dist < nearest_d and self:checkLOS(point, self.basic) == true then
              nearest_d = dist
              nearest = point
            end
            --end
          end
          if nearest ~= nil and nearest_d < 8000 then
            task = FireAtPoint
            task.params.point = { x = nearest.x, y = nearest.z }
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

    return { x = targX, z = targY, y = land.getHeight({ x = targX, y = targY }) }
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
      if WT.utils.isInCircle(target, safezone.radius, safezone.point) then
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
  WT.MLRS.types = { Smerch = 10, ["Uragan_BM-27"] = 10, ["Grad-URAL"] = 6, MLRS = 7, Smerch_HE = 10 }

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
      timer.scheduleFunction(WT.strobe.strobeOff, { d = details, s = spot },
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
          missionCommands.addCommandForGroup(grp, "green flare", { [1] = "Signal Flares" }, WT.popFlare.popFlare,
            { grp = name, colour = 0 })
          missionCommands.addCommandForGroup(grp, "red flare", { [1] = "Signal Flares" }, WT.popFlare.popFlare,
            { grp = name, colour = 1 })
          missionCommands.addCommandForGroup(grp, "white flare", { [1] = "Signal Flares" }, WT.popFlare.popFlare,
            { grp = name, colour = 2 })
          missionCommands.addCommandForGroup(grp, "yellow flare", { [1] = "Signal Flares" }, WT.popFlare.popFlare,
            { grp = name, colour = 3 })
        end
      end
    end
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
    WT.coverMe.groups[#WT.coverMe.groups + 1] = { group = group, co = coalition, distance = distance, covered = false }
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
    local details = { pname = player, name = name, flag = flag, single = singleUse, cName = nil, cID = nil }
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
        local v1 = WT.utils.VecMag(u[1]:getVelocity())
        local tasking = nil
        if cat < 2 then
          tasking = deepCopy(WT.tasks.airMission)
        else
          tasking = deepCopy(WT.tasks.groundMission)
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
  --meaning to use this properly for now your targets need to be invisible or use neutral units for AA
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
    timer.scheduleFunction(WT.shelling.shell, { z = zone, s = safe, r = rate, f = flag }, timer.getTime() + 1)
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
          location = { x = 0, y = desc.box.max.y - desc.box.min.y, z = 0 }
        end
        timer.scheduleFunction(WT.strobe.strobeOn, { u = units[u], g = grp, l = location, i = math.max(0.15, interval) },
          timer.getTime() + 1 + (math.random(0, 100) / 100))
      end
    end
  end

  ------
  --- func desc
  ---@param target string
  ---@param filter weaponFilter
  ---@param range integer
  ---@param flag string
  function WT.weapon.near(target, filter, range, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newNearInstance(filter, target, range, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end

  function WT.weapon.hit(target, filter, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newHitInstance(filter, target, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end

  ---comment
  ---@param target string
  ---@param filter weaponFilter
  ---@param range integer
  ---@param flag string
  function WT.weapon.impactNear(target, filter, range, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newImpactNearInstance(filter, target, range, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end

  ---comment
  ---@param filter weaponFilter
  ---@param zone string
  ---@param flag string
  function WT.weapon.inZone(filter, zone, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newZoneInstance(filter, zone, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end

  ---comment
  ---@param filter weaponFilter
  ---@param zone string
  ---@param flag string
  function WT.weapon.impactInZone(filter, zone, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newImpactZoneInstance(filter, zone, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end


  ---comment
  ---@param filter weaponFilter
  ---@param flag string
  function WT.weapon.shot(filter, flag)
    if #WT.weapon.instances < 1 then
      newEventHandler(WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newShotInstance(filter, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
  end

  ---comment
  function WT.weapon.Debug()
    WT.weapon.debug = true
  end

  ------------------------------------------
  --System init calls here
  ------------------------------------------

  WT.utils.getZones()
  WT.tasking.getGroups()
end
