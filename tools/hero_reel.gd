extends "res://tools/pitch_reel.gd"
## SCRATCH (private, never shipped). --hero-reel --hunter=<id> [--hero-pass=hud|clean] [--hero-seed=N] [--foe=<id>]
## [--foe-hp=<x>] [--bot-diff=expert] [--dry] --shots-dir=<dir>: shot 11 is the hero moment (a cinematic intro with the
## HUD off, then the combo played through the REAL input actions: Input.action_press / release, read by
## Match._gather_input exactly as a keyboard and mouse would be), shot 12 the same combo inside a 2v2.
## Prints HERO_STEP / HERO_RESULT lines (fired, landed, foe hp) so a dry run says what failed.

const HERO_SHOT := 11
const FIGHT_SHOT := 12
const PORT_SHOT := 13  # v6: eye-level front portrait orbit, HUD off
const PORT_S := 6.0
const INTRO_S := 3.6  # s of the cinematic intro
const INTRO_ARC := 150.0  # deg the orbit sweeps
const INTRO_R := 2.9  # m from the hunter
const INTRO_EYE := 1.1  # m above the feet (knee height: --intro-eye=0.55)
const INTRO_FOV := 40.0
const GAP_M := 6.0  # m between the hunter and the foe at the start
const HOLD_END_S := 1.0  # s kept after the kill
const COMBO_MAX_S := 14.0  # s the combo may take before it is called failed
const FINISH_MAX_S := 6.0  # s the driver keeps hitting after the last step when the foe is still up
const READY_WAIT_S := 5.0  # s a step waits for its ability to come back before it is called not fired
const AFTER_S := 0.7  # s watched after a press for the ability's effect
const STEP_GAP_S := 0.2  # s between two steps
const WALL_SEARCH_M := 110  # m round the start the wall spot is looked for
const FLOOR_K := 0.12  # share of the foe's hp it cannot be brought under until the combo's last step
const RECAST_AFTER_S := 0.8  # s after the first press a second R (Kitefall's strike) waits
const ULT_AFTER_S := 2.5  # s watched after an ult (Kitefall and the like land late)
const WALL_REACH_M := 2.6  # m behind the foe a wall must stand for the Storm Rod's stun
const FAR_M := 70.0  # m the foe waits away during the intro
const MOVES := ["left", "right", "up", "down"]
## [label key (slot), action, slot, hold s, range m, tag]. fire has no slot (checked by the foe's hp).
const COMBOS := {
	"mage": [["sec", "secondary", "sec", 0.35, 9.0, "wall"], ["fire", "fire", "", 1.7, 9.0, ""],
		["dash", "dash", "dash", 0.2, 7.0, "through"], ["x", "hunter_ult", "x", 0.35, 8.0, ""],
		["x", "hunter_ult", "x", 0.1, 20.0, "recast"]],
	"thief": [["sec", "secondary", "sec", 0.3, 9.0, ""], ["dash", "dash", "dash", 0.2, 8.0, "in"],
		["fire", "fire", "", 1.6, 3.5, ""], ["kin", "signature", "e", 0.3, 6.0, ""],
		["x", "hunter_ult", "x", 0.3, 6.0, ""]],
	"dolm": [["kin", "signature", "e", 0.3, 8.0, ""], ["sec", "secondary", "sec", 0.3, 8.0, ""],
		["dash", "dash", "dash", 0.2, 6.0, "in"], ["x", "hunter_ult", "x", 0.3, 6.0, ""]],
	"juggernaut": [["dash", "dash", "dash", 0.5, 9.0, "in"], ["kin", "signature", "e", 0.3, 7.0, ""],
		["fire", "fire", "", 1.6, 3.0, ""], ["sec", "secondary", "sec", 0.3, 4.0, ""],
		["x", "hunter_ult", "x", 0.3, 4.0, ""]],  # ends on Gilded Riposte (Fable edit 2)
	"ashwick": [["dash", "dash", "dash", 0.2, 8.0, "in"], ["kin", "signature", "e", 0.3, 4.0, ""],
		["fire", "fire", "", 1.8, 4.5, ""], ["sec", "secondary", "sec", 0.3, 8.0, ""]],
	"tender": [["sec", "secondary", "sec", 0.3, 9.0, ""], ["fire", "fire", "", 1.6, 7.0, ""],
		["dash", "dash", "dash", 0.2, 6.0, "in"], ["sec", "secondary", "sec", 0.3, 6.0, ""]],
	"ostra": [["kin", "signature", "e", 0.3, 8.0, ""], ["sec", "secondary", "sec", 0.3, 8.0, ""],
		["x", "hunter_ult", "x", 0.3, 8.0, ""], ["fire", "fire", "", 1.6, 5.0, ""]],
	"learn": [["dash", "dash", "dash", 0.2, 8.0, "in"], ["fire", "fire", "", 2.0, 4.0, ""], ["sec", "secondary", "sec", 0.3, 8.0, ""],
		["dash", "dash", "dash", 0.2, 6.0, "in"], ["fire", "fire", "", 2.0, 4.0, ""]],  # same move for every hunter (learnings beat)
	"rimewright": [["fire", "fire", "", 1.6, 8.0, ""], ["kin", "signature", "e", 0.3, 7.0, ""],
		["sec", "secondary", "sec", 0.3, 8.0, ""], ["x", "hunter_ult", "x", 0.3, 6.0, ""]],
}

