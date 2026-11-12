extends RefCounted
## --airdash-glide-check: an air dash straight into a glide keeps its speed, for every hunter. The
## glider must open with at least KEEP of the dash's exit speed (its speed on the last step of the dash),
## pressed during the dash it glides that step at the dash's speed (playtest 11-08 item 4).
## And the look (playtest 11-08 item 17): a Hero's dash pressed on the ground plays its ground clip, pressed in the
## air its "air_clip" (content/rules/warden_anim), never the ground one; a Hero with no air clip is listed (AIRCLIP).

const KEEP := 0.7
const HEIGHT := 40.0
const DASH_LOOK := 0.8         # s after the press its look is read over: Tarek's Rock Hop chains three hops

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AIRGLIDE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch`, high above a flat, empty patch of ground.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

func _step(m: Match) -> void:
	m.step(Match.DT)
	var hunter: Hunter = m.player
	hunter.render(Match.DT, 1.0)
	if hunter.model and hunter.model.has_node("Warden/Sync"):
		var sync: Node = hunter.model.get_node("Warden/Sync")
		sync.set_process(false)
		sync.call("_process", Match.DT)

func _clips(hunter: Hunter) -> WardenClips:
	var sync := hunter.model.get_node_or_null("Warden/Sync")
	return sync.get("clips") if sync else null

## A dash pressed on the ground, then one pressed in the air: each kit move it starts plays the clip its map picks
## for where it was pressed, and an air clip lasts the real air dash (to within the fade out of it).
func _looks(m: Match, arch: String) -> void:
	var hunter: Hunter = m.player
	var clips := _clips(hunter)
	if clips == null:
		print("AIRCLIP %s: no hand-keyed clips, the rig plays both" % arch)
		return
	var home := hunter.pos
	var ground := _dash_clips(m, true)
	_settle(m, home)
	var spent := _dash_clips(m, false)      # out of charges: the long dash, still on the ground
	_settle(m, home)
	hunter.teleport(home + Vector3(0, HEIGHT, 0))
	for i in 12:
		_step(m)
	var air := _dash_clips(m, true)
	var moves: Dictionary = clips.d.get("kmoves", {})
	_on_ground(arch, moves, ground["moves"])
	_on_ground(arch, moves, spent["moves"])
	for km in air["moves"]:
		var mv: Dictionary = moves.get(km, {})
		if not mv.has("air_clip"):
			print("AIRCLIP %s: %s has no air clip, plays %s in the air" % [arch, km, air["moves"][km]])
			continue
		var want := String(mv["air_clip"])
		var ground_pick := String(mv.get("ground_clip", mv["clip"]))
		ok(air["moves"][km].has(want) and (want == ground_pick or not air["moves"][km].has(ground_pick)),
				"%s: %s in the air plays %s (%s)" % [arch, km, want, air["moves"][km]])
		var length := clips.lib.get_animation(want).length
		ok(length + WardenClips.FADE >= float(air["dur"]), "%s: %s lasts the air dash (%.2f s clip, %.2f s dash)" %
				[arch, want, length, air["dur"]])

## Back on the spot he started from, standing, with the last move played out (Ostra's trade moves her late).
func _settle(m: Match, home: Vector3) -> void:
	for i in 150:
		_step(m)
	m.player.teleport(home)
	for i in 30:
		_step(m)
	ok(m.player.grounded, "%s: back on the ground for the next press" % m.player.arch)

## Each kit move a dash on the ground started played its ground clip, never its air one.
func _on_ground(arch: String, moves: Dictionary, seen: Dictionary) -> void:
	for km in seen:
		var mv: Dictionary = moves.get(km, {})
		if mv.is_empty():
			continue
		var got: Array = seen[km]
		var want := String(mv.get("ground_clip", mv["clip"]))
		var air_pick := String(mv.get("air_clip", want))
		ok(got.has(want) and (air_pick == want or not got.has(air_pick)),
				"%s: %s on the ground plays %s (%s)" % [arch, km, want, got])

## The clips the Hero's model plays over a dash pressed now, for the DASH_LOOK s after it (in the air: until he
## lands); `charged`: with its charges, else with none (the long dash).
## Returns {moves: {kit move id the press started: [clips]}, dur: s the dash ran}.
func _dash_clips(m: Match, charged: bool) -> Dictionary:
	var hunter: Hunter = m.player
	var air := not hunter.grounded
	hunter.dashes = hunter.max_dashes() if charged else 0.0
	hunter.ex_cd = 0.0
	hunter.inp["move"] = Vector2(1, 0)
	var pressed := m.time
	hunter.do_dash()
	var seen := {}
	var dur := 0.0
	var clips := _clips(hunter)
	for i in int(DASH_LOOK / Match.DT):
		_step(m)
		if air and hunter.grounded:
			break
		if hunter.ak.in_dash():
			dur = m.time - pressed
		if hunter.ak.anim_id != "" and hunter.ak.anim_at >= pressed:
			var got: Array = seen.get(hunter.ak.anim_id, [])
			for c in [clips.cur, clips.cur_u]:      # (the full body's clip, and a torso-only move's)
				if c != "" and not c in got:
					got.append(c)
			seen[hunter.ak.anim_id] = got
	hunter.inp["move"] = Vector2.ZERO
	return {"moves": seen, "dur": dur}

func _speed(hunter: Hunter) -> float:
	return Vector2(hunter.vel.x, hunter.vel.z).length()

## Dashes east in the air with the glide key held; returns {exit, open}: the dash's last-step speed and the speed
## on the first frame the glider is open (-1 when it never opened).
func _air_dash(m: Match) -> Dictionary:
	var hunter: Hunter = m.player
	hunter.teleport(hunter.pos + Vector3(0, HEIGHT, 0))
	hunter.inp["move"] = Vector2(1, 0)
	hunter.inp["aim"] = hunter.pos + Vector3(8, 0.9, 0)
	for i in 12:
		m.step(Match.DT)
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.do_dash()
	var exit_speed := 0.0
	for i in 150:
		hunter.inp["move"] = Vector2(1, 0)
		hunter.inp["glide"] = true
		hunter.inp["glide_btn"] = true
		m.step(Match.DT)
		if hunter.gliding:
			return {"exit": exit_speed, "open": _speed(hunter)}
		if hunter.roll_t > 0.0:
			exit_speed = _speed(hunter)
	return {"exit": exit_speed, "open": -1.0}

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		_looks(m, arch)
		m.queue_free()
		m = _match(main, arch)
		var r := _air_dash(m)
		var exit_speed: float = r["exit"]
		var open_speed: float = r["open"]
		ok(open_speed >= exit_speed * KEEP,
			"%s: dash exit %.1f m/s, glide opens at %.1f m/s (%.0f%%)" % [arch, exit_speed, open_speed,
			100.0 * open_speed / maxf(0.01, exit_speed) if exit_speed > 0.0 else 0.0])
		m.queue_free()
		await main.get_tree().process_frame
	print("AIRGLIDE DONE, failures: %d" % bad)
	main.get_tree().quit()
