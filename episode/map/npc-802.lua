local smwMap = require("smwMap")

local npcID = NPC_ID
local baseLevelFrames = 4

smwMap.setObjConfig(npcID, {
    framesY = 12,
    isLevel = true,
    hasBeatenAnimation = true,

    onTickObj = function(v)
        if SaveData.smwMap.beatenLevels[v.settings.levelFilename] then
            v.frameY = baseLevelFrames
                     + (smwMap.isLevelCompletelyBeaten(v) and 0 or smwMap.playerSettings.numSupported)
                     + SaveData.smwMap.beatenLevels[v.settings.levelFilename].character - 1
        else
            v.frameY = smwMap.doBasicAnimation(v, baseLevelFrames, 16)
        end
    end,
})

return {}
