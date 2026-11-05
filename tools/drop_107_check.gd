extends RefCounted
## --drop-107-check: owner item 107, a cooler, higher drop. Prints D107 lines.
##   the camera pulls out so the whole island is in view, and is back near play zoom before the ground
##   the wind builds, and drops away when the glider catches; the snap and the landing ring play; no self-shake
##   steering works high up and low down; the reticle's long projection lands where you land
##   your squad shows beside you (their contrails and tags), and every hunter's beats play
##   a ping works in the fall and reaches the bots
##   the budget (item 94): the counts below, and a lobby's frame of DropFx measured

const CHEAP_MS := 2.5          # ms: DropFx's whole frame with 20 hunters falling (GDScript, this box)
const PUFFS_MAX := 64

var bad := 0
var main: Node
var m: Match
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("D107 %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(opts: Dictionary) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(opts)
	m.set_process(false)
	P = m.player

func _frame(hud_keys := Vector2.ZERO) -> void:
	P.inp["move"] = hud_keys
	if P.dropping or P.drop_glide:
		SkyFall.assist(m, P)
	m.step(Match.DT)
	if P.dropping:
		DropCam.frame(m, P)
	m.cam.follow(DropCam.focus(m, P, P.pos), Match.DT, false)
	m.drop_fx._process(Match.DT)
	m.drop_fx.blasts._process(Match.DT)

func _to_ship_middle() -> void:
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	for i in 4000:
		if Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() < 40.0 or not P.riding:
			break
		m.step(Match.DT)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	seed(107)
	_solo()
	_squad()
	_lobby()
	print("D107 DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _solo() -> void:
	_start({"teams": 3, "squad": 1, "tier": 0, "seed": 4103, "no_plan": true, "raid": "clear"})
	_to_ship_middle()
	m.ship_jump(P, true)
	var shake0: float = m.cam.shake_total
	var w := m.world
	var seen_all := false
	var peak_zoom := 0.0
	var low_zoom := 99.0
	var wind_early := -99.0
	var wind_top := -99.0
	var wind_at_open := 0.0
	var wind_after := 0.0
	var turned_high := 0.0
	var turned_low := 0.0
	var pr := {}
	var t := 0.0
	var open_t := -1.0
	var snaps := 0
	while t < 40.0 and not P.grounded:
		t += Match.DT
		var keys := Vector2.ZERO
		if t > 3.0 and t < 4.0:
			keys = Vector2(-P.fall_dir.y, P.fall_dir.x) * 0.7
		var h := SkyFall.height_over(w, P.pos)
		var d0 := P.fall_dir
		if P.dropping and h < 40.0 and h > 25.0:
			keys = Vector2(-P.fall_dir.y, P.fall_dir.x) * 0.7
		_frame(keys)
		if t > 3.0 and t < 4.0:
			turned_high += absf(d0.angle_to(P.fall_dir))
		if P.dropping and h < 40.0 and h > 25.0:
			turned_low += absf(d0.angle_to(P.fall_dir))
		peak_zoom = maxf(peak_zoom, m.cam.zoom)
		if t > 2.4 and t < 4.0:
			var corners := 0
			for c in [Vector3(30, 0, 30), Vector3(w.w - 30, 0, 30), Vector3(30, 0, w.h - 30), Vector3(w.w - 30, 0, w.h - 30)]:
				if m.cam.is_position_in_frustum(c):
					corners += 1
			seen_all = seen_all or corners == 4
		if t > 0.3 and t < 0.5:
			wind_early = m.drop_fx.wind.low_db
		if P.dropping:
			wind_top = maxf(wind_top, m.drop_fx.wind.low_db)
			wind_at_open = m.drop_fx.wind.low_db
			low_zoom = m.cam.zoom
			if h < 24.0 and pr.is_empty():
				pr = SkyFall.project(P, Vector2.ZERO)
		elif open_t < 0.0:
			open_t = t
			snaps = m.drop_fx.blasts.live.size()
		elif t - open_t > 0.35 and wind_after == 0.0:
			wind_after = m.drop_fx.wind.low_db
	ok(seen_all, "the whole island is in view off the ship (zoom %.1f)" % peak_zoom)
	ok(m.cam.far > 0.0 and peak_zoom >= DropCam.WIDE_ZOOM * 0.6, "the camera pulls far out (%.1fx the match camera)" % peak_zoom)
	ok(low_zoom <= DropCam.NEAR_ZOOM + 0.3, "back near play zoom by the time the glider opens (%.2f)" % low_zoom)
	ok(wind_top > wind_early + 6.0, "the wind builds: %.1f dB just off the ship, %.1f dB falling" % [wind_early, wind_top])
	ok(wind_after < wind_at_open - 4.0, "the wind drops as the glider catches: %.1f -> %.1f dB" % [wind_at_open, wind_after])
	ok(snaps >= 1, "the glider's snap plays")
	ok(turned_high > 0.3 and turned_low > 0.3, "steering works high up (%.2f rad) and low down (%.2f rad)" % [turned_high, turned_low])
	for i in 60:
		_frame()
	ok(m.cam.shake_total == shake0, "no self-shake on the way down or on landing")
	var off := Vector2(pr.get("at", Vector3.ZERO).x - P.pos.x, pr.get("at", Vector3.ZERO).z - P.pos.z).length()
	ok(off < 14.0, "the reticle at 24 m called the landing within %.1f m" % off)

func _squad() -> void:
	_start({"teams": 3, "squad": 3, "tier": 0, "seed": 4101, "no_plan": true, "raid": "clear"})
	_to_ship_middle()
	m.ship_jump(P, true)
	var D := m.skydrop
	for f in D.comet.riders(P.team):
		f.ai["break_y"] = -1.0
	for i in 200:
		_frame()
	var mates: Array = D.comet.riders(P.team).duplicate()
	ok(mates.size() == 2, "a squad of three in the comet")
	for f in mates:
		D.separate(f)
	for i in 30:
		_frame()
	var fx := m.drop_fx
	var trails := 0
	var tags := 0
	for f in mates:
		if fx._trails.has(f.nid) and bool(fx._trails[f.nid]["near"]):
			trails += 1
		var tag: Label3D = fx._tags.get(f.nid)
		if tag and tag.visible:
			tags += 1
		ok(f.flat_dist(P) < 26.0, "%s drops beside you (%.1f m)" % [f.pname, f.flat_dist(P)])
	ok(trails == 2, "your squad's contrails in their own colours (%d)" % trails)
	ok(tags == 2, "and a name tag over each while the camera is out (%d)" % tags)
	var c0: Color = fx._trails[mates[0].nid]["col"]
	ok(c0.a > 0.8 and c0 != Color(0.85, 0.93, 1.0, 0.55), "a mate's contrail isn't the neutral a rival's has")
	# a ping in the fall
	var n0 := m.pings.size()
	var at: Vector3 = DropPing.place(m, Vector2(760, 420))
	var mine: Array = m.pings.filter(func(pg): return pg["by"] == P)
	ok(mine.size() == 1 and m.pings.size() >= n0, "a ping in the fall lands on the map (%.0f, %.0f)" % [at.x, at.z])
	var told := mates.filter(func(f): return f.ai.has("ping_goal"))
	ok(told.size() == mates.size(), "and reaches the bots (%d)" % told.size())
	ok(DropPing.in_sky(m), "the Boki keys are off in the sky (middle mouse is the ping)")

func _lobby() -> void:
	_start({"teams": 10, "squad": 2, "tier": 0, "seed": 4111, "no_plan": true, "raid": "clear"})
	_to_ship_middle()
	for h in m.hunters:
		if h.riding:
			m.ship_jump(h, true)
	for i in 120:
		m.step(Match.DT)
	var fx := m.drop_fx
	var puffs: int = fx._puffs.multimesh.instance_count
	ok(puffs <= PUFFS_MAX, "%d cloud puffs, one MultiMesh" % puffs)
	ok(fx.blasts.multimesh.instance_count == DropBlasts.SIZE, "%d pooled blasts, one MultiMesh" % DropBlasts.SIZE)
	var us := 0
	var n := 120
	for i in n:
		m.step(Match.DT)
		var t0 := Time.get_ticks_usec()
		fx._process(Match.DT)
		us += Time.get_ticks_usec() - t0
	var falling := m.hunters.filter(func(x): return x.dropping).size()
	var ms := us / 1000.0 / n
	ok(falling >= 10 and ms < CHEAP_MS, "DropFx with %d in the air: %.2f ms a frame (budget %.1f)" % [falling, ms, CHEAP_MS])
	var rt0 := Time.get_ticks_usec()
	for i in 30:
		SkyFall.project(P, Vector2.ZERO)
	ok(true, "one landing projection: %.2f ms (10 Hz, you and up to 3 mates)" % ((Time.get_ticks_usec() - rt0) / 1000.0 / 30.0))
