extends "res://tools/hunter_scale_shots.gd"
## --ref-parity-shots --shots-dir=<dir> [--hero=arch,arch] [--tag=before] [--stills]: every hero (or --hero) at the
## match start's view (the default camera style, the wheel's start notch), 1920x1080, alone on open floor. Prints:
## REFCAM (arm m from the focus, vertical / horizontal lens, ground across at the focus, px per m at the feet),
## REFH per hero (px tall feet to the top of the head, own plate width px, the gap px between the bottom of the plate
## and the model's top: negative = the plate sits in the head), REFHUD (the vitals portrait, the health bar and the
## ability row as % of the screen) and REFMEAN (the mean and range of the heights). --stills also saves
## <dir>/<tag>_<hero>.png for the four STILLS heroes: the hero with a squad mate on its left and a Grimble rival on its
## right (both idle), HUD on, so the own, ally and rival plates read side by side. --wide (with --stills and
## --hero=gunslinger) saves <dir>/<tag>_wide.png instead: WIDE_HERO with two mates on its left and four rivals on its
## right out to 13 m, to show how much ground the start notch frames. --plates (runs headless too): the hero plus six
## copies of it as squad mates and rivals over the view (PLATE_SPOTS), each turned to FACES headings; prints REFGAP
## (plate to crown px, min..max per side) and REFFIT (the body.crown that bounds them). Stills need a renderer.

const STILLS := ["juggernaut", "gunslinger", "ostra", "rimewright"]  # Kael, Vex, Motley, Neve
const RIVAL := "dredge"  # Grimble: the tallest plate to clear
const CROWN_K := 0.2  # --plates: the top fifth of a body's height is its crown (what a plate must clear)
const FACES := 8  # --plates: headings each hunter is turned to while its top is measured
## --plates: where the copies stand off the hero (m): squad mates (even) and rivals (odd), out to the view's sides,
## top and bottom at the start notch
const PLATE_SPOTS := [
	Vector3(-3.2, 0, 0.6),
	Vector3(3.2, 0, -0.6),
	Vector3(-10, 0, 5),
	Vector3(10, 0, -6),
	Vector3(0, 0, 6),
	Vector3(0, 0, -7)
]
const SIDE_M := 3.2  # m either side of the hero the still's mate and rival stand
const WIDE_HERO := "gunslinger"  # --wide: this hero stands between two squad mates (left) and four rivals (right)
const WIDE_ROW := [
	[-7.0, "juggernaut"], [-3.5, "ostra"], [3.5, "dredge"], [6.8, "thief"], [10.1, "rimewright"], [13.4, "mage"]
]


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	var tag := "now"
	var stills := OS.get_cmdline_user_args().has("--stills")
	var wide := stills and OS.get_cmdline_user_args().has("--wide")
	var plates := OS.get_cmdline_user_args().has("--plates")
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="):
			heroes = String(a).substr(7).split(",")
		elif String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--tag="):
			tag = String(a).substr(6)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	var tall: Array = []
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player
		for k in m.kins:
			k.model.visible = false
		var at := _arena_spot(m.player.pos)
		_bare_floor(at)
		var extra: Array = []
		var wide_shot: bool = wide and hero == WIDE_HERO
		if wide_shot:
			extra = _wide_row(at)
		elif plates:  # the hero again as squad mates and rivals of itself, spread over the view
			for i in PLATE_SPOTS.size():
				var team := (m.player.team + i % 2) % 2
				extra.append(_idle("ref_p%d" % i, team, hero, at + PLATE_SPOTS[i]))
		elif stills and hero in STILLS:
			var mate := "gunslinger" if hero != "gunslinger" else "juggernaut"
			var team := m.player.team
			extra.append(_idle("ref_mate", team, mate, at + Vector3(-SIDE_M, 0.0, 0.6)))
			extra.append(_idle("ref_rival", (team + 1) % 2, RIVAL, at + Vector3(SIDE_M, 0.0, -0.6)))
		await _start_view(at, extra)
		if tall.is_empty():
			_cam_row()
		tall.append(_hero_row(hero))
		if plates:
			await _face_sweep(hero, extra)
		if stills and not extra.is_empty():
			await _save("%s_%s.png" % [tag, "wide" if wide_shot else hero])
		if hero == heroes[0]:
			_hud_row()
		m.queue_free()
	tall.sort()
	var mean := 0.0
	for t in tall:
		mean += t / tall.size()
	print("REFMEAN %d heroes: mean %.0f px, %.0f..%.0f px (target 100..112)" % [tall.size(), mean, tall[0], tall[-1]])
	main.get_tree().quit(0)


## WIDE_ROW's hunters: the ones left of the hero on its squad, the ones right of it rivals, all idle.
func _wide_row(at: Vector3) -> Array:
	var out: Array = []
	for i in WIDE_ROW.size():
		var team := (m.player.team + (0 if WIDE_ROW[i][0] < 0.0 else 1)) % 2
		var spot := at + Vector3(WIDE_ROW[i][0], 0.0, 0.6 if i % 2 == 0 else -0.6)
		out.append(_idle("ref_w%d" % i, team, WIDE_ROW[i][1], spot))
	return out


