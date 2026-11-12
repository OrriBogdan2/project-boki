extends RefCounted
## --receiver-cue-check: what a Hunter receiving a heal or a shield shows (ReceiverCue). Each source gives the
## cue once on the body it reaches (Meeko's Hearthlight path, Albert's zone ticks and burst, a heal effect,
## a shield effect, a heal+shield area, the Tonic, the Medkit, a knock heal, a Boki's shield, the Fuse
## afterglow), tinted by the giver's ability colour, with the number in the heal or shield colour. A zone
## ticking again inside GAP_S is one rise; a zero heal or a downed body shows nothing; no particle burst
## or ring fires; the cue draws with the particle quality at zero (readable at the lowest setting); no
## script raises a shield by hand any more. With --shots-dir=<dir> (a renderer) it writes a crop per source.
## Never touches the save.

const DT := 1.0 / 60.0
const SHIELD_RAISE_RE := "\\.shield\\s*=\\s*maxf\\("
## the scripts that may raise a shield by hand: the helper itself and the generic expiry/clear lines
const SHIELD_OK := ["scripts/match/receiver_cue.gd"]
const SETTLE_S := 0.3        # s a source runs before its cues are counted (a Boki ability lands a moment later)
const SHOT_S := 0.1          # s after a source the crop is taken, while the cue is at its fullest
const CLEAR_S := 0.4         # s between sources, so the next one starts clean
const ZOOM_PX := 260         # px: a crop's side on screen

var bad := 0
var _dir := ""
var _body_at := Vector3.ZERO      # where the crops are centred (the player's chest)

func ok(cond: bool, what: String) -> void:
	print("RECEIVERCUE %s %s" % ["ok  " if cond else "FAIL", what])
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
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "arch": "bulwark",
		"cls": Arch.weight("bulwark"), "weapon": Arch.signature("bulwark")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var ally: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team == P.team and ally == null: ally = o
	ally.teleport(P.pos + Vector3(8.0, 0, 8.0))       # far from P: area sources reach one body at a time
	var cue := ReceiverCue.of(m)
	cue.set_process(false)                              # (stepped by hand in _settle, like the match)
	_body_at = P.pos + Vector3(0, 1.0, 0)
	await _settle(main, m, P, 0.4)
	await _sources(main, m, P, ally, cue)
	await _rules(main, m, P, ally, cue)
	print("RECEIVERCUE done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Part 1: no script raises a shield by hand outside the helper.
func _scan() -> void:
	var re := RegEx.new()
	re.compile(SHIELD_RAISE_RE)
	var hits: Array = []
	for f in _gd_files("res://scripts"):
		if SHIELD_OK.has(f.trim_prefix("res://")):
			continue
		for line in FileAccess.get_file_as_string(f).split("\n"):
			if re.search(line):
				hits.append("%s: %s" % [f.get_file(), line.strip_edges().left(60)])
	ok(hits.is_empty(), "every shield gain goes through ReceiverCue.shield (%s)" % [hits])

func _gd_files(dir: String) -> Array:
	var out: Array = []
	for n in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + n))
	for n in DirAccess.get_files_at(dir):
		if n.ends_with(".gd"):
			out.append(dir + "/" + n)
	return out

func _reset(m: Match, hs: Array, cue: ReceiverCue) -> void:
	for h in hs:
		h.hp = h.max_hp * 0.5
		h.shield = 0.0
		h.shield_t = 0.0
	cue._gap.clear()
	cue.last = {}

