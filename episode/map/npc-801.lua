local smwMap = require("smwMap")

local npcID = NPC_ID
local baseLevelFrames = 4

local function anyEventOn(v)
    for _, e in ipairs(smwMap.activeEvents) do
        if e.levelObj == v then
            return true
        end
    end
    return false
end

smwMap.setObjSettings(npcID, {
    framesY = 12,
    isLevel = true,
    hasBeatenAnimation = true,

    onTickObj = function(v)
        if SaveData.smwMap.beatenLevels[v.settings.levelFilename] then --and not anyEventOn(v) then
            v.frameY = baseLevelFrames
                     + (smwMap.isLevelCompletelyBeaten(v) and 0 or smwMap.playerSettings.numSupported)
                     + SaveData.smwMap.beatenLevels[v.settings.levelFilename].character - 1
        else
            v.frameY = smwMap.doBasicAnimation(v, baseLevelFrames, 16)
        end
    end,
})

return {}
