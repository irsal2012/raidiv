--!strict
-- Server entry point. Every ModuleScript in Services/ may export `init(services)` and `start()`.
-- All inits run first (wire dependencies, no yielding), then all starts (connect events, loops).
-- `services` maps module name -> module, e.g. services.DiveService.

local servicesFolder = script:FindFirstChild("Services")
local services: { [string]: any } = {}

if servicesFolder then
	for _, module in servicesFolder:GetChildren() do
		if module:IsA("ModuleScript") then
			services[module.Name] = (require :: any)(module)
		end
	end
end

for name, service in services do
	if service.init then
		local ok, err = pcall(service.init, services)
		if not ok then
			warn(`[Server] {name}.init failed: {err}`)
		end
	end
end

for name, service in services do
	if service.start then
		task.spawn(function()
			local ok, err = pcall(service.start)
			if not ok then
				warn(`[Server] {name}.start failed: {err}`)
			end
		end)
	end
end

print("[Server] Deep Salvage booted")
