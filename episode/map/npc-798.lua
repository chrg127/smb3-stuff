local smwMap = require("smwMap")

local npcID = NPC_ID
local frameLength = 8

smwMap.setObjConfig(npcID, {
    framesX = 1,
    framesY = 3,

    onTickObj = function (v)
        v.data.timer = (v.data.timer or 0) + 1
        v.frameY = math.floor(v.data.timer / frameLength)
        if (v.data.timer > frameLength * smwMap.getObjectConfig(npcID).framesY) then
            v:remove()
        end
    end
})

return {}

