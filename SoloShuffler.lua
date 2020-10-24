-- Define Globals
diff = 0			-- Current frame
lowTime = 5		-- Min shuffle time
highTime = 30	-- Max shuffle time
timeLimit = 5 -- Current time limit
newGame = 0

romSet = {}

gamePath = ".\\CurrentROMs\\"
settingsPath = "settings.xml"

currentChangeCount = 0	-- Num times a game has been swapped to
currentGame = 1

saveOldTime = 0
savePlayCount = 0

countdown = false;	-- Countdown is disabled by default
buffer = 0					-- Buffer for countdown graphics

if userdata.get("countdown") ~= nil then
	countdown = userdata.get("countdown")
end

if userdata.get("currentChangeCount") ~= nil then -- Syncs up the last time settings changed so it doesn't needlessly read the CurrentROMs folder again.
	currentChangeCount = userdata.get("currentChangeCount")
end
databaseSize = userdata.get("databaseSize")

function openCurrentTime(rom)
	-- Read playtime of current game from file
	local oldTime = io.open(".\\TimeLogs\\" .. currentGame .. ".txt","a+")
	local readOldTimeString = oldTime:read("*line")
	local readOldTime = "0"
	if readOldTimeString ~= nil then
		readOldTime = readOldTimeString
	end
	oldTime:close()
	saveOldTime = readOldTime

	-- Read playcount of current game from file
	local oldCount = io.open(".\\PlayCount\\" .. currentGame .. ".txt","a+")
	local readOldCountString = oldCount:read("*line")
	local  readOldCount = 0
	if readOldCountString ~= nil then
		readOldCount = tonumber(readOldCountString)
	end
	oldCount:close()
	savePlayCount = readOldCount + 1

	-- Update database with time and count info
	romDatabase = io.open("CurrentGameTime.txt","w")
	romDatabase:write(gameinfo.getromname() .. " play time: " .. saveOldTime)
	romDatabase:close()
	timeDatabase = io.open("CurrentGameSwitchCount.txt","w")
	timeDatabase:write(savePlayCount)
	timeDatabase:close()

end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function dirLookup(directory) -- Reads all ROM names in the CurrentROMs folder.
	local i = 0
	for directory in io.popen([[dir ".\CurrentROMs" /b]]):lines() do
		if ends_with(directory, ".bin") then
			console.log("SKIP: " .. directory)
		else
			console.log("ROM: " .. directory)
			i = i + 1
			userdata.set("rom" .. i,directory)
			romSet[i] = directory
		end
	end
	databaseSize = i
	console.log("databaseSize is " .. databaseSize .. " roms!")
end

function getSettings(filename) -- Gets the settings saved by the RaceShufflerSetup.exe
	local fp = io.open(filename, "r" ) -- Opens settings.xml
	if fp == nil then 
		return nil
	end
	settingsName = {}
	settingsValue = {}
	newLine = "a"
	newSetting = "a"
	k = 1
	for line in fp:lines() do -- Gets lines from the settings xml.
		newLine = string.match(line,'%l+%u*%l+')
		newSetting = string.match(line,'%p%a+%p(%w+)')
		if newLine ~= "settings" then
			settingsValue["value" .. k] = newSetting
			k = k + 1
		end
			
	end
	fp:close() -- Closes settings.xml
	lowTime = settingsValue["value2"] -- Stores minimum value
	highTime = settingsValue["value3"] -- Stores maximum value
	changedRomCount = tonumber(settingsValue["value6"]) -- Stores value indicating if ROMs have been changed
	if settingsValue["value5"] == "true" then
		countdown = true
	else
		countdown = false
		console.log(tostring(settingsValue["value5"]))
	end	
end

if databaseSize ~= nil then
	currentGame = userdata.get("currentGame")
	openCurrentTime(rom)
	console.log("Current Game: " .. currentGame)
	lowTime = userdata.get("lowTime")
	highTime = userdata.get("highTime")
	seed = (userdata.get("seed"))
	math.randomseed(seed)
	math.random()
	if lowTime ~= highTime then
		timeLimit = math.random(lowTime * 60,highTime * 60)
	else
		timeLimit = tonumber(highTime * 60)
	end
else 
	getSettings(settingsPath)
	timeLimit = 5
	dirLookup(directory)
	seed = settingsValue["value4"]
	math.randomseed(seed)
	math.random()
	console.log("Initial seed " .. seed)
end

function getRomList()
	-- local i = 0
	for i=0, databaseSize do
		-- i = i + 1
		romSet[i] = userdata.get("rom" .. i)
	end
end

getRomList()

console.log("Time Limit " .. timeLimit)

