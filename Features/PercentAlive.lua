---------------------------------------------------------------------
--percentAlive
---------------------------------------------------------------------
WT.percentAlive = {}

function WT.percentAlive.newTracker(groups, flag)
    local tracker = {
        grps = groups,
        full = 0,
        flg = flag,

        getFull = function(self)
            for g = 1, #self.grps do
                local grp = Group.getByName(self.grps[g])
                if grp then
                    self.full = self.full + grp:getInitialSize()
                end
            end
        end,

        check = function(self, time)
            local current = 0
            for g = 1, #self.grps do
                local grp = Group.getByName(self.grps[g])
                if grp then
                    current = current + grp:getSize()
                end
            end
            current = math.floor((current / self.full) * 100 + 0.5)
            trigger.action.setUserFlag(self.flg, current)
            if current > 0 then
                return time + 1
            end
            return nil
        end,
    }
    tracker:getFull()
    timer.scheduleFunction(tracker.check, tracker, timer.getTime() + 1)
end

----------------------------------------------
--percentAlive: updates a provided flag with overall percent of indicated groups that are alive
--groups: a list of groupnames in the form {"name1","name2","name3"}
--flag: flag to populate with overal percent alive
--example:
----------------------------------------------

function WT.percentAlive.setup(groups, flag)
    WT.percentAlive.newTracker(groups, flag)
end