var hero_pass := "hud"
var hero_seed := 5
var foe_id := ""
var foe_hp_k := 1.0
var ally_id := ""
var foe2_id := ""
var summon_at := -1.0  # --summon-at=<s>: tap C this many s into the combo (Boki wisp out whole)
var combo_key := ""  # --combo=<key>: play another hunter's (or the generic "learn") combo
var diff := "expert"
var dry := false
var intro_eye := INTRO_EYE
var port_fov := 36.0
var port_s := PORT_S
var port_arc := 70.0
var port_r0 := 3.0
var port_r1 := 2.1
var port_y0 := 1.0
var port_y1 := 1.35
var port_eye := 1.45
var steps_log: Array = []
var reseats := 0
var floor_on := false
var casts: Array = []  # ability ids the Hunter cast (CombatBus.ability_used), in order


func run(main_node: Node) -> void:
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		hero_pass = arg.substr(12) if arg.begins_with("--hero-pass=") else hero_pass
		hero_seed = int(arg.substr(12)) if arg.begins_with("--hero-seed=") else hero_seed
		foe_id = arg.substr(6) if arg.begins_with("--foe=") else foe_id
		foe_hp_k = float(arg.substr(9)) if arg.begins_with("--foe-hp=") else foe_hp_k
		diff = arg.substr(11) if arg.begins_with("--bot-diff=") else diff
		intro_eye = float(arg.substr(12)) if arg.begins_with("--intro-eye=") else intro_eye
		combo_key = arg.substr(8) if arg.begins_with("--combo=") else combo_key
		port_fov = float(arg.substr(11)) if arg.begins_with("--port-fov=") else port_fov
		port_s = float(arg.substr(9)) if arg.begins_with("--port-s=") else port_s
		port_arc = float(arg.substr(11)) if arg.begins_with("--port-arc=") else port_arc
		port_r0 = float(arg.substr(10)) if arg.begins_with("--port-r0=") else port_r0
		port_r1 = float(arg.substr(10)) if arg.begins_with("--port-r1=") else port_r1
		port_y0 = float(arg.substr(10)) if arg.begins_with("--port-y0=") else port_y0
		port_y1 = float(arg.substr(10)) if arg.begins_with("--port-y1=") else port_y1
		port_eye = float(arg.substr(11)) if arg.begins_with("--port-eye=") else port_eye
		ally_id = arg.substr(7) if arg.begins_with("--ally=") else ally_id
		foe2_id = arg.substr(7) if arg.begins_with("--foe2=") else foe2_id
		summon_at = float(arg.substr(12)) if arg.begins_with("--summon-at=") else summon_at
		dry = dry or arg == "--dry"
		floor_on = floor_on or arg == "--hp-floor"
	await super.run(main_node)


func _hunter_for(args: PackedStringArray) -> String:
	return Demo.hunter_in(args)


