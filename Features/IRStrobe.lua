---------------------------------------------------------------------
--IRStrobe.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------

WT.strobe = {}
WT.strobe.current = {}

function WT.strobe.strobeOff(details, time)
    WT.utils.p(details.s.destroy, details.s)
    if (WT.strobe.current[details.d.g] == 0) then
        return nil
    end
    timer.scheduleFunction(WT.strobe.strobeOn, details.d, timer.getTime() + details.d.i)
    return nil
end

function WT.strobe.strobeOn(details, time)
    local pos = WT.utils.p(details.u.getPosition, details.u)
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
            timer.scheduleFunction(WT.strobe.strobeOn,
                { u = units[u], g = grp, l = location, i = math.max(0.15, interval) },
                timer.getTime() + 1 + (math.random(0, 100) / 100))
        end
    end
end
