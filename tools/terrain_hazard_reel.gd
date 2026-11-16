extends RefCounted
## --terrain-hazard-reel --shots-dir=<dir>: footage of each terrain hazard (TerrainHazards) on the Hollow
## Crown, once with a Boki that doesn't counter it (Vespyx) and once with one that does. Each clip walks
## the hunter in from outside, holds still in the middle (burns, shocks, breath, slide) and walks out the
## far side, at the match camera with the HUD on. Frames go to <dir>/<kind>_<with|without>/%05d.jpg at
## 30 fps; ffmpeg makes the MP4s. Needs a renderer (jobq --needs gpu). Never writes the save.

const STEP := 1.0 / 60.0          # s per match step; two make one 30 fps frame
const FRAME_W := 960              # px wide per saved frame
const LEAD := 5.0                 # m outside the area the walk starts
const HOLD := 3.0                 # s standing in the middle
const PLAIN := "cindle"
const COUNTER := {"lava": "cindowary", "deep_water": "lilybara", "ice": "floenatee", "static": "kestrike",
	"bramble": "heatherhorn"}

var main: Node
var dir := "shots"
var m: Match
var P: Hunter
var tz: TerrainHazards

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	main.get_window().size = Vector2i(1280, 720)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	await _build(PLAIN)
	for kind in COUNTER:
		await _clip(kind, false)
	for kind in COUNTER:
		await _build(COUNTER[kind])
		await _clip(kind, true)
	print("HAZARD_REEL_DONE in %s" % dir)
	main.get_tree().quit(0)

func _build(species: String) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": species,
		"demo_kin_lv": "12:95"})
	m.set_process(false)
	P = m.player
	tz = TerrainHazards.of(m)

## Where the walk starts: LEAD metres out from either end of the area (the one on ground), or closer.
func _start(c: Vector2, along: Vector2, half: float) -> Vector2:
	for k: float in [1.0, 0.6, 0.3]:
		for sgn: float in [-1.0, 1.0]:
			var p := c + along * sgn * (half + LEAD * k)
			if not m.world.is_void(p.x, p.y) and not m.world.is_block(p.x, p.y):
				return p
	return c

func _clip(kind: String, safe: bool) -> void:
	var ai := -1
	for i in tz.areas.size():
		if tz.areas[i]["kind"] == kind and ai < 0: ai = i
	var A: Dictionary = tz.areas[ai]
	var c: Vector3 = A["centre"]
	# along the area's longer side, so the walk spends longest in it
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q: Vector2i in A["cells"]:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x + 1), maxf(hi.y, q.y + 1))
	var along := Vector2(1, 0) if hi.x - lo.x >= hi.y - lo.y else Vector2(0, 1)
	var half := ((hi - lo) * along).length() * 0.5
	var start := _start(Vector2(c.x, c.z), along, half)
	along = (Vector2(c.x, c.z) - start).normalized()
	var lead := start.distance_to(Vector2(c.x, c.z)) - half
	P.teleport(Vector3(start.x, m.world.ground_at(start.x, start.y), start.y))
	P.hp = P.max_hp
	for k in ["burn_t", "slow_t", "slow_k", "stun_t", "haste_t"]: P.set(k, 0.0)
	tz.state.clear()
	tz.hinted.clear()
	var out := dir.path_join("%s_%s" % [kind, "with" if safe else "without"])
	DirAccess.make_dir_recursive_absolute(out)
	var boki := String(Data.KIN[(P.kin as Kin).species]["name"])
	var label := "%s  ·  %s %s" % [A["def"]["name"], "with" if safe else "without", boki]
	if m.hud: m.hud.toast(label, Color.WHITE)
	var frame := 0
	var phase := "in"
	var held := 0.0
	var walked := 0.0
	while phase != "done":
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		var at := Vector2(P.pos.x, P.pos.z)
		if phase == "in" and (at - start).dot(along) >= half + lead:
			phase = "hold"
			if kind == "static": A["t"] = float(A["def"]["effect"]["warn_s"]) + 0.8     # a shock while we stand there
		elif phase == "hold":
			held += STEP * 2.0
			if held >= HOLD: phase = "out"
		elif phase == "out":
			walked += STEP * 2.0
			var ahead := at + along * 1.5
			if (at - start).dot(along) >= 2.0 * half + lead * 1.6 or walked > 6.0 or m.world.is_void(ahead.x, ahead.y):
				phase = "done"
		P.inp["move"] = along if phase != "hold" else Vector2.ZERO
		for _i in 2:
			m.step(STEP)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(STEP * 2.0, 1.0)
		await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		if img:      # (none headless: a dry run walks the clips without saving them)
			img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
			img.save_jpg(out.path_join("%05d.jpg" % frame), 0.85)
		frame += 1
	P.inp["move"] = Vector2.ZERO
	print("HAZARD_REEL %s %d frames" % [out, frame])
