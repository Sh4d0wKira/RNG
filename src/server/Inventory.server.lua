local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local InventoryStore = DataStoreService:GetDataStore("PlayerInventories_v1")
local Inventories = {} -- Local cache: [UserId] = { Cards = {}, Spins = 0 }

local function getRemotesFolder()
	return ReplicatedStorage:WaitForChild("Remotes")
end

local remotesFolder = getRemotesFolder()

-- Function to save data safely
local function savePlayerData(player)
	local userId = player.UserId
	if Inventories[userId] then
		local success, err = pcall(function()
			InventoryStore:SetAsync(tostring(userId), Inventories[userId])
		end)
		if not success then
			warn("[DataStore] Failed to save data for " .. player.Name .. ": " .. tostring(err))
		else
			print("[DataStore] Data saved for " .. player.Name)
		end
	end
end

-- Function to load data safely
local function loadPlayerData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return InventoryStore:GetAsync(tostring(userId))
	end)

	if success then
		-- Migration and initialization
		if data then
			if data.Cards then
				-- Already in new format
				Inventories[userId] = data
			else
				-- Old format was just a list of cards
				Inventories[userId] = {
					Cards = data,
					Spins = 0
				}
			end
		else
			-- New player
			Inventories[userId] = { Cards = {}, Spins = 0 }
		end

		-- Sync to leaderstats
		local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
		
		local spinsStat = stats:FindFirstChild("Spins") or Instance.new("IntValue")
		spinsStat.Name = "Spins"
		spinsStat.Value = Inventories[userId].Spins
		spinsStat.Parent = stats

		print("[DataStore] Data loaded for " .. player.Name .. " (" .. #Inventories[userId].Cards .. " cards, " .. Inventories[userId].Spins .. " spins)")
	else
		Inventories[userId] = { Cards = {}, Spins = 0 }
		warn("[DataStore] Failed to load data for " .. player.Name .. ": " .. tostring(data))
	end
end

-- Events
Players.PlayerAdded:Connect(loadPlayerData)
Players.PlayerRemoving:Connect(savePlayerData)

-- Handle Inventory retrieval
remotesFolder:WaitForChild(Remotes.GetInventory).OnServerInvoke = function(player)
	if not Inventories[player.UserId] then
		loadPlayerData(player) 
	end
	return Inventories[player.UserId]
end

-- Function to increment spins (called by RNGService)
local function incrementSpins(player)
	local userId = player.UserId
	if not Inventories[userId] then return end
	
	Inventories[userId].Spins = Inventories[userId].Spins + 1
	
	-- Update leaderstats
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local spinsStat = stats:FindFirstChild("Spins")
		if spinsStat then
			spinsStat.Value = Inventories[userId].Spins
		end
	end
	
	-- No need to save on every single spin to avoid throttling, 
	-- PlayerRemoving and BindToClose will handle it, but maybe save every 10?
	if Inventories[userId].Spins % 5 == 0 then
		task.spawn(savePlayerData, player)
	end
end

-- Export for RNGService
_G.IncrementSpins = incrementSpins

-- Handle Card claiming
remotesFolder:WaitForChild(Remotes.ClaimCard).OnServerEvent:Connect(function(player, cardData)
	local userId = player.UserId
	if not Inventories[userId] then
		Inventories[userId] = { Cards = {}, Spins = 0 }
	end
	
	table.insert(Inventories[userId].Cards, cardData)
	print(string.format("[Inventory] %s saved card: %s", player.Name, cardData.Name))
	
	task.spawn(savePlayerData, player)
end)

-- BindToClose for server shutdowns
game:BindToClose(function()
	print("[DataStore] Server shutting down, saving all data...")
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
	task.wait(2) -- Give time for async requests to finish
end)

print("Persistent Inventory Service initialized.")
