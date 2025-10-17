
--[[
				   smb3HUD.lua by John Nameless
				A HUD script designed to replicate
				the UI of the all-stars version of 
					   Super Mario Bros. 3
			
	CREDITS:
	Barack Obama - ripped various sprites from SMAS-SMB3's HUD used here. (https://www.spriters-resource.com/snes/smassmb3/sheet/205518/)
	MrDoubleA & Chipps - taught me how to properly use vertex/textureCoords for Graphics.glDraw()
					   - borrowed chunks of code from MrDoubleA's SMW Costumes scripts specifically
	Sleepy - made the miniature SMB2 Heart Sprite used here.
	VannyArts - made the large starcoin sprite icon used whenever you have the cardType set to smb3HUD.TYPE_STARCOINS 
	
	TO DO:
	- Implement multiplayer + split-screen support, whenever you have the motivation to do so.
	- Make the cards more customizable without the need of touching the source code of this HUD.
]]--

local tplus = require("textplus")
local starcoin = require("npcs/ai/starcoin")

local smb3HUD = {}

GameData.smb3HUD = GameData.smb3HUD or {}
local gamedata = GameData.smb3HUD
gamedata.goalList = gamedata.goalList or table.map{}
local canResetList = false 

local lastBigValues = nil
local bigBoxLayout = nil
local lastSmallValues = {}
local smallBoxLayouts = {}
 
local runspeed = 0
local pSpeed = 0
 
smb3HUD.TYPE_NONE = -1		-- disables the 3 cards from displaying entirely
smb3HUD.TYPE_SMBXHUD = 0	-- makes the 3 card squares have extra information the stock SMBX HUD has
smb3HUD.TYPE_ROULETTE = 1 	-- makes the 3 card squares have the collected card types when getting a SMB3 Card Roulette Goal
smb3HUD.TYPE_STARCOINS = 2	-- makes the 3 card squares only have collected starcoins

smb3HUD.toggles = {
	lives = true,
	score = true,
	coins = true,
	timer = true,
	world = true,
	pSpeed = true,
	cardType = smb3HUD.TYPE_SMBXHUD,
}

smb3HUD.currentWorld = 0
smb3HUD.heartsIMG = Graphics.loadImageResolved("smb3HUD/hearts.png")
smb3HUD.pSpeedIMG = Graphics.loadImageResolved("smb3HUD/pspeedBar.png")
smb3HUD.statusBarIMG = Graphics.loadImageResolved("smb3HUD/statusBar.png")
smb3HUD.lifeIconIMG = Graphics.loadImageResolved("smb3HUD/lifeIcons.png")
smb3HUD.starcoinIMG = Graphics.loadImageResolved("smb3HUD/starcoin.png")
smb3HUD.starcoinMiniIMG = Graphics.loadImageResolved("smb3HUD/starcoin-mini.png")
smb3HUD.rouletteIconIMG = Graphics.loadImageResolved("smb3HUD/rouletteIcons.png")

smb3HUD.pSpeedSFX = SFX.open(Misc.resolveSoundFile("smb3HUD/p-speed.ogg"))
smb3HUD.hudFont = tplus.loadFont("smb3HUD/smb3-font.ini")

smb3HUD.rouletteOneUps = { -- how many one ups will be obtained depedning on the tier of the 3 matching cards
	[1] = 2,
	[2] = 3,
	[3] = 4
}

------------- taken straight from MrDoubleA's SMW Costumes -------------
local characterSpeedModifiers = {
	[CHARACTER_PEACH] = 0.93,
	[CHARACTER_TOAD]  = 1.07,
}
local characterNeededPSpeeds = {
	[CHARACTER_MARIO] = 35,
	[CHARACTER_LUIGI] = 40,
	[CHARACTER_PEACH] = 80,
	[CHARACTER_TOAD]  = 60,
	[CHARACTER_LINK] = 10,
}

