extends RefCounted
## --terrain-hazard-reel --shots-dir=<dir>: footage of each terrain hazard (TerrainHazards) on the Hollow
## Crown, once with a Boki that doesn't counter it (Vespyx) and once with one that does. Each clip walks
## the hunter in from outside, holds still in the middle (burns, shocks, breath, slide) and walks out the
## far side, at the match camera with the HUD on. Frames go to <dir>/<kind>_<with|without>/%05d.jpg at
## 30 fps; ffmpeg makes the MP4s. With --stills: two PNGs per clip (see _stills). GPU (jobq --needs gpu). No save.

const STEP := 1.0 / 60.0  # s per match step; two make one 30 fps frame
const FRAME_W := 960  # px wide per saved frame
const LEAD := 5.0  # m outside the area the walk starts
const HOLD := 3.0  # s standing in the middle
const STILL_OUT := 2.5  # m outside the edge for the --stills edge shot
const STILL_IN := 2.0  # m inside the edge for the --stills in-field shot
const PLAIN := "cindle"
const COUNTER := {
	"lava": "cindowary", "deep_water": "lilybara", "ice": "floenatee", "static": "kestrike", "bramble": "heatherhorn"
}

var main: Node
var dir := "shots"
var m: Match
var p_v: Hunter
var tz: TerrainHazards


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = Vector2i(1280, 720)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	await _build(PLAIN)
	if OS.get_cmdline_user_args().has("--stills"):
		await _stills(false)
		for kind in COUNTER:
			await _build(COUNTER[kind])
			await _stills(true, kind)
		print("HAZARD_STILLS_DONE in %s" % dir)
		main.get_tree().quit(0)
		return
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
	await m.start(
		{"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": species, "demo_kin_lv": "12:95"}
	)
	m.set_process(false)
	p_v = m.player
	tz = TerrainHazards.of(m)


## Where the walk starts: LEAD metres out from either end of the area (the one on ground), or closer.
func _start(c: Vector2, along: Vector2, half: float) -> Vector2:
	for k: float in [1.0, 0.6, 0.3]:
		for sgn: float in [-1.0, 1.0]:
			var p := c + along * sgn * (half + LEAD * k)
			if not m.world.is_void(p.x, p.y) and not m.world.is_block(p.x, p.y):
				return p
	return c


## The walk for a kind's first area: {A, start, along (unit, toward the area), half (m), lead (m to its edge)}.
func _approach(kind: String) -> Dictionary:
	var ai := -1
	for i in tz.areas.size():
		if tz.areas[i]["kind"] == kind and ai < 0:
			ai = i
	var a: Dictionary = tz.areas[ai]
	var c: Vector3 = a["centre"]
	# along the area's longer side, so the walk spends longest in it
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q: Vector2i in a["cells"]:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x + 1), maxf(hi.y, q.y + 1))
	var along := Vector2(1, 0) if hi.x - lo.x >= hi.y - lo.y else Vector2(0, 1)
	var half := ((hi - lo) * along).length() * 0.5
	var start := _start(Vector2(c.x, c.z), along, half)
	along = (Vector2(c.x, c.z) - start).normalized()
	return {"A": a, "start": start, "along": along, "half": half, "lead": start.distance_to(Vector2(c.x, c.z)) - half}


func _put(at: Vector2) -> void:
	p_v.teleport(Vector3(at.x, m.world.ground_at(at.x, at.y), at.y))
	p_v.hp = p_v.max_hp
	for k in ["burn_t", "slow_t", "slow_k", "stun_t", "haste_t"]:
		p_v.set(k, 0.0)
	tz.state.clear()
	tz.hinted.clear()


## --stills: per kind, standing STILL_OUT m outside the area's edge and STILL_IN m inside it, at the match camera
## (<dir>/<kind>_<with|without>_<edge|in>.png): can you tell where the field starts, and does a counter show?
func _stills(safe: bool, only := "") -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for kind in COUNTER:
		if only != "" and kind != only:
			continue
		var w := _approach(kind)
		var start: Vector2 = w["start"]
		var along: Vector2 = w["along"]
		var edge: Vector2 = start + along * (float(w["lead"]) - STILL_OUT)
		for spot in [["edge", edge], ["in", edge + along * (STILL_OUT + STILL_IN)]]:
			_put(spot[1])
			for _i in 90:
				for mb in m.mobs:
					mb.queue_free()
				m.mobs.clear()
				m.step(STEP)
				m.cam.snap(p_v.pos)
				for h in m.hunters:
					h.render(STEP, 1.0)
				if _i % 30 == 29:
					await main.get_tree().process_frame
			await main.get_tree().process_frame
			var img := main.get_viewport().get_texture().get_image()
			if img:
				img.save_png(dir.path_join("%s_%s_%s.png" % [kind, "with" if safe else "without", spot[0]]))
		print("HAZARD_STILL %s %s" % [kind, "with" if safe else "without"])


func _clip(kind: String, safe: bool) -> void:
	var w := _approach(kind)
	var a: Dictionary = w["A"]
	var start: Vector2 = w["start"]
	var along: Vector2 = w["along"]
	var half: float = w["half"]
	var lead: float = w["lead"]
	_put(start)
	var out := dir.path_join("%s_%s" % [kind, "with" if safe else "without"])
	DirAccess.make_dir_recursive_absolute(out)
	var boki := String(Data.KIN[(p_v.kin as Kin).species]["name"])
	var label := "%s  ·  %s %s" % [a["def"]["name"], "with" if safe else "without", boki]
	if m.hud:
		m.hud.toast(label, Color.WHITE)
	var frame := 0
	var phase := "in"
	var held := 0.0
	var walked := 0.0
	while phase != "done":
		for mb in m.mobs:
			mb.queue_free()
		m.mobs.clear()
		var at := Vector2(p_v.pos.x, p_v.pos.z)
		if phase == "in" and (at - start).dot(along) >= half + lead:
			phase = "hold"
			if kind == "static":
				a["t"] = float(a["def"]["effect"]["warn_s"]) + 0.8  # a shock while we stand there
		elif phase == "hold":
			held += STEP * 2.0
			if held >= HOLD:
				phase = "out"
		elif phase == "out":
			walked += STEP * 2.0
			var ahead := at + along * 1.5
			if (at - start).dot(along) >= 2.0 * half + lead * 1.6 or walked > 6.0 or m.world.is_void(ahead.x, ahead.y):
				phase = "done"
		p_v.inp["move"] = along if phase != "hold" else Vector2.ZERO
		for _i in 2:
			m.step(STEP)
		m.cam.snap(p_v.pos)
		for h in m.hunters:
			h.render(STEP * 2.0, 1.0)
		await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		if img:  # (none headless: a dry run walks the clips without saving them)
			img.resize(FRAME_W, int(FRAME_W * img.get_height() / float(img.get_width())), Image.INTERPOLATE_BILINEAR)
			img.save_jpg(out.path_join("%05d.jpg" % frame), 0.85)
		frame += 1
	p_v.inp["move"] = Vector2.ZERO
	print("HAZARD_REEL %s %d frames" % [out, frame])
