---------------------------------------------------------------------
--Ejection Cleanup
---------------------------------------------------------------------
WT.eject = {}

function WT.eject.cleanupEjection(pilot, time)
    if pilot then
        WT.utils.p(pilot.destroy, pilot)
    end
    return nil
end

function WT.eject.handleEjects(event)
    if event.id then
        if event.id == world.event.S_EVENT_EJECTION or event.id == world.event.S_EVENT_DISCARD_CHAIR_AFTER_EJECTION then
            if (math.random(1, 2)) == 2 then
                timer.scheduleFunction(WT.eject.cleanupEjection, event.target, timer.getTime() + 60)
            else
                event.target:destroy()
            end
        end
    end
end

----------------------------------------------
--Ejection Cleanup: simple feature that deletes 50% of ejected pilots immediately and the rest after a minute
----------------------------------------------
function WT.eject.init()
    WT.utils.registerEventListener({ world.event.S_EVENT_EJECTION, world.event.S_EVENT_DISCARD_CHAIR_AFTER_EJECTION },
        WT.eject.handleEjects)
end
