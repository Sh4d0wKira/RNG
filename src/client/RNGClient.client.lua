local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

-- Disable default PlayerList
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared:WaitForChild("Cards"))

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local isRolling = false
local autoSpinEnabled = false
local currentCard = nil
local minRarityRank = 1
local currentAura = nil
local lastRollTime = 0
local ROLL_COOLDOWN = 2.0
local totalSpins = 0
local autoUnlocked = false
local AUTO_UNLOCK_THRESHOLD = 50

-- Helper for modern styling
local function applyModernStyle(instance, color1, color2)
	local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = instance

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color1:Lerp(Color3.new(1, 1, 1), 0.4)
	stroke.Transparency = 0.2
	stroke.Parent = instance

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1:Lerp(Color3.new(1, 1, 1), 0.2)), -- Lighter top
		ColorSequenceKeypoint.new(0.5, color1),
		ColorSequenceKeypoint.new(1, color2 or color1:Lerp(Color3.new(0, 0, 0), 0.3)) -- Darker bottom
	})
	gradient.Rotation = 90
	gradient.Parent = instance
	
	-- Hover effects using TweenService
	instance.MouseEnter:Connect(function()
		TweenService:Create(instance, TweenInfo.new(0.3), {BackgroundColor3 = color1:Lerp(Color3.new(1, 1, 1), 0.2)}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), {Thickness = 4, Transparency = 0}):Play()
	end)
	
	instance.MouseLeave:Connect(function()
		TweenService:Create(instance, TweenInfo.new(0.3), {BackgroundColor3 = color1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), {Thickness = 2.5, Transparency = 0.2}):Play()
	end)

	-- Add Text Glow/Stroke
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 1.5
	textStroke.Color = Color3.new(0, 0, 0)
	textStroke.Transparency = 0.5
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = instance
end

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

	-- Roll Button Container (for animation scaling)
	local rollContainer = Instance.new("Frame")
	rollContainer.Name = "RollContainer"
	rollContainer.Size = UDim2.new(0, 180, 0, 50)
	rollContainer.Position = UDim2.new(0.5, -195, 0.85, 0)
	rollContainer.BackgroundTransparency = 1
	rollContainer.Parent = screenGui

	local rollButton = Instance.new("TextButton")
	rollButton.Name = "RollButton"
	rollButton.Size = UDim2.new(1, 0, 1, 0)
	rollButton.Text = "ROLL"
	rollButton.BackgroundColor3 = Color3.fromRGB(80, 50, 200) -- Vibrant Electric Purple
	rollButton.TextColor3 = Color3.new(1, 1, 1)
	rollButton.Font = Enum.Font.GothamBold
	rollButton.TextSize = 24
	rollButton.ClipsDescendants = true
	rollButton.Parent = rollContainer
	applyModernStyle(rollButton, Color3.fromRGB(80, 50, 200), Color3.fromRGB(40, 20, 120)) -- Electric Blue/Purple

	-- Wave Overlay for Charging effect
	local waveOverlay = Instance.new("Frame")
	waveOverlay.Name = "WaveOverlay"
	waveOverlay.Size = UDim2.new(2, 0, 1, 0)
	waveOverlay.Position = UDim2.new(-2, 0, 0, 0)
	waveOverlay.BackgroundTransparency = 1
	waveOverlay.ZIndex = 0
	waveOverlay.Parent = rollButton

	local waveGradient = Instance.new("UIGradient")
	waveGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
	})
	waveGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.4), -- Sharper wave
		NumberSequenceKeypoint.new(0.6, 0.8),
		NumberSequenceKeypoint.new(1, 1)
	})
	waveGradient.Parent = waveOverlay

	-- AutoSpin Button
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoButton"
	autoButton.Size = UDim2.new(0, 180, 0, 50)
	autoButton.Position = UDim2.new(0.5, 15, 0.85, 0)
	autoButton.Text = "AUTO: OFF"
	autoButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40) -- Vibrant Crimson
	autoButton.TextColor3 = Color3.new(1, 1, 1)
	autoButton.Font = Enum.Font.GothamBold
	autoButton.TextSize = 22
	autoButton.Parent = screenGui
	applyModernStyle(autoButton, Color3.fromRGB(200, 40, 40), Color3.fromRGB(120, 20, 20))

	-- Filter Button
	local filterBtn = Instance.new("TextButton")
	filterBtn.Name = "FilterToggle"
	filterBtn.Size = UDim2.new(0, 160, 0, 45) -- Increased width from 120 to 160
	filterBtn.Position = UDim2.new(0.95, -160, 0.45, 0)
	filterBtn.Text = "FILTER: ALL"
	filterBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 160)
	filterBtn.TextColor3 = Color3.new(1, 1, 1)
	filterBtn.Font = Enum.Font.GothamBold
	filterBtn.TextSize = 14
	filterBtn.TextWrapped = true
	filterBtn.Parent = screenGui
	applyModernStyle(filterBtn, Color3.fromRGB(80, 80, 160), Color3.fromRGB(50, 50, 100))

	-- Result Display
	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(0, 400, 0, 100)
	resultLabel.Position = UDim2.new(0.5, -200, 0.3, -50)
	resultLabel.Text = "Roll for a card!"
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextColor3 = Color3.new(1, 1, 1)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 38
	
	local shadowLabel = Instance.new("TextLabel")
	shadowLabel.Name = "ShadowLabel"
	shadowLabel.Size = UDim2.new(1, 0, 1, 0)
	shadowLabel.Position = UDim2.new(0, 3, 0, 3) -- Slightly deeper shadow
	shadowLabel.BackgroundTransparency = 1
	shadowLabel.TextColor3 = Color3.new(0, 0, 0)
	shadowLabel.TextTransparency = 0.4
	shadowLabel.Font = Enum.Font.GothamBold
	shadowLabel.TextSize = 38
	shadowLabel.Text = resultLabel.Text
	shadowLabel.ZIndex = 0
	shadowLabel.Parent = resultLabel
	
	resultLabel.Parent = screenGui

	-- Confirmation UI
	local confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "ConfirmFrame"
	confirmFrame.Size = UDim2.new(0, 320, 0, 120)
	confirmFrame.Position = UDim2.new(0.5, -160, 0.45, 0)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	confirmFrame.BorderSizePixel = 0
	confirmFrame.Visible = false
	local cfCorner = Instance.new("UICorner")
	cfCorner.Parent = confirmFrame
	local cfStroke = Instance.new("UIStroke")
	cfStroke.Thickness = 3
	cfStroke.Color = Color3.fromRGB(120, 120, 120)
	cfStroke.Parent = confirmFrame
	confirmFrame.Parent = screenGui

	local keepBtn = Instance.new("TextButton")
	keepBtn.Name = "KeepButton"
	keepBtn.Size = UDim2.new(0, 130, 0, 45)
	keepBtn.Position = UDim2.new(0.05, 0, 0.35, 0)
	keepBtn.Text = "KEEP"
	keepBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 40) -- Vibrant Neon Green
	keepBtn.TextColor3 = Color3.new(1, 1, 1)
	keepBtn.Font = Enum.Font.GothamBold
	keepBtn.Parent = confirmFrame
	applyModernStyle(keepBtn, Color3.fromRGB(40, 200, 40), Color3.fromRGB(20, 120, 20))

	local discardBtn = Instance.new("TextButton")
	discardBtn.Name = "DiscardButton"
	discardBtn.Size = UDim2.new(0, 130, 0, 45)
	discardBtn.Position = UDim2.new(0.55, 0, 0.35, 0)
	discardBtn.Text = "DISCARD"
	discardBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40) -- Vibrant Red
	discardBtn.TextColor3 = Color3.new(1, 1, 1)
	discardBtn.Font = Enum.Font.GothamBold
	discardBtn.Parent = confirmFrame
	applyModernStyle(discardBtn, Color3.fromRGB(220, 40, 40), Color3.fromRGB(140, 20, 20))

	-- Bag Toggle
	local invToggle = Instance.new("TextButton")
	invToggle.Name = "InventoryToggle"
	invToggle.Size = UDim2.new(0, 75, 0, 75)
	invToggle.Position = UDim2.new(0.02, 0, 0.5, -37.5)
	invToggle.Text = "BAG"
	invToggle.BackgroundColor3 = Color3.fromRGB(220, 180, 40) -- Golden Yellow
	invToggle.TextColor3 = Color3.new(1, 1, 1)
	invToggle.Font = Enum.Font.GothamBold
	invToggle.TextSize = 20
	local itCorner = Instance.new("UICorner")
	itCorner.CornerRadius = UDim.new(1, 0)
	itCorner.Parent = invToggle
	applyModernStyle(invToggle, Color3.fromRGB(220, 180, 40), Color3.fromRGB(160, 120, 20))
	invToggle.Parent = screenGui

	-- Inventory Frame
	local invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryFrame"
	invFrame.Size = UDim2.new(0, 300, 0, 450)
	invFrame.Position = UDim2.new(-0.4, 0, 0.5, -225)
	invFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	invFrame.Parent = screenGui
	applyModernStyle(invFrame, Color3.fromRGB(40, 40, 45), Color3.fromRGB(25, 25, 30))
	
	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(1, 0, 0, 40)
	invTitle.Text = "MY COLLECTION"
	invTitle.TextColor3 = Color3.new(1, 1, 1)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 18
	invTitle.BackgroundTransparency = 1
	invTitle.Parent = invFrame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -60)
	scroll.Position = UDim2.new(0, 10, 0, 50)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = invFrame

	-- Leaderboard Frame
	local lbFrame = Instance.new("Frame")
	lbFrame.Name = "LeaderboardFrame"
	lbFrame.Size = UDim2.new(0, 240, 0, 300)
	lbFrame.Position = UDim2.new(1, -250, 0.02, 0)
	lbFrame.BackgroundTransparency = 1
	lbFrame.Parent = screenGui

	-- Leaderboard Toggle Button (Now relative to Frame)
	local lbToggle = Instance.new("TextButton")
	lbToggle.Name = "LeaderboardToggle"
	lbToggle.Size = UDim2.new(0, 25, 0, 40)
	lbToggle.Position = UDim2.new(0, -30, 0, 0) -- Left side of frame
	lbToggle.Text = ">"
	lbToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	lbToggle.TextColor3 = Color3.new(1, 1, 1)
	lbToggle.Font = Enum.Font.GothamBold
	lbToggle.TextSize = 14
	lbToggle.Parent = lbFrame
	applyModernStyle(lbToggle, Color3.fromRGB(50, 50, 60), Color3.fromRGB(30, 30, 35))

	-- Header Frame
	local lbHeader = Instance.new("Frame")
	lbHeader.Name = "Header"
	lbHeader.Size = UDim2.new(1, 0, 0, 35)
	lbHeader.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	lbHeader.Parent = lbFrame
	applyModernStyle(lbHeader, Color3.fromRGB(50, 50, 60), Color3.fromRGB(35, 35, 45))

	local pCountFrame = Instance.new("Frame")
	pCountFrame.Name = "CountCircle"
	pCountFrame.Size = UDim2.new(0, 25, 0, 25)
	pCountFrame.Position = UDim2.new(0, 5, 0.5, -12.5)
	pCountFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	local pcc = Instance.new("UICorner")
	pcc.CornerRadius = UDim.new(1, 0)
	pcc.Parent = pCountFrame
	pCountFrame.Parent = lbHeader

	local pCountLabel = Instance.new("TextLabel")
	pCountLabel.Name = "Count"
	pCountLabel.Size = UDim2.new(1, 0, 1, 0)
	pCountLabel.Text = "0"
	pCountLabel.TextColor3 = Color3.new(1, 1, 1)
	pCountLabel.Font = Enum.Font.GothamBold
	pCountLabel.TextSize = 12
	pCountLabel.BackgroundTransparency = 1
	pCountLabel.Parent = pCountFrame

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(0.8, 0, 1, 0)
	headerLabel.Position = UDim2.new(0.15, 0, 0, 0)
	headerLabel.Text = "USER   ||   ROLLS"
	headerLabel.TextColor3 = Color3.new(1, 1, 1)
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 14
	headerLabel.BackgroundTransparency = 1
	headerLabel.Parent = lbHeader

	local lbScroll = Instance.new("ScrollingFrame")
	lbScroll.Name = "LeaderboardScroll"
	lbScroll.Size = UDim2.new(1, 0, 1, -40)
	lbScroll.Position = UDim2.new(0, 0, 0, 40)
	lbScroll.BackgroundTransparency = 1
	lbScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	lbScroll.ScrollBarThickness = 0
	lbScroll.Parent = lbFrame

	local lbLayout = Instance.new("UIListLayout")
	lbLayout.Padding = UDim.new(0, 4)
	lbLayout.Parent = lbScroll

	return rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame, rollContainer, lbScroll, lbToggle, lbFrame, pCountLabel
