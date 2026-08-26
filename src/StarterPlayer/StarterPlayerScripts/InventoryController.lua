-- A dedicated "Inventory" menu (press I) for everything you've crafted,
-- separate from the raw-resource Backpack/Warehouse panels: which Tools
-- & Weapons you personally own, and how many of each Buildable the
-- shared Warehouse currently has ready to place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local InventoryController = {}

local function sortedNamesOfKind(kind)
	local names = {}
	for itemName, recipe in pairs(GameConfig.Recipes) do
		if recipe.Kind == kind then
			table.insert(names, itemName)
		end
	end
	table.sort(names)
	return names
end

local TOOL_NAMES = sortedNamesOfKind("Tool")
local BUILDABLE_NAMES = sortedNamesOfKind("Buildable")

local ROW_HEIGHT = 22

function InventoryController.Init(hud, closeOtherMenus)
	local screenGui = hud.ScreenGui

	local menu = Instance.new("Frame")
	menu.Name = "InventoryMenu"
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
	title.Text = "Inventory (press I)"
	title.Parent = menu

	local toolsHeader = Instance.new("TextLabel")
	toolsHeader.BackgroundTransparency = 1
	toolsHeader.Position = UDim2.new(0, 10, 0, 34)
	toolsHeader.Size = UDim2.new(1, -20, 0, 18)
	toolsHeader.Font = Enum.Font.GothamBold
	toolsHeader.TextSize = 13
	toolsHeader.TextXAlignment = Enum.TextXAlignment.Left
	toolsHeader.TextColor3 = Color3.fromRGB(160, 200, 255)
	toolsHeader.Text = "Tools & Weapons crafted"
	toolsHeader.Parent = menu

	local toolRows = {}
	for i, itemName in ipairs(TOOL_NAMES) do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 10, 0, 56 + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -20, 0, ROW_HEIGHT)
		row.Font = Enum.Font.Gotham
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(100, 100, 108)
		row.Text = "  " .. itemName .. " (not crafted)"
		row.Parent = menu
		toolRows[itemName] = row
	end

	local buildablesTop = 56 + (#TOOL_NAMES * ROW_HEIGHT) + 16

	local buildablesHeader = Instance.new("TextLabel")
	buildablesHeader.BackgroundTransparency = 1
	buildablesHeader.Position = UDim2.new(0, 10, 0, buildablesTop)
	buildablesHeader.Size = UDim2.new(1, -20, 0, 18)
	buildablesHeader.Font = Enum.Font.GothamBold
	buildablesHeader.TextSize = 13
	buildablesHeader.TextXAlignment = Enum.TextXAlignment.Left
	buildablesHeader.TextColor3 = Color3.fromRGB(160, 220, 160)
	buildablesHeader.Text = "Buildables ready to place (shared)"
	buildablesHeader.Parent = menu

	local buildableRows = {}
	for i, itemName in ipairs(BUILDABLE_NAMES) do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 10, 0, buildablesTop + 22 + (i - 1) * ROW_HEIGHT)
		row.Size = UDim2.new(1, -20, 0, ROW_HEIGHT)
		row.Font = Enum.Font.Gotham
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(255, 255, 255)
		row.Text = itemName .. ": 0"
		row.Parent = menu
		buildableRows[itemName] = row
	end

	-- Tool ownership: a crafted Tool always starts out in the player's
	-- Backpack (see CraftingSystem.giveTool), so watching Backpack's
	-- ChildAdded is enough to know the moment a new one is owned --
	-- equipping/unequipping just moves it to/from Character afterward.
	local ownedTools = {}

	local function markOwned(toolName)
		local row = toolRows[toolName]
		if not row or ownedTools[toolName] then
			return
		end
		ownedTools[toolName] = true
		row.Text = "* " .. toolName
		row.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	local function scanForOwnedTools(container)
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				markOwned(item.Name)
			end
		end
	end

	local backpack = player:WaitForChild("Backpack")
	scanForOwnedTools(backpack)
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			markOwned(child.Name)
		end
	end)

	local function onCharacterAdded(character)
		scanForOwnedTools(character)
	end
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	Remotes.BuildablesUpdated.OnClientEvent:Connect(function(counts)
		for itemName, row in pairs(buildableRows) do
			row.Text = itemName .. ": " .. tostring(counts[itemName] or 0)
		end
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
		if input.KeyCode == Enum.KeyCode.I then
			toggle()
		end
	end)

	return { Menu = menu, Toggle = toggle, SetVisible = setVisible }
end

return InventoryController
