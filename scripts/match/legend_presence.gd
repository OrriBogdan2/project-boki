class_name LegendPresence
extends RefCounted
## What a legendary Boki sounds like (DECISIONS 2026-11-09). When one turns up, every player hears one
## distant roar panned toward it, and within LOOP_REACH_M of it a low presence loop plays; a capture or
## defeat ends the loop with a short sting. Every game finds the legendary the same way, from the wild
## Boki it can see (host or client, no Net event), so the cue plays once per spawn on all of them.
## Sounds: tools/gen_sfx_legendary.py, content/sfx/legendary.json.

const LOOP_KEY := "legendary"
const LOOP_REACH_M := 40.0       # m: how far the presence loop carries
const LOOP_DB := -4.0            # dB: the presence loop under the combat sounds
const ROAR_DB := -3.0            # dB: the roar at its nearest
const ROAR_FAR_DB := -9.0        # dB: the roar from across the whole map (it never drops further)
const ROAR_FAR_M := 150.0        # m: the distance at which the roar is at ROAR_FAR_DB
const STING_DB := -4.0           # dB: the capture / defeat sting

var kin: Kin = null              # the match's legendary once it has turned up (at most one a match)
var roars := 0                   # roars played this match (a check counts them)
var gone := false                # the tracked one has been captured or defeated

## The roar for a species: its theme's own timbre where there is one, else the shared roar.
static func roar_name(species: String) -> String:
	var spec := KinLib.kin(species)
	var themed := "leg_roar_" + (spec.theme if spec else "none")
	return themed if Sfx.ensure(themed) else "leg_roar"

static func is_live(k: Kin) -> bool:
	return is_instance_valid(k) and not k.dead and k.hp > 0.0 and k.state in ["wild", "dazed"]

## Once per sim step (SpawnPlan.tick's 0.25 s beat): notice a new legendary, keep its loop at its feet,
## and end it when it is gone.
func tick(m: Match) -> void:
	if kin == null:
		_find(m)
	if kin == null or gone:
		return
	if is_live(kin):
		Sfx.loop_set(LOOP_KEY, kin.pos)
	else:
		gone = true
		Sfx.loop_stop(LOOP_KEY)
		Sfx.play("leg_sting", null, STING_DB, 0.02)

func _find(m: Match) -> void:
	for k in m.kins:
		if is_live(k) and Legendary.is_legendary(k.species):
			kin = k
			gone = false
			roars += 1
			Sfx.play_toward(roar_name(k.species), k.pos, ROAR_DB, ROAR_FAR_DB, ROAR_FAR_M)
			Sfx.loop_start(LOOP_KEY, "leg_loop", k.pos, LOOP_DB, LOOP_REACH_M)
			return
