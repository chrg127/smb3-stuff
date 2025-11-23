local smwMap = require "smwMap"

local npcID = NPC_ID

smwMap.boatID = npcID

smwMap.setObjConfig(npcID,{
    framesY = 2,
    gfxoffsety = 16,

    onInitObj = function (v)
        v.originalPos = vector(v.x, v.y)

        if SaveData.smwMap.objectData[v.data.index] == nil then
            SaveData.smwMap.objectData[v.data.index] = {
                x = v.x,
                y = v.y
            }
        end

        local savedPos = SaveData.smwMap.objectData[v.data.index]
        v.x = savedPos.x
        v.y = savedPos.y
    end,

    -- checking for whether to start attaching to the player must be done
    -- before moving the player, in order to attach when returning from a lost level
    onTickObj = function (v)
        if v.x == smwMap.mainPlayer.x and v.y == smwMap.mainPlayer.y then
            v.isPlayerOnBoat = true
        end
    end,

    -- checking for whether to stop attaching and updating position must be done after
    -- moving the player, to make sure the boat moves correctly with him and to disattach
    -- correctly when encountering a bridge
    onTickEndObj = function(v)
        v.frameY = smwMap.doBasicAnimation(v, smwMap.getObjectConfig(v.id).framesY, 16)

        if v.isPlayerOnBoat and smwMap.mainPlayer.state == smwMap.PLAYER_STATE.WALKING then
            local level = smwMap.findLevel(smwMap.mainPlayer, smwMap.mainPlayer.x, smwMap.mainPlayer.y)
            if level ~= nil and smwMap.getObjectConfig(level.id).isBridge then
                v.isPlayerOnBoat = false
            end
        elseif smwMap.mainPlayer.state == smwMap.PLAYER_STATE.GOING_BACK and not GameData.smwMap.lastLevelBeaten.isWaterTile then
            v.isPlayerOnBoat = false
            v.x = v.originalPos.x
            v.y = v.originalPos.y
        end

        if v.isPlayerOnBoat then
            v.x = smwMap.mainPlayer.x
            v.y = smwMap.mainPlayer.y
        end

        SaveData.smwMap.objectData[v.data.index] = {
            x = v.x,
            y = v.y,
        }
    end,
})

return {}