## An idle hunter of `arch` (no brain: it stands where it is put) for the stills.
func _idle(id: String, team: int, arch: String, at: Vector3) -> Hunter:
	var kit := {"arch": arch, "weapon": Arch.signature(arch), "perk": ""}
	var g := _ground(at)
	return m.make_hunter(id, team, Arch.weight(arch), HeroTitle.base_name(arch), "idle", {}, g, kit)


## The match start's view on `at`: the wheel's start notch eased in fully, the hero (and `extra`) settled there.
func _start_view(at: Vector3, extra: Array) -> void:
	var p := m.player
	var spots := []
	for h in extra:
		spots.append(h.pos)
	p.teleport(at)
	p.vel = Vector3.ZERO
	m.cam.user_zoom = CamWheel.far(true)
	m.cam.zoom_to = m.cam.air_zoom(p, 0.0)
	m.cam.zoom = m.cam.zoom_to
	m.cam.snap(p.pos)
	for _i in SETTLE:
		_purge()
		p.inp["aim"] = p.pos + Vector3(8.0, 0.9, 0.0)
		for j in extra.size():
			(extra[j] as Hunter).teleport(spots[j])
			(extra[j] as Hunter).vel = Vector3.ZERO
		m.step(STEP)
		m.cam.zoom = m.cam.zoom_to
		m.cam.follow(p.pos, STEP, false)
		for h in m.hunters:
			h.render(STEP, 1.0)
		_clean()
	await main.get_tree().process_frame
	_clean()
	m.hud.visible = true
	await _grab()  # the HUD draws once, so its groups' rects are known


func _k() -> float:
	return float(SIZE.y) / main.get_viewport().get_visible_rect().size.y  # viewport px to 1080p px


func _cam_row() -> void:
	var c: CamRig = m.cam
	var aim := m.player.position + Vector3(0.0, c.rise, 0.0)
	var arm := c.global_position.distance_to(aim)
	var view := main.get_viewport().get_visible_rect().size
	var hfov := 2.0 * atan(tan(deg_to_rad(c.fov) * 0.5) * view.x / view.y)
	var across := 2.0 * arm * tan(hfov * 0.5)
	var p := m.player.position
	var ppm := (c.unproject_position(p + Vector3(0.5, 0, 0)).x - c.unproject_position(p - Vector3(0.5, 0, 0)).x) * _k()
	var fmt := "REFCAM style %s: pitch %.1f deg, arm %.1f m (dist %.1f x zoom %.4f), lens %.1f v / %.1f h deg"
	fmt += ", across %.1f m, %.1f px/m"
	print(fmt % [c.style_id, rad_to_deg(c.pitch), arm, c.dist, c.zoom, c.fov, rad_to_deg(hfov), across, ppm])


## REFH row for the player; returns its px height.
func _hero_row(hero: String) -> float:
	var p := m.player
	var feet := m.cam.unproject_position(p.position)
	var top := _top(p.model)
	var plate := HudPlate.screen_at(m.cam, p, 2.7 * float(p.cdat["scale"]))
	var plate_frame := HudPlate._frame_rect(0.0, 0.0, HudStyle.PLATE_W_SELF)
	var rival := HudPlate.plate_offset(p) * CamRig.match_hunter_scale
	var rp := HudPlate.screen_at(m.cam, p, HudPlate.plate_offset(p))
	var rf := HudPlate._frame_rect(0.0, 0.0, HudStyle.PLATE_W)
	var tall := (feet.y - top) * _k()
	var fmt := "REFH %s: %.0f px tall (top %.2f m, top_h %.3f), own plate %.0f px wide, gap %.0f px"
	fmt += "; as a rival (at %.2f m): %.0f px wide, gap %.0f px"
	var own_gap := (top - plate.y - plate_frame.size.y) * _k()
	var rival_gap := (top - rp.y - rf.size.y) * _k()
	var top_m := _top_m(p.model) - p.position.y
	print(
		(
			fmt
			% [
				hero,
				tall,
				top_m,
				top_m / p.vis_k,
				plate_frame.size.x * _k(),
				own_gap,
				rival,
				rf.size.x * _k(),
				rival_gap
			]
		)
	)
	return tall


