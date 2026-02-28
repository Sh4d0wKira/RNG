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
local sessionSpins = 0
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
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Guarantee layer control
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

	-- Luck Counter
	local luckLabel = Instance.new("TextLabel")
	luckLabel.Name = "LuckLabel"
	luckLabel.Size = UDim2.new(0, 180, 0, 30)
	luckLabel.Position = UDim2.new(0.5, -195, 0.85, -35)
	luckLabel.Text = "0/10"
	luckLabel.TextColor3 = Color3.new(1, 1, 1)
	luckLabel.Font = Enum.Font.GothamBold
	luckLabel.TextSize = 18
	luckLabel.BackgroundTransparency = 1
	luckLabel.Parent = screenGui

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

	-- Sidebar Container
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 50, 0, 310)
	sidebar.Position = UDim2.new(0.02, 0, 0.5, -155)
	sidebar.BackgroundTransparency = 1
	sidebar.Parent = screenGui

	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 10)
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sideLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sidebar

	-- Tooltip Label
	local tooltip = Instance.new("TextLabel")
	tooltip.Name = "Tooltip"
	tooltip.Size = UDim2.new(0, 100, 0, 30)
	tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	tooltip.TextColor3 = Color3.new(1, 1, 1)
	tooltip.Font = Enum.Font.GothamBold
	tooltip.TextSize = 14
	tooltip.Visible = false
	tooltip.ZIndex = 10
	local ttCorner = Instance.new("UICorner")
	ttCorner.CornerRadius = UDim.new(0, 6)
	ttCorner.Parent = tooltip
	local ttStroke = Instance.new("UIStroke")
	ttStroke.Thickness = 1.5
	ttStroke.Color = Color3.fromRGB(100, 100, 110)
	ttStroke.Parent = tooltip
	tooltip.Parent = screenGui

	local function setupSidebarButton(name, iconId, layoutOrder, color1, color2)
		-- Base Container (Handles Style & Layout)
		local base = Instance.new("Frame")
		base.Name = name .. "Base"
		base.Size = UDim2.new(0, 42, 0, 42)
		base.BackgroundColor3 = color1
		base.LayoutOrder = layoutOrder
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = base

		applyModernStyle(base, color1, color2)

		-- Invisible Button (Handles full frame input)
		local btn = Instance.new("TextButton")
		btn.Name = "Hitbox"
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 20
		btn.Parent = base

		-- Centered Icon Layer (Fixed proportions 55%)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(0.55, 0, 0.55, 0)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = Color3.new(1, 1, 1)
		icon.ZIndex = 10
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = base

		base.Parent = sidebar

		-- Interaction logic
		btn.MouseEnter:Connect(function()
			tooltip.Text = name:upper()
			tooltip.Position = UDim2.new(0, sidebar.AbsolutePosition.X + 65, 0, base.AbsolutePosition.Y + 10)
			tooltip.Visible = true
			TweenService:Create(base, TweenInfo.new(0.2), {BackgroundColor3 = color1:Lerp(Color3.new(1, 1, 1), 0.1)}):Play()
		end)
		
		btn.MouseLeave:Connect(function()
			tooltip.Visible = false
			TweenService:Create(base, TweenInfo.new(0.2), {BackgroundColor3 = color1}):Play()
		end)

		return btn
	end

	-- VERIFIED LUCIDE ICONS (GUARANTEED VISIBILITY)
	-- Order: Storage (1), Missions (2), Shop (3), Index (4), Settings (5)
	local invToggle = setupSidebarButton("Storage", "rbxassetid://7734056747", 1, Color3.fromRGB(220, 180, 40), Color3.fromRGB(160, 120, 20))    -- shopping-bag
	local missionsBtn = setupSidebarButton("Missions", "rbxassetid://7733920117", 2, Color3.fromRGB(80, 160, 220), Color3.fromRGB(40, 80, 120)) -- clipboard-list
	local shopBtn = setupSidebarButton("Shop", "rbxassetid://7734056813", 3, Color3.fromRGB(220, 80, 160), Color3.fromRGB(120, 40, 80))        -- shopping-cart
	local indexBtn = setupSidebarButton("Index", "rbxassetid://7733914390", 4, Color3.fromRGB(80, 220, 160), Color3.fromRGB(40, 120, 80))     -- book
	local settingsBtn = setupSidebarButton("Settings", "rbxassetid://7734053495", 5, Color3.fromRGB(140, 140, 150), Color3.fromRGB(80, 80, 90))-- settings

	-- Inventory Frame (Storage Redesign)
	local invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryFrame"
	invFrame.Size = UDim2.new(0, 700, 0, 450)
	invFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
	invFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	invFrame.Visible = false
	invFrame.ZIndex = 50
	invFrame.Parent = screenGui
	applyModernStyle(invFrame, Color3.fromRGB(35, 35, 40), Color3.fromRGB(20, 20, 25))
	
	-- Top Bar
	local invTopBar = Instance.new("Frame")
	invTopBar.Size = UDim2.new(1, 0, 0, 40)
	invTopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = invTopBar
	local topFiller = Instance.new("Frame")
	topFiller.Size = UDim2.new(1, 0, 0, 10)
	topFiller.Position = UDim2.new(0, 0, 1, -10)
	topFiller.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	topFiller.BorderSizePixel = 0
	topFiller.Parent = invTopBar
	invTopBar.Parent = invFrame

	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(0, 200, 1, 0)
	invTitle.Position = UDim2.new(0, 20, 0, 0)
	invTitle.Text = "CARDS STORAGE"
	invTitle.TextColor3 = Color3.new(1, 1, 1)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 16
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.BackgroundTransparency = 1
	invTitle.Parent = invTopBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -40, 0, 0)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.BackgroundTransparency = 1
	closeBtn.Parent = invTopBar
	closeBtn.MouseButton1Click:Connect(function()
		invFrame.Visible = false
	end)

	-- Tabs
	local tabsFrame = Instance.new("Frame")
	tabsFrame.Size = UDim2.new(1, -240, 0, 40)
	tabsFrame.Position = UDim2.new(0, 240, 0, 45)
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.Parent = invFrame

	local tabCartas = Instance.new("TextButton")
	tabCartas.Size = UDim2.new(0.5, -5, 1, 0)
	tabCartas.Text = "CARTAS"
	tabCartas.BackgroundColor3 = Color3.fromRGB(60, 60, 75) -- Consistent medium-bright
	tabCartas.TextColor3 = Color3.new(1, 1, 1)
	tabCartas.Font = Enum.Font.GothamBold
	tabCartas.TextSize = 15
	tabCartas.Parent = tabsFrame
	applyModernStyle(tabCartas, Color3.fromRGB(60, 60, 75), Color3.fromRGB(45, 45, 60))
	if tabCartas:FindFirstChild("UIStroke") and tabCartas.UIStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		tabCartas.UIStroke:Destroy() -- Remove text stroke for maximum clarity
	end

	local tabItems = Instance.new("TextButton")
	tabItems.Size = UDim2.new(0.5, -5, 1, 0)
	tabItems.Position = UDim2.new(0.5, 5, 0, 0)
	tabItems.Text = "ITEMS"
	tabItems.BackgroundColor3 = Color3.fromRGB(60, 60, 75) -- Same as Cartas
	tabItems.TextColor3 = Color3.new(1, 1, 1) 
	tabItems.Font = Enum.Font.GothamBold
	tabItems.TextSize = 15
	tabItems.Parent = tabsFrame
	applyModernStyle(tabItems, Color3.fromRGB(60, 60, 75), Color3.fromRGB(45, 45, 60))
	if tabItems:FindFirstChild("UIStroke") and tabItems.UIStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		tabItems.UIStroke:Destroy() -- Remove text stroke
	end

	-- Search Bar
	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -240, 0, 30)
	searchBox.Position = UDim2.new(0, 240, 0, 95)
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(220, 220, 220) -- Clearer placeholder
	searchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75) -- Same as buttons
	searchBox.TextColor3 = Color3.new(1, 1, 1)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 14
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = invFrame
	applyModernStyle(searchBox, Color3.fromRGB(60, 60, 75), Color3.fromRGB(45, 45, 60))
	if searchBox:FindFirstChild("UIStroke") and searchBox.UIStroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		searchBox.UIStroke:Destroy() -- Remove text stroke
	end

	-- Grid Area
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "GridScroll"
	scroll.Size = UDim2.new(1, -250, 1, -180)
	scroll.Position = UDim2.new(0, 240, 0, 135)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = invFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 100, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	-- Bottom Bar
	local invBottomBar = Instance.new("Frame")
	invBottomBar.Size = UDim2.new(1, -250, 0, 40)
	invBottomBar.Position = UDim2.new(0, 240, 1, -45)
	invBottomBar.BackgroundTransparency = 1
	invBottomBar.Parent = invFrame

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0.5, 0, 1, 0)
	countLabel.Text = "0 CARTAS"
	countLabel.TextColor3 = Color3.new(1, 1, 1)
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 16
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.BackgroundTransparency = 1
	countLabel.Parent = invBottomBar

	local deleteModeBtn = Instance.new("TextButton")
	deleteModeBtn.Size = UDim2.new(0, 150, 0, 30)
	deleteModeBtn.Position = UDim2.new(1, -150, 0.5, -15)
	deleteModeBtn.Text = "DELETE MODE"
	deleteModeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	deleteModeBtn.TextColor3 = Color3.new(1, 1, 1)
	deleteModeBtn.Font = Enum.Font.GothamBold
	deleteModeBtn.TextSize = 12
	deleteModeBtn.Parent = invBottomBar
	applyModernStyle(deleteModeBtn, Color3.fromRGB(180, 40, 40), Color3.fromRGB(120, 20, 20))

	-- Details Panel (Left)
	local detailsFrame = Instance.new("Frame")
	detailsFrame.Name = "DetailsFrame"
	detailsFrame.Size = UDim2.new(0, 210, 1, -60)
	detailsFrame.Position = UDim2.new(0, 15, 0, 45)
	detailsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	detailsFrame.Parent = invFrame
	applyModernStyle(detailsFrame, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20))

	local dName = Instance.new("TextLabel")
	dName.Name = "ItemName"
	dName.Size = UDim2.new(1, -20, 0, 30)
	dName.Position = UDim2.new(0, 10, 0, 15)
	dName.Text = "SELECT A CARD"
	dName.TextColor3 = Color3.new(1, 1, 1)
	dName.Font = Enum.Font.GothamBold
	dName.TextSize = 16
	dName.TextWrapped = true
	dName.BackgroundTransparency = 1
	dName.Parent = detailsFrame

	local dChance = Instance.new("TextLabel")
	dChance.Name = "ItemChance"
	dChance.Size = UDim2.new(1, -20, 0, 20)
	dChance.Position = UDim2.new(0, 10, 0, 50)
	dChance.Text = ""
	dChance.TextColor3 = Color3.new(1, 1, 1) -- Brighter
	dChance.Font = Enum.Font.GothamBold
	dChance.TextSize = 14 -- Increased
	dChance.BackgroundTransparency = 1
	dChance.Parent = detailsFrame

	local dQuote = Instance.new("TextLabel")
	dQuote.Name = "ItemQuote"
	dQuote.Size = UDim2.new(1, -20, 0, 80)
	dQuote.Position = UDim2.new(0, 10, 0, 90)
	dQuote.Text = ""
	dQuote.TextColor3 = Color3.fromRGB(220, 220, 220) -- Brighter
	dQuote.Font = Enum.Font.GothamMedium
	dQuote.TextSize = 13 -- Increased
	dQuote.TextWrapped = true
	dQuote.BackgroundTransparency = 1
	dQuote.Parent = detailsFrame

	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipBtn"
	equipBtn.Size = UDim2.new(1, -30, 0, 35)
	equipBtn.Position = UDim2.new(0, 15, 1, -145)
	equipBtn.Text = "EQUIP"
	equipBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	equipBtn.TextColor3 = Color3.new(1, 1, 1)
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 14
	equipBtn.Visible = false
	equipBtn.Parent = detailsFrame
	applyModernStyle(equipBtn, Color3.fromRGB(40, 160, 80), Color3.fromRGB(20, 100, 40))

	local deleteBtn = Instance.new("TextButton")
	deleteBtn.Name = "DeleteBtn"
	deleteBtn.Size = UDim2.new(1, -30, 0, 35)
	deleteBtn.Position = UDim2.new(0, 15, 1, -100)
	deleteBtn.Text = "DELETE"
	deleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	deleteBtn.TextColor3 = Color3.new(1, 1, 1)
	deleteBtn.Font = Enum.Font.GothamBold
	deleteBtn.TextSize = 14
	deleteBtn.Visible = false
	deleteBtn.Parent = detailsFrame
	applyModernStyle(deleteBtn, Color3.fromRGB(180, 40, 40), Color3.fromRGB(120, 20, 20))

	local lockBtn = Instance.new("TextButton")
	lockBtn.Name = "LockBtn"
	lockBtn.Size = UDim2.new(1, -30, 0, 35)
	lockBtn.Position = UDim2.new(0, 15, 1, -55)
	lockBtn.Text = "LOCK"
	lockBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 180)
	lockBtn.TextColor3 = Color3.new(1, 1, 1)
	lockBtn.Font = Enum.Font.GothamBold
	lockBtn.TextSize = 14
	lockBtn.Visible = false
	lockBtn.Parent = detailsFrame
	applyModernStyle(lockBtn, Color3.fromRGB(40, 80, 180), Color3.fromRGB(20, 40, 120))

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

	return rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame, rollContainer, lbScroll, lbToggle, lbFrame, pCountLabel, luckLabel, missionsBtn, shopBtn, indexBtn, settingsBtn
