local smwMap = require "smwMap"

local npcID = NPC_ID

smwMap.setObjConfig(npcID, {
    isBlocking = true,
    isBreakable = true,

    onTickObj = function(v)
    end,
})

return {}
