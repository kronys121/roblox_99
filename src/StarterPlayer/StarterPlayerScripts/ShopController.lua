-- Shop menu: toggled with "V". Cosmetics tab spends Embers (the in-game
-- currency, earned per night survived) on a purely procedural aura --
-- no external asset IDs needed. Game Passes tab lists the Robux
-- upgrades; a pass with no real ID yet (see GameConfig.GamePasses) shows
-- as "Not available yet" instead of prompting a purchase that would fail.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local ShopController = {}

function ShopController.Init(hud, closeOtherMenus)
	local screenGui = hud.ScreenGui
	local ownedCosmetics = {}
	local activeCosmetic = nil

	local menu = Instance.new("Frame")
	menu.Name = "ShopMenu"
	menu.AnchorPoint = Vector2.new(0.5, 1)
	menu.Position = UDim2.new(0.5, 0, 1, -20)
	menu.Size = UDim2.new(0, 420, 0, 320)
	menu.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	menu.BackgroundTransparency = 0.15
	menu.Visible = false
	menu.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = menu

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "Shop (press V)"
	title.Parent = menu

	local cosmeticsLabel = Instance.new("TextLabel")
	cosmeticsLabel.BackgroundTransparency = 1
	cosmeticsLabel.Position = UDim2.new(0, 10, 0, 32)
	cosmeticsLabel.Size = UDim2.new(1, -20, 0, 18)
	cosmeticsLabel.Font = Enum.Font.GothamBold
	cosmeticsLabel.TextSize = 13
	cosmeticsLabel.TextXAlignment = Enum.TextXAlignment.Left
	cosmeticsLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	cosmeticsLabel.Text = "Cosmetics (" .. GameConfig.Currency.Name .. ")"
	cosmeticsLabel.Parent = menu

	local cosmeticsList = Instance.new("Frame")
	cosmeticsList.BackgroundTransparency = 1
	cosmeticsList.Position = UDim2.new(0, 10, 0, 52)
	cosmeticsList.Size = UDim2.new(1, -20, 0, 120)
	cosmeticsList.Parent = menu

	local cosmeticsLayout = Instance.new("UIListLayout")
	cosmeticsLayout.Padding = UDim.new(0, 4)
	cosmeticsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cosmeticsLayout.Parent = cosmeticsList

	local cosmeticButtons = {}

	local function refreshCosmeticButtons()
		for cosmeticId, buttons in pairs(cosmeticButtons) do
			local owned = table.find(ownedCosmetics, cosmeticId) ~= nil
			if owned then
				buttons.Buy.Visible = false
				buttons.Equip.Visible = true
				buttons.Equip.Text = (activeCosmetic == cosmeticId) and "Equipped" or "Equip"
				buttons.Equip.BackgroundColor3 = (activeCosmetic == cosmeticId) and Color3.fromRGB(80, 80, 90) or Color3.fromRGB(70, 130, 80)
			else
				buttons.Buy.Visible = true
				buttons.Equip.Visible = false
			end
		end
	end

	for order, cosmetic in ipairs(GameConfig.Cosmetics) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		row.Size = UDim2.new(1, 0, 0, 30)
		row.LayoutOrder = order
		row.Parent = cosmeticsList

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.new(0, 6, 0.5, -8)
		swatch.Size = UDim2.new(0, 16, 0, 16)
		swatch.BackgroundColor3 = cosmetic.Color
		swatch.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 30, 0, 0)
		nameLabel.Size = UDim2.new(1, -160, 1, 0)
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Text = cosmetic.Name .. " - " .. cosmetic.Cost
		nameLabel.Parent = row

		local buyButton = Instance.new("TextButton")
		buyButton.AnchorPoint = Vector2.new(1, 0.5)
		buyButton.Position = UDim2.new(1, -6, 0.5, 0)
		buyButton.Size = UDim2.new(0, 60, 0, 24)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 12
		buyButton.BackgroundColor3 = Color3.fromRGB(90, 70, 40)
		buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyButton.Text = "Buy"
		buyButton.Parent = row

		local equipButton = Instance.new("TextButton")
		equipButton.AnchorPoint = Vector2.new(1, 0.5)
		equipButton.Position = UDim2.new(1, -6, 0.5, 0)
		equipButton.Size = UDim2.new(0, 70, 0, 24)
		equipButton.Font = Enum.Font.GothamBold
		equipButton.TextSize = 12
		equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		equipButton.Text = "Equip"
		equipButton.Visible = false
		equipButton.Parent = row

		cosmeticButtons[cosmetic.Id] = { Buy = buyButton, Equip = equipButton }

		buyButton.MouseButton1Click:Connect(function()
			local ok, resultOrError = Remotes.BuyCosmetic:InvokeServer(cosmetic.Id)
			if ok then
				table.insert(ownedCosmetics, cosmetic.Id)
				hud.ShowToast("Purchased " .. cosmetic.Name)
				refreshCosmeticButtons()
			else
				hud.ShowToast(resultOrError or "Cannot buy")
			end
		end)

		equipButton.MouseButton1Click:Connect(function()
			local newActive = (activeCosmetic == cosmetic.Id) and nil or cosmetic.Id
			activeCosmetic = newActive
			Remotes.SetActiveCosmetic:FireServer(newActive)
			refreshCosmeticButtons()
		end)
	end

	local passesLabel = Instance.new("TextLabel")
	passesLabel.BackgroundTransparency = 1
	passesLabel.Position = UDim2.new(0, 10, 0, 180)
	passesLabel.Size = UDim2.new(1, -20, 0, 18)
	passesLabel.Font = Enum.Font.GothamBold
	passesLabel.TextSize = 13
	passesLabel.TextXAlignment = Enum.TextXAlignment.Left
	passesLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
	passesLabel.Text = "Game Passes (Robux)"
	passesLabel.Parent = menu

	local passesList = Instance.new("Frame")
	passesList.BackgroundTransparency = 1
	passesList.Position = UDim2.new(0, 10, 0, 200)
	passesList.Size = UDim2.new(1, -20, 0, 100)
	passesList.Parent = menu

	local passesLayout = Instance.new("UIListLayout")
	passesLayout.Padding = UDim.new(0, 4)
	passesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	passesLayout.Parent = passesList

	for order, pass in ipairs(GameConfig.GamePasses) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		row.Size = UDim2.new(1, 0, 0, 34)
		row.LayoutOrder = order
		row.Parent = passesList

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 8, 0, 2)
		nameLabel.Size = UDim2.new(1, -100, 0, 16)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Text = pass.Name
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.Position = UDim2.new(0, 8, 0, 18)
		descLabel.Size = UDim2.new(1, -100, 0, 14)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 10
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
		descLabel.Text = pass.Description
		descLabel.Parent = row

		local buyButton = Instance.new("TextButton")
		buyButton.AnchorPoint = Vector2.new(1, 0.5)
		buyButton.Position = UDim2.new(1, -6, 0.5, 0)
		buyButton.Size = UDim2.new(0, 84, 0, 26)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 11
		buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyButton.Parent = row

		if pass.Id > 0 then
			buyButton.Text = "Buy"
			buyButton.BackgroundColor3 = Color3.fromRGB(60, 110, 70)
			buyButton.MouseButton1Click:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
		else
			buyButton.Text = "Not available yet"
			buyButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
			buyButton.AutoButtonColor = false
			buyButton.Active = false
		end
	end

	Remotes.CurrencyUpdated.OnClientEvent:Connect(function(currency)
		ownedCosmetics = currency.OwnedCosmetics or {}
		activeCosmetic = currency.ActiveCosmetic
		refreshCosmeticButtons()
	end)

	local function setVisible(visible)
		if visible and closeOtherMenus then
			closeOtherMenus()
		end
		menu.Visible = visible
	end

	local function toggle()
		setVisible(not menu.Visible)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			toggle()
		end
	end)

	return { Menu = menu, Toggle = toggle, SetVisible = setVisible }
end

return ShopController
