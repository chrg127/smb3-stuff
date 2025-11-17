local smwMap = require "smwMap"

local npcID = NPC_ID

smwMap.blockingObjID = npcID

smwMap.setObjConfig(npcID, {
    isBlocking = true,
    isBreakable = true,

    onTickObj = function(v)
        if smwMap.isLevelBeaten(v.settings.levelFilename) then
            v:remove()
        end
    end,
})

return {}
