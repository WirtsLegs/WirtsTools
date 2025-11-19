WT.expressions = {}

-- Utility: Trim string
function WT.expressions.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Coalition mapping
WT.expressions.coalitionMap = {
    BLUE = coalition.side.BLUE,
    RED = coalition.side.RED,
    NEUTRAL = coalition.side.NEUTRAL,
}

-- Unit category helpers
function WT.expressions.getUnitCategory(unit)
    local unitDesc = unit:getDesc()
    if unitDesc.category == Unit.Category.AIRPLANE then
        return "AIRPLANE"
    elseif unitDesc.category == Unit.Category.HELICOPTER then
        return "HELICOPTER"
    elseif unitDesc.category == Unit.Category.GROUND_UNIT then
        return "GROUND"
    elseif unitDesc.category == Unit.Category.SHIP then
        return "NAVAL"
    end
    return nil
end

function WT.expressions.isPlayerControlled(unit)
    return unit:getPlayerName() ~= nil
end

-- Check if unit matches a category, supporting both DCS categories and masked AIRCRAFT term
function WT.expressions.matchesCategory(unit, categoryTerm)
    local unitCategory = WT.expressions.getUnitCategory(unit)
    if not unitCategory then return false end

    -- Exact match to DCS categories
    if categoryTerm == unitCategory then
        return true
    end

    -- Masked category: AIRCRAFT includes both AIRPLANE and HELICOPTER
    if categoryTerm == "AIRCRAFT" then
        return unitCategory == "AIRPLANE" or unitCategory == "HELICOPTER"
    end

    return false
end



-- Parse a single selection term (e.g., "BLUE", "PLAYER", "AIRCRAFT")
function WT.expressions.parseTerm(term)
    term = WT.expressions.trim(term):upper()

    if WT.expressions.coalitionMap[term] then
        return { type = "coalition", value = WT.expressions.coalitionMap[term] }
    elseif term == "PLAYER" then
        return { type = "player", value = true }
    elseif term == "AI" then
        return { type = "player", value = false }
    elseif term == "AIRCRAFT" or term == "AIRPLANE" or term == "HELICOPTER" or term == "GROUND" or term == "NAVAL" then
        return { type = "category", value = term }
    end

    return nil
end

-- Parse GROUP:name or GROUP_PREFIX:name syntax
function WT.expressions.parseGroupFilter(term)
    term = WT.expressions.trim(term)
    if string.starts(term, "GROUP:") then
        local name = WT.expressions.trim(term:sub(7))
        return { type = "group", mode = "exact", value = name }
    elseif string.starts(term, "GROUP_PREFIX:") then
        local name = WT.expressions.trim(term:sub(14))
        return { type = "group", mode = "prefix", value = name }
    end
    return nil
end

-- Check if a unit matches a single filter criterion
function WT.expressions.unitMatchesFilter(unit, filter)
    if filter.type == "coalition" then
        return unit:getCoalition() == filter.value
    elseif filter.type == "player" then
        return WT.expressions.isPlayerControlled(unit) == filter.value
    elseif filter.type == "category" then
        return WT.expressions.matchesCategory(unit, filter.value)
    elseif filter.type == "group" then
        local group = unit:getGroup()
        local groupName = group:getName()
        if filter.mode == "exact" then
            return groupName == filter.value
        elseif filter.mode == "prefix" then
            return string.starts(groupName, filter.value)
        end
    end
    return false
end

-- Check if a unit matches all filters in an AND clause
function WT.expressions.unitMatchesAndClause(unit, filters)
    for _, filter in ipairs(filters) do
        if not WT.expressions.unitMatchesFilter(unit, filter) then
            return false
        end
    end
    return true
end

-- Parse a single AND clause (e.g., "BLUE PLAYER AIRCRAFT")
-- Handles both implicit (space-separated) and explicit AND operators
function WT.expressions.parseAndClause(clauseStr)
    local filters = {}
    -- Replace explicit AND with space for uniform parsing
    clauseStr = clauseStr:gsub("%s+AND%s+", " ")
    for term in clauseStr:gmatch("[^%s]+") do
        local filter = WT.expressions.parseGroupFilter(term)
        if not filter then
            filter = WT.expressions.parseTerm(term)
        end
        if filter then
            table.insert(filters, filter)
        end
    end
    return filters
end

