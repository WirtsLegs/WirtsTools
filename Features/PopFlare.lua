-----------------------------------------------------
--popFlare
-----------------------------------------------------

WT.popFlare = {}
WT.popFlare.side = { 0, 0 }
WT.popFlare.done = {}
function WT.popFlare.popFlare(details, amount)
    local grp = Group.getByName(details.grp)
    local gid = grp:getID()
    local unit = WT.utils.p(grp.getUnit, grp, 1)
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

-----------------------------
--popFlare
--Will give several command options to pop a signal flare at group lead for all groups
--side: coaltion number for which side to apply to
-----------------------------
function WT.popFlare.setup(side)
    local groups = coalition.getGroups(side)
    WT.utils.registerEventListener(world.event.S_EVENT_BIRTH, WT.popFlare.eventHandle)
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
