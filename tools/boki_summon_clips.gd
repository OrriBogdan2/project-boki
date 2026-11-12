extends RefCounted
## A summoned Boki plays the state clips it has at home (docs/art/kin/RIGGED_BOKI.md, "Summoned").
## audit(): one species per body plan fights headless as a summon (burst, melee, both abilities, a re-bloom, a
## knock-down) and every frame is judged: a strike plays lunge and a cast plays cast, a jump (burst, re-bloom, blink)
## does not make it run on the spot, a Boki on the move does not slide in a pose, a knock-down faints (settle, nap)
## for KinSummon.FAINT_S before BokiWispPop folds it. The hit jolt is BokiRig's KinFlinch, not judged here.
## --boki-rig-check calls it. --summon-clips-shots [--shots-dir=<dir>] runs it and, with a renderer, also draws a
## strip per species into <dir>/summon_<species>.png (needs a GPU: jobq --needs gpu).

const SPECIES := {"biped": "hivara", "quadruped": "cindle", "flyer": "wisplet", "serpent": "zephyrak"}
const DT := 1.0 / 60.0
const JUMP_M := 1.5          # m it moves in one frame only by being put somewhere
const STREAK := 8            # frames of a wrong clip that count as a fault (0.13 s, under the blend time)
const SPIKE := 1.0           # m/s a jump may add to the speed the rig measures
const TILE := 300            # px: one moment of a strip
const FAR := 40.0            # m: where the foe stands while the clips are driven by hand
const FAINT_CLIPS := ["settle", "nap"]   # the faint: home's lie-down and its held sleep

var ok_fn := Callable()
var main: Node
var m: Match
var p: Hunter
var k: Kin
var foe: Hunter
var dir := ""
var cam: Camera3D
var draw := false
var tiles: Array = []
var captions: Array = []
var bad := 0
var real := 0.0              # m/s it really moves (jumps left out)
var last_pos := Vector3.ZERO
var last_tp := 0
var scene := ""
var viol := {}               # fault -> frames; where it first showed
var where := {}
var run_len := 0
var slide_len := 0

