local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared:WaitForChild("Cards"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Set random seed for better randomization
math.randomseed(os.time())

local RNGService = {}

-- Initialize Remotes in ReplicatedStorage
local function initRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	for _, name in pairs(Remotes) do
		if not folder:FindFirstChild(name) then
			local remote
			if name == "GetInventory" then
				remote = Instance.new("RemoteFunction")
			else
				remote = Instance.new("RemoteEvent")
			end
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

local remotesFolder = initRemotes()

function RNGService.Roll(player, luckMultiplier)
	luckMultiplier = luckMultiplier or 1
	
	-- New logic: Roll per rarity, starting from the rarest (highest Rank)
	local sortedRarities = {}
	for name, data in pairs(Cards.Rarities) do
		if name ~= "Common" then
			table.insert(sortedRarities, {Name = name, Chance = data.Chance, Rank = data.Rank})
		end
	end
	
	-- Sort by Rank Descending (Rarest first)
	table.sort(sortedRarities, function(a, b) return a.Rank > b.Rank end)
	
	local selectedRarity = "Common"
	
	for _, rarity in ipairs(sortedRarities) do
		-- "1 in X" logic: math.random(1, X) == 1
		-- Luck multiplier reduces the effective "X": X / luckMultiplier
		local effectiveChance = math.max(1, rarity.Chance / luckMultiplier)
		if math.random() * effectiveChance <= 1 then
			selectedRarity = rarity.Name
			break
		end
	end
	
	local itemsInRarity = Cards.GetItemsByRarity(selectedRarity)
	
	if #itemsInRarity == 0 then
		itemsInRarity = Cards.Items
	end
	
	local selectedItem = itemsInRarity[math.random(1, #itemsInRarity)]
	
	if luckMultiplier > 1 then
		print(string.format("[LUCKY ROLL] %s rolled: %s (1 in %s) [x%.1f Luck]", 
			player.Name, selectedItem.Name, selectedItem.Rarity, luckMultiplier))
	else
		print(string.format("[RNG] %s rolled: %s (1 in %s)", 
			player.Name, selectedItem.Name, selectedItem.Rarity))
	end
	
	remotesFolder.RollResult:FireClient(player, selectedItem)
	return selectedItem
end

local sessionLuck = {}

-- Listener for client requests
remotesFolder.RollRequested.OnServerEvent:Connect(function(player)
	local luckMultiplier = 1
	
	if _G.IncrementSpins then
		_G.IncrementSpins(player)
	end
	
	sessionLuck[player.UserId] = (sessionLuck[player.UserId] or 0) + 1
	
	if sessionLuck[player.UserId] % 11 == 0 then
		luckMultiplier = 2.2
	end
	
	RNGService.Roll(player, luckMultiplier)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	sessionLuck[player.UserId] = nil
end)

-- RNG Service initialized successfully.
print("RNG Service initialized successfully.")
