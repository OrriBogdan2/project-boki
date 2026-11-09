extends RefCounted
## --heal-read-check: every heal and shield gain reads the same way (HealRead). Part 1 reads the scripts:
## no code raises health or a shield by hand except the helper itself and the listed non-heals (regen,
## max-health bonuses). Part 2 plays it: a heal gives the green rise and one green number per MERGE_S,
## heals from each source go through the helper, a squadmate's heal shows, a rival's shows only when big,
## the dash-reset heal and a dash give no rise, a shield gain flashes the shell white, and a remote
## Hunter's heal and shield gain from a snapshot show too. With --shots-dir=<dir> (on a GPU) it also writes
## heal_read_strip.png: a self heal and a shield gain, frame by frame. Never touches the save.

const DT := 1.0 / 60.0
const HEAL_RE := "hp\\s*=\\s*minf\\([^,]*max_hp[^,]*,\\s*[A-Za-z_.]*\\bhp\\s*\\+|\\bhp\\s*\\+="
const SHIELD_RE := "\\bshield\\s*=\\s*maxf\\(|set\\(\"shield\"|\\bshield\\s*\\+="
## [file, a piece of the line, why it is not a heal read] for the lines Part 1 lets through
const ALLOWED := [
	["scripts/match/heal_read.gd", "(e as Hunter).shield = maxf", "the helper"],
	["scripts/match/heal_read.gd", "(e as Kin).shield = maxf", "the helper"],
	["scripts/match/hunter.gd", "hp = minf(max_hp, hp + n)", "Hunter.heal, which calls the helper"],
	["scripts/combat/effects.gd", "t.hp = minf(t.max_hp, t.hp + n)", "Effects._heal, which calls the helper"],
	["scripts/match/hunter.gd", "hp + kin_hp_added", "a Boki's max-health bonus coming on"],
	["scripts/match/hunter.gd", "hp + regen", "passive regen"],
	["scripts/match/hunter.gd", "hp + 15.0", "Toughskin's max-health bonus"],
	["scripts/match/kin.gd", "hp + max_hp * 0.02 * dt", "a Boki resting in the satchel"],
	["scripts/match/kin.gd", "hp + dt * 0.5", "a dazed wild Boki coming round"],
	["scripts/kin/kin_regen.gd", "k.hp + heal", "KinRegen, out-of-fight regen with its own motes"],
	["scripts/match/boss.gd", "hp + max_hp * 0.08 * dt", "a boss regenerating at home"],
	["scripts/arch/kits/dredge_kit.gd", "h.hp += delta", "Salvage raising max health"],
	["scripts/match/level_growth.gd", "h.hp += want", "a level's extra health"],
]
const STRIP_T := [0.0, 0.05, 0.12, 0.2, 0.3, 0.45]     # s after the heal / the shield gain, one crop each
const CROP := 320                                    # px: each crop's side

var bad := 0
var _dir := ""
var _crops: Array = []