end

local rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame, _rollContainer, lbScroll, lbToggle, lbFrame, pCountLabel = createUI()

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
	
	local auraPart = Instance.new("Part")
	auraPart.Name = "UIAura"
	auraPart.Transparency = 1
	auraPart.CanCollide = false
	auraPart.Anchored = true
	auraPart.Size = Vector3.new(1, 1, 1)
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
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local data = getInventory:InvokeServer()
	local inventory = data.Cards
	totalSpins = data.Spins
	
	if totalSpins < AUTO_UNLOCK_THRESHOLD then
		autoButton.Text = string.format("LOCKED (%d/%d)", totalSpins, AUTO_UNLOCK_THRESHOLD)
		autoButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		autoButton.AutoButtonColor3 = false
	else
		autoUnlocked = true
		if not autoSpinEnabled then
			autoButton.Text = "AUTO: OFF"
			autoButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		end
	end

	for _, item in ipairs(inventory) do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 45)
		frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		local fCorner = Instance.new("UICorner")
		fCorner.Parent = frame
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.new(0, 10, 0, 0)
		label.Text = string.format("[%s] %s", item.Rarity:upper(), item.Name)
		label.BackgroundTransparency = 1
		label.TextColor3 = Cards.Rarities[item.Rarity].Color
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = frame
		
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 4, 0.8, 0)
		stripe.Position = UDim2.new(0, 0, 0.1, 0)
		stripe.BackgroundColor3 = Cards.Rarities[item.Rarity].Color
		stripe.BorderSizePixel = 0
		stripe.Parent = frame
		
		frame.Parent = scroll
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, #inventory * 53)
end

