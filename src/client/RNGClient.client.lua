local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared:WaitForChild("Cards"))

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local isRolling = false
local autoSpinEnabled = false
local currentCard = nil
local minRarityRank = 1
local currentAura = nil

-- Basic UI Setup
local function createUI()
	local existing = PlayerGui:FindFirstChild("RNGGui")
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RNGGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	-- Flash Frame
	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "FlashFrame"
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.ZIndex = 100
	flashFrame.Parent = screenGui

	-- Roll Button
	local rollButton = Instance.new("TextButton")
	rollButton.Name = "RollButton"
	rollButton.Size = UDim2.new(0, 180, 0, 50)
	rollButton.Position = UDim2.new(0.5, -195, 0.85, 0)
	rollButton.Text = "ROLL"
	rollButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	rollButton.TextColor3 = Color3.new(1, 1, 1)
	rollButton.Font = Enum.Font.GothamBold
	rollButton.TextSize = 20
	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = rollButton
	rollButton.Parent = screenGui

	-- AutoSpin Button
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoButton"
	autoButton.Size = UDim2.new(0, 180, 0, 50)
	autoButton.Position = UDim2.new(0.5, 15, 0.85, 0)
	autoButton.Text = "AUTO: OFF"
	autoButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	autoButton.TextColor3 = Color3.new(1, 1, 1)
	autoButton.Font = Enum.Font.GothamBold
	autoButton.TextSize = 20
	local abCorner = Instance.new("UICorner")
	abCorner.CornerRadius = UDim.new(0, 8)
	abCorner.Parent = autoButton
	autoButton.Parent = screenGui

	-- Filter Button
	local filterBtn = Instance.new("TextButton")
	filterBtn.Name = "FilterToggle"
	filterBtn.Size = UDim2.new(0, 100, 0, 40)
	filterBtn.Position = UDim2.new(0.9, -110, 0.5, -20)
	filterBtn.Text = "FILTER: ALL"
	filterBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	filterBtn.TextColor3 = Color3.new(1, 1, 1)
	filterBtn.Font = Enum.Font.GothamBold
	filterBtn.TextSize = 14
	local fbCorner = Instance.new("UICorner")
	fbCorner.Parent = filterBtn
	filterBtn.Parent = screenGui

	-- Result Display
	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(0, 400, 0, 100)
	resultLabel.Position = UDim2.new(0.5, -200, 0.3, -50)
	resultLabel.Text = "Roll for a card!"
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextColor3 = Color3.new(1, 1, 1)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 30
	resultLabel.Parent = screenGui

	-- Confirmation UI
	local confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "ConfirmFrame"
	confirmFrame.Size = UDim2.new(0, 300, 0, 100)
	confirmFrame.Position = UDim2.new(0.5, -150, 0.45, 0)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	confirmFrame.BorderSizePixel = 0
	confirmFrame.Visible = false
	local cfCorner = Instance.new("UICorner")
	cfCorner.Parent = confirmFrame
	confirmFrame.Parent = screenGui

	local keepBtn = Instance.new("TextButton")
	keepBtn.Name = "KeepButton"
	keepBtn.Size = UDim2.new(0, 120, 0, 40)
	keepBtn.Position = UDim2.new(0.1, 0, 0.3, 0)
	keepBtn.Text = "KEEP"
	keepBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
	keepBtn.TextColor3 = Color3.new(1, 1, 1)
	keepBtn.Font = Enum.Font.GothamBold
	keepBtn.Parent = confirmFrame

	local discardBtn = Instance.new("TextButton")
	discardBtn.Name = "DiscardButton"
	discardBtn.Size = UDim2.new(0, 120, 0, 40)
	discardBtn.Position = UDim2.new(0.55, 0, 0.3, 0)
	discardBtn.Text = "DISCARD"
	discardBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
	discardBtn.TextColor3 = Color3.new(1, 1, 1)
	discardBtn.Font = Enum.Font.GothamBold
	discardBtn.Parent = confirmFrame

	-- Bag Toggle
	local invToggle = Instance.new("TextButton")
	invToggle.Name = "InventoryToggle"
	invToggle.Size = UDim2.new(0, 60, 0, 60)
	invToggle.Position = UDim2.new(0.02, 0, 0.5, -30)
	invToggle.Text = "BAG"
	invToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	invToggle.TextColor3 = Color3.new(1, 1, 1)
	invToggle.Font = Enum.Font.GothamBold
	local itCorner = Instance.new("UICorner")
	itCorner.CornerRadius = UDim.new(1, 0)
	itCorner.Parent = invToggle
	invToggle.Parent = screenGui

	local invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryFrame"
	invFrame.Size = UDim2.new(0, 250, 0, 400)
	invFrame.Position = UDim2.new(-0.3, 0, 0.5, -200)
	invFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	invFrame.BorderSizePixel = 0
	local invCorner = Instance.new("UICorner")
	invCorner.Parent = invFrame
	invFrame.Parent = screenGui

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -20)
	scroll.Position = UDim2.new(0, 10, 0, 10)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 4
	scroll.Parent = invFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scroll

	return rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame
end

local rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame = createUI()

-- VFX Functions
local function clearAura()
	if currentAura then
		currentAura:Destroy()
		currentAura = nil
	end
end

local function applyShake(intensity)
	local cam = workspace.CurrentCamera
	
	task.spawn(function()
		for i = 1, 10 do
			local offset = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)) * (intensity / 100)
			cam.CFrame = cam.CFrame * CFrame.new(offset)
			task.wait(0.02)
		end
	end)
end

local function applyFlash(color)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end

