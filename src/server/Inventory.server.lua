local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local InventoryStore = DataStoreService:GetDataStore("PlayerInventories_v1")
local Inventories = {} -- Local cache: [UserId] = { {Name = "Goku", Rarity = "Common"}, ... }

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
		Inventories[userId] = data or {}
		print("[DataStore] Data loaded for " .. player.Name .. " (" .. #Inventories[userId] .. " items)")
	else
		Inventories[userId] = {}
		warn("[DataStore] Failed to load data for " .. player.Name .. ": " .. tostring(data))
	end
end

-- Events
Players.PlayerAdded:Connect(loadPlayerData)
Players.PlayerRemoving:Connect(savePlayerData)

-- Handle Inventory retrieval
remotesFolder:WaitForChild(Remotes.GetInventory).OnServerInvoke = function(player)
	if not Inventories[player.UserId] then
		loadPlayerData(player) -- Fallback if PlayerAdded didn't catch it
	end
	return Inventories[player.UserId]
end

-- Handle Card claiming
remotesFolder:WaitForChild(Remotes.ClaimCard).OnServerEvent:Connect(function(player, cardData)
	local userId = player.UserId
	if not Inventories[userId] then
		Inventories[userId] = {}
	end
	
	table.insert(Inventories[userId], cardData)
	print(string.format("[Inventory] %s saved card: %s", player.Name, cardData.Name))
	
	-- Proactive save for critical items (Optional: could also wait for PlayerRemoving)
	task.spawn(function()
		savePlayerData(player)
	end)
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