-- Leaderboard logic
local function createCornerAccents(parent, color)
	local positions = {
		UDim2.new(0, -1, 0, -1),
		UDim2.new(1, -5, 0, -1),
		UDim2.new(0, -1, 1, -5),
		UDim2.new(1, -5, 1, -5)
	}
	local sizes = {
		{UDim2.new(0, 6, 0, 2), UDim2.new(0, 2, 0, 6)},
		{UDim2.new(0, 6, 0, 2), UDim2.new(0, 2, 0, 6)},
		{UDim2.new(0, 6, 0, 2), UDim2.new(0, 2, 0, 6)},
		{UDim2.new(0, 6, 0, 2), UDim2.new(0, 2, 0, 6)}
	}

	for i, pos in ipairs(positions) do
		local h = Instance.new("Frame")
		h.BorderSizePixel = 0
		h.BackgroundColor3 = color
		h.Position = pos
		h.Size = sizes[i][1]
		if i == 2 or i == 4 then h.AnchorPoint = Vector2.new(1, 0) end
		h.Parent = parent
		
		local v = Instance.new("Frame")
		v.BorderSizePixel = 0
		v.BackgroundColor3 = color
		v.Position = pos
		v.Size = sizes[i][2]
		if i == 2 or i == 4 then v.AnchorPoint = Vector2.new(1, 0) end
		v.Parent = parent
	end
