--!strict
-- Sound asset ids, e.g. "rbxassetid://1234567890". Empty = silent, so the game runs fine
-- before any audio exists. Use sounds you own or that the Creator Store lists as free to use.
-- What each one is for (doc/03 Phase 3, doc/07 §4):

return table.freeze({
	Ambience = "", -- looping underwater drone while diving
	Breathing = "", -- looping regulator breath while diving; speeds up and gets louder below 25% air
	Pickup = "", -- relic taken
	Extract = "", -- climbed out with a relic haul
	Sonar = "", -- sonar pulse
	Stinger = "", -- tutorial scare
	CreatureAlert = "", -- a Drifter heard something (3D, from the creature)
	CreatureChase = "", -- looping while a Drifter or Warden is chasing (3D)
	LurkerWindup = "", -- the Lurker's dodge cue (3D)
	WardenArrive = "", -- the Warden spawns (3D)
})
