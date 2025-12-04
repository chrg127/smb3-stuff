local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 4,
    usePositionBasedPriority = true,
    isEncounter = true,

    onTickObj = function(v)
        local totalFrames = smwMap.getObjectConfig(v.id).framesY
        v.frameY = smwMap.doBasicAnimation(v, 2, 8 / v.data.animationSpeed)
        if v.data.direction == DIR_RIGHT then
            v.frameY = v.frameY + totalFrames / 2
        end
    end,
})

return {}
