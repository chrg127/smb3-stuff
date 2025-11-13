local smwMap = require("smwMap")

local npcID = NPC_ID
local frameLength = 8

smwMap.scenerySmokeID = npcID

smwMap.setObjConfig(npcID, {
    framesY = 3,
    priority = -10,

    onTickObj = function (v)
        v.data.timer = (v.data.timer or 0) + 1
        v.frameY = math.floor(v.data.timer / frameLength)
        if (v.data.timer > frameLength * smwMap.getObjectConfig(npcID).framesY) then
            v:remove()
        end
    end
})

return {}

