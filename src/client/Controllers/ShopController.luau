--!strict
-- Shop panel: Pearl packs and game passes (Robux, prompted through MarketplaceService) and lamp
-- colours (Pearls, validated on the server). The SHOP button appears after the first
-- extraction. Robux items whose id is still 0 in Config/Monetization are hidden.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = Shared:WaitForChild("Config")
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local GREEN = Color3.fromRGB(40, 160, 80)
local GREY = Color3.fromRGB(70, 75, 80)
local ROBUX = Color3.fromRGB(0, 140, 90)
local ROW_HEIGHT = 44

local ShopController = {}

local localPlayer = Players.LocalPlayer

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

local function textLabel(parent: Instance, text: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

local function textButton(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Font = Enum.Font.GothamBlack
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = text
	button.BackgroundColor3 = color
	button.Position = position
	button.Size = size
	corner(button)
	button.Parent = parent
	return button
end

function ShopController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false

	local openButton =
		textButton(gui, "SHOP", Color3.fromRGB(170, 120, 20), UDim2.new(0, 16, 0.5, 30), UDim2.fromOffset(110, 40))
	openButton.Name = "ShopButton"
	openButton.Visible = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 460)
	panel.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	corner(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 460)
	limit.Parent = panel

	local title = textLabel(panel, "Shop", UDim2.fromOffset(16, 12), UDim2.new(1, -80, 0, 30))
	local close =
		textButton(panel, "X", Color3.fromRGB(160, 50, 50), UDim2.new(1, -48, 0, 12), UDim2.fromOffset(36, 30))
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -68)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function row(): Frame
		order += 1
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		frame.Parent = list
		return frame
	end
	local function heading(text: string)
		local frame = row()
		frame.Size = UDim2.new(1, -8, 0, 26)
		textLabel(frame, text, UDim2.fromOffset(0, 2), UDim2.new(1, 0, 1, -4)).TextColor3 =
			Color3.fromRGB(150, 200, 230)
	end

	local buyCosmetic = Remotes.get("ShopBuyCosmetic")
	local equipCosmetic = Remotes.get("ShopEquip")

	local function render(state: Types.ShopState)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		order = 0
		title.Text = `Shop  ·  {state.pearls} Pearls`

		local robuxShown = false
		heading("Pearls")
		for _, pack in Monetization.PearlPacks do
			if pack.id == 0 then
				continue
			end
			robuxShown = true
			local frame = row()
			textLabel(frame, `{pack.pearls} Pearls`, UDim2.fromOffset(0, 10), UDim2.new(0.6, 0, 0, 24))
			textButton(frame, `R$ {pack.price}`, ROBUX, UDim2.new(0.65, 0, 0, 4), UDim2.new(0.35, 0, 0, 36)).Activated:Connect(
				function()
					MarketplaceService:PromptProductPurchase(localPlayer, pack.id)
				end
			)
		end

		heading("Passes")
		for key, pass in Monetization.GamePasses :: any do
			if pass.id == 0 then
				continue
			end
			robuxShown = true
			local frame = row()
			textLabel(frame, pass.name, UDim2.fromOffset(0, 2), UDim2.new(0.62, 0, 0, 22))
			local description = textLabel(frame, pass.description, UDim2.fromOffset(0, 24), UDim2.new(0.62, 0, 0, 16))
			description.Font = Enum.Font.Gotham
			if state.passes[key] then
				textButton(frame, "Owned", GREY, UDim2.new(0.65, 0, 0, 4), UDim2.new(0.35, 0, 0, 36))
			else
				textButton(frame, `R$ {pass.price}`, ROBUX, UDim2.new(0.65, 0, 0, 4), UDim2.new(0.35, 0, 0, 36)).Activated:Connect(
					function()
						MarketplaceService:PromptGamePassPurchase(localPlayer, pass.id)
					end
				)
			end
		end
		if not robuxShown then
			local frame = row()
			local note = textLabel(frame, "Robux items coming soon", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 22))
			note.Font = Enum.Font.Gotham
		end

		heading("Lamp colours")
		for _, item in Cosmetics do
			local frame = row()
			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.fromOffset(0, 8)
			swatch.Size = UDim2.fromOffset(28, 28)
			swatch.BackgroundColor3 = Color3.fromRGB(table.unpack(item.color))
			corner(swatch)
			swatch.Parent = frame
			textLabel(frame, item.name, UDim2.fromOffset(38, 10), UDim2.new(0.6, -38, 0, 24))

			local owned = item.price == 0 or state.ownedCosmetics[item.id] == true
			local equipped = (state.equipped[item.slot] or "lamp_standard") == item.id
			local position, size = UDim2.new(0.65, 0, 0, 4), UDim2.new(0.35, 0, 0, 36)
			if equipped then
				textButton(frame, "Equipped", GREY, position, size)
			elseif owned then
				textButton(frame, "Equip", GREEN, position, size).Activated:Connect(function()
					equipCosmetic:FireServer(item.id)
				end)
			else
				local affordable = state.pearls >= item.price
				textButton(frame, `{item.price} Pearls`, if affordable then GREEN else GREY, position, size).Activated:Connect(
					function()
						buyCosmetic:FireServer(item.id)
					end
				)
			end
		end
	end

	local requestRemote = Remotes.get("ShopRequest")
	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			requestRemote:FireServer()
		end
	end)
	Remotes.get("ShopState").OnClientEvent:Connect(function(state: Types.ShopState)
		openButton.Visible = state.unlocked
		render(state)
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return ShopController
