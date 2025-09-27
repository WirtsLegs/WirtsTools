---------------------------------------------------------------------
--Killswitch.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------

WT.killswitch = {}
WT.killswitch.active = {}
WT.killswitch.used = {}

function WT.killswitch.killswitch(details)
    trigger.action.setUserFlag(details.flag, 1)
    if details.single == true then
        missionCommands.removeItemForGroup(details.id, { [1] = "killswitch" })
        WT.killswitch.used[details.name] = true
    end
end

function WT.killswitch.updateMenu(details, time)
    local cntgrp = WT.utils.p(Group.getByName, details.cName)
    local players = WT.utils.TableConcat(coalition.getPlayers(1), coalition.getPlayers(2))
    local group = nil
    for p = 1, #players do
        if string.match(players[p]:getPlayerName(), details.pname) then
            group = players[p]:getGroup():getName()
        end
    end

    if WT.killswitch.used[details.name] == true then
        return nil
    end

    if details.cName ~= group then
        if details.cID ~= nil then
            missionCommands.removeItemForGroup(details.cID, { [1] = "killswitch" })
            WT.killswitch.active[details.cID] = 0
        end
        if group then
            local gr = Group.getByName(group)
            local id = gr:getID()
            if WT.killswitch.active[id] ~= 1 then
                missionCommands.addSubMenuForGroup(gr:getID(), "killswitch")
                WT.killswitch.active[id] = 1
            end
            missionCommands.addCommandForGroup(gr:getID(), details.name, { [1] = "killswitch" }, WT.killswitch
                .killswitch,
                { flag = details.flag, single = details.single, name = details.name, id = details.cID })
            details.cID = gr:getID()
            details.cName = group
        end
    end
    return time + 5
end

---------------------------------------------------------------------------
--killSwitch
--will only expose a radio f10 option to a given player-name's group
--player: subname of the player (eg maple if the player's name will for sure contain maple)
--name: name of the radio option
--flag: flag to set when pressed
---------------------------------------------------------------------------
function WT.killswitch.setup(player, name, flag, singleUse)
    local details = { pname = player, name = name, flag = flag, single = singleUse, cName = nil, cID = nil }
    timer.scheduleFunction(WT.killswitch.updateMenu, details, timer.getTime() + 1)
end
