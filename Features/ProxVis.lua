---------------------------------------------------------------------
--proxVis.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------

WT.proxVis = {}
WT.proxVis.groups = {}
WT.proxVis.status = {}



function WT.proxVis.getPlayerGroups(co)
    local players = coalition.getPlayers(co)
    local groups = {}
    for p = 1, #players do
        local grp = players[p]:getGroup()
        groups[grp:getName()] = 1
    end
    return groups
end

function WT.proxVis.getAIUnits(co)
    local grps = coalition.getGroups(co)
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

function WT.proxVis.checkGroups(group, co)
    local group1 = WT.utils.p(Group.getByName, group)
    if not (group1) then
        return -1
    end
    local g1_units = WT.utils.p(Group.getUnits, group1)
    local g2_units = WT.proxVis.getAIUnits(co) --p(Group.getUnits,group2)
    if not (g1_units and g2_units) then
        return -1
    end
    local shortest = -1

    for i = 1, #g1_units do
        local p1 = WT.utils.p(Unit.getPoint, g1_units[i])
        if p1 then
            for j = 1, #g2_units do
                local p2 = WT.utils.p(Unit.getPoint, g2_units[j])
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

function WT.proxVis.check(co, time)
    for g = 1, #WT.proxVis.groups do
        if WT.proxVis.groups[g].group == 1 or WT.proxVis.groups[g].group == 2 then
            local grps = WT.proxVis.getPlayerGroups(WT.proxVis.groups[g].group)
            for r, s in pairs(grps) do
                local dist = WT.proxVis.checkGroups(r, WT.proxVis.groups[g].co)
                if dist ~= -1 then
                    if dist > WT.proxVis.groups[g].distance then
                        Group.getByName(r):getController():setCommand(WT.tasks.setInvisible)
                    else
                        Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
                    end
                else
                    Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
                end
            end
        else
            if not WT.proxVis.groups[g].group then
                return time + 1
            end
            for r = 1, #WT.proxVis.groups[g].group do
                local dist = WT.proxVis.checkGroups(WT.proxVis.groups[g].group[r], WT.proxVis.groups[g].co)
                if dist ~= -1 then
                    if dist > WT.proxVis.groups[g].distance then
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

-----------------------------
--proxVis: renders players invisible when they are more than a set distance from any hostiles
--group: group to function on (1 or 2 for all player redfor or player blufor respectively)
--coalition: coalition of AI units that should be used for vis
--distance: distance in meters they must be within to be visible
-----------------------------
function WT.proxVis.setup(group, coalition, distance)
    if #WT.proxVis.groups < 1 then
        timer.scheduleFunction(WT.proxVis.check, 2, timer.getTime() + 1)
    end
    WT.proxVis.groups[#WT.proxVis.groups + 1] = { group = group, co = coalition, distance = distance, covered = false }
end
