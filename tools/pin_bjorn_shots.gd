extends RefCounted
## --pin-bjorn-shots --shots-dir=<dir> [--before]: screenshots of Pin's and Bjorn's abilities, run
## through the real kits with scripted input on a flat stretch of island (xvfb, a renderer). Each shot is
## [file stem, hero, script, capture time s, camera lead m east, caption]. Writes <dir>/MANIFEST.txt as
## `<hero>/v2|<file>|<caption>`. --before runs only the "before/after" set, touching nothing but input
## and the dummy, so the same file can be dropped into an older checkout for the "before" frames.

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var dir := ""
var home := Vector3.ZERO
var lines: Array = []
var before := false
const DT := 1.0 / 60.0

const SHOTS := [
	# ------------------------------------------------ Pin
	["pin_draw_v", "archer", "draw", 0.35, 3.0, "Draw toward Empowered: the V of two lines closing on the cursor, a glint riding out, the cursor ring filling"],
	["pin_draw_empowered", "archer", "draw", 0.64, 3.0, "Empowered ready: the lines merged into one bright line, a flash at the bow"],
	["pin_draw_super", "archer", "draw_tgt", 1.3, 4.0, "Supercharged: a thick white line past the cursor to max range, the white star at the bow, the dummy ringed at its feet"],
	["pin_overdraw", "archer", "draw_tgt", 1.85, 4.0, "Overdrawn: the line and the star dim, the draw arm shakes"],
	["pin_perfect", "archer", "perfect", 0.68, 2.5, "Perfect release: the gold four-point star with its ring beside the bow hand, the cursor star"],
	["pin_arrow_flight", "archer", "empowered_miss", 0.87, 3.0, "Empowered arrow in flight: a green bolt with a teal head and a green trail, heading for the cursor"],
	["pin_spent_arrow", "archer", "empowered_miss", 1.6, 3.0, "No target: the arrow stuck in the ground at the cursor, glowing teal"],
	["pin_super_flight", "archer", "super_shot", 1.33, 4.0, "Supercharged arrow: a wide white-teal beam past the cursor"],
	["pin_super_hit", "archer", "super_shot", 1.43, 5.0, "Supercharged hit: the teal X-star burst on the dummy"],
	["pin_heavy_hold", "archer", "heavy", 1.0, 3.0, "Heavy Shot held: the V in gold and a gold bar growing from the bow"],
	["pin_heavy_flight", "archer", "heavy", 1.27, 4.0, "Heavy Shot: the thick gold arrow with violet fins, the pink crescent at her feet"],
	["pin_heavy_hit", "archer", "heavy", 1.4, 5.0, "Heavy Shot impact: red-white burst, dust as the dummy is driven back, the white ring"],
	["pin_snare", "archer", "snare", 0.62, 4.0, "Snare tap: the snare arrow flying"],
	["pin_spirit_roll", "archer", "spirit", 0.6, 2.0, "Spirit Walk: the dodge roll and its green burst"],
	["pin_spirit_inside", "archer", "spirit_rock", 1.15, 1.0, "Spirit Walk inside a rock: the green shell, her screen tinted dark blue"],
	["pin_hail_tell", "archer", "hail", 0.6, 3.0, "Hail Wall cast: the curved arc at the cursor distance (everyone sees it for the 0.35 s tell)"],
	["pin_hail_rain", "archer", "hail", 1.8, 3.0, "Hail Wall: seven green panels with fletch posts, arrows streaking down, blue burn flames on the dummy"],
	# ------------------------------------------------ Bjorn
	["bjorn_throw_flight", "bulwark", "throw", 0.62, 3.0, "Hammer thrown: tumbling, gold-orange glow and trail, flying to the cursor"],
	["bjorn_planted", "bulwark", "throw", 1.4, 3.0, "Planted at the cursor: tilted in the ground under the gold beacon ray"],
	["bjorn_recall", "bulwark", "recall", 1.62, 3.0, "Recall: the hammer flying back"],
	["bjorn_spin", "bulwark", "spin", 0.75, 1.5, "LMB held: the hammer spinning in his hand, side-on, cursor ring filling"],
	["bjorn_glint", "bulwark", "spin", 1.25, 1.5, "LMB held past 0.6 s: the glint on the hammer head"],
	["bjorn_flare", "bulwark", "spin", 1.78, 1.5, "Full charge: the flare on the hammer head and on the cursor"],
	["bjorn_slam", "bulwark", "slam", 1.86, 2.0, "Release: the flaming 180 degree crescent, carried forward"],
	["bjorn_slam_hit", "bulwark", "slam", 1.98, 2.5, "Slam impact: white dust on the dummy, the debris trail as it flies"],
	["bjorn_aegis", "bulwark", "aegis", 0.9, 1.5, "RMB held: his aegis, a curved gold slab with ribs and a hammer sigil"],
	["bjorn_aegis_block", "bulwark", "aegis_block", 1.02, 1.5, "Aegis blocking: the flash and yellow sparks"],
	["bjorn_aegis_break", "bulwark", "aegis_break", 1.2, 1.5, "Aegis broken: gold shards, SHIELD BROKEN"],
	["bjorn_smash_dash", "bulwark", "smash", 0.6, 3.0, "360 Smash: the short dash"],
	["bjorn_smash_spin", "bulwark", "smash", 0.78, 3.5, "360 Smash: the one spin hit on arrival, the red-gold swirl ring"],
	["bjorn_purify_column", "bulwark", "purify", 1.05, 1.0, "Mending Ground with the hammer in hand: the green column coming down on him, the ring filling"],
	["bjorn_purify_burst", "bulwark", "purify", 1.62, 1.0, "Mending Ground lands: the green ring bloom"],
	["bjorn_bash", "bulwark", "bash", 0.58, 2.0, "Bash: the shield shove"],
]
## The before/after pairs (top 3 gaps per hero), run on this build and, with --before, on an older one.
const PAIRS := [
	["gap1_cursor_landing", "archer", "empowered_miss", 0.95, 3.0, "Gap 1 (aim): an Empowered arrow with the cursor at 5 m"],
	["gap2_draw_reticle", "archer", "draw", 0.45, 3.0, "Gap 2 (reticle): the bow mid-draw"],
	["gap3_perfect", "archer", "perfect", 0.68, 2.5, "Gap 3 (perfect release): the frame after letting go on the stage"],
	["gap1_throw_cursor", "bulwark", "throw", 1.4, 3.0, "Gap 1 (aim): the hammer thrown with the cursor at 6 m"],
	["gap2_slam_numbers", "bulwark", "slam", 2.1, 2.5, "Gap 2 (numbers) and 4 (swing VFX): a full swing on the dummy"],
	["gap3_hold_glint", "bulwark", "spin", 1.25, 1.5, "Gap 3 (hold): the swing held 0.9 s"],
]