## Runs `src`, lets time pass, and asserts the cue started `want` times with the number/tint colours.
func _expect(main: Node, m: Match, P: Hunter, cue: ReceiverCue, label: String, want: int, kind: String,
		src: Callable) -> void:
	_reset(m, m.hunters, cue)
	var before := cue.shown
	src.call()
	await _settle(main, m, P, SHOT_S)
	_shot(main, label)
	await _settle(main, m, P, SETTLE_S - SHOT_S)
	ok(cue.shown - before == want, "%s: the cue starts %d time(s) (%d)" % [label, want, cue.shown - before])
	if want > 0 and kind != "":
		ok(String(cue.last.get("kind", "")) == kind, "%s: a %s cue" % [label, kind])
		var num: Color = HudStyle.SHIELD if kind == "shield" else ReceiverCue.HEAL_COLOR
		ok(cue.last.get("number") == num, "%s: the number is in the %s colour" % [label, kind])
	await _settle(main, m, P, CLEAR_S)
	if P.ak is BulwarkKit:
		(P.ak as BulwarkKit).mend = {}

func _sources(main: Node, m: Match, P: Hunter, ally: Hunter, cue: ReceiverCue) -> void:
	var giver := Color("ff00aa")
	var lit := giver.lerp(Color.WHITE, ReceiverCue.TINT_WHITE)
	var heal_fx := [{"type": "heal", "amount": 20.0, "color": "#ff00aa"}]
	var shield_fx := [{"type": "shield", "amount": 40.0, "time": 5.0, "color": "#ff00aa"}]
	await _expect(main, m, P, cue, "Meeko heal", 1, "heal", func(): CareUtil.heal(m, P, 20.0, 5.0, giver))
	ok(cue.last.get("tint") == lit, "Meeko heal: tinted by the giver's colour")
	await _expect(main, m, P, cue, "heal effect", 1, "heal", func(): Effects.run(heal_fx, P, {}))
	ok(cue.last.get("tint") == lit, "heal effect: tinted by the effect's ability colour")
	await _expect(main, m, P, cue, "shield effect", 1, "shield", func(): Effects.run(shield_fx, P, {}))
	var pale := giver.lerp(Color.WHITE, ReceiverCue.SHIELD_WHITE)
	ok(cue.last.get("tint") == pale, "shield effect: tinted by the ability colour")
	var area := [{"type": "ally_area", "heal": 20.0, "shield": 30.0, "radius": 3.0}]
	await _expect(main, m, P, cue, "ally area (heal + shield)", 2, "", func(): Effects.run(area, P, {"at": P.pos}))
	await _expect(main, m, P, cue, "knock heal", 1, "heal", func(): P.heal(P.max_hp * 0.2))
	await _expect(main, m, P, cue, "Albert's zone tick", 1, "heal", func(): _zone(P, false))
	await _expect(main, m, P, cue, "Albert's zone burst", 1, "heal", func(): _zone(P, true))
	await _expect(main, m, P, cue, "Tonic", 1, "heal", func(): _tonic(m, P))
	await _expect(main, m, P, cue, "Medkit", 1, "heal", func(): _medkit(P))
	await _expect(main, m, P, cue, "Fuse afterglow", 1, "shield", func(): MergeRelease.afterglow(P))
	await _expect(main, m, P, cue, "Boki shield", 1, "shield", func(): _boki(m, P, "puddlet", "k2"))

