---------------------------------------------------------------------
--Tasking.lua
--Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools)
---------------------------------------------------------------------

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

---------------------------------------------------------------------------
--Call when you want to drop a new mission into a group, designed to have taskings defined via late activation groups you never activate
--group: name of the group you want to task
--task: name of the group whose tasking you want to clone (must start with 'TASK_')
---------------------------------------------------------------------------

function WT.tasking.task(group, task, relative)
    local grp = WT.utils.p(Group.getByName, group)
    if grp and grp:isExist() then
        local cat = grp:getCategory()
        local u = WT.utils.p(grp.getUnits, grp)
        if u and WT.tasking.tasks[task] then
            local u1 = u[1]:getPoint()
            local v1 = WT.utils.VecMag(u[1]:getVelocity())
            local tasking = nil
            if cat < 2 then
                tasking = WT.utils.deepCopy(WT.tasks.airMission)
            else
                tasking = WT.utils.deepCopy(WT.tasks.groundMission)
            end
            tasking.params['route']['points'] = WT.utils.deepCopy(WT.tasking.tasks[task])
            if relative then
                if cat < 2 then
                    tasking = WT.tasking.relative(u1, tasking, false)
                else
                    tasking = WT.tasking.relative(u1, tasking, true)
                end
            end
            tasking.params.route.points[1].alt = u1.y
            tasking.params.route.points[1].x = u1.x
            tasking.params.route.points[1].y = u1.z
            tasking.params.route.points[1].speed = v1

            local cnt = grp:getController()
            cnt:setTask(tasking)
        end
    end
end
