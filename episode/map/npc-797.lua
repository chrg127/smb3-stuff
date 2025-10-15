local smwMap = require("smwMap")

local npcID = NPC_ID
local frameLength = 8
local lifetime = 3 * frameLength

smwMap.setObjSettings(npcID, {
    framesX = 1,
    framesY = 3,

    onTickObj = function (v)
        v.data.timer = (v.data.timer or 0) + 1
        v.frameY = math.floor(v.data.timer / math.ceil(lifetime / 3))
        if (v.data.timer > lifetime) then
            v:remove()
        end
    end
})

return {}
