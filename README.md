# WirtsTools
WirtsTools is a amalgamation of various little functions and features that I have built to assist in my DCS mission making, and previously have shared amongst Border Zone

## Contents
*   [Disclaimer](#disclaimer)
*   [How to use](#how-to-use)
*   [Features](#features)
    *   [popFlare](#popflare)
    *   [impactInZone](#impactinzone)
    *   [impactNear](#impactnear)
    *   [playerNear](#playernear)
    *   [coverMe](#coverme)
    *   [invisAlt](#invisalt)
    *   [suppression](#suppression)
    *   [missileDeath](#missiledeath)
    *   [killSwitch](#killswitch)
    *   [tasking](#tasking)
    *   [stormtrooperAA](#stormtrooperaa)
    *   [shelling](#shelling)
    *   [MLRS](#MLRS)
    *   [percentAlive](#percentalive)
    *   [ejectionCleanup](#ejectioncleanup)
    *   [IRStrobe](#irstrobe)

## Disclaimer
Note that this script is provided as is with no guarantee of function nor promise of support, use at your own risk

## How to use
Simply run the script with a triggered "Do Script File" then call the relevant setup functions in a "Do Script" for the features you wish to use

## Features
### popFlare
This is a simple script that will give your players a F10 option to fire a signal flare (choosing a colour), init function is
```lua
WT.popFlare.setup(side)
```
side\<number>: Which side to apply to, use 1 for redfor, 2 for blufor  
run multiple times if you want it to work for both sides

### impactInZone
This will detect munition impact in a defined zone and increment a flag for each impact, setup function is
```lua
WT.impactInZone.setup(munition,zone,flag,help,debug)
```
munition\<string>: munition name  
zone\<string>: zone name  
flag\<string>: flag to increment  
help\<boolean>: for finding munition names, set to true then drop munitions to get a message with the back-end name  
debug\<boolean>: to get text debugging messages  
Examples:
```lua
WT.impactInZone.setup(nil,nil,nil,true,false) --for getting munition names
WT.impactInZone.setup("AN_M64","target-1","flag2",false,true) --for testing with debugging outputs (AN_M64 hitting in target-1 zone)
WT.impactInZone.setup("AN_M64","target-1","flag2",false,false) --for actual mission use (no text outputs)
WT.impactInZone.setup(nil,"target-1","flag2",false,false) --to function on all weapons of category "bomb" or "rocket"
```

### impactNear
Increments a flag when a munition lands near a unit or any unit in a group  
munition\<string>: munition name  
radius\<integer>: radius of circle around units to check for impacts (in meters)  
group\<string>: name of group to check for impacts near  
unit\<string>: name of unit to check for impacts near (if group has a value this will be ignored)  
flag\<string>: flag to increment  
Examples:  
```lua
WT.impactNear.setup("AN_M64",1000,"Group-1",nil,"flag1") --detect AN_M64 impacts within 1000meters of any member of Group-1, increment flag1 when you do
WT.impactNear.setup("AN_M64",1000,nil,"Group-1-1","flag2") --detect AN_M64 impacts within 1000meters of the unit named of Group-1-1, increment flag1 when you do
```

### playerNear
Increment a flag for every second that a player is within a defined distance of a defined AI group
```lua
WT.playerNear.setup(target_group,player_groups, flag, distance)
```
target_group\<string>: name of group you need to be near (in quotes)  
player_groups\<table/number>: a list in the form {"name1","name2",...}, set to 2 for all blue players or 1 for all red  
flag\<string>: flag name to increment when conditions met  
distance\<number>: distance in meters to operate within  
Examples
```lua
WT.playerNear.setup("target-1",2,"flag1",1000) --this will increment flag1 whenever any players are near the group target-1
WT.playerNear.setup("target-1",{"player"},"flag2",500) --this will increment the flag only when the specific given group is within range
```

### coverMe
renders players invisible when there is a allied AI aircraft within a defined range of the player
```lua
WT.coverMe.setup(group,coalition,distance)
```
group\<string>: group that is covered by AI (1 or 2 for all player redfor or player blufor respectively)  
coalition\<number>: coalition of AI players you want to be able to provide cover  
distance\<number>: distance in meters they must be within to be covered  

### invisAlt
Toggles invisibility when units go below a given AGL, note that since invis is at a group level this
only works properly when each unit is in a group of 1
```lua
WT.invisAlt.setup(alt,side)
```
alt\<number>: altitude (AGL) below which a group should be invisible  
side\<number>: coalition enum (1 for red or 2 for blue) will apply to all players on that side  

### suppression
suppresses ground units when they are shot at, not that it has no wway of knowing the current ROEs so if they are already weapons hold they will go weapons free when shot, after suppression ends as a result,is extremely basic, all hits work so yes infantry can suppress a tank, will iterate on later
```lua
WT.suppression.setup(hit,kill,all,side,ai)
```
hit\<number>: suuppression time on hit in seconds  
kill\<number>: suppression time on kill in seconds  
all\<boolean>: should we apply to all ground units or only those whose group name starts with SUP_  
side\<number>: 1 for red 2 for blue, nil for both  
ai\<boolean>: if false then suppression only happens when shot by a player unit  

Examples
```lua
WT.suppression.setup(2,5,true,1,false) --2 seconds suppression on hit, 5 on unit death, apply to all ground units, in red coalition, and only apply it if shot by a player
WT.suppression.setup(2,5,false,1,false) --2 seconds suppression on hit, 5 on unit death, apply to only ground units whose group name starts with SUP_, in red coalition, and only apply it if shot by a player
```

### missileDeath  
simple function that makes sure that any unit hit by a missile dies (good for time rtavel missions, warbirds are weirdly resilient to missiles)
```lua
WT.missileDeath.setup()
```

### killSwitch  
For multiplayer missions its nice to have F10 radio options as backups/killswitches so you can salavage the mission if something breaks or say for example SEAD fligth all crash, but its not great when those options are exposed to 30 curious pilots fiddling in the radio menu or people that use VAICOM and thus constantly randomly trigger every possible radio option

This function lets you assign radio options based on player name, they will be added/removed to/from groups as needed so that ONLY a group containing a player whose name contains a given string have those options
```lua
WT.killswitch.setup(player,name,flag,singleUse)
```

player\<string>: subname of the player (eg maple if the player's name will for sure contain maple)  
name\<string>: name of the radio option  
flag\<string>: flag to set when pressed  
singleUse\<bool>: true makes the option disappear once used
  
### tasking  
Call when you want to drop a new mission into a group, designed to have taskings defined via late activation groups you never activate
```lua
WT.tasking.task(group,task,relative)
```
group\<string>: name of the group you want to task  
task\<string>: name of the group whose tasking you want to clone (must start with 'TASK_')
relative\<boolean>:  whether you want the task waypoints to be shifted so the path is the same shape as defined but starting where the group is (true), or keep tasking waypoints in defined locations (false)   
  
### stormtrooperAA  
Makes designated AA units shoot in the vincinity of valid targets instead of at them, note that at this time there is a bug where units tasked to fire at point will ignore that order if there is a valid target nearby, meaning to use this properly for now your targets need to be invisible
```lua
WT.stormtrooperAA.setup(side,shooters,advancedLOS)
```
side\<number>: side of the expected targets (yes you can make blue shoot blue)  
shooters\<number>: side of the AA you wish to control (all AA must be group name starts with AA_)  
advancedLOS\<bool>: whether to factor in objects (statics, scenery, and other units) for LOS calculations
Example
```lua
WT.stormtrooperAA.setup(2,1,true) --will give red shooting blue using advanced LOS
```  
  
### shelling  
Like the vanilla shelling zone, but instead generates a sustained barrage within the target zone (only for circular zones)  
```lua
WT.shelling.setup(zone,rate,safe,flag)
```  
zone\<string>: name of the zone you want to shell  
rate\<number>: a number that when multiplied by a random value between 1 and 10 determines the delay between impacts, smaller number means faster barrage, try 0.03 to start  
safe\<number>: how many safe zones (zones that shouldn't be shelled) overlap your target zone, safe zones need to be named <zone>-safe-<number> starting at one, so for a target zone of 'target-1' the first safe zone would be 'target-1-safe-1'
flag\<string>: a flag to watch for and if set to true to stop the shelling  
Example  
```lua
WT.shelling.setup("target",0.03,1,"endit") --will shell the zone named target, with a 0.03 rate modifier, there is 1 safe zone and shelling will stop when the flag "endit" is set
```

### MLRS  
Deletes rockets/missiles from MLRS units while they are in flight so you can have the effect of them firing without tanking FPS from them impacting  
```lua
WT.MLRS.setup(groups)
```  
groups\<table>: table of the group names you want this to apply to, use nil for all MLRS units
Example  
```lua
WT.MLRS.setup({"SMERCH-1","SMERCH-2","SMERCH-3"}) --will function only when MLRS units in groups names SMERCH-1, SMERCH-2, or SMERCH-3 fire
WT.MLRS.setup(nil) --will function on all MLRS launches
```  

### percentAlive  
Updates a flag with the overal percent (0 - 100) of the units in the designated groups that are alive.  
```lua
WT.percentAlive.setup(groups,flag)
```  
groups\<table>: table of the group names you want this to apply to, use nil for all MLRS units  
flag\<string>: the name of the fag you want the alive status to be updated through  
Example  
```lua
WT.percentAlive.setup({"SMERCH-1","SMERCH-2","SMERCH-3"},"smerch_groups") --will update a flag called 'smerch_groups' based on the percentage of the those groups that are alive
```  

### EjectionCleanup
Simple feature that deletes 50% of ejected pilots immediately and the rest after a minute  
Example:  
```lua
WT.eject.init()
```  

### IRStrobe
Creates a blinking IR strobe on units  
groups\<string>\<group>: can be either a reference to a group table, or the name of the group as a string  
onoff\<boolean>: if true then sets the strobe on, if false sets it off, if nil then toggles it (on if currently off, off if currently on)  
interval\<number>: time interval that the ir light is on/off eg a interval of 1 would be 1 seond on then 1 second off, personally I find 0.15 or 0.2 works well (note overly long intervals will look strange)  
location\<Vec3>: the strobe is attached at this Vec3 point in model local coordinates, nil for a default strobe above the unit
Example:  
```lua
WT.strobe.toggleStrobe("infantry-1",true,0.2,nil) --will turn on a default strobe for a group named 'infantry-1' with a 0.2 second interval
WT.strobe.toggleStrobe("infantry-2",nil,0.2,nil) --will toggle a default strobe on/off for 'infantry-2' if turning on it will use a interval of 0.2 seconds
WT.strobe.toggleStrobe("Blackhawks",true,0.2,{x=-10.3,y=2.15,z=0}) --turn on strobes on top of the tail fins of all UH-60A Blackhawk units of the group
WT.strobe.toggleStrobe("Kiowas",true,0.2,{x=-6.85,y=1.8,z=0.14}) --turn on strobes on top of the tail fins of all OH-58D Kiowa Warrior units of the group
```
Final example is meant to be used in a "do script" advanced waypoint action
```lua
local grp = ... --this gets the current group
WT.strobe.toggleStrobe(grp,true,0.2,{x=-1,y=1,z=0}) --toggles on a strobe 1 meter above and 1 meter back to the local coordinate origin of each unit of the group in question
```
