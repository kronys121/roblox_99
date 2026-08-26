-- Builds and updates the entire HUD purely in code (no pre-made GUI
-- assets needed): night counter, health/hunger/thirst/stamina bars,
-- personal + shared Warehouse resource counts, currency, and toast
-- notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local DayNightConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("DayNightConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local function formatClock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

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

local function makeResourcePanel(parent, position, title)
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = UDim2.new(0, 170, 0, 150)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BackgroundTransparency = 0.35
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 10, 0, 4)
	titleLabel.Size = UDim2.new(1, -20, 0, 20)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	titleLabel.Text = title
	titleLabel.Parent = frame

	local labels = {}
	local resourceOrder = { "Wood", "Stone", "Berries", "Water", "RareMaterial" }
	for i, name in ipairs(resourceOrder) do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 10, 0, 26 + (i - 1) * 24)
		label.Size = UDim2.new(1, -20, 0, 22)
		label.Font = Enum.Font.Gotham
		label.TextSize = 15
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = name .. ": 0"
		label.Parent = frame
		labels[name] = label
	end

	return frame, labels
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
	nightLabel.Size = UDim2.new(0, 340, 0, 40)
	nightLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	nightLabel.BackgroundTransparency = 0.25
	nightLabel.Font = Enum.Font.GothamBold
	nightLabel.TextSize = 22
	nightLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	nightLabel.Text = "Day - Night 0 / " .. DayNightConfig.TotalNights
	nightLabel.Parent = screenGui

	local nightCorner = Instance.new("UICorner")
	nightCorner.CornerRadius = UDim.new(0, 8)
	nightCorner.Parent = nightLabel

	-- Currency, just under the night counter.
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.AnchorPoint = Vector2.new(0.5, 0)
	currencyLabel.Position = UDim2.new(0.5, 0, 0.02, 46)
	currencyLabel.Size = UDim2.new(0, 200, 0, 28)
	currencyLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	currencyLabel.BackgroundTransparency = 0.35
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.TextSize = 15
	currencyLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	currencyLabel.Text = GameConfig.Currency.Name .. ": 0"
	currencyLabel.Parent = screenGui

	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 8)
	currencyCorner.Parent = currencyLabel

	-- Health/Hunger/Thirst/Stamina bars, bottom left, stacked upward.
	local _, healthFill = makeBar(screenGui, UDim2.new(0, 20, 1, -190), UDim2.new(0, 220, 0, 24), Color3.fromRGB(210, 60, 60), "Health")
	local _, hungerFill = makeBar(screenGui, UDim2.new(0, 20, 1, -160), UDim2.new(0, 220, 0, 24), Color3.fromRGB(210, 150, 40), "Hunger")
	local _, thirstFill = makeBar(screenGui, UDim2.new(0, 20, 1, -130), UDim2.new(0, 220, 0, 24), Color3.fromRGB(70, 150, 220), "Thirst")
	local _, staminaFill = makeBar(screenGui, UDim2.new(0, 20, 1, -100), UDim2.new(0, 220, 0, 24), Color3.fromRGB(80, 200, 90), "Stamina")

	-- Personal carry, top left. Shared base Warehouse, top right.
	local _, personalLabels = makeResourcePanel(screenGui, UDim2.new(0, 20, 0, 20), "Backpack")
	local _, warehouseLabels = makeResourcePanel(screenGui, UDim2.new(1, -190, 0, 20), "Warehouse (shared)")

	-- Eat / Drink buttons.
	local eatButton = Instance.new("TextButton")
	eatButton.Position = UDim2.new(0, 260, 1, -160)
	eatButton.Size = UDim2.new(0, 130, 0, 36)
	eatButton.BackgroundColor3 = Color3.fromRGB(90, 60, 40)
	eatButton.Font = Enum.Font.GothamBold
	eatButton.TextSize = 15
	eatButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	eatButton.Text = "Eat Berries"
	eatButton.Parent = screenGui

	local eatCorner = Instance.new("UICorner")
	eatCorner.CornerRadius = UDim.new(0, 8)
	eatCorner.Parent = eatButton

	eatButton.MouseButton1Click:Connect(function()
		Remotes.EatFood:FireServer()
	end)

	local drinkButton = Instance.new("TextButton")
	drinkButton.Position = UDim2.new(0, 260, 1, -118)
	drinkButton.Size = UDim2.new(0, 130, 0, 36)
	drinkButton.BackgroundColor3 = Color3.fromRGB(40, 70, 95)
	drinkButton.Font = Enum.Font.GothamBold
	drinkButton.TextSize = 15
	drinkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	drinkButton.Text = "Drink Water"
	drinkButton.Parent = screenGui

	local drinkCorner = Instance.new("UICorner")
	drinkCorner.CornerRadius = UDim.new(0, 8)
	drinkCorner.Parent = drinkButton

	drinkButton.MouseButton1Click:Connect(function()
		Remotes.DrinkWater:FireServer()
	end)

	-- Toast notifications, center-bottom.
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -210)
	toast.Size = UDim2.new(0, 500, 0, 30)
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
	Remotes.DayNightChanged.OnClientEvent:Connect(function(state)
		nightLabel.Text = string.format(
			"%s - Night %d / %d - %s",
			state.Phase,
			state.Night,
			state.TotalNights,
			formatClock(state.TimeLeft)
		)
	end)

	Remotes.StatsUpdated.OnClientEvent:Connect(function(stats)
		healthFill.Size = UDim2.new(math.clamp(stats.Health / stats.MaxHealth, 0, 1), 0, 1, 0)
		hungerFill.Size = UDim2.new(math.clamp(stats.Hunger / GameConfig.Hunger.Max, 0, 1), 0, 1, 0)
		thirstFill.Size = UDim2.new(math.clamp(stats.Thirst / GameConfig.Thirst.Max, 0, 1), 0, 1, 0)
		staminaFill.Size = UDim2.new(math.clamp(stats.Stamina / GameConfig.Stamina.Max, 0, 1), 0, 1, 0)
	end)

	Remotes.InventoryUpdated.OnClientEvent:Connect(function(inventory)
		for name, label in pairs(personalLabels) do
			label.Text = name .. ": " .. tostring(inventory[name] or 0)
		end
	end)

	Remotes.WarehouseUpdated.OnClientEvent:Connect(function(stock)
		for name, label in pairs(warehouseLabels) do
			label.Text = name .. ": " .. tostring(stock[name] or 0)
		end
	end)

	Remotes.CurrencyUpdated.OnClientEvent:Connect(function(currency)
		currencyLabel.Text = (currency.CurrencyName or GameConfig.Currency.Name) .. ": " .. tostring(currency.Currency or 0)
	end)

	Remotes.Notify.OnClientEvent:Connect(showToast)

	return {
		ScreenGui = screenGui,
		ShowToast = showToast,
	}
end

return HUDController
