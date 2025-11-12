local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    framesY = 6,
    gfxoffsety = 0,
    usePositionBasedPriority = true,
    isEncounter = true,

    onTickObj = function(v)
        if v.data.state == smwMap.ENCOUNTER_STATE.NORMAL then
            if #smwMap.activeEvents > 0 then
                v.graphicsOffsetX = 0
            else
                v.graphicsOffsetX = v.graphicsOffsetX + v.data.direction*0.5
            end
            if v.graphicsOffsetX*v.data.direction >= smwMap.encounterSettings.idleWanderDistance then
                v.data.direction = -v.data.direction
            end
            v.data.animationSpeed = 1
        elseif v.data.state == smwMap.ENCOUNTER_STATE.WALKING then
            v.graphicsOffsetX = 0
            v.data.animationSpeed = 4
        elseif v.data.state == smwMap.ENCOUNTER_STATE.DEFEATED then
            v.data.animationSpeed = 4
        end


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
