local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjSettings(npcID, {
    framesY = 1,
    isLevel = true,
    hasDestroyedAnimation = true,
    isBonusLevel = true,

    onTickObj = function (v)
        local totalFrames = smwMap.getObjectConfig(v.id).framesY
        v.frameY = smwMap.doBasicAnimation(v, totalFrames - 1, 8)
    end,
})

return {}
