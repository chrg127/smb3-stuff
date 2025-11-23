local smwMap = require "smwMap"

local npcID = NPC_ID

smwMap.setObjConfig(npcID, {
    framesY = 2,
    isBlocking = true,
    canBeOpened = true,

    onInitObj = function (v)
        if SaveData.smwMap.objectData[v.data.index] == nil then
            SaveData.smwMap.objectData[v.data.index] = {
                isOpen = v.settings.isOpen
            }
        end

        v.isOpen = SaveData.smwMap.objectData[v.data.index].isOpen
    end,

    onTickObj = function(v)
        v.frameY = v.isOpen and 0 or 1
    end,
})

return {}
