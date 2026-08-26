-- Builds and updates the entire HUD purely in code (no pre-made GUI
-- assets needed): night counter, hunger/stamina bars, resource counts,
-- and toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local HUDController = {}

local function makeBar(parent, position, size, fillColor, label)
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.new(0, 0, 0, 0)
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = frame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Text = label
	text.Parent = frame

	return frame, fill
end

function HUDController.Init()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SurvivalHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Night counter, top center.
	local nightLabel = Instance.new("TextLabel")
	nightLabel.Name = "NightLabel"
	nightLabel.AnchorPoint = Vector2.new(0.5, 0)
	nightLabel.Position = UDim2.new(0.5, 0, 0.02, 0)
	nightLabel.Size = UDim2.new(0, 320, 0, 40)
	nightLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	nightLabel.BackgroundTransparency = 0.25
	nightLabel.Font = Enum.Font.GothamBold
	nightLabel.TextSize = 22
	nightLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	nightLabel.Text = "Day - Night 0 / " .. GameConfig.TotalNights
	nightLabel.Parent = screenGui

	local nightCorner = Instance.new("UICorner")
	nightCorner.CornerRadius = UDim.new(0, 8)
	nightCorner.Parent = nightLabel

	-- Hunger + stamina bars, bottom left.
	local hungerFrame, hungerFill = makeBar(
		screenGui,
		UDim2.new(0, 20, 1, -100),
		UDim2.new(0, 220, 0, 24),
		Color3.fromRGB(210, 150, 40),
		"Hunger"
	)

	local staminaFrame, staminaFill = makeBar(
		screenGui,
		UDim2.new(0, 20, 1, -70),
		UDim2.new(0, 220, 0, 24),
		Color3.fromRGB(80, 200, 90),
		"Stamina"
	)

	-- Resource counts, top left.
	local resourcesFrame = Instance.new("Frame")
	resourcesFrame.Position = UDim2.new(0, 20, 0, 20)
	resourcesFrame.Size = UDim2.new(0, 160, 0, 100)
	resourcesFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	resourcesFrame.BackgroundTransparency = 0.35
	resourcesFrame.Parent = screenGui

	local resourcesCorner = Instance.new("UICorner")
	resourcesCorner.CornerRadius = UDim.new(0, 8)
	resourcesCorner.Parent = resourcesFrame

	local resourceLabels = {}
	local resourceOrder = { "Wood", "Stone", "Berries" }
	for i, name in ipairs(resourceOrder) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 10, 0, (i - 1) * 32 + 6)
		label.Size = UDim2.new(1, -20, 0, 28)
		label.Font = Enum.Font.Gotham
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = name .. ": 0"
		label.Parent = resourcesFrame
		resourceLabels[name] = label
	end

	-- Eat button.
	local eatButton = Instance.new("TextButton")
	eatButton.Position = UDim2.new(0, 250, 1, -100)
	eatButton.Size = UDim2.new(0, 120, 0, 40)
	eatButton.BackgroundColor3 = Color3.fromRGB(90, 60, 40)
	eatButton.Font = Enum.Font.GothamBold
	eatButton.TextSize = 16
	eatButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	eatButton.Text = "Eat Berries"
	eatButton.Parent = screenGui

	local eatCorner = Instance.new("UICorner")
	eatCorner.CornerRadius = UDim.new(0, 8)
	eatCorner.Parent = eatButton

	eatButton.MouseButton1Click:Connect(function()
		Remotes.EatFood:FireServer()
	end)

	-- Toast notifications, center-bottom.
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -140)
	toast.Size = UDim2.new(0, 400, 0, 30)
	toast.BackgroundTransparency = 1
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 18
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextTransparency = 1
	toast.Text = ""
	toast.Parent = screenGui

	local function showToast(message)
		toast.Text = message
		toast.TextTransparency = 0
		task.delay(2.5, function()
			if toast.Text == message then
				toast.TextTransparency = 1
			end
		end)
	end

	-- Remote hookups.
	Remotes.DayNightChanged.OnClientEvent:Connect(function(phase, night, totalNights)
		nightLabel.Text = string.format("%s - Night %d / %d", phase, night, totalNights)
	end)

	Remotes.StatsUpdated.OnClientEvent:Connect(function(stats)
		hungerFill.Size = UDim2.new(math.clamp(stats.Hunger / GameConfig.Hunger.Max, 0, 1), 0, 1, 0)
		staminaFill.Size = UDim2.new(math.clamp(stats.Stamina / GameConfig.Stamina.Max, 0, 1), 0, 1, 0)
	end)

	Remotes.InventoryUpdated.OnClientEvent:Connect(function(inventory)
		for name, label in pairs(resourceLabels) do
			label.Text = name .. ": " .. tostring(inventory[name] or 0)
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(showToast)

	return {
		ScreenGui = screenGui,
		ShowToast = showToast,
	}
end

return HUDController