-- Parse selection expression with OR support
-- Supports both symbolic (,) and word-based (OR) operators
-- Examples: "BLUE HELICOPTER, RED AIRCRAFT" or "BLUE HELICOPTER OR RED AIRCRAFT"
function WT.expressions.parseSelectionExpr(selectionExpr)
    local orClauses = {}

    -- Normalize: replace " OR " with comma for uniform splitting
    selectionExpr = selectionExpr:gsub("%s+OR%s+", ",")

    for clause in selectionExpr:gmatch("[^,]+") do
        local filters = WT.expressions.parseAndClause(clause)
        if #filters > 0 then
            table.insert(orClauses, filters)
        end
    end
    return orClauses
end

-- Analyze selection criteria to determine optimal collection strategy
function WT.expressions.analyzeSelectionCriteria(orClauses)
    local analysis = {
        specificGroups = {},
        coalitions = {},
        onlyPlayers = nil,
        onlyAI = nil,
        categories = {},
    }

    -- Track constraints across all OR clauses
    local allCoalitions = {}
    local allOnlyPlayers = nil
    local allOnlyAI = nil
    local allCategories = {}

    for _, andFilters in ipairs(orClauses) do
        local clauseCoalitions = {}
        local clauseOnlyPlayers = nil
        local clauseOnlyAI = nil
        local clauseCategories = {}
        local clauseSpecificGroup = nil

        for _, filter in ipairs(andFilters) do
            if filter.type == "coalition" then
                clauseCoalitions[filter.value] = true
            elseif filter.type == "player" then
                if filter.value == true then
                    clauseOnlyPlayers = true
                else
                    clauseOnlyAI = true
                end
            elseif filter.type == "category" then
                clauseCategories[filter.value] = true
            elseif filter.type == "group" and filter.mode == "exact" then
                clauseSpecificGroup = filter.value
            end
        end

        if clauseSpecificGroup then
            table.insert(analysis.specificGroups, clauseSpecificGroup)
        end

        -- Merge clause constraints into overall constraints
        for coal, _ in pairs(clauseCoalitions) do
            allCoalitions[coal] = true
        end
        for cat, _ in pairs(clauseCategories) do
            allCategories[cat] = true
        end

        if clauseOnlyPlayers then allOnlyPlayers = true end
        if clauseOnlyAI then allOnlyAI = true end
    end

    -- Convert coalitions to array
    for coal, _ in pairs(allCoalitions) do
        table.insert(analysis.coalitions, coal)
    end

    -- If no coalition specified, include all
    if #analysis.coalitions == 0 then
        analysis.coalitions = { coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }
    end

    -- Convert categories to array
    for cat, _ in pairs(allCategories) do
        table.insert(analysis.categories, cat)
    end

    analysis.onlyPlayers = allOnlyPlayers
    analysis.onlyAI = allOnlyAI

    return analysis
end

-- Get all units matching the selection expression
function WT.expressions.getCandidates(selectionExpr)
    local orClauses = WT.expressions.parseSelectionExpr(selectionExpr)

    if #orClauses == 0 then
        return {}
    end

    -- Analyze selection criteria for optimal collection
    local analysis = WT.expressions.analyzeSelectionCriteria(orClauses)

    local candidates = {}

    -- Optimization 1: If only specific groups are mentioned, fetch only those
    if #analysis.specificGroups > 0 and #analysis.specificGroups == #orClauses then
        for _, groupName in ipairs(analysis.specificGroups) do
            local group = Group.getByName(groupName)
            if group then
                local units = group:getUnits()
                for _, unit in ipairs(units) do
                    for _, andFilters in ipairs(orClauses) do
                        if WT.expressions.unitMatchesAndClause(unit, andFilters) then
                            table.insert(candidates, unit)
                            break
                        end
                    end
                end
            end
        end
        return candidates
    end

    -- Optimization 2: If only players or only AI, use specialized collection
    if analysis.onlyPlayers == true and not analysis.onlyAI then
        for _, coalitionSide in ipairs(analysis.coalitions) do
            local players = coalition.getPlayers(coalitionSide)
            for _, unit in ipairs(players) do
                for _, andFilters in ipairs(orClauses) do
                    if WT.expressions.unitMatchesAndClause(unit, andFilters) then
                        table.insert(candidates, unit)
                        break
                    end
                end
            end
        end
        return candidates
    end

    -- Standard approach: Iterate through coalitions and groups
    for _, coalitionSide in ipairs(analysis.coalitions) do
        local groups = coalition.getGroups(coalitionSide)
        for _, group in ipairs(groups) do
            local units = group:getUnits()
            for _, unit in ipairs(units) do
                for _, andFilters in ipairs(orClauses) do
                    if WT.expressions.unitMatchesAndClause(unit, andFilters) then
                        table.insert(candidates, unit)
                        break
                    end
                end
            end
        end
    end

    return candidates
end

-- Basic keyword registry
WT.expressions.keywords = {
    AGL = true,
    ASL = true,
    SPEED = true,
    HEADING = true,
    LIFE = true,
}

