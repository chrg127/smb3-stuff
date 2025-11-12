local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 3,
    usePositionBasedPriority = true,
    isEncounter = true,

    onTickObj = function(v)
        if v.data.state == smwMap.ENCOUNTER_STATE.SLEEPING then
            v.frameY = 2
        else
            v.frameY = smwMap.doBasicAnimation(v, 2, 8 / v.data.animationSpeed)
        end
    end,
})

return {}