end

local function updateLeaderboard()
	for _, child in ipairs(lbScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local players = Players:GetPlayers()
	pCountLabel.Text = tostring(#players)
	
	table.sort(players, function(a, b)
		local aSpins = a:FindFirstChild("leaderstats") and a.leaderstats:FindFirstChild("Spins") and a.leaderstats.Spins.Value or 0
		local bSpins = b:FindFirstChild("leaderstats") and b.leaderstats:FindFirstChild("Spins") and b.leaderstats.Spins.Value or 0
		return aSpins > bSpins
	end)

	for i, p in ipairs(players) do
		local spins = p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Spins") and p.leaderstats.Spins.Value or 0
		local isTopPlayer = (i == 1)
		
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 45)
		row.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		row.BackgroundTransparency = 0.2
		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 4)
		rCorner.Parent = row
		
		-- Avatar
		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 35, 0, 35)
		avatar.Position = UDim2.new(0, 5, 0.5, -17.5)
		avatar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		avatar.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		local aCorner = Instance.new("UICorner")
		aCorner.CornerRadius = UDim.new(0, 4)
		aCorner.Parent = avatar
		avatar.Parent = row
		
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 45, 0, 0)
		nameLabel.Text = p.DisplayName:upper()
		nameLabel.TextColor3 = isTopPlayer and Color3.fromRGB(80, 255, 150) or Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.BackgroundTransparency = 1
		nameLabel.Parent = row
		
		local spinValue = Instance.new("TextLabel")
		spinValue.Size = UDim2.new(0.35, 0, 1, 0)
		spinValue.Position = UDim2.new(0.6, 0, 0, 0)
		spinValue.Text = string.format("%d", spins):gsub("(%d)(%d%d%d)$", "%1,%2") -- Pseudo comma
		spinValue.TextColor3 = isTopPlayer and Color3.fromRGB(80, 255, 150) or Color3.new(1, 1, 1)
		spinValue.Font = Enum.Font.GothamBold
		spinValue.TextSize = 13
		spinValue.TextXAlignment = Enum.TextXAlignment.Right
		spinValue.BackgroundTransparency = 1
		spinValue.Parent = row
		
		if isTopPlayer then
			createCornerAccents(row, Color3.fromRGB(80, 255, 150))
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(80, 255, 150)
			stroke.Thickness = 1
			stroke.Transparency = 0.6
			stroke.Parent = row
			
			-- Avatar border
			local astroke = Instance.new("UIStroke")
			astroke.Color = Color3.fromRGB(80, 255, 150)
			astroke.Thickness = 2
			astroke.Parent = avatar
		else
			createCornerAccents(row, Color3.new(1, 1, 1))
			if p == player then
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Thickness = 1
				stroke.Transparency = 0.4
				stroke.Parent = row
			end
		end
		
		row.Parent = lbScroll
	end
	lbScroll.CanvasSize = UDim2.new(0, 0, 0, #players * 49)
end

Players.PlayerAdded:Connect(function(newPlayer)
	updateLeaderboard()
	task.spawn(function()
		local stats = newPlayer:WaitForChild("leaderstats", 15)
		if stats then
			local spins = stats:WaitForChild("Spins", 15)
			if spins then
				spins.Changed:Connect(updateLeaderboard)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(updateLeaderboard)

-- Listen for existing players
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local stats = p:WaitForChild("leaderstats", 15)
		if stats then
			local spins = stats:WaitForChild("Spins", 15)
			if spins then
				spins.Changed:Connect(updateLeaderboard)
			end
		end
	end)
end

-- Toggle Handler
local lbVisible = true
local function toggleLeaderboard()
	lbVisible = not lbVisible
	lbToggle.Text = lbVisible and ">" or "<"
	lbFrame:TweenPosition(UDim2.new(1, lbVisible and -250 or 10, 0.02, 0), "Out", "Quad", 0.3, true)
end

lbToggle.MouseButton1Click:Connect(toggleLeaderboard)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		toggleLeaderboard()
	end
end)

-- Button Animations
local waveTween = nil

local function setRollButtonActive(active)
	local rollContainer = PlayerGui.RNGGui.RollContainer
	local rollButton = rollContainer.RollButton
	local waveOverlay = rollButton:FindFirstChild("WaveOverlay")
	
	if active then
		-- Quick click animation
		TweenService:Create(rollContainer, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 180 * 0.9, 0, 50 * 0.9)}):Play()
		task.delay(0.1, function()
			TweenService:Create(rollContainer, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 180, 0, 50)}):Play()
		end)
		
		rollButton.Text = "WAITING..."
		
		-- Start Wave Charging
		if waveOverlay then
			waveOverlay.Position = UDim2.new(-2, 0, 0, 0)
			if waveTween then waveTween:Cancel() end
			waveTween = TweenService:Create(waveOverlay, TweenInfo.new(ROLL_COOLDOWN, Enum.EasingStyle.Linear), {Position = UDim2.new(1, 0, 0, 0)})
			waveTween:Play()
		end
	else
		-- Stop Wave and Ready
		if waveTween then 
			waveTween:Cancel() 
			waveTween = nil
		end
		if waveOverlay then
			waveOverlay.Position = UDim2.new(-2, 0, 0, 0)
		end
		rollButton.Text = autoSpinEnabled and "AUTO ACTIVE" or "ROLL"
		
		-- Ready Pop
		TweenService:Create(rollContainer, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 190, 0, 55)}):Play()
		task.delay(0.2, function()
			TweenService:Create(rollContainer, TweenInfo.new(0.2), {Size = UDim2.new(0, 180, 0, 50)}):Play()
		end)
	end
