local smwMap = require("smwMap")

local npcID = NPC_ID
smwMap.levelDestroyedSmokeEffectID = npcID

local lifetime = 32

smwMap.setObjSettings(npcID,{
    framesX = 1,
    framesY = 6,

    onTickObj = (function(v)
        v.data.timer = (v.data.timer or 0) + 1
        v.frameY = math.floor(v.data.timer / math.ceil(lifetime / 6))
        if (v.data.timer > lifetime) then
            v:remove()
        end
    end),
})



return {}
