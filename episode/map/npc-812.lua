local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 4,
    isLevel = true,

    onTickObj = function(v)
        v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(v.id).framesY, 16)
    end,
})

return {}
