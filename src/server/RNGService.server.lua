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
	
	-- Weighted random calculation
	local totalWeight = 0
	local tempRarities = {}
	local extraWeight = 0
	
	for name, data in pairs(Cards.Rarities) do
		if name ~= "Common" then
			local chance = data.Chance
			if luckMultiplier > 1 then
				local newChance = chance * luckMultiplier
				extraWeight = extraWeight + (newChance - chance)
				chance = newChance
			end
			table.insert(tempRarities, {Name = name, Chance = chance})
			totalWeight = totalWeight + chance
		end
	end
	
	local commonChance = math.max(1, Cards.Rarities.Common.Chance - extraWeight)
	table.insert(tempRarities, {Name = "Common", Chance = commonChance})
	totalWeight = totalWeight + commonChance
	
	local rollValue = math.random() * totalWeight
	local cumulativeChance = 0
	local selectedRarity = nil

	table.sort(tempRarities, function(a, b) return a.Chance < b.Chance end)

	for _, rarity in ipairs(tempRarities) do
		cumulativeChance = cumulativeChance + rarity.Chance
		if rollValue <= cumulativeChance then
			selectedRarity = rarity.Name
			break
		end
	end
	
	selectedRarity = selectedRarity or "Common"
	local itemsInRarity = Cards.GetItemsByRarity(selectedRarity)
	
	if #itemsInRarity == 0 then
		itemsInRarity = Cards.Items
	end
	
	local selectedItem = itemsInRarity[math.random(1, #itemsInRarity)]
	
	if luckMultiplier > 1 then
		print(string.format("[LUCKY ROLL] %s rolled: %s (%s)", player.Name, selectedItem.Name, selectedItem.Rarity))
	else
		print(string.format("[RNG] %s rolled: %s (%s)", player.Name, selectedItem.Name, selectedItem.Rarity))
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
		luckMultiplier = 1.6
	end
	
	RNGService.Roll(player, luckMultiplier)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	sessionLuck[player.UserId] = nil
end)

-- RNG Service initialized successfully.
print("RNG Service initialized successfully.")
