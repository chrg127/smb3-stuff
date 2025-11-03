local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 6,
    gfxoffsety = 0,
    usePositionBasedPriority = true,
    isEncounter = true,

    onTickObj = function(v)
        -- Frames
        local totalFrames = smwMap.getObjectConfig(v.id).framesY

        if v.data.state ~= smwMap.ENCOUNTER_STATE.SLEEPING then
            v.frameY = smwMap.doBasicAnimation(v, (totalFrames*0.5) - 1, 16 / v.data.animationSpeed)
        else
            v.frameY = (totalFrames*0.5) - 1
        end

        if v.data.direction == DIR_RIGHT then
            v.frameY = v.frameY + totalFrames*0.5
        end
    end,
})

return {}