## --plates: for the player and `extra` turned to FACES headings, the px (1080p) between the lowest pixel of each plate
## where the HUD drew it (HudPlate._place: frame and level badge) and the body's highest pixel. Prints REFGAP (min and
## max per side and overall) and REFFIT: the top_h / top_r (HudPlate.top_y) that bound every sample with the least
## spare air (what body.top_h / top_r in the archetype's JSON should read).
func _face_sweep(hero: String, extra: Array) -> void:
	var all: Array = [m.player] + extra
	var spots: Array = all.map(func(h: Hunter): return h.pos)
	var gaps := {}  # side -> [min, max]
	var samples: Array = []  # [feet, vis_k, top px]
	for i in FACES:
		var heading := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / FACES)
		for _f in SETTLE:
			for j in all.size():
				var h: Hunter = all[j]
				h.teleport(spots[j])
				h.vel = Vector3.ZERO
				h.inp["aim"] = h.pos + heading * 8.0 + Vector3(0.0, 0.9, 0.0)
			m.step(STEP)
			m.cam.follow(m.player.pos, STEP, false)
			for h in m.hunters:
				h.render(STEP, 1.0)
		await main.get_tree().process_frame
		await main.get_tree().process_frame  # the HUD places its plates on the frame after the step
		for h: Hunter in all:
			var top := _crown_top(h)
			samples.append([h.model.global_transform, top])
			var it = m.hud.plates._items.get(h.nid)
			if it == null or not it.visible:
				continue
			var gap: float = (top - it.position.y - HudPlate.HANG) * _k()
			for side in [_side(h), "all"]:
				var g: Array = gaps.get(side, [1e9, -1e9])
				gaps[side] = [minf(g[0], gap), maxf(g[1], gap)]
	for side in gaps:
		print("REFGAP %s %s: %.0f..%.0f px" % [hero, side, gaps[side][0], gaps[side][1]])
	_fit(hero, samples)


## The screen y of h's crown: the highest pixel of the body's points in its top CROWN_K of height over the feet (the
## head, hair, horns and back props; not an arm or a held weapon reaching out lower down).
func _crown_top(h: Hunter) -> float:
	var pts := _body_points(h.model)
	var tall := 0.0
	for wp in pts:
		tall = maxf(tall, wp.y - h.position.y)
	var top := 1e9
	for wp in pts:
		if wp.y - h.position.y >= tall * (1.0 - CROWN_K):
			top = minf(top, m.cam.unproject_position(wp).y)
	return top


## REFFIT for `hero`: the crown (Arch.crown, model space) that keeps every sample's crown pixel under it with the
## least mean spare px: x and z on a 0.1 m grid, then 0.02 m round the best; y the least that clears every sample.
func _fit(hero: String, samples: Array) -> void:
	var best := _fit_grid(hero, samples, Vector2.ZERO, 0.1, 8)
	best = _fit_grid(hero, samples, Vector2(best[0].x, best[0].z), 0.02, 5)
	var c: Vector3 = best[0]
	var fmt := 'REFFIT %s: "crown": [%.2f, %.2f, %.2f] (spare %.1f px mean, %.1f max over %d samples; was %s)'
	print(fmt % [hero, c.x, c.y, c.z, best[1], best[2], samples.size(), str(Arch.crown(hero))])


## [crown, mean spare px, max spare px] of the best crown with x, z on a grid of `step` m, `n` steps out from `mid`.
func _fit_grid(hero: String, samples: Array, mid: Vector2, step: float, n: int) -> Array:
	var saved: Variant = Arch.body(hero).get("crown")
	var best := [Vector3.ZERO, 1e9, 0.0]
	for xi in range(-n, n + 1):
		for zi in range(-n, n + 1):
			var cx := snappedf(mid.x + xi * step, 0.01)
			var cz := snappedf(mid.y + zi * step, 0.01)
			var need := 0.0
			for sm: Array in samples:
				var lo := 0.0
				var hi := 5.0
				for _i in 20:
					var mid_y := (lo + hi) * 0.5
					if m.cam.unproject_position((sm[0] as Transform3D) * Vector3(cx, mid_y, cz)).y > sm[1]:
						lo = mid_y
					else:
						hi = mid_y
				need = maxf(need, hi)
			need = ceilf(need * 100.0) / 100.0
			Arch.body(hero)["crown"] = [cx, need, cz]
			var spare := 0.0
			var most := 0.0
			for sm: Array in samples:
				var px: float = (sm[1] - HudPlate.top_y(m.cam, sm[0], hero)) * _k()
				spare += px / samples.size()
				most = maxf(most, px)
			if spare < best[1]:
				best = [Vector3(cx, need, cz), spare, most]
	if saved == null:
		Arch.body(hero).erase("crown")
	else:
		Arch.body(hero)["crown"] = saved
	return best


func _side(h: Hunter) -> String:
	if h == m.player:
		return "self"
	return "squad" if h.team == m.player.team else "rival"


## Where the vitals block's parts sit, as % of the screen (HudScale.drawn: the anchors' rects as drawn).
func _hud_row() -> void:
	var view := main.get_viewport().get_visible_rect().size
	for g in HudScale.drawn:
		var r: Rect2 = HudScale.drawn[g]
		var pct := [r.position.x / view.x, r.end.x / view.x, r.position.y / view.y, r.end.y / view.y]
		print("REFHUD %s: x %.0f-%.0f%%, y %.0f-%.0f%%" % [g, pct[0] * 100, pct[1] * 100, pct[2] * 100, pct[3] * 100])