local function spawnAura(rarityData)
	clearAura()
	
	local cam = workspace.CurrentCamera
	local vfxData = rarityData.Vfx
	
	-- Create a local part in front of the camera to host particles
	local auraPart = Instance.new("Part")
	auraPart.Name = "UIAura"
	auraPart.Transparency = 1
	auraPart.CanCollide = false
	auraPart.Anchored = true
	auraPart.Size = Vector3.new(1, 1, 1)
	-- Position it roughly where the ResultLabel is in screen space (center-ish)
	auraPart.CFrame = cam.CFrame * CFrame.new(0, 2, -10) 
	auraPart.Parent = workspace
	
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(rarityData.Color)
	emitter.Size = NumberSequence.new(vfxData.Size)
	emitter.Rate = vfxData.Rate
	emitter.Lifetime = NumberRange.new(0.5, 1.5)
	emitter.Speed = NumberRange.new(2, 8)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Parent = auraPart
	
	local light = Instance.new("PointLight")
	light.Color = rarityData.Color
	light.Brightness = vfxData.Light
	light.Range = 15
	light.Parent = auraPart
	
	currentAura = auraPart
end

-- Safe access to remotes
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn("RNGClient: Remotes folder not found!")
	return
end

local rollRequested = remotesFolder:WaitForChild("RollRequested")
local rollResult = remotesFolder:WaitForChild("RollResult")
local claimCard = remotesFolder:WaitForChild("ClaimCard")
local getInventory = remotesFolder:WaitForChild("GetInventory")

-- Logic Functions
local rarityOrder = {"Common", "Rare", "Epic", "Legendary", "Mythic"}

local function updateInventory()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	
	local inventory = getInventory:InvokeServer()
	for _, item in ipairs(inventory) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 30)
		label.Text = string.format("[%s] %s", item.Rarity:sub(1,1), item.Name)
		label.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		label.TextColor3 = Cards.Rarities[item.Rarity].Color
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		local lCorner = Instance.new("UICorner")
		lCorner.Parent = label
		label.Parent = scroll
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, #inventory * 35)
end

local function performRoll()
	if isRolling or confirmFrame.Visible then return false end
	isRolling = true
	clearAura()
	rollRequested:FireServer()
	rollButton.Text = "ROLLING..."
	resultLabel.Text = "Spinning..."
	resultLabel.TextColor3 = Color3.new(1, 1, 1)
	return true
end

-- UI Handlers
invToggle.MouseButton1Click:Connect(function()
	local isOpen = invFrame.Position.X.Scale > 0
	invFrame:TweenPosition(UDim2.new(isOpen and -0.3 or 0.08, 0, 0.5, -200), "Out", "Quad", 0.3, true)
	if not isOpen then updateInventory() end
end)

rollButton.MouseButton1Click:Connect(performRoll)

autoButton.MouseButton1Click:Connect(function()
	autoSpinEnabled = not autoSpinEnabled
	autoButton.Text = autoSpinEnabled and "AUTO: ON" or "AUTO: OFF"
	autoButton.BackgroundColor3 = autoSpinEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
end)

filterBtn.MouseButton1Click:Connect(function()
	minRarityRank = (minRarityRank % 5) + 1
	local rarityName = rarityOrder[minRarityRank]
	filterBtn.Text = "FILTER: " .. rarityName:upper() .. "+"
	filterBtn.TextColor3 = Cards.Rarities[rarityName].Color
end)

rollResult.OnClientEvent:Connect(function(item)
	local rarityData = Cards.Rarities[item.Rarity]
	
	-- Dramatic timing for rare cards
	if rarityData.Rank >= 3 then
		task.wait(1) -- Dramatic pause
	end

	-- BUGFIX: Reset rolling state early to avoid getting stuck
	isRolling = false

	-- Apply Filter
	if rarityData.Rank < minRarityRank then
		resultLabel.Text = "Skipped: " .. item.Name
		resultLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
		rollButton.Text = "ROLL"
		return
	end

	-- Trigger VFX
	spawnAura(rarityData)
	if rarityData.Vfx.Shake then applyShake(rarityData.Rank * 5) end
	if rarityData.Vfx.Flash then applyFlash(rarityData.Color) end

	-- Normal result display
	currentCard = item
	resultLabel.Text = string.format("YOU GOT: %s!\n(%s)", item.Name, item.Rarity)
	resultLabel.TextColor3 = rarityData.Color
	confirmFrame.Visible = true
	rollButton.Text = "DECIDE..."
	
	-- Pop animation
	resultLabel.Size = UDim2.new(0, 450, 0, 120)
	task.delay(0.05, function()
		resultLabel:TweenSize(UDim2.new(0, 400, 0, 100), "Out", "Back", 0.3, true)
	end)
end)

keepBtn.MouseButton1Click:Connect(function()
	if currentCard then
		claimCard:FireServer(currentCard)
		currentCard = nil
		confirmFrame.Visible = false
		isRolling = false
		rollButton.Text = "ROLL AGAIN"
		resultLabel.Text = "Card saved to Bag!"
		resultLabel.TextColor3 = Color3.new(0, 1, 0)
		clearAura()
	end
end)

discardBtn.MouseButton1Click:Connect(function()
	currentCard = nil
	confirmFrame.Visible = false
	isRolling = false
	rollButton.Text = "ROLL AGAIN"
	resultLabel.Text = "Card discarded."
	resultLabel.TextColor3 = Color3.new(1, 0, 0)
	clearAura()
end)

-- AutoSpin Loop
task.spawn(function()
	while true do
		task.wait(3.5)
		if autoSpinEnabled and not isRolling and not confirmFrame.Visible then
			performRoll()
		end
	end
end)

print("RNG Client with VFX initialized.")
