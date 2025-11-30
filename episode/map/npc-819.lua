local smwMap = require("smwMap")

local npcID = NPC_ID

local function spawnAirship(v, savedData, pos)
    savedData.airshipPos = pos
    local airship = smwMap.createObject(770, pos.x, pos.y, nil, savedData.airshipIndex)
    airship.castleIndex = v.data.index
    airship.settings = {
        destinationWarpName = v.settings.destinationWarpName,
        levelFilename = v.settings.levelFilename,
        warpIndex = v.settings.warpIndex,
        exitWarpIndex = v.settings.exitWarpIndex,
        canWalkOn = 3,
        movesWhen = 2,
    }

    v.data.airshipSpawned = true
    v.settings.levelFilename = nil
    savedData.airshipIndex = airship.data.index
end

smwMap.setObjConfig(npcID, {
    framesY = 1,
    isLevel = true,

    onInitObj = function (v)
        if SaveData.smwMap.objectData[v.data.index] == nil then
            SaveData.smwMap.objectData[v.data.index] = {}
        end

        local savedData = SaveData.smwMap.objectData[v.data.index]
        if savedData.airshipPos ~= nil then
            spawnAirship(v, savedData, savedData.airshipPos)
        end

        v.frameY = 0
    end,

    onTickObj = function(v)
        if not v.data.airshipSpawned and smwMap.hasPlayerJustLost(v) then
            local savedData = SaveData.smwMap.objectData[v.data.index]
            spawnAirship(v, savedData, vector(v.x, v.y))
        end
    end,
})

return {}
