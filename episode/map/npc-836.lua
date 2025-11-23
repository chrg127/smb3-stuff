local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.oneUpEffectID = npcID

smwMap.setObjConfig(npcID, {
    framesY = 1,
    priority = -10,

    onTickObj = function (v)
        v.data.timer = (v.data.timer or 0) + 1
        v.y = v.y - 1
        if v.data.timer > 50 then
            v:remove()
        end
    end
})

return {}


