-- Crafting menu: toggled with "C", lists every recipe in GameConfig
-- (grouped by tier) with its cost, prerequisite, and craft time, and
-- lets the player attempt to craft it. Everything is spent from the
-- shared base Warehouse, validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CraftingController = {}

local function costText(cost)
	local parts = {}
	for name, amount in pairs(cost) do
		table.insert(parts, string.format("%s x%d", name, amount))
	end
	return table.concat(parts, ", ")
end

local function detailText(recipe)
	local details = { "Tier " .. recipe.Tier }
	if recipe.Requires then
		table.insert(details, "needs " .. recipe.Requires)
	end
	if recipe.CraftTime and recipe.CraftTime > 0 then
		table.insert(details, recipe.CraftTime .. "s")
	end
	return table.concat(details, " - ")
end

local function sortedRecipes()
	local entries = {}
	for itemName, recipe in pairs(GameConfig.Recipes) do
		table.insert(entries, { Name = itemName, Recipe = recipe })
	end
	table.sort(entries, function(a, b)
		if a.Recipe.Tier ~= b.Recipe.Tier then
			return a.Recipe.Tier < b.Recipe.Tier
		end
		return a.Name < b.Name
	end)
	return entries
end

function CraftingController.Init(hud, closeOtherMenus)
	local screenGui = hud.ScreenGui

	local menu = Instance.new("Frame")
	menu.Name = "CraftingMenu"
	menu.AnchorPoint = Vector2.new(1, 0.5)
	menu.Position = UDim2.new(1, -20, 0.5, 0)
	menu.Size = UDim2.new(0, 280, 0, 440)
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
	title.Text = "Crafting (press C)"
	title.Parent = menu

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 10, 0, 36)
	list.Size = UDim2.new(1, -20, 1, -46)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = menu
	layout.Parent = list

	for order, entry in ipairs(sortedRecipes()) do
		local itemName, recipe = entry.Name, entry.Recipe

		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		row.Size = UDim2.new(1, 0, 0, 58)
		row.LayoutOrder = order
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 8, 0, 4)
		nameLabel.Size = UDim2.new(1, -16, 0, 18)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Text = itemName
		nameLabel.Parent = row

		local detailLabel = Instance.new("TextLabel")
		detailLabel.BackgroundTransparency = 1
		detailLabel.Position = UDim2.new(0, 8, 0, 21)
		detailLabel.Size = UDim2.new(1, -70, 0, 16)
		detailLabel.Font = Enum.Font.Gotham
		detailLabel.TextSize = 11
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
		detailLabel.Text = detailText(recipe)
		detailLabel.Parent = row

		local costLabel = Instance.new("TextLabel")
		costLabel.BackgroundTransparency = 1
		costLabel.Position = UDim2.new(0, 8, 0, 37)
		costLabel.Size = UDim2.new(1, -70, 0, 18)
		costLabel.Font = Enum.Font.Gotham
		costLabel.TextSize = 12
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		costLabel.Text = costText(recipe.Cost)
		costLabel.Parent = row

		local craftButton = Instance.new("TextButton")
		craftButton.AnchorPoint = Vector2.new(1, 0.5)
		craftButton.Position = UDim2.new(1, -8, 0.5, 0)
		craftButton.Size = UDim2.new(0, 60, 0, 30)
		craftButton.Font = Enum.Font.GothamBold
		craftButton.TextSize = 13
		craftButton.BackgroundColor3 = Color3.fromRGB(70, 130, 80)
		craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		craftButton.Text = "Craft"
		craftButton.Parent = row

		craftButton.MouseButton1Click:Connect(function()
			craftButton.Text = "..."
			local ok, resultOrError = Remotes.CraftItem:InvokeServer(itemName)
			craftButton.Text = "Craft"
			if ok then
				hud.ShowToast("Crafted " .. itemName)
			else
				hud.ShowToast(resultOrError or "Cannot craft")
			end
		end)
	end

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
		if input.KeyCode == Enum.KeyCode.C then
			toggle()
		end
	end)

	return { Menu = menu, Toggle = toggle, SetVisible = setVisible }
end

return CraftingController
