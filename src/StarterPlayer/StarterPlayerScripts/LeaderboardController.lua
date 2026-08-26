-- Global leaderboard menu: toggled with "L", fetches the top 10 best
-- nights reached (across all servers) from LeaderboardService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local LeaderboardController = {}

function LeaderboardController.Init(hud)
	local screenGui = hud.ScreenGui

	local menu = Instance.new("Frame")
	menu.Name = "LeaderboardMenu"
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, 20, 0.5, 0)
	menu.Size = UDim2.new(0, 260, 0, 380)
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
	title.Text = "Best Nights (press L)"
	title.Parent = menu

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 10, 0, 36)
	list.Size = UDim2.new(1, -20, 1, -46)
	list.Parent = menu

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function clearRows()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function addRow(order, text)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.LayoutOrder = order
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = text
		label.Parent = list
	end

	local function refresh()
		clearRows()
		addRow(0, "Loading...")

		task.spawn(function()
			local ok, results = pcall(function()
				return Remotes.GetLeaderboard:InvokeServer(10)
			end)

			clearRows()
			if not ok or type(results) ~= "table" or #results == 0 then
				addRow(0, "No scores yet.")
				return
			end

			for i, entry in ipairs(results) do
				addRow(i, string.format("%d. %s - Night %d", i, entry.Name, entry.Night))
			end
		end)
	end

	local function toggle()
		menu.Visible = not menu.Visible
		if menu.Visible then
			refresh()
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.L then
			toggle()
		end
	end)

	return { Menu = menu, Toggle = toggle }
end

return LeaderboardController