end

local function performRoll()
	if isRolling or confirmFrame.Visible then return false end
	if tick() - lastRollTime < ROLL_COOLDOWN then return false end
	
	isRolling = true
	lastRollTime = tick()
	clearAura()
	setRollButtonActive(true)
	rollRequested:FireServer()
	resultLabel.Text = "Spinning..."
	resultLabel.TextColor3 = Color3.new(1, 1, 1)
	if resultLabel:FindFirstChild("ShadowLabel") then
		resultLabel.ShadowLabel.Text = resultLabel.Text
	end
	return true
end

-- UI Handlers
invToggle.MouseButton1Click:Connect(function()
	local isOpen = invFrame.Position.X.Scale > 0
	invFrame:TweenPosition(UDim2.new(isOpen and -0.4 or 0.08, 0, 0.5, -225), "Out", "Quad", 0.4, true)
	if not isOpen then updateInventory() end
end)

rollButton.MouseButton1Click:Connect(performRoll)

local autoRevertDelay = nil

autoButton.MouseButton1Click:Connect(function()
	if not autoUnlocked then
		-- Show how many more needed
		local remaining = AUTO_UNLOCK_THRESHOLD - totalSpins
		autoButton.Text = string.format("Need %d more!", remaining)
		
		-- Shake button
		local startPos = autoButton.Position
		task.spawn(function()
			for i = 1, 6 do
				autoButton.Position = startPos + UDim2.new(0, math.random(-5, 5), 0, 0)
				task.wait(0.05)
			end
			autoButton.Position = startPos
		end)
		
		-- Revert after 2 seconds
		if autoRevertDelay then task.cancel(autoRevertDelay) end
		autoRevertDelay = task.delay(2, function()
			if not autoUnlocked then
				autoButton.Text = string.format("LOCKED (%d/%d)", totalSpins, AUTO_UNLOCK_THRESHOLD)
			end
			autoRevertDelay = nil
		end)
		return 
	end

	autoSpinEnabled = not autoSpinEnabled
	autoButton.Text = autoSpinEnabled and "AUTO: ON" or "AUTO: OFF"
	local activeColor = Color3.fromRGB(40, 200, 40) -- Neon Green
	local inactiveColor = Color3.fromRGB(200, 40, 40) -- Crimson Red
	local color = autoSpinEnabled and activeColor or inactiveColor
	
	autoButton.BackgroundColor3 = color
	-- Update gradient in runtime
	local grad = autoButton:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1,1,1), 0.2)),
			ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0,0,0), 0.3))
		})
	end
	
	if not isRolling and not confirmFrame.Visible then
		rollButton.Text = autoSpinEnabled and "AUTO ACTIVE" or "ROLL"
	end
