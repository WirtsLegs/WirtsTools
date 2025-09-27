-----------------------------
--Tasking
----------------------------
WT.tasking = {}
WT.tasking.tasks = {}


function WT.tasking.relative(point, task, ground)
    local offsetX = point.x - task.params.route.points[1].x
    local offsetAlt = point.y - task.params.route.points[1].alt
    local offsetY = point.z - task.params.route.points[1].y
    for p = 2, task.params.route.points do
        task.params.route.points[p].x = task.params.route.points[p].x + offsetX
        task.params.route.points[p].y = task.params.route.points[p].y + offsetY

        if ground then
            task.params.route.points[p].alt = land.getHeight({
                x = task.params.route.points[p].x,
                y = task.params.route
                    .points[p].y
            })
        else
            task.params.route.points[p].alt = task.params.route.points[p].alt + offsetAlt
        end
    end

    return task
end

function WT.tasking.getGroups()
    local grp_rt = env.mission['coalition']['blue']['country']
    local tgt = nil
    for c = 1, #grp_rt do
        if grp_rt[c]['vehicle'] then
            local grplocal = grp_rt[c]['vehicle']['group']
            for g = 1, #grplocal do
                if string.starts(grplocal[g]['name'], "TASK_") then
                    WT.tasking.tasks[grplocal[g]['name']] = grplocal[g]["route"]["points"]
                end
            end
        end
        if grp_rt[c]['plane'] then
            local grplocal = grp_rt[c]['plane']['group']
            for g = 1, #grplocal do
                if string.starts(grplocal[g]['name'], "TASK_") then
                    WT.tasking.tasks[grplocal[g]['name']] = grplocal[g]["route"]["points"]
                end
            end
        end
    end
end
