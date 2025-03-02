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
        ["MARKER"]=1,
        ["CHAT"]=2,
        ["SMOKE"]=3
    }

    WT.support.target_point={
        x=0,
        y=0,
        z=0,
        radius=0,
        designation={}
        id=0,
        name=""
    }

    


end