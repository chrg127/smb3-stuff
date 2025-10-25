--[[
    smb3Map.lua v1.0
    by chrg
    forked from smwMap.lua v1.1 by MrDoubleA

    Default Graphics Credit:

    - Peach by AwesomeZack (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=31182)
    - Toad by GlacialSiren484 (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=37667)
]]

local smwMap = {}


-- Name of the level file that the map is on.
smwMap.levelFilename = "map.lvlx"


SaveData.smwMap = SaveData.smwMap or {}
local saveData = SaveData.smwMap
saveData.beatenLevels        = saveData.beatenLevels        or {}
saveData.encounterData       = saveData.encounterData       or {}
saveData.unlockedCheckpoints = saveData.unlockedCheckpoints or {}

GameData.smwMap = GameData.smwMap or {}
local gameData = GameData.smwMap
gameData.winType = gameData.winType or 0


-- Stuff to handle when not actually on the map
if Level.filename() ~= smwMap.levelFilename then
    gameData.winType = LEVEL_WIN_TYPE_NONE

    function smwMap.onInitAPI()
        registerEvent(smwMap,"onStart")
        registerEvent(smwMap,"onCheckpoint")
        registerEvent(smwMap,"onExitLevel")
    end

    function smwMap.onStart()
        Audio.MusicVolume(64)
    end

    function smwMap.onCheckpoint(c,_)
        saveData.unlockedCheckpoints[Level.filename()] = saveData.unlockedCheckpoints[Level.filename()] or {}
        saveData.unlockedCheckpoints[Level.filename()][c.idx] = true
    end

    function smwMap.onExitLevel(winType)
        gameData.winType = winType
    end

    return smwMap
end


local CHECKPOINT_PATH_ADDR = 0x00B250B0

local SCREEN_WIDTH = 800
local SCREEN_HEIGHT = 600


-- Debug thing: if true, an area's "restrict camera" setting won't do anything and the look around mode will always work.
smwMap.freeCamera = false
-- Debug thing: if true, disables the HUD and lets you see the entirety of the main buffer
smwMap.fullBufferView = false


local warpTransition
pcall(function() warpTransition = require("warpTransition") end)

local rooms
pcall(function() rooms = require("rooms") end)
if rooms ~= nil then
    rooms.dontPlayMusicThroughLua = true
end


local configFileReader = require("configFileReader")
local starcoin = require("npcs/ai/starcoin")
local textplus = require("textplus")


smwMap.playerSettings = {
    images = {
        [CHARACTER_MARIO] = Graphics.loadImageResolved("smwMap/player-mario.png"),
        [CHARACTER_LUIGI] = Graphics.loadImageResolved("smwMap/player-luigi.png"),
        [CHARACTER_PEACH] = Graphics.loadImageResolved("smwMap/player-peach.png"),
        [CHARACTER_TOAD ] = Graphics.loadImageResolved("smwMap/player-toad.png"),
    },

    shadowImage = Graphics.loadImageResolved("smwMap/shadow.png"),
    waterImage = Graphics.loadImageResolved("smwMap/water.png"),

    levelSelectedSound = SFX.open(Misc.resolveSoundFile("smwMap/levelSelected")),
    levelDestroyedSound = SFX.open(Misc.resolveSoundFile("smwMap/levelDestroyed")),
    switchBlockReleasedSound = SFX.open(Misc.resolveSoundFile("smwMap/switchBlockReleased")),


    canEnterDestroyedLevels = true,
    canEnterDestroyedBonusLevels = false,


    walkSpeed = 4,
    climbSpeed = 0.75, -- should be unused


    lookAroundArrowImage = Graphics.loadImageResolved("smwMap/lookAroundArrow.png"),
    lookAroundMoveSpeed = 4,


    framesX = 1,
    framesY = 4,

    bootFrames = 2,
    clownCarFrames = 2,
    yoshiFrames = 2,

    gfxYOffset = 0,
    mountOffsets = {
        [MOUNT_BOOT]     = -12,
        [MOUNT_CLOWNCAR] = -32,
        [MOUNT_YOSHI]    = -8,
    },

    numSupported = 4, -- mario, luigi, peach and toad
}


smwMap.pathSettings = {
    lockedColor = Color.fromHexRGBA(0x0000004E),

    unlockAnimationFrequency = 12,
    unlockAnimationDistance = 32,

    unlockLoopSound = SFX.open(Misc.resolveSoundFile("smwMap/unlock_loop")),
    unlockFinishSound = SFX.open(Misc.resolveSoundFile("smwMap/unlock_finish")),
    itemPanel = SFX.open(Misc.resolveSoundFile("smwMap/item-panel")),


    renderScale = 0.5,


    cullingPadding = 8,
}


smwMap.encounterSettings = {
    idleWanderDistance = 12,

    walkSpeed = 1,

    maxMovements = 6,
    keepWalkingChance = 3,

    movingSound = Misc.resolveSoundFile("smwMap/encountersMoving.wav"),
    enterSound = nil,
}


smwMap.hudSettings = {
    border = {
        enabled = true,
        image = Graphics.loadImageResolved("smwMap/hud_border.png"),
        rightWidth = 66,
        leftWidth = 66,
        topHeight = 96,
        bottomHeight = 96,
    },

    box = {
        image = Graphics.loadImageResolved("smwMap/hud.png"),
        x = 48,
        y = 528,
    },

    countersFont = textplus.loadFont("smwMap/smb3-font.ini"),

    levelTitle = {
        enabled = true,
        font = textplus.loadFont("smwMap/titleFont.ini"),
        x = 104,
        y = 26,
    },

    starcoin = {
        enabled = true,
        uncollectedImage = Graphics.loadImageResolved("hardcoded-51-0.png"),
        collectedImage = Graphics.loadImageResolved("hardcoded-51-1.png"),
        x = 456,
        y = 30,
    },

    playerIcon = {
        image = Graphics.loadImageResolved("smwMap/player-icons.png"),
        x = 8,
        y = 30,
    },

    worldName = {
        x = 8,
        y = 12
    },

    priority = 5,
}


smwMap.selectStartPointSettings = {
    -- If true, enables a small menu that allows you to select the checkpoint to start from when choosing a level
    enabled = false,

    beginningText = "Beginning",
    checkpointSingleText = "Checkpoint",
    checkpointMultipleText = "Checkpoint %d",

    textFont = textplus.loadFont("smwMap/levelTitleFont.ini"),
    textScale = 2,
    textColorSelected = Color(1,1,0.25),
    textColorUnselected = Color.white,

    backColor = Color.black.. 0.9,

    optionGap = 8,
    borderSize = 16,

    distanceFromPlayer = 32,

    priority = -5.15,
}


-- Find star coin counts
local function countStarCoinsInFile(filePath)
    local f = io.open(filePath,"r")

    if f == nil then -- I have no idea how the file wouldn't exist, but hey! better safe than sorry.
        return 0
    end

    local starcoinMap

    local isInNPCSection = false

    while (true) do
        local line = f:read("*l")

        if line == "NPC_END" or line == nil then -- after NPC_END we can just stop reading
            break
        end

        if isInNPCSection then
            -- Get some properties from the NPC
            local id = line:match("ID:(%d+);")

            if id == "310" then
                local special = tonumber(line:match("S1:(%d+);"))
                local friendly = line:match("FD:(%d+);")

                if (special ~= nil and special > 0) and (friendly == nil or friendly == "0") then
                    starcoinMap = starcoinMap or {}
                    starcoinMap[special] = true
                end
            end
        elseif line == "NPC" then -- the NPC section has started, so we can start actually checking for star coins now
            isInNPCSection = true
        end
    end

    f:close()


    if starcoinMap ~= nil then
        return #starcoinMap
    else
        return 0
    end
end

local function getStarCoinCounts()
    local episodePath = Misc.episodePath()
    local starcoinCounts = {}
    local levelCount = 0

    for _,filename in ipairs(Misc.listFiles(episodePath)) do
        if filename:sub(-5) == ".lvlx" then
            starcoinCounts[filename] = countStarCoinsInFile(episodePath.. filename)

            levelCount = levelCount + 1
        end
    end

    return starcoinCounts
end

gameData.starcoinCounts = getStarCoinCounts()


smwMap.camera = {
    x = 0,
    y = 0,

    width = 0,
    height = 0,

    offsetX = 0,
    offsetY = 0,
}


local function getUsualCameraPos()
    local x = smwMap.mainPlayer.x - smwMap.camera.width *0.5
    local y = smwMap.mainPlayer.y - smwMap.camera.height*0.5

    if smwMap.freeCamera then
        y = y + smwMap.mainPlayer.zOffset -- if using free camera, apply the Z offset, 'cause why not
    end

    -- Restrict the camera, if necessary
    local cameraArea = smwMap.currentCameraArea
    if cameraArea ~= nil and not smwMap.freeCamera then
        if cameraArea.collider.width >= smwMap.camera.width then -- the camera can fit here
            x = math.clamp(x,cameraArea.collider.x,cameraArea.collider.x + cameraArea.collider.width - smwMap.camera.width)
        else -- camera cannot fit in, so put it in the centre
            x = cameraArea.collider.x + cameraArea.collider.width*0.5 - smwMap.camera.width*0.5
        end

        if cameraArea.collider.height >= smwMap.camera.height then -- the camera can fit here
            y = math.clamp(y,cameraArea.collider.y,cameraArea.collider.y + cameraArea.collider.height - smwMap.camera.height)
        else -- camera cannot fit in, so put it in the centre
            y = cameraArea.collider.y + cameraArea.collider.height*0.5 - smwMap.camera.height*0.5
        end
    end

    return x,y
end


local function isNormalLevel(id)
    local config = smwMap.getObjectConfig(id)
    return (config.isLevel and not config.isWarp)
end

local function findLevel(v, x, y)
    for _,obj in ipairs(smwMap.getIntersectingObjects(x - v.width*0.5, y - v.height*0.5, x + v.width*0.5, y + v.height*0.5)) do
        if smwMap.getObjectConfig(obj.id).isLevel then
            return obj
        end
    end
    return nil
end

local function findBlockingObj(v, x, y)
    for _,obj in ipairs(smwMap.getIntersectingObjects(x - v.width*0.5, y - v.height*0.5, x + v.width*0.5, y + v.height*0.5)) do
        if obj.id == smwMap.blockingObjID then
            return obj
        end
    end
    return nil
end

-- Transitions
do
    smwMap.transitionDrawFunction = nil
    smwMap.transitionMiddleFunction = nil
    smwMap.transitionEndFunction = nil

    smwMap.transitionStartTime = nil
    smwMap.transitionWaitTime = nil
    smwMap.transitionEndTime = nil

    smwMap.transitionPriority = nil

    smwMap.transitionProgress = 0

    smwMap.transitionTimer = 0


    local mosaicShader = Shader()
    mosaicShader:compileFromFile(nil, Misc.multiResolveFile("fuzzy_pixel.frag", "shaders/npc/fuzzy_pixel.frag"))

    local irisOutShader = Shader()
    irisOutShader:compileFromFile(nil, Misc.resolveFile("smwMap/irisOut.frag"))

    local buffer = Graphics.CaptureBuffer(SCREEN_WIDTH,SCREEN_HEIGHT)


    function smwMap.TRANSITION_FADE(progress,priority)
        Graphics.drawBox{priority = priority,color = Color.black.. progress,x = 0,y = 0,width = SCREEN_WIDTH,height = SCREEN_HEIGHT}
    end


    function smwMap.TRANSITION_MOSAIC(progress,priority)
        local pixelSize = math.lerp(1,32, progress)

        Graphics.drawBox{priority = priority,color = Color.black.. progress,x = 0,y = 0,width = SCREEN_WIDTH,height = SCREEN_HEIGHT}

        -- Apply mosaic effect (done via 2 buffers to avoid weirdness)
        Graphics.drawBox{texture = smwMap.mainBuffer,target = buffer,priority = -6.1,x = 0,y = 0}

        Graphics.drawBox{
            texture = buffer,target = smwMap.mainBuffer,priority = -6,
            x = 0,y = 0,

            shader = mosaicShader,uniforms = {
                pxSize = vector(smwMap.mainBuffer.width / pixelSize,smwMap.mainBuffer.height / pixelSize),
            },
        }
    end


    function smwMap.TRANSITION_WINDOW(progress,priority)
        for i = 0,1 do
            for j = 0,1 do
                local x,y,width,height

                if j == 0 then
                    width = smwMap.camera.width
                    height = smwMap.camera.height * progress * 0.5
                    x = 0
                    y = i * (smwMap.camera.height - height)
                else
                    width = smwMap.camera.width * progress * 0.5
                    height = smwMap.camera.height
                    x = i * (smwMap.camera.width - width)
                    y = 0
                end

                Graphics.drawBox{
                    target = smwMap.mainBuffer,priority = priority,color = Color.black,
                    x = x,y = y,width = width,height = height,
                }
            end
        end
    end


    function smwMap.TRANSITION_IRIS_OUT(progress,priority)
        local focus = vector(
            smwMap.mainPlayer.x - smwMap.camera.x + smwMap.camera.renderX,
            smwMap.mainPlayer.y + smwMap.playerSettings.gfxYOffset + (smwMap.playerSettings.mountOffsets[smwMap.mainPlayer.basePlayer.mount] or 0) + smwMap.mainPlayer.zOffset - smwMap.camera.y + smwMap.camera.renderY
        )
        local radius = ((1 - progress) * math.max(smwMap.camera.width,smwMap.camera.height))

        Graphics.drawBox{
            priority = priority,color = Color.black,x = 0,y = 0,width = SCREEN_WIDTH,height = SCREEN_HEIGHT,
            shader = irisOutShader,uniforms = {
                screenSize = vector(SCREEN_WIDTH,SCREEN_HEIGHT),
                radius = radius,
                focus = focus,
            },
        }
    end



    function smwMap.startTransition(middleFunction,endFunction,args)
        if smwMap.transitionDrawFunction ~= nil then
            return
        end

        if args.drawFunction == nil then
            if middleFunction ~= nil then
                middleFunction()
            end
            if endFunction ~= nil then
                endFunction()
            end

            return
        end


        smwMap.transitionDrawFunction = args.drawFunction
        smwMap.transitionMiddleFunction = middleFunction
        smwMap.transitionEndFunction = endFunction

        smwMap.transitionStartTime = args.startTime or args.progressTime or 28
        smwMap.transitionWaitTime = args.waitTime or 8
        smwMap.transitionEndTime = args.endTime or args.progressTime or 28

        smwMap.transitionPriority = args.priority or 6

        smwMap.transitionPauses = args.pauses
        if smwMap.transitionPauses == nil then
            smwMap.transitionPauses = true
        end

        smwMap.transitionTimer = 0

        if smwMap.transitionPauses then
            Misc.pause(true)
        end
    end


    local function updateTransition()
        local beforeEndTime = (smwMap.transitionStartTime + smwMap.transitionWaitTime)
        local totalLength = (beforeEndTime + smwMap.transitionEndTime)

        smwMap.transitionProgress = 1

        smwMap.transitionTimer = smwMap.transitionTimer + 1

        if smwMap.transitionTimer > totalLength then
            if smwMap.transitionEndFunction ~= nil then
                smwMap.transitionEndFunction()
            end

            smwMap.transitionDrawFunction = nil

            if smwMap.transitionPauses then
                Misc.unpause()
            end

            return
        elseif smwMap.transitionTimer == (smwMap.transitionStartTime + math.floor(smwMap.transitionWaitTime*0.5)) and smwMap.transitionMiddleFunction ~= nil then
            smwMap.transitionMiddleFunction()
        elseif smwMap.transitionTimer < smwMap.transitionStartTime then
            smwMap.transitionProgress = (smwMap.transitionTimer / smwMap.transitionStartTime)
        elseif smwMap.transitionTimer > beforeEndTime then
            smwMap.transitionProgress = 1 - ((smwMap.transitionTimer - beforeEndTime) / smwMap.transitionEndTime)
        end
    end


    function smwMap.onDrawTransition()
        if smwMap.transitionDrawFunction ~= nil then
            if smwMap.transitionPauses then
                updateTransition()
            end

            if smwMap.transitionDrawFunction ~= nil then
                smwMap.transitionDrawFunction(smwMap.transitionProgress,smwMap.transitionPriority)
            end
        end
    end

    function smwMap.onTickTransition()
        if smwMap.transitionDrawFunction ~= nil and not smwMap.transitionPauses then
            updateTransition()
        end
    end
end


