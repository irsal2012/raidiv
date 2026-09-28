--!strict
-- Client entry point. Every ModuleScript in Controllers/ may export `init(controllers)` and `start()`.
-- Same two-phase contract as the server loader.

local controllersFolder = script:FindFirstChild("Controllers")
local controllers: { [string]: any } = {}

if controllersFolder then
	for _, module in controllersFolder:GetChildren() do
		if module:IsA("ModuleScript") then
			controllers[module.Name] = (require :: any)(module)
		end
	end
end

for name, controller in controllers do
	if controller.init then
		local ok, err = pcall(controller.init, controllers)
		if not ok then
			warn(`[Client] {name}.init failed: {err}`)
		end
	end
end

for name, controller in controllers do
	if controller.start then
		task.spawn(function()
			local ok, err = pcall(controller.start)
			if not ok then
				warn(`[Client] {name}.start failed: {err}`)
			end
		end)
	end
end

print("[Client] Deep Salvage booted")
