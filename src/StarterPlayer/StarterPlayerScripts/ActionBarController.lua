-- An always-visible row of buttons for Craft/Build/Shop/Ranks, so every
-- menu is reachable by clicking instead of needing to already know its
-- hotkey. Each button just calls the same Toggle() the hotkey calls.
-- Placed top-center, just under the night/currency labels, to stay clear
-- of the menus themselves (which dock left/right/bottom-center).

local ActionBarController = {}

local BUTTONS = {
	{ Label = "Craft (C)", Color = Color3.fromRGB(70, 130, 80) },
	{ Label = "Build (B)", Color = Color3.fromRGB(80, 110, 150) },
	{ Label = "Shop (V)", Color = Color3.fromRGB(150, 110, 40) },
	{ Label = "Ranks (L)", Color = Color3.fromRGB(120, 90, 150) },
}

local BUTTON_WIDTH = 110
local BUTTON_HEIGHT = 40
local GAP = 8

function ActionBarController.Init(hud, handlers)
	local screenGui = hud.ScreenGui

	local totalWidth = (#BUTTONS * BUTTON_WIDTH) + ((#BUTTONS - 1) * GAP)

	local bar = Instance.new("Frame")
	bar.Name = "ActionBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.02, 96)
	bar.Size = UDim2.new(0, totalWidth, 0, BUTTON_HEIGHT)
	bar.BackgroundTransparency = 1
	bar.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for i, info in ipairs(BUTTONS) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, BUTTON_WIDTH, 1, 0)
		button.LayoutOrder = i
		button.BackgroundColor3 = info.Color
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = info.Label
		button.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local handler = handlers[i]
		if handler then
			button.MouseButton1Click:Connect(handler)
		end
	end

	return bar
end

return ActionBarController
