local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.twisterID = npcID

smwMap.setObjConfig(npcID, {
    framesY = 2,
    priority = -10,

    onTickObj = function (v)
        v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(v.id).framesY, 16)
        v.x = v.x - 4

        if v.x + 32 < smwMap.camera.x then
            if v.isComing then
                local mid = function ()
                    -- create a fake level obj
                    local levelObj = {
                        settings = {},
                    }
                    smwMap.warpPlayer(smwMap.mainPlayer, levelObj, smwMap.areas.name.whistleWarpName)
                    Audio.MusicPlay()
                    local x, y = smwMap.getUsualCameraPos()
                    local obj = smwMap.createObject(smwMap.twisterID, x + smwMap.camera.width, smwMap.mainPlayer.y)
                    obj.isComing = false
                    smwMap.addTwister(obj)
                    v:remove()
                end
                smwMap.startTransition(mid, nil, smwMap.transitionSettings.whistleWarp)
            else
                smwMap.removeTwister()
                v:remove()
            end
        end
    end
})

return {}