end

local rollButton, autoButton, filterBtn, resultLabel, confirmFrame, keepBtn, discardBtn, invToggle, invFrame, scroll, flashFrame, _rollContainer, lbScroll, lbToggle, lbFrame, pCountLabel, luckLabel, missionsBtn, shopBtn, _indexBtn, settingsBtn = createUI()

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

local function updateLuckUI()
	local progress = sessionSpins % 11
	if progress == 10 then
		luckLabel.Text = "LUCKY SPIN!"
		luckLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold
	else
		luckLabel.Text = string.format("%d/10", (progress + 1))
		luckLabel.TextColor3 = Color3.new(1, 1, 1) -- White
	end
end

local function updateInventory()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	
	local data = getInventory:InvokeServer()
	local inventory = data.Cards
	totalSpins = data.Spins
	
	updateLuckUI()
	
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

	local countLabel = invFrame:FindFirstChild("CountLabel", true)
	if countLabel then
		countLabel.Text = string.format("%d CARTAS", #inventory)
	end
	
	local detailsFrame = invFrame:FindFirstChild("DetailsFrame")

	for _, item in ipairs(inventory) do
		local cell = Instance.new("TextButton")
		cell.Size = UDim2.new(0, 100, 0, 100)
		cell.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		cell.Text = ""
		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 6)
		cCorner.Parent = cell
		
		local rarityData = Cards.Rarities[item.Rarity]
		local rColor = rarityData and rarityData.Color or Color3.new(1, 1, 1)
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = rColor
		stroke.Thickness = 2
		stroke.Parent = cell
		
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -10, 0.4, 0)
		nameLbl.Position = UDim2.new(0, 5, 0.1, 0)
		nameLbl.Text = item.Name:upper()
		nameLbl.TextColor3 = rColor
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 13 -- Slightly larger
		nameLbl.TextWrapped = true
		nameLbl.BackgroundTransparency = 1
		nameLbl.Parent = cell
		
		local nStroke = Instance.new("UIStroke")
		nStroke.Thickness = 1
		nStroke.Color = Color3.new(0, 0, 0)
		nStroke.Transparency = 0.4
		nStroke.Parent = nameLbl

		local chanceLbl = Instance.new("TextLabel")
		chanceLbl.Size = UDim2.new(1, -10, 0.3, 0)
		chanceLbl.Position = UDim2.new(0, 5, 0.55, 0) -- Adjusted position
		chanceLbl.Text = rarityData and string.format("1 IN\n%d", rarityData.Chance) or ""
		chanceLbl.TextColor3 = Color3.new(1, 1, 1)
		chanceLbl.Font = Enum.Font.GothamBold
		chanceLbl.TextSize = 11 -- Increased
		chanceLbl.BackgroundTransparency = 1
		chanceLbl.Parent = cell

		local cStroke = Instance.new("UIStroke")
		cStroke.Thickness = 1
		cStroke.Color = Color3.new(0, 0, 0)
		cStroke.Transparency = 0.4
		cStroke.Parent = chanceLbl
		
		-- Click Interaction
		cell.MouseButton1Click:Connect(function()
			if detailsFrame then
				local dName = detailsFrame:FindFirstChild("ItemName")
				local dChance = detailsFrame:FindFirstChild("ItemChance")
				local equipBtn = detailsFrame:FindFirstChild("EquipBtn")
				local deleteBtn = detailsFrame:FindFirstChild("DeleteBtn")
				local lockBtn = detailsFrame:FindFirstChild("LockBtn")
				
				if dName then dName.Text = item.Name:upper(); dName.TextColor3 = rColor end
				if dChance then dChance.Text = chanceLbl.Text end
				if equipBtn then equipBtn.Visible = true end
				if deleteBtn then deleteBtn.Visible = true end
				if lockBtn then lockBtn.Visible = true end
			end
		end)
		
		cell.Parent = scroll
	end
	
	-- UIGridLayout calculates AbsoluteContentSize dynamically
	local gridLayout = scroll:FindFirstChild("UIGridLayout")
	if gridLayout then
		-- Delay briefly to ensure GridLayout updates
		task.delay(0.1, function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y)
		end)
	else
		scroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#inventory / 4) * 116)
	end
