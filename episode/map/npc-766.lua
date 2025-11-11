local smwMap = require "smwMap"

local npcID = NPC_ID

smwMap.boatID = npcID

smwMap.setObjConfig(npcID,{
    framesY = 2,
    gfxoffsety = 16,

    onTickEndObj = function(v)
        v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(v.id).framesY, 16)

        if v.x == smwMap.mainPlayer.x and v.y == smwMap.mainPlayer.y then
            v.isPlayerOnBoat = true
        end

        if v.isPlayerOnBoat and smwMap.mainPlayer.state == smwMap.PLAYER_STATE.WALKING then
            local level = smwMap.findLevel(smwMap.mainPlayer, smwMap.mainPlayer.x, smwMap.mainPlayer.y)
            if level ~= nil and smwMap.getObjectConfig(level.id).isBridge then
                v.isPlayerOnBoat = false
            end
        end

        if v.isPlayerOnBoat then
            v.x = smwMap.mainPlayer.x
            v.y = smwMap.mainPlayer.y
        end
    end,
})

return {}
