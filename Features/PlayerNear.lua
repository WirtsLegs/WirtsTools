-----------------------------------------------------------------------
--PlayerNear.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------
WT.playerNear = {}
WT.playerNear.groups = {}
local playerNear = {}

function playerNear.checkGroups(g1, g2)
    local group1 = WT.utils.p(Group.getByName, g1)
    local group2 = WT.utils.p(Group.getByName, g2)
    if not (group1 and group2) then
        return -1
    end
    local g1_units = WT.utils.p(Group.getUnits, group1)
    local g2_units = WT.utils.p(Group.getUnits, group2)
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

function playerNear.getPlayerGroups(co)
    local players = coalition.getPlayers(co)
    local groups = {}
    for p = 1, #players do
        local grp = players[p]:getGroup()
        groups[grp:getName()] = 1
    end
    return groups
end

function playerNear.check(co, time)
    local validated = false
    for g = 1, #WT.playerNear.groups do
        validated = false
        if WT.playerNear.groups[g].player_groups == 0 then
            local grps = playerNear.getPlayerGroups(WT.playerNear.groups[g].co)
            for r, s in pairs(grps) do
                local dist = playerNear.checkGroups(WT.playerNear.groups[g].name, r)
                if dist ~= -1 then
                    if dist <= WT.playerNear.groups[g].distance then
                        validated = true
                    end
                end
            end
        else
            if not WT.playerNear.groups[g].player_groups then
                return time + 1
            end
            for r = 1, #WT.playerNear.groups[g].player_groups do
                local dist = playerNear.checkGroups(WT.playerNear.groups[g].name,
                    WT.playerNear.groups[g].player_groups[r])
                if dist ~= -1 then
                    if dist <= WT.playerNear.groups[g].distance then
                        validated = true
                    end
                end
            end
        end
        if validated == true then
            trigger.action.setUserFlag(WT.playerNear.groups[g].flag,
                trigger.misc.getUserFlag(WT.playerNear.groups[g].flag) +
                1)
        else
            trigger.action.setUserFlag(WT.playerNear.groups[g].flag, 0)
        end
    end
    return time + 1
end

---------------------------
--playerNear: increment a flag when a player is within a defined distance of a group
--target_group: name of group you need to be near (in quotes)
--player_groups: a list in the form {"name1","name2",...}, set to 2 for all blue players or 1 for all red
--flag: flag name to increment when conditions met
--distance: distance in meters to operate within
--WT.playerNear.setup("target-1",2,"flag1",1000) this will increment flag1 whenever any players are near the group target-1
--WT.playerNear.setup("target-1",{"player"},"flag2",500) this will increment the flag only when the specific given group is within range
-----------------------------
function WT.playerNear.setup(target_group, player_groups, flag, distance)
    trigger.action.setUserFlag(flag, 0)
    if #WT.playerNear.groups < 1 then
        timer.scheduleFunction(playerNear.check, 2, timer.getTime() + 1)
    end
    if player_groups == 1 then
        WT.playerNear.groups[#WT.playerNear.groups + 1] = {
            name = target_group,
            player_groups = 0,
            co = 1,
            flag = flag,
            distance =
                distance
        }
    elseif player_groups == 2 then
        WT.playerNear.groups[#WT.playerNear.groups + 1] = {
            name = target_group,
            player_groups = 0,
            co = 2,
            flag = flag,
            distance =
                distance
        }
    else
        WT.playerNear.groups[#WT.playerNear.groups + 1] = {
            name = target_group,
            player_groups = player_groups,
            flag = flag,
            distance =
                distance
        }
    end
end
