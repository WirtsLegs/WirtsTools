-- Progressive destruction of units in a group using DCS timer.scheduleFunction
-- group: DCS group reference
-- minPower, maxPower: explosion power range
-- totalTime: seconds over which to destroy all units
function WT.progressiveDestruction(group, minPower, maxPower, totalTime)
    local units = group:getUnits()
    local unitCount = #units
    if unitCount == 0 then return end

    -- Shuffle units for random order
    local shuffled = {}
    for i = 1, unitCount do shuffled[i] = units[i] end
    for i = unitCount, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Assign kill times: evenly spaced, last unit at totalTime
    local killTimes = {}
    for i = 1, unitCount do
        killTimes[i] = ((i-1) / (unitCount-1)) * totalTime
    end

    -- Store initial life for each unit
    local initialLife = {}
    for i, unit in ipairs(shuffled) do
        initialLife[unit:getName()] = unit:getLife()
    end

    local function confirmKill(args)
        local unit = args.u
        local power = args.p
        local initialLifeVal = args.i
        if unit and unit:isExist() then
            local life = unit:getLife()
            if life > 0.05 * initialLifeVal then
                -- Repeat explosion immediately
                local point = unit:getPoint()
                WT.utils.explodePoint({ point = point, power = power })
                timer.scheduleFunction(confirmKill, {u=unit, p=power, i=initialLifeVal}, timer.getTime() + 0.01)
            end
        end
        return nil
    end

    -- Helper: explosion and check
    local function explodeAndCheck(unit, power, initialLifeVal)
        local point = unit:getPoint()
        WT.utils.explodePoint({ point = point, power = power })
        timer.scheduleFunction(confirmKill, {u=unit, p=power, i=initialLifeVal}, timer.getTime() + 0.01)
        return nil
    end

    -- Schedule explosions
    for i, unit in ipairs(shuffled) do
        local name = unit:getName()
        timer.scheduleFunction(function()
            explodeAndCheck(unit, math.random() * (maxPower - minPower) + minPower, initialLife[name])
        end, {}, timer.getTime() + killTimes[i])
    end
end