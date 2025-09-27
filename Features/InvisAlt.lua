---------------------------------------------------------------------
--  InvisAlt
---------------------------------------------------------------------
WT.invisAlt = {}
WT.invisAlt.triggerAlt = 0


function WT.invisAlt.checkPlayer(player, time)
    local p = WT.utils.p(player.getPoint, player)
    if p == nil then
        return nil
    end
    local s = land.getHeight({ x = p.x, y = p.z })
    local alt = p.y - s
    if (WT.invisAlt.higher == false and alt > WT.invisAlt.triggerAlt) or (WT.invisAlt.higher == true and alt < WT.invisAlt.triggerAlt) then
        player:getGroup():getController():setCommand(WT.tasks.setVisible)
    else
        player:getGroup():getController():setCommand(WT.tasks.setInvisible)
    end
    return time + 0.5
end

function WT.invisAlt.eventHandle(event)
    local name = ""
    if event.id == world.event.S_EVENT_BIRTH then
        name = event.initiator:getPlayerName()
        if name ~= nil then
            timer.scheduleFunction(WT.invisAlt.checkPlayer, event.initiator, timer.getTime() + 1)
        end
    end
end

function WT.invisAlt.initPlayers(players)
    if players == 1 or players == 2 then
        local players = coalition.getPlayers(players)
        for i = 1, #players do
            timer.scheduleFunction(WT.invisAlt.checkPlayer, players[i], timer.getTime() + 1)
        end
    else
        local grp = Group.getByName(players)
        local un = grp:getUnits()
        for u = 1, #un do
            timer.scheduleFunction(WT.invisAlt.checkPlayer, un[u], timer.getTime() + 1)
        end
    end
end

----------------------------------------------
--InvisAlt: only works properly if each unit is their own group
--alt: altitude (AGL) below which a group should be invisible
--side: coalition enum (1 for red or 2 for blue) will apply to all players on that side
----------------------------------------------
function WT.invisAlt.setup(alt, side, higher)
    WT.invisAlt.triggerAlt = alt
    WT.invisAlt.higher = higher
    WT.invisAlt.initPlayers(side)
    WT.utils.registerEventListener(world.event.S_EVENT_BIRTH, WT.invisAlt.eventHandle)
end