## The registry entry (--pin-bjorn-shots): needs --shots-dir=<dir>.
func run(main_node: Node) -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	if out == "":
		print("PINBJORN shots: pass --shots-dir=<dir>")
	else:
		await take(main_node, out)
	main_node.get_tree().quit(0)

func take(main_node: Node, out: String) -> void:
	main = main_node; dir = out
	before = "--before" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(dir)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("archer"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0
	for x in m.hunters:
		if x != P and x != T: x.teleport(home + Vector3(-30, 0, 30))
	if m.hud: m.hud.visible = false
	var list: Array = PAIRS if before else SHOTS + PAIRS
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			var want := String(a).substr(7).split(",")
			list = list.filter(func(e): return String(e[0]) in want)
	for s in list:
		await _shot(s, PAIRS.has(s))
	var f := FileAccess.open(dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	print("PINBJORN shots: %d in %s" % [lines.size(), dir])
	m.queue_free()
	await main.get_tree().process_frame

func _spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(8, W.h - 8, 3):
		for x in range(10, W.w - 18, 3):
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-4, 5):
				for dx in range(-6, 13):
					var i: int = W.idx(x + dx, z + dz)
					if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false; break
				if not good: break
			if good:
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	return start

## The nearest rock or tree tile to `p` that stands on open ground with free tiles west of it.
func _rock_near(p: Vector3) -> Vector3:
	var W = m.world
	var best := Vector3.INF
	for z in range(4, W.h - 4):
		for x in range(6, W.w - 4):
			if W.kind[W.idx(x, z)] != World.T_BLOCK: continue
			var ok := true
			for dx in range(1, 5):
				if W.kind[W.idx(x - dx, z)] != World.T_GROUND or W.kind[W.idx(x + 1, z)] == World.T_VOID: ok = false
			if not ok: continue
			var q := Vector3(x + 0.5, W.ground_at(x + 0.5, z + 0.5), z + 0.5)
			if best == Vector3.INF or q.distance_to(p) < best.distance_to(p): best = q
	return best

func _aim(at: Vector3) -> void:
	P.inp["aim"] = at + Vector3(0, 0.9, 0); P.inp["aim_y"] = at.y

func _reset(hero: String) -> void:
	if P.arch != hero or P.wid != Arch.signature(hero):
		if m.arena: m.arena.set_arch(hero, Arch.signature(hero))
		else:
			P.reclass(Arch.weight(hero), hero, Arch.signature(hero)); P.unlock_all()
		if m.arena and m.arena.card_layer: m.arena.card_layer.visible = false
	P.lvl = 6
	P.teleport(home); P.vel = Vector3.ZERO; P.hp = P.max_hp
	P.dashes = P.max_dashes(); P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = false; P.inp["sec_hold"] = false; P.inp["move"] = Vector2.ZERO
	T.teleport(home + Vector3(7.0, 0, 0)); T.hp = T.max_hp; T.vel = Vector3.ZERO; T.stun_t = 0.0; T.root_t = 0.0
	if m.arena:
		var i := 0
		for dm in m.arena.dummies:
			i += 1
			dm["at"] = home + Vector3(-14.0 - 3.0 * i, 0, -14.0)
			(dm["h"] as Hunter).teleport(dm["at"])
		if m.arena.get("bot") != null and is_instance_valid(m.arena.bot): (m.arena.bot as Hunter).teleport(home + Vector3(-20, 0, 14))
	var K = P.ak
	if K:
		K.cd["rmb"] = 0.0; K.cd["e"] = 0.0; K.ch_rmb = 2.0; K.res = 0.0
		if K.get("draw") != null: K.get("draw").quick = false
		if K.get("mace") != null and not (K.get("mace") as Dictionary).is_empty() and K.has_method("_catch"):
			K.call("_catch", true)
	AimKit.clear(P)
	_aim(home + Vector3(7.0, 0, 0))

## The scripted input for one moment at time t (s since the shot started).
func _input(what: String, t: float) -> void:
	var K = P.ak
	var at := func(x: float) -> bool: return t >= x - DT * 0.5 and t < x + DT * 0.5
	match what:
		"draw":
			P.inp["fire"] = t >= 0.0; K.res = 0.0
		"draw_tgt":
			P.inp["fire"] = true; K.res = 0.0
		"perfect":
			P.inp["fire"] = t < 0.62; K.res = 0.0
		"empowered_miss":
			T.teleport(home + Vector3(0, 0, 8.0)); _aim(home + Vector3(5.0, 0, 0))
			P.inp["fire"] = t >= 0.0 and t < 0.82; K.res = 0.0
		"super_shot":
			_aim(home + Vector3(4.0, 0, 0)); T.teleport(home + Vector3(10.0, 0, 0))
			P.inp["fire"] = t < 1.3; K.res = 0.0
		"heavy":
			K.res = 0.0
			P.inp["sec_hold"] = t < 1.25
			if at.call(0.05): K.press_rmb()
		"snare":
			K.res = 0.0
			if at.call(0.55): K.press_rmb()
		"spirit":
			P.inp["move"] = Vector2(1, 0) if t > 0.45 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
		"spirit_rock":
			if at.call(0.0):
				var rk := _rock_near(home)
				if rk != Vector3.INF:
					P.teleport(rk - Vector3(2.5, 0, 0))
					_aim(rk + Vector3(3, 0, 0))
			P.inp["move"] = Vector2(1, 0) if t > 0.45 and t < 0.8 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
			if at.call(0.85):
				var rk2 := _rock_near(home)
				if rk2 != Vector3.INF: P.teleport(rk2); P.vel = Vector3.ZERO
		"hail":
			K.res = 0.0
			_aim(home + Vector3(5.0, 0, 0)); T.teleport(home + Vector3(5.0, 0, 0).rotated(Vector3.UP, 0.4))
			if at.call(0.5): K.use_e()
		"throw":
			T.teleport(home + Vector3(0, 0, 7.0)); _aim(home + Vector3(6.0, 0, 0))
			P.inp["fire"] = at.call(0.5)
		"recall":
			T.teleport(home + Vector3(0, 0, 7.0)); _aim(home + Vector3(5.0, 0, 0))
			P.inp["fire"] = at.call(0.5) or at.call(1.5)
		"spin":
			T.teleport(home + Vector3(2.4, 0, 0)); _aim(T.pos)
			P.inp["fire"] = t > 0.4
		"slam":
			if t < 1.8: T.teleport(home + Vector3(2.4, 0, 0))
			_aim(home + Vector3(2.4, 0, 0))
			P.inp["fire"] = t > 0.4 and t < 1.82
		"aegis", "aegis_block", "aegis_break":
			T.teleport(home + Vector3(6.0, 0, 0)); _aim(T.pos)
			P.inp["sec_hold"] = t > 0.45
			if at.call(0.5): K.set("lock_t", 0.0); K.press_rmb()
			if what != "aegis" and at.call(0.98):
				if what == "aegis_break" and K.get("wall") != null and not (K.get("wall") as Dictionary).is_empty():
					K.get("wall")["hp"] = 4.0
				m.spawn_shot(T, T.pos + Vector3(-0.6, 1.0, 0), Vector2(-40, 0), 12.0, 0.3, 0.15, Color("ff6a4a"), {"kb": 0.0})
		"smash":
			T.teleport(home + Vector3(5.6, 0, 0)); _aim(T.pos)
			P.inp["move"] = Vector2(1, 0) if t > 0.45 and t < 0.7 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
		"purify":
			P.hp = P.max_hp * 0.6
			if at.call(0.95): K.use_e()
		"bash":
			T.teleport(home + Vector3(2.0, 0, 0)); _aim(T.pos)
			if at.call(0.5): P.inp["sec_hold"] = false; K.press_rmb()

func _shot(s: Array, pair: bool) -> void:
	var stem := String(s[0]); var hero := String(s[1]); var what := String(s[2])
	var cap_t := float(s[3]); var lead := float(s[4]); var caption := String(s[5])
	_reset(hero)
	for i in 30:
		m.step(DT)
		await main.get_tree().process_frame
	_reset(hero)
	var t := 0.0
	while t < cap_t:
		_input(what, t)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT); t += DT
		P.face = atan2(-(P.inp["aim"].x - P.pos.x), -(P.inp["aim"].z - P.pos.z))
		m.cam.snap(P.pos + Vector3(lead, 0, 0))
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	if "--shots-debug" in OS.get_cmdline_user_args():
		print("SHOT %s dash=%s grounded=%s dashes=%.1f ex_cd=%.1f e_cd=%.1f in_e=%s anim=%s pos=%s" % [stem, str(P.ak.st.get("last_dash")), P.grounded, P.dashes, P.ex_cd, float(P.ak.cd["e"]), P.ak.in_e(), P.ak.anim_id, str(P.pos - home)])
	if "--shots-debug" in OS.get_cmdline_user_args() and P.ak.get("fx") != null:
		var fxn: Node3D = P.ak.get("fx")
		var vis := []
		for c in fxn.get_children():
			if c is Node3D and (c as Node3D).visible: vis.append("%s@%s tree=%s" % [c.name, str((c as Node3D).global_position - home), (c as Node3D).is_visible_in_tree()])
		print("  FX in_tree=%s vis=%s visible_nodes=%s" % [fxn.is_inside_tree(), fxn.is_visible_in_tree(), str(vis)])
	if DisplayServer.get_name() == "headless":
		return
	var img := main.get_viewport().get_texture().get_image()
	var nm := "pin" if hero == "archer" else "bjorn"
	var file := ("before_" if before else ("after_" if pair else "")) + stem + ".png"
	img.save_png(dir.path_join(file))
	lines.append("%s/v2|%s|%s%s" % [nm, file, ("Before: " if before else ("After: " if pair else "")), caption])
	P.inp["fire"] = false; P.inp["sec_hold"] = false; P.inp["move"] = Vector2.ZERO
	for i in 40:
		m.step(DT)
	AimKit.clear(P)
