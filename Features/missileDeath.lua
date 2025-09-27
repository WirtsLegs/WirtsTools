-----------------------------------------------------------------------
--MissileDeath
----------------------------------------------------------------------
WT.missileDeath = {}

local function destroyIt(target)
    if target then
        if target:isExist() then
            local point = WT.utils.p(target.getPoint, target)
            trigger.action.explosion(point, 3000)
        end
    end
    return nil
end

--update weapon position and trigger impact checks
function WT.missileDeath.updateWeapon(weapon, time)
    if WT.utils.p(weapon.weapon.isExist, weapon.weapon) then
        weapon.last_point = weapon.weapon:getPoint()
        return time + 0.05
    else
        if weapon.name then
            if weapon.target == nil then
                return nil
            end
            local tp = WT.utils.p(weapon.target.getPoint, weapon.target)
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

---------------------------------------------------------------------------
--missileDeath
--blows up any aircraft that a missile hits
---------------------------------------------------------------------------
function WT.missileDeath.setup()
    WT.utils.registerEventListener(world.event.S_EVENT_SHOT, WT.missileDeath.handeShots)
end
