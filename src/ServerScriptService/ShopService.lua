-- Cosmetic shop: spend Embers (earned for nights survived) on purely
-- procedural cosmetics (a colored aura light) -- no external asset IDs
-- needed. Real Robux Game Passes are handled separately by
-- GamePassService, since those require an actual Game Pass ID from the
-- Creator Dashboard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyCosmetic = Remotes:WaitForChild("BuyCosmetic")
local SetActiveCosmetic = Remotes:WaitForChild("SetActiveCosmetic")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

local ShopService = {}

local function findCosmetic(cosmeticId)
	for _, cosmetic in ipairs(GameConfig.Cosmetics) do
		if cosmetic.Id == cosmeticId then
			return cosmetic
		end
	end
	return nil
end

local function applyAura(character, cosmeticId)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local existing = rootPart:FindFirstChild("CosmeticAura")
	if existing then
		existing:Destroy()
	end

	local cosmetic = cosmeticId and findCosmetic(cosmeticId)
	if not cosmetic then
		return
	end

	local light = Instance.new("PointLight")
	light.Name = "CosmeticAura"
	light.Color = cosmetic.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = rootPart
end

function ShopService.ApplyActiveCosmetic(player, character)
	local data = PlayerDataManager.Get(player)
	applyAura(character, data and data.ActiveCosmetic)
end

function ShopService.Start()
	BuyCosmetic.OnServerInvoke = function(player, cosmeticId)
		local cosmetic = findCosmetic(cosmeticId)
		if not cosmetic then
			return false, "Unknown cosmetic"
		end

		if PlayerDataManager.OwnsCosmetic(player, cosmeticId) then
			return false, "Already owned"
		end

		if not PlayerDataManager.SpendCurrency(player, cosmetic.Cost) then
			return false, "Not enough " .. GameConfig.Currency.Name
		end

		PlayerDataManager.GrantCosmetic(player, cosmeticId)
		return true, cosmeticId
	end

	SetActiveCosmetic.OnServerEvent:Connect(function(player, cosmeticId)
		if cosmeticId ~= nil and not PlayerDataManager.OwnsCosmetic(player, cosmeticId) then
			return
		end
		PlayerDataManager.SetActiveCosmetic(player, cosmeticId)

		local character = player.Character
		if character then
			applyAura(character, cosmeticId)
		end
	end)
end

return ShopService
