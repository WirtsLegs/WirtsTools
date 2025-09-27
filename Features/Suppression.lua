--------------------------------------------------------------------
--Suppression
--------------------------------------------------------------------
WT.suppression = {}
local suppression = {}
suppression.suppressed_groups = {}
suppression.time_on_kill = 5
suppression.time_on_hit = 2
suppression.coalition = -1
suppression.all_ground = true
suppression.ai_enable = true

function suppression.suppress(dur, group)
    local found = false
    for g = 1, #suppression.suppressed_groups do
        if suppression.suppressed_groups[g].grp == group then
            found = true
            local timing = suppression.suppressed_groups[g].timing - timer.getTime()
            if timing < 4 * dur then
                if timing < 0 then
                    suppression.suppressed_groups[g].timing = timer.getTime() + dur
                    group:getController():setOption(0, 4) --weapons hold
                    suppression.suppressed_groups[g].suppressed = true
                else
                    suppression.suppressed_groups[g].timing = suppression.suppressed_groups[g].timing + dur
                end
            end
        end
    end
    if found == false then
        suppression.suppressed_groups[#suppression.suppressed_groups + 1] = {
            grp = group,
            timing = timer.getTime() + dur,
            suppressed = true,
            size =
                group:getSize()
        }
        group:getController():setOption(0, 4)
    end
end

function suppression.checkSuppression(bunk, time) --bunk is a placeholder because DCS lua is dumb
    local toRemove = {}
    for g = 1, #suppression.suppressed_groups do
        if suppression.suppressed_groups[g].grp:isExist() then
            if suppression.suppressed_groups[g].timing - timer.getTime() <= 0 and suppression.suppressed_groups[g].suppressed == true and suppression.suppressed_groups[g].grp:isExist() then
                suppression.suppressed_groups[g].grp:getController():setOption(0, 0) --weapons free
                suppression.suppressed_groups[g].suppressed = false
            end
            if suppression.suppressed_groups[g].size > suppression.suppressed_groups[g].grp:getSize() and suppression.time_on_kill > 0 then
                suppression.suppress(suppression.time_on_kill, suppression.suppressed_groups[g].grp)
                suppression.suppressed_groups[g].size = suppression.suppressed_groups[g].grp:getSize()
            end
        else
            --remove(suppressed_groups[g].gID)
            toRemove[#toRemove + 1] = g
        end
    end
    for r = 1, #toRemove do
        table.remove(suppression.suppressed_groups, toRemove[r])
    end
    if #suppression.suppressed_groups > 0 then
        return time + 0.10
    else
        return time + 1
    end
end

function suppression.handleEvents(event)
    if event.id == world.event.S_EVENT_HIT then --hit
        if Object.getCategory(event.target) ~= 1 then
            return
        end
        if event.target:getDesc().Category ~= 2 and event.target:getDesc().Category ~= 3 then
            return
        end
        local grp = event.target:getGroup()
        if grp:isExist() and event.initiator then
            if event.initiator:getPlayerName() ~= nil or suppression.ai_enable == true then
                if grp:getSize() > 0 and grp:getCategory() == 2 then
                    if suppression.all_ground == true then
                        if coalition ~= nil or grp:getCoalition() == coalition then
                            suppression.suppress(suppression.time_on_hit, grp)
                        end
                    else
                        if string.starts(grp:getName(), "SUP_") then
                            suppression.suppress(suppression.time_on_hit, grp)
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
--suppression: suppresses ground units when they are shot at, not that it has no wway of knowing the current ROEs so if they are already weapons hold they will go weapons free when shot, after suppression ends as a result
--is extremely basic, all hits work so yes infantry can suppress a tank, will iterate on later
--args are as follows
--hit: suuppression time on hit in seconds
--kill: suppression time on kill in seconds
--all: should we apply to all ground units
--side: 1 for red 2 for blue, nil for both
--ai: if false then suppression only happens when shot by a player unit
--WT.suppression.setup(2,5,true,1,false) 2 seconds suppression on hit, 5 on unit death, apply to all ground units, in red coalition, and only apply it if shot by a player
--WT.suppression.setup(2,5,false,1,false) 2 seconds suppression on hit, 5 on unit death, apply to only ground units whose group name starts with SUP_, in red coalition, and only apply it if shot by a player
---------------------------------------------------------------------------
function WT.suppression.setup(hit, kill, all, side, ai)
    suppression.time_on_kill = kill
    suppression.time_on_hit = hit
    suppression.ai_enable = ai
    suppression.all_ground = all
    WT.utils.registerEventListener(world.event.S_EVENT_HIT, WT.suppression.eventHandle)
    timer.scheduleFunction(suppression.checkSuppression, 1, timer.getTime() + 1)
end
