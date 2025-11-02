local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID, {
    framesY = 1,
    isLevel = true,
    hasBeatenAnimation = true,

    onTickObj = function(v)
        if smwMap.isLevelBeaten(v) then
            v.textureOverride = smwMap.levelSettings.beatenTileImage
            v.framesYOverride = smwMap.levelSettings.beatenTileImage.height / 32
            v.frameY = (smwMap.isLevelCompletelyBeaten(v) and 0 or smwMap.playerSettings.numSupported)
                     + SaveData.smwMap.beatenLevels[v.settings.levelFilename].character - 1
        else
            v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(npcID).framesY, 16)
        end
    end,
})

return {}
