--!strict
-- Sound asset ids, e.g. "rbxassetid://1234567890". Empty = silent, so the game runs fine
-- before any audio exists. Use sounds you own or that the Creator Store lists as free to use.
-- The current set is synthesized by tools/make_sounds.py (sources in assets/audio/) and
-- uploaded by irsal2025. Re-run the script, re-upload, and paste the new ids to change one.
-- What each one is for (doc/03 Phase 3, doc/07 §4):

return table.freeze({
	Ambience = "rbxassetid://105569751738777", -- looping underwater drone while diving
	Breathing = "rbxassetid://72498713581803", -- looping regulator breath while diving; speeds up and gets louder below 25% air
	Pickup = "rbxassetid://78199681133480", -- relic taken
	Extract = "rbxassetid://140684955028197", -- climbed out with a relic haul
	Sonar = "rbxassetid://134457611118209", -- sonar pulse
	Stinger = "rbxassetid://109914527393615", -- tutorial scare
	CreatureAlert = "rbxassetid://86073430720050", -- a Drifter heard something (3D, from the creature)
	CreatureChase = "rbxassetid://110749178495572", -- looping while a Drifter or Warden is chasing (3D)
	LurkerWindup = "rbxassetid://96750738447391", -- the Lurker's dodge cue (3D)
	WardenArrive = "rbxassetid://135849086937836", -- the Warden spawns (3D)
})