end)

filterBtn.MouseButton1Click:Connect(function()
	minRarityRank = (minRarityRank % 5) + 1
	local rarityName = rarityOrder[minRarityRank]
	filterBtn.Text = "FILTER: " .. rarityName:upper() .. "+"
	filterBtn.TextColor3 = Cards.Rarities[rarityName].Color
end)

rollResult.OnClientEvent:Connect(function(item)
	local rarityData = Cards.Rarities[item.Rarity]
	
	-- Update Spins (Count every roll received)
	totalSpins = totalSpins + 1
	
	if not autoUnlocked and totalSpins >= AUTO_UNLOCK_THRESHOLD then
		autoUnlocked = true
		autoButton.Text = "AUTO UNLOCKED!"
		autoButton.BackgroundColor3 = Color3.fromRGB(40, 200, 40)
		TweenService:Create(autoButton, TweenInfo.new(1, Enum.EasingStyle.Elastic), {Size = UDim2.new(0, 200, 0, 60)}):Play()
		task.delay(1.5, function()
			TweenService:Create(autoButton, TweenInfo.new(0.5), {Size = UDim2.new(0, 180, 0, 50)}):Play()
			if not autoSpinEnabled then
				autoButton.Text = "AUTO: OFF"
				autoButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
			end
		end)
	elseif not autoUnlocked then
		autoButton.Text = string.format("LOCKED (%d/%d)", totalSpins, AUTO_UNLOCK_THRESHOLD)
	end

	if rarityData.Rank >= 3 then
		task.wait(1)
	end

	isRolling = false

	if rarityData.Rank < minRarityRank then
		resultLabel.Text = "Skipped: " .. item.Name
		resultLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
		if resultLabel:FindFirstChild("ShadowLabel") then
			resultLabel.ShadowLabel.Text = resultLabel.Text
		end
		setRollButtonActive(false)
		return
	end

	spawnAura(rarityData)
	if rarityData.Vfx.Shake then applyShake(rarityData.Rank * 5) end
	if rarityData.Vfx.Flash then applyFlash(rarityData.Color) end

	currentCard = item
	resultLabel.Text = string.format("YOU GOT: %s!\n(%s)", item.Name, item.Rarity)
	resultLabel.TextColor3 = rarityData.Color
	if resultLabel:FindFirstChild("ShadowLabel") then
		resultLabel.ShadowLabel.Text = resultLabel.Text
	end
	confirmFrame.Visible = true
	rollButton.Text = "DECIDE..."
	
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
		setRollButtonActive(false)
		resultLabel.Text = "Card saved to Bag!"
		resultLabel.TextColor3 = Color3.new(0, 1, 0)
		if resultLabel:FindFirstChild("ShadowLabel") then
			resultLabel.ShadowLabel.Text = resultLabel.Text
		end
		clearAura()
	end
end)

