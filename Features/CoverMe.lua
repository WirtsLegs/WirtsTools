-----------------------------------------------------------------------
--CoverMe
----------------------------------------------------------------------
WT.coverMe = {}
WT.coverMe.groups = {}
WT.coverMe.status = {}
local coverMe = {}


function coverMe.getPlayerGroups(co)
    local players = coalition.getPlayers(co)
    local groups = {}
    for p = 1, #players do
        local grp = players[p]:getGroup()
        groups[grp:getName()] = 1
    end
    return groups
end

function coverMe.getAIUnits(co)
    local grps = coalition.getGroups(co, 0)
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

function coverMe.checkGroups(group, co)
    local group1 = WT.utils.p(Group.getByName, group)
    if not (group1) then
        return -1
    end
    local g1_units = WT.utils.p(Group.getUnits, group1)
    local g2_units = coverMe.getAIUnits(co) --p(Group.getUnits,group2)
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

function coverMe.check(co, time)
    for g = 1, #WT.coverMe.groups do
        if WT.coverMe.groups[g].group == 1 or WT.coverMe.groups[g].group == 2 then
            local grps = coverMe.getPlayerGroups(WT.coverMe.groups[g].group)
            for r, s in pairs(grps) do
                local dist = coverMe.checkGroups(r, WT.coverMe.groups[g].co)
                if dist ~= -1 then
                    if dist <= WT.coverMe.groups[g].distance then
                        Group.getByName(r):getController():setCommand(WT.tasks.setInvisible)
                    else
                        Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
                    end
                else
                    Group.getByName(r):getController():setCommand(WT.tasks.setVisible)
                end
            end
        else
            if not WT.coverMe.groups[g].group then
                return time + 1
            end
            for r = 1, #WT.coverMe.groups[g].group do
                local dist = coverMe.checkGroups(WT.coverMe.groups[g].group[r], WT.coverMe.groups[g].co)
                if dist ~= -1 then
                    if dist <= WT.coverMe.groups[g].distance then
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
--coverMe: renders players invisible when there is a allied AI aircraft within a defined range of the player
--group: group that is covered by AI (1 or 2 for all player redfor or player blufor respectively)
--coalition: coalition of AI players you want to be able to provide cover
--distance: distance in meters they must be within to be covered
--WT.playerNear.setup("target-1",2,"flag1",1000) this will increment flag1 whenever any players are near the group target-1
--WT.playerNear.setup("target-1",{"player"},"flag2",500) this will increment the flag only when the specific given group is within range
-----------------------------
function WT.coverMe.setup(group, coalition, distance)
    if #WT.coverMe.groups < 1 then
        timer.scheduleFunction(coverMe.check, 2, timer.getTime() + 1)
    end
    WT.coverMe.groups[#WT.coverMe.groups + 1] = { group = group, co = coalition, distance = distance, covered = false }
end
