--!strict
-- RemoteEvent registry. The server creates them; clients wait for them.
-- Phase 2 replaces this with Zap-generated typed remotes.
--
--   StartDive  client -> server  ()
--   SetSprint  client -> server  (sprinting: boolean)
--   SetLamp    client -> server  (on: boolean)
--   DiveState  server -> client  (Types.DiveState)
--   Notify     server -> client  (message: string)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "StartDive", "SetSprint", "SetLamp", "DiveState", "Notify" }
local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
