extends "res://tools/hunter_scale_shots.gd"
## --ref-parity-shots --shots-dir=<dir> [--hero=arch,arch] [--tag=before] [--stills]: every hero (or --hero) at the
## match start's view (the default camera style, the wheel's start notch), 1920x1080, alone on open floor. Prints:
## REFCAM (arm m from the focus, vertical / horizontal lens, ground across at the focus, px per m at the feet),
## REFH per hero (px tall feet to the top of the head, own plate width px, the gap px between the bottom of the plate
## and the model's top: negative = the plate sits in the head), REFHUD (the vitals portrait, the health bar and the
## ability row as % of the screen) and REFMEAN (the mean and range of the heights). --stills also saves
## <dir>/<tag>_<hero>.png for the four STILLS heroes: the hero with a squad mate on its left and a Grimble rival on its
## right (both idle), HUD on, so the own, ally and rival plates read side by side. --wide (with --stills and
## --hero=gunslinger) saves <dir>/<tag>_wide.png instead: WIDE_HERO mid-row with three mates and three rivals out to
## +-14 m, to show how much ground the start notch frames. Needs a renderer (xvfb or jobq gpu).

const STILLS := ["juggernaut", "gunslinger", "ostra", "rimewright"]  # Kael, Vex, Motley, Neve
const RIVAL := "dredge"  # Grimble: the tallest plate to clear
const SIDE_M := 3.2  # m either side of the hero the still's mate and rival stand
const WIDE_HERO := "gunslinger"  # --wide: this hero stands mid-row between three squad mates and three rivals
const WIDE_ROW := [
	[-14.0, "juggernaut"], [-8.5, "ostra"], [-4.0, "mage"], [4.0, "dredge"], [8.5, "thief"], [14.0, "rimewright"]
]


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	var tag := "now"
	var stills := OS.get_cmdline_user_args().has("--stills")
	var wide := stills and OS.get_cmdline_user_args().has("--wide")
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
		var wide_shot := wide and hero == WIDE_HERO
		if wide_shot:
			extra = _wide_row(at)
		elif stills and hero in STILLS:
			var mate := "gunslinger" if hero != "gunslinger" else "juggernaut"
			var team := m.player.team
			extra.append(_idle("ref_mate", team, mate, at + Vector3(-SIDE_M, 0.0, 0.6)))
			extra.append(_idle("ref_rival", (team + 1) % 2, RIVAL, at + Vector3(SIDE_M, 0.0, -0.6)))
		await _start_view(at, extra)
		if tall.is_empty():
			_cam_row()
		tall.append(_hero_row(hero))
		if not extra.is_empty():
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


## WIDE_ROW's hunters: the first three on the hero's squad, the rest rivals, all idle, spread over the row.
func _wide_row(at: Vector3) -> Array:
	var out: Array = []
	for i in WIDE_ROW.size():
		var team := (m.player.team + (0 if i < 3 else 1)) % 2
		out.append(_idle("ref_w%d" % i, team, WIDE_ROW[i][1], at + Vector3(WIDE_ROW[i][0], 0.0, 0.6 if i % 2 == 0 else -0.6)))
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
	var up := HudPlate.up(p, 2.7 * float(p.cdat["scale"])) * CamRig.match_hunter_scale
	var plate := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, up, 0))
	var frame := HudPlate._frame_rect(0.0, 0.0, HudStyle.PLATE_W_SELF)
	var rival := HudPlate.up(p, HudPlate.plate_offset(p)) * CamRig.match_hunter_scale
	var rp := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, rival, 0))
	var rf := HudPlate._frame_rect(0.0, 0.0, HudStyle.PLATE_W)
	var tall := (feet.y - top) * _k()
	var fmt := "REFH %s: %.0f px tall (top %.2f m, top_h %.3f), own plate %.0f px wide, gap %.0f px"
	fmt += "; as a rival (at %.2f m): %.0f px wide, gap %.0f px"
	var own_gap := (top - plate.y - frame.size.y) * _k()
	var rival_gap := (top - rp.y - rf.size.y) * _k()
	var top_m := _top_m(p.model) - p.position.y
	print(fmt % [hero, tall, top_m, top_m / p.vis_k, frame.size.x * _k(), own_gap, rival, rf.size.x * _k(), rival_gap])
	return tall


## Where the vitals block's parts sit, as % of the screen (HudScale.drawn: the anchors' rects as drawn).
func _hud_row() -> void:
	var view := main.get_viewport().get_visible_rect().size
	for g in HudScale.drawn:
		var r: Rect2 = HudScale.drawn[g]
		var pct := [r.position.x / view.x, r.end.x / view.x, r.position.y / view.y, r.end.y / view.y]
		print("REFHUD %s: x %.0f-%.0f%%, y %.0f-%.0f%%" % [g, pct[0] * 100, pct[1] * 100, pct[2] * 100, pct[3] * 100])
