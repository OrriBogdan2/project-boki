extends RefCounted
## The support pair's combo checks (--tender-combo-check, --rimewright-combo-check, and part of
## --support-check): each sheet behaviour and small mechanic in docs/heroes/tender.md and
## rimewright.md: where shots land, the telegraph shown while holding, the timings, the payoffs, the
## moves and sounds, merge-start hold drops. Runs on tools/support_check.gd's setup and report.

const MOVE_TAIL_MAX := 0.45    # s a dash move may run past its dash (the landing and settle)
## Each move's release beat in pip.glb (tools/art1/pip_clips.py: the push, arms up, thrust), s into the clip.
const RELEASE_BEAT := {
	"mm_shot_r": 0.08, "mm_shot_l": 0.08, "mm_shot_emp": 0.14, "mm_seed": 0.07, "mm_hearth": 0.18, "mm_call": 0.1}
const BEAT_TOL := 0.05          # s: how near the kit's effect frame the beat sits (a source frame is 0.2 s)
const SRC_WIND := 0.07          # s: the source's cast wind before the hand releases (footage 716.3 s, 30 fps)

var sc        # the SupportCheck running us (setup, step, ok, aim_at)

func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)

func step(m: Match, secs: float, each := Callable()) -> void:
	sc.step(m, secs, each)


## The owner's skate: steered into a curve with the move keys, firing the whole way, and a shorter
## skate gives back more of its cooldown.
func _skate_feel() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	sc.aim_at(P, T.pos)
	var spans := {}
	for hold_t in [0.3, 1.2]:
		P.dashes = 1.0
		P.inp["move"] = Vector2(1, 0)
		P.inp["dash"] = true
		P.inp["dash_down"] = true
		step(m, 0.05)
		P.inp["dash"] = false
		step(m, hold_t - 0.05)
		var before := P.dashes
		P.inp["dash_down"] = false
		step(m, 0.05)
		spans[hold_t] = P.dashes - before
		step(m, 0.4)
	ok(
			"tm Shift: the shorter the skate, the more of the charge comes back",
			float(spans[0.3]) > float(spans[1.2]) + 0.15,
			"0.3 s: +%.2f, 1.2 s: +%.2f" % [float(spans[0.3]), float(spans[1.2])])
	P.dashes = 1.0
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	var b0: int = K.stats["beams"]
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.1)
	var early: Vector2 = K.rinkrun.get("dir", Vector2.ZERO)
	step(m, 0.5)
	var late: Vector2 = K.rinkrun.get("dir", Vector2.ZERO)
	var turned := rad_to_deg(absf(Vector2(1, 0).angle_to(late)))
	ok(
			"tm Shift: she steers the skate into a curve (not a snap) with ice spraying off the edge",
			K.rinkrunning() and turned > 60.0 and rad_to_deg(absf(Vector2(1, 0).angle_to(early))) < 40.0
				and K.lk().live.filter(func(e): return String(e["kind"]) == "chip").size() >= 4,
			"turned %.0f deg" % turned)
	ok(
			"tm Shift: LMB keeps firing (straight beams) the whole skate",
			int(K.stats["beams"]) - b0 >= 3, "%d beams in 0.6 s" % (int(K.stats["beams"]) - b0))
	# the owner's parity example: on her ice trail she turns to the cursor and fires at it (footage
	# 0239-0245): swing the cursor round mid-skate and the next beams leave straight at it, whatever the skate's way
	var aim_to := P.pos + Vector3(-6.0, 0, -6.0)
	sc.aim_at(P, aim_to)
	var seen_beams := {}
	for s0 in _mine(m, P):
		seen_beams[s0["sid"]] = true
	var off_deg := -1.0
	for i in 18:
		step(m, 1.0 / 60.0)
		for s1 in _mine(m, P):
			if not seen_beams.has(s1["sid"]) and off_deg < 0.0:
				var want := Vector2(aim_to.x - P.pos.x, aim_to.z - P.pos.z)
				off_deg = rad_to_deg(absf((s1["vel"] as Vector2).angle_to(want)))
	var skate_dir: Vector2 = K.rinkrun.get("dir", Vector2.ZERO)
	ok(
			"tm Shift: skating, the beams track the cursor: a beam after the cursor swings leaves at it (within 6 deg)",
			K.rinkrunning() and off_deg >= 0.0 and off_deg < 6.0
				and rad_to_deg(absf(skate_dir.angle_to(Vector2(-1, -1)))) > 30.0,
			"%.1f deg off the cursor" % off_deg)
	P.inp["fire"] = false
	P.inp["dash_down"] = false
	step(m, 0.2)
	await _free(m)