--Commenting delay out until we implement it in the setup bot. Feel free to use it yourself.
--[[


-- Pause after a swap
sound = client.GetSoundOn()
client.SetSoundOn(false)
client.sleep(500)  -- TODO: This should be configurable
client.SetSoundOn(sound)
]]

function cleanup()
	userdata.clear()
	do return end
end

function nextGame(game) -- Changes to the next game and saves the current settings into userdata
	if databaseSize > 0 then
		getSettings(settingsPath)
		diff = 0
		if currentChangeCount < changedRomCount then -- Only do dirLookup() if settings have changed
			dirLookup(directory)
			currentChangeCount = changedRomCount
		end
		if databaseSize == 1 then
			dirLookup(directory)
			newGame = romSet[1]
		else
			local randNumber = math.random(1,databaseSize)
			if romSet[randNumber] ~= nil then
				newGame = romSet[randNumber]
				-- console.log("Random Number" .. randNumber .. " was in range")
				-- console.log("Size of romSet: " .. #romSet .. " Size of database: " .. databaseSize)
			else
				-- console.log("Random Number was out of range")
				dirLookup(directory)
				newGame = userdata.get("rom" .. randNumber)
				--console.log("Ran dirLookup()")
			end
			while currentGame == newGame or newGame == nil do
				randNumber = math.random(1,databaseSize)
				newGame = romSet[randNumber]
				console.log("Reroll! " .. randNumber)
			end
		end
		currentGame = newGame
		userdata.set("first",1)
		savestate.saveslot(1)
		client.openrom(gamePath .. currentGame)
		savestate.loadslot(1)
		console.log(currentGame .. " loaded!")
		userdata.set("currentGame",currentGame)
		userdata.set("timeLimit",timeLimit)
		romDatabase = io.open("CurrentROM.txt","w")
		romDatabase:write(gameinfo.getromname())
		romDatabase:close()
		--console.log(emu.getsystemid())
		randIncrease = math.random(1,20)
		userdata.set("seed",seed + randIncrease) -- Changes the seed so the next game/time don't follow a pattern.
		userdata.set("currentChangeCount",currentChangeCount)
		userdata.set("databaseSize",databaseSize)
		userdata.set("lowTime",lowTime)
		userdata.set("highTime",highTime)
		userdata.set("consoleID",emu.getsystemid())
		userdata.set("countdown",countdown)
		
		setRomList()
	end	
end

function setRomList()
	console.log("Updating Database...")
	for x=0, databaseSize do
		userdata.set("rom" .. x, romSet[x])
	end
end

function setBuffer()
	buffer = 0 -- Sets countdown location. Adding 8 makes it appear correct for the NES.
	if emu.getsystemid() == "NES" then
		buffer = 8
	end
end

setBuffer()

function startCountdown(count) -- Draws the countdown box and text
	if countdown == true then
		gui.drawBox(client.bufferwidth()/2-60,buffer,client.bufferwidth()-(client.bufferwidth()/2+1-60),15+buffer,"white","black")
		if (diff >= timeLimit - 60) then 
			gui.drawText(client.bufferwidth()/2,buffer,"!.!.!.ONE.!.!.!","red",null,null,null,"center")
		elseif (diff >= timeLimit - 120) then 
			gui.drawText(client.bufferwidth()/2,buffer,"!.!...TWO...!.!","yellow",null,null,null,"center")
		else
			gui.drawText(client.bufferwidth()/2,buffer,"!....THREE....!","lime",null,null,null,"center")
		end
	end
end

function saveTime(currentRom)
	currentGameTime = io.open(".\\TimeLogs\\" .. currentGame .. ".txt","w")
	local newTime = 0
	if saveOldTime ~= nil then
		newTime = saveOldTime + timeLimit
	else
		newTime = timeLimit
	end
	currentGameTime:write(newTime)
	currentGameTime:close()
	currentGamePlayCount = io.open(".\\PlayCount\\" .. currentGame .. ".txt","w")
	local newPlayCount = 1
	if savePlayCount ~= nil then
		newPlayCount = savePlayCount
	end
	currentGamePlayCount:write(newPlayCount)
	currentGamePlayCount:close()
end

if databaseSize == 1 then
	timeLimit = 6000
end

while true do -- The main cycle that causes the emulator to advance and trigger a game switch.
	if (diff >= timeLimit - 180) then
		startCountdown(count)
	end
	if diff > timeLimit then
		saveTime(currentRom)
		nextGame(game)
	end		
	diff = diff + 1
	if (diff % 300) == 0 then
		console.log("On frame " .. diff)
	end
	emu.frameadvance()
end