## The registry entry: the audit, and the strips when a directory is given.
func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	ok_fn = _own_ok
	await audit(main_node, ok_fn)
	if dir != "":
		await _strips()
	print("SUMMONCLIPS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _own_ok(c: bool, what: String) -> void:
	print("SUMMONCLIPS %s %s" % ["PASS" if c else "FAIL", what])
	bad += int(not c)

## The headless audit; `ok` is the caller's assert (Callable(cond, text)).
func audit(main_node: Node, ok: Callable) -> void:
	main = main_node
	ok_fn = ok
	for plan in SPECIES:
		await _species(plan, SPECIES[plan])
	if m:
		m.queue_free()
		m = null

func _species(plan: String, id: String) -> void:
	var tag := "%s (%s)" % [id, plan]
	await _start(id)
	viol.clear()
	where.clear()
	ok_fn.call(BokiRig.has(id), "%s: summoned fights use the rigged model" % tag)
	await _burst(tag)
	await _melee(tag)
	await _rebloom(tag)            # before the casts: some end with it flying home to the shoulder
	for slot in ["k1", "k2"]:
		await _cast(tag, slot)
	await _fight(tag)
	for rule in ["attack_clip", "cast_clip", "faint_clip", "spike", "in_place", "slide"]:
		var n: int = viol.get(rule, 0)
		var why := "" if n == 0 else " (%d frames, first in %s)" % [n, where[rule]]
		ok_fn.call(n == 0, "%s: %s%s" % [tag, RULES[rule], why])
	await _knock(tag)

const RULES := {
	"attack_clip": "a strike plays the lunge clip",
	"cast_clip": "a cast plays the cast clip",
	"faint_clip": "a faint plays settle then nap",
	"spike": "a jump (burst, re-bloom, blink) does not read as speed",
	"in_place": "it never runs or walks on the spot",
	"slide": "it never slides in a pose while on the move",
}

func _start(id: String) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": id,
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	p = m.player
	k = p.kin
	foe = m.hunters.filter(func(x: Hunter) -> bool: return x.team != p.team)[0]
	_foe_at(-FAR)
	await _go(0.3)

func _foe_at(dist: float) -> void:
	foe.teleport(m.world.free_spot_near(p.pos + Vector3(dist, 0, 0), [], 1.0, 0.4, 8.0))

func _rig() -> BokiRig:
	return k.model.get_node_or_null("Body/Flex/BokiRig") as BokiRig if k.model else null

## One fixed step of the match, the Boki drawn, its rig stepped by hand and every frame judged.
func _step() -> void:
	m.step(DT)
	foe.hp = foe.max_hp
	p.hp = p.max_hp
	k.render(DT, 1.0)
	var d := k.pos.distance_to(last_pos)
	last_pos = k.pos
	var tp: int = k.model.get_meta("tp", 0) if k.model else 0
	var jumped := d > JUMP_M or tp != last_tp
	last_tp = tp
	if not jumped:
		real = lerpf(real, d / DT, 1.0 - exp(-10.0 * DT))
	var r := _rig()
	if r == null:
		return
	r.manual = true
	var before := r._speed
	var pulse_before := r._pulse
	r._flinch.update(k.model, DT)
	r._keep_flex(DT)
	r._track_speed(DT)
	r._pick_clip(DT)
	r._face_step(DT)
	if jumped and r._speed > before + SPIKE:
		_fault("spike")
	var ks := String(k.model.get_meta("kstate", ""))
	if ks == "attack" and r.clip != "lunge":
		_fault("attack_clip")
	if ks == "sleep" and not r.clip in FAINT_CLIPS:
		_fault("faint_clip")
	if r._pulse != pulse_before:
		if r.clip != "cast" and not (ks == "attack" and r.clip == "lunge"):
			_fault("cast_clip")
	run_len = run_len + 1 if r.clip in ["run", "walk"] and real < BokiRig.WALK_SPEED else 0
	if run_len == STREAK:
		_fault("in_place")
	slide_len = slide_len + 1 if r.clip in ["idle", "walk"] and real > BokiRig.RUN_SPEED + 0.8 else 0
	if slide_len == STREAK:
		_fault("slide")

func _fault(rule: String) -> void:
	viol[rule] = int(viol.get(rule, 0)) + 1
	if not where.has(rule):
		where[rule] = scene

## Runs `secs` of steps; with a renderer each step shows (the strips).
func _go(secs: float) -> void:
	var n := int(round(secs / DT))
	for i in n:
		_step()
		if draw:
			m.cam.snap(p.pos)
			for h in m.hunters:
				h.render(DT, 1.0)
			await main.get_tree().process_frame

## The clips it showed for `secs`, in order and without repeats.
func _clips(secs: float) -> Array:
	var seen: Array = []
	for i in int(round(secs / DT)):
		await _go(DT)
		var r := _rig()
		if r and (seen.is_empty() or seen[-1] != r.clip):
			seen.append(r.clip)
	return seen

func _out(secs := 8.0) -> void:
	k.summon.left = secs
	k.summon.cd = 0.0

func _say(tag: String, what: String, seen: Array) -> void:
	print("SUMMONCLIPS %s %s: %s" % [tag, what, " > ".join(seen)])

## The wisp bursts into the full Boki: the jump must not read as a run.
func _burst(tag: String) -> void:
	scene = "burst"
	ok_fn.call(KinSummon.press(p) and not k.wisp, "%s: Summon bursts the wisp" % tag)
	var seen := await _clips(0.8)
	_say(tag, "burst", seen)
	ok_fn.call(not ("run" in seen), "%s: it blooms standing, not running" % tag)

func _melee(tag: String) -> void:
	scene = "melee"
	_out()
	k.lunge_t = 0.3
	var seen := await _clips(0.8)
	_say(tag, "melee", seen)
	ok_fn.call("lunge" in seen, "%s: a strike plays the lunge clip" % tag)

func _cast(tag: String, slot: String) -> void:
	if not k.runner.has_slot(slot):
		return
	scene = "cast " + slot
	_out()
	k.runner.slots[slot]["charges"] = 1.0
	k.runner.slots[slot]["cd"] = 0.0
	var def := k.runner.def_of(slot)
	k._cast(slot, p.pos + Vector3(4, 0, 0), true, k, 1.0)
	var seen := await _clips(1.0)
	_say(tag, "%s %s" % [slot, def.id], seen)
	ok_fn.call(seen.size() > 0 and seen[0] == "cast",
		"%s: %s (%s) plays the cast clip first" % [tag, slot, def.id])

## Left far behind, it blooms again beside the hunter.
func _rebloom(tag: String) -> void:
	scene = "rebloom"
	_out()
	await _go(0.3)
	p.pos += Vector3(30, 0, 0)
	p.prev = p.pos
	var seen := await _clips(0.6)
	_say(tag, "rebloom", seen)
	ok_fn.call(not ("run" in seen), "%s: it re-blooms standing, not running" % tag)

## The real AI against a foe: whatever it does, the faults above stay at none.
func _fight(tag: String) -> void:
	scene = "fight"
	_out(6.0)
	for off in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4)]:
		foe.teleport(m.world.free_spot_near(p.pos + off, [], 1.0, 0.4, 8.0))
		if k.walkable_to(foe.pos):
			break
	KinFollow.on_damage(foe, p, 5.0)       # you hit it: its Boki joins the fight (docs/decisions/0002)
	var seen := {}
	for i in int(6.0 / DT):
		await _go(DT)
		var r := _rig()
		if r:
			seen[r.clip] = int(seen.get(r.clip, 0)) + 1
	print("SUMMONCLIPS %s fight: %s" % [tag, str(seen)])
	_foe_at(-FAR)

