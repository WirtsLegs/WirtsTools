----------------------------------------------------
-- Support.lua
-- Module for WIrtsTools that adds support call-ins, primarily Close Air Support and Artillery
----------------------------------------------------
do
    WT.support={}
    WT.support.cas={}
    WT.support.artillery={}
    WT.support.target_points={}
    WT.support.designationTypes={
        MARKER=1,
        CHAT=2,
        SMOKE=3
    }
    WT.support.artillery.shells={
        HE=1,
        ILLUM=2
    }
    WT.support.artillery.skill={
        NOVICE={
            aimTime=180,
            initialError=500,
            timeBetweenRounds=20
        },
        REGULAR={
            aimTime=120,
            initialError=280,
            timeBetweenRounds=16
        },
        VETERAN={
            aimTime=60,
            initialError=150,
            timeBetweenRounds=12
        }
    }

    WT.support.artillery.era={
        WW2={
            minimum=20,
            distance=0.008,
            lateral=0.003,
        },
        COLDWAR={
            minimum=15,
            distance=0.0065,
            lateral=0.0025
        },
        MODERN={
            minimum=10,
            distance=0.005,
            lateral=0.002
        }

    }

    WT.support.artillery.battery_type={
        VIRTUAL=1,
        REAL=2
    }

    WT.support.target_point={
        x=0,
        y=0,
        elevation=0,
        radius=0,
        designation={}
        id=0,
        name=""
    }

    function WT.support.eventHandler(event)

    end

    function WT.support.newVirtualArtilleryBattery(name,coalition)
        local battery={
            name=name,
            Coalition=coalition,
            BatteryType=WT.support.artillery.battery_type.VIRTUAL,
            BatteryEra=WT.support.artillery.era.COLDWAR,
            position={},
            guns={},
            range=0,
            travelTime=2,
            skill=WT.support.artillery.skill.REGULAR,
            shells={WT.support.artillery.shells.HE,WT.support.artillery.shells.ILLUM},


            activeMission = nil,
            missions = {},

            tasked=false,
            firing=false,
            roundCount=0,
            

            setPosition=function(self,position)
                self.position=position
            end,

            setRange=function(self,range)
                self.range=range
            end,

            setCoalition=function(self,coalition)
                self.Coalition=coalition
            end,

            setTravelTime=function(self,time)
                self.travelTime=time
            end,

            setGroupName=function(self,groupName)
                self.groupName=groupName
            end,

            setSkill=function(self,skill)
                self.skill=skill
            end,

            addShell=function(self,shell)
                for i,s in ipairs(self.shells) do
                    if s == shell then
                        return
                    end
                end
                self.shells[#self.shells+1]=shell
            end,

            removeShell=function(self,shell)
                for i,s in ipairs(self.shells) do
                    if s == shell then
                        self.shells[i]=nil
                    end
                end
            end,

            updateGun=function(self)
                local remainingRounds = 0
                for _, gun in ipairs(self.guns) do
                    remainingRounds = remainingRounds + gun.rounds
                end
                if remainingRounds == 0 then
                    self.firing = false
                end
            end,

            addGun=function(self)
                gun={
                    rounds=0
                    battery=self,
                    mission=nil,
                    
                    addRound=function(self,round)
                        self.rounds=self.rounds+1
                    end,

                    setMission=function(self,mission)
                        self.mission=mission
                    end,

                    cancelFire=function(self)
                        self.rounds={}
                    end,

                    fire=function(sel,time)
                        if self.rounds>0 then
                            self.rounds=self.rounds-1
                            --develop the target point, as the original target point, randomized by spread
                            --then randomized by variance(inherent to the gun based on range)
                            local baseline=self.mission.targetPoint
                            local spread=WT.utils.randomInCircle({x=0,y=0},self.mission.spread)
                            baseline.x=baseline.x+spread.x
                            baseline.y=baseline.y+spread.y
                            local target={x=baseline.x+self.mission.adjustments.x,y=baseline.y+self.mission.adjustments.y}
                            local variance_dist=(math.random() * 2 - 1)*self.mission.variance.distance
                            local variance_lat=(math.random() * 2 - 1)*self.mission.variance.lateral
                            local target={x=target.x+self.mission.variance.lateral_vec.x*variance_lat+self.mission.variance.distance_vec.x*variance_dist,y=target.y+self.mission.variance.lateral_vec.y*variance_lat+self.mission.variance.distance_vec.y*variance_dist}
                            local travel_time=self.mission.range*self.battery.travelTime

                            if self.mission.roundType==WT.support.artillery.shells.HE then
                                timer.scheduleFunction(WT.utils.explodePoint,{target,200},timer.getTime()+travel_time)
                            elseif self.mission.roundType==WT.support.artillery.shells.ILLUM then
                                --TODO: schedule illumination
                            end
                            if self.rounds>0 then
                                return time+self.battery.skill.timeBetweenRounds+((math.random() * 2) - 1)
                            end
                            return true
                        else
                            return false
                        end
                    end
                }
                self.guns[#self.guns+1]=gun
            end,

            removeGun=function(self)
                self.guns[#self.guns]=nil
            end,

            createMission = function(self, targetPoint)
               
                local mission = {
                    battery = self,
                    targetPoint = {}
                    variance={}
                    rounds = {},
                    range = 0,
                    adjustments = {x = 0, y = 0},
                    
                    roundType = WT.support.artillery.shells.HE,
                    spread = 100,
                    
                    -- Mission methods
                    setRoundType = function(self, roundType)
                        self.roundType = roundType
                    end,

                    setSpread = function(self, spread)
                        self.spread = spread
                    end,
                    
                    setTargetPoint = function(self, targetPoint)
                        self.targetPoint = targetPoint

                        self.range=WT.utils.getDistance(self.position,targetPoint)
                        local variance_dist=self.range*self.BatteryEra.distance
                        if variance_dist<self.BatteryEra.minimum then
                            variance_dist=self.BatteryEra.minimum
                        end
                        local variance_lat=self.range*self.BatteryEra.lateral
                        if variance_lat<self.BatteryEra.minimum then
                            variance_lat=self.BatteryEra.minimum
                        end
                        
                        -- Calculate unit vectors for distance (along battery-to-target line) and lateral (perpendicular)
                        local dx = targetPoint.x - self.position.x
                        local dy = targetPoint.y - self.position.y
                        local angle = math.atan2(dy, dx)
        
                        -- Distance unit vector (along battery-to-target line)
                        local distance_vector = {
                            x = math.cos(angle),
                            y = math.sin(angle)
                        }
        
                        -- Lateral unit vector (perpendicular, 90 degrees clockwise)
                        local lateral_vector = {
                            x = math.cos(angle + math.pi/2),
                            y = math.sin(angle + math.pi/2)
                        }        
                        self.variance{
                            lateral_vec=lateral_vector,
                            distance_vec=distance_vector,
                            distance=variance_dist,
                            lateral=variance_lat
                        }
                        local initialError=WT.utils.randomInCircle({x=0,y=0},self.battery.skill.initialError)
                        self.adjustments.x=self.adjustments.x+initialError.x
                        self.adjustments.y=self.adjustments.y+initialError.y
                    end,
                }
                
                mission:setTargetPoint(targetPoint)
                self.missions[#self.missions + 1] = mission
                return mission
            end,

            adjustRange=function(self,adjustment)
                -- Convert range adjustment into x,y vector based on angle from source to target
                local dx = self.activeMission.targetPoint.x - self.position.x
                local dz = self.activeMission.targetPoint.y - self.position.y
                local angle = math.atan2(dz, dx)
                local adjustX = adjustment * math.cos(angle)
                local adjustY = adjustment * math.sin(angle)
                
                self.activeMission.adjustments.x = self.activeMission.adjustments.x + adjustX
                self.activeMission.adjustments.y = self.activeMission.adjustments.y + adjustY
            end,

            adjustAzimuth=function(self,adjustment)
                -- Convert azimuth adjustment into x,y vector based on angle from source to target
                local dx = self.activeMission.targetPoint.x - self.activeMission.position.x
                local dz = self.activeMission.targetPoint.y - self.activeMission.position.y
                local angle = math.atan2(dz, dx)
                local adjustX = adjustment * math.cos(angle + math.pi/2)
                local adjustY = adjustment * math.sin(angle + math.pi/2)
                
                self.activeMission.adjustments.x = self.activeMission.adjustments.x + adjustX
                self.activeMission.adjustments.y = self.activeMission.adjustments.y + adjustY
            end,

            checkMissionReady=function(self)
                if self.activeMission then
                    if self.activeMission.targetPoint=={} then
                        return false
                    end
                    if self.activeMission.rounds=={} then
                        return false
                    end
                    if self.activeMission.range==0 then
                        return false
                    end
                    if self.activeMission.range > self.range and self.range>0 then
                        return false
                    end
                else
                    return false
                end
                return true
            end,

            beginFireMission=function(self)
                if self.firing==false then
                    self.roundCount = rounds
                    self.firing = true
                    local gunCount=#self.guns
                    local currentGun=1
                    local rounds=self.activeMission.rounds
                    for r=1,rounds do
                        if currentGun>gunCount then
                            currentGun=1
                        end
                        self.guns[currentGun]:addRound()
                        currentGun=currentGun+1
                    end
                    
                else
                    return false
                end
            end

            fire=function(self)
                return
            end
        }
        WT.support.artillery[name]=battery
        return battery
    end

    function WT.support.newCASTemplate(groupName,name)
        local CASTemplate={
            name=name,
            groupName=groupName,
        }
        WT.support.cas[name]=CASTemplate
        return CASTemplate

    end



end