func ok(cond: bool, what: String) -> void:
	print("HEALREAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): _dir = String(a).substr(12)
	if _dir != "": DirAccess.make_dir_recursive_absolute(_dir)
	_scan()
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	m.heal_read.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var ally: Hunter = null
	var rival: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team == P.team and ally == null: ally = o
		if o.team != P.team and rival == null: rival = o
	ok(ally != null and rival != null, "a squadmate and a rival are in the match")
	ally.teleport(P.pos + Vector3(2.0, 0, 0))
	rival.teleport(P.pos + Vector3(-2.0, 0, 3.0))
	await _settle(main, m, P, 0.3)
	await _self_heal(main, m, P)
	await _sources(main, m, P, ally)
	await _sides(main, m, P, ally, rival)
	await _no_rise(main, m, P, rival)
	await _shield(main, m, P)
	await _remote(main, m, P, rival)
	_save_strip()
	print("HEALREAD done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Part 1: every line that raises health or a shield by hand is the helper or a listed non-heal.
func _scan() -> void:
	var heal := RegEx.create_from_string(HEAL_RE)
	var shield := RegEx.create_from_string(SHIELD_RE)
	var seen := {}
	for path in _scripts("res://scripts"):
		var rel := String(path).trim_prefix("res://")
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := String(line).get_slice("#", 0)
			if heal.search(code) == null and shield.search(code) == null:
				continue
			var allowed := false
			for al in ALLOWED:
				if al[0] == rel and code.contains(al[1]):
					allowed = true
					seen[al] = true
			if not allowed:
				ok(false, "%s:%d raises health or shield by hand: route it through HealRead" % [rel, n])
	ok(bad == 0, "every health and shield raise in scripts/ is HealRead, Hunter.heal, Effects._heal or listed")
	for al in ALLOWED:
		ok(seen.has(al), "allowed line still exists: %s '%s'" % [al[0], al[1]])

func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out

## A heal on you: a green rise at once, one green number when the window closes; five quick heals make one
## number and one rise.
func _self_heal(main: Node, m: Match, P: Hunter) -> void:
	P.hp = P.max_hp * 0.4
	var r0: int = m.heal_read.rises
	P.heal(20.0)
	ok(m.heal_read.rises == r0 + 1, "a heal on you: the green rise starts at once")
	for t in STRIP_T:
		await _settle(main, m, P, t - (STRIP_T[STRIP_T.find(t) - 1] if t > 0.0 else 0.0))
		await _crop(main, P)
	ok(_number_on(m, P) == 20, "one '+20' green number over you (got %d)" % _number_on(m, P))
	await _settle(main, m, P, 1.2)
	r0 = m.heal_read.rises
	var n0: int = m.heal_read.numbers
	for i in 5:
		P.heal(4.0)
		await _settle(main, m, P, 0.04)
	await _settle(main, m, P, HealRead.MERGE_S)
	ok(m.heal_read.rises == r0 + 1, "five heals inside %.1f s: one rise" % HealRead.MERGE_S)
	ok(m.heal_read.numbers == n0 + 1 and is_equal_approx(m.heal_read.last_number, 20.0),
		"five heals of 4: one merged '+20' (got +%.0f)" % m.heal_read.last_number)
	await _settle(main, m, P, 1.2)

## Every kind of heal source reaches the helper.
func _sources(main: Node, m: Match, P: Hunter, ally: Hunter) -> void:
	var sources := {
		"ability heal (Effects)": func(): Effects.run([{"type": "heal", "amount": 15.0}], P, {}),
		"ally area heal (Effects)": func(): Effects.run([{"type": "ally_area", "heal": 15.0, "radius": 3.0}], P,
			{"at": P.pos}),
		"Meeko's heal (CareUtil)": func(): CareUtil.heal(m, ally, 15.0),
		"area field heal (Fields)": func(): m.fields.add(P, P.pos, {"heal": 15.0, "radius": 3.0, "time": 0.6,
			"every": 0.2}, {}, 1.0),
		"a tonic (Hunter.heal)": func(): P.heal(15.0),
	}
	for src in sources:
		P.hp = P.max_hp * 0.4
		ally.hp = ally.max_hp * 0.4
		var h0: int = m.heal_read.heals
		(sources[src] as Callable).call()
		await _settle(main, m, P, 0.4)
		ok(m.heal_read.heals > h0, "%s goes through HealRead" % src)
	var k: Kin = P.kin if P.kin else m.give_kin(P, Save.new_kin("pebbit"))
	k.hp = k.max_hp * 0.4
	var h1: int = m.heal_read.heals
	Effects._heal(k, 10.0)
	ok(m.heal_read.heals > h1, "a heal on your Boki goes through HealRead")
	k.dead = true          # (out of the way: it would fight the rival)
	k.visible = false
	P.kin = null
	await _settle(main, m, P, 1.0)

## Your squad's heals always show; a rival's only when big.
func _sides(main: Node, m: Match, P: Hunter, ally: Hunter, rival: Hunter) -> void:
	ally.hp = ally.max_hp * 0.5
	var r0: int = m.heal_read.rises
	var n0: int = m.heal_read.numbers
	ally.heal(5.0)
	await _settle(main, m, P, HealRead.MERGE_S + 0.05)
	ok(m.heal_read.rises == r0 + 1 and m.heal_read.numbers == n0 + 1 and is_equal_approx(m.heal_read.last_number, 5.0),
		"a small heal on your squadmate shows")
	rival.hp = rival.max_hp * 0.5
	r0 = m.heal_read.rises
	n0 = m.heal_read.numbers
	rival.heal(rival.max_hp * HealRead.BIG_K * 0.5)
	await _settle(main, m, P, HealRead.MERGE_S + 0.05)
	ok(m.heal_read.rises == r0 and m.heal_read.numbers == n0, "a small heal on a rival does not show")
	await _settle(main, m, P, 1.0)
	rival.heal(rival.max_hp * HealRead.BIG_K * 1.5)
	await _settle(main, m, P, HealRead.MERGE_S + 0.05)
	ok(m.heal_read.rises == r0 + 1 and m.heal_read.numbers == n0 + 1, "a big heal on a rival shows")
	await _settle(main, m, P, 1.0)

## The heal a dash reset gives shows its number only; a dash shows nothing.
func _no_rise(main: Node, m: Match, P: Hunter, rival: Hunter) -> void:
	P.hp = P.max_hp * 0.5
	var r0: int = m.heal_read.rises
	var n0: int = m.heal_read.numbers
	DashReset.takedown(P, rival)
	await _settle(main, m, P, HealRead.MERGE_S + 0.05)
	ok(m.heal_read.rises == r0 and m.heal_read.numbers == n0 + 1, "the dash-reset heal: its number, no green rise")
	r0 = m.heal_read.rises
	P.inp["dash"] = true
	await _settle(main, m, P, 0.1)
	P.inp["dash"] = false
	await _settle(main, m, P, 0.5)
	ok(m.heal_read.rises == r0, "a dash gives no green rise")

## A shield gain flashes the shell white for GAIN_S, then it shows the side colour.
func _shield(main: Node, m: Match, P: Hunter) -> void:
	P.shield = 0.0
	P.shield_t = 0.0
	await _settle(main, m, P, 0.1)
	Effects.run([{"type": "shield", "amount": 40.0, "time": 5.0}], P, {})
	await _settle(main, m, P, DT)
	ok(P.get_meta(ShieldLook.META, Color.BLACK) == Color.WHITE, "a shield gain: the shell flashes white")
	for t in STRIP_T:
		await _settle(main, m, P, t - (STRIP_T[STRIP_T.find(t) - 1] if t > 0.0 else 0.0))
		await _crop(main, P)
	var side: Color = P.get_meta(ShieldLook.META, Color.BLACK)
	ok(side != Color.WHITE and side != Color.BLACK, "after the flash the shell is back to the side colour")
	var at0: float = P.get_meta(ShieldLook.GAIN_META, -1.0)
	m.heal_read.shield(P, 10.0)
	ok(is_equal_approx(float(P.get_meta(ShieldLook.GAIN_META, -1.0)), at0), "a smaller shield: no flash")
	P.shield = 0.0
	await _settle(main, m, P, 0.3)

## A remote Hunter heals and shields on its own game; the snapshot's rise shows here (not regen).
func _remote(main: Node, m: Match, P: Hunter, rival: Hunter) -> void:
	rival.hp = rival.max_hp * 0.5
	var r0: int = m.heal_read.rises
	m.heal_read.note(rival)
	rival.hp += 1.0
	m.heal_read.synced(rival)
	ok(m.heal_read.rises == r0, "a remote rise of 1 hp (regen) shows nothing")
	m.heal_read.note(rival)
	rival.hp += rival.max_hp * 0.3
	rival.shield = 30.0
	m.heal_read.synced(rival)
	ok(m.heal_read.rises == r0 + 1, "a remote big heal from a snapshot shows")
	ok(rival.has_meta(ShieldLook.GAIN_META), "a remote shield gain from a snapshot flashes the shell")
	await _settle(main, m, P, 0.4)

func _number_on(m: Match, e: Ent) -> int:
	var best := 0
	for n in m.fx.nums:
		if String(n.get("pre", "")) == "+" and (n["base"] as Vector3).distance_to(e.pos + Vector3(0, 1.6, 0)) < 1.0 \
				and (n["node"] as Label3D).visible:
			best = maxi(best, int(round(float(n["val"]))))
	return best

func _settle(main: Node, m: Match, P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		m.step(DT)
		m.heal_read.tick(DT)
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(P.pos)
		await main.get_tree().process_frame
		t += DT

func _crop(main: Node, P: Hunter) -> void:
	if _dir == "":
		return
	await main.get_tree().process_frame
	var vp := main.get_viewport()
	var img := vp.get_texture().get_image()
	var c := vp.get_camera_3d().unproject_position(P.position + Vector3(0, 1.0, 0))
	c *= Vector2(img.get_size()) / vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2 + 40), Vector2i(CROP, CROP))
	_crops.append(img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))))

## Two rows (the heal, the shield gain), one crop per STRIP_T.
func _save_strip() -> void:
	if _dir == "" or _crops.is_empty():
		return
	var cols := STRIP_T.size()
	var rows := ceili(_crops.size() / float(cols))
	var out := Image.create(CROP * cols, CROP * rows, false, Image.FORMAT_RGBA8)
	for i in _crops.size():
		var c: Image = _crops[i]
		c.convert(Image.FORMAT_RGBA8)
		out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(i % cols * CROP, i / cols * CROP))
	out.save_png(_dir.path_join("heal_read_strip.png"))
