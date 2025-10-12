local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjSettings(npcID,{
    framesY = 5,
    isLevel = true,
    hasBeatenAnimation = true,

    onTickObj = function(v)
        if SaveData.smwMap.beatenLevels[v.settings.levelFilename] then
            v.frameY = 4
        else
            v.frameY = smwMap.doBasicAnimation(v, 4, 16)
        end
    end,
})

return {}
