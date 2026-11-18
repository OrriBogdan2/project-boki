extends RefCounted
## --hit-flash-kind-check: a hit shows what it struck (Juice.flash_col). A Hunter keeps the white flash (the
## hot one on you), a Boki flashes in its type colour (the Field Book's, DexView.type_col) with a smaller
## number, a mob keeps its own. In a 30-Hunter fight the hits draw from the same fixed flash pool and make no
## new nodes, and a hit on a Boki costs no more flashes than a hit on a Hunter.
## --hit-flash-kind-shots --shots-dir=<dir>: a Hunter and a Boki taking the same hit side by side, two frames.
## Never touches the save.

const DT := 1.0 / 60.0
const HIT := 12.0            # damage of the test hit
const FIGHT := 30            # Hunters in the budget fight
const FIGHT_FRAMES := 120    # frames of one hit per Hunter each
const WARM_FRAMES := 30      # of them before the node count is taken
const SHOT_FRAMES := [2, 5]  # frames after the hit the strip is taken at (the flash holds ~6)

var bad := 0
var main: Node
var m: Match
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("HITFLASH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(root: Node, mode: String = "check") -> void:
	main = root
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	if mode == "shots":
		await _shots()
	else:
		_check()
	print("HITFLASH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _flash_col() -> Color:
	var fx := m.fx
	var mi: MeshInstance3D = fx.flash_pool[(fx.fi - 1 + fx.flash_pool.size()) % fx.flash_pool.size()]
	return (mi.material_override as ShaderMaterial).get_shader_parameter("color")

## The flash a plain hit from the player leaves on `t`, and how many flashes it started.
func _hit(t: Ent, dmg := HIT) -> Array:
	var before: int = m.fx.flashes.size()
	m.on_damage(t, P, dmg, {"src": "primary"})
	return [_flash_col(), m.fx.flashes.size() - before]

func _foe(at: Vector3) -> Hunter:
	var h := m.make_hunter("F%d" % m.hunters.size(), 2, "warden", "Foe", "idle", {}, at, {})
	h.ctrl = "idle"
	h.armor = 0.0       # (armor turns the flash blue: a different case)
	return h

func _check() -> void:
	var foe := _foe(P.pos + Vector3(4, 0, 0))
	var wild := m.spawn_wild(Save.new_kin("puddlet", "Wob"), P.pos + Vector3(-4, 0, 0), false)
	var mob := m.spawn_mob("skitter", P.pos + Vector3(0, 0, 4))
	var tcol := DexView.type_col(DexView.type_of("puddlet"))
	ok(tcol != DexView.type_col(""), "puddlet has a type colour of its own")
	var rh := _hit(foe)
	var rb := _hit(wild)
	var rm := _hit(mob)
	ok(rh[0] == Juice.HIT_COL, "a Hunter's hit flashes white: %s" % str(rh[0]))
	ok(rb[0] == tcol, "a Boki's hit flashes in its type colour: %s" % str(rb[0]))
	ok(rm[0] == Juice.HIT_COL, "a mob keeps its flash: %s" % str(rm[0]))
	ok(Juice.flash_col(P, P) == Juice.HURT_COL, "a hit on you keeps the hot flash")
	ok(rb[0] != rh[0] and rb[0] != Juice.HURT_COL, "a Boki's flash can't be taken for a Hunter's")
	ok(rb[1] <= rh[1], "a Boki hit starts no more flashes than a Hunter hit (%d vs %d)" % [rb[1], rh[1]])
	var nb := _number_size(wild)
	var nh := _number_size(foe)
	ok(nb > 0 and nb < nh, "a Boki's number is smaller than a Hunter's (%d vs %d)" % [nb, nh])
	_budget()

## Font size of the number the player's hit on t just printed (the newest in use).
func _number_size(t: Ent) -> int:
	m.fx.nums.clear()
	for l in m.fx.num_pool: l.visible = false
	m.on_damage(t, P, 30.0, {"src": "primary"})
	return (m.fx.nums[m.fx.nums.size() - 1]["node"] as Label3D).font_size if not m.fx.nums.is_empty() else 0

## 30 Hunters, a hit on each every frame, half of them with a Boki beside: no node is made, no flash
## beyond the pool is live, and the number labels stay in their pool.
func _budget() -> void:
	var targets: Array = []
	for i in FIGHT:
		var at := P.pos + Vector3(float(i % 6) * 1.5 - 4.0, 0, 3.0 + float(i / 6) * 1.5)
		var h := _foe(at)
		targets.append(h)
		if i % 2 == 0:
			targets.append(m.spawn_wild(Save.new_kin("puddlet", "W%d" % i), at + Vector3(0.7, 0, 0), false))
	var nodes := 0
	var peak := 0
	for f in FIGHT_FRAMES:
		if f == WARM_FRAMES:
			nodes = m.fx.get_child_count()     # (Fx builds a few pools on first use)
		for t in targets:
			t.hp = 1e6
			m.on_damage(t, P, HIT, {"src": "primary"})
		m.fx._process(DT)
		peak = maxi(peak, m.fx.flashes.size())
	ok(m.fx.get_child_count() == nodes, "the fight makes no new fx nodes once warm (%d)" % nodes)
	ok(peak <= m.fx.flash_pool.size(), "live flashes stay in the pool (%d of %d)" % [peak, m.fx.flash_pool.size()])
	ok(m.fx.nums.size() <= m.fx.NUM_POOL, "live numbers stay in the pool (%d)" % m.fx.nums.size())

func _shots() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	if m.hud: m.hud.visible = false
	var home := P.pos
	var foe := _foe(home + Vector3(-1.4, 0, 5))
	var wild := m.spawn_wild(Save.new_kin("puddlet", "Wob"), home + Vector3(1.4, 0, 5), false)
	foe.face = PI
	var frames: Array = []
	for k in 30:
		m.step(DT)
		for t in [foe, wild]:
			t.teleport(t.pos)
			t.vel = Vector3.ZERO
		m.cam.snap(home + Vector3(0, 0, 5))
		await main.get_tree().process_frame
	m.on_damage(foe, P, HIT, {"src": "primary"})
	m.on_damage(wild, P, HIT, {"src": "primary"})
	var last := 0
	for f in SHOT_FRAMES:
		for k in f - last:
			m.fx._process(DT)
			await main.get_tree().process_frame
		last = f
		frames.append(main.get_viewport().get_texture().get_image())
	var cam := main.get_viewport().get_camera_3d()
	var tl := cam.unproject_position(home + Vector3(-3.0, 3.0, 5))
	var br := cam.unproject_position(home + Vector3(3.0, 0.0, 5))
	var rg := Rect2i(Vector2i(tl), Vector2i(br - tl)).intersection(Rect2i(Vector2i.ZERO, frames[0].get_size()))
	for i in frames.size():
		var crop: Image = (frames[i] as Image).get_region(rg)
		crop.resize(960, int(crop.get_height() * 960.0 / crop.get_width()), Image.INTERPOLATE_LANCZOS)
		crop.save_png(dir.path_join("hit_f%d.png" % SHOT_FRAMES[i]))
	print("HITFLASH shots ", dir)