smwMap.transitionSettings = {
    selectedLevelSettings = {
        drawFunction = smwMap.TRANSITION_MOSAIC,
        progressTime = 28,
        priority = 6,
    },

    enterEncounterSettings = {
        drawFunction = smwMap.TRANSITION_MOSAIC,
        progressTime = 28,
        priority = 6,
    },

    enterMapSettings = {
        drawFunction = smwMap.TRANSITION_MOSAIC,
        progressTime = 28,
        priority = 6,

        waitTime = 0,startTime = 0, -- these are important! you probably shouldn't touch them
    },

    warpToWarpSettings = {
        drawFunction = smwMap.TRANSITION_FADE,
        progressTime = 20,
        waitTime = 8,
        priority = -4,
    },
    warpToPathSettings = {
        drawFunction = smwMap.TRANSITION_WINDOW,
        progressTime = 20,
        waitTime = 8,
        priority = -6,
        pauses = false,
    },
}


-- world card, shown when entering an area with a name
WORLD_CARD_STATE = {
    NOT_SHOWN = 0,
    ON_CARD = 1,
    EXPANDING_STARS = 2,
    CLOSING_STARS = 3,
}

smwMap.worldCard = {
    state = WORLD_CARD_STATE.NOT_SHOWN,
    center = vector(0, 0),
    radius = 0,
    starFrame = 0,
    starOffset = 0,

    cardImage = Graphics.loadImageResolved("smwMap/world-card.png"),
    starImage = Graphics.loadImageResolved("smwMap/stars.png"),
}


-- Events system
-- Handles stuff like paths opening, castle destruction, etc.
local EVENT_TYPE = {
    BEAT_LEVEL         = 0,
    LEVEL_DESTROYED    = 1,
    SWITCH_PALACE      = 2,
    ENCOUNTER_DEFEATED = 3,
    SHOW_HIDE_SCENERIES= 4,
    MOVE_ENCOUNTERS    = 5,
    SHOW_WORLD_CARD    = 6,
}

local updateEvent
local unlockLoopObj

smwMap.activeEvents = {}

do
    local updateFunctions = {}

    -- handles flipping icon animation, the player icon showing is handled by the level objects themselves
    updateFunctions[EVENT_TYPE.BEAT_LEVEL] = function (eventObj)
        eventObj.timer = eventObj.timer + 1
        if eventObj.timer == 1 then
            SFX.play(smwMap.pathSettings.itemPanel)
            smwMap.createObject(797, eventObj.levelObj.x, eventObj.levelObj.y)
        elseif eventObj.timer == 3 * 8 then
            smwMap.unlockLevelPaths(eventObj.levelObj, eventObj.winType)
        elseif eventObj.timer >= 5 * 8 then
            table.remove(smwMap.activeEvents, 1)
        end
    end

    updateFunctions[EVENT_TYPE.SHOW_HIDE_SCENERIES] = function(eventObj)
        if eventObj.sceneryProgress < eventObj.neededSceneryProgress+1 then
            eventObj.timer = eventObj.timer + 1
            eventObj.sceneryProgress = (eventObj.timer/smwMap.pathSettings.unlockAnimationFrequency)

            -- Update each scenery
            for _,scenery in ipairs(eventObj.showSceneries) do
                if scenery.globalSettings.useSmoke then
                    if scenery.globalSettings.showDelay == math.floor(eventObj.sceneryProgress) and scenery.opacity == 0 then
                        scenery.opacity = 1
                        smwMap.createObject(798, scenery.x, scenery.y)
                    end
                else
                    scenery.opacity = math.clamp(eventObj.sceneryProgress - scenery.globalSettings.showDelay)
                end
            end

            for _,scenery in ipairs(eventObj.hideSceneries) do
                if scenery.globalSettings.useSmoke then
                    if scenery.globalSettings.hideDelay == math.floor(eventObj.sceneryProgress) and scenery.opacity == 1 then
                        scenery.opacity = 0
                        smwMap.createObject(798, scenery.x, scenery.y)
                    end
                else
                    scenery.opacity = math.clamp(1 - (eventObj.sceneryProgress - scenery.globalSettings.hideDelay))
                end
            end
        else
            table.remove(smwMap.activeEvents,1)
        end
    end

    -- Destroying a castle
    updateFunctions[EVENT_TYPE.LEVEL_DESTROYED] = (function(eventObj)
        eventObj.timer = eventObj.timer + 1
        if eventObj.timer == 1 then
            SFX.play(smwMap.playerSettings.levelDestroyedSound)
            if smwMap.levelDestroyedSmokeEffectID ~= nil then
                smwMap.createObject(smwMap.levelDestroyedSmokeEffectID, eventObj.levelObj.x, eventObj.levelObj.y + 16)
            end
        elseif eventObj.timer == 32 then
            smwMap.unlockLevelPaths(eventObj.levelObj, eventObj.winType)
        elseif eventObj.timer >= 64 then
            table.remove(smwMap.activeEvents,1)
        end
    end)

    -- Switch palacing releasing the blocks
    updateFunctions[EVENT_TYPE.SWITCH_PALACE] = (function(eventObj)
        local blockSpeeds = {
            vector(0,0),
            vector(0,-12),
            vector(5,-9),vector(-5,-9),
            vector(7,-3.25),vector(-7,-3.25),
            vector(5,-0.2),vector(-5,-0.2),
        }

        local interval = (eventObj.timer/16)

        if math.floor(interval) == interval then
            if interval <= 8 then
                for _,speed in ipairs(blockSpeeds) do
                    local block = smwMap.createObject(smwMap.switchBlockEffectID, eventObj.levelObj.x,eventObj.levelObj.y)

                    block.data.speedX = speed.x
                    block.data.speedY = speed.y
                    block.frameY = eventObj.switchColorID-1
                end

                if switchBlockReleasedSound ~= nil and switchBlockReleasedSound:isPlaying() then
                    switchBlockReleasedSound:stop()
                end

                switchBlockReleasedSound = SFX.play(smwMap.playerSettings.switchBlockReleasedSound)
            elseif interval > 12 then
                smwMap.unlockLevelPaths(eventObj.levelObj, eventObj.winType)
                table.remove(smwMap.activeEvents,1)
            end
        end

        eventObj.timer = eventObj.timer + 1
    end)

    updateFunctions[EVENT_TYPE.ENCOUNTER_DEFEATED] = (function(eventObj)
        if not eventObj.encounterObj.isValid then
            table.remove(smwMap.activeEvents,1)
        end
    end)

    updateFunctions[EVENT_TYPE.MOVE_ENCOUNTERS] = function (eventObj)
        eventObj.timer = (eventObj.timer or 0) + 1
        if eventObj.timer == 1 then
            smwMap.beginMovingEncounters()
            if smwMap.encounterSettings.movingSound ~= nil then
                eventObj.movingSound = SFX.play{sound = smwMap.encounterSettings.movingSound, loops = 0}
            end
        end

        if smwMap.getMovingEncountersCount() == 0 then
            if eventObj.movingSound ~= nil then
                eventObj.movingSound:stop()
                eventObj.movingSound = nil
            end
            table.remove(smwMap.activeEvents, 1)
        end
    end

    updateFunctions[EVENT_TYPE.SHOW_WORLD_CARD] = function (eventObj)
        local center = vector(
            smwMap.camera.renderX + smwMap.camera.width  / 2,
            smwMap.camera.renderY + smwMap.camera.height / 2
        )
        local minDist = math.min(center.x, center.y) / 2
        local expandThresh  = minDist / 4 + 100
        local closingThresh = expandThresh + minDist / 4
        local playerPos = vector(
            smwMap.mainPlayer.x - smwMap.camera.x,
            smwMap.mainPlayer.y - smwMap.camera.y
        )

        eventObj.timer = (eventObj.timer or 0) + 1
        if eventObj.timer == 1 then
            smwMap.worldCard.state = WORLD_CARD_STATE.ON_CARD
        elseif eventObj.timer == 100 then
            smwMap.worldCard.state = WORLD_CARD_STATE.EXPANDING_STARS
            smwMap.worldCard.center = vector(
                smwMap.camera.renderX + smwMap.camera.width  / 2,
                smwMap.camera.renderY + smwMap.camera.height / 2
            )
            local dist = playerPos - smwMap.worldCard.center
            smwMap.worldCard.speed = dist / (closingThresh - expandThresh)
        elseif eventObj.timer >  100 and eventObj.timer < expandThresh then
            smwMap.worldCard.radius = smwMap.worldCard.radius + 4
            smwMap.worldCard.starFrame = math.floor((eventObj.timer - 100) / 4) % 2
            smwMap.worldCard.starOffset = smwMap.worldCard.starOffset + 4
        elseif eventObj.timer >= expandThresh and eventObj.timer < closingThresh then
            smwMap.worldCard.radius = smwMap.worldCard.radius - 4
            smwMap.worldCard.starFrame = math.floor((eventObj.timer - 100) / 4) % 2
            smwMap.worldCard.starOffset = smwMap.worldCard.starOffset + 4
            smwMap.worldCard.center = smwMap.worldCard.center + smwMap.worldCard.speed 
        elseif eventObj.timer == closingThresh then
            smwMap.worldCard.state = WORLD_CARD_STATE.NOT_SHOWN
            table.remove(smwMap.activeEvents, 1)
        end
    end

    function updateEvent(eventObj)
        updateFunctions[eventObj.type](eventObj)
    end
end


-- Encounters stuff
local onTickEncounterObj

do
    smwMap.ENCOUNTER_STATE = {
        NORMAL   = 0,
        WALKING  = 1,
        SLEEPING = 2,
        DEFEATED = 3,
    }

    local CAN_WALK_ON = {
        NON_HIDDEN = 0,
        ANY        = 1,
        UNLOCKED   = 2,
        NONE       = 3,
    }

    smwMap.encountersWaitingTimer = 0
    smwMap.encountersWaitingToMove = {}

    smwMap.encountersCount = 0


    local function setEncounterLevel(v,data,levelObj)
        local config = smwMap.getObjectConfig(levelObj.id)

        v.x = levelObj.x
        v.y = levelObj.y

        v.isUnderwater = config.isWater

        data.savedData.x = v.x
        data.savedData.y = v.y

        data.levelObj = levelObj
    end

    local function choosePath(v, data, level)
        local canWalkOn = v.settings.canWalkOn
        if canWalkOn == CAN_WALK_ON.NONE then
            return false
        end

        -- should be updated to check a list of ids instead
        if level.id == 811 and level ~= v.data.levelObj and level ~= smwMap.mainPlayer.levelObj then
            return false
        end

        -- Find any paths that are available
        local validPaths = {}
        for _, dir in ipairs{"up","right","down","left"} do
            if level.settings["unlock_" .. dir] ~= 0 then
                table.insert(validPaths, dir)
            end
        end

        if #validPaths == 0 then
            return false
        end

        -- Walk down one
        local chosenPath = RNG.irandomEntry(validPaths)
        v.walkingDirection = ({ down = vector( 0, 1), up    = vector(0, -1),
                                left = vector(-1, 0), right = vector(1,  0) })[chosenPath]
        data.direction = v.walkingDirection.x == 0 and DIR_LEFT or v.walkingDirection.x
        v.lastMovement = chosenPath
        data.state = smwMap.ENCOUNTER_STATE.WALKING
        data.timer = 0
        return true
    end


    function onTickEncounterObj(v)
        local data = v.data

        if data.state == nil then
            smwMap.encountersCount = smwMap.encountersCount + 1
            data.index = smwMap.encountersCount

            saveData.encounterData[data.index] = saveData.encounterData[data.index] or {
                x = v.x,
                y = v.y,
                killed = false,
            }
            data.savedData = saveData.encounterData[data.index]


            if data.savedData.killed then
                v:remove()
                return
            end

            v.x = data.savedData.x
            v.y = data.savedData.y


            -- Initialise
            data.state = smwMap.ENCOUNTER_STATE.NORMAL
            data.timer = 0

            data.direction = DIR_LEFT

            data.animationSpeed = 1

            data.defeatedSpeedY = 0

            local levelObj = findLevel(v,v.x,v.y)
            if levelObj ~= nil then
                setEncounterLevel(v,data,levelObj)
            else
                data.levelObj = nil
            end
        end


        if data.state == smwMap.ENCOUNTER_STATE.NORMAL then
            if #smwMap.activeEvents > 0 then
                v.graphicsOffsetX = 0
            else
                v.graphicsOffsetX = v.graphicsOffsetX + data.direction*0.5
            end
            if v.graphicsOffsetX*data.direction >= smwMap.encounterSettings.idleWanderDistance then
                data.direction = -data.direction
            end
            v.graphicsOffsetY = 0
            data.animationSpeed = 1
        elseif data.state == smwMap.ENCOUNTER_STATE.WALKING then
            local walkSpeed = walkSpeed or (v.isClimbing and smwMap.playerSettings.climbSpeed) or smwMap.encounterSettings.walkSpeed
            local newPosition = vector(v.x, v.y) + v.walkingDirection * walkSpeed
            v.x = newPosition.x
            v.y = newPosition.y

            v.graphicsOffsetX = 0
            v.graphicsOffsetY = 0

            data.animationSpeed = 4

            local levelObj = findLevel(v,v.x,v.y)

            local function isWithin(movement, x, y, lx, ly)
                return movement == "down"  and (y >= ly and x == lx)
                    or movement == "up"    and (y <= ly and x == lx)
                    or movement == "right" and (x >= lx and y == ly)
                    or movement == "left"  and (x <= lx and y == ly)
            end

            if levelObj ~= nil and levelObj ~= data.levelObj and isWithin(v.lastMovement, v.x, v.y, levelObj.x, levelObj.y) then
                local keepWalking = choosePath(v, data, levelObj)
                if not keepWalking then
                    setEncounterLevel(v,data,levelObj)
                    data.state = smwMap.ENCOUNTER_STATE.NORMAL
                    data.timer = 0
                else
                    v.x = levelObj.x
                    v.y = levelObj.y
                    data.levelObj = levelObj
                end
            end
        elseif data.state == smwMap.ENCOUNTER_STATE.SLEEPING then
            v.graphicsOffsetY = 0
        elseif data.state == smwMap.ENCOUNTER_STATE.DEFEATED then
            data.timer = data.timer + 1

            if data.timer == 1 then
                data.defeatedSpeedY = -6
                v.graphicsOffsetY = 0

                v.isUnderwater = false

                v.priority = -10

                data.savedData.killed = true

                SFX.play(9)
            elseif data.timer > 32 then
                if smwMap.smokeCloudEffectID ~= nil then
                    smwMap.createObject(smwMap.smokeCloudEffectID,v.x + v.graphicsOffsetX,v.y + v.graphicsOffsetY)
                end

                v:remove()
            end

            data.defeatedSpeedY = data.defeatedSpeedY + 0.26

            v.graphicsOffsetX = v.graphicsOffsetX + 0.5
            v.graphicsOffsetY = v.graphicsOffsetY + data.defeatedSpeedY

            data.animationSpeed = 4
        end
    end


    function smwMap.getMovingEncountersCount()
        local res = 0
        for _, v in ipairs(smwMap.objects) do
            if smwMap.getObjectConfig(v.id).isEncounter and v.data.state == smwMap.ENCOUNTER_STATE.WALKING then
                res = res + 1
            end
        end
        return res
    end


    function smwMap.beginMovingEncounters()
        for _, v in ipairs(smwMap.objects) do
            local cameraX, cameraY = getUsualCameraPos()

            if  smwMap.getObjectConfig(v.id).isEncounter
            and v.isValid
            -- If on camera, add to the list that'll move around
            and (cameraX + smwMap.camera.width ) > v.x-v.width *0.5
            and (cameraY + smwMap.camera.height) > v.y-v.height*0.5
            and (cameraX                       ) < v.x+v.width *0.5
            and (cameraY                       ) < v.y+v.height*0.5
            then
                choosePath(v, v.data, v.data.levelObj)
            end
        end
    end
end



function smwMap.onInitAPI()
    registerEvent(smwMap,"onStart")

    registerEvent(smwMap,"onCameraUpdate")
    registerEvent(smwMap,"onCameraDraw")

    registerEvent(smwMap,"onTick","onTickObjects")

    registerEvent(smwMap,"onTick","onTickPlayers")

    registerEvent(smwMap,"onTick")
    registerEvent(smwMap,"onDraw")

    registerEvent(smwMap,"onDraw","updateMusic")

    registerEvent(smwMap,"onTick","onTickTransition")
    registerEvent(smwMap,"onDraw","onDrawTransition")

    -- registerEvent(smwMap,"onTick","updateEncounters")

    registerEvent(smwMap,"onTickEnd")
end


