# WirtsTools
WirtsTools is a amalgamation of various little functions and features that I have built to assist in my DCS mission making, and previously have shared amongst Border Zone

## Contents
*   [Disclaimer](#disclaimer)
*   [How to use](#how-to-use)
*   [Features](#features)
    *   [Weapon Features](#weapon-features)
        *   [Weapon Impact In Zone](#weapon-impact-in-zone)
        *   [Weapon Impact Near](#weapon-impact-near)
	    *   [Weapon Near](#weapon-near)
	    *   [Weapon in Zone](#weapon-in-zone)
        *   [Weapon Hit](#weapon-hit)
    *   [Pop Flare](#pop-flare)
    *   [Player Near](#player-near)
    *   [Cover Me](#cover-me)
    *   [Invis Alt](#invis-alt)
    *   [Suppression](#suppression)
    *   [Missile Death](#missile-death)
    *   [Kill Switch](#kill-switch)
    *   [Tasking](#tasking)
    *   [Stormtrooper AA](#stormtrooper-aa)
    *   [Shelling](#shelling)
    *   [MLRS](#mlrs)
    *   [Percent Alive](#percent-alive)
    *   [Ejection Cleanup](#ejection-cleanup)
    *   [IR Strobe](#ir-strobe)

## Disclaimer
Note that this script is provided as is with no guarantee of function nor promise of support, use at your own risk

## How to use
Simply run the script with a triggered "Do Script File" then call the relevant setup functions in a "Do Script" for the features you wish to use

## Features

### Weapon Features
Starting in version 2.2.0 WirtsTools includes a specific grouping of features under `WT.weapon`, these for now are generally features that set flag values based on weapon behaviour (weapon impacts the ground in a zone, or gets near a unit etc). Note some other features may get moved in here to use the filter system eventually (like Missile Death)

These features all use a common filter system to define the weapon types you are interested in. So to get started with any of these features you need to start with defining a filter.
```lua
local filter=WT.weapon.newFilter() -- create a new filter and save it to a local variable 'filter'
```
To start the filter is empty, this will match on every weapon fired, you may want that, but you also may not, to get mroe specific we add terms to the filter

Terms are basically requirements any weapon must meet to pass the filter and can be made for a few different properties of the weapon, these are
*   Name: The typename of the weapon, basically be very explicit and only match a specific weapon
*   Coalition: The side the weapon belongs to (fired by a red, blue or neutral unit), defined as coalition.side.NEUTRAL, coalition.side.BLUE, or coalition.side.RED
*   Category: The weapon's category (Shell, Missile, Rocket, Bomb, or Torpedo) 
*   GuidanceType: How is the weapon guided (if it is), options include INS, IR, RADAR_ACTIVE and so on
*   MissileCategory: Specific missile category (AAM, SAM, ANTI_SHIP, etc) note that not all missiles in DCS are properly categorized, for example the harpoon is categorized as Weapon.MissileCategory.OTHER instead of Weapon.MissileCategory.ANTI_SHIP
*   WarheadType: AP, HE, or SHAPED_EXPLOSIVE

You can create any number of terms for each property, and you can create negative terms as well. The evaluation logic is such that for any given property if there are any positive terms then atleast one of them MUST match, and if there are any negative terms they must all be satisfied

So for example if Category terms include Weapon.Category.BOMB and Weapon.Category.MISSILE as positive terms then that will match on bombs or missiles, conversly if Warhead Type includes Weapon.WarheadType.AP and Weapon.WarheadType.HE as negative terms then weapons with AP or HE warheads will not be accepted by the filter

Note for exact enum values to use see [here](https://wiki.hoggitworld.com/view/DCS_enum_weapon)

Finally to debug or otherwise figure out the values for a specific weapon including name run `WT.weapon.Debug()` that will turn on debugging output that will, among other things, print weapon details out to the screen when you fire a weapon

Ok now how to actually add those terms to the filter, to start we created a filter with

```lua
local filter=WT.weapon.newFilter()
```
Now lets look at the addTerm() function

self<filter>: this just means it takes a filter object, the way you will be calling it you wont have to worry about this argument
field<string>: This is the field name for example Category as a string (possible values are "Name", "Coalition", "Category", "GuidanceType", "MissileCategory", and "WarheadType")
term<int/enum>: This is the value you are looking to match or negate, you can put a integer value like 1, 2, 3, etc as that is what the enumerators technically are, or you can use something like Weapon.Category.MISSILE (I prefer this for readability)
match<bool>: This tells the function if you want to match or negate for this term, if set to true then it will match, if false it will negate, if you dont inclue it this will default to true 
```lua
WT.weapon.filter.addTerm(self,field,term,match)
```
ok in practice then to add a term we call addTerm() on the filter we created like so
```lua
filter:addTerm("Categry",Weapon.Categroy.MISSILE,true) --this adds a term to the filter that will match weapons of category missile
filter:addTerm("GuidanceType",Weapon.GuidanceType.IR,false) --ok the second term we added negates anything guided via IR
```

Note when defining these filters you can take a few different approaches, the example used above creates a local variable to hold the filter, so it exists within the scope of the "do script" action you are running it in, this si good for single use approach, defione the filter and immediately pass it to a function

However if you plan to use the samne terms for multiple filters/functions you could take an approach like this

```lua
myFilters={}

myFilters.missiles_not_ir = WT.weapon.newFilter()
myFilters.missiles_not_ir:addTerm("Categry",Weapon.Categroy.MISSILE,true)
myFilters.missiles_not_ir:addTerm("GuidanceType",Weapon.GuidanceType.IR,false)

myFilters.bombs = WT.weapon.newFilter()
myFilters.bombs:addTerm("Categry",Weapon.Categroy.BOMB,true)
```
Now you have a global table with those filters in it, you can access those filters at any time in other doScript triggers or elsewhere with `myFilters.missiles_not_ir` and `myFilters.bombs`

That being said for simplicity in documentation examples going forward will assume taking the local approach with a filter simply named filter, but in those examples you would simply swap in `myFilers.filtername` to use a global filter


So now we have a filter that will match any missile that isn't guided via IR, lets do something with it....

All weapon features work similarly, they take a filter and some other arguments and then will set a flag based on those values. Note that all instances you create are only self-aware, they do not take into account OTHER instances, so if you use the same flag value in more than one instance behaviour will be odd at best

All instances also have two functions for control that can be called on them, activate() and deactivate(), if you deactivate an instance the matching logic will stop being applied and all flags/background counters etc will be reset to 0

To be able to activate/deactivate you need to save a reference to the instance SO for example with a impactInZone instance you do the following

```lua
impactInstance = WT.weapon.inZone(filter,"ZoneName","flagName")
```
more details on this function below but here ive created an instance and saved it to a global variable, you could also take an approach similar to the filter table above and define `myInstances = {}` and do this
```lua
myInstances.impactInstance = WT.weapon.impactInZone(filter,"ZoneName","flagName")
```
Then to deactivate or activate you simply do
```lua
impactInstance:deactivate()
```
or
```lua
impactInstance:activate()
```
note that all instances default activated at time of creation.

A final point on performance, I did a lot to minimize impact, and indeed you should be run a lot of these features at once (or many instances) without issue, but one of the performance considerations means that any instances created will NOT detect/fire on weapons that were already in flight at time of the instance being created

Right ok, lets talk the actual instance types....

### Weapon Impact in Zone
This feature is designed to detect when a weapon impacts the ground in a zone, (note that for performance reasons impact is defined as the weapon being destroyed within 15meters of the ground).

This works with both poly and circular zones, and will increment a flag with each weapon impact in the zone that matches the filter

filter<WT.weapon.filter>: Pass it a filter 
zone<String>: name of the zone
flag<String>: name of the flag to use
```lua
WT.weapon.impactInZone(filter,zone,flag)
```
example assuming we have a defined filter named filter
```lua
WT.weapon.impactInZone(filter,"impact_zone","impactCounter")
```
this will increment a flag called "impactCounter" with each impact in a zone called "impact_zone" that matches the defined filter

### Weapon Impact Near
This feature is designed to detect when a weapon impacts the ground near a unit or group, (note that for performance reasons impact is defined as the weapon being destroyed within 15meters of the ground).

This will increment a flag with each weapon impact within a deifned range of either a single unit, or any unit in a group, that matches the defined filter

target<String>: Name of a unit or group, the function first looks for a unit with this name, if none found it will look for a group with that name.
filter<WT.weapon.filter>: Pass it a filter 
range<Integer>: distance in meters th eimpact must be within to trigger
flag<String>: name of the flag to use
```lua
WT.weapon.impactNear(target,filter,range,flag)
```
example assuming we have a defined filter named filter
```lua
WT.weapon.impactNear("badGuy-1",filter,100,"impactCounter")
```
this will increment a flag called "impactCounter" with each impact within 100 meters of any unit in the group named "badGuy-1" which match the provided filter

### Weapon Near
This feature is designed to detect when a weapon flies near a target

This will set a flag based on the amount of weapons currently within a given range from target, it accepts groups or units but for performance reasons when using a group it only uses the group leader for checks

target<String>: Name of a unit or group, the function first looks for a unit with this name, if none found it will look for a group with that name.
filter<WT.weapon.filter>: Pass it a filter 
range<Integer>: distance in meters th eimpact must be within to trigger
flag<String>: name of the flag to use
```lua
WT.weapon.near(target,filter,range,flag)
```
Example assuming we have a defined filter named filter
```lua
WT.weapon.near("badGuy-1",filter,500,"weaponsNear")
```
this will keep a flag called "weaponsNear" set to a count of the amount of weapons within 500 meters of the leader of the group named "badGuy-1" which match the provided filter

### Weapon in Zone
This feature is designed to detect weapons in a zone

This will set a flag based on the amount of weapons currently within a given zone

filter<WT.weapon.filter>: Pass it a filter 
zone<String>: Name of zone to use
flag<String>: name of the flag to use
```lua
WT.weapon.inZone(filter,zone,flag)
```
Example assuming we have a defined filter named filter
```lua
WT.weapon.inZone(filter,"ADIZ_1","weaponsInADIZ")
```
This will keep a flag called "weaponsInADIZ" set to a count of the amount of weapons within a zone called "ADIZ_1"

### Weapon Hit
This feature is designed increment a flag for each time a weapon hits a given target

This is really designed for very large targets like ships where impactNear with a very small distance isnt appropriate as a proxy for a hit

Note that the hit event is extremely unrealiable in multiplayer, especially for player units, in my experience it does work ok for AI ships and such but YMMV, ensure you thoroughly test with this one before using it in multiplayer

it will increment the provided flag for each hit on the target unit

target<String>: unit name
filter<WT.weapon.filter>: Pass it a filter 
flag<String>: name of the flag to use
```lua
WT.weapon.hit(target,filter,flag)
```
Example assuming we have a defined filter named filter
```lua
WT.weapon.hit("BadShip-1",filter,"hits_on_ship")
```
This will increment a flag called "hits_on_ship" for each weapon that hits the unit named "BadShip-1" which passes the provided filter

### Pop Flare
This is a simple script that will give your players a F10 option to fire a signal flare (choosing a colour), init function is
```lua
WT.popFlare.setup(side)
```
side\<number>: Which side to apply to, use 1 for redfor, 2 for blufor  
run multiple times if you want it to work for both sides
### Player Near
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

### Cover Me
renders players invisible when there is a allied AI aircraft within a defined range of the player
```lua
WT.coverMe.setup(group,coalition,distance)
```
group\<string>: group that is covered by AI (1 or 2 for all player redfor or player blufor respectively)  
coalition\<number>: coalition of AI players you want to be able to provide cover  
distance\<number>: distance in meters they must be within to be covered  

### Invis Alt
Toggles invisibility when units go below a given AGL, note that since invis is at a group level this
only works properly when each unit is in a group of 1
```lua
WT.invisAlt.setup(alt,side)
```
alt\<number>: altitude (AGL) below which a group should be invisible  
side\<number>: coalition enum (1 for red or 2 for blue) will apply to all players on that side  

### Suppression
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

### Missile Death  
simple function that makes sure that any unit hit by a missile dies (good for time rtavel missions, warbirds are weirdly resilient to missiles)
```lua
WT.missileDeath.setup()
```

### Kill Switch  
For multiplayer missions its nice to have F10 radio options as backups/killswitches so you can salavage the mission if something breaks or say for example SEAD fligth all crash, but its not great when those options are exposed to 30 curious pilots fiddling in the radio menu or people that use VAICOM and thus constantly randomly trigger every possible radio option

This function lets you assign radio options based on player name, they will be added/removed to/from groups as needed so that ONLY a group containing a player whose name contains a given string have those options
```lua
WT.killswitch.setup(player,name,flag,singleUse)
```

player\<string>: subname of the player (eg maple if the player's name will for sure contain maple)  
name\<string>: name of the radio option  
flag\<string>: flag to set when pressed  
singleUse\<bool>: true makes the option disappear once used
  
### Tasking  
Call when you want to drop a new mission into a group, designed to have taskings defined via late activation groups you never activate
```lua
WT.tasking.task(group,task,relative)
```
group\<string>: name of the group you want to task  
task\<string>: name of the group whose tasking you want to clone (must start with 'TASK_')
relative\<boolean>:  whether you want the task waypoints to be shifted so the path is the same shape as defined but starting where the group is (true), or keep tasking waypoints in defined locations (false)   
  
### Stormtrooper AA  
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
  
### Shelling  
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

### Percent Alive  
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

### Ejection Cleanup
Simple feature that deletes 50% of ejected pilots immediately and the rest after a minute  
Example:  
```lua
WT.eject.init()
```  

### IR Strobe
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