-- Detects if the player is on the ground, the redigit way. Sometimes more reliable than just p:isOnGround().
local function isOnGround(p)
	return (
		p.speedY == 0 -- "on a block"
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function canBuildPSpeed(p)
	return (
		p.forcedState == FORCEDSTATE_NONE
		and p.deathTimer == 0 and not p:mem(0x13C,FIELD_BOOL) -- not dead
		and p.mount ~= MOUNT_BOOT and p.mount ~= MOUNT_CLOWNCAR
		and not p.climbing
		and not p:mem(0x0C,FIELD_BOOL) -- fairy
		and not p:mem(0x44,FIELD_BOOL) -- surfing on a rainbow shell
		and not p:mem(0x4A,FIELD_BOOL) -- statue
		and p:mem(0x34,FIELD_WORD) == 0 -- underwater
	)
end
------------------------------------------------------------------------

smb3HUD.getValue = {
	["lives"] = function()
		local lives = "   "
		if smb3HUD.toggles.lives then
			lives = "x"..string.format("%.2d",mem(0x00B2C5AC,FIELD_FLOAT))
		end
		return lives
	end,
	["score"] = function()
		local score = "       "
		if smb3HUD.toggles.score then
			score = string.format("%.7d",Misc.score())
		end
		return score
	end,
	["coins"] = function()
		local coins = "  "
		if smb3HUD.toggles.coins then
			coins = "c"..string.format("%.2d",Misc.coins())
		end
		return coins
	end,
	["timer"] = function()
		local timer = ""
		if smb3HUD.toggles.timer and Timer.isVisible() then
			timer = "	t"..string.format("%.3d",Timer.getValue())
		end
		return timer
	end,
	["world"] = function()
		local world = "      "
		if smb3HUD.toggles.world then
			world = "W" .. smb3HUD.currentWorld
			if smb3HUD.currentWorld <= 9 then
				world = world .. " "
			end
		end
		return world
	end,
	["reserve"] = function()
		return player.reservePowerup
	end,
	["health"] = function()
		return math.min(player:mem(0x16, FIELD_WORD) - 1,3)
	end,
	["starcoins"] = function()
		if smb3HUD.toggles.cardType == smb3HUD.TYPE_SMBXHUD then
			return tostring(starcoin.getLevelCollected())
		elseif smb3HUD.toggles.cardType == smb3HUD.TYPE_STARCOINS then
			return starcoin.getLevelList(Level.filename())
		end
		return nil
	end
}

function smb3HUD.drawStatusBox(x,y,width,priority)
	width = width or 1
	local img = smb3HUD.statusBarIMG
	local portion = img.width/3
	local middleX = x+portion
	local endX = middleX + (portion*width)
	Graphics.glDraw{
		texture = img,
		vertexCoords = {
			------- STARTING PORTION -------
			-- FRIST TRIANGLE
			-- top left
			x,	y,
			-- top right
			middleX,	y,
			-- bottom left
			x,	y + img.height,
			
			-- SECOND TRIANGLE
			-- top right
			middleX,	y,
			-- bottom left
			x,	y + img.height,
			-- bottom right
			middleX,	y + img.height,
		
			------- MIDDLE PORTION -------
			-- FRIST TRIANGLE
			-- top left
			middleX,	y,
			-- top right
			endX,	y,
			-- bottom left
			middleX,	y + img.height,
			
			-- SECOND TRIANGLE
			-- top right
			endX,	y,
			-- bottom left
			middleX,	y + img.height,
			-- bottom right
			endX,	y + img.height,
			
			------- ENDING PORTION -------
			-- FRIST TRIANGLE
			-- top left
			endX,	y,
			-- top right
			endX + portion,	y,
			-- bottom left
			endX,	y + img.height,
			
			-- SECOND TRIANGLE
			-- top right
			endX + portion,	y,
			-- bottom left
			endX,	y + img.height,
			-- bottom right
			endX + portion,	y + img.height,
		},
		textureCoords = {
			------- STARTING PORTION -------
			-- FRIST TRIANGLE
			-- top left
			0,	0,
			-- top right
			portion/img.width, 0,
			-- bottom left
			0,	1,
			
			-- SECOND TRIANGLE
			-- top right
			portion/img.width, 0,
			-- bottom left
			0,	1,
			-- bottom right
			portion/img.width,	1,
		
			------- MIDDLE PORTION -------
			-- FRIST TRIANGLE
			-- top left
			portion/img.width, 0,
			-- top right
			(portion*2)/img.width, 0,
			-- bottom left
			portion/img.width,	1,
			
			-- SECOND TRIANGLE
			-- top right
			(portion*2)/img.width,	0,
			-- bottom left
			portion/img.width,	1,
			-- bottom right
			(portion*2)/img.width,	1,
			
			------- ENDING PORTION -------
			-- FRIST TRIANGLE
			-- top left
			(portion*2)/img.width,	0,
			-- top right
			1,	0,
			-- bottom left
			(portion*2)/img.width,	1,
			
			-- SECOND TRIANGLE
			-- top right
			1,	0,
			-- bottom left
			(portion*2)/img.width,	1,
			-- bottom right
			1,	1,
		},
		priority = priority - 0.01
	}
end

local function differentValues(newValues)
	return (
		lastBigValues.lives ~= newValues.lives
		or lastBigValues.score ~= newValues.score
		or lastBigValues.coins ~= newValues.coins
		or lastBigValues.timer ~= newValues.timer
		or lastBigValues.world ~= newValues.world
	)
end

local function updateLayout(txt)
	local layout = tplus.layout(
		tplus.parse(
			txt,
			{
				font = smb3HUD.hudFont, 
				xscale = 2,
				yscale = 2,
			}
		)
	)
    return layout
end

function smb3HUD.drawHUD(idx,priority,isSplit)
	local toggle = smb3HUD.toggles
	local cam = Camera(idx)
	centerX = cam.width/2
	centerY = cam.height/2
		
	if isSplit and cam.idx == 1 then
		centerY = centerY * 2
	end
	
	Graphics.drawBox{
		x=0,
		y=cam.height - 64,
		width = cam.width,
		height = 64,
		color = Color.black,
		priority = priority - 0.02,
	}
	
	local bigBoxCoords = {
		x = centerX-232,
		y = cam.height-60
	}
	if smb3HUD.toggles.cardType == smb3HUD.TYPE_NONE then  
		bigBoxCoords.x = centerX - 152
	end
	-- Big Status Box + Life Icons
	smb3HUD.drawStatusBox(bigBoxCoords.x,bigBoxCoords.y,17,priority,false)
	if toggle.lives then
		Graphics.drawImageWP(
			smb3HUD.lifeIconIMG,
			bigBoxCoords.x + 8,
			bigBoxCoords.y + 30,
			0,
			smb3HUD.lifeIconIMG.height/16 * (player.character - 1),
			smb3HUD.lifeIconIMG.width,
			smb3HUD.lifeIconIMG.height/16,
			1,
			priority
		)
	end
	
	-- P-Speed
	if toggle.pSpeed then 
		Graphics.drawImageWP(
			smb3HUD.pSpeedIMG,
			bigBoxCoords.x + 104,
			bigBoxCoords.y + 12,
			0,
			smb3HUD.pSpeedIMG.height/8 * math.floor(runspeed),
			smb3HUD.pSpeedIMG.width,
			smb3HUD.pSpeedIMG.height/8,
			1,
			priority
		)
	end

	local values = {
		lives = smb3HUD.getValue["lives"](),
		score = smb3HUD.getValue["score"](),
		coins = smb3HUD.getValue["coins"](),
		timer = smb3HUD.getValue["timer"](),
		world = smb3HUD.getValue["world"](),
	}
	
	if lastBigValues == nil or differentValues(values) then
		bigBoxLayout = updateLayout(tostring(values.world.."         "..values.coins.. "\n  "..values.lives.." "..values.score..values.timer))
		lastBigValues = values
	end
	
	tplus.render{
		x = bigBoxCoords.x + 8,
		y = bigBoxCoords.y + 10,
		layout = bigBoxLayout,
		priority = priority
	}
	
	if smb3HUD.toggles.cardType == smb3HUD.TYPE_NONE then return end
	for i=1,3 do
		local tinyBoxcoords = vector((centerX+88)+(smb3HUD.statusBarIMG.width * (i-1)),cam.height-60)
		smb3HUD.drawStatusBox(tinyBoxcoords.x,tinyBoxcoords.y,1,priority,false)
		if smb3HUD.toggles.cardType == smb3HUD.TYPE_SMBXHUD then
			local args = {
				img = nil,
				x = tinyBoxcoords.x + 8,
				y = tinyBoxcoords.y + 12, 
				sourceX = 0,
				sourceY = 0,
				sourceWidth = 0,
				sourceHeight = 0,
			}
			if i == 1 then
				if Graphics.getHUDType(player.character) == Graphics.HUD_ITEMBOX  -- Handles getting the RESERVE POWERUP a player has
				and player.reservePowerup > 0 then
					local reserveID = smb3HUD.getValue["reserve"]()
					local config = NPC.config[reserveID]
					local gfxwidth = config.gfxwidth
					local gfxheight = config.gfxheight
					if gfxwidth == 0 then
						gfxwidth = config.width
					end
					if gfxheight == 0 then
						gfxheight = config.height
					end
					args.img = Graphics.sprites.npc[reserveID].img
					args.x = (args.x + 16) - (gfxwidth/2)
					args.y = (args.y + 16) - (gfxheight/2)
					args.sourceWidth = gfxwidth
					args.sourceHeight = gfxheight
				elseif Graphics.getHUDType(player.character) == Graphics.HUD_HEARTS then -- Handles getting the amount of HEARTS a player has
					local hp = smb3HUD.getValue["health"]()
					args.x = args.x - 4
					args.y = args.y - 4
					args.img = smb3HUD.heartsIMG
					args.sourceWidth = args.img.width
					args.sourceHeight = args.img.height/3
					args.sourceY = args.sourceHeight * hp
				end
			else 
				local txt = ""
				local yOffset = 18
				if i == 2 and mem(0x00B251E0,FIELD_WORD) > 0 then -- handles getting the amount of POWER-STARS a player has
					args.img = Graphics.sprites.hardcoded["33-5"].img
					args.y = args.y + 2
					yOffset = 14
					txt = tostring(mem(0x00B251E0,FIELD_WORD))
				elseif i == 3 and #starcoin.getLevelList(Level.filename()) > 0 then -- handles getting the amount of STARCOINS a player has
					args.img = smb3HUD.starcoinMiniIMG
					args.y = args.y - 2
					txt = smb3HUD.getValue["starcoins"]()
				end
				if lastSmallValues[i] == nil or lastSmallValues[i] ~= txt then
					smallBoxLayouts[i] = updateLayout(txt)
					lastSmallValues[i] = txt
				end
				if args.img ~= nil then
					args.sourceWidth = args.img.width
					args.sourceHeight = args.img.height
					if txt ~= "" then
						tplus.render{
							x = (args.x + 32) - 1*smallBoxLayouts[i].width,
							y = args.y + yOffset,
							layout = smallBoxLayouts[i],
							priority = priority
						}	
					end
				end
			end
			if args.img ~= nil then
				Graphics.drawImageWP(
					args.img, 
					args.x, 
					args.y, 
					args.sourceX, 
					args.sourceY, 
					args.sourceWidth, 
					args.sourceHeight, 
					1, 
					priority
				) 
			end
		elseif smb3HUD.toggles.cardType == smb3HUD.TYPE_ROULETTE and gamedata.goalList[i] ~= nil then -- handles drawing the ROULETTE CARDS a player has
			Graphics.drawImageWP(
				smb3HUD.rouletteIconIMG,
				tinyBoxcoords.x + 8,
				tinyBoxcoords.y + 12,
				0,
				smb3HUD.rouletteIconIMG.height/3 * (gamedata.goalList[i] - 1),
				smb3HUD.rouletteIconIMG.width,
				smb3HUD.rouletteIconIMG.height/3,
				1,
				priority
			)
		elseif smb3HUD.toggles.cardType == smb3HUD.TYPE_STARCOINS then -- handles filling the 3 slots with a STARCOIN if obtained
			for coinIDX, v in ipairs(smb3HUD.getValue["starcoins"]()) do
				if coinIDX == i and v ~= 0 then
					Graphics.drawImageWP(
						smb3HUD.starcoinIMG, 
						tinyBoxcoords.x + 24 - (smb3HUD.starcoinIMG.width/2),
						tinyBoxcoords.y + 28 - (smb3HUD.starcoinIMG.height/2), 
						0, 
						0, 
						smb3HUD.starcoinIMG.width, 
						smb3HUD.starcoinIMG.height, 
						1, 
						priority
					) 
				end
			end
		end
	end
end

function smb3HUD.onInitAPI()
	Graphics.overrideHUD(smb3HUD.drawHUD)
	registerEvent(smb3HUD,"onTickEnd")
	registerEvent(smb3HUD,"onPostNPCCollect")
	registerEvent(smb3HUD,"onExitLevel")
end

function smb3HUD.onTickEnd() -- handles incrementing/decrementing the p-meter + p-speed
	if Level.endState() ~= 0 then runspeed = 0 return end
	if not smb3HUD.toggles.pSpeed then return end
	local speedcap = Defines.player_runspeed
	local p = player
	local reachedPSpeed = pSpeed >= (characterNeededPSpeeds[p.character] or 35)
	local isFlying = p:mem(0x16C,FIELD_BOOL) or p:mem(0x16E,FIELD_BOOL)
	local speedX = math.abs(p.speedX)
	if speedX <= 0 and isOnGround(p) then
		runspeed = 0
	end
	if not isFlying and not reachedPSpeed then -- handles the p-meter arrows
		for i=0,6 do
			if speedX ~= 0 and speedX > speedcap * (i * 0.155)  then
				runspeed = i
			else
				break
			end
		end
	end
	if canBuildPSpeed(p) then -- handles p-speed itself
		if isOnGround(p) then
			if p.powerup == 4 or p.powerup == 5 then
				reachedPSpeed = isFlying
			elseif runspeed >= speedcap 
			and math.abs(p.speedX) >= speedcap*(characterSpeedModifiers[p.character] or 1) then
				pSpeed = math.min(characterNeededPSpeeds[p.character] or 35,pSpeed + 1)
			else
				pSpeed = math.max(0,pSpeed - 0.3)
			end
		end
		if (reachedPSpeed or isFlying) then
			if lunatime.tick() % 8 == 0 then
				SFX.play(smb3HUD.pSpeedSFX)
			end
			runspeed = 6 + (1 * (math.floor(lunatime.tick() * 0.125) % 2))
		end
	else
		pSpeed = 0
	end
end

function smb3HUD.onPostNPCCollect(v,p) -- handles recreating SMB3's card roulette system
	if smb3HUD.toggles.cardType ~= smb3HUD.TYPE_ROULETTE then return end
	if v.id ~= 11 then return end
	local tier = v.animationFrame
	if tier == 0 then
		if NPC.config[v.id].frames ~= 0 then
			tier = NPC.config[v.id].frames
		else
			tier = 3
		end
	end
	local list = gamedata.goalList
	table.insert(list,tier)
	
	if #list < 3 then return end
	Audio.sounds[19].muted = true
	local firstSlot
	local fullyMatched = true
	for i=1,#gamedata.goalList do
		if i == 1 then
			firstSlot = gamedata.goalList[i]
		elseif gamedata.goalList[i] ~= firstSlot then
			fullyMatched = false
			break
		end
	end
	local giveDelay = 0
	if tier >= 3 then -- done to have a delay before the 1up giving if a player got another 1up from a star card
		giveDelay = 35
	end
	local oneUpsGiven = 0
	if fullyMatched then
		oneUpsGiven = smb3HUD.rouletteOneUps[firstSlot]
		SFX.play(21)
	else
		if tier < 3 then
			oneUpsGiven = 1
		end
		SFX.play(52)
	end
	Routine.run(function()
		local vect = vector(v.x+v.width*0.5,v.y+v.height*0.5)
		Routine.waitFrames(giveDelay)
		Audio.sounds[19].muted = false
		for i=1,oneUpsGiven do
			Misc.givePoints(SCORE_1UP,vect)
			Routine.waitFrames(35)
		end
	end)
	canResetList = true
end

function smb3HUD.onExitLevel(winType)
	if canResetList then
		gamedata.goalList = nil
	end
end

return smb3HUD