function smwMap.onStart()
    for _,p in ipairs(Player.get()) do
        p.forcedState = FORCEDSTATE_INVISIBLE
        p.forcedTimer = 0
    end

    smwMap.camera.width  = SCREEN_WIDTH  - smwMap.hudSettings.border.leftWidth - smwMap.hudSettings.border.rightWidth
    smwMap.camera.height = SCREEN_HEIGHT - smwMap.hudSettings.border.topHeight - smwMap.hudSettings.border.bottomHeight
    smwMap.camera.renderX = smwMap.hudSettings.border.leftWidth
    smwMap.camera.renderY = smwMap.hudSettings.border.topHeight

    if warpTransition ~= nil then
        if warpTransition.currentTransitionType ~= nil then
            warpTransition.currentTransitionType = nil
            warpTransition.transitionTimer = 0

            warpTransition.transitionIsFromLevelStart = false
            warpTransition.currentWarp = nil

            Misc.unpause()
        end

        warpTransition.levelStartTransition = nil
    end


    Audio.SeizeStream(-1)
    Audio.MusicStop()


    Graphics.activateHud(false)

    smwMap.initObjects()
    smwMap.initTiles()
    smwMap.initSceneries()
    smwMap.initPlayers()
end


function smwMap.onTickEnd()
    if lunatime.tick() == 1 then
        smwMap.startTransition(nil,nil,smwMap.transitionSettings.enterMapSettings)
    end
end


-- Player
local PLAYER_STATE = {
    NORMAL               = 0, -- just standing there
    WALKING              = 1, -- walking along a path
    SELECTED             = 2, -- just picked a level
    WON                  = 3, -- just returned from a level, and is waiting to unlock some paths
    CUSTOM_WARPING       = 4, -- using star road warp
    PARKING_WHERE_I_WANT = 5, -- illparkwhereiwant / debug mode
    SELECT_START         = 6, -- selecting the start point
}

local LOOK_AROUND_STATE = {
    INACTIVE = 0,
    ACTIVE = 1,
    RETURN = 2,
}

smwMap.PLAYER_STATE = PLAYER_STATE
smwMap.LOOK_AROUND_STATE = LOOK_AROUND_STATE

