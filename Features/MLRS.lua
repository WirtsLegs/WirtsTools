---------------------------------------------------------------------
--MLRS.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------

WT.MLRS = {}
WT.MLRS.types = { Smerch = 10, ["Uragan_BM-27"] = 10, ["Grad-URAL"] = 6, MLRS = 7, Smerch_HE = 10 }

function WT.MLRS.remove(weapon, time)
    WT.utils.p(weapon.destroy, weapon)
    return nil
end

function WT.MLRS.handleShots(event)
    if event.id == world.event.S_EVENT_SHOT then --track fired missiles
        local type = event.initiator:getTypeName()
        local group = WT.utils.p(event.initiator.getGroup, event.initiator)
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
    WT.utils.registerEventListener(world.event.S_EVENT_SHOT, WT.MLRS.handleShots)
end