func play() -> void:
	if shot == HERO_SHOT or shot == FIGHT_SHOT or shot == PORT_SHOT:
		await _hero()
	else:
		await super.play()


## The match, as _start builds it but with this take's seed and bot difficulty.
func _start_hero(arch: String) -> void:
	Save.d["first_guide"] = 99
	Save.d["name"] = HeroTitle.base_name(arch)
	var o := {"teams": 2, "squad": 3, "total": 1, "tier": 1, "seed": hero_seed, "length": 1e9, "no_drop": true,
		"raid": "clear", "blight": false, "sim_keep": true, "demo_kin": "cindle", "demo_kin_lv": "8:95",
		"bot_diff": diff, "boki_wisps": true}
	o.merge({"arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch)}, true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	_purge()
	if m.hud:
		m.hud.guide_hidden = true
	m.player.unlock_all()
	m.player.lvl = int(Hunter.ULT_AT[0])  # R (the hero ult) is gated on this level


func _hero() -> void:
	await _start_hero(hunter)
	m.length = m.time + CLOCK_LEFT_S
	var me := m.player
	var foe_arch := foe_id if Arch.exists(foe_id) else ("gunslinger" if hunter == "juggernaut" else "juggernaut")
	CombatBus.ability_used.connect(_on_cast)
	var combo: Array = COMBOS.get(combo_key if combo_key != "" else hunter, [])
	if combo.is_empty():
		fail("no combo for %s" % hunter)
		return
	var spot := _arena(me, combo)
	me.pos = spot["me"]
	var foe := _hunter("b0", 1, foe_arch, "pebbit", _ground(spot["foe"] + Vector3(FAR_M, 0, 0)))
	foe.max_hp *= foe_hp_k
	foe.hp = foe.max_hp
	foe.belt = UtilityBelt.empty()  # no tonic to drink: a hurt bot would back out and heal to half
	foe.belt_free = {}
	foe.ctrl = "idle"
	var squad_b_extra: Array = []
	squad_a = [me]
	if shot == FIGHT_SHOT:
		var ally_arch := ally_id if Arch.exists(ally_id) else String(Arch.ids()[(Arch.ids().find(hunter) + 1) % Arch.ids().size()])
		var ally := _hunter("a1", 0, ally_arch, "pebbit", _ground(spot["me"] + Vector3(-2.5, 0, 2.0)))
		squad_a.append(ally)
		squad_b_extra.append(_hunter("b1", 1, foe2_id if Arch.exists(foe2_id) else "gunslinger", "pebbit", _ground(spot["foe"] + Vector3(FAR_M, 0, 3))))
		(squad_b_extra[0] as Hunter).ctrl = "idle"
	squad_b = [foe] + squad_b_extra
	for h in squad_a + squad_b:
		h.teleport(h.pos)
	print("PITCH_HERO_INFO hunter=%s foe=%s seed=%d diff=%s bot_diff=%s lvl=%d pass=%s wall=%s" %
			[hunter, foe_arch, hero_seed, diff, m.bot_diff, me.lvl, hero_pass, spot["wall"]])
	_zoom(KIT_ZOOM)
	if shot == PORT_SHOT:
		await _portrait(me)
		return
	await _intro(me)
	for a in squad_a:
		if a != me:
			(a as Hunter).ctrl = "bot"  # the ally fights too (2v2)
	for i in squad_b.size():
		var f: Hunter = squad_b[i]
		f.ctrl = "bot"
		f.teleport(_ground(spot["foe"] + Vector3(1.5, 0, 1.5) * i))
	Record.set_level(1 if hero_pass == "hud" else 2)
	mark("combo")
	await _combo(me, foe, combo, spot)
	_release_all()


## The cinematic intro: a slow 150 degree orbit at eye height, HUD off, the Hunter idle with its Boki beside it.
func _intro(me: Hunter) -> void:
	Record.set_level(2)
	var fov0 := m.cam.fov
	var near0 := m.cam.near
	m.cam.fov = INTRO_FOV
	m.cam.near = 0.1
	mark("intro")
	var frames := roundi(INTRO_S * FPS)
	var a0 := deg_to_rad(-20.0)
	for i in frames:
		_purge()
		m.step(1.0 / FPS)
		for h in m.hunters:
			h.render(1.0 / FPS, 1.0)
		var k := float(i) / float(frames - 1)
		k = k * k * (3.0 - 2.0 * k)
		var mid := me.pos.lerp(me.kin.pos if me.kin != null else me.pos, 0.35) + Vector3(0, 0.95, 0)
		var ang := a0 + deg_to_rad(INTRO_ARC) * k
		var r := INTRO_R * lerpf(1.15, 0.85, k)
		var eye := mid + Vector3(sin(ang) * r, intro_eye - 0.95, cos(ang) * r)
		m.cam.global_transform = Transform3D(Basis.looking_at(mid - eye, Vector3.UP), eye)
		if i % 30 == 0:
			print("PITCH_HERO_DBG intro f=%d pos=%s vel=%s anim=%s ctrl=%s" % [i, me.pos, me.vel, me.get("anim_name"), me.ctrl])
		await main.get_tree().process_frame
	m.cam.fov = fov0
	m.cam.near = near0
	print("PITCH_HERO_INTRO frames=%d kin=%s" % [frames, me.kin != null])


## A spot with room all round; for a combo that needs a wall behind the foe, a foe spot with a wall within
## WALL_REACH_M one way and the Hunter WALL gap the other way.
func _arena(me: Hunter, combo: Array) -> Dictionary:
	var base := _roomy_ground(me.pos)
	var out := {"me": base, "foe": _ground(base + Vector3(GAP_M, 0, 0)), "wall": false, "dir": Vector2(1, 0)}
	var wants := false
	for s in combo:
		wants = wants or String(s[5]) == "wall"
	if not wants:
		return out
	var probe := _hunter("probe", 1, "juggernaut", "pebbit", base)
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for ring in range(0, WALL_SEARCH_M, 3):
		for dz in range(-ring, ring + 1, 3):
			for dx in range(-ring, ring + 1, 3):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var c := _ground(Vector3(base.x + dx, 0, base.z + dz))
				probe.pos = c
				for d: Vector2 in dirs:
					if KnockWall.behind(m, probe, d, WALL_REACH_M) and _open(c - Vector3(d.x, 0, d.y) * GAP_M):
						m.hunters.erase(probe)
						probe.queue_free()
						return {"me": _ground(c - Vector3(d.x, 0, d.y) * GAP_M), "foe": c, "wall": true, "dir": d}
	print("PITCH_HERO_WALL none found within %d m" % WALL_SEARCH_M)
	m.hunters.erase(probe)
	probe.queue_free()
	return out


func _open(p: Vector3) -> bool:
	var x := int(p.x)
	var z := int(p.z)
	return m.world.inb(x, z) and m.world.edge_dist(x, z, 3) > 2 and not m.world.is_void(p.x, p.z)


# ------------------------------------------------------------------ the combo driver
## Plays `combo` step by step on the real input actions; each step waits for its ability, walks into range,
## presses (hold = the aim hold of an aimed cast), lets go, and watches 0.7 s for fired / landed.
func _combo(me: Hunter, foe: Hunter, combo: Array, spot: Dictionary) -> void:
	var idx := 0
	var phase := "approach"
	var timer := 0.0
	var wait_ready := 0.0
	var prev_hp := 0.0
	var hp0 := foe.hp
	var charges0 := 0
	var casts0 := 0
	var seen_down := false
	var t := 0.0
	var end_t := -1.0
	var finish := false
	var summoned := false
	var sum_rel := -1.0
	steps_log.clear()
	while true:
		_purge()
		if floor_on and idx < combo.size() - 1 and not foe.dead:
			foe.hp = maxf(foe.hp, foe.max_hp * FLOOR_K)  # the finisher is the last step's
		if foe.hp > prev_hp + 5.0:
			print("PITCH_HERO_DBG t=%.2f foe hp %.0f -> %.0f idx=%d phase=%s" % [t, prev_hp, foe.hp, idx, phase])
		prev_hp = foe.hp
		if m.hud:
			m.hud.msgs.hold = true  # no tips, bond popups or "Last squad down" in the HUD pass
			m.hud.msgs.clear()
		me.hp = me.max_hp  # the Hunter is never the story: a take must not end on its own KO
		me.inp["aim_y"] = foe.pos.y
		var down := foe.dead or foe.downed or foe.out
		if down and end_t < 0.0:
			end_t = t
			_release_all()
			if idx < combo.size() and phase != "approach":
				_log(me, foe, combo[idx], idx, true, true, hp0, charges0, casts.size() > casts0)
			print("PITCH_HERO_KILL t=%.2f step=%d dead=%s downed=%s out=%s why=%s hp=%.0f/%.0f void=%s" % [t, idx, foe.dead, foe.downed, foe.out, foe.get_meta("died_why", "-"), foe.hp, foe.max_hp, m.world.is_void(foe.pos.x, foe.pos.z)])
		if end_t >= 0.0 and t - end_t >= HOLD_END_S:
			mark("hold_end")
			break
		if t > COMBO_MAX_S + (FINISH_MAX_S if finish else 0.0) and end_t < 0.0:
			print("PITCH_HERO_NOKILL t=%.2f idx=%d foe_hp=%.0f/%.0f" % [t, idx, foe.hp, foe.max_hp])
			break
		if summon_at >= 0.0 and t >= summon_at and not summoned:
			summoned = true
			_key("summon", true)
			sum_rel = t + 0.15
		if summoned and sum_rel > 0.0 and t >= sum_rel:
			_key("summon", false)
			sum_rel = -1.0
		var ms := Vector2.ZERO
		if end_t < 0.0:
			if idx >= combo.size():
				finish = true
				_key("fire", true)
				ms = Vector2(foe.pos.x - me.pos.x, foe.pos.z - me.pos.z).normalized() if me.flat_dist(foe) > 6.0 else ms
			else:
				var st: Array = combo[idx]
				var dist := me.flat_dist(foe)
				var to := Vector2(foe.pos.x - me.pos.x, foe.pos.z - me.pos.z)
				var info: Dictionary = me.slot_info(String(st[2])) if String(st[2]) != "" else {"ready": true}
				match phase:
					"approach":
						ms = to.normalized() if dist > float(st[4]) else Vector2.ZERO
						if String(st[5]) == "wall" and foe.pos.distance_to(spot["foe"]) > 3.0 and not down:
							foe.teleport(_ground(spot["foe"]))
							reseats += 1
						wait_ready += 1.0 / FPS
						var go: bool = bool(info["ready"])
						if String(st[5]) == "recast":
							go = me.ak != null and me.ak.ult_running() and wait_ready > RECAST_AFTER_S
						if go and dist <= float(st[4]) + 0.3:
							phase = "hold"
							timer = float(st[3])
							hp0 = foe.hp
							charges0 = int(info.get("charges", 0))
							casts0 = casts.size()
							_key(String(st[1]), true)
						elif wait_ready > READY_WAIT_S:
							_log(me, foe, st, idx, false, false, hp0, 0, false)
							idx += 1
							wait_ready = 0.0
					"hold":
						ms = to.normalized() if String(st[5]) in ["in", "through"] else Vector2.ZERO
						timer -= 1.0 / FPS
						if timer <= 0.0:
							_key(String(st[1]), false)
							phase = "after"
							timer = AFTER_S if idx + 1 < combo.size() and String(combo[idx + 1][5]) == "recast" else ULT_AFTER_S if String(st[2]) == "x" else AFTER_S
					"after":
						timer -= 1.0 / FPS
						ms = Vector2.ZERO
						if timer <= 0.0:
							_log(me, foe, st, idx, true, foe.hp < hp0 - 0.5 or foe.stun_t > 0.0, hp0, charges0, casts.size() > casts0)
							idx += 1
							phase = "approach"
							wait_ready = -STEP_GAP_S
		_move(ms)
		m._gather_input()
		me.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		me.inp["aim_y"] = foe.pos.y
		_step_frame(me.pos.lerp(foe.pos, 0.5))
		await main.get_tree().process_frame
		t += 1.0 / FPS
		seen_down = seen_down or down
	print("PITCH_HERO_RESULT hunter=%s kill=%s t=%.2f reseats=%d steps=%s casts=%s" % [hunter, end_t >= 0.0, t, reseats, steps_log, casts])


## One step's outcome: `fired` = the ability went on cooldown (or, for the basic attack, the foe lost hp).
func _log(me: Hunter, foe: Hunter, st: Array, idx: int, pressed: bool, landed: bool, hp0: float, charges0: int, cast: bool) -> void:
	var slot := String(st[2])
	var info: Dictionary = me.slot_info(slot) if slot != "" else {}
	var name := String(info.get("name", "Finger Guns / basic"))
	var fired := pressed
	if pressed and slot == "":
		fired = foe.hp < hp0 - 0.5
	elif pressed:
		fired = cast or int(info.get("charges", 0)) < charges0 or not bool(info.get("ready", true))
	var line := "PITCH_HERO_STEP %d %s (%s) fired=%s landed=%s foe_hp=%.0f" % [idx + 1, name, String(st[1]), fired, landed, foe.hp]
	print(line)
	steps_log.append("%s:%s%s" % [name, "F" if fired else "-", "L" if landed else "-"])


## A real action press or release (Input.action_press is what a key down does inside the Input singleton).
func _key(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Walk keys from a screen-space direction (camera yaw 0: east is +x, south is +z).
func _move(v: Vector2) -> void:
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("up")
	Input.action_release("down")
	if v.length() < 0.01:
		return
	Input.action_press("right" if v.x > 0.0 else "left", absf(v.x))
	Input.action_press("down" if v.y > 0.0 else "up", absf(v.y))


func _on_cast(caster: Node, ability_id: String, slot: String) -> void:
	if caster == m.player:
		casts.append("%s/%s" % [ability_id, slot])


func _release_all() -> void:
	for a in ["fire", "secondary", "signature", "dash", "hunter_ult"] + MOVES:
		Input.action_release(a)


## v6 portrait: HUD off, the Hunter idle, the camera starts 40 deg to one side of its FRONT at eye height, sweeps through the
## front to 40 deg the other side while pushing in from a full-body frame to head and shoulders. Faces readable.
func _portrait(me: Hunter) -> void:
	Record.set_level(2)
	var fov0 := m.cam.fov
	m.cam.fov = port_fov
	m.cam.near = 0.1
	var hid := 0
	if m.world != null and m.world.get("_deco") != null:
		for c in (m.world.get("_deco") as Node).get_children():
			if String(c.name).begins_with("Bushes") and c is Node3D:
				(c as Node3D).visible = false  # tall grass out of the foreground
				hid += 1
	print("PITCH_HERO_PORT hid_bush_chunks=%d" % hid)
	await main.get_tree().process_frame
	mark("intro")
	var frames := roundi(port_s * FPS)
	for i in frames:
		_purge()
		m.step(1.0 / FPS)
		for h in m.hunters:
			h.render(1.0 / FPS, 1.0)
		var k := float(i) / float(frames - 1)
		k = k * k * (3.0 - 2.0 * k)
		var ang := deg_to_rad(-port_arc * 0.5 + port_arc * k)
		var fwd := Vector3(-sin(me.face), 0, -cos(me.face))
		var dirv := fwd.rotated(Vector3.UP, ang)
		var r := lerpf(port_r0, port_r1, k)
		var look := me.pos + Vector3(0, lerpf(port_y0, port_y1, k), 0)
		var eye := look + dirv * r + Vector3(0, port_eye - lerpf(port_y0, port_y1, k), 0)
		m.cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
		if i % 15 == 0:
			var mf: Vector3 = me.model.global_transform.basis * Vector3(0, 0, -1)
			var cf: Vector3 = (look - eye).normalized()
			print("PITCH_HERO_DBG port f=%d ang=%.0f face=%.2f modelfwd=%s camfwd=%s mpos=%s pos=%s anim=%s vel=%s" % [i, rad_to_deg(ang), me.face, mf.snapped(Vector3.ONE * 0.01), cf.snapped(Vector3.ONE * 0.01), me.model.global_position, me.pos, me.get("anim_name"), me.vel])
		await main.get_tree().process_frame
	m.cam.fov = fov0
	print("PITCH_HERO_PORT frames=%d" % frames)
