WT.ScenicFire = {}
WT.ScenicFire.__index = WT.ScenicFire

-- Utility to get a random value in [-variance, +variance]
function WT.ScenicFire.randomVariance(base, variance)
    return base + (math.random() * 2 - 1) * variance
end

-- Utility to get a random point above the target within a dome of errorSize
function WT.ScenicFire.randomErrorPoint(targetPoint, errorSize)
    -- Random direction
    local theta = math.random() * 2 * math.pi
    local phi = math.acos(math.random()) -- [0, pi], but we want only above the target (phi in [0, pi/2])
    phi = phi / 2
    local r = math.random() * errorSize
    local dx = r * math.sin(phi) * math.cos(theta)
    local dy = r * math.sin(phi) * math.sin(theta)
    local dz = r * math.cos(phi)
    return {
        x = targetPoint.x + dx,
        y = targetPoint.y + dz, -- y is up in DCS
        z = targetPoint.z + dy
    }
end

function WT.ScenicFire.new(group, roundCount, roundVariance, interval, intervalVariance, errorSize, maxRange, fallbackPrefix)
    local self = setmetatable({}, WT.ScenicFire)
    self.groupName = group:getName()
    self.roundCount = roundCount or 5
    self.roundVariance = roundVariance or 2
    self.interval = interval or 10
    self.intervalVariance = intervalVariance or 3
    self.errorSize = errorSize or 50
    self.maxRange = maxRange -- optional, can be nil
    self.fallbackPrefix = fallbackPrefix -- optional, can be nil
    self.active = false
    return self
end

function WT.ScenicFire:start()
    self.active = true
    self:scheduleNext()
end

function WT.ScenicFire:stop()
    self.active = false
end

function WT.ScenicFire:scheduleNext()
    if not self.active then return end
    local delay = WT.ScenicFire.randomVariance(self.interval, self.intervalVariance)
    timer.scheduleFunction(function()
        local continue = self:fireAtTarget()
        if continue then
            self:scheduleNext()
        else
            self:stop()
        end
    end, {}, timer.getTime() + delay)
end

function WT.ScenicFire:fireAtTarget()
    local group = WT.utils.p(Group.getByName, self.groupName)
    if not group or not group:isExist() then
        return false -- stop scheduling
    end
    local controller = group:getController()
    if not controller then return true end
    local detected = controller:getDetectedTargets()
    local target = nil

    if detected and #detected > 0 then
        -- Filter targets by maxRange if set
        local filteredTargets = {}
        local groupPos = group:getUnits()[1]:getPoint()
        for _, dt in ipairs(detected) do
            if dt.object and (not self.maxRange or
                WT.utils.VecMag({
                    x = dt.object:getPoint().x - groupPos.x,
                    y = dt.object:getPoint().y - groupPos.y,
                    z = dt.object:getPoint().z - groupPos.z
                }) <= self.maxRange)
            then
                table.insert(filteredTargets, dt)
            end
        end
        if #filteredTargets > 0 then
            -- Prefer visible targets
            for _, dt in ipairs(filteredTargets) do
                if dt.visible then
                    target = dt
                    break
                end
            end
            if not target then
                target = filteredTargets[1]
            end
        end
    end

    -- Fallback: no detected targets, use fallbackPrefix if provided
    if not target and self.fallbackPrefix then
        local enemy_co = 1
        if group:getCoalition() == 1 then
            enemy_co = 2
        end
        local allGroups = coalition.getGroups(enemy_co, 2) -- ground groups only
        local groupPos = group:getUnits()[1]:getPoint()
        local shooterPos = { x = groupPos.x, y = groupPos.y + 1.5, z = groupPos.z }
        local candidates = {}
        for _, g in ipairs(allGroups) do
            local gName = g:getName()
            if string.starts(gName, self.fallbackPrefix) and g:isExist() and g:getSize() > 0 then
                local gPosRaw = g:getUnits()[1]:getPoint()
                local gPos = { x = gPosRaw.x, y = gPosRaw.y + 1.5, z = gPosRaw.z }
                local dist = WT.utils.VecMag({
                    x = gPosRaw.x - groupPos.x,
                    y = gPosRaw.y - groupPos.y,
                    z = gPosRaw.z - groupPos.z
                })
                if (not self.maxRange or dist <= self.maxRange) and land.isVisible(shooterPos, gPos) then
                    table.insert(candidates, g)
                end
            end
        end
        if #candidates > 0 then
            local idx = math.random(1, #candidates)
            local fallbackGroup = candidates[idx]
            local tgtPointRaw = fallbackGroup:getUnits()[1]:getPoint()
            local tgtPoint = { x = tgtPointRaw.x, y = tgtPointRaw.y + 1.5, z = tgtPointRaw.z }
            target = { object = { getPoint = function() return tgtPoint end } }
        end
    end

    if not target or not target.object then return true end

    local tgtPoint = target.object:getPoint()
    local firePoint = WT.ScenicFire.randomErrorPoint(tgtPoint, self.errorSize)
    local rounds = math.max(1, math.floor(WT.ScenicFire.randomVariance(self.roundCount, self.roundVariance)))

    local fireTask = {
        id = 'FireAtPoint',
        params = {
            point = {x=firePoint.x, y=firePoint.z},
            altitude = firePoint.y,
            alt_type=0,
            expendQtyEnabled = true,
            expendQty  = rounds
        }
    }
    controller:setTask(fireTask)
    return true
end

-- Usage:
-- local sf = WT.ScenicFire.new(Group.getByName("MyGroup"), 5, 2, 10, 3, 50, 1000)