func _rules(main: Node, m: Match, P: Hunter, ally: Hunter, cue: ReceiverCue) -> void:
	if P.kin:                                             # (its Refraction would shield P on its own below half health)
		P.kin.dead = true
		P.kin.visible = false
		P.kin = null
	_reset(m, m.hunters, cue)
	var before := cue.shown
	P.heal(10.0)
	P.heal(10.0)
	ok(cue.shown - before == 1, "two heals inside %.1f s are one rise" % ReceiverCue.GAP_S)
	before = cue.shown
	P.hp = P.max_hp
	P.heal(10.0)
	ok(cue.shown == before, "a heal at full health shows nothing")
	P.hp = 10.0
	P.downed = true
	P.heal(10.0)
	P.downed = false
	ok(cue.shown == before, "a downed body shows nothing")
	_reset(m, m.hunters, cue)
	ReceiverCue.shield(P, 30.0)
	before = cue.shown
	ReceiverCue.shield(P, 20.0)
	ok(cue.shown == before and P.shield == 30.0, "a shield that adds nothing shows nothing")
	ally.hp = ally.max_hp * 0.5
	before = cue.shown
	ally.heal(10.0)
	ok(cue.shown - before == 1, "a squadmate's heal shows on them")
	await _settle(main, m, P, 1.5)                        # let every other source's own effects finish
	_reset(m, m.hunters, cue)
	await _settle(main, m, P, 0.1)
	var live0 := _live(cue)
	var emitting0 := _emitting(m)          # (a control window: whatever else is firing on its own)
	await _settle(main, m, P, 0.1)
	emitting0 = maxi(emitting0, _emitting(m))
	m.fx.particles = 0.0                                  # the lowest particle setting: the cue must still draw
	P.heal(15.0)
	ReceiverCue.shield(P, 30.0)
	await _settle(main, m, P, 0.1)
	ok(_emitting(m) <= emitting0, "a heal and a shield fire no particle burst (%d -> %d)" % [emitting0, _emitting(m)])
	ok(_live(cue) == 2 and live0 == 0, "at the lowest particle setting both cues draw (%d live)" % _live(cue))
	ok(cue._slots.size() == ReceiverCue.POOL, "the cue pool is fixed at %d bodies" % ReceiverCue.POOL)
	await _settle(main, m, P, ReceiverCue.RISE_S + 0.1)
	ok(_live(cue) == 0 and cue.live == 0, "the cues end (%d on screen, live %d)" % [_live(cue), cue.live])

func _emitting(m: Match) -> int:
	var n := 0
	for b in m.fx.bursts:
		if b.emitting: n += 1
	return n

func _live(cue: ReceiverCue) -> int:
	var n := 0
	for s in cue._slots:
		if (s["mi"] as MeshInstance3D).visible: n += 1
	return n

func _zone(P: Hunter, burst: bool) -> void:
	var k := P.ak as BulwarkKit
	k.mend = {"pos": P.pos, "r": 5.0, "t": 1.0, "zone": 1.0, "tick": 9.0}
	if burst:
		k._mend_burst()
	else:
		k._mend_tick()

func _tonic(m: Match, P: Hunter) -> void:
	UtilityBelt.set_count(P, "tonic", 1)
	P.drink_t = 0.01
	UtilityUse.tick(P, 0.02)

func _medkit(P: Hunter) -> void:
	UtilityBelt.set_count(P, "medkit", 1)
	UtilityUse.start(P, UtilityBelt.slot_of(P, "medkit"), "medkit")

func _boki(m: Match, P: Hunter, species: String, slot: String) -> void:
	if P.kin:
		P.kin.dead = true
		P.kin.visible = false
		P.kin = null
	var rec := Save.new_kin(species)
	rec["trust"] = 95.0
	var k := m.give_kin(P, rec)
	k.brain.think_t = 1e9
	k.runner.reset()
	k.teleport(P.pos + Vector3(0.6, 0, 1.0))
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true
	k.use_ability(slot, P.pos)

func _settle(main: Node, m: Match, P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		ReceiverCue.of(m).tick(DT)
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(P.pos)
		await main.get_tree().process_frame
		t += DT

## A match-zoom crop around the player (only with --shots-dir).
func _shot(main: Node, label: String) -> void:
	if _dir == "":
		return
	var vp := main.get_viewport()
	var img := vp.get_texture().get_image()
	var c := vp.get_camera_3d().unproject_position(_body_at)
	var box := Rect2i(Vector2i(c) - Vector2i(ZOOM_PX / 2, ZOOM_PX / 2), Vector2i(ZOOM_PX, ZOOM_PX))
	var file := label.to_lower().replace("+", "and").replace(" ", "_")
	for ch in ["'", "(", ")"]:
		file = file.replace(ch, "")
	img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png("%s/%s.png" % [_dir, file])
