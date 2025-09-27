-- File: weapon.lua

WT.weapon = {}
WT.weapon.debug = false
WT.weapon.instanceTypes = {
    IN_ZONE = 1,
    NEAR = 2,
    IMPACT_IN_ZONE = 3,
    IMPACT_NEAR = 4,
    HIT = 5,
    SHOT = 6
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
                local debug = false
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
                        local cat         = desc.category -- e.g. Weapon.Category.MISSILE
                        local guidance    = desc.guidance -- e.g. Weapon.GuidanceType.IR
                        local missileCat  = desc.missileCategory -- e.g. Weapon.MissileCategory.AAM
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
            local cat         = desc.category    -- e.g. Weapon.Category.MISSILE
            local guidance    = desc.guidance    -- e.g. Weapon.GuidanceType.IR
            local missileCat  = desc.missileCategory -- e.g. Weapon.MissileCategory.AAM
            local warheadType = desc.warheadType -- e.g. Weapon.WarheadType.HE
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
                if not WT.utils.isInList(self.Name, name) then
                    if debug == true then
                        trigger.action.outText("Name filter", 5, false)
                    end
                    return false
                end
            end
            -- 1b) Check Name (negative)
            if self.Name_neg and #self.Name_neg > 0 then
                -- If the weapon's Name is in our negative list, fail
                if WT.utils.isInList(self.Name_neg, name) then
                    if debug == true then
                        trigger.action.outText("Name neg filter", 5, false)
                    end
                    return false
                end
            end
            if self.Coalition and #self.Coalition > 0 then
                -- If we have a positive Category filter, the weapon's Name must be in that list
                if not WT.utils.isInList(self.Coalition, side) then
                    if debug == true then
                        trigger.action.outText("Coalition filter", 5, false)
                    end
                    return false
                end
            end
            -- 1b) Check Name (negative)
            if self.Coalition_neg and #self.Coalition_neg > 0 then
                -- If the weapon's Name is in our negative list, fail
                if WT.utils.isInList(self.Coalition_neg, side) then
                    if debug == true then
                        trigger.action.outText("Coalition neg filter", 5, false)
                    end
                    return false
                end
            end

            -- 1) Check Category (positive)
            if self.Category and #self.Category > 0 then
                -- If we have a positive Category filter, the weapon's category must be in that list
                if not WT.utils.isInList(self.Category, cat) then
                    if debug == true then
                        trigger.action.outText("Category filter", 5, false)
                    end
                    return false
                end
            end
            -- 1b) Check Category (negative)
            if self.Category_neg and #self.Category_neg > 0 then
                -- If the weapon's category is in our negative list, fail
                if WT.utils.isInList(self.Category_neg, cat) then
                    if debug == true then
                        trigger.action.outText("Category neg filter", 5, false)
                    end
                    return false
                end
            end

            -- 2) Check GuidanceType (positive)
            if self.GuidanceType and #self.GuidanceType > 0 then
                if not WT.utils.isInList(self.GuidanceType, guidance) then
                    if debug == true then
                        trigger.action.outText("Guidance filter", 5, false)
                    end
                    return false
                end
            end
            -- 2b) Negative
            if self.GuidanceType_neg and #self.GuidanceType_neg > 0 then
                if WT.utils.isInList(self.GuidanceType_neg, guidance) then
                    if debug == true then
                        trigger.action.outText("Guidance neg filter", 5, false)
                    end
                    return false
                end
            end

            -- 3) Check MissileCategory (positive)
            if self.MissileCategory and #self.MissileCategory > 0 then
                if not WT.utils.isInList(self.MissileCategory, missileCat) then
                    if debug == true then
                        trigger.action.outText("Missile Category filter", 5, false)
                    end
                    return false
                end
            end
            -- 3b) Negative
            if self.MissileCategory_neg and #self.MissileCategory_neg > 0 then
                if WT.utils.isInList(self.MissileCategory_neg, missileCat) then
                    if debug == true then
                        trigger.action.outText("Missile Category neg filter", 5, false)
                    end
                    return false
                end
            end

            -- 4) Check WarheadType (positive)
            if self.WarheadType and #self.WarheadType > 0 then
                if not WT.utils.isInList(self.WarheadType, warheadType) then
                    if debug == true then
                        trigger.action.outText("Warhead filter", 5, false)
                    end
                    return false
                end
            end
            -- 4b) Negative
            if self.WarheadType_neg and #self.WarheadType_neg > 0 then
                if WT.utils.isInList(self.WarheadType_neg, warheadType) then
                    if debug == true then
                        trigger.action.outText("Warhead neg filter", 5, false)
                    end
                    return false
                end
            end

            if self.Func and #self.Func > 0 then
                for _, func in ipairs(self.Function) do
                    if func(weapon, debug) == false then
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
                    if func(weapon, debug) == true then
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
    if WT.utils.p(weapon.weapon.isExist, weapon.weapon) then
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
            local weapon = {
                weapon = event.weapon,
                name = weapon_name,
                category = weapon_category,
                target = event.weapon
                    :getTarget(),
                id = id,
                instances = valid_instances,
                last_point = p1
            }
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
    local tgt = WT.utils.p(Unit.getByName, target)
    if tgt == nil then
        tgt = WT.utils.p(Group.getByName, target)
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
            end
        end,

        triggerUpdate = function(self, wep)
            for i = 1, #self.updateFunc do
                self.updateFunc[i]({ instance = self, weapon = wep })
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
                local g = WT.utils.p(Group.getByName, self.target)
                if g then
                    local u = WT.utils.p(Group.getUnit, g, 1)
                    if u then
                        ref = u:getPoint()
                    else
                        return
                    end
                else
                    return
                end
            else
                local u = WT.utils.p(Unit.getByName, self.target)
                if u then
                    ref = u:getPoint()
                else
                    return
                end
            end
            local pos = wep.last_point
            local dist = WT.utils.VecMag { x = pos.x - ref.x, y = pos.y - ref.y, z = pos.z - ref.z }
            if dist <= self.range then
                if not WT.utils.isInList(self.present, wep.id) then
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
    local tgt = WT.utils.p(Unit.getByName, target)
    if tgt == nil then
        tgt = WT.utils.p(Group.getByName, target)
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
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
                local g = WT.utils.p(Group.getByName, self.target)
                if g then
                    local u = WT.utils.p(Group.getUnits, g)
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
                local u = WT.utils.p(Unit.getByName, self.target)
                if u then
                    ref[#ref + 1] = u:getPoint()
                else
                    return
                end
            end

            for p = 1, #ref do
                local dist = WT.utils.VecMag { x = pos.x - ref[p].x, y = pos.y - ref[p].y, z = pos.z - ref[p].z }
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
            end
        end,

        triggerUpdate = function(self, wep)
            for i = 1, #self.updateFunc do
                self.updateFunc[i]({ instance = self, weapon = wep })
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
            if WT.utils.inZone({ x = pos.x, y = pos.z }, WT.zones[self.zone]) == true then
                if not WT.utils.isInList(self.present, wep.id) then
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
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
            if WT.utils.inZone({ x = pos.x, y = pos.z }, WT.zones[self.zone]) == true then
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
            end
        end,

        triggerUpdate = function(self, wep)
            for i = 1, #self.updateFunc do
                self.updateFunc[i]({ instance = self, weapon = wep })
            end
        end,

        checkEvent = function(self, event)
            if event.id == world.event.S_EVENT_SHOT then
                self:triggerUpdate(event)
                if self.active == true then
                    if self.filter:checkFilter(event.weapon, WT.weapon.debug) == true then
                        self.shots = self.shots + 1
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

        triggerChange = function(self, wep)
            for i = 1, #self.changeFunc do
                self.changeFunc[i]({ instance = self, weapon = wep })
            end
        end,

        triggerUpdate = function(self, wep)
            for i = 1, #self.updateFunc do
                self.updateFunc[i]({ instance = self, weapon = wep })
            end
        end,

        checkEvent = function(self, event)
            if event.id == world.event.HIT then
                local weapon = event.weapon
                if event.target then
                    local tgtName = WT.utils.p(Unit.getName, event.target)
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

------
--- func desc
---@param target string
---@param filter weaponFilter
---@param range integer
---@param flag string
function WT.weapon.near(target, filter, range, flag)
    if #WT.weapon.instances < 1 then
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newNearInstance(filter, target, range, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
end

function WT.weapon.hit(target, filter, flag)
    if #WT.weapon.instances < 1 then
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
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
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
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
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
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
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
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
        WT.utils.registerEventListener({ world.event.S_EVENT_SHOT, world.event.S_EVENT_HIT }, WT.weapon.handleEvents)
    end
    local instance = WT.weapon.newShotInstance(filter, flag)
    WT.weapon.instances[#WT.weapon.instances + 1] = instance
    return instance
end

---comment
function WT.weapon.Debug()
    WT.weapon.debug = true
end
