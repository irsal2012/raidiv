--!strict
-- Squad UI: a SQUAD button opening a panel (invite players in this server, leave squad),
-- an invite popup (accept/decline), and a small squad member list on the left.
-- Plain Instances for now; moves to Fusion in the Phase 3 UI pass.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local SquadConfig = require(Shared:WaitForChild("Config"):WaitForChild("Squad"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local ROW_HEIGHT = 40
local GREEN = Color3.fromRGB(40, 160, 80)
local RED = Color3.fromRGB(160, 50, 50)
local BLUE = Color3.fromRGB(20, 110, 160)
local PANEL = Color3.fromRGB(15, 22, 30)

local SquadController = {}

local localPlayer = Players.LocalPlayer
local squadUserIds: { [number]: boolean } = {}

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text
	textLabel.Position = position
	textLabel.Size = size
	textLabel.Parent = parent
	return textLabel
end

local function button(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2): TextButton
	local textButton = Instance.new("TextButton")
	textButton.Font = Enum.Font.GothamBlack
	textButton.TextColor3 = Color3.new(1, 1, 1)
	textButton.TextScaled = true
	textButton.Text = text
	textButton.BackgroundColor3 = color
	textButton.Position = position
	textButton.Size = size
	corner(textButton)
	textButton.Parent = parent
	return textButton
end

local function frame(parent: Instance, position: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.1
	f.Position = position
	f.Size = size
	corner(f)
	f.Parent = parent
	return f
end

function SquadController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Squad"
	gui.ResetOnSpawn = false

	-- Open button, left edge below the Roblox menu buttons.
	-- Left-middle column (SQUAD, BOOK, SHOP): clear of Roblox chat at the top left and the
	-- thumbstick at the bottom left (doc/07 §5).
	local openButton = button(gui, "SQUAD", BLUE, UDim2.new(0, 16, 0.5, -70), UDim2.fromOffset(110, 40))
	openButton.Name = "SquadButton"

	-- Member list under it.
	local memberList = label(gui, "", UDim2.new(0, 16, 0.5, 130), UDim2.fromOffset(200, 20)) -- under the coins
	memberList.TextScaled = false
	memberList.TextSize = 16
	memberList.TextYAlignment = Enum.TextYAlignment.Top
	memberList.AutomaticSize = Enum.AutomaticSize.Y
	memberList.TextStrokeTransparency = 0.4

	-- Panel.
	local panel = frame(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(360, 370))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	label(panel, "Squad", UDim2.fromOffset(16, 12), UDim2.new(0.5, 0, 0, 30))
	local close = button(panel, "X", RED, UDim2.new(1, -48, 0, 12), UDim2.fromOffset(36, 30))
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	label(
		panel,
		`Invite players in this server (max {SquadConfig.MaxSize})`,
		UDim2.fromOffset(16, 48),
		UDim2.new(1, -32, 0, 18)
	).Font =
		Enum.Font.Gotham

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 72)
	list.Size = UDim2.new(1, -32, 1, -176)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	-- Invite Roblox friends who aren't in this server (Roblox's own invite window).
	local inviteFriends =
		button(panel, "Invite friends to Deep Salvage", GREEN, UDim2.new(0, 16, 1, -96), UDim2.new(1, -32, 0, 40))
	local inviteSentRemote = Remotes.get("InviteSent")
	inviteFriends.Activated:Connect(function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, localPlayer)
		if ok and canInvite then
			SocialService:PromptGameInvite(localPlayer)
		else
			inviteFriends.Text = "Invites unavailable here"
			task.delay(2, function()
				inviteFriends.Text = "Invite friends to Deep Salvage"
			end)
		end
	end)
	SocialService.GameInvitePromptClosed:Connect(function(player: Player, recipientIds: { number })
		if player == localPlayer and #recipientIds > 0 then
			inviteSentRemote:FireServer(#recipientIds)
		end
	end)

	local leave = button(panel, "Leave squad", RED, UDim2.new(0, 16, 1, -48), UDim2.new(1, -32, 0, 36))
	leave.Activated:Connect(function()
		Remotes.get("SquadLeave"):FireServer()
	end)

	local inviteRemote = Remotes.get("SquadInvite")
	local function refreshList()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, player in Players:GetPlayers() do
			if player == localPlayer then
				continue
			end
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
			row.Parent = list
			label(row, player.DisplayName, UDim2.fromOffset(0, 8), UDim2.new(0.6, 0, 0, 24))
			if squadUserIds[player.UserId] then
				label(row, "In squad", UDim2.new(0.65, 0, 0, 10), UDim2.new(0.35, 0, 0, 20)).Font = Enum.Font.Gotham
			else
				local invite = button(row, "Invite", GREEN, UDim2.new(0.65, 0, 0, 2), UDim2.new(0.35, 0, 0, 34))
				invite.Activated:Connect(function()
					inviteRemote:FireServer(player.UserId)
				end)
			end
		end
		leave.Visible = next(squadUserIds) ~= nil
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshList()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refreshList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.Visible then
			task.defer(refreshList)
		end
	end)

	Remotes.get("SquadState").OnClientEvent:Connect(function(state: Types.SquadState)
		table.clear(squadUserIds)
		local names = {}
		for _, member in state.members do
			if member.userId ~= localPlayer.UserId then
				squadUserIds[member.userId] = true
			end
			table.insert(names, member.name)
		end
		memberList.Text = if #state.members > 1 then "Squad:\n" .. table.concat(names, "\n") else ""
		if panel.Visible then
			refreshList()
		end
	end)

	-- Invite popup: newest invite replaces any showing one.
	local respondRemote = Remotes.get("SquadRespond")
	local popup = frame(gui, UDim2.new(0.5, 0, 0, 90), UDim2.fromOffset(340, 110))
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Visible = false
	local popupText = label(popup, "", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 44))
	popupText.TextXAlignment = Enum.TextXAlignment.Center
	local accept = button(popup, "Join", GREEN, UDim2.new(0, 16, 1, -48), UDim2.new(0.5, -24, 0, 36))
	local decline = button(popup, "No thanks", RED, UDim2.new(0.5, 8, 1, -48), UDim2.new(0.5, -24, 0, 36))

	local pendingFrom: number? = nil
	local popupToken = 0
	local function respond(join: boolean)
		if pendingFrom then
			respondRemote:FireServer(pendingFrom, join)
		end
		pendingFrom = nil
		popup.Visible = false
	end
	accept.Activated:Connect(function()
		respond(true)
	end)
	decline.Activated:Connect(function()
		respond(false)
	end)

	Remotes.get("SquadInviteReceived").OnClientEvent:Connect(function(fromUserId: number, fromName: string)
		pendingFrom = fromUserId
		popupText.Text = `{fromName} invited you to their squad`
		popup.Visible = true
		popupToken += 1
		local token = popupToken
		task.delay(SquadConfig.InviteSeconds, function()
			if popupToken == token then
				pendingFrom = nil
				popup.Visible = false
			end
		end)
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return SquadController