do
    smwMap.players = {}
    smwMap.activeAreas = {}
    smwMap.currentBackgroundArea = nil
    smwMap.currentMusicArea = nil
    smwMap.currentCameraArea = nil

    local FOLLOWING_DELAY = 16

    function smwMap.createPlayer(basePlayerIdx)
        local v = {}

        v.width = 32
        v.height = 32

        v.state = PLAYER_STATE.NORMAL
        v.timer = 0
        v.timer2 = 0

        v.direction = 0
        v.frame = 0

        v.animationTimer = 0


        v.bounceOffset = 0
        v.bounceSpeed = 0
        v.mountFrame = 0

        v.zOffset = 0



        if smwMap.mainPlayer == nil then
            v.x = 0
            v.y = 0

            v.levelObj = nil

            v.warpCooldown = 0

            v.isUnderwater = false
            v.isClimbing = false

        else
            v.x = smwMap.mainPlayer.x
            v.y = smwMap.mainPlayer.y

            v.levelObj = smwMap.mainPlayer.levelObj

            v.warpCooldown = smwMap.mainPlayer.warpCooldown

            v.isUnderwater = smwMap.mainPlayer.isUnderwater
            v.isClimbing = smwMap.mainPlayer.isClimbing
        end


        v.movementHistory = {}
        -- different from the field above
        v.lastMovement = saveData.lastMovement or ""


        v.followingDelay = FOLLOWING_DELAY * #smwMap.players


        v.lookAroundState = LOOK_AROUND_STATE.INACTIVE
        v.lookAroundX = 0
        v.lookAroundY = 0



        v.basePlayer = Player(basePlayerIdx)

        v.isMainPlayer = false


        v.buffer = Graphics.CaptureBuffer(200,200)


        table.insert(smwMap.players,v)


        return v
    end

    smwMap.mainPlayer = smwMap.createPlayer()
    smwMap.mainPlayer.isMainPlayer = true

    smwMap.startPointSelectOptions = {}
    smwMap.startPointSelectedOption = 1
    smwMap.startPointOpenProgress = 0

    smwMap.startSelectLayouts = nil

    function smwMap.getStartPointOptions(levelObj)
        local startPoints = {}

        local filename = levelObj.settings.levelFilename
        local unlockedCheckpoints = saveData.unlockedCheckpoints[filename]

        local settings = smwMap.selectStartPointSettings


        table.insert(startPoints, {settings.beginningText, (function()
            mem(CHECKPOINT_PATH_ADDR,FIELD_STRING,"")
            GameData.__checkpoints[filename] = {}
        end)})

        if unlockedCheckpoints ~= nil then
            local checkpointIndices = {}
            for idx,_ in pairs(unlockedCheckpoints) do
                table.insert(checkpointIndices,idx)
            end

            for _,idx in ipairs(checkpointIndices) do
                local text
                if #checkpointIndices > 1 then
                    text = settings.checkpointMultipleText
                else
                    text = settings.checkpointSingleText
                end

                table.insert(startPoints, {text:format(idx), (function()
                    mem(CHECKPOINT_PATH_ADDR,FIELD_STRING,Misc.episodePath().. filename)

                    GameData.__checkpoints[filename] = {current = idx}

                    for i = 1, idx do
                        GameData.__checkpoints[filename][tostring(i)] = true
                    end
                end)})
            end
        end

        return startPoints
    end


    function smwMap.getStartSelectLayouts()
        local settings = smwMap.selectStartPointSettings

        smwMap.startSelectLayouts = {}

        for _,option in ipairs(smwMap.startPointSelectOptions) do
            local layout = textplus.layout(option[1],nil,{font = settings.textFont,xscale = settings.textScale,yscale = settings.textScale})

            table.insert(smwMap.startSelectLayouts,layout)
        end
    end

    function smwMap.drawStartSelect()
        local progress = smwMap.startPointOpenProgress
        local p = smwMap.mainPlayer

        local settings = smwMap.selectStartPointSettings


        if smwMap.startSelectLayouts == nil then
            smwMap.getStartSelectLayouts()
        end


        local mainWidth = 0
        local mainHeight = 0

        for idx,layout in ipairs(smwMap.startSelectLayouts) do
            mainWidth = math.max(mainWidth, layout.width)
            mainHeight = mainHeight + layout.height

            if idx < #smwMap.startSelectLayouts then
                mainHeight = mainHeight + settings.optionGap
            end
        end

        local fullWidth = mainWidth + settings.borderSize*2
        local fullHeight = mainHeight + settings.borderSize*2


        local finalX = p.x - fullWidth*0.5
        local finalY = p.y + (smwMap.playerSettings.mountOffsets[smwMap.mainPlayer.basePlayer.mount] or 0) - settings.distanceFromPlayer - fullHeight

        local startX = finalX
        local startY = finalY + 48

        if finalY < smwMap.camera.y+8 then
            finalY = p.y + settings.distanceFromPlayer
            startY = finalY - 48
        end

        local x = math.lerp(startX,finalX,progress)
        local y = math.lerp(startY,finalY,progress)

        local backColor = settings.backColor
        backColor = Color(backColor.r,backColor.g,backColor.b,backColor.a*progress)

        Graphics.drawBox{
            target = smwMap.mainBuffer,priority = settings.priority,color = backColor,
            x = x - smwMap.camera.x,y = y - smwMap.camera.y,width = fullWidth,height = fullHeight,
        }


        local textY = y + settings.borderSize - smwMap.camera.y

        for idx,layout in ipairs(smwMap.startSelectLayouts) do
            local textColor
            if idx == smwMap.startPointSelectedOption then
                textColor = settings.textColorSelected
            else
                textColor = settings.textColorUnselected
            end

            textplus.render{
                layout = layout,target = smwMap.mainBuffer,priority = settings.priority,color = textColor * progress,
                x = x + fullWidth*0.5 - layout.width*0.5 - smwMap.camera.x,y = textY,
            }

            textY = textY + layout.height + settings.optionGap
        end
    end


    local function findEncounter(v)
        for _,obj in ipairs(smwMap.getIntersectingObjects(v.x - v.width*0.5,v.y - v.height*0.5,v.x + v.width*0.5,v.y + v.height*0.5)) do
            if smwMap.getObjectConfig(obj.id).isEncounter then
                local levelFilename = obj.settings.levelFilename
                if levelFilename ~= "" and io.exists(Misc.episodePath().. levelFilename) and obj.data.state == smwMap.ENCOUNTER_STATE.NORMAL then
                    return obj
                end
            end
        end
    end


    local function getIntersectingInstantWarps(x,y)
        local ret = {}

        for _,warpObj in ipairs(smwMap.instantWarpsList) do
            if  x+1 > warpObj.x-1
            and y+1 > warpObj.y-1
            and x-1 < warpObj.x+1
            and y-1 < warpObj.y+1
            then
                table.insert(ret,warpObj)
            end
        end

        return ret
    end


    function smwMap.tryPlayerMove(v, directionName)
        if v.state ~= PLAYER_STATE.NORMAL then
            return
        end

        if not smwMap.levelExitIsUnlocked(v.levelObj, directionName, v.lastMovement) then
            SFX.play(3)
            return
        end

        v.walkingDirection = ({ down = vector( 0, 1), up    = vector(0, -1),
                                left = vector(-1, 0), right = vector(1,  0) })[directionName]
        v.state = PLAYER_STATE.WALKING
        v.timer = 0
        v.timer2 = 0
        v.lastMovement = directionName
        v.movementHistory[1] = directionName
        return true
    end

    function smwMap.levelExitIsUnlocked(levelObj, directionName, lastMovement)
        local function reverseDir(dir)
            return ({ down = "up", up = "down", left = "right", right = "left" })[dir]
        end

        -- come-back rule: if the player came to a level from a direction,
        -- then he can ALWAYS come back with the opposite direction
        if lastMovement == reverseDir(directionName) then
            return true
        end
        if levelObj == nil then
            return false
        end
        if isNormalLevel(levelObj.id) then
            local dirtype = levelObj.settings["unlock_" .. directionName]
            if dirtype == 0 then
                return false
            end
            return dirtype == 1
                or (saveData.beatenLevels[levelObj.settings.levelFilename] or {})[directionName] ~= nil
        else
            return levelObj.settings["unlock_" .. directionName]
        end
    end

    -- checks if any exit has been unlocked on a level. takes either a level object or a name
    function smwMap.isLevelBeaten(level)
        if type(level) == "string" then
            return saveData.beatenLevels[level]
        end
        return (level.settings.levelFilename ~= nil and saveData.beatenLevels[level.settings.levelFilename])
    end

    -- checks if all exits have been unlocked on a level.
    function smwMap.isLevelCompletelyBeaten(level)
        local data = saveData.beatenLevels[level.settings.levelFilename]
        for _, dir in ipairs({"up", "down", "left", "right"}) do
            if level.settings["unlock_" .. dir] >= 2 and not data[dir] then
                return false
            end
        end
        return true
    end

    local function setPlayerLevel(v,levelObj)
        v.levelObj = levelObj

        if levelObj ~= nil then
            v.x = levelObj.x
            v.y = levelObj.y

            v.isUnderwater = smwMap.getObjectConfig(levelObj.id).isWater
            v.isClimbing = false


            levelObj.lockedFade = 0


            if v.isMainPlayer then
                saveData.playerX = v.x
                saveData.playerY = v.y
            end
        end
    end


    local function canEnterLevel(levelObj)
        if levelObj == nil then
            return false
        end

        -- Handle warps
        if smwMap.getObjectConfig(levelObj.id).isWarp then
            return smwMap.warpsMap[levelObj.settings.destinationWarpName] ~= nil
        end

        -- Does the level file actually exist?
        if levelObj.settings.levelFilename == "" then
            return false
        end

        if not io.exists(Misc.episodePath().. levelObj.settings.levelFilename) then
            return false
        end

        if levelObj.settings.destroyAfterWin then
            if smwMap.getObjectConfig(levelObj.id).isBonusLevel then
                return smwMap.playerSettings.canEnterDestroyedBonusLevels
            else
                return smwMap.playerSettings.canEnterDestroyedLevels
            end
        else
            return true
        end
    end

    function smwMap.unlockLevelPaths(levelObj, winType)
        local function arrayMax(t, f)
            local res = -math.huge
            for _, e in ipairs(t) do
                res = math.max(res, f(e))
            end
            return res
        end

        local function getSceneryEventData(name)
            local show = {}
            local hide = {}
            for _, scenery in ipairs(smwMap.sceneries) do
                if scenery.globalSettings.showLevelName == name and (scenery.opacity == 0 or scenery.globalSettings.hideLevelName == name) then
                    table.insert(show, scenery)
                end
                if scenery.globalSettings.hideLevelName == name and (scenery.opacity == 1 or scenery.globalSettings.showLevelName == name) then
                    table.insert(hide, scenery)
                end
            end
            return show, hide
        end

        if levelObj.settings.levelFilename == nil then
            return
        end
        saveData.beatenLevels[levelObj.settings.levelFilename] = saveData.beatenLevels[levelObj.settings.levelFilename] or {}
        saveData.beatenLevels[levelObj.settings.levelFilename].character = smwMap.mainPlayer.basePlayer.character

        for _, directionName in ipairs{"up", "right", "down", "left"} do
            local unlockType = (levelObj.settings["unlock_".. directionName])
            if (type(unlockType) == "number" and (unlockType == 2 or unlockType-2 == winType)) or unlockType == true then
                if not saveData.beatenLevels[levelObj.settings.levelFilename][directionName] then
                    saveData.beatenLevels[levelObj.settings.levelFilename][directionName] = true

                    -- finds each blocking obj belonging to the level and remove them
                    for _, o in ipairs(smwMap.objects) do
                        if o.id == 754 and o.settings.levelFilename == levelObj.settings.levelFilename then
                            o:remove()
                        end
                    end

                    -- Initialise showing/hiding sceneries
                    local showSceneries, hideSceneries = getSceneryEventData(levelObj.settings.levelFilename)
                    table.insert(smwMap.activeEvents, {
                        type = EVENT_TYPE.SHOW_HIDE_SCENERIES,
                        neededSceneryProgress = math.max(arrayMax(showSceneries, function (e) return e.globalSettings.showDelay end),
                                                         arrayMax(hideSceneries, function (e) return e.globalSettings.hideDelay end)),
                        sceneryProgress = 0,
                        timer = 0,
                        showSceneries = showSceneries,
                        hideSceneries = hideSceneries,
                    })
                end
            end
        end
    end


    local function enterEncounter(v,encounterObj)
        local middleFunction = (function()
            Level.load(encounterObj.settings.levelFilename,nil,encounterObj.settings.warpIndex)
            Misc.unpause()
        end)

        smwMap.startTransition(middleFunction,nil, smwMap.transitionSettings.enterEncounterSettings)

        if smwMap.encounterSettings.enterSound ~= nil then
            SFX.play(smwMap.encounterSettings.enterSound)
        end
    end


    local function updateWalkingPosition(v, walkSpeed)
        local walkSpeed = walkSpeed or (v.isClimbing and smwMap.playerSettings.climbSpeed) or smwMap.playerSettings.walkSpeed
        local newPosition = vector(v.x, v.y) + v.walkingDirection * walkSpeed
        v.direction = 0
        v.x = newPosition.x
        v.y = newPosition.y
    end


    local function updateActiveAreas(v,padding)
        for i = #smwMap.activeAreas, 1, -1 do
            smwMap.activeAreas[i] = nil
        end


        local collider = Colliders.Box(v.x - v.width*0.5 - padding,v.y - v.height*0.5 - padding,v.width + padding*2,v.height + padding*2)

        local hasCollided = false

        for _,areaObj in ipairs(smwMap.areas) do
            if areaObj.collider:collide(collider) then
                if not hasCollided then
                    smwMap.currentBackgroundArea = nil
                    smwMap.currentMusicArea = nil
                    smwMap.currentCameraArea = nil

                    hasCollided = true
                end


                table.insert(smwMap.activeAreas,areaObj)

                if areaObj.music ~= nil then
                    smwMap.currentMusicArea = areaObj
                end

                if areaObj.backgroundName ~= "" or areaObj.backgroundColor ~= Color.black then
                    smwMap.currentBackgroundArea = areaObj
                end

                if areaObj.restrictCamera then
                    smwMap.currentCameraArea = areaObj
                end
            end
        end

        if smwMap.currentCameraArea.name ~= nil and gameData.areaName ~= smwMap.currentCameraArea.name then
            gameData.areaName = smwMap.currentCameraArea.name
            table.insert(smwMap.activeEvents, {
                type = EVENT_TYPE.SHOW_WORLD_CARD
            })
        end
    end


    function smwMap.doPlayerWarp(v,warpObj)
        local destinationLevel = smwMap.warpsMap[warpObj.settings.destinationWarpName]

        if destinationLevel ~= nil then
            local middleFunction = (function()
                for _,p in ipairs(smwMap.players) do
                    p.state = PLAYER_STATE.NORMAL
                    p.timer = 0
                    -- bug?
                    -- v.timer2 = 0
                    p.timer2 = 0
                    p.zOffset = 0
                    setPlayerLevel(p,destinationLevel)
                end

                v.movementHistory = {}
                v.direction = 0
                updateActiveAreas(v,64)
            end)

            smwMap.startTransition(middleFunction,nil, smwMap.transitionSettings.warpToWarpSettings)
        end

        --[[
        elseif destinationPath ~= nil then
            local middleFunction = (function()
                for _,p in ipairs(smwMap.players) do
                    p.state = PLAYER_STATE.WALKING
                    p.timer = p.followingDelay
                    p.timer2 = 0

                    p.zOffset = 0

                    p.pathObj = destinationPath

                    if warpObj.settings.pathWalkingDirection == 0 then
                        p.walkingDirection = 1
                        p.walkingProgress = 0
                    else
                        p.walkingDirection = -1
                        p.walkingProgress = 1
                    end

                    p.warpCooldown = 60

                    for i = 1,2 do -- done twice to make sure the player's facing the right way
                        updateWalkingPosition(p,0.0001)
                    end
                end

                v.movementHistory = {}

                updateActiveAreas(v,64)

                smwMap.unlockPath(destinationPath.name)
            end)

            smwMap.startTransition(middleFunction,nil, smwMap.transitionSettings.warpToPathSettings)
        end
        ]]
    end


    local stateFunctions = {}

    -- just standing there
    stateFunctions[PLAYER_STATE.NORMAL] = (function(v)
        -- Only face forwards after a few frames
        v.timer = v.timer + 1
        if v.timer >= 12 then
            v.direction = 0
        end


        if #smwMap.activeEvents == 0 and v.isMainPlayer then
            local encounterObj = findEncounter(v)

            if encounterObj ~= nil then -- on top of encounter
                enterEncounter(v,encounterObj)
            elseif player.keys.jump == KEYS_PRESSED and canEnterLevel(v.levelObj) then -- enter level
                local config = smwMap.getObjectConfig(v.levelObj.id)

                if config.isWarp then
                    -- Warps
                    if config.doWarpOverride == nil then
                        smwMap.doPlayerWarp(v,v.levelObj)
                    else
                        -- Make all players do the custom warping
                        v.state = PLAYER_STATE.CUSTOM_WARPING
                        v.timer = 0
                        v.timer2 = 0
                    end
                else
                    -- Normal levels
                    smwMap.startPointSelectOptions = smwMap.getStartPointOptions(v.levelObj)

                    if #smwMap.startPointSelectOptions <= 1 or not smwMap.selectStartPointSettings.enabled then
                        v.state = PLAYER_STATE.SELECTED
                        v.timer = 0
                        v.timer2 = 0

                        v.direction = 0
                    else
                        v.state = PLAYER_STATE.SELECT_START
                        v.timer = 0
                        v.timer2 = 0

                        v.direction = 0

                        smwMap.startPointSelectedOption = 1
                        smwMap.startSelectLayouts = nil
                    end

                    SFX.play(smwMap.playerSettings.levelSelectedSound)
                end
            elseif player.keys.dropItem == KEYS_PRESSED and v.levelObj ~= nil and Misc.inEditor() then -- unlock ALL the things (only works from in editor)
                v.state = PLAYER_STATE.WON
                v.timer = 1000
                v.timer2 = 0

                gameData.winType = 2
            elseif player.keys.altRun == KEYS_PRESSED and Misc.inEditor() then
                v.state = PLAYER_STATE.PARKING_WHERE_I_WANT
                v.timer = 0
                v.timer2 = 0
            else
                -- moving
                for _, dir in ipairs{"up", "down", "left", "right"} do
                    if player.keys[dir] == KEYS_PRESSED then
                        smwMap.tryPlayerMove(v, dir)
                    end
                end
            end
        elseif not v.isMainPlayer then
            -- If not the main player, mimic the main player's movement, delayed by a certain amount
            local movement = smwMap.mainPlayer.movementHistory[v.followingDelay]

            if smwMap.mainPlayer.state == PLAYER_STATE.CUSTOM_WARPING and v.levelObj == smwMap.mainPlayer.levelObj then
                v.state = PLAYER_STATE.CUSTOM_WARPING
                v.timer = -v.followingDelay
                v.timer2 = 0
            elseif movement ~= nil and movement ~= "" then
                if v.levelObj ~= nil then
                    v.x = v.levelObj.x
                    v.y = v.levelObj.y
                else
                    setPlayerLevel(v,smwMap.mainPlayer.levelObj)
                end

                smwMap.tryPlayerMove(v,movement)
            end
        end
    end)

    -- Walking around
    stateFunctions[PLAYER_STATE.WALKING] = (function(v)
        if (smwMap.transitionDrawFunction ~= nil and not smwMap.transitionPauses) then
            return
        end

        if v.timer > 0 then
            v.timer = math.max(0, v.timer - 1)
            return
        end

        updateWalkingPosition(v)

        -- Look for instant warps
        if v.isMainPlayer and v.warpCooldown == 0 then
            for _,warpObj in ipairs(getIntersectingInstantWarps(v.x,v.y)) do
                if canEnterLevel(warpObj) then
                    smwMap.doPlayerWarp(v,warpObj)
                    return
                end
            end
        end

        v.warpCooldown = math.max(0, v.warpCooldown - 1)

        -- has the player has finished walking the path (i.e. is resting on a level)?
        local levelObj = findLevel(v,v.x,v.y)

        local function isWithin(movement, x, y, lx, ly)
            return movement == "down"  and (y >= ly and x == lx)
                or movement == "up"    and (y <= ly and x == lx)
                or movement == "right" and (x >= lx and y == ly)
                or movement == "left"  and (x <= lx and y == ly)
        end

        if levelObj ~= nil and v.levelObj ~= levelObj and isWithin(v.lastMovement, v.x, v.y, levelObj.x, levelObj.y) then
            v.x = levelObj.x
            v.y = levelObj.y
            v.state = PLAYER_STATE.NORMAL
            v.timer = 0
            v.timer2 = 0
            v.warpCooldown = 0

            setPlayerLevel(v,levelObj)

            if v.isMainPlayer then
                local encounterObj = findEncounter(v)

                if encounterObj ~= nil then
                    enterEncounter(v,encounterObj)
                else
                    SFX.play(26)
                end

                -- save the last movement here so that the player doesn't remain stuck on a level
                -- if he quits there
                saveData.lastMovement = v.lastMovement
            end
        else
            local obj = findBlockingObj(v, v.x, v.y)
            if obj ~= nil then
                v.x = obj.x + ({ left = 32, right = -32, up =   0, down =  0 })[v.lastMovement]
                v.y = obj.y + ({ left =  0, right =   0, up = 32, down = -32 })[v.lastMovement]
                v.state = PLAYER_STATE.NORMAL
                v.timer = 0
                v.timer2 = 0
                v.warpCooldown = 0
                if v.levelObj ~= nil and (v.x ~= v.levelObj.x or v.y ~= v.levelObj.y) then
                    v.levelObj = nil
                    if v.isMainPlayer then
                        SFX.play(26)
                    end
                else
                    -- we haven't actually moved, so restore previous lastMovement
                    v.lastMovement = saveData.lastMovement
                    if v.isMainPlayer then
                        SFX.play(3)
                    end
                end
            end
        end
    end)

    -- Has selected a level
    stateFunctions[PLAYER_STATE.SELECTED] = (function(v)
        v.timer = v.timer + 1

        smwMap.startPointOpenProgress = math.max(0,smwMap.startPointOpenProgress - v.timer*0.005)

        if v.timer == 48 and v.isMainPlayer then
            local middleFunction = (function()
                Level.load(v.levelObj.settings.levelFilename,nil,v.levelObj.settings.warpIndex)
                Misc.unpause()
            end)

            smwMap.startTransition(middleFunction,nil, smwMap.transitionSettings.selectedLevelSettings)
        end
    end)

    -- Just beat a level, unlock any paths
    stateFunctions[PLAYER_STATE.WON] = (function(v)
        if v.levelObj == nil then -- failsafe
            v.state = PLAYER_STATE.NORMAL
            v.timer = 0
            v.timer2 = 0

            gameData.winType = LEVEL_WIN_TYPE_NONE
        end


        v.timer = v.timer + 1

        if v.timer < 24 then
            return
        end


        local encounterObj = findEncounter(v)

        if encounterObj ~= nil then
            local eventObj = {}

            eventObj.type = EVENT_TYPE.ENCOUNTER_DEFEATED
            eventObj.encounterObj = encounterObj

            table.insert(smwMap.activeEvents,eventObj)


            encounterObj.data.state = smwMap.ENCOUNTER_STATE.DEFEATED
            encounterObj.data.timer = 0


            gameData.winType = LEVEL_WIN_TYPE_NONE

            v.state = PLAYER_STATE.NORMAL
            v.timer = 0
            v.timer2 = 0

            Misc.saveGame()

            return
        end

        -- if the player hasn't already beaten the level
        if not saveData.beatenLevels[v.levelObj.settings.levelFilename] and isNormalLevel(v.levelObj.id) then
            -- Releasing blocks from switch palace
            local config = smwMap.getObjectConfig(v.levelObj.id)
            if config.switchColorID ~= nil and smwMap.switchBlockEffectID ~= nil then
                -- Create the event for blocks flying
                table.insert(smwMap.activeEvents, {
                    type = EVENT_TYPE.SWITCH_PALACE,
                    timer = 0,
                    levelObj = v.levelObj,
                    switchColorID = config.switchColorID,
                    winType = gameData.winType,
                })
            end

            if v.levelObj.settings.destroyAfterWin then
                -- Create the destruction event
                if config.hasDestroyedAnimation then
                    table.insert(smwMap.activeEvents, {
                        type = EVENT_TYPE.LEVEL_DESTROYED,
                        timer = 0,
                        levelObj = v.levelObj,
                        winType = gameData.winType,
                    })
                else
                    smwMap.unlockLevelPaths(v.levelObj, gameData.winType)
                end
            else
                if config.hasBeatenAnimation then
                    table.insert(smwMap.activeEvents, {
                        type = EVENT_TYPE.BEAT_LEVEL,
                        timer = 0,
                        levelObj = v.levelObj,
                        winType = gameData.winType,
                    })
                else
                    smwMap.unlockLevelPaths(v.levelObj, gameData.winType)
                end
            end
        else
            smwMap.unlockLevelPaths(v.levelObj, gameData.winType)
        end

        -- in any case, trigger the encounters
        table.insert(smwMap.activeEvents, {
            type = EVENT_TYPE.MOVE_ENCOUNTERS,
        })

        -- End the state
        gameData.winType = LEVEL_WIN_TYPE_NONE

        v.state = PLAYER_STATE.NORMAL
        v.timer = 0
        v.timer2 = 0

        Misc.saveGame()
    end)

    -- Warping
    stateFunctions[PLAYER_STATE.CUSTOM_WARPING] = (function(v)
        if v.levelObj == nil then
            v.state = PLAYER_STATE.NORMAL
            v.timer = 0
            v.timer2 = 0

            return
        end


        if v.timer < 0 then
            v.timer = v.timer + 1
            return
        end


        local config = smwMap.getObjectConfig(v.levelObj.id)

        local shouldFinishWarp = true

        if config.doWarpOverride ~= nil then
            shouldFinishWarp = config.doWarpOverride(v,v.levelObj)
        end

        if shouldFinishWarp and v.isMainPlayer then
            smwMap.doPlayerWarp(v,v.levelObj)
        end
    end)

    -- "illparkwhereiwant" cheat
    stateFunctions[PLAYER_STATE.PARKING_WHERE_I_WANT] = (function(v)
        if player.keys.left then
            v.x = v.x - 4
        elseif player.keys.right then
            v.x = v.x + 4
        end

        if player.keys.up then
            v.y = v.y - 4
        elseif player.keys.down then
            v.y = v.y + 4
        end


        v.levelObj = findLevel(v,v.x,v.y)

        if v.levelObj ~= nil and player.keys.jump == KEYS_PRESSED then
            for _,p in ipairs(smwMap.players) do
                p.state = PLAYER_STATE.NORMAL
                p.timer = 0
                p.timer2 = 0

                p.direction = 0
                p.zOffset = 0

                setPlayerLevel(p,v.levelObj)
            end

            SFX.play(26)

            return
        elseif Misc.GetKeyState(VK_BACK) and Misc.inEditor() then
            local middleFunction = (function()
                SaveData.smwMap = {}

                Misc.unpause()
                Level.exit()
            end)

            smwMap.startTransition(middleFunction,nil, smwMap.transitionSettings.selectedLevelSettings)

            return
        end

        v.timer = v.timer + 1
        v.direction = 0
        v.zOffset = math.sin(v.timer / 8) * 6
        v.animationTimer = 0

        local selectLevelText = {
            [false] = {"MOVE AROUND TO FIND A LEVEL,","PRESS JUMP TO SELECT IT"},
            [true] = {"MOVE AROUND TO FIND A LEVEL,","PRESS JUMP TO SELECT IT","","YOU CAN ALSO PRESS BACKSPACE","TO ERASE MAP-RELATED SAVE DATA"}
        }

        local messages = selectLevelText[Misc.inEditor()]
        local y = SCREEN_HEIGHT - smwMap.hudSettings.border.bottomHeight - 16
        for i = #messages, 1, -1 do
            local text = messages[i]
            local width,height = Text.getSize(text)
            y = y - height
            Text.printWP(text, SCREEN_WIDTH*0.5 - width*0.5,y,6)
        end
    end)


    stateFunctions[PLAYER_STATE.SELECT_START] = (function(v)
        if v.timer > 0 then
            smwMap.startPointOpenProgress = math.max(0,smwMap.startPointOpenProgress - v.timer*0.003)

            v.timer = v.timer + 1

            if smwMap.startPointOpenProgress <= 0 then
                v.state = PLAYER_STATE.NORMAL
                v.timer = 0
                v.timer2 = 0
            end

            return
        end

        if player.keys.run == KEYS_PRESSED then
            v.timer = 1
            return
        end

        smwMap.startPointOpenProgress = math.lerp(smwMap.startPointOpenProgress,1, 0.125)

        if player.keys.up == KEYS_PRESSED and smwMap.startPointSelectedOption > 1 then
            smwMap.startPointSelectedOption = smwMap.startPointSelectedOption - 1
            SFX.play(26)
        elseif player.keys.down == KEYS_PRESSED and smwMap.startPointSelectedOption < #smwMap.startPointSelectOptions then
            smwMap.startPointSelectedOption = smwMap.startPointSelectedOption + 1
            SFX.play(26)
        end

        if player.keys.jump == KEYS_PRESSED then
            v.state = PLAYER_STATE.SELECTED
            v.timer = 0
            v.timer2 = 0

            smwMap.startPointSelectOptions[smwMap.startPointSelectedOption][2]()

            SFX.play(smwMap.playerSettings.levelSelectedSound)
        end
    end)


    -- Handling looking around (done by pressing altJump)
    local lookAroundStateFunctions = {}

    -- Normal
    local cantEnterLookAroundStates = table.map{PLAYER_STATE.SELECTED,PLAYER_STATE.WON,PLAYER_STATE.CUSTOM_WARPING,PLAYER_STATE.SELECT_START}

    lookAroundStateFunctions[LOOK_AROUND_STATE.INACTIVE] = (function(v)
        -- attempt to look around
        if v.isMainPlayer and player.keys.altJump == KEYS_PRESSED and #smwMap.activeEvents == 0 and smwMap.transitionDrawFunction == nil and not cantEnterLookAroundStates[v.state] then
            -- Is the area big enough?
            local areaObj = smwMap.currentCameraArea

            if areaObj ~= nil and (areaObj.collider.width > smwMap.camera.width+16 or areaObj.collider.height > smwMap.camera.height+16) or smwMap.freeCamera then
                -- Enter the state
                v.lookAroundState = LOOK_AROUND_STATE.ACTIVE

                v.lookAroundX = smwMap.camera.x
                v.lookAroundY = smwMap.camera.y
            end
        end
    end)

    -- Can move the camera around
    lookAroundStateFunctions[LOOK_AROUND_STATE.ACTIVE] = (function(v)
        local areaObj = smwMap.currentCameraArea

        if player.keys.altJump == KEYS_PRESSED or (areaObj == nil and not smwMap.freeCamera) then -- return to normal behaviour
            v.lookAroundState = LOOK_AROUND_STATE.RETURN
            return
        end

        -- Move around the camera
        local moveSpeed = smwMap.playerSettings.lookAroundMoveSpeed

        if player.keys.left then
            v.lookAroundX = v.lookAroundX - moveSpeed
        elseif player.keys.right then
            v.lookAroundX = v.lookAroundX + moveSpeed
        end

        if player.keys.up then
            v.lookAroundY = v.lookAroundY - moveSpeed
        elseif player.keys.down then
            v.lookAroundY = v.lookAroundY + moveSpeed
        end

        -- Clamp it to the area bounds
        if areaObj ~= nil and not smwMap.freeCamera then
            v.lookAroundX = math.clamp(v.lookAroundX, areaObj.collider.x,areaObj.collider.x + areaObj.collider.width  - smwMap.camera.width )
            v.lookAroundY = math.clamp(v.lookAroundY, areaObj.collider.y,areaObj.collider.y + areaObj.collider.height - smwMap.camera.height)
        end
    end)

    -- Return to the original position
    lookAroundStateFunctions[LOOK_AROUND_STATE.RETURN] = (function(v)
        local moveSpeed = smwMap.playerSettings.lookAroundMoveSpeed * 2

        local goalX,goalY = getUsualCameraPos()

        local distance = vector(goalX - v.lookAroundX,goalY - v.lookAroundY)
        local speed = distance:normalise() * math.min(distance.length, moveSpeed)

        if distance.length <= moveSpeed then
            v.lookAroundState = LOOK_AROUND_STATE.INACTIVE
        else
            v.lookAroundX = v.lookAroundX + speed.x
            v.lookAroundY = v.lookAroundY + speed.y
        end
    end)


    local function updateNonMainPlayerCounts()
        local realPlayerCount = Player.count()
        local mapPlayerCount = #smwMap.players

        if mapPlayerCount > realPlayerCount then
            -- Too many map players
            for idx = realPlayerCount+1, mapPlayerCount do
                smwMap.players[idx] = nil
            end
        elseif realPlayerCount > mapPlayerCount then
            -- Too little map players
            for idx = mapPlayerCount+1, realPlayerCount do
                smwMap.createPlayer(idx)
            end
        end
    end


    function smwMap.onTickPlayers()
        updateNonMainPlayerCounts()

        for _,v in ipairs(smwMap.players) do
            if v.isMainPlayer then
                updateActiveAreas(v,0)
            end


            lookAroundStateFunctions[v.lookAroundState](v)

            if smwMap.mainPlayer.lookAroundState == LOOK_AROUND_STATE.INACTIVE then
                if v.isMainPlayer and #smwMap.players > 0 then
                    -- Record this player's movement history
                    table.insert(v.movementHistory,1,"")

                    for i = ((#smwMap.players-1) * FOLLOWING_DELAY)+1, #v.movementHistory do
                        v.movementHistory[i] = nil
                    end
                end

                -- Run main state
                stateFunctions[v.state](v)
            end


            -- Animations
            if v.state ~= PLAYER_STATE.SELECTED and (v.state ~= PLAYER_STATE.SELECT_START or v.timer > 0) then
                -- Normal animation
                v.animationTimer = v.animationTimer + 1

                if #smwMap.activeEvents > 0 then
                    if smwMap.activeEvents[1].type == EVENT_TYPE.BEAT_LEVEL
                    or smwMap.activeEvents[1].type == EVENT_TYPE.SHOW_WORLD_CARD then
                        v.frame = 3
                    else
                        v.frame = 2
                    end
                elseif v.basePlayer.mount == MOUNT_BOOT then
                    v.mountFrame = math.floor(v.animationTimer / 8) % smwMap.playerSettings.bootFrames

                    if v.direction == 0 and (v.state == PLAYER_STATE.NORMAL or v.state == PLAYER_STATE.WON) and v.bounceOffset == 0 then
                        v.frame = math.floor(v.animationTimer / 8) % 2
                    else
                        v.frame = 0
                    end

                    -- Bouncing
                    if v.isClimbing then
                        v.bounceOffset = 0
                        v.bounceSpeed = 0
                    else
                        v.bounceSpeed = v.bounceSpeed + 0.3
                        v.bounceOffset = math.min(0,v.bounceOffset + v.bounceSpeed)

                        if v.bounceOffset >= 0 and v.state == PLAYER_STATE.WALKING then
                            v.bounceSpeed = -2.3
                        end
                    end
                elseif v.basePlayer.mount == MOUNT_CLOWNCAR then
                    v.mountFrame = math.floor(v.animationTimer / 3) % smwMap.playerSettings.clownCarFrames
                    v.frame = 0
                elseif v.basePlayer.mount == MOUNT_YOSHI then
                    v.mountFrame = math.floor(v.animationTimer / 8) % smwMap.playerSettings.yoshiFrames
                    v.frame = 0
                else
                    v.frame = math.floor(v.animationTimer / 8) % 2
                end
            else
                v.frame = 0
            end
        end
    end

    function smwMap.initPlayers()
        local levelObj
        if saveData.playerX ~= nil and saveData.playerY ~= nil then
            levelObj = findLevel(smwMap.mainPlayer,saveData.playerX,saveData.playerY)
        end

        levelObj = levelObj or findLevel(smwMap.mainPlayer,smwMap.mainPlayer.x,smwMap.mainPlayer.y)

        setPlayerLevel(smwMap.mainPlayer,levelObj)



        if gameData.winType ~= LEVEL_WIN_TYPE_NONE and smwMap.mainPlayer.levelObj ~= nil then
            smwMap.mainPlayer.state = PLAYER_STATE.WON
        else
            smwMap.mainPlayer.state = PLAYER_STATE.NORMAL
        end


        updateNonMainPlayerCounts()

        updateActiveAreas(smwMap.mainPlayer,0)
    end
end


-- Objects
do
    smwMap.objects = {}

    smwMap.objectConfig = {}

    smwMap.instantWarpsList = {}
    smwMap.warpsMap = {}

    smwMap.areas = {}

    function smwMap.getObjectConfig(id)
        if smwMap.objectConfig[id] == nil then
            smwMap.objectConfig[id] = {}
            local config = smwMap.objectConfig[id]

            config.framesX = 1
            config.framesY = 1

            config.width = 32
            config.height = 32

            config.gfxoffsetx = 0
            config.gfxoffsety = 0

            config.priority = nil
            config.usePositionBasedPriority = false

            config.isLevel = false
            config.isWater = false
            config.hasDestroyedAnimation = false

            config.isWarp = false
            config.isEncounter = false

            config.onInitObj = nil
            config.onTickObj = nil
        end

        smwMap.objectConfig[id].texture = smwMap.objectConfig[id].texture or Graphics.sprites.npc[id].img

        return smwMap.objectConfig[id]
    end


    function smwMap.setObjConfig(id,settings)
        local config = smwMap.getObjectConfig(id)
        for k,v in pairs(settings) do
            config[k] = v
        end
        return config
    end


    function smwMap.createObject(id, x, y, npc)
        local config = smwMap.getObjectConfig(id)

        if id == 754 and smwMap.isLevelBeaten(npc.data._settings.levelFilename) then
            return
        end

        local v = {}

        v.id = id

        v.width = config.width
        v.height = config.height

        v.x = x
        v.y = y

        v.frameX = 0
        v.frameY = 0


        if config.usePositionBasedPriority then
            v.priority = nil
        elseif config.priority ~= nil then
            v.priority = config.priority
        elseif config.isLevel then
            v.priority = -55
        else
            v.priority = -50
        end


        v.toRemove = false
        v.isValid = true

        v.isOffScreen = false


        v.graphicsOffsetX = 0
        v.graphicsOffsetY = 0

        v.cutoffLeftX = nil
        v.cutoffRightX = nil
        v.cutoffBottomY = nil
        v.cutoffTopY = nil


        v.data = {}


        if npc ~= nil then
            v.settings = npc.data._settings
        else
            v.settings = NPC.makeDefaultSettings(id)
        end


        if config.isLevel and not v.settings.alwaysVisible then
            v.lockedFade = 1
            v.hideIfLocked = true
        else
            v.lockedFade = 0
            v.hideIfLocked = false
        end

        -- very interesting, maybe we should have a isLevelDestroyed function instead
        -- v.levelDestroyed = isNormalLevel(v.id) and v.settings.levelFilename ~= ""
                       -- and saveData.beatenLevels[v.settings.levelFilename]

        if config.isWarp then
            smwMap.warpsMap[v.settings.warpName] = v

            if not config.isLevel then
                table.insert(smwMap.instantWarpsList,v)
            end
        end

        setmetatable(v,{
            __index = {
                remove = function (v)
                    v.toRemove = true
                end
            },
        })


        if config.onInitObj ~= nil then
            config.onInitObj(v)
        end


        table.insert(smwMap.objects,v)

        return v
    end


    function smwMap.getIntersectingObjects(x1,y1,x2,y2)
        local ret = {}

        --Graphics.drawBox{target = smwMap.mainBuffer,x = x1 - smwMap.camera.x,y = y1 - smwMap.camera.y,width = x2 - x1,height = y2 - y1,priority = -6,color = Color.red.. 0.5}

        for _,obj in ipairs(smwMap.objects) do
            if  x2 > obj.x-obj.width *0.5
            and y2 > obj.y-obj.height*0.5
            and x1 < obj.x+obj.width *0.5
            and y1 < obj.y+obj.height*0.5
            then
                table.insert(ret,obj)
            end
        end

        return ret
    end


    function smwMap.initObjects()
        for _,v in NPC.iterate() do
            local config = smwMap.getObjectConfig(v.id)

            smwMap.createObject(v.id,v.x + config.width*0.5,v.y + config.height*0.5,v)
            v:kill(HARM_TYPE_VANISH)
        end

        for _,v in ipairs(smwMap.objects) do
            local config = smwMap.getObjectConfig(v.id)

            if config.onStartObj ~= nil then
                config.onStartObj(v)
            end
        end
    end

    function smwMap.onTickObjects()
        for idx = #smwMap.objects, 1, -1 do
            local v = smwMap.objects[idx]

            if v.toRemove then
                table.remove(smwMap.objects,idx)
                v.isValid = false
            else
                local config = smwMap.getObjectConfig(v.id)

                if config.isEncounter then
                    onTickEncounterObj(v)
                end

                if config.onTickObj ~= nil and not v.toRemove then
                    config.onTickObj(v)
                end
            end
        end
    end


    function smwMap.doBasicAnimation(v,frames,framespeed)
        v.data.animationTimer = (v.data.animationTimer or 0) + 1
        return math.floor(v.data.animationTimer / framespeed) % frames
    end
end


-- Tiles
do
    smwMap.tiles = {}

    smwMap.tileConfig = {}

    function smwMap.getTileConfig(id)
        if smwMap.tileConfig[id] == nil then
            smwMap.tileConfig[id] = {}
            local config = smwMap.tileConfig[id]

            local bgoConfig = BGO.config[id]

            config.frames = bgoConfig.frames or 1
            config.framespeed = bgoConfig.framespeed or 1
        end

        smwMap.tileConfig[id].texture = smwMap.tileConfig[id].texture or Graphics.sprites.background[id].img

        return smwMap.tileConfig[id]
    end

    function smwMap.createTile(id,x,y,width,height)
        local v = {}

        v.id = id

        v.x = x
        v.y = y

        v.width = width
        v.height = height

        table.insert(smwMap.tiles,v)

        return v
    end

    function smwMap.initTiles()
        for _,bgo in BGO.iterate() do
            smwMap.createTile(bgo.id,bgo.x + bgo.width*0.5,bgo.y + bgo.height*0.5,bgo.width,bgo.height)
            bgo.isHidden = true
        end
    end
end


-- Sceneries
do
    smwMap.sceneries = {}

    smwMap.sceneryConfig = {}


    -- Add some extra txt properties to blocks
    for id = 1, BLOCK_MAX_ID do
        local blockConfig = Block.config[id]

        blockConfig:setDefaultProperty("priority",-1000)
        blockConfig:setDefaultProperty("hillpart","")
    end


    function smwMap.getSceneryConfig(id)
        if smwMap.sceneryConfig[id] == nil then
            smwMap.sceneryConfig[id] = {}
            local config = smwMap.sceneryConfig[id]

            local blockConfig = Block.config[id]

            config.frames = blockConfig.frames or 1
            config.framespeed = blockConfig.framespeed or 1

            config.hillpart = blockConfig.hillpart or ""

            config.priority = (blockConfig.priority ~= -1000 and blockConfig.priority) or nil
        end

        smwMap.sceneryConfig[id].texture = smwMap.sceneryConfig[id].texture or Graphics.sprites.block[id].img

        return smwMap.sceneryConfig[id]
    end

    function smwMap.createScenery(id,x,y,width,height,block)
        local v = {}

        v.id = id

        v.x = x
        v.y = y

        v.width = width
        v.height = height


        v.priorityFindY = nil


        if block ~= nil then
            v.settings = block.data._settings
        else
            v.settings = Block.makeDefaultSettings(id)
        end

        v.globalSettings = v.settings._global

        if (v.globalSettings.showLevelName ~= "" and smwMap.isLevelBeaten(v.globalSettings.showLevelName))
        or (v.globalSettings.hideLevelName ~= "" and not smwMap.isLevelBeaten(v.globalSettings.hideLevelName))
        or (v.globalSettings.showLevelName == "" and v.globalSettings.hideLevelName == "") then
            v.opacity = 1
        else
            v.opacity = 0
        end

        table.insert(smwMap.sceneries, v)
        return v
    end


    function smwMap.fixHillPriority()
        for _,v in ipairs(smwMap.sceneries) do
            local selfConfig = smwMap.getSceneryConfig(v.id)

            if selfConfig.hillpart ~= "" and selfConfig.hillpart ~= "bottom" and selfConfig.priority == nil and v.priorityFindY == nil then
                local highestHill

                for _,other in ipairs(smwMap.sceneries) do
                    local otherConfig = smwMap.getSceneryConfig(other.id)

                    if v ~= other
                    and otherConfig.hillpart == "bottom"
                    and math.abs(v.x - other.x) <= 2 and other.y > v.y
                    and (highestHill == nil or other.y < highestHill.y)
                    then
                        highestHill = other
                    end
                end

                if highestHill ~= nil then
                    v.priorityFindY = (highestHill.y + highestHill.height*0.5)
                end
            end
        end
    end


    function smwMap.initSceneries()
        for _,block in Block.iterate() do
            smwMap.createScenery(block.id,block.x + block.width*0.5,block.y + block.height*0.5,block.width,block.height,block)
            block.isHidden = true
        end

        smwMap.fixHillPriority()
    end
end


-- Rendering
do
    --[[
        USUAL PRIORITY:

        -90          Tiles default
        -80          Completely locked things
        -60          Paths
        -55          Levels default
        -50          Objects default
        -25 to -20   Players and sceneries default (dependent on Y position relative to camera)
        -10          Some higher priority objects
    ]]


    smwMap.mainBuffer   = Graphics.CaptureBuffer(SCREEN_WIDTH,SCREEN_HEIGHT) -- main buffer that everything is drawn to
    smwMap.lockedBuffer = Graphics.CaptureBuffer(SCREEN_WIDTH,SCREEN_HEIGHT) -- buffer that everything that is completed locked gets drawn to, to prevent weird overlapping
    smwMap.pathBuffer   = Graphics.CaptureBuffer(SCREEN_WIDTH,SCREEN_HEIGHT) -- used to remove 1x1 pixels on paths


    local lockedShader = Shader()
    lockedShader:compileFromFile(nil, Misc.resolveFile("smwMap/locked.frag"))


    local basicGlDrawArgs = {
        vertexCoords = {},
        textureCoords = {},
    }

    local function doBasicGlDrawSetup(texture,x,y,width,height,sourceX,sourceY,sourceWidth,sourceHeight)
        basicGlDrawArgs.texture = texture

        -- Vertex coords
        do
            local vc = basicGlDrawArgs.vertexCoords

            local x1 = x
            local y1 = y
            local x2 = x1+width
            local y2 = y1+height

            vc[1] = x1
            vc[2] = y1

            vc[3] = x1
            vc[4] = y2

            vc[5] = x2
            vc[6] = y1

            vc[7] = x1
            vc[8] = y2

            vc[9] = x2
            vc[10] = y1

            vc[11] = x2
            vc[12] = y2
        end

        -- Texture coords
        do
            local tc = basicGlDrawArgs.textureCoords

            local x1 = sourceX/texture.width
            local y1 = sourceY/texture.height
            local x2 = (sourceX+sourceWidth )/texture.width
            local y2 = (sourceY+sourceHeight)/texture.height

            tc[1] = x1
            tc[2] = y1

            tc[3] = x1
            tc[4] = y2

            tc[5] = x2
            tc[6] = y1

            tc[7] = x1
            tc[8] = y2

            tc[9] = x2
            tc[10] = y1

            tc[11] = x2
            tc[12] = y2
        end

        basicGlDrawArgs.vertexColors = nil
    end



    local function getSceneOrPlayerPriority(x,y)
        return -25 + math.clamp((y - smwMap.camera.y) / (smwMap.camera.height+1000))*5
    end


    function smwMap.isOnCamera(x,y,width,height)
        return (
            (x + width) > smwMap.camera.x
            and (y + height) > smwMap.camera.y
            and x < (smwMap.camera.x + smwMap.camera.width)
            and y < (smwMap.camera.y + smwMap.camera.height)
        )
    end

    local isOnCamera = smwMap.isOnCamera



    local function handleCutoff(position,size,sourcePosition,sourceSize, cutoffLess,cutoffMore)
        if cutoffLess ~= nil then
            size = math.clamp(position+size - cutoffLess, 0,size)
            sourceSize = math.clamp(position+sourceSize - cutoffLess, 0,sourceSize)
            sourcePosition = sourcePosition + math.max(0, cutoffLess - position)
            position = math.max(position, cutoffLess)
        end

        if cutoffMore ~= nil then
            size = math.clamp(cutoffMore - position, 0,size)
            sourceSize = math.clamp(cutoffMore - position, 0,sourceSize)
            position = math.min(position, cutoffMore)
        end

        return position,size,sourcePosition,sourceSize
    end


    function smwMap.drawObject(v)
        local config = smwMap.getObjectConfig(v.id)

        local texture = config.texture

        if texture == nil or v.toRemove or (v.lockedFade >= 1 and v.hideIfLocked) or (config.hidden and not (Misc.inEditor() and Misc.GetKeyState(VK_T))) then
            return
        end


        local sourceWidth  = texture.width  / config.framesX
        local sourceHeight = texture.height / config.framesY

        local width,height = sourceWidth,sourceHeight

        local x = v.x - width*0.5 + v.graphicsOffsetX + config.gfxoffsetx
        local y = v.y + v.height*0.5 + v.graphicsOffsetY - height + config.gfxoffsety


        if not isOnCamera(x,y,width,height) then
            v.isOffScreen = true
            return
        else
            v.isOffScreen = false
        end

        local priority = v.priority or getSceneOrPlayerPriority(v.x + config.gfxoffsetx,v.y + height*0.5 + config.gfxoffsety)

        local sourceX = v.frameX * sourceWidth
        local sourceY = v.frameY * sourceHeight


        -- Water
        if v.isUnderwater then
            local waterImage = smwMap.playerSettings.waterImage
            local waterHeight = waterImage.height*0.5
            local waterFrame = math.floor(lunatime.tick() / 8) % 2

            y = y + 10

            basicGlDrawArgs.priority = priority

            doBasicGlDrawSetup(waterImage, x + width*0.5 - waterImage.width*0.5 - smwMap.camera.x,y + height - waterHeight - smwMap.camera.y,waterImage.width,waterHeight,0,waterFrame*waterHeight,waterImage.width,waterHeight)

            Graphics.glDraw(basicGlDrawArgs)


            height = height - waterHeight
            sourceHeight = sourceHeight - waterHeight
        end


        -- Handle cutoff
        x,width ,sourceX,sourceWidth  = handleCutoff(x,width ,sourceX,sourceWidth , v.cutoffLeftX,v.cutoffRightX)
        y,height,sourceY,sourceHeight = handleCutoff(y,height,sourceY,sourceHeight, v.cutoffTopY,v.cutoffBottomY)


        doBasicGlDrawSetup(texture,x - smwMap.camera.x,y - smwMap.camera.y,width,height,sourceX,sourceY,sourceWidth,sourceHeight)

        basicGlDrawArgs.priority = priority


        if v.lockedFade >= 1 then -- fully locked, so put it in the special buffer
            basicGlDrawArgs.target = smwMap.lockedBuffer
            basicGlDrawArgs.priority = -99
        elseif v.lockedFade > 0 then
            basicGlDrawArgs.shader = lockedShader
            basicGlDrawArgs.uniforms = {
                hideIfLocked = (v.hideIfLocked and 1) or 0,
                lockedFade = v.lockedFade,

                lockedPathColor = smwMap.pathSettings.lockedColor,
            }
        end


        Graphics.glDraw(basicGlDrawArgs)

        basicGlDrawArgs.target = smwMap.mainBuffer

        basicGlDrawArgs.shader = nil
        basicGlDrawArgs.uniforms = nil
    end


    function smwMap.drawTile(v)
        local config = smwMap.getTileConfig(v.id)
        local texture = config.texture

        if texture == nil then
            return
        end


        local width = v.width
        local height = v.height

        local x = v.x - width *0.5
        local y = v.y - height*0.5

        if not isOnCamera(x,y,width,height) then
            return
        end


        local frame = math.floor(lunatime.tick() / config.framespeed) % config.frames

        doBasicGlDrawSetup(texture,x - smwMap.camera.x,y - smwMap.camera.y,width,height,0,frame*height,width,height)

        basicGlDrawArgs.priority = -90

        Graphics.glDraw(basicGlDrawArgs)
    end


    function smwMap.drawScenery(v)
        local config = smwMap.getSceneryConfig(v.id)
        local texture = config.texture

        if texture == nil or v.opacity <= 0 then
            return
        end


        local width = v.width
        local height = v.height

        local x = v.x - width *0.5
        local y = v.y - height*0.5

        if not isOnCamera(x,y,width,height) then
            return
        end


        --[[if v.priorityFindY ~= nil then
            Text.printWP(v.priorityFindY - v.y,v.x - v.width*0.5 - smwMap.camera.x + smwMap.camera.renderX,v.y - v.height*0.5 - smwMap.camera.y + smwMap.camera.renderY,10)
        end]]


        local frame = math.floor(lunatime.tick() / config.framespeed) % config.frames

        doBasicGlDrawSetup(texture,x - smwMap.camera.x,y - smwMap.camera.y,width,height,0,frame*height,width,height)

        basicGlDrawArgs.priority = config.priority or getSceneOrPlayerPriority(v.x,v.priorityFindY or (v.y + v.height*0.5))
        basicGlDrawArgs.color = Color.white.. v.opacity

        Graphics.glDraw(basicGlDrawArgs)

        basicGlDrawArgs.color = nil
    end



    local mountImages = {}
    local function getMountImage(mountType,mountColor)
        if mountType == MOUNT_BOOT then
            mountImages[mountType] = mountImages[mountType] or {}
            mountImages[mountType][mountColor] = mountImages[mountType][mountColor] or Graphics.loadImageResolved("smwMap/player-boot-".. mountColor.. ".png")

            return mountImages[mountType][mountColor]
        elseif mountType == MOUNT_YOSHI then
            mountImages[mountType] = mountImages[mountType] or {}
            mountImages[mountType][mountColor] = mountImages[mountType][mountColor] or Graphics.loadImageResolved("smwMap/player-yoshi-".. mountColor.. ".png")

            return mountImages[mountType][mountColor]
        elseif mountType == MOUNT_CLOWNCAR then
            mountImages[mountType] = mountImages[mountType] or Graphics.loadImageResolved("smwMap/player-clownCar.png")

            return mountImages[mountType]
        end
    end

    function smwMap.drawPlayer(v)
        local texture = smwMap.playerSettings.image or smwMap.playerSettings.images[v.basePlayer.character] or smwMap.playerSettings.images[1]

        local width  = texture.width  / smwMap.playerSettings.framesX
        local height = texture.height / smwMap.playerSettings.framesY

        local mainXOffset = 0
        local mainYOffset = smwMap.playerSettings.gfxYOffset

        local shadowY = y
        local shadowOpacity = 0

        local priority = getSceneOrPlayerPriority(v.x,v.y + smwMap.playerSettings.gfxYOffset + height*0.5)

        local mountImage = getMountImage(v.basePlayer.mount,v.basePlayer.mountColor)

        local offsetFromMount = (smwMap.playerSettings.mountOffsets[v.basePlayer.mount] or 0)

        basicGlDrawArgs.target = v.buffer
        v.buffer:clear(0)

        if v.basePlayer.mount == MOUNT_BOOT then
            mainYOffset = mainYOffset + v.bounceOffset

            if not v.isUnderwater then
                shadowOpacity = (-v.bounceOffset / 32)
            end

            -- Mount
            local mountWidth  = mountImage.width  / smwMap.playerSettings.framesX
            local mountHeight = mountImage.height / smwMap.playerSettings.bootFrames

            doBasicGlDrawSetup(mountImage,
                v.buffer.width*0.5 + mainXOffset - mountWidth*0.5,
                v.buffer.height*0.5 + mainYOffset + height*0.5 - mountHeight,
                mountWidth, mountHeight,
                v.direction*mountWidth, v.mountFrame*mountHeight,
                mountWidth, mountHeight
            )

            basicGlDrawArgs.priority = -98.5

            Graphics.glDraw(basicGlDrawArgs)


            mainYOffset = mainYOffset + offsetFromMount
        elseif v.basePlayer.mount == MOUNT_CLOWNCAR then
            local extraOffset = math.cos(v.animationTimer / 8) * 4
            local clownCarOffset = (mainYOffset + offsetFromMount + extraOffset + 10)


            shadowOpacity = (-clownCarOffset / 64)

            -- Mount
            local mountWidth  = mountImage.width
            local mountHeight = mountImage.height / smwMap.playerSettings.clownCarFrames

            doBasicGlDrawSetup(mountImage,v.buffer.width*0.5 + mainXOffset - mountWidth*0.5,v.buffer.height*0.5 + clownCarOffset + height*0.5 - mountHeight,mountWidth,mountHeight,0,v.mountFrame*mountHeight,mountWidth,mountHeight)

            basicGlDrawArgs.priority = -98.5

            Graphics.glDraw(basicGlDrawArgs)


            mainYOffset = mainYOffset + offsetFromMount + extraOffset
        elseif v.basePlayer.mount == MOUNT_YOSHI then
            if v.direction == 0 then
                mainYOffset = mainYOffset + offsetFromMount - 6 - v.mountFrame*2
            elseif v.direction == 1 then
                mainYOffset = mainYOffset + offsetFromMount - 4 + v.mountFrame*2
            elseif v.direction == 2 then
                mainXOffset = mainXOffset + 14
                mainYOffset = mainYOffset + offsetFromMount - 0 - v.mountFrame*2
            elseif v.direction == 3 then
                mainXOffset = mainXOffset - 14
                mainYOffset = mainYOffset + offsetFromMount - 0 - v.mountFrame*2
            end

            if v.direction == 0 then
                basicGlDrawArgs.priority = -98.5
            else
                basicGlDrawArgs.priority = -99.5
            end

            -- Mount
            local mountWidth  = mountImage.width  / smwMap.playerSettings.framesX
            local mountHeight = mountImage.height / smwMap.playerSettings.yoshiFrames

            doBasicGlDrawSetup(mountImage,
                v.buffer.width*0.5 - mountWidth*0.5, v.buffer.height*0.5 + smwMap.playerSettings.gfxYOffset + height*0.5 - mountHeight,
                mountWidth, mountHeight,
                v.direction*mountWidth, v.mountFrame*mountHeight,
                mountWidth, mountHeight
            )

            Graphics.glDraw(basicGlDrawArgs)
        end


        if shadowOpacity > 0 then
            local shadowTexture = smwMap.playerSettings.shadowImage

            local x = v.x - shadowTexture.width*0.5 - smwMap.camera.x
            local y = v.y + height*0.5 + smwMap.playerSettings.gfxYOffset - shadowTexture.height*0.5 - smwMap.camera.y

            basicGlDrawArgs.priority = priority
            basicGlDrawArgs.color = Color.black.. shadowOpacity
            basicGlDrawArgs.target = smwMap.mainBuffer

            doBasicGlDrawSetup(shadowTexture, x,y, shadowTexture.width,shadowTexture.height, 0,0, shadowTexture.width,shadowTexture.height)

            Graphics.glDraw(basicGlDrawArgs)

            basicGlDrawArgs.color = nil
            basicGlDrawArgs.target = v.buffer
        end


        -- Draw main player to the buffer
        doBasicGlDrawSetup(texture,
            v.buffer.width*0.5 + mainXOffset - width*0.5, v.buffer.height*0.5 + mainYOffset - height*0.5,
            width, height,
            v.direction*width, v.frame*height,
            width, height
        )

        basicGlDrawArgs.priority = -99

        Graphics.glDraw(basicGlDrawArgs)

        basicGlDrawArgs.target = smwMap.mainBuffer


        -- Draw the player buffer to the main buffer + water effects
        local bufferDrawHeight = v.buffer.height
        local bufferDrawX = v.x - v.buffer.width *0.5 - smwMap.camera.x
        local bufferDrawY = v.y - v.buffer.height*0.5 - smwMap.camera.y + v.zOffset

        if v.isUnderwater and player.mount ~= MOUNT_CLOWNCAR then
            local waterImage = smwMap.playerSettings.waterImage
            local waterFrame = math.floor(v.animationTimer / 8) % 2

            bufferDrawHeight = bufferDrawHeight*0.5 + 8 - waterImage.height*0.5 - v.zOffset
            bufferDrawY = bufferDrawY + 10

            doBasicGlDrawSetup(waterImage,v.x - waterImage.width*0.5 - smwMap.camera.x,v.y - smwMap.camera.y,waterImage.width,waterImage.height*0.5,0,waterFrame*waterImage.height*0.5,waterImage.width,waterImage.height*0.5)

            basicGlDrawArgs.priority = priority+0.0001

            Graphics.glDraw(basicGlDrawArgs)
        end

        doBasicGlDrawSetup(v.buffer,bufferDrawX,bufferDrawY,v.buffer.width,bufferDrawHeight,0,0,v.buffer.width,bufferDrawHeight)

        basicGlDrawArgs.priority = priority

        Graphics.glDraw(basicGlDrawArgs)
    end


    -- Path rendering! (weird)
    local PATH_STEP = 4
    local PATH_CACHED_TIME = 160
    local PATH_MAX_LENGTH = 2048
    local PATH_STRAIGHTEN_LENIENCY = math.rad(10)


    local finalPathDrawArgs = {vertexCoords = {},textureCoords = {},shader = lockedShader,uniforms = {}}
    local finalPathDrawOldVertexCount = 0


    local pathImages = {}

    local pathRenderingDisabled = false


    local partsInPathTypes = {
        ["normal"]     = 3, -- middle, middle, end        (start is just flipped end)
        ["unique"]     = 4, -- middle, middle, end, start (for having unique start and ends)
        ["continuous"] = 2, -- middle, middle             (for having no start and end)
    }

    local pathConfig = {}

    function smwMap.getPathConfig(type)
        if pathConfig[type] == nil then
            -- Load config file
            local configPath = Misc.resolveFile("paths/".. type.. ".txt")

            if configPath ~= nil then
                config = configFileReader.rawParse(configPath,true)
            else
                config = {}
            end

            -- Load image
            local imagePath = Misc.resolveGraphicsFile("paths/".. type.. ".png")

            if imagePath ~= nil then
                config.image = Graphics.loadImage(imagePath)
            else
                pathRenderingDisabled = true
                Misc.warn("Path image '".. type.. "' does not exist.")
            end


            -- Initialise properties
            config.textureType = config.textureType or "normal"
            config.parts = partsInPathTypes[config.textureType]

            config.frames         = config.frames         or 1
            config.framespeed     = config.framespeed     or 8
            config.isWater        = config.isWater        or false
            config.isLadder       = config.isLadder       or false
            config.autoStraighten = config.autoStraighten or false

            if config.image ~= nil then
                config.partWidth  = config.image.width  / config.frames
                config.partHeight = config.image.height / config.parts
            else
                config.partWidth = 1
                config.partHeight = 1
            end

            pathConfig[type] = config
        end

        return pathConfig[type]
    end


    local function getPathLockedFade(pathObj,distance)
        if not smwMap.pathIsUnlocked(pathObj.name) then
            return 1
        end

        if pathObj.unlockingEventObj == nil then
            return 0
        end

        if pathObj.unlockingEventObj.direction == 1 then
            return math.clamp(math.floor(distance/smwMap.pathSettings.unlockAnimationDistance)+1 - pathObj.unlockingEventObj.pathProgress)
        else
            return math.clamp(math.floor((pathObj.splineLength-distance)/smwMap.pathSettings.unlockAnimationDistance)+1 - pathObj.unlockingEventObj.pathProgress)
        end
    end

    local function getPathLockedProgress(pathObj)
        if not smwMap.pathIsUnlocked(pathObj.name) then
            return 1
        end

        if pathObj.unlockingEventObj == nil then
            return 0
        end

        return math.min(0.9999, pathObj.unlockingEventObj.pathProgress / math.ceil(pathObj.splineLength / smwMap.pathSettings.unlockAnimationDistance))
    end


    local function getDistanceToNextPathType(pathObj,currentProgress,currentDistance,currentType)
        local lookAheadProgress = currentProgress
        local lookAheadDistance = currentDistance

        while (lookAheadProgress < 1 and lookAheadDistance < PATH_MAX_LENGTH) do
            local lookAheadPosition
            lookAheadProgress,lookAheadPosition = pathObj.splineObj:step(PATH_STEP, lookAheadProgress)

            lookAheadDistance = lookAheadDistance + PATH_STEP


            local lookAheadType = pathObj.types[math.floor(lookAheadPosition.z)]

            if lookAheadType ~= nil and lookAheadType ~= currentType then
                return lookAheadProgress * pathObj.splineLength
            end
        end

        return pathObj.splineLength
    end


    local function calculatePathVertexStuff(pathObj)
        local lockedProgress = getPathLockedProgress(pathObj)

        if pathObj.drawGroups ~= nil and lockedProgress == pathObj.lockedProgress then
            return
        end

        pathObj.lockedProgress = lockedProgress

        pathObj.drawGroups = {}
        pathObj.drawGroupCount = 0


        local currentProgress = 0
        local currentDistance = 0
        local stepIndex = 0

        local config

        local previousPosition,previousType,previousLockedFade
        local typeStartDistance,typeEndDistance

        while (currentProgress < 1 and currentDistance < PATH_MAX_LENGTH) do
            -- Move along the spline --
            local currentPosition

            if stepIndex > 0 then
                currentProgress,currentPosition = pathObj.splineObj:step(PATH_STEP, currentProgress)
                currentDistance = currentDistance + PATH_STEP
            else
                currentPosition = vector(pathObj.splineObj.x,pathObj.splineObj.y,0) + pathObj.splineObj.points[1]
            end


            -- Figure stuff out --
            local currentPointIndex = math.floor(currentPosition.z)
            local currentType = pathObj.types[currentPointIndex] or "normal"

            local currentLockedFade = getPathLockedFade(pathObj,currentDistance)


            if pathObj.drawGroupCount == 0 or currentType ~= previousType or currentLockedFade ~= previousLockedFade then
                local drawGroup = {}

                config = smwMap.getPathConfig(currentType)


                if pathRenderingDisabled then
                    return
                end


                drawGroup.texture = config.image

                drawGroup.vertexCoords = {}
                drawGroup.textureCoords = {}
                drawGroup.vertexCount = 0

                drawGroup.hideIfLocked = pathObj.hideIfLocked

                drawGroup.type = currentType

                if currentLockedFade < 1 or drawGroup.hideIfLocked then
                    drawGroup.target = smwMap.mainBuffer
                    drawGroup.lockedFade = currentLockedFade
                    drawGroup.priority = -60
                else -- fully locked, so goes into the special buffer
                    drawGroup.target = smwMap.lockedBuffer
                    drawGroup.lockedFade = 0
                    drawGroup.priority = -99
                end


                pathObj.drawGroupCount = pathObj.drawGroupCount + 1
                pathObj.drawGroups[pathObj.drawGroupCount] = drawGroup


                -- Figure out the distance to the next type change
                if pathObj.drawGroupCount == 0 or currentType ~= previousType then
                    typeStartDistance = currentDistance
                    typeEndDistance = getDistanceToNextPathType(pathObj,currentProgress,currentDistance,currentType)
                end
            end


            -- Figure more stuff out --
            local drawGroup = pathObj.drawGroups[pathObj.drawGroupCount]

            local width = config.partWidth
            local height = math.min(PATH_STEP,(typeEndDistance - (currentDistance - PATH_STEP)))

            local x = currentPosition.x
            local y = currentPosition.y

            local rotation

            if previousPosition ~= nil then
                rotation = math.atan2(currentPosition.y - previousPosition.y, currentPosition.x - previousPosition.x) + math.pi*0.5
            else
                local _,forwardPosition = pathObj.splineObj:step(1, currentProgress)

                rotation = math.atan2(forwardPosition.y - currentPosition.y, forwardPosition.x - currentPosition.x) + math.pi*0.5
            end


            if config.autoStraighten then
                for i = 0, math.pi*2 - 0.01, math.pi*0.25 do
                    if math.abs(i - rotation) <= PATH_STRAIGHTEN_LENIENCY then
                        rotation = i
                        break
                    end
                end
            end


            -- Set up vertex coords --
            local vc = drawGroup.vertexCoords
            local count = drawGroup.vertexCount

            local sinAngle = math.sin(rotation)
            local cosAngle = math.cos(rotation)

            local w1 = cosAngle*width*0.5
            local w2 = sinAngle*width*0.5
            local h1 = sinAngle*height
            local h2 = cosAngle*height


            local topLeftX,topLeftY,topRightX,topRightY

            if count > 0 then
                topLeftX  = vc[count - 11] -- previous one's bottom left
                topLeftY  = vc[count - 10]
                topRightX = vc[count - 9]  -- previous one's bottom right
                topRightY = vc[count - 8]
            elseif pathObj.drawGroupCount > 1 and previousType == currentType then
                local lastDrawGroup = pathObj.drawGroups[pathObj.drawGroupCount - 1]

                topLeftX  = lastDrawGroup.vertexCoords[lastDrawGroup.vertexCount - 11] -- previous one's bottom left
                topLeftY  = lastDrawGroup.vertexCoords[lastDrawGroup.vertexCount - 10]
                topRightX = lastDrawGroup.vertexCoords[lastDrawGroup.vertexCount - 9]  -- previous one's bottom right
                topRightY = lastDrawGroup.vertexCoords[lastDrawGroup.vertexCount - 8]
            else
                topLeftX  = math.floor(x - w1)
                topLeftY  = math.floor(y - w2)
                topRightX = math.floor(x + w1)
                topRightY = math.floor(y + w2)
            end

            vc[count+1]  = math.floor(x - h1 - w1) -- bottom left
            vc[count+2]  = math.floor(y + h2 - w2)
            vc[count+3]  = math.floor(x - h1 + w1) -- bottom right
            vc[count+4]  = math.floor(y + h2 + w2)
            vc[count+5]  = topLeftX                -- top left
            vc[count+6]  = topLeftY

            vc[count+7]  = math.floor(x - h1 + w1) -- bottom right
            vc[count+8]  = math.floor(y + h2 + w2)
            vc[count+9]  = topRightX               -- top right
            vc[count+10] = topRightY
            vc[count+11] = topLeftX                -- top left
            vc[count+12] = topLeftY


            -- Set up texture coords --
            local tc = drawGroup.textureCoords

            local textureHeight = drawGroup.texture.height

            local hasStartAndEnd = (config.textureType ~= "continuous")
            local startAndEndLength = math.min((typeEndDistance - typeStartDistance) * 0.5, config.partHeight)


            local x1 = 0
            local x2 = 1 / config.frames

            local y1,y2

            if currentType == "specialTest" then -- debug!
                y1 = (currentProgress)
                y2 = y1
            elseif currentDistance >= typeEndDistance-startAndEndLength and hasStartAndEnd then -- end
                y1 = ((config.partHeight * 3) - (typeEndDistance - currentDistance)) / textureHeight
                y2 = math.min(config.partHeight*3 / textureHeight,y1 + (height / textureHeight))
            elseif currentDistance <= typeStartDistance+startAndEndLength and hasStartAndEnd then -- start
                if config.textureType == "unique" then
                    y2 = ((config.partHeight*3) + (currentDistance - typeStartDistance)) / textureHeight
                    y1 = y2 - (height / textureHeight)
                else
                    y2 = (textureHeight - (currentDistance - typeStartDistance)) / textureHeight
                    y1 = y2 + (height / textureHeight)
                end
            else
                local distance = (currentDistance - typeStartDistance)
                if hasStartAndEnd then
                    distance = distance - startAndEndLength
                end

                y2 = ((distance % config.partHeight) + config.partHeight) / textureHeight
                y1 = y2 - (height / textureHeight)
            end


            tc[count+1]  = x1 -- bottom left
            tc[count+2]  = y2
            tc[count+3]  = x2 -- bottom right
            tc[count+4]  = y2
            tc[count+5]  = x1 -- top left
            tc[count+6]  = y1

            tc[count+7]  = x2 -- bottom right
            tc[count+8]  = y2
            tc[count+9]  = x2 -- top right
            tc[count+10] = y1
            tc[count+11] = x1 -- top left
            tc[count+12] = y1


            drawGroup.vertexCount = drawGroup.vertexCount + 12



            previousPosition = currentPosition
            previousType = currentType
            previousLockedFade = currentLockedFade

            stepIndex = stepIndex + 1
        end
    end


    local function roundWithRenderScale(a,scale)
        return math.floor(a * scale) / scale
    end

    --[[
    function smwMap.drawPath(pathObj)
        if pathObj.pointCount == 0 or (pathObj.hideIfLocked and not smwMap.pathIsUnlocked(pathObj.name)) then
            return
        end


        -- Culling
        --Graphics.drawBox{target = smwMap.mainBuffer,x = pathObj.minX - smwMap.camera.x,y = pathObj.minY - smwMap.camera.y,width = pathObj.maxX - pathObj.minX,height = pathObj.maxY - pathObj.minY,color = Color.red.. 0.15,priority = -10}

        if not isOnCamera(pathObj.minX,pathObj.minY,pathObj.maxX - pathObj.minX,pathObj.maxY - pathObj.minY) or pathRenderingDisabled then
            if pathObj.drawGroups ~= nil then
                -- The draw groups are deleted after enough time of being off screen, so they don't unnecessarily eat up memory
                pathObj.cachedLifetime = pathObj.cachedLifetime - 1

                --local p = pathObj.splineObj:evaluate(0)
                --Text.print(pathObj.cachedLifetime,p.x - smwMap.camera.x,p.y - smwMap.camera.y)

                if pathObj.cachedLifetime <= 0 then
                    pathObj.drawGroups = nil
                    pathObj.cachedLifetime = nil
                    return
                end
            end

            return
        end


        calculatePathVertexStuff(pathObj)


        pathObj.cachedLifetime = PATH_CACHED_TIME


        if pathRenderingDisabled then
            return
        end


        local args = finalPathDrawArgs
        local vc = args.vertexCoords
        local tc = args.textureCoords

        local renderScale = smwMap.pathSettings.renderScale

        local cameraX = roundWithRenderScale(smwMap.camera.x,renderScale)
        local cameraY = roundWithRenderScale(smwMap.camera.y,renderScale)


        local newBufferWidth  = SCREEN_WIDTH  + (1 / renderScale)
        local newBufferHeight = SCREEN_HEIGHT + (1 / renderScale)

        if smwMap.pathBuffer.width ~= newBufferWidth or smwMap.pathBuffer.height ~= newBufferHeight then
            smwMap.pathBuffer = Graphics.CaptureBuffer(newBufferWidth,newBufferHeight)
        end


        -- Set up for path buffer
        doBasicGlDrawSetup(smwMap.pathBuffer,cameraX - smwMap.camera.x,cameraY - smwMap.camera.y,smwMap.pathBuffer.width,smwMap.pathBuffer.height,0,0,smwMap.pathBuffer.width * renderScale,smwMap.pathBuffer.height * renderScale)

        --Text.printWP(cameraX - smwMap.camera.x,32,32,10)
        --Text.printWP(cameraY - smwMap.camera.y,32,64,10)


        for _,drawGroup in ipairs(pathObj.drawGroups) do
            -- Convert vertex coords to screen space rather than scene space, and account for frames with the texture coords
            local config = smwMap.getPathConfig(drawGroup.type)

            local groupVC = drawGroup.vertexCoords
            local groupTC = drawGroup.textureCoords
            local groupVertexCount = drawGroup.vertexCount

            for i = 1, groupVertexCount, 2 do
                vc[i  ] = (groupVC[i  ] - cameraX) * renderScale
                vc[i+1] = (groupVC[i+1] - cameraY) * renderScale

                if config.frames > 1 then
                    local frame = (math.floor(lunatime.tick() / config.framespeed) / config.frames) % 1

                    tc[i] = groupTC[i] + frame
                else
                    tc[i] = groupTC[i]
                end

                tc[i+1] = groupTC[i+1]
            end

            -- Delete old vertices from last draw
            for i = groupVertexCount+1, finalPathDrawOldVertexCount do
                vc[i] = nil
                tc[i] = nil
            end


            -- Set up some other stuff
            smwMap.pathBuffer:clear(drawGroup.priority)

            args.target = smwMap.pathBuffer

            args.texture = drawGroup.texture
            args.priority = drawGroup.priority

            args.shader = lockedShader
            args.uniforms.lockedFade = drawGroup.lockedFade
            args.uniforms.hideIfLocked = (drawGroup.hideIfLocked and 1) or 0


            Graphics.glDraw(args)


            finalPathDrawOldVertexCount = groupVertexCount

            -- Draw the path buffer to the screen
            basicGlDrawArgs.priority = drawGroup.priority
            basicGlDrawArgs.target = drawGroup.target

            Graphics.glDraw(basicGlDrawArgs)
        end

        basicGlDrawArgs.target = smwMap.mainBuffer
    end
    ]]

    smwMap.walkCycles = {}

    smwMap.walkCycles[CHARACTER_MARIO]           = {[PLAYER_SMALL] = {1,2, framespeed = 8},[PLAYER_BIG] = {1,2,3,2, framespeed = 6}}
    smwMap.walkCycles[CHARACTER_LUIGI]           = smwMap.walkCycles[CHARACTER_MARIO]
    smwMap.walkCycles[CHARACTER_PEACH]           = {[PLAYER_BIG] = {1,2,3,2, framespeed = 6}}
    smwMap.walkCycles[CHARACTER_TOAD]            = smwMap.walkCycles[CHARACTER_PEACH]
    smwMap.walkCycles[CHARACTER_LINK]            = {[PLAYER_BIG] = {4,3,2,1, framespeed = 6}}
    smwMap.walkCycles[CHARACTER_MEGAMAN]         = {[PLAYER_BIG] = {2,3,2,4, framespeed = 12}}
    smwMap.walkCycles[CHARACTER_WARIO]           = smwMap.walkCycles[CHARACTER_MARIO]
    smwMap.walkCycles[CHARACTER_BOWSER]          = smwMap.walkCycles[CHARACTER_TOAD]
    smwMap.walkCycles[CHARACTER_KLONOA]          = smwMap.walkCycles[CHARACTER_TOAD]
    smwMap.walkCycles[CHARACTER_NINJABOMBERMAN]  = smwMap.walkCycles[CHARACTER_PEACH]
    smwMap.walkCycles[CHARACTER_ROSALINA]        = smwMap.walkCycles[CHARACTER_PEACH]
    smwMap.walkCycles[CHARACTER_SNAKE]           = smwMap.walkCycles[CHARACTER_LINK]
    smwMap.walkCycles[CHARACTER_ZELDA]           = smwMap.walkCycles[CHARACTER_LUIGI]
    smwMap.walkCycles[CHARACTER_ULTIMATERINKA]   = smwMap.walkCycles[CHARACTER_TOAD]
    smwMap.walkCycles[CHARACTER_UNCLEBROADSWORD] = smwMap.walkCycles[CHARACTER_TOAD]
    smwMap.walkCycles[CHARACTER_SAMUS]           = smwMap.walkCycles[CHARACTER_LINK]

    smwMap.walkCycles["SMW-MARIO"] = {[PLAYER_SMALL] = {1,2, framespeed = 8},[PLAYER_BIG] = {3,2,1, framespeed = 6}}
    smwMap.walkCycles["SMW-LUIGI"] = smwMap.walkCycles["SMW-MARIO"]

    smwMap.walkCycles["ACCURATE-SMW-MARIO"] = smwMap.walkCycles["SMW-MARIO"]
    smwMap.walkCycles["ACCURATE-SMW-LUIGI"] = smwMap.walkCycles["SMW-MARIO"]
    smwMap.walkCycles["ACCURATE-SMW-TOAD"]  = smwMap.walkCycles["SMW-MARIO"]



    smwMap.hudCounters = {
        -- lives
        {
            getValue = (function()
                return mem(0x00B2C5AC,FIELD_FLOAT)
            end),
            x = 56, y = 28,
            formatString = "%2d",
        },
        -- Coins
        {
            getValue = (function()
                return mem(0x00B2C5A8,FIELD_WORD)
            end),
            x = 408, y = 12,
            formatString = "%2d",
        },
        -- Stars
        {
            getValue = (function()
                return mem(0x00B251E0,FIELD_WORD)
            end),
            x = 488, y = 12,
            formatString = "%3d",
        }
    }


    local function getImage(image)
        if type(image) == "table" then
            return image.img
        else
            return image
        end
    end


    local yoshiAnimationFrames = {
        {bodyFrame = 0,headFrame = 0,headOffsetX = 0 ,headOffsetY = 0,bodyOffsetX = 0,bodyOffsetY = 0,playerOffset = 0},
        {bodyFrame = 1,headFrame = 0,headOffsetX = -1,headOffsetY = 2,bodyOffsetX = 0,bodyOffsetY = 1,playerOffset = 1},
        {bodyFrame = 2,headFrame = 0,headOffsetX = -2,headOffsetY = 4,bodyOffsetX = 0,bodyOffsetY = 2,playerOffset = 2},
        {bodyFrame = 1,headFrame = 0,headOffsetX = -1,headOffsetY = 2,bodyOffsetX = 0,bodyOffsetY = 1,playerOffset = 1},
    }

    local bootBounceData = {}


    function smwMap.drawHUD()
        local hudSettings = smwMap.hudSettings

        if hudSettings.border.enabled and hudSettings.border.image ~= nil then
            Graphics.drawImageWP(hudSettings.border.image, 0, 0, hudSettings.priority)
        end

        local levelObj = smwMap.mainPlayer.levelObj

        -- Level title
        local levelTitleMaxWidth = 592

        if hudSettings.levelTitle.enabled then
            local levelTitle = ""
            if levelObj ~= nil then
                levelTitle = levelObj.settings.levelTitle or ""
            end

            textplus.render{
                layout = textplus.layout(levelTitle, levelTitleMaxWidth, {
                    font = hudSettings.levelTitle.font,
                    xscale = 2,
                    yscale = 2,
                }),
                color = Color.white,
                priority = 6,
                x = hudSettings.levelTitle.x,
                y = hudSettings.levelTitle.y,
            }
        end

        -- box
        Graphics.drawImageWP(hudSettings.box.image, hudSettings.box.x, hudSettings.box.y, hudSettings.priority);

        -- counters
        for _, c in ipairs(smwMap.hudCounters) do
            local text = string.format(c.formatString, c.getValue())
            textplus.render{
                layout = textplus.layout(text, 48, {
                    font = hudSettings.countersFont,
                    xscale = 2,
                    yscale = 2,
                }),
                priority = hudSettings.priority,
                x = hudSettings.box.x + c.x,
                y = hudSettings.box.y + c.y,
            }
        end

        -- starcoins
        if levelObj ~= nil then
            local starcoinCount = gameData.starcoinCounts[levelObj.settings.levelFilename]
            if starcoinCount ~= nil and starcoinCount > 0 then
                local starcoinData = starcoin.getLevelList(levelObj.settings.levelFilename) or {}
                for i = 1, starcoinCount do
                    local image = starcoinData[i] == 1 and hudSettings.starcoin.collectedImage
                                                        or hudSettings.starcoin.uncollectedImage
                    local x = hudSettings.box.x + hudSettings.starcoin.x + 16 * (i - 1) + 2
                    local y = hudSettings.box.y + hudSettings.starcoin.y
                    Graphics.drawImageWP(image, x, y, hudSettings.priority)
                end
            end
        end

        -- player icon
        Graphics.drawImageWP(
            hudSettings.playerIcon.image,
            hudSettings.box.x + hudSettings.playerIcon.x,
            hudSettings.box.y + hudSettings.playerIcon.y,
            0, (smwMap.mainPlayer.basePlayer.character - 1) * 14,
            32, 14,
            hudSettings.priority
        )

        -- area name
        textplus.render{
            layout = textplus.layout(smwMap.currentCameraArea.name, #smwMap.currentCameraArea.name * 16, {
                font = hudSettings.levelTitle.font,
                xscale = 2,
                yscale = 2,
            }),
            priority = hudSettings.priority,
            x = hudSettings.box.x + hudSettings.worldName.x,
            y = hudSettings.box.y + hudSettings.worldName.y,
        }
    end

    function smwMap.drawWorldCard()
        if smwMap.worldCard.state == WORLD_CARD_STATE.ON_CARD then
            local x = smwMap.camera.renderX + (smwMap.camera.width  - smwMap.worldCard.cardImage.width ) / 2
            local y = smwMap.camera.renderY + (smwMap.camera.height - smwMap.worldCard.cardImage.height) / 2
            Graphics.drawImageWP(smwMap.worldCard.cardImage, x, y, smwMap.hudSettings.priority)

            local areaNameWidth = #gameData.areaName * 16
            local areaNameX = (smwMap.worldCard.cardImage.width - areaNameWidth) / 2
            textplus.render{
                layout = textplus.layout(gameData.areaName, areaNameWidth, {
                    font = smwMap.hudSettings.levelTitle.font,
                    xscale = 2,
                    yscale = 2,
                }),
                priority = smwMap.hudSettings.priority,
                x = x + areaNameX,
                y = y + 24,
            }

            local characterNames = { "MARIO", "LUIGI", "PEACH", "TOAD " }
            textplus.render{
                layout = textplus.layout(characterNames[smwMap.mainPlayer.basePlayer.character], 5 * 16, {
                    font = smwMap.hudSettings.levelTitle.font,
                    xscale = 2,
                    yscale = 2,
                }),
                priority = smwMap.hudSettings.priority,
                x = x + 24,
                y = y + 70,
            }

            local lives = smwMap.hudCounters[1].getValue()
            textplus.render{
                layout = textplus.layout(string.format("×%2d", lives), 1000, {
                    font = smwMap.hudSettings.levelTitle.font,
                    xscale = 2,
                    yscale = 2,
                }),
                priority = smwMap.hudSettings.priority,
                x = x + 168,
                y = y + 72,
            }

            Graphics.drawImageWP(
                smwMap.playerSettings.images[player.character],
                x + 128, y + 58,
                0, 0, 32, 32,
                smwMap.hudSettings.priority
            )
        elseif smwMap.worldCard.state == WORLD_CARD_STATE.EXPANDING_STARS
            or smwMap.worldCard.state == WORLD_CARD_STATE.CLOSING_STARS then
            for i = 1, 8 do
                local angle = 360 / 8 * (i - 1) + smwMap.worldCard.starOffset
                local pos = smwMap.worldCard.center + vector(
                    math.sin(math.rad(angle)) * smwMap.worldCard.radius,
                    math.cos(math.rad(angle)) * smwMap.worldCard.radius
                )
                print("i = ", i, "pos = ", pos.x, pos.y)
                Graphics.drawImageWP(
                    smwMap.worldCard.starImage,
                    pos.x, pos.y,
                    0, smwMap.worldCard.starFrame * 32, 32, 32,
                    smwMap.hudSettings.priority
                )
            end
        end
    end

    local function drawLookAroundArrows()
        if lunatime.tick()%32 < 16 then
            return
        end


        local image = smwMap.playerSettings.lookAroundArrowImage

        local halfCameraSize = vector(smwMap.camera.width*0.5,smwMap.camera.height*0.5)

        for i = 0, 359, 90 do
            local position = halfCameraSize + (vector(0,-1):rotate(i) * (halfCameraSize-24))

            Graphics.drawBox{texture = image,target = smwMap.mainBuffer,priority = -6,centred = true,rotation = i,x = position.x,y = position.y}
        end
    end


    local backgroundShader = Shader()
    backgroundShader:compileFromFile(nil, Misc.resolveFile("smwMap/background.frag"))


    local backgroundConfig = {}

    function smwMap.getBackgroundConfig(name)
        if backgroundConfig[name] == nil then
            -- Load config file
            local configPath = Misc.resolveFile("backgrounds/".. name.. ".txt")
            local config

            if configPath ~= nil then
                config = configFileReader.rawParse(configPath,true)
            else
                config = {}
            end


            -- Get image
            local imagePath = Misc.resolveGraphicsFile("backgrounds/".. name.. ".png")

            if imagePath ~= nil then
                config.image = Graphics.loadImage(imagePath)
            else
                Misc.warn("Background image '".. name.. "' does not exist.")
            end

            config.frames = config.frames or 1
            config.framespeed = config.framespeed or 8

            config.speedX = config.speedX or 0
            config.speedY = config.speedY or 0

            config.parallaxX = config.parallaxX or 1
            config.parallaxY = config.parallaxY or 1

            config.priority = config.priority or -100

            backgroundConfig[name] = config
        end

        return backgroundConfig[name]
    end


    local function drawBackground(areaObj)
        local name = areaObj.backgroundName


        if name == "" then
            -- Draw flat colour
            Graphics.drawBox{
                target = smwMap.mainBuffer,color = smwMap.currentBackgroundArea.backgroundColor,priority = -101,
                x = 0,y = 0,width = smwMap.camera.width,height = smwMap.camera.height
            }

            return
        end


        local config = smwMap.getBackgroundConfig(name)

        if config.image == nil then
            return
        end

        local time = lunatime.tick()

        local screenSize = vector(smwMap.camera.width,smwMap.camera.height)

        local scrollPosition = vector(
            ((smwMap.camera.x - areaObj.collider.x) - math.floor(time*config.speedX)) * config.parallaxX,
            ((smwMap.camera.y - areaObj.collider.y) - math.floor(time*config.speedY)) * config.parallaxY
        )

        local currentFrame = math.floor(time / config.framespeed) % config.frames

        Graphics.drawBox{
            texture = config.image,target = smwMap.mainBuffer,priority = config.priority,
            x = 0,y = 0,width = screenSize.x,height = screenSize.y,
            shader = backgroundShader,uniforms = {
                scrollPosition = scrollPosition,
                screenSize = screenSize,

                textureSize = vector(config.image.width,config.image.height),
                frames = config.frames,
                currentFrame = currentFrame,
            },
        }
    end


    function smwMap.onCameraDraw()
        basicGlDrawArgs.target = smwMap.mainBuffer


        Graphics.drawBox{color = Color.black,target = smwMap.mainBuffer,x = 0,y = 0,width = smwMap.mainBuffer.width,height = smwMap.mainBuffer.height,priority = -101}


        -- Draw background
        if smwMap.currentBackgroundArea ~= nil then
            drawBackground(smwMap.currentBackgroundArea)
        end


        smwMap.lockedBuffer:clear(-100)


        -- Tiles / BGO's
        for _,v in ipairs(smwMap.tiles) do
            smwMap.drawTile(v)
        end

        -- Sceneries / blocks
        for _,v in ipairs(smwMap.sceneries) do
            smwMap.drawScenery(v)
        end

        --[[
        for _,pathObj in ipairs(smwMap.pathsList) do
            smwMap.drawPath(pathObj)
        end
        ]]

        for _,v in ipairs(smwMap.objects) do
            smwMap.drawObject(v)
        end


        for idx = #smwMap.players, 1, -1 do
            smwMap.drawPlayer(smwMap.players[idx])
        end


        if smwMap.startPointOpenProgress > 0 then
            smwMap.drawStartSelect()
        end


        -- Draw the locked buffer to the main buffer
        doBasicGlDrawSetup(smwMap.lockedBuffer,0,0,smwMap.lockedBuffer.width,smwMap.lockedBuffer.height,0,0,smwMap.lockedBuffer.width,smwMap.lockedBuffer.height)

        basicGlDrawArgs.priority = -80

        basicGlDrawArgs.shader = lockedShader
        basicGlDrawArgs.uniforms = {
            hideIfLocked = 0,
            lockedFade = 1,

            lockedPathColor = smwMap.pathSettings.lockedColor,
        }

        Graphics.glDraw(basicGlDrawArgs)

        basicGlDrawArgs.shader = nil
        basicGlDrawArgs.uniforms = nil


        if smwMap.mainPlayer.lookAroundState == LOOK_AROUND_STATE.ACTIVE then
            drawLookAroundArrows()
        end


        -- Finally, draw the buffer to the screen
        if not smwMap.fullBufferView then
            Graphics.drawBox{
                texture = smwMap.mainBuffer,priority = -5.01,

                x = smwMap.camera.renderX,
                y = smwMap.camera.renderY,
                sourceX = 0,sourceY = 0,

                width = smwMap.camera.width,height = smwMap.camera.height,
                sourceWidth = smwMap.camera.width,sourceHeight = smwMap.camera.height,
            }

            smwMap.drawHUD()
        else
            Graphics.drawBox{texture = smwMap.mainBuffer,x = 0,y = 0,priority = -5.01}
        end

        smwMap.drawWorldCard()
    end

    function smwMap.onCameraUpdate()
        if smwMap.mainPlayer.lookAroundState == LOOK_AROUND_STATE.INACTIVE then
            smwMap.camera.x,smwMap.camera.y = getUsualCameraPos()
        else
            smwMap.camera.x = smwMap.mainPlayer.lookAroundX
            smwMap.camera.y = smwMap.mainPlayer.lookAroundY
        end
    end
end


-- Music
do
    smwMap.defaultMusicPaths = {
        "music/smw-yoshisisland.spc|0;g=2.7;",
        "music/smw-worldmap.spc|0;g=2.7;",
        "music/smw-vanilladome.spc|0;g=2.7;",
        "music/smw-forestofillusion.spc|0;g=2.7;",
        "music/smw-bowserscastle.spc|0;g=2.7;",
        "music/smw-starroad.spc|0;g=2.7;",
        "music/smw-special.spc|0;g=2.7;",
        "music/smb3-world1.spc|0;g=2.7;",
        "music/smb3-world2.spc|0;g=2.7;",
        "music/smb3-world3.spc|0;g=2.7;",
        "music/smb3-world4.spc|0;g=2.7;",
        "music/smb3-world5.spc|0;g=2.7;",
        "music/smb3-world6.spc|0;g=2.7;",
        "music/smb3-world7.spc|0;g=2.7;",
        "music/smb3-world8.spc|0;g=2.7;",
    }

    smwMap.currentlyPlayingMusic = nil

    smwMap.forceMutedMusic = false


    local function getMusicPath(music)
        if type(music) == "string" then
            return Misc.episodePath().. music
        else
            return getSMBXPath().. "/".. smwMap.defaultMusicPaths[music]
        end
    end


    function smwMap.updateMusic()
        local newMusic = 0
        if smwMap.currentMusicArea ~= nil and not smwMap.forceMutedMusic then
            newMusic = smwMap.currentMusicArea.music
        end

        if smwMap.currentlyPlayingMusic ~= newMusic then
            if newMusic ~= 0 then
                Audio.MusicOpen(getMusicPath(newMusic))
                Audio.MusicPlay()
            else
                Audio.MusicStop()
            end

            smwMap.currentlyPlayingMusic = newMusic
        end

        if smwMap.mainPlayer.state == PLAYER_STATE.SELECTED then
            Audio.MusicVolume(math.max(0,Audio.MusicVolume() - 2))

            if Audio.MusicVolume() == 0 then
                Audio.MusicPause()
            end
        else
            Audio.MusicVolume(64)
        end
    end
end



function smwMap.onTick()
    if #smwMap.activeEvents > 0 then
        updateEvent(smwMap.activeEvents[1])
    end
end

function smwMap.onDraw()
    if Misc.isPaused() and unlockLoopObj ~= nil and unlockLoopObj:isPlaying() then
        unlockLoopObj:pause()
    end
end


-- Cheats!
do
    Cheats.register("imtiredofallthiswalking", {
        onActivate = function()
            --[[
            for _,pathObj in ipairs(smwMap.pathsList) do
                if smwMap.isOnCamera(pathObj.minX,pathObj.minY,pathObj.maxX - pathObj.minX,pathObj.maxY - pathObj.minY) then
                    smwMap.unlockPath(pathObj.name,vector(smwMap.mainPlayer.x,smwMap.mainPlayer.y))
                else
                    smwMap.unlockPath(pathObj.name)
                end
            end

            return true
            ]]
        end,
        activateSFX = 27,
    })

    Cheats.register("illparkwhereiwant", {
        onActivate = (function()
            if smwMap.mainPlayer.state == PLAYER_STATE.NORMAL then
                smwMap.mainPlayer.state = PLAYER_STATE.PARKING_WHERE_I_WANT
                smwMap.mainPlayer.timer = 0
                smwMap.mainPlayer.timer2 = 0
                SFX.play(13)
            end
            return true
        end),
        aliases = {"speenmerightround"},
    })
end


return smwMap