-- Complex keyword registry
WT.expressions.complexKeywords = {}

-- Register a complex keyword with argument count and handler
function WT.expressions.registerKeyword(name, argCount, handler)
    WT.expressions.complexKeywords[name] = { argCount = argCount, handler = handler }
end

-- Replace logical operators with Lua equivalents
function WT.expressions.normalizeOperators(expr)
    expr = expr:gsub("AND", "and")
    expr = expr:gsub("OR", "or")
    expr = expr:gsub("NOT", "not")
    return expr
end

-- Preprocess complex keywords: replace with placeholders
function WT.expressions.preprocessComplex(expr)
    local complexCount = 0
    return expr:gsub("(%u+)%s+([%w_:]+)", function(keyword, args)
        local entry = WT.expressions.complexKeywords[keyword]
        if entry then
            complexCount = complexCount + 1
            local placeholder = string.format("__COMPLEX_%d__", complexCount)
            return placeholder .. " "
        end
        return keyword .. " " .. args
    end)
end

-- Preprocess basic keywords: replace with placeholders
function WT.expressions.preprocessKeywords(expr)
    return expr:gsub("(%u[%u_]*)", function(term)
        if WT.expressions.keywords[term] then
            return "__KEYWORD_" .. term .. "__"
        else
            return term
        end
    end)
end

-- Get basic unit parameters with minimal API calls
-- paramsNeeded: table of parameter names (e.g., {"SPEED", "AGL", "HEADING"})
-- Returns: table with all requested parameters
function WT.expressions.getBasicParams(unit, paramsNeeded)
    local params = {}

    -- If no params requested, return empty table
    if not paramsNeeded or #paramsNeeded == 0 then
        return params
    end

    -- Check which expensive calls we actually need
    local needPosition = false
    local needVelocity = false

    for _, param in ipairs(paramsNeeded) do
        if param == "AGL" or param == "ASL" then
            needPosition = true
        elseif param == "SPEED" or param == "HEADING" then
            needVelocity = true
        elseif param == "LIFE" then
            -- LIFE doesn't need position or velocity
        end
    end

    -- Make minimal API calls
    local position = nil
    local velocity = nil

    if needPosition then
        position = unit:getPoint()
    end

    if needVelocity then
        velocity = unit:getVelocity()
    end

    -- Calculate all requested parameters
    for _, param in ipairs(paramsNeeded) do
        if param == "AGL" then
            if position then
                local terrainHeight = land.getHeight({ x = position.x, y = position.z })
                params.AGL = position.y - terrainHeight
            else
                params.AGL = 0
            end
        elseif param == "ASL" then
            if position then
                params.ASL = position.y
            else
                params.ASL = 0
            end
        elseif param == "SPEED" then
            if velocity then
                params.SPEED = math.sqrt(velocity.x ^ 2 + velocity.y ^ 2 + velocity.z ^ 2)
            else
                params.SPEED = 0
            end
        elseif param == "HEADING" then
            if velocity then
                -- Calculate heading in degrees (0-360)
                -- North is 0 degrees, East is 90, South is 180, West is 270
                local heading = math.atan2(velocity.x, velocity.z) * 180 / math.pi
                params.HEADING = (heading + 360) % 360
            else
                params.HEADING = 0
            end
        elseif param == "LIFE" then
            local life = WT.utils.p(unit.getLife, unit)
            params.LIFE = life or 0
        end
    end

    return params
end

