local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 1,
    isWarp = true,

    onTickObj = function(v)
        v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(v.id).framesY, 6)
    end,
})

return {}
