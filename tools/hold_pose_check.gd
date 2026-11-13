extends "res://tools/dash_flow_check.gd"
## --hold-pose-check[=<id>,<id>]: a hold pose never shows without its key (briefs/DECISIONS.md, movement and
## combat feel). For every Hunter and every slot, each move whose clip loops a hold (warden_anim kmoves with
## "hold_from": draws, charges, guards, aims, channels) is provoked in SCENARIOS: a tap, a short press, a press
## made in a ground or air dash and let go before the dash ends (DashFlow replays it at the end), one made on its
## last step, one in the glider, and a long hold let go in a dash or in the air. Then it counts the seconds the
## kit's move sits on a hold clip, or the draw and charge state stays up, with every key up. More than
## POSE_SLACK is a failure. A tap of 1, 2 or 4 fixed steps may not show a hold clip on any frame the key is
## still down (ArchKit.HOLD_POSE_T: a hold clip comes after the press, not on it). Prints the hold moves no
## trial brought up, so a silent pass can be told from a miss.

const POSE_SLACK := 0.25        # s: a hold pose may outlast the key by the clip's own recovery, no more
const WATCH_S := 2.5            # s watched after the key goes up
const SHORT_S := 0.15           # s: a short press
const HELD_S := 0.7             # s: a hold, past every tap and charge threshold
const RELEASE_STEPS := 5        # steps into the dash the held key goes up
const TAP_STEPS := {"tap 1": 1, "tap 2": 2, "tap 4": 4}       # fixed steps the key stays down
const SCENARIOS := ["tap 1", "tap 2", "tap 4", "short", "dash buffered", "dash late", "air dash buffered", "glide",
		"held into dash", "held in air"]
const KEYS := {"lmb": ["fire"], "rmb": ["sec", "sec_hold"], "e": ["sig"], "x": ["x_down"]}
## Hold clips no key holds: a dash or dive pose, a timed cast or an ultimate's own run. They end by their clock.
const NOT_HELD := [
	"jug_meteor", "jug_guard", "lw_jet", "mm_call_hold", "tm_rime_hold", "mage_x", "mage_x_air", "bul_ult_wind",
	"thf_encore_dance", "thf_exdash", "pin_walk", "dr_reel", "dr_dive", "breah_skate", "breah_dive",
	"ostra_swap_air", "ostra_snap_wind", "ostra_well", "gil_spin", "gil_surf",
]

## Tap-pose exceptions (hero -> hold clip): the clip shows on the press on purpose, listed in the READY line.
## Archer: the owner rule "the arrow nocks within 0.05 s of the press" (pin_bjorn_owner_check).
const TAP_POSE_OPEN := {"archer": "arc_draw"}

var reached := {}               # hold clip ids the trials brought up at all, key down or up
var hold_ids := {}              # kmove id -> true, of the hero under test (its art file's "hold_from" moves)

func run(main: Node) -> void:
	Save.no_write = true
	for hero in _heroes():
		hold_ids = _hold_ids(hero)
		reached = {}
		for slot in KEYS:
			var m := _match(main, hero)
			for sc in SCENARIOS:
				_scenario(m, hero, slot, sc)
			m.queue_free()
			await main.get_tree().process_frame
		var missed := hold_ids.keys().filter(func(id): return not reached.has(id))
		print("HOLDPOSE %s: hold moves no trial reached: %s" % [hero, missed])
	print("HOLDPOSE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold-pose-check=") and arg.length() > 18:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

func _hold_ids(hero: String) -> Dictionary:
	var path := "%s%s.json" % [WardenClips.DIR, WardenGlb.ART[hero]]
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).get("kmoves", {})
	var ids := {}
	for id in moves:
		if moves[id].has("hold_from") and id not in NOT_HELD:
			ids[id] = true
	return ids

func _keys(slot: String, down: bool) -> void:
	for key in KEYS[slot]:
		hunter.inp[key] = down

func _tap(slot: String) -> void:
	if slot == "x":
		HunterKeys.ult_pressed(hunter)
	_keys(slot, true)

## One step with `slot`'s key still down ("": none). Presses are one-step, and DashFlow's replayed LMB is a tap
## too, so nothing but `slot` keeps a key down. With no key down, adds the step to `seen` (name -> s) while a
## hold clip, a bow draw or a sword charge is up. A `tap` step (key down) counts only a hold clip.
func _step(m: Match, slot: String, seen: Dictionary, tap := false) -> void:
	m.step(Match.DT)
	hunter.inp["sec"] = false
	hunter.inp["sig"] = false
	if slot != "lmb":
		hunter.inp["fire"] = false
	var id := hunter.ak.anim_id
	reached[id] = true
	if slot != "":
		if tap and hold_ids.has(id):
			seen["tap " + id] = float(seen.get("tap " + id, 0.0)) + Match.DT
		return
	var up := {"draw_t": hunter.draw_t > 0.0, "mel_hold": hunter.mel_hold > 0.0, id: hold_ids.has(id)}
	for name in up:
		if up[name]:
			seen[name] = float(seen.get(name, 0.0)) + Match.DT

func _scenario(m: Match, hero: String, slot: String, sc: String) -> void:
	_ready_up(m)
	var seen := {}
	var held := sc.begins_with("held")
	if sc.contains("air dash") or sc == "glide" or sc == "held in air":
		_lift()
	hunter.gliding = sc == "glide"
	if held:
		_tap(slot)
		for i in int(HELD_S / Match.DT):
			_step(m, slot, seen)
	if sc.contains("dash"):
		hunter.inp["move"] = Vector2(0, -1)
		hunter.inp["dash"] = true
		for i in DASH_WAIT:
			if hunter.ak.in_dash():
				break
			_step(m, slot if held else "", {})
		if not hunter.ak.in_dash():
			return
	while sc == "dash late" and hunter.ak.dash_left() > Match.DT * 2.5:
		_step(m, "", {})
	if sc == "held into dash":
		for i in RELEASE_STEPS:
			_step(m, slot, seen)
	elif not held:
		_tap(slot)
		var n: int = TAP_STEPS.get(sc, int(SHORT_S / Match.DT))
		for i in n:
			_step(m, slot, seen, TAP_STEPS.has(sc))
	_keys(slot, false)
	for i in int(WATCH_S / Match.DT):
		_step(m, "", seen)
	for name in seen:
		var what := "%s %s %s: %s up %.2f s with the key up or a tap's" % [hero, slot, sc, name, seen[name]]
		if name == "tap " + TAP_POSE_OPEN.get(hero, ""):
			continue
		var slack := 0.0 if name.begins_with("tap ") else POSE_SLACK
		ok(float(seen[name]) <= slack, what)
