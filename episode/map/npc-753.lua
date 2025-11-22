local smwMap = require("smwMap")

local npcID = NPC_ID

local function getMusic(settings)
    if settings.music == 0 then -- don't change
        return nil
    elseif settings.music == 1 then -- none
        return 0
    elseif settings.music == 2 then -- custom
        return settings.customMusicPath
    else -- some other songs
        return settings.music - 2
    end
end

smwMap.setObjConfig(npcID,{
    hidden = true,

    onInitObj = function(v)
        table.insert(smwMap.areas, {
            name1 = v.settings.name1,
            name2 = v.settings.name2,
            name1hud = v.settings.name1hud,
            name2hud = v.settings.name2hud,
            enableWorldCard = v.settings.enableWorldCard,
            collider = Colliders.Box(v.x - v.width*0.5,v.y - v.height*0.5,v.settings.width,v.settings.height),
            restrictCamera = v.settings.restrictCamera,
            backgroundName  = v.settings.backgroundName,
            backgroundColor = v.settings.backgroundColor,
            music = getMusic(v.settings),
            areaEffect = v.settings.areaEffect,
            whistleWarpName = v.settings.whistleWarpName,
        })
        v:remove()
    end,
})

return {}