## Knocked down: it faints where it stands (not yet a wisp, untouchable, still), then BokiWispPop folds it.
func _knock(tag: String) -> void:
	scene = "knock"
	_out()
	await _go(0.2)
	var s := k.summon
	var at := k.pos
	var rig := _rig()
	k.hurt(k.max_hp * 5.0, null)
	await _go(DT)
	ok_fn.call(not k.wisp and s.fainting() and rig.clip in FAINT_CLIPS and _pop() == null,
		"%s: knocked down it faints first, not straight into a wisp (%s)" % [tag, rig.clip])
	ok_fn.call(not k.hittable() and not k.ready_to_fight() and k.hurt(10.0, foe) == 0.0,
		"%s: ...untouchable and idle while it lies" % tag)
	await _go(KinSummon.FAINT_S * 0.8)
	ok_fn.call(not k.wisp and k.pos.is_equal_approx(at) and rig.clip in FAINT_CLIPS and _pop() == null,
		"%s: ...it stays put, lying (%s), no fold yet" % [tag, rig.clip])
	await _go(KinSummon.FAINT_S * 0.3 + KinSummon.SHRINK_S * 0.5)
	ok_fn.call(not k.wisp and not s.fainting() and s.shrink > 0.0 and _pop() != null and k.pos.is_equal_approx(at),
		"%s: ...then BokiWispPop folds it, where it lay" % tag)
	await _go(KinSummon.SHRINK_S)
	ok_fn.call(k.wisp and absf(s.cd_full - s.cd_base * float(KinSummon.rules()["knocked_cd_mult"])) < 0.01,
		"%s: ...and the wisp rests the longer cooldown (%.1f s)" % [tag, s.cd_full])
	s.cd = 0.0

func _pop() -> Node:
	return k.get_node_or_null(KinSummon.POP)

# ------------------------------------------------------------------ strips (needs a renderer)
func _strips() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	draw = true
	cam = Camera3D.new()
	cam.fov = 60.0
	main.add_child(cam)
	_hide_ui()
	for plan in SPECIES:
		var id: String = SPECIES[plan]
		await _start(id)
		_hide_ui()
		tiles.clear()
		_foe_at(-FAR)
		await _go(0.3)
		KinSummon.press(p)
		await _go(0.1)
		await _tile("burst")
		_out()
		_foe_at(9.0)
		await _until("run", 2.0)
		await _tile("run")
		k.lunge_t = 0.3
		await _go(0.15)
		await _tile("attack")
		k.lunge_t = 0.0
		_foe_at(-FAR)
		_out()
		await _go(0.5)
		k.runner.slots["k1"]["charges"] = 1.0
		k._cast("k1", foe.pos, true, k, 1.0)
		await _go(0.25)
		await _tile("cast")
		k.flash_t = 0.12
		KinFlinch.hit(k.model, Vector3(1, 0, 0), 0.3, k.mass())
		await _go(0.1)
		await _tile("hit")
		k.hurt(k.max_hp * 5.0, null)
		await _go(0.3)
		await _tile("faint")
		await _go(KinSummon.FAINT_S - 0.3 + KinSummon.SHRINK_S * 0.4)
		await _tile("fold")
		var strip := Image.create(TILE * tiles.size(), TILE, false, Image.FORMAT_RGBA8)
		for i in tiles.size():
			strip.blit_rect(tiles[i], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
		strip.save_png(dir.path_join("summon_%s.png" % id))
		print("SUMMONCLIPS strip %s: %s" % [id, " | ".join(captions)])
		captions.clear()
	cam.queue_free()
	draw = false

## The title screen and the match's HUD sit over the world: hide them for the tiles.
func _hide_ui() -> void:
	for root in [main, m]:
		for n in root.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		for n in root.get_children():
			if n is Control:
				(n as Control).visible = false

func _until(clip: String, secs: float) -> void:
	for i in int(secs / DT):
		var r := _rig()
		if r and r.clip == clip:
			return
		await _go(DT)

func _tile(what: String) -> void:
	var at3 := k.global_position + Vector3(0, 0.6, 0)
	cam.global_position = at3 + Vector3(0.9, 0.5, 2.4)
	cam.look_at(at3)
	cam.make_current()
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var c := Vector2i(cam.unproject_position(k.global_position + Vector3(0, 0.6, 0)))
	var at := Vector2i(clampi(c.x - TILE / 2, 0, img.get_width() - TILE),
		clampi(c.y - TILE / 2, 0, img.get_height() - TILE))
	tiles.append(img.get_region(Rect2i(at, Vector2i(TILE, TILE))))
	var r := _rig()
	var shown := r.clip if r else "wisp"
	if _pop():
		shown = "pop"
	captions.append("%s=%s" % [what, shown])
