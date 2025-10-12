local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjSettings(npcID,{
    framesY = 2,
    isLevel = true,
    hasDestroyedAnimation = true,

    onTickObj = function(v)
        local totalFrames = smwMap.getObjectConfig(v.id).framesY
        if v.levelDestroyed then
            v.frameY = (totalFrames - 1)
        else
            v.frameY = smwMap.doBasicAnimation(v,totalFrames - 1,8)
        end
    end,
})

return {}
