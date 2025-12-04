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
                    local target = smwMap.getRandomLevelInArea(nil, {
                        types = smwMap.FIND_TYPES.STOP_POINTS_ONLY,
                        visitedOnly = false,
                    })
                    if target ~= nil then
                        o.originalPos = vector(o.x, o.y)
                        o.target = target
                        o.timer = 0
                        o.data.direction = o.target.x < o.x and DIR_LEFT or DIR_RIGHT
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
    -- isLevel = true,
    isEncounter = true,
    -- usePositionBasedPriority = true,

    onInitObj = function (v)
        -- in case the airship is used as a standalone encounter
        -- and not spawned from a castle
        v.timer = flyingTime + 20 - 1
    end,

    onTickObj = function (v)
        v.timer = v.timer + 1
        v.priority = -10

        if v.timer < flyingTime then
            v.x = math.lerp(v.originalPos.x, v.target.x, v.timer / flyingTime)
            v.y = math.lerp(v.originalPos.y, v.target.y, v.timer / flyingTime)
        elseif v.timer == flyingTime then
            v.x = v.target.x
            v.y = v.target.y
            v.data.levelObj = v.target
        elseif v.timer == flyingTime + 20 then
            v.data.direction = DIR_RIGHT
            if v.castleIndex ~= nil then
                SaveData.smwMap.objectData[v.castleIndex].airshipPos = vector(v.x, v.y)
                SaveData.smwMap.objectData[v.data.index].x = v.x
                SaveData.smwMap.objectData[v.data.index].y = v.y
            end
        end

        local totalFrames = smwMap.getObjectConfig(v.id).framesY
        v.frameY = smwMap.doBasicAnimation(v, totalFrames / 2, 16)
        if v.data.direction == DIR_RIGHT then
            v.frameY = v.frameY + totalFrames / 2
        end
    end,
})

return {}