discardBtn.MouseButton1Click:Connect(function()
	currentCard = nil
	confirmFrame.Visible = false
	setRollButtonActive(false)
	resultLabel.Text = "Card discarded."
	resultLabel.TextColor3 = Color3.new(1, 0, 0)
	if resultLabel:FindFirstChild("ShadowLabel") then
		resultLabel.ShadowLabel.Text = resultLabel.Text
	end
	clearAura()
end)

-- AutoSpin Loop
task.spawn(function()
	while true do
		-- If auto is active and we are NOT rolling, show wave even while waiting
		if autoSpinEnabled and not isRolling and not PlayerGui.RNGGui.ConfirmFrame.Visible then
			local rollContainer = PlayerGui:FindFirstChild("RNGGui") and PlayerGui.RNGGui:FindFirstChild("RollContainer")
			if rollContainer then
				local rollButton = rollContainer.RollButton
				local waveOverlay = rollButton:FindFirstChild("WaveOverlay")
				if waveOverlay and not waveTween then
					waveTween = TweenService:Create(waveOverlay, TweenInfo.new(ROLL_COOLDOWN, Enum.EasingStyle.Linear), {Position = UDim2.new(1, 0, 0, 0)})
					waveTween:Play()
				end
			end
		end
		
		task.wait(ROLL_COOLDOWN)
		
		if autoSpinEnabled and not isRolling and not PlayerGui.RNGGui.ConfirmFrame.Visible then
			if waveTween then 
				waveTween:Cancel() 
				waveTween = nil 
			end
			performRoll()
		end
	end
end)

print("RNG Client initialized.")
updateInventory() -- Initial sync
updateLeaderboard()
