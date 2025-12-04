local smwMap = require("smwMap")

local npcID = NPC_ID

smwMap.setObjConfig(npcID,{
    hidden = true,

    onInitObj = function(v)
        if SaveData.smwMap.playerX ~= nil and SaveData.smwMap.playerY ~= nil then
            smwMap.mainPlayer.x = SaveData.smwMap.playerX
            smwMap.mainPlayer.y = SaveData.smwMap.playerY
        else
            smwMap.mainPlayer.x = v.x
            smwMap.mainPlayer.y = v.y
        end
        v:remove()
    end,
})

return {}