## Item 12: the skate is her only dash. No charge refuses it, an air press buffers the skate to the
## landing (no air dash), and ice plates form under her while it runs.
func _skate_only() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	step(m, 0.1)
	P.dashes = 0.0
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	ok(
			"tm Shift: with no charge nothing happens (no spare dash)",
			not K.rinkrunning() and P.roll_t <= 0.0 and P.ex_cd <= 0.0)
	P.inp["dash_down"] = false
	P.dashes = P.max_dashes()
	# a tap on the ground is the skate's shortest run, never a travel() dash
	P.inp["dash"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	var kinds := {}
	for i in 30:
		if P.roll_t > 0.0:
			kinds[P.move_kind] = true
		step(m, 1.0 / 60.0)
	var others := {}
	var viewer: Dictionary = Content.rules("hunter_viewer")["moves"]
	for hero in viewer:
		if hero != "rimewright":
			for mv in (viewer[hero] as Dictionary).get("dash", []):
				others[mv] = hero
	var dd: Dictionary = K.dash_def()
	ok(
			"tm Shift: her dash moves are her own skate (push-off, stride), no other hero's, fitting the skate",
			not others.has("tm_skate_go") and not others.has("tm_skate")
				and KMovesCare.length("tm_skate_go") <= float(dd["min_t"])
				and KMovesCare.length("tm_skate") <= float(dd["max_t"]),
			"push-off %.2f s (shortest skate %.2f), stride %.2f s" % [
				KMovesCare.length("tm_skate_go"), float(dd["min_t"]), KMovesCare.length("tm_skate")])
	ok(
			"tm Shift: a tap on the ground is a short skate, no dash, and no long-dash pip",
			kinds.keys() == ["rinkrun"] and not K.rinkrunning() and not K.has_long_dash(), str(kinds.keys()))
	P.dashes = P.max_dashes()
	P.teleport(P.pos + Vector3(0, 4.0, 0))
	step(m, 0.1)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	ok(
			"tm Shift (item 62): pressed in the air the skate starts at once at skate speed (no buffer)",
			not P.grounded and K.rinkrunning() and absf(P.roll_speed - float(dd["speed"])) < 0.01 and P.roll_t > 0.0,
			"roll %.1f m/s of %.1f" % [P.roll_speed, float(dd["speed"])])
	step(m, 0.7)
	var slabs := K.lk().live.filter(func(e): return String(e["kind"]) == "slab").size()
	ok("tm Shift: ice plates form under her while she skates", slabs >= 5, "%d plates" % slabs)
	P.inp["dash_down"] = false
	await _free(m)

## Item 62: Shift pressed in the air skates through the air at once (no buffer), sinking at most air_fall, carries
## her over a 6 m gap, goes on along the ground if she lands mid-skate, and an ult cast from it keeps the skate's
## velocity (item 64).
func _air_skate() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var gy := P.pos.y
	var fall := float(K.dash_def()["air_fall"])
	var skate_v := float(K.dash_def()["speed"])
	for dx in range(3, 9):          # a 6 m gap, tiles hx+3 .. hx+8
		for dz in range(-6, 7):
			if W.inb(hx + dx, hz + dz):
				W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	step(m, 0.1)
	# a real jump off the near edge, Shift at the top of it
	P.teleport(Vector3(hx + 0.5, gy, hz + 0.5))
	P.vel = Vector3.ZERO
	P.grounded = true
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.inp["jump"] = true
	step(m, 1.0 / 60.0)
	P.inp["jump"] = false
	step(m, 0.15)
	var jumped := not P.grounded
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	var started := K.rinkrunning() and P.roll_speed >= skate_v - 0.01
	var worst_fall := 0.0
	var crossed := false
	var over_void := false
	for i in 90:
		step(m, 1.0 / 60.0)
		worst_fall = maxf(worst_fall, -P.vel.y)
		over_void = over_void or P.over_void()
		crossed = crossed or P.pos.x >= hx + 9.5
		if crossed:
			break
	ok(
			"tm Shift (item 62): a Shift at the top of a jump skates within a frame at skate speed",
			jumped and started, "jumped %s, skating %s, %.1f m/s" % [jumped, started, P.roll_speed])
	ok(
			"tm Shift (item 62): over a 6 m abyss gap she skates across, sinking no faster than air_fall",
			over_void and crossed and not P.out and P.pos.y > gy - 3.0 and worst_fall <= fall + 0.05,
			"void %s, crossed %s, y %.2f, sink %.2f of %.2f m/s" % [over_void, crossed, P.pos.y - gy, worst_fall, fall])
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	await _free(m)
	# landing mid-skate carries straight on along the ground; an ult cast from the air skate carries the velocity
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	K = P.ak
	K.cd["x"] = 0.0
	P.lvl = 6
	P.dashes = P.max_dashes()
	P.teleport(P.pos + Vector3(0, 0.7, 0))
	P.grounded = false
	step(m, 0.05)
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	var in_air := not P.grounded and K.rinkrunning()
	var t := 0.0
	while not P.grounded and t < 2.0:
		step(m, 0.02)
		t += 0.02
	ok(
			"tm Shift (item 62): landing mid-skate goes straight on along the ground (no stop, no restart)",
			in_air and P.grounded and K.rinkrunning() and P.roll_speed >= skate_v - 0.01,
			"in air %s, landed after %.2f s, skating %s" % [in_air, t, K.rinkrunning()])
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.grounded = false
	step(m, 1.0 / 60.0)
	var v := P.roll_speed
	var dir0 := Vector2(P.roll_dir)
	HunterKeys.ult_pressed(P)
	P.inp["dash_down"] = false
	var slowest := 99.0
	var worst_dot := 1.0
	for i in 18:
		var q := P.pos
		step(m, 1.0 / 60.0)
		var dv := Vector2(P.pos.x - q.x, P.pos.z - q.z)
		slowest = minf(slowest, dv.length() * 60.0)
		worst_dot = minf(worst_dot, dv.normalized().dot(dir0))
	ok(
			"tm X (item 64): an ult cast from the air skate keeps >= 80% of its speed for 0.3 s, same direction",
			K.ult_running() and slowest >= 0.8 * v and worst_dot > 0.99,
			"slowest %.1f of %.1f m/s, dot %.3f" % [slowest, v, worst_dot])
	P.inp["move"] = Vector2.ZERO
	await _free(m)

## Item 62's rules around the air skate: a jump in the skate rises as any jump and the skate goes on (item 51), the
## air skate plays its own move id, a press while gliding folds the glider and skates at once, and a jump press in
## the air skate opens the glider with the speed kept (ending in the air: normal fall / glide rules).
func _air_skate_rules() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var skate_v := float(K.dash_def()["speed"])
	var y0 := P.pos.y
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	step(m, 0.25)
	var was_ground := P.grounded and K.rinkrunning()
	P.inp["jump"] = true
	step(m, 1.0 / 60.0)
	P.inp["jump"] = false
	var top := 0.0
	var air_id := false
	var skated := true
	for i in 45:
		step(m, 1.0 / 60.0)
		top = maxf(top, P.pos.y - y0)
		air_id = air_id or K.anim_id == "tm_skate_air"
		skated = skated and K.rinkrunning() and P.roll_speed >= skate_v - 0.01
		if P.grounded and i > 3:
			break
	ok(
			"tm Shift (items 51/62): a jump in the skate rises and the skate goes on under it, at skate speed",
			was_ground and top > 0.6 and skated, "ground %s, top %.2f m, skating %s" % [was_ground, top, skated])
	ok("tm Shift (item 62): off the ground the skate plays its own move, tm_skate_air", air_id, K.anim_id)
	P.pos.y = P.ground() + 0.02          # brought down to the landing: a jump in the skate sinks as slowly as the skate
	step(m, 0.1)
	ok(
			"tm Shift (item 62): landing from it goes back to the ground stride",
			P.grounded and K.rinkrunning() and K.anim_id == "tm_skate",
			"%s grounded %s skating %s" % [K.anim_id, P.grounded, K.rinkrunning()])
	P.inp["dash_down"] = false
	step(m, 0.5)
	# a press while gliding
	P.teleport(P.pos + Vector3(0, 6.0, 0))
	P.grounded = false
	P.gliding = true
	P.dashes = P.max_dashes()
	step(m, 0.1)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	ok(
			"tm Shift (item 62): pressed while gliding the glider folds and she skates at once",
			not P.gliding and K.rinkrunning() and P.roll_speed >= skate_v - 0.01,
			"gliding %s, skating %s, %.1f m/s" % [P.gliding, K.rinkrunning(), P.roll_speed])
	step(m, 0.2)
	P.inp["jump"] = true
	P.inp["glide"] = true          # the key stays down: the glider is held open
	step(m, 1.0 / 60.0)
	P.inp["jump"] = false
	step(m, 1.0 / 60.0)
	var hv := Vector2(P.vel.x, P.vel.z).length()
	P.inp["glide"] = false
	ok(
			"tm Shift (item 62): a jump press in the air skate opens the glider, keeping the speed",
			P.gliding and not K.rinkrunning() and hv >= 0.6 * skate_v,
			"gliding %s, %.1f m/s" % [P.gliding, hv])
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	await _free(m)

## Item 65: the statue takes nothing but the recast and Shift: no dart, jump or turn, from the first frame of the
## slide (the slide counts as the dash for DashFlow, so its rows must not let a shot through).
func _statue_locks() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	K.cd["x"] = 0.0
	P.lvl = 6
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	step(m, 0.4)
	HunterKeys.ult_pressed(P)
	P.inp["dash_down"] = false
	P.inp["fire"] = true
	var y0 := P.pos.y
	var top := 0.0
	var shots := 0
	var aimed := false
	for i in 120:
		P.inp["jump"] = i % 10 == 0
		step(m, 1.0 / 60.0)
		shots += _mine(m, P).size()
		top = maxf(top, P.pos.y - y0)
		aimed = aimed or K.aims_in_dash() or K.fires_in_dash()
	ok(
			"tm X (item 65): LMB and jump do nothing in the statue, sliding or rooted",
			K.ult_running() and shots == 0 and top < 0.05 and not aimed and K.cast_locked(),
			"%d shots, rose %.2f m, aiming %s" % [shots, top, aimed])
	P.inp["fire"] = false
	P.inp["jump"] = false
	P.inp["move"] = Vector2.ZERO
	await _free(m)

## Item 27: no glide while sealed in Rimelock (she falls; each press is refused), and Shift ends it and
## skates straight out at speed instead of stopping.
func _rime_glide_skate() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	K.cd["x"] = 0.0
	P.teleport(P.pos + Vector3(0, 5.0, 0))
	P.grounded = false
	step(m, 0.05)
	HunterKeys.ult_pressed(P)
	var y0 := P.pos.y
	var opened := false
	for i in 30:
		P.inp["glide"] = true
		step(m, 1.0 / 60.0)
		opened = opened or P.gliding
	P.inp["glide"] = false
	ok(
			"tm X: glide held while sealed in the air does nothing; she keeps falling",
			K.ult_running() and not opened and P.pos.y < y0 - 0.3 and K.glide_held,
			"fell %.2f m" % (y0 - P.pos.y))
	await _free(m)
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	K = P.ak
	K.cd["x"] = 0.0
	P.dashes = P.max_dashes()
	HunterKeys.ult_pressed(P)
	step(m, 1.0)
	var before := Vector2(P.vel.x, P.vel.z).length()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	var slowest := 99.0
	var prev := P.pos
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	var out_of_ult := not K.ult_running() and K.rinkrunning()
	prev = P.pos
	for i in 18:
		step(m, 1.0 / 60.0)
		slowest = minf(slowest, Vector2(P.pos.x - prev.x, P.pos.z - prev.z).length() * 60.0)
		prev = P.pos
	var skate_v := float(K.dash_def()["speed"])
	ok(
			"tm X: Shift ends Rimelock and she skates straight out at speed (first 0.3 s >= 80%)",
			out_of_ult and slowest >= 0.8 * maxf(before, skate_v),
			"slowest %.1f m/s (before %.1f, skate %.1f)" % [slowest, before, skate_v])
	P.inp["dash_down"] = false
	await _free(m)

## Skating into Rimelock (items 64/65): the skate's momentum carries the frozen statue on as the shell closes
## (x.carry_t, easing to a stop: skate speed * carry_t * 2/3), the rink riding with her, her facing locked; then
## she is rooted (no slide on the ice) until it ends,
## and an early recast frees her.
func _rime_skate_in() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	P.lvl = 6
	K.cd["x"] = 0.0
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	step(m, 0.4)
	var v := P.roll_speed
	var p0 := P.pos
	HunterKeys.ult_pressed(P)
	P.inp["dash_down"] = false
	var sealed := K.ult_running() and not K.rinkrunning() and K.anim_id == "tm_rime_carry"
	var carry_t := float(K.x_def()["carry_t"])
	var face0 := P.face
	var dir0 := Vector2(P.roll_dir)
	var slowest := 99.0
	var worst_dot := 1.0
	var face_dev := 0.0
	var frames := int(round((carry_t + 0.1) * 60.0))
	for i in frames:
		P.inp["aim"] = P.pos + Vector3(cos(i * 0.12), 0.0, sin(i * 0.12)) * 6.0     # the cursor sweeps round her
		var q := P.pos
		step(m, 1.0 / 60.0)
		var dv := Vector2(P.pos.x - q.x, P.pos.z - q.z)
		if i < 18:
			slowest = minf(slowest, dv.length() * 60.0)
			if dv.length() > 0.001:
				worst_dot = minf(worst_dot, dv.normalized().dot(dir0))
		face_dev = maxf(face_dev, absf(angle_difference(P.face, face0)))
	var carried := Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length()
	var want := v * carry_t * 2.0 / 3.0
	ok(
			"tm X (item 64): skating into it keeps >= 80% of the skate's speed for 0.3 s, same direction",
			sealed and slowest >= 0.8 * v and worst_dot > 0.99,
			"slowest %.1f of %.1f m/s, direction dot %.3f" % [slowest, v, worst_dot])
	ok(
			"tm X (item 65): the statue slides on along the skate (speed x carry_t x 2/3, >= 2 m), easing to a stop",
			absf(carried - want) < want * 0.15 and carried >= 2.0,
			"%.2f m (want %.2f from %.1f m/s over %.1fs)" % [carried, want, v, carry_t])
	var rink_at: Vector3 = K.rime["at"]
	ok(
			"tm X: the rink rode with her and sits where she stopped",
			Vector2(rink_at.x - P.pos.x, rink_at.z - P.pos.z).length() < 0.05)
	var p1 := P.pos
	var fastest := 0.0
	for i in 60:
		step(m, 1.0 / 60.0)
		fastest = maxf(fastest, Vector2(P.vel.x, P.vel.z).length())
	ok(
			"tm X: then encased and rooted: zero planar speed with the move key held, no slide on the ice",
			K.ult_running() and fastest < 0.01 and Vector2(P.pos.x - p1.x, P.pos.z - p1.z).length() < 0.01,
			"fastest %.3f m/s" % fastest)
	var yaw0 := P.model.global_transform.basis.get_euler().y
	var yaw_dev := 0.0
	for i in 85:
		P.inp["aim"] = P.pos + Vector3(cos(i * 0.1), 0.0, sin(i * 0.1)) * 6.0
		step(m, 1.0 / 60.0)
		face_dev = maxf(face_dev, absf(angle_difference(P.face, face0)))
		yaw_dev = maxf(yaw_dev, absf(angle_difference(P.model.global_transform.basis.get_euler().y, yaw0)))
	ok(
			"tm X (item 65): her facing and model rotation hold while the cursor sweeps 360 deg round the seal",
			K.ult_running() and face_dev < 0.001 and yaw_dev < 0.01 and K.face_locked(),
			"face off by %.4f rad, model %.4f rad" % [face_dev, yaw_dev])
	HunterKeys.ult_pressed(P)
	step(m, 0.4)
	ok(
			"tm X: an early recast frees her: she walks off",
			not K.ult_running() and P.root_t <= 0.0 and Vector2(P.pos.x - p1.x, P.pos.z - p1.z).length() > 0.5,
			"moved %.2f" % Vector2(P.pos.x - p1.x, P.pos.z - p1.z).length())
	P.inp["move"] = Vector2.ZERO
	await _free(m)

## Rank 3 Skate over the Abyss lays ice underfoot that holds a while and then goes; below rank 3 she gets none.
func _skate_ice() -> void:
	var laid := {}
	for rank_n in [1, 3]:
		var r: Array = sc.setup("rimewright", 30.0)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var K: RimewrightKit = P.ak
		P.slot_lv["dash"] = rank_n
		var W = m.world
		var hx := int(floor(P.pos.x))
		var hz := int(floor(P.pos.z))
		var gap: Array = []
		for dx in range(-24, -2):
			for dz in range(-4, 5):
				if W.inb(hx + dx, hz + dz):
					var i: int = W.idx(hx + dx, hz + dz)
					W.kind[i] = World.T_VOID
					gap.append(i)
		step(m, 0.1)
		P.dashes = P.max_dashes()
		P.inp["move"] = Vector2(-1, 0)
		P.inp["dash"] = true
		P.inp["dash_down"] = true
		step(m, 0.05)
		P.inp["dash"] = false
		step(m, 1.2)
		var now := gap.filter(func(i): return W.kind[i] != World.T_VOID).size()
		P.inp["dash_down"] = false
		step(m, float(K.dash_def()["ice_time"]) + 1.5)
		var later := gap.filter(func(i): return W.kind[i] != World.T_VOID).size()
		laid[rank_n] = [now, later]
		await _free(m)
	ok(
			"tm Shift rank 3: skating over the Abyss lays ice that goes again; none below rank 3",
			int(laid[1][0]) == 0 and int(laid[3][0]) >= 6 and int(laid[3][1]) == 0,
			"rank 1 %s, rank 3 %s (tiles now, after)" % [str(laid[1]), str(laid[3])])

## Owner 23:55: Celeste's darts home in toward the END of their flight, also while she skates. A dart keeps its
## launch heading through its first third, then turns in (wpn.home_from 0.35 to home_full 0.7 of its flight);
## a skating beam aimed 1.5 m off a foe still curves onto it late.
func _late_homing() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	T.teleport(P.pos + Vector3(7.0, 0, 2.5))
	sc.aim_at(P, T.pos)
	step(m, 0.05)
	P.inp["fire"] = true
	step(m, 1.0 / 60.0)
	P.inp["fire"] = false
	var mine := _mine(m, P)
	var dart: Dictionary = mine[0] if not mine.is_empty() else {}
	var v0: Vector2 = dart.get("vel", Vector2.RIGHT)
	var turned_early := 0.0
	var turned_late := 0.0
	var t := 0.0
	var from: Vector3 = dart.get("start", P.pos)
	var reach := Vector2(T.pos.x - from.x, T.pos.z - from.z).length()
	while m.shots.has(dart) and t < 1.0:
		step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
		var turned := rad_to_deg(absf(v0.angle_to(dart["vel"])))
		var p: Vector3 = dart["pos"]
		if Vector2(p.x - from.x, p.z - from.z).length() < reach * 0.33:
			turned_early = turned
		else:
			turned_late = maxf(turned_late, turned)
	ok(
			"tm LMB: a dart flies out straight (the first third of the way under 1 deg of turn), then curves in late",
			turned_early < 1.0 and turned_late > 5.0,
			"early %.1f deg, late %.1f deg" % [turned_early, turned_late])
	await _free(m)
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	T = r[3]
	K = P.ak
	T.teleport(P.pos + Vector3(4.0, 0, -7.0))
	step(m, 0.05)
	var hp0 := T.hp
	P.dashes = 1.0
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	var beams0: int = K.stats["beams"]
	for i in 36:
		sc.aim_at(P, T.pos + Vector3(1.5, 0, 0))
		P.inp["fire"] = true
		step(m, 1.0 / 60.0)
	P.inp["fire"] = false
	P.inp["dash_down"] = false
	step(m, 0.4)
	var shot := int(K.stats["beams"]) - beams0
	ok(
			"tm Shift: skating, beams aimed 1.5 m off a foe still home in late and hit it",
			shot >= 3 and hp0 - T.hp >= float(P.wpn["dmg"]) * float(shot) * 0.6,
			"%d beams, %.0f damage" % [shot, hp0 - T.hp])
	P.inp["move"] = Vector2.ZERO
	step(m, 1.8)
	var slabs := K.lk().live.filter(func(e): return String(e["kind"]) == "slab").size()
	ok(
			"tm Shift: her ice trail lasts a few seconds (plates still down 2 s after the skate), skate cd 13 s (data)",
			slabs >= 3 and absf(P.dash_regen() - 13.0) < 0.01, "%d plates, cd %.1f s" % [slabs, P.dash_regen()])
	await _free(m)

## Owner 19:50: the further the spear goes, the longer it travels; it always starts at her, never at the target.
func _spear_travel() -> void:
	var flights := []
	for reach in [4.0, 10.0]:
		var r: Array = sc.setup("rimewright", 30.0)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var K: RimewrightKit = P.ak
		var cur := P.pos + Vector3(reach, 0, 0)
		step(m, 0.05)
		sc.aim_at(P, cur)
		K.ch_rmb = 2.0
		P.inp["sec"] = true
		P.inp["sec_hold"] = true
		step(m, 0.3)
		P.inp["sec"] = false
		P.inp["sec_hold"] = false
		var t := 0.0
		var start := Vector3.INF
		while K.zones.is_empty() and t < 2.0:
			step(m, 1.0 / 60.0)
			t += 1.0 / 60.0
			var mine := _mine(m, P)
			if start == Vector3.INF and not mine.is_empty():
				start = mine[0]["start"]
		flights.append({"t": t, "near": Vector2(start.x - P.pos.x, start.z - P.pos.z).length()})
		await _free(m)
	var near: Dictionary = flights[0]
	var far: Dictionary = flights[1]
	var per_m := (float(far["t"]) - float(near["t"])) / 6.0
	ok(
			"tm RMB: travel time grows with distance (4 m vs 10 m: about 1/speed s per metre), from her each time",
			float(far["t"]) > float(near["t"]) + 0.2 and absf(per_m - 1.0 / 18.0) < 0.01
				and float(near["near"]) < 1.0 and float(far["near"]) < 1.0,
			"%.2f s vs %.2f s" % [float(near["t"]), float(far["t"])])

## Rank 3 Spear: the detonation hits 45% harder (on top of the rank's own +30%) and is no wider.
func _spear_rank3() -> void:
	var hits := {}
	var rim := {}
	for rank_n in [1, 3]:
		var r: Array = sc.setup("rimewright", 30.0)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var T: Hunter = r[3]
		var K: RimewrightKit = P.ak
		P.slot_lv["sec"] = rank_n
		var edge: Hunter = m.make_hunter(
				"T2", T.team, "medium", "Edge", "idle", {}, P.pos + Vector3(8.4, 0, 0), {"arch": "none"})
		edge.max_hp = 10000.0
		edge.hp = 10000.0
		edge.armor = 0.0
		T.teleport(P.pos + Vector3(5.0, 0, 0))
		step(m, 0.05)
		var t0 := T.hp
		K._detonate(P.pos + Vector3(5.0, 0, 0))
		hits[rank_n] = t0 - T.hp
		rim[rank_n] = 10000.0 - edge.hp
		await _free(m)
	var want: float = Effects.level_k({"level": 3}) * 1.45
	var got: float = float(hits[3]) / maxf(0.01, float(hits[1]))
	ok(
			"tm RMB rank 3: the detonation is 45% harder and no wider",
			absf(got - want) < 0.1 and float(rim[1]) == 0.0 and float(rim[3]) == 0.0,
			"x%.2f want x%.2f, edge foe %.0f/%.0f" % [got, want, float(rim[1]), float(rim[3])])

func _free(m: Match) -> void:
	m.queue_free()
	await sc.main.get_tree().process_frame

## The shots in flight from P.
## Elluna's Moon Shot (parity pass): held, a shot every 0.4 s (card) from alternating hands, each a straight-arm
## push with a big torso unwind (footage: about +-45 degrees); she strafes freely and every ember leaves at the
## cursor as it moves round her.
func _moon_shot_parity(m: Match, P: Hunter, K: TenderKit) -> void:
	var seen := {}
	for s0 in _mine(m, P):
		seen[s0["sid"]] = true
	var times: Array = []
	var worst := 0.0
	var moves := {}
	P.inp["fire"] = true
	P.inp["move"] = Vector2(0, 1)
	var t := 0.0
	while t < 1.3:
		var swing := Vector3(cos(t * 2.0), 0, sin(t * 2.0)) * 6.0
		sc.aim_at(P, P.pos + swing)
		step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
		moves[K.anim_id] = true
		for s1 in _mine(m, P):
			if seen.has(s1["sid"]):
				continue
			seen[s1["sid"]] = true
			times.append(t)
			worst = maxf(worst, rad_to_deg(absf((s1["vel"] as Vector2).angle_to(Vector2(swing.x, swing.z)))))
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	var gaps: Array = []
	for i in range(1, times.size()):
		gaps.append(float(times[i]) - float(times[i - 1]))
	var cadence: float = gaps.reduce(func(a, g): return a + float(g), 0.0) / maxf(1.0, gaps.size())
	ok(
			"mm LMB: a shot every 0.4 s (card) from alternating hands while strafing",
			absf(cadence - 0.4) < 0.03 and moves.has("mm_shot_r") and moves.has("mm_shot_l"),
			"%d shots, %.2f s apart" % [times.size(), cadence])
	ok("mm LMB: each ember leaves at the cursor as it swings round her (within 8 deg)", worst < 8.0, "%.1f deg" % worst)
	var unwind := absf(float(KMovesCare.MOVES["mm_shot_r"]["keys"][2][1]["y"]))
	ok("mm LMB: the push unwinds the torso about 45 degrees (footage)", unwind >= 0.7, "%.2f rad" % unwind)
	_release_beats()

## The clip's release beat lands on the frame the kit's effect fires (every effect starts at its move's t 0), so the
## hand and the ember, the seed, the plus and the thrust read as one frame, as in the source.
func _release_beats() -> void:
	var km: Dictionary = WardenClips.data("pip")["kmoves"]
	var worst := 0.0
	for id in RELEASE_BEAT:
		worst = maxf(worst, absf(float(RELEASE_BEAT[id]) - float((km[id] as Dictionary).get("lead", 0.0))))
	ok("mm clips: each release beat lands on the kit's effect frame (within %.2f s)" % BEAT_TOL,
			worst <= BEAT_TOL, "%.3f s" % worst)
	var wind := float(RELEASE_BEAT["mm_shot_r"]) - float((km["mm_shot_r"] as Dictionary)["lead"])
	ok("mm LMB: the hand releases within the source's %.2f s wind of the ember" % SRC_WIND,
			wind <= SRC_WIND, "%.3f s" % wind)

func _mine(m: Match, P: Hunter) -> Array:
	return m.shots.filter(func(s): return s["by"] == P)

# ================================================================== Pip
func tender() -> void:
	var r: Array = sc.setup("tender", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	ok(
			"mm: renamed Pip, kit sounds load",
			Arch.name_of("tender") == "Little Lantern"
			and Sfx.streams.has("tend_seed")
			and Sfx.streams.has("tend_root")
			and Sfx.streams.has("tend_hop"))
	# --- Moon Shot flies its full range past the cursor (cursor 3 m out, off the target line)
	sc.aim_at(P, P.pos + Vector3(0, 0, 3.0))
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["fire"] = false
	var sh: Array = _mine(m, P)
	var reach := 0.0
	if not sh.is_empty(): reach = float(sh[-1]["life0"]) * (sh[-1]["vel"] as Vector2).length()
	ok(
			"mm LMB: the ember flies its full range past the cursor",
			AimMode.mode_of(P) == AimMode.MAX and reach > float(P.wpn["range"]) - 0.3, "reach %.1f" % reach)
	ok(
			"mm LMB: each ember has its comet look, a swirl at the hand and the flick move",
			K.stats["swirls"] >= 1 and K.lk().skins.size() >= 1 and K.anim_id in ["mm_shot_r", "mm_shot_l"],
			"%s %d" % [K.anim_id, K.stats["swirls"]])
	step(m, 0.6)
	_moon_shot_parity(m, P, K)
	# --- Kindle ramp and its foot glow; nodes stay pooled while firing
	sc.aim_at(P, T.pos)
	K.cd["e"] = 8.0
	P.inp["fire"] = true
	step(m, 0.3)
	var made0: int = K.lk().made
	step(m, 1.8)
	P.inp["fire"] = false
	var shown_glow: bool = K.lk().showing("kin%d" % T.get_instance_id())
	ok(
			"mm passive: embers Kindle the foe and a foot glow grows on them", K.kindle_on(T) >= 3 and shown_glow,
			"kindle %d" % K.kindle_on(T))
	ok("mm passive: an ember into a Kindled foe winds Hearthlight back", K.cd["e"] < 7.0, "e %.2f" % K.cd["e"])
	ok(
			"mm LMB: looks are pooled (no new nodes per ember)", K.lk().made - made0 <= 3,
			"made %d -> %d" % [made0, K.lk().made])
	# the ramp: about +45% over 5 hits (sheet: 64 -> 93)
	var ramp := float(Arch.def("tender")["resource"]["per_stack"]) * 5.0 / float(P.wpn["dmg"])
	ok(
			"mm passive: Kindle ramps embers about +45% at 5 stacks", ramp > 0.38 and ramp < 0.52,
			"+%.0f%%" % (ramp * 100.0))
	# --- the idle crook: the next ember is Empowered (longer, its own bigger flick)
	step(m, 1.3)
	var e0: int = K.stats["emp"]
	P.ammo = int(P.wpn["mag"])
	P.reload_t = 0.0
	P.inp["fire"] = true
	step(m, 0.05)
	P.inp["fire"] = false
	ok(
			"mm LMB: after a pause the next ember is Empowered (40% further, its own move)",
			K.stats["emp"] > e0 and K.anim_id == "mm_shot_emp", "emp %d anim %s" % [K.stats["emp"], K.anim_id])
	step(m, 0.6)
	# --- Burrseed (item 118): a press, a fixed wind-up, the throw by itself on the aim of that moment
	K.kind.clear()
	T.hp = T.max_hp
	T.root_t = 0.0
	sc.aim_at(P, P.pos + Vector3(0, 0, -8.0))         # off the foe: the aim at the press misses him
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var n0: int = _mine(m, P).size()
	var wind := float(K.rmb_def()["windup"])
	ok(
			"mm RMB: not a hold (no hold data), the wind-up is about 1 s, its clip as long",
			not K.rmb_def().has("hold") and wind >= 0.9 and wind <= 1.0
			and absf(KMovesCare.length("mm_seed_aim") - wind) < 0.01
			and not bool(HunterAnim.km_def("mm_seed_aim").get("hold", false)))
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	var lane: Dictionary = AimKit.entry(P, "rmb")
	ok(
			"mm RMB: winding up, a short dotted lane, the coiled pose, half speed",
			AimKit.shown(P, "rmb")
			and String(lane.get("kind", "")) == "dotted"
			and absf(float(lane.get("len", 0.0)) - float(K.rmb_def()["wind_lane"])) < 0.1
			and K.anim_id == "mm_seed_aim"
			and absf(K.move_k() - float(K.rmb_def()["wind_move"])) < 0.01,
			"%s len %.1f %s k %.2f" % [
				String(lane.get("kind", "")), float(lane.get("len", 0.0)), K.anim_id, K.move_k()])
	ok("mm RMB: nothing leaves during the wind-up", _mine(m, P).size() == n0 and K.ch_rmb >= 1.0)
	# letting go early changes nothing; the flick onto him at the very end is what counts
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 0.3)
	ok("mm RMB: letting go early does not throw or cancel", K.seed_aim and _mine(m, P).size() == n0)
	var tt := 0.6
	while _mine(m, P).size() == n0 and tt < 1.5:
		if tt >= wind - 0.1:
			sc.aim_at(P, T.pos)
		step(m, 1.0 / 60.0)
		tt += 1.0 / 60.0
	ok(
			"mm RMB: the seed goes by itself at the end of the wind-up (thrown at %.2f s)" % tt,
			absf(tt - wind) <= 0.05 and K.anim_id == "mm_seed" and not K.seed_aim
				and not AimKit.shown(P, "rmb"),
			"%.2f %s" % [tt, K.anim_id])
	var t_stick := -1.0
	var ts := 0.0
	while ts < 0.5 and t_stick < 0.0:
		step(m, 1.0 / 60.0)
		ts += 1.0 / 60.0
		if K.burrs.size() > 0: t_stick = ts
	ok(
			"mm RMB: the aim is sampled at the throw: flicked onto the foe, it sticks in under 0.35 s",
			t_stick > 0.0 and t_stick < 0.35,
			"stuck at %.2f s" % t_stick)
	var bid := "burr%d" % int(K.burrs[0]["id"]) if K.burrs.size() > 0 else ""
	step(m, 0.1)
	var tele: Dictionary = AimKit.entry(P, bid)
	ok(
			"mm RMB: the burst area shows under the foe at once, for everyone, filling",
			AimKit.shown(P, bid)
			and bool(tele.get("all", false))
			and absf(float(tele.get("r", 0.0)) - 2.2) < 0.05
			and K.lk().showing(bid),
			"r %.2f" % float(tele.get("r", 0.0)))
	var rooted_early := T.root_t > 0.0
	var h1 := T.hp
	step(m, 0.7)
	ok(
			"mm RMB: it roots about 0.7 s after it sticks (not before), damages and Kindles",
			not rooted_early and T.root_t > 0.0 and h1 - T.hp > 25.0 and K.kindle_on(T) >= 1,
			"root %.2f dmg %.0f" % [T.root_t, h1 - T.hp])
	await _free(m)
	# --- Hearthlight: on her a 2.6 m ring with its own cast move; E again throws it to the cursor at once
	r = sc.setup("tender", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	A.teleport(P.pos + Vector3(-6, 0, 3))
	T.teleport(P.pos + Vector3(14, 0, 0))
	step(m, 0.05)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	ok(
			"mm E: lit on her, a 2.6 m ring (1.4 bh) and the raise-the-lantern move",
			K.in_e() and absf(K.hearth_r() - 2.6) < 0.01 and K.anim_id == "mm_hearth" and K.lk().showing("hearth"))
	var cur := P.pos + Vector3(6.0, 0, 0)
	sc.aim_at(P, cur)
	step(m, 0.2)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 0.15)
	var hp: Vector3 = K.hearth.get("pos", Vector3.ZERO)
	var land_off := Vector2(hp.x - cur.x, hp.z - cur.z).length()
	ok(
			"mm E: thrown, it lands on the cursor within 0.2 s and widens to 2.9 m",
			String(K.hearth.get("mode", "")) == "ground" and land_off < 0.4
				and absf(K.hearth_r() - 2.9) < 0.01 and K.anim_id == "mm_toss",
			"%s at %.2f m" % [String(K.hearth.get("mode", "")), land_off])
	step(m, 3.0)
	# --- Relay Step goes where you move, not at the cursor, with its own hop and a lantern trail
	K.cd["e"] = 8.0
	var p0 := P.pos
	sc.aim_at(P, P.pos + Vector3(0, 0, -6))
	P.inp["move"] = Vector2(1, 0)
	P.dashes = P.max_dashes()
	P.inp["dash"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	var aft := K.lk().live.filter(func(e): return String(e["kind"]) == "mote").size()
	step(m, 0.25)
	P.inp["move"] = Vector2.ZERO
	ok(
			"mm Shift: Relay Step goes where you move (cursor elsewhere), its own hop and after-images",
			P.pos.x - p0.x > 2.5 and absf(P.pos.z - p0.z) < 1.0 and aft >= 1,
			"dx %.1f dz %.1f aft %d" % [P.pos.x - p0.x, P.pos.z - p0.z, aft])
	ok(
			"mm Shift: the hop is its own move (no shared roll under it)",
			K.anim_id == "mm_skip" and K.dodge_anim() == "kit")
	# --- the air dash is her long floaty glide (dash.air), not the class long dash
	step(m, 0.4)
	var g0 := P.pos
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.grounded = false
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	var lift0 := P.pos.y
	step(m, 0.5)
	var sink := lift0 - P.pos.y
	step(m, 0.4)
	P.inp["move"] = Vector2.ZERO
	var glide_d := P.pos.x - g0.x
	var air: Dictionary = K.dash_def()["air"]
	var glide_want := float(air["dist"])
	ok(
			"mm air dash: a floaty glide of dash.air.dist, held up while it floats, its own move",
			absf(glide_d - glide_want) < 1.0 and sink < 1.0 and K.anim_id == "mm_float",
			"%.1f m of %.1f, sank %.2f m in 0.5 s" % [glide_d, glide_want, sink])
	ok(
			"mm body: small (a 0.65 model) with the 0.34 m hitbox",
			absf(P.r - 0.34) < 0.001 and P.model.scale.y < 0.9,
			"r %.2f scale %.2f" % [P.r, P.model.scale.y])
	step(m, 1.0)
	# --- Carrier: a teammate being stomped can't be picked up (small mechanic), else a pickup move
	sc.down(m, A)
	A.teleport(P.pos + Vector3(0.5, 0, 0))
	T.teleport(A.pos)
	K.lock_t = 0.2
	step(m, 0.1)
	K.lock_t = 0.0
	step(m, 0.1)
	ok(
			"mm passive: a teammate being stomped can't be scooped up",
			not CareUtil.is_carried(A) and bool(A.get_meta("stomped", false)))
	T.teleport(P.pos + Vector3(14, 0, 0))
	step(m, 0.1)
	ok(
			"mm passive: scooping a downed teammate up plays the pickup move",
			CareUtil.is_carried(A) and K.anim_id == "mm_pickup", K.anim_id)
	P.inp["crouch"] = true
	step(m, 0.1)
	P.inp["crouch"] = false
	step(m, 0.1)
	await _free(m)
	# --- merge start drops the Burrseed aim (no throw, the lane and pose gone)
	r = sc.setup("tender", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	K.ch_rmb = 1.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.2)
	var aiming := K.seed_aim and AimKit.shown(P, "rmb")
	var n1: int = _mine(m, P).size()
	K.drop_holds()
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, float(K.rmb_def()["windup"]) + 0.2)
	ok(
			"mm merge: drop_holds ends the Burrseed wind-up without a throw",
			aiming
			and not K.seed_aim
			and not K.rmb_down
			and not AimKit.shown(P, "rmb")
			and _mine(m, P).size() == n1
			and K.ch_rmb >= 1.0)
	# holding the key through it changes nothing: one throw, on time
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	sc.aim_at(P, T.pos)
	var n2: int = _mine(m, P).size()
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	var th := 0.0
	while _mine(m, P).size() == n2 and th < 2.0:
		step(m, 1.0 / 60.0)
		th += 1.0 / 60.0
	step(m, 1.0)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	ok(
			"mm RMB: held down, it goes at the same moment, once (%.2f s)" % th,
			absf(th - float(K.rmb_def()["windup"])) <= 0.05 and K.ch_rmb < 1.0 and not K.seed_aim)
	# a stun loses the throw, not the charge
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.press_rmb()
	var n3: int = _mine(m, P).size()
	step(m, 0.2)
	P.stun_t = 0.3
	step(m, 1.2)
	ok("mm RMB: a stun in the wind-up loses the throw, not the charge",
			not K.seed_aim and K.ch_rmb >= 1.0 and _mine(m, P).size() == n3)
	await _free(m)
	await growth()
	await burr_ranks()
	await _dashes_cute()
	await _no_blasts()

## Elluna's dashes, copied (numbers in docs/heroes/tender.md): the ground hop is the source's 2 bh
## in 0.2 s (after the dash feel), the air glide its measured 13.3 m over 0.95 s peaking about 17 m/s, 3-4x the
## hop's distance and about 5x its time; each plays its own move (item 35), sized to its dash, and no other kit
## plays those moves.
func _dashes_cute() -> void:
	var r: Array = sc.setup("tender", 20.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: TenderKit = P.ak
	var p0 := P.pos
	P.inp["move"] = Vector2(1, 0)
	P.dashes = P.max_dashes()
	P.inp["dash"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	P.inp["move"] = Vector2.ZERO
	var ground_t := P.roll_t + 1.0 / 60.0
	var ground_move := K.anim_id
	step(m, P.roll_t)
	var ground_d := P.pos.x - p0.x
	ok(
			"mm dashes: the ground hop is Elluna's: 2 bh (3.6 m) in 0.2 s after the dash feel",
			absf(ground_d - 3.6) < 0.25 and absf(ground_t - 0.2) < 0.02,
			"%.2f m in %.2f s" % [ground_d, ground_t])
	step(m, 0.5)
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.grounded = false
	var a0 := P.pos
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	P.inp["move"] = Vector2.ZERO
	var air_t := P.roll_t
	var glide_cd := P.ex_cd
	var air_move := K.anim_id
	var peak := {"v": 0.0}
	step(m, air_t + 0.05, func(): peak["v"] = maxf(float(peak["v"]), P.roll_speed))
	var air_d := P.pos.x - a0.x
	ok(
			"mm dashes: the air glide is Elluna's: 13.3 m over 0.95 s, peaking 16.5-22 m/s",
			absf(air_d - 13.3) < 0.7 and absf(air_t - 0.95) < 0.03 and float(peak["v"]) >= 16.5
				and float(peak["v"]) <= 22.0,
			"%.2f m in %.2f s, peak %.1f m/s" % [air_d, air_t, float(peak["v"])])
	var ratio := air_d / maxf(0.01, ground_d)
	ok(
			"mm dashes: Elluna's cooldowns: the glide 14 s, a hop charge 7 s (separate)",
			absf(glide_cd - 14.0) < 0.05 and absf(P.dash_regen() - 7.0) < 0.01,
			"glide %.2f s, hop %.2f s" % [glide_cd, P.dash_regen()])
	ok(
			"mm dashes: the glide goes 3-4x the hop's distance and about 5x its time (source)",
			ratio >= 3.0 and ratio <= 4.0 and air_t / ground_t >= 4.0 and air_t / ground_t <= 6.0,
			"x%.2f distance, x%.2f time" % [ratio, air_t / ground_t])
	ok(
			"mm dashes: each plays its own move, never the shared roll",
			ground_move == "mm_skip" and air_move == "mm_float" and K.dodge_anim() == "kit",
			"%s / %s" % [ground_move, air_move])
	var fits := func(id: String, t: float) -> bool:
		var n := KMovesCare.length(id)
		return n >= t and n <= t + MOVE_TAIL_MAX
	ok(
			"mm dashes: each move covers its dash and settles soon after (ground 0.16-0.25 s)",
			fits.call("mm_skip", ground_t) and fits.call("mm_float", air_t) and KMovesCare.length("mm_skip") <= 0.25,
			"skip %.2f/%.2f float %.2f/%.2f" % [
				KMovesCare.length("mm_skip"), ground_t, KMovesCare.length("mm_float"), air_t])
	ok("mm dashes: no other kit plays her dash moves", own_moves_only("tender_kit.gd", ["mm_skip", "mm_float"]))
	await _free(m)
	await _moosh_audit()

## Audit: the glide is airborne only (on the ground with the hop spent, Shift is refused, never a glide
## along the ground); the move keys steer the glide (air control); Burrseed 10.5 s (the data's ratio to E);
## her Ember Cast has no magazine and no slow while firing (the source has neither).
func _moosh_audit() -> void:
	var r: Array = sc.setup("tender", 20.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: TenderKit = P.ak
	step(m, 0.1)
	P.dashes = 0.0
	P.ex_cd = 0.0
	var p0 := P.pos
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	step(m, 1.0 / 60.0)
	P.inp["dash"] = false
	P.inp["move"] = Vector2.ZERO
	step(m, 0.3)
	ok(
			"mm dashes: on the ground with the hop spent, Shift is refused (no glide along the ground)",
			P.grounded and K.glide.is_empty() and P.ex_cd <= 0.0
				and Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length() < 1.5,
			"moved %.2f, ex_cd %.1f" % [Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length(), P.ex_cd])
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.grounded = false
	P.inp["move"] = Vector2(1, 0)
	K.on_dash(true)
	step(m, 0.15)
	var heading0: Vector2 = P.roll_dir
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.4)
	var turned := rad_to_deg(absf(heading0.angle_to(P.roll_dir)))
	P.inp["move"] = Vector2.ZERO
	ok(
			"mm air dash: the move keys steer the glide (air control), at a capped rate",
			turned > 40.0 and turned < 90.0, "turned %.0f deg in 0.4 s" % turned)
	step(m, 1.0)
	ok(
			"mm RMB: Burrseed 10.5 s (the data's 11.5 : 12 against Hearthlight's 11 s)",
			absf(float(K.rmb_def()["cooldown"]) - 10.5) < 0.01)
	ok(
			"mm LMB: Ember Cast has no magazine to reload and no slow while firing (the source has neither)",
			int(P.wpn["mag"]) >= 99 and float(P.wpn["fire_slow"]) >= 1.0)
	await _free(m)

## True when no hero kit (a *_kit.gd) other than `own` names any of `ids` (a dash move is one hero's own).
static func own_moves_only(own: String, ids: Array) -> bool:
	for f in DirAccess.get_files_at("res://scripts/arch/kits"):
		if not f.ends_with("_kit.gd") or f == own:
			continue
		var src := FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)
		for id in ids:
			if src.contains('"%s"' % id):
				return false
	return true

## Owner item 23: no cosmetic burst or ring on her hop or glide, her Hearthlight's last heal blooms without a
## ring, blast or shake, and the explosion sounds sit under the agreed peak.
func _no_blasts() -> void:
	var r: Array = sc.setup("tender", 20.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: TenderKit = P.ak
	var rings := {"made": 0, "seen": m.fx.rings.size()}      # rings spawned (a lambda keeps a dict by reference)
	var each := func():
		rings["made"] = int(rings["made"]) + maxi(0, m.fx.rings.size() - int(rings["seen"]))
		rings["seen"] = m.fx.rings.size()
	var bi0: int = m.fx.bi
	P.inp["move"] = Vector2(1, 0)
	P.dashes = P.max_dashes()
	P.inp["dash"] = true
	step(m, 1.0 / 60.0, each)
	P.inp["dash"] = false
	step(m, 0.5, each)
	P.teleport(P.pos + Vector3(0, 3.0, 0))
	P.grounded = false
	P.ex_cd = 0.0
	K.on_dash(true)
	step(m, 1.1, each)
	P.inp["move"] = Vector2.ZERO
	var emitted := posmod(m.fx.bi - bi0, m.fx.bursts.size())
	var loud := K.lk().live.filter(func(e): return String(e["fx"]) in ["flare", "rays", "column"]).size()
	ok(
			"mm dashes: no ring or burst on her hop or glide (two tiny dust puffs, soft motes)",
			int(rings["made"]) == 0 and emitted <= 2 and loud == 0,
			"rings %d emitters %d flares %d" % [int(rings["made"]), emitted, loud])
	A.teleport(P.pos + Vector3(0.8, 0, 0))
	A.hp = A.max_hp * 0.5
	K.cd["e"] = 0.0
	P.inp["sig"] = true
	step(m, 1.0 / 60.0)
	P.inp["sig"] = false
	step(m, float(K.e_def()["time"]) - 0.1)
	var hp0 := A.hp
	rings["made"] = 0
	rings["seen"] = m.fx.rings.size()
	var shake0: float = m.cam.shake_total if m.cam else 0.0
	step(m, 0.2, each)
	ok(
			"mm E: the light's last heal blooms (heals, no ring, blast or shake; a quiet chime)",
			not K.in_e() and A.hp > hp0 + 5.0 and int(rings["made"]) == 0
				and (m.cam == null or m.cam.shake_total <= shake0) and TenderKit.BLOOM_DB <= -6.0,
			"healed %.1f rings %d" % [A.hp - hp0, int(rings["made"])])
	var worst := -99.0
	for sn in Sfx.BLAST:
		worst = maxf(worst, wav_peak_db("res://audio/%s.wav" % sn) + Sfx.BLAST_DB)
	ok(
			"audio: the explosion category peaks under the agreed level", worst <= Sfx.BLAST_PEAK_DB and worst > -40.0,
			"%.1f dBFS (ceiling %.1f)" % [worst, Sfx.BLAST_PEAK_DB])
	await _free(m)

## The peak of a 16-bit PCM wav file in dBFS (-99 if it can't be read).
static func wav_peak_db(path: String) -> float:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var n := bytes.decode_u32(at + 4)
		if tag == "data":
			var peak := 0
			for i in range(at + 8, mini(bytes.size() - 1, at + 8 + n), 2):
				peak = maxi(peak, absi(bytes.decode_s16(i)))
			return linear_to_db(maxf(peak, 1) / 32768.0)
		at += 8 + n + (n % 2)
	return -99.0

## Burrseed's burst damage on the first foe, with the hunter at level `lvl`.
func _seed_burst(lvl: int) -> float:
	var r: Array = sc.setup("tender", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	P.lvl = lvl
	LevelGrowth.apply(P)          # growth follows levels gained (a level set straight grows nothing)
	sc.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var h0 := T.hp
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 1.2 + float(K.rmb_def()["windup"]))
	var dmg := h0 - T.hp
	await _free(m)
	return dmg

## Ability damage reads ArchKit.power(), so quiet level growth (LevelGrowth.ap) raises it.
func growth() -> void:
	var d1: float = await _seed_burst(1)
	var d10: float = await _seed_burst(10)
	ok(
			"mm RMB: Burrseed's burst grows with level (LevelGrowth.ap 1.0 -> %.2f)" % (1.0 + LevelGrowth.ap_pct(10)),
			d1 > 25.0 and d10 > d1 * 1.15, "L1 %.1f L10 %.1f" % [d1, d10])

## Rank 3 doubles the Burrseed's burst width (the source's detonation-radius upgrade) and adds 0.3 s of root.
func burr_ranks() -> void:
	var r: Array = sc.setup("tender", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: TenderKit = P.ak
	var wide1 := K.burst_radius()
	P.slot_lv["sec"] = 3
	var wide3 := K.burst_radius()
	ok("mm RMB: the burst is 2.2 m wide, 4.4 m at rank 3", absf(wide1 - 2.2) < 0.01 and absf(wide3 - 4.4) < 0.01,
			"r1 %.2f r3 %.2f" % [wide1, wide3])
	await _free(m)

# ================================================================== Claire
func rimewright() -> void:
	var r: Array = sc.setup("rimewright", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	ok(
			"tm: kit sounds load",
			Sfx.streams.has("rime_shard") and Sfx.streams.has("rime_wall_tell") and Sfx.streams.has("rime_zone"))
	step(m, 0.05)
	ok("tm: the thin aim line to the cursor is always up", AimKit.shown(P, "aim"))
	# --- a steady stream (no pause) of slow darts that bow out and home, 4 plain then 3 large
	var times: Array = []
	var dmgs: Array = []
	var bows: Array = []
	var seen := {}
	P.inp["fire"] = true
	var t := 0.0
	while t < 1.4:
		step(m, 1.0 / 60.0)
		t += 1.0 / 60.0
		for s in _mine(m, P):
			if not seen.has(s["sid"]):
				seen[s["sid"]] = true
				times.append(t)
				dmgs.append(float(s["dmg"]))
				bows.append(absf(rad_to_deg((s["vel"] as Vector2).angle_to(P.aim_dir()))))
	P.inp["fire"] = false
	var gaps: Array = []
	for i in range(1, times.size()): gaps.append(float(times[i]) - float(times[i - 1]))
	var maxgap: float = gaps.max() if not gaps.is_empty() else 9.0
	ok(
			"tm LMB: a steady stream, one dart every 0.18 s with no pause", times.size() >= 7 and maxgap < 0.22,
			"%d darts, longest gap %.2f" % [times.size(), maxgap])
	var base_dmg := float(P.wpn["dmg"]) * float(m.dmg_mult(P))
	var pattern := dmgs.slice(0, 7).map(func(d): return "H" if float(d) > base_dmg * 1.5 else "p")
	ok(
			"tm LMB: the source's barrage: 4 darts, then 3 larger ones at double damage (game data), then round again",
			"".join(pattern) == "ppppHHH" and dmgs.size() >= 8 and float(dmgs[7]) < base_dmg * 1.5
				and K.stats["heavies"] >= 3,
			"".join(pattern))
	ok(
			"tm LMB: darts come out slowly (16 m/s), a little off the aim to alternating sides",
			float(P.wpn["speed"]) <= 18.0 and not bows.is_empty() and float(bows[0]) > 5.0 and float(bows[0]) < 15.0,
			"first bow %.0f deg" % (float(bows[0]) if not bows.is_empty() else 0.0))
	step(m, 0.8)
	var thrown_dmg: float = dmgs.reduce(func(a, d): return a + float(d), 0.0)
	ok(
			"tm LMB: the bowed darts curve back onto the foe at the cursor",
			T.max_hp - T.hp >= thrown_dmg * 0.75,
			"dealt %.0f of %.0f" % [T.max_hp - T.hp, thrown_dmg])
	ok("tm LMB: darts alternate hands with their own flick moves", K.stats["darts"] >= 7)
	ok(
			"tm passive: the frost glow on the foe shows the stacks",
			K.lk().showing("frost%d" % T.get_instance_id()) or K.splinter_log > 0)
	await _free(m)
	await _late_homing()
	# --- 8 darts on one foe Shatter them for about 15 darts' worth, with the spikes
	r = sc.setup("rimewright", 5.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var T2: Hunter = m.make_hunter(
			"T2", T.team, "medium", "Target2", "idle", {}, T.pos + Vector3(1.2, 0, 0), {"arch": "none"})
	T2.max_hp = 10000.0
	T2.hp = 10000.0
	T2.armor = 0.0
	T2.max_armor = 0.0
	var s0 := K.splinter_log
	P.inp["fire"] = true
	step(m, 2.4)
	P.inp["fire"] = false
	var spikes := K.lk().live.filter(func(e): return String(e["fx"]) == "spikes").size() > 0 or K.lk().made > 0
	ok(
			"tm passive: 8 darts on one foe Shatter them (about 15 darts' damage, ice spikes)",
			K.splinter_log > s0 and T2.max_hp - T2.hp > float(P.wpn["dmg"]) * 12.0 and spikes,
			"neighbour -%.0f" % (T2.max_hp - T2.hp))
	step(m, 0.5)
	# --- Shatter on a knock (Chilled foe)
	T.hp = 8.0
	K.add_chill(T)
	T2.teleport(T.pos + Vector3(1.5, 0, 0))
	T2.hp = T2.max_hp
	step(m, 0.05)
	var s1 := K.splinter_log
	var hh := T2.hp
	sc.aim_at(P, T.pos)
	P.inp["fire"] = true
	step(m, 0.8)
	P.inp["fire"] = false
	step(m, 0.8)
	ok(
			"tm passive: knocking a Chilled foe Shatters them after a beat",
			T.downed and K.splinter_log > s1 and T2.hp < hh, "downed %s" % str(T.downed))
	await _free(m)
	# --- Skate: darts fly straight and thick at normal damage; she carries on over a ledge; the stride move loops
	r = sc.setup("rimewright", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var lv := int(W.level[W.idx(hx, hz)])
	for dz in range(-10, 11):
		for dx in range(-2, 2):
			# she stands on a step; off its edge it drops
			if W.inb(hx + dx, hz + dz): W.level[W.idx(hx + dx, hz + dz)] = lv + 1
	P.teleport(P.pos + Vector3(0, World.LEVEL, 0))
	step(m, 0.1)
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(-1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	ok(
			"tm Shift: Shift held starts a skate with its push-off",
			K.rinkrunning() and P.roll_t > 0.0 and K.anim_id == "tm_skate_go")
	sc.aim_at(P, T.pos)
	var nb := _mine(m, P).size()
	P.inp["fire"] = true
	step(m, 0.1)
	P.inp["fire"] = false
	var bs: Array = _mine(m, P)
	var bd := float(bs[-1]["dmg"]) if bs.size() > nb else 0.0
	ok(
			"tm Shift: darts while skating are straight beams at normal damage",
			bs.size() > nb and absf(bd - float(P.wpn["dmg"])) < 0.05 and K.stats["beams"] >= 1,
			"dmg %.2f" % bd)
	step(m, 0.15)
	var skate_v := Vector2(P.vel.x, P.vel.z).length()
	ok(
			"tm Shift: full skating speed (dash.speed) within about 0.2 s, with a ribbon of ice chips",
			absf(skate_v - float(K.dash_def()["speed"])) < 0.6
				and K.lk().live.filter(func(e): return String(e["kind"]) == "chip").size() >= 4,
			"%.1f m/s" % skate_v)
	step(m, 0.55)
	ok("tm Shift: the stride move loops while skating (off the step she is on the air stride)",
			K.anim_id == ("tm_skate" if P.grounded else "tm_skate_air") and K.rinkrunning(),
			"%s grounded %s" % [K.anim_id, P.grounded])
	ok(
			"tm Shift: she skates on over a ledge (not stopped by leaving the ground)",
			K.rinkrunning() and float(int(floor(P.pos.x)) - hx) <= -3.0,
			"at %.1f from the start" % (P.pos.x - float(hx)))
	P.inp["dash_down"] = false
	step(m, 0.1)
	ok(
			"tm Shift: letting go stops with a hockey stop and refunds part of the charge",
			not K.rinkrunning() and P.dashes > 0.05 and K.anim_id == "tm_skate_stop", "dashes %.2f" % P.dashes)
	await _free(m)
	await _skate_feel()
	await _skate_only()
	await _air_skate()
	await _air_skate_rules()
	await _statue_locks()
	await _rime_glide_skate()
	await _rime_skate_in()
	await _skate_ice()
	await _spear_rank3()
	await _spear_travel()
	# --- Ice Spear: hold shows the ring at the cursor; it lands there, slows, detonates 1.8 s later
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	var cur := P.pos + Vector3(7.0, 0, 0)
	T.teleport(cur + Vector3(0.6, 0, 0))
	step(m, 0.05)
	sc.aim_at(P, cur)
	K.ch_rmb = 2.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.3)
	var ring: Dictionary = AimKit.entry(P, "rmb")
	var ra: Vector2 = ring.get("at", Vector2.ZERO)
	var chest := P.position + Vector3(P.aim_dir().x * RimewrightKit.SPEAR_AHEAD, RimewrightKit.SPEAR_Y,
			P.aim_dir().y * RimewrightKit.SPEAR_AHEAD)
	ok(
			"tm RMB: held, the landing ring sits on the cursor; she gathers the spear between her palms at her chest",
			AimKit.shown(P, "rmb") and ra.distance_to(Vector2(cur.x, cur.z)) < 0.2 and K.anim_id == "tm_spear_aim"
				and K.lk().showing("spear_prop") and K._spear_at(0.0).distance_to(chest) < 0.01)
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	step(m, 1.0 / 60.0)
	ok(
			"tm RMB: let go, the push starts (no throw wind-up): the spear on her palms, nothing at the target",
			K.lk().showing("spear_prop") and _mine(m, P).is_empty() and K.zones.is_empty() and K.anim_id == "tm_spear")
	var thrown := {}
	var waited := 1.0 / 60.0
	while thrown.is_empty() and waited < 0.5:
		step(m, 1.0 / 60.0)
		waited += 1.0 / 60.0
		var mine := _mine(m, P)
		if not mine.is_empty():
			thrown = mine[0]
	var ld: Dictionary = K.rmb_def()["lance"]
	var from: Vector3 = thrown.get("start", Vector3.INF)
	var spd := (thrown.get("vel", Vector2.ZERO) as Vector2).length()
	var off_her := Vector2(from.x - P.pos.x, from.z - P.pos.z).length()
	ok(
			"tm RMB: the push: the spear emerges from her (within 1 m, chest height) as the palms extend (0.1 s)",
			not thrown.is_empty() and absf(waited - RimewrightKit.PUSH_T) < 0.04 and off_her < 1.0
				and from.y - P.pos.y > 0.8 and absf(spd - float(ld["speed"])) < 0.01
				and not K.lk().showing("spear_prop"),
			"after %.2f s, %.2f m out at %.2f m up, %.1f m/s" % [waited, off_her, from.y - P.pos.y, spd])
	var flight := 0.0
	var hp_fly := T.hp
	while K.zones.is_empty() and flight < 1.5:
		step(m, 1.0 / 60.0)
		flight += 1.0 / 60.0
	var landed := hp_fly - T.hp
	var want_flight := Vector2(cur.x - from.x, cur.z - from.z).length() / float(ld["speed"])
	ok(
			"tm RMB: it travels out to the target, landing on arrival (not at the cast)",
			flight > 0.25 and absf(flight - want_flight) < 0.06, "flight %.2f s, want %.2f" % [flight, want_flight])
	ok(
			"tm RMB: the landing hits a small area (game data: 156 in a small AoE + slow): 18 within 1.2 m",
			absf(landed - float(ld["dmg"]) * K.power("sec")) < 0.5 and float(ld["impact_r"]) <= 1.5,
			"%.1f" % landed)
	var zat: Vector3 = K.zones[0]["at"] if not K.zones.is_empty() else Vector3.INF
	ok(
			"tm RMB: the spear lands at the cursor and leaves a slow zone",
			not K.zones.is_empty() and Vector2(zat.x - cur.x, zat.z - cur.z).length() < 1.0,
			"off %.2f" % Vector2(zat.x - cur.x, zat.z - cur.z).length())
	step(m, 0.2)
	ok(
			"tm RMB: two charges on a 10.2 s cooldown",
			K.rmb_charges() == 2 and K.cd["rmb"] > 9.0 and K.cd["rmb"] <= 10.2, "cd %.2f" % K.cd["rmb"])
	ok(
			"tm RMB: a foe in the zone is slowed and Chilled", T.slow_t > 0.0 and T.slow_k >= 0.34 and K.chilled(T),
			"slow %.2f" % T.slow_k)
	var hb := T.hp
	var since := 0.2
	while int(K.stats["detonations"]) == 0 and since < 3.0:
		step(m, 1.0 / 60.0)
		since += 1.0 / 60.0
	ok(
			"tm RMB: it detonates 1.8 s after landing: the big hit and a slow, no root (the data has none)",
			absf(since - float(ld["delay"])) < 0.05 and hb - T.hp > 50.0 and T.root_t <= 0.0 and T.slow_t > 0.0,
			"at %.2f s, %.0f damage, root %.2f" % [since, hb - T.hp, T.root_t])
	await _free(m)
	# --- Rink Wall: a 0.2 s tell, narrow just ahead, widening as it slides, stops at the cursor
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	cur = P.pos + Vector3(7.0, 0, 0)
	sc.aim_at(P, cur)
	T.teleport(P.pos + Vector3(4.0, 0, 0))
	T.ctrl = "idle"
	step(m, 0.05)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	ok(
			"tm E: a 0.2 s tell first (sparkle, the move, the path shown to all), no wall yet",
			K.wall.is_empty()
			and not K.wall_cast.is_empty()
			and K.anim_id == "tm_wall"
			and AimKit.shown(P, "e")
			and bool(AimKit.entry(P, "e").get("all", false)))
	step(m, 0.25)
	var w0: Dictionary = K.wall.get("w", {})
	var mid0 := ((w0.get("a", Vector2.ZERO) as Vector2) + (w0.get("b", Vector2.ZERO) as Vector2)) * 0.5
	ok(
			"tm E: then it erupts about 1 bh ahead and narrow, in her own ice look",
			not K.wall.is_empty()
			and absf(mid0.x - P.pos.x - 1.8) < 0.8
			and float(w0.get("len", 9.0)) < 2.4
			and K.lk().showing("wall")
			and not (w0["node"] as Node3D).visible,
			"at %.1f len %.1f" % [mid0.x - P.pos.x, float(w0.get("len", 0.0))])
	var tx := T.pos.x
	step(m, 1.4)
	var w1: Dictionary = K.wall["w"]
	var mid1 := ((w1["a"] as Vector2) + (w1["b"] as Vector2)) * 0.5
	ok(
			"tm E: it slides toward the cursor, widening, and shoves the foe ahead",
			float(w1["len"]) > 3.5 and mid1.x > mid0.x + 3.0 and T.pos.x > tx + 1.0,
			"len %.1f moved %.1f foe +%.1f" % [float(w1["len"]), mid1.x - mid0.x, T.pos.x - tx])
	ok(
			"tm E: it stops at the cursor", not bool(K.wall["sliding"]) and absf(mid1.x - cur.x) < 0.8,
			"mid at %.1f, cursor %.1f" % [mid1.x - P.pos.x, cur.x - P.pos.x])
	await _free(m)
	# aimed far past its reach, it slides its full travel (4.5 m/s, 16.2 m) and still stands after
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	K = P.ak
	sc.aim_at(P, P.pos + Vector3(24.0, 0, 0))
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 0.3)
	var wf: Dictionary = K.wall["w"]
	var start_x: float = P.pos.x + float(K.e_def()["reach"])
	var slid := 0.3
	while bool(K.wall.get("sliding", false)) and slid < 6.0:
		step(m, 0.05)
		slid += 0.05
	var end_x := ((wf["a"] as Vector2) + (wf["b"] as Vector2)).x * 0.5
	var ed: Dictionary = K.e_def()
	ok(
			"tm E: it travels 16.2 m at most (+50%), about 3.6 s, and still stands at the end",
			absf(end_x - start_x - float(ed["travel"])) < 0.6 and float(ed["travel"]) >= 16.0 and slid > 3.3
				and not K.wall.is_empty() and float(wf["len"]) > 4.4,
			"travelled %.1f m in %.2f s" % [end_x - start_x, slid])
	await _free(m)
	r = sc.setup("rimewright", 30.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	sc.aim_at(P, P.pos + Vector3(10.0, 0, 0))
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	step(m, 0.5)
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	var wa: Vector2 = K.wall["w"]["a"]
	step(m, 0.5)
	ok(
			"tm E: E again freezes it where it stands, for 6 s, with the stamp move",
			not bool(K.wall["sliding"])
			and (K.wall["w"]["a"] as Vector2).distance_to(wa) < 0.01
			and float(K.wall["w"]["t"]) > 5.0
			and K.anim_id == "tm_freeze")
	# a foe's shot into the wall is stopped
	var ph := P.hp
	var wm := ((K.wall["w"]["a"] as Vector2) + (K.wall["w"]["b"] as Vector2)) * 0.5
	m.spawn_shot(T, Vector3(wm.x + 3.0, P.pos.y + 0.95, wm.y), Vector2(-1, 0) * 30.0, 10.0, 1.0, 0.2, Color.RED, {})
	step(m, 0.6)
	ok("tm E: the wall stops a foe's shot", P.hp >= ph - 0.01, "hp %.1f -> %.1f" % [ph, P.hp])
	await _free(m)
	# --- merge start: skate, spear aim and a wall in its tell all drop
	r = sc.setup("rimewright", 6.0)
	m = r[0]
	P = r[1]
	A = r[2]
	T = r[3]
	K = P.ak
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, 0.05)
	P.inp["dash"] = false
	K.ch_rmb = 2.0
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	step(m, 0.2)
	P.inp["sig"] = true
	step(m, 0.02)
	P.inp["sig"] = false
	var all_up := K.rinkrunning() and K.spear_aim and not K.wall_cast.is_empty()
	K.drop_holds()
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	P.inp["dash_down"] = false
	step(m, 0.4)
	ok(
			"tm merge: drop_holds ends the skate, the spear aim and the wall's tell (no throw, no wall)",
			all_up
			and not K.rinkrunning()
			and not K.spear_aim
			and K.wall_cast.is_empty()
			and K.wall.is_empty()
			and K.zones.is_empty()
			and not AimKit.shown(P, "rmb"))
	await _free(m)
