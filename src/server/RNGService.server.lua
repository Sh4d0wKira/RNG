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

function RNGService.Roll(player)
	-- Weighted random calculation
	local rollValue = math.random() * 100
	local cumulativeChance = 0
	local selectedRarity = nil

	-- Define rarity order
	local sortedRarities = {}
	for name, data in pairs(Cards.Rarities) do
		table.insert(sortedRarities, data)
	end
	table.sort(sortedRarities, function(a, b) return a.Chance < b.Chance end)

	for _, rarity in ipairs(sortedRarities) do
		cumulativeChance = cumulativeChance + rarity.Chance
		if rollValue <= cumulativeChance then
			selectedRarity = rarity.Name
			break
		end
	end
	
	-- Fallback to Common if something goes wrong
	selectedRarity = selectedRarity or "Common"

	-- Pick a random item from that rarity
	local itemsInRarity = Cards.GetItemsByRarity(selectedRarity)
	if #itemsInRarity == 0 then
		print("Warning: No items found for rarity " .. selectedRarity .. ". Falling back to any item.")
		itemsInRarity = Cards.Items
	end
	
	local selectedItem = itemsInRarity[math.random(1, #itemsInRarity)]
	
	print(string.format("[RNG] %s rolled: %s (%s)", player.Name, selectedItem.Name, selectedItem.Rarity))
	
	-- Fire result to client
	remotesFolder.RollResult:FireClient(player, selectedItem)
	
	return selectedItem
end

-- Listener for client requests
remotesFolder.RollRequested.OnServerEvent:Connect(function(player)
	RNGService.Roll(player)
end)

-- RNG Service initialized successfully.
print("RNG Service initialized successfully.")
