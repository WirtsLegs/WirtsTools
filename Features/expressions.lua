WT = WT or {}
WT.expressions = {}

-- Utility: Split string by space
local function split(str)
    local t = {}
    for word in string.gmatch(str, "[^%s]+") do
        table.insert(t, word)
    end
    return t
end

-- Utility: Trim string
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Selection parser: returns a list of unit objects based on selectionExpr
function WT.expressions.getCandidates(selectionExpr)
    -- TODO: Implement unit selection logic using DCS API
    return {}
end

-- Basic keyword handlers: fetch unit parameters
WT.expressions.keywords = {
    AGL = function(unit) return 0 end,      -- TODO
    ASL = function(unit) return 0 end,      -- TODO
    SPEED = function(unit) return 0 end,    -- TODO
    HEADING = function(unit) return 0 end,  -- TODO
    LIFE = function(unit) return 0 end,     -- TODO
    -- ...add more as needed...
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
    return expr:gsub("([A-Z]+%s*:?[%w_]*)", function(term)
        local keyword, args = term:match("^(%w+)%s*(.*)$")
        local entry = WT.expressions.complexKeywords[keyword]
        if entry then
            local argList = {}
            if args ~= "" then
                for arg in string.gmatch(args, "[^:]+") do
                    table.insert(argList, arg)
                end
            end
            while #argList < entry.argCount do
                table.insert(argList, "")
            end
            -- Use a unique placeholder for each complex term
            local placeholder = "__COMPLEX_" .. keyword .. "_" .. table.concat(argList, "_") .. "__"
            return placeholder
        end
        return term
    end)
end

-- Preprocess basic keywords: replace with placeholders
function WT.expressions.preprocessKeywords(expr)
    return expr:gsub("([%u_]+)", function(term)
        if WT.expressions.keywords[term] then
            return "__KEYWORD_" .. term .. "__"
        else
            return term
        end
    end)
end

-- At construction, preprocess the expression
function WT.expressions.new(selectionExpr, boolExpr, evalMode, threshold)
    local self = {
        selectionExpr = selectionExpr,
        evalMode = evalMode or "ANY",
        threshold = threshold,
    }

    -- Preprocess expression: logical ops, complex, then basic keywords
    local expr = WT.expressions.normalizeOperators(boolExpr)
    expr = WT.expressions.preprocessComplex(expr)
    expr = WT.expressions.preprocessKeywords(expr)
    self.exprTemplate = expr
    self.complexTerms = {}
    self.basicTerms = {}

    -- Collect placeholders for complex terms
    expr:gsub("(__COMPLEX_([A-Z]+)_([%w_]*)__)", function(placeholder, keyword, args)
        table.insert(self.complexTerms, { placeholder = placeholder, keyword = keyword, args = args })
    end)
    -- Collect placeholders for basic keywords
    expr:gsub("(__KEYWORD_([%u_]+)__)", function(placeholder, term)
        table.insert(self.basicTerms, { placeholder = placeholder, term = term })
    end)

    -- Evaluate boolean expression for a unit
    function self:evaluateUnit(unit)
        local expr = self.exprTemplate
        -- Substitute complex term placeholders
        for _, entry in ipairs(self.complexTerms) do
            local handlerEntry = WT.expressions.complexKeywords[entry.keyword]
            local argList = {}
            if entry.args ~= "" then
                for arg in string.gmatch(entry.args, "[^_]+") do
                    table.insert(argList, arg)
                end
            end
            while #argList < handlerEntry.argCount do
                table.insert(argList, nil)
            end
            local value = tostring(handlerEntry.handler(unit, unpack(argList)))
            expr = expr:gsub(entry.placeholder, value)
        end
        -- Substitute basic keyword placeholders
        for _, entry in ipairs(self.basicTerms) do
            local value = tostring(WT.expressions.keywords[entry.term](unit))
            expr = expr:gsub(entry.placeholder, value)
        end
        local ok, result = pcall(function() return loadstring("return " .. expr)() end)
        return ok and result or false
    end

    -- Evaluate the whole expression
    function self:evaluate()
        local candidates = WT.expressions.getCandidates(self.selectionExpr)
        local countTrue = 0
        local total = #candidates
        for _, unit in ipairs(candidates) do
            if self:evaluateUnit(unit) then
                countTrue = countTrue + 1
            end
        end
        if self.evalMode == "ANY" then
            return countTrue > 0
        elseif self.evalMode == "ALL" then
            return countTrue == total and total > 0
        elseif self.evalMode == "PERCENT" then
            return total > 0 and (countTrue / total * 100) >= (self.threshold or 100)
        elseif self.evalMode == "AMOUNT" then
            return countTrue >= (self.threshold or total)
        end
        return false
    end

    function self:setWhen(flagName)
        local value = self:evaluate()
        trigger.action.setUserFlag(flagName, value and 1 or 0)
    end

    return self
end

-- Example: Register a complex keyword
WT.expressions.registerKeyword("LOCKED", 1, function(unit, lockType)
    -- TODO: Implement logic to check if unit is locked by lockType (e.g., RADAR)
    return false
end)

WT.expressions.registerKeyword("PROX", 2, function(unit, coalition, unitType)
    -- TODO: Implement logic to get proximity to specified coalition/unitType
    return 99999
end)

-- Usage example (stub):
-- local expr = WT.expressions.new("COALITION RED AIRCRAFT", "AGL > 500 AND LOCKED RADAR", "ANY")
-- local result = expr:evaluate()
-- expr:setWhen("FlagX")
