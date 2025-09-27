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