-- At construction, preprocess the expression
function WT.expressions.new(selectionExpr, boolExpr, evalMode, threshold)
    local self = {
        selectionExpr = selectionExpr,
        evalMode = evalMode or "ANY",
        threshold = threshold,
        debug = false,
    }

    -- Preprocess expression: logical ops, then complex, then basic keywords
    local expr = WT.expressions.normalizeOperators(boolExpr)

    -- Capture complex keywords before preprocessing
    self.complexTerms = {}
    expr:gsub("(%u+)%s+([%w_:]+)", function(keyword, args)
        local entry = WT.expressions.complexKeywords[keyword]
        if entry then
            table.insert(self.complexTerms, { keyword = keyword, args = args })
        end
    end)

    -- Now preprocess
    expr = WT.expressions.preprocessComplex(expr)
    expr = WT.expressions.preprocessKeywords(expr)
    self.exprTemplate = expr
    self.basicTerms = {}

    -- Collect placeholders for basic keywords
    expr:gsub("(__KEYWORD_([%u_]+)__)", function(placeholder, term)
        table.insert(self.basicTerms, { placeholder = placeholder, term = term })
    end)

    -- Collect which basic parameters are needed
    local basicParamsNeeded = {}
    for _, entry in ipairs(self.basicTerms) do
        table.insert(basicParamsNeeded, entry.term)
    end
    self.basicParamsNeeded = basicParamsNeeded

    -- Evaluate boolean expression for a unit
    function self:evaluateUnit(unit)
        local expr = self.exprTemplate

        -- Get all basic parameters with single function call
        local basicParams = WT.expressions.getBasicParams(unit, self.basicParamsNeeded)

        -- Substitute complex term placeholders
        for idx, entry in ipairs(self.complexTerms) do
            local placeholder = string.format("__COMPLEX_%d__", idx)
            local handlerEntry = WT.expressions.complexKeywords[entry.keyword]

            local argList = {}
            if entry.args ~= "" then
                for arg in string.gmatch(entry.args, "[^:]+") do
                    table.insert(argList, WT.expressions.trim(arg))
                end
            end

            while #argList < handlerEntry.argCount do
                table.insert(argList, nil)
            end

            local value = tostring(handlerEntry.handler(unit, unpack(argList)))
            expr = expr:gsub(placeholder, value)
        end

        -- Substitute basic keyword placeholders
        for _, entry in ipairs(self.basicTerms) do
            local value = basicParams[entry.term] or 0
            expr = expr:gsub(entry.placeholder, tostring(value))
        end

        local ok, result = pcall(function() return loadstring("return " .. expr)() end)
        return ok and result or false
    end

    -- Evaluate the whole expression
    function self:evaluate(debugMode)
        debugMode = debugMode or self.debug

        local candidates = WT.expressions.getCandidates(self.selectionExpr)

        if debugMode then
            trigger.action.outText("=== EXPRESSION EVALUATION DEBUG ===", 5, false)
            trigger.action.outText("Selection: " .. self.selectionExpr, 5, false)
            trigger.action.outText("Boolean Expression: " .. self.exprTemplate, 5, false)
            trigger.action.outText("Evaluation Mode: " .. self.evalMode .. (self.threshold and " (Threshold: " .. self.threshold .. ")" or ""), 5, false)
            trigger.action.outText("---", 5, false)
        end

        if debugMode then
            if #candidates == 0 then
                trigger.action.outText("No units matched selection criteria", 5, false)
            else
                trigger.action.outText("Selected Units:", 5, false)
                for i, unit in ipairs(candidates) do
                    trigger.action.outText("  " .. i .. ". " .. unit:getName(), 5, false)
                end
                trigger.action.outText("---", 5, false)
            end
        end

        local countTrue = 0
        local total = #candidates

        for _, unit in ipairs(candidates) do
            local unitResult = self:evaluateUnit(unit)
            if unitResult then
                countTrue = countTrue + 1
            end

            if debugMode then
                trigger.action.outText("  " .. unit:getName() .. ": " .. tostring(unitResult), 5, false)
            end
        end

        local finalResult = false

        if self.evalMode == "ANY" then
            finalResult = countTrue > 0
        elseif self.evalMode == "ALL" then
            finalResult = countTrue == total and total > 0
        elseif self.evalMode == "PERCENT" then
            finalResult = total > 0 and (countTrue / total * 100) >= (self.threshold or 100)
        elseif self.evalMode == "AMOUNT" then
            finalResult = countTrue >= (self.threshold or total)
        end

        if debugMode then
            trigger.action.outText("---", 5, false)
            trigger.action.outText("Result: " .. countTrue .. "/" .. total .. " units matched", 5, false)
            trigger.action.outText("Overall Result: " .. tostring(finalResult), 5, false)
            trigger.action.outText("===================================", 5, false)
        end

        return finalResult
    end

    function self:setWhen(flagName)
        local value = self:evaluate()
        trigger.action.setUserFlag(flagName, value and 1 or 0)
    end

    return self
end

-- Example: Register complex keywords
WT.expressions.registerKeyword("LOCKED", 1, function(unit, lockType)
    -- TODO: Implement logic to check if unit is locked by lockType (e.g., RADAR)
    return false
end)

WT.expressions.registerKeyword("PROX", 2, function(unit, coalition, unitType)
    -- TODO: Implement logic to get proximity to specified coalition/unitType
    return 99999
end)

-- Usage examples:
-- local expr = WT.expressions.new("BLUE AIRCRAFT", "AGL > 500 AND SPEED > 100", "ANY")
-- local result = expr:evaluate(true) -- true enables debug output
-- local expr = WT.expressions.new("RED HELICOPTER OR BLUE PLAYER AIRCRAFT", "LIFE > 50", "ALL")
-- local result = expr:evaluate(true)
