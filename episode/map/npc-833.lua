local smwMap = require "smwMap"

local npcID = NPC_ID

table.insert(smwMap.postLevelBeatenFunctions, function (level, winType)
    if smwMap.getObjectConfig(level.id).isBonusLevel then
        return
    end

    table.insert(smwMap.activeEvents, {
        type = smwMap.EVENT_TYPE.CUSTOM,
        run = function (event)
            for _, o in ipairs(smwMap.objects) do
                -- also check if it is in the current camera area
                if o.id == npcID and o.settings.changesStateWhen == 0 then
                    o.isOpen = not o.isOpen
                end
            end
            table.remove(smwMap.activeEvents, 1)
        end
    })
end)

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
