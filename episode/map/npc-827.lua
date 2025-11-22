local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 1,
    isLevel = true,
    isWarp = true,

    onTickObj = (function(v)
        v.frameY = 0
    end),
})

return {}