end

-- Leaderboard logic
local playerRows = {}

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
		h.Name = "Accent"
		h.BorderSizePixel = 0
		h.BackgroundColor3 = color
		h.Position = pos
		h.Size = sizes[i][1]
		if i == 2 or i == 4 then h.AnchorPoint = Vector2.new(1, 0) end
		h.Parent = parent
		
		local v = Instance.new("Frame")
		v.Name = "Accent"
		v.BorderSizePixel = 0
		v.BackgroundColor3 = color
		v.Position = pos
		v.Size = sizes[i][2]
		if i == 2 or i == 4 then v.AnchorPoint = Vector2.new(1, 0) end
		v.Parent = parent
	end
end

local function updateLeaderboard()
	local players = Players:GetPlayers()
	pCountLabel.Text = tostring(#players)
	
	table.sort(players, function(a, b)
		local aSpins = a:FindFirstChild("leaderstats") and a.leaderstats:FindFirstChild("Spins") and a.leaderstats.Spins.Value or 0
		local bSpins = b:FindFirstChild("leaderstats") and b.leaderstats:FindFirstChild("Spins") and b.leaderstats.Spins.Value or 0
		return aSpins > bSpins
	end)

	local currentUIDs = {}
	
	for i, p in ipairs(players) do
		local uid = tostring(p.UserId)
		currentUIDs[uid] = true
		local spins = p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Spins") and p.leaderstats.Spins.Value or 0
		local rank = i
		local rankColor = Color3.new(1, 1, 1) -- Default text color
		if rank == 1 then
			rankColor = Color3.fromRGB(255, 215, 0) -- Gold
		elseif rank == 2 then
			rankColor = Color3.fromRGB(200, 200, 200) -- Silver
		elseif rank == 3 then
			rankColor = Color3.fromRGB(205, 127, 50) -- Bronze
		end
		local isTop3 = (rank <= 3)
		
		local rowData = playerRows[uid]
		if not rowData then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 45)
			row.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
			row.BackgroundTransparency = 0.2
			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 4)
			rCorner.Parent = row
			
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
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 13
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.BackgroundTransparency = 1
			nameLabel.Parent = row
			
			local spinValue = Instance.new("TextLabel")
			spinValue.Size = UDim2.new(0.35, 0, 1, 0)
			spinValue.Position = UDim2.new(0.6, 0, 0, 0)
			spinValue.Font = Enum.Font.GothamBold
			spinValue.TextSize = 13
			spinValue.TextXAlignment = Enum.TextXAlignment.Right
			spinValue.BackgroundTransparency = 1
			spinValue.Parent = row
			
			row.Parent = lbScroll
			
			rowData = {
				Frame = row,
				Name = nameLabel,
				Value = spinValue,
				Avatar = avatar,
				LastRank = nil
			}
			playerRows[uid] = rowData
		end
		
		-- Update Content
		rowData.Value.Text = string.format("%d", spins):gsub("(%d)(%d%d%d)$", "%1,%2")
		rowData.Frame.LayoutOrder = i
		
		-- Update Style if Needed
		if rowData.LastRank ~= rank then
			rowData.LastRank = rank
			
			-- Cleanup previous decorations
			for _, child in ipairs(rowData.Frame:GetChildren()) do
				if child.Name == "Accent" or child:IsA("UIStroke") then child:Destroy() end
			end
			for _, child in ipairs(rowData.Avatar:GetChildren()) do
				if child:IsA("UIStroke") then child:Destroy() end
			end
			
			rowData.Name.TextColor3 = rankColor
			rowData.Value.TextColor3 = rankColor
			
			if isTop3 then
				createCornerAccents(rowData.Frame, rankColor)
				local stroke = Instance.new("UIStroke")
				stroke.Color = rankColor
				stroke.Thickness = 1
				stroke.Transparency = 0.6
				stroke.Parent = rowData.Frame
				
				local astroke = Instance.new("UIStroke")
				astroke.Color = rankColor
				astroke.Thickness = 2
				astroke.Parent = rowData.Avatar
			elseif p == player then
				-- White highlight for local player if not in top 3
				createCornerAccents(rowData.Frame, Color3.new(1, 1, 1))
			else
				-- Default look for everyone else
				rowData.Name.TextColor3 = Color3.new(1, 1, 1)
				rowData.Value.TextColor3 = Color3.new(1, 1, 1)
				
				if p == player then
					-- White highlight for local player if not in top 3
					local stroke = Instance.new("UIStroke")
					stroke.Color = Color3.new(1, 1, 1)
					stroke.Thickness = 1
					stroke.Transparency = 0.4
					stroke.Parent = rowData.Frame
				end
			end
		end
	end
	
	-- Cleanup
	for uid, data in pairs(playerRows) do
		if not currentUIDs[uid] then
			data.Frame:Destroy()
			playerRows[uid] = nil
		end
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
	invFrame.Visible = not invFrame.Visible
	if invFrame.Visible then updateInventory() end
end)

missionsBtn.MouseButton1Click:Connect(function()
	print("Missions clicked - (Coming soon!)")
	-- Logic for missions window will go here
end)

shopBtn.MouseButton1Click:Connect(function()
	print("Shop clicked - (Coming soon!)")
	-- Logic for shop window will go here
end)

settingsBtn.MouseButton1Click:Connect(function()
	print("Settings clicked - (Coming soon!)")
	-- Logic for settings window will go here
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
	sessionSpins = sessionSpins + 1
	updateLuckUI()
	
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
