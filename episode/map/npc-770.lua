local smwMap = require("smwMap")

local npcID = NPC_ID

local airshipMovingSound = SFX.open(Misc.resolveSoundFile("smwMap/boss-death"))
local flyingTime = 75
local standStillTime = 20

table.insert(smwMap.postLevelBeatenFunctions, 1, function (level, winType)
    if winType ~= LEVEL_WIN_TYPE_NONE then
        return
    end

    table.insert(smwMap.activeEvents, {
        type = smwMap.EVENT_TYPE.CUSTOM,
        run = function (event)
            if event.timer ~= nil then
                event.timer = event.timer + 1
                if event.timer == flyingTime + standStillTime then
                    table.remove(smwMap.activeEvents, 1)
                end

                return
            end

            -- check if there are any airships and begin moving them
            local found = false
            for _, o in ipairs(smwMap.objects) do
                if o.id == npcID then
                    found = true
                    local target = smwMap.getRandomLevelPositionInArea(nil, {
                        types = smwMap.FIND_TYPES.STOP_POINTS_ONLY,
                        visitedOnly = false,
                    })
                    if target ~= nil then
                        o.originalPos = vector(o.x, o.y)
                        o.targetPos = target
                        o.timer = 0
                        o.data.direction = o.targetPos.x < o.x and DIR_LEFT or DIR_RIGHT
                        SFX.play(airshipMovingSound)
                    end
                end
            end

            if found then
                event.timer = 0
            else
                table.remove(smwMap.activeEvents, 1)
            end
        end
    })
end)

smwMap.setObjConfig(npcID, {
    framesY = 4,
    isLevel = true,
    isEncounter = true,
    usePositionBasedPriority = true,

    onInitObj = function (v)
        v.timer = flyingTime + 20 - 1
    end,

    onTickObj = function (v)
        v.timer = v.timer + 1

        if v.timer == 102 then
        end

        if v.timer < flyingTime then
            v.x = math.lerp(v.originalPos.x, v.targetPos.x, v.timer / flyingTime)
            v.y = math.lerp(v.originalPos.y, v.targetPos.y, v.timer / flyingTime)
        elseif v.timer == flyingTime then
            v.x = v.targetPos.x
            v.y = v.targetPos.y
        elseif v.timer == flyingTime + 20 then
            v.data.direction = DIR_RIGHT
            SaveData.smwMap.objectData[v.castleIndex].airshipPos = vector(v.x, v.y)
            SaveData.smwMap.objectData[v.data.index].x = v.x
            SaveData.smwMap.objectData[v.data.index].y = v.y
        end

        local totalFrames = smwMap.getObjectConfig(v.id).framesY
        v.frameY = smwMap.doBasicAnimation(v, totalFrames / 2, 16)
        if v.data.direction == DIR_RIGHT then
            v.frameY = v.frameY + totalFrames / 2
        end
    end,
})

return {}
