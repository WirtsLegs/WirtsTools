---------------------------------------------------------------------
--StormtrooperAA.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------
WT.stormtrooperAA = {}
WT.stormtrooperAA.stormtroopers = {}


WT.stormtrooperAA.FireAtPoint = {
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

function WT.stormtrooperAA.hasStormtrooper(group)
    local groupName
    if type(group) == "table" and group.getName then
        groupName = group:getName()
    elseif type(group) == "string" then
        groupName = group
    else
        return false
    end

    for i = 1, #WT.stormtrooperAA.stormtroopers do
        local st = WT.stormtrooperAA.stormtroopers[i]
        if st.active_units and st.active_units.getName and st.active_units:getName() == groupName then
            return true
        end
    end
    return false
end

function WT.stormtrooperAA.newStormtrooper()
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


  ---------------------------------------------
  --StormtrooperAA: makes designated AA units shoot in the vincinity of valid targets instead of at them
  --note that at this time there is a bug where units tasked to fire at point will ignore that order if there is a valid target nearby
  --meaning to use this properly for now your targets need to be invisible or use neutral units for AA
  --targets: side of the expected targets (yes you can make blue shoot blue)
  --shooters: side of the AA you wish to control (all AA must be group name starts with AA_), or a list of groups, or a list of groupnames
  --advanced: should advanced LOS detection be uysed (uses more CPU)
  --example: stormtrooperAA.setup(2,1,true) will give red shooting blue with advanced LOS use
  ---------------------------------------------
  function WT.stormtrooperAA.setup(targets, shooters, advanced)
    local active = {}
    if type(shooters) == "table" then
      if WT.utils.p(shooters, "getName") then
        -- Single group table detected
        active[1] = shooters
      elseif type(shooters[1]) == "string" then
        for i = 1, #shooters do
            local group = Group.getByName(shooters[i])
            active[#active + 1] = group
        end
      elseif type(shooters[1]) == "table" then
        active = shooters
      end
    elseif type(shooters) == "string" then
        local group = Group.getByName(shooters)
        if group then
          active[1] = group
        end
    else
        local allGround = coalition.getGroups(shooters)
        for g = 1, #allGround do
          if string.starts(allGround[g]:getName(), "AA_") then
            active[#active + 1] = allGround[g]
          end
        end
    end
    for a = 1, #active do
      WT.stormtrooperAA.stormtroopers[#WT.stormtrooperAA.stormtroopers + 1] = WT.stormtrooperAA.newStormtrooper()
      WT.stormtrooperAA.stormtrooperAA.stormtroopers[#WT.stormtrooperAA.stormtroopers]:init(targets, shooters, active[a], advanced)
    end
  end