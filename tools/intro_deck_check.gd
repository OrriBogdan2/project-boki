extends RefCounted
## --intro-deck-check: the squad intro and the skyship ride as the player sees them, for each of the 13 Hunters.
##  1. Feet: the lowest vertex of the boots (their skinned mesh, posed by the clips and the camera's lean) against
##     the deck's top, over the intro's poses. A boot sunk into the planks reads as the Hunter standing through the
##     floor; the old check only looked at where the Hunter's origin was put, not at the body drawn there.
##  2. Sounds: over the intro, the plan and the sail no held loop plays and the abyss howl (the bed for the edge of
##     the world; the ship sails over the void for the whole ride) stays quiet.
## Prints a table row per Hunter: DECK <id> <min> <max> m (sole over the deck), and the loops heard.

const FRAMES := 150            # 2.5 s: the plan's first beats (every rider has struck a pose by then)
const WARM := 30               # frames before measuring: the lift eases in (Hunter.render)
const EVERY := 6               # frames between two measurements
const DIP := 0.02              # m: a sole may sit this far under the deck (a boot's own give, not a sunk foot)
const FLOAT := 0.06            # m: ...or this far over it
const QUIET := 0.05            # an ambience layer under this is not heard
const QUIET_DB := -45.0        # dB: a held loop under this (a far wall's hum) is not heard

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(id: String) -> Match:
	SquadIntro._last_lineup = ""
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "squad_intro": true}
	o["cls"] = Arch.weight(id)
	o["arch"] = id
	m.start(o)
	m.set_process(false)
	return m

## One frame as the game draws it: the sim step, the intro, every rider's body (lean, scale, clips).
func _frame(m: Match) -> void:
	m.step(Match.DT)
	m.music_dir.tick(m, Match.DT)
	if m.intro:
		m.intro.frame(Match.DT)
	for h in m.hunters:
		h.render(Match.DT, 1.0)
		var sync = h.model.get_node_or_null("Warden/Sync") if h.model else null
		if sync:
			sync.set_process(false)
			sync._process(Match.DT)

func _feet(id: String) -> void:
	var m := await _start(id)
	var deck: float = (m.ship["node"] as Node3D).position.y + SkyshipModel.DECK_Y
	var seen := {}
	for i in FRAMES:
		_frame(m)
		deck = (m.ship["node"] as Node3D).position.y + SkyshipModel.DECK_Y
		if i < WARM or i % EVERY != 0:
			continue
		for h in m.intro.squad:
			var y := BootSole.low(h.model) - deck
			var r: Array = seen.get(h, [INF, -INF])
			seen[h] = [minf(r[0], y), maxf(r[1], y)]
	for h in seen:
		var lo: float = seen[h][0]
		var hi: float = seen[h][1]
		var tag := "%s%s" % [h.arch, "*" if h == m.player else ""]
		print("DECK row %s %s sole over the deck: min %.3f max %.3f" % [id, tag, lo, hi])
		ok(lo >= -DIP and hi <= FLOAT, "%s stands on the deck (boots %.3f to %.3f m over it)" % [tag, lo, hi])
	m.queue_free()
	await main.get_tree().process_frame

## What is heard over the ship, `secs` into the plan and again on the ride: no held loop, no abyss howl.
func _sounds(m: Match, when: String) -> void:
	var heard: Array = []
	for k in Sfx.loops:
		if (Sfx.loops[k]["p"] as AudioStreamPlayer).volume_db > QUIET_DB:
			heard.append(k)
	var abyss := float(Sfx.amb_layers.get("abyss", {}).get("want", 0.0))
	var what := "%s: no loop or abyss howl aboard (loops %s, abyss %.2f)" % [when, heard, abyss]
	ok(heard.is_empty() and abyss < QUIET, what)

## The whole of a match start as the player hears it: the intro, the plan, the sail.
func _ride() -> void:
	var m := await _start("gunslinger")
	for i in int((SquadIntro.INTRO_T + 1.0) / Match.DT):
		_frame(m)
	_sounds(m, "intro")
	for i in int((m.skydrop.plan_t + 3.0) / Match.DT):
		_frame(m)
	var sailing: bool = m.player.riding and m.player.rocket == null and not m.skydrop.planning
	ok(sailing, "the ship has set off with the squad aboard")
	_sounds(m, "ride")
	m.queue_free()
	await main.get_tree().process_frame

func run(mn: Node, _arg = null) -> void:
	main = mn
	Save.no_write = true
	for id in Arch.ids():
		await _feet(String(id))
	await _ride()
	print("INTRO_DECK_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
