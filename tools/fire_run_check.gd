extends RefCounted
## --fire-run-check [--wardens=a,b]: firing while running keeps the run legs (docs/art/wardens/CLIPS.md, "upper").
## Per Hunter with hand-keyed clips, in a real match (archetype_check's strip, the kit's own keys, Hunter.render and
## Sync): he runs at full stick, then fires LMB, RMB and E without letting go of the stick. For each press it reads
## the planted feet against the ground (the --anim-audit measure: a foot in the lowest 30 % of its height range is
## planted, its world speed is the slide) and how much of the body the move's clip owns. The gate, on the frames
## he is still at full stick (FULL: a kit's slow-down hands the legs to the walk/run blend, the gait layer's job,
## --anim-audit): the move plays on the upper body, and its feet slide at most MAX_SLIDE of the speed more than his
## plain run's do. A cast that roots him, a dash or lunge the kit carries him on, and NO_LEGS are their clips'.
## Never touches the save.

const DT := 1.0 / 60.0
const WARM_S := 1.4          # s of running up to speed (and out of the last move), not sampled
const RUN_S := 2.4           # s of plain running sampled once per Hunter: the baseline and the feet's height range
const PRESS_S := 1.1         # s sampled from the press (only while the move's clip is on)
const FULL := 0.9            # of the plain run's speed: a frame he is still running at full stick
const ROOTED := 0.6          # a move slower than this on average stops him (a braced cast): the clip owns the legs
const DRIVEN := 1.15         # ...and one faster carries him (a lunge, a dash): the clip owns them too
const MIN_FRAMES := 10       # full-stick frames a move needs to be gated
const TAP := 8               # frames LMB is held: a click
const PLANT_BAND := 0.3
const MAX_SLIDE := 0.25
const SLOTS := ["lmb", "rmb", "e"]
const NO_LEGS := ["ostra", "rimewright"]     # they hover and skate: no stepping legs (as --anim-audit)

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FIRERUN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var ids: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
	for id in ids:
		if not WardenClips.data(String(WardenGlb.ART.get(id, ""))).is_empty():
			await _hunter(String(id))
	print("FIRE_RUN_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(id: String) -> void:
	var r: Array = A.setup(id, 40.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	(r[2] as Hunter).teleport(home + Vector3(0, 0, 30.0))
	_run(m, P, WARM_S, "")
	var fr := _run(m, P, RUN_S, "")
	var band := _band(fr)
	var base := _slide(fr, band)
	var run_share: float = base["slide"] / maxf(base["speed"], 0.1)
	print("FIRERUN %-10s run %.2f m/s slide %.2f m/s (%d%%)" % [id, base["speed"], base["slide"], round(100.0 * run_share)])
	for slot in SLOTS:
		P.teleport(home)
		P.vel = Vector3.ZERO
		_run(m, P, WARM_S, "")
		var on: Array = _run(m, P, PRESS_S, slot).filter(func(p): return float(p["up"]) + float(p["full"]) > 0.05)
		var moves := {}
		for p in on:
			moves[p["move"]] = true
		for mv in moves:
			var own: Array = on.filter(func(p): return p["move"] == mv)
			var ms := _slide(own, band)
			var kept: float = ms["speed"] / maxf(base["speed"], 0.1)
			var fast: Array = own.filter(func(p): return float(p["v"]) >= FULL * float(base["speed"]))
			var fs := _slide(fast, band)
			var share: float = fs["slide"] / maxf(fs["speed"], 0.1)
			var full: float = fast.map(func(p): return float(p["full"])).max() if not fast.is_empty() else 0.0
			print("FIRERUN %-10s %-3s %-16s speed %3d%% full-stick %2d/%2d frames, body %.2f, slide %3d%% (all frames %3d%%)"
					% [id, slot, mv, round(100.0 * kept), fast.size(), own.size(),
					full, round(100.0 * share), round(100.0 * ms["slide"] / maxf(ms["speed"], 0.1))])
			if fast.size() < MIN_FRAMES or id in NO_LEGS or kept < ROOTED or kept > DRIVEN:
				continue
			ok(full < 0.5, "%s %s: running, plays on the upper body (whole-body weight %.2f)" % [id, mv, full])
			ok(share <= run_share + MAX_SLIDE, "%s %s: the feet slide %d%% while firing, %d%% plain run (limit +%d)"
					% [id, mv, round(100.0 * share), round(100.0 * run_share), round(100.0 * MAX_SLIDE)])
	A.done(m)
	await A.main.get_tree().process_frame

## Runs along +X for secs, pressing slot on the first frame (LMB a click, RMB held for a third of it): per frame,
## the feet, his speed, the move and how much of the body its clip owns.
func _run(m: Match, P: Hunter, secs: float, slot: String) -> Array:
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var sync: Node = P.model.get_node("Warden/Sync")
	var clips: WardenClips = sync.get("clips")
	var fr: Array = []
	var n := int(secs / DT)
	for f in n:
		P.inp["move"] = Vector2(1, 0)
		A.aim_at(P, P.pos + Vector3(12.0, 0, 0))
		P.inp["fire"] = slot == "lmb" and f < TAP
		P.inp["sec"] = slot == "rmb" and f == 0
		P.inp["sec_hold"] = slot == "rmb" and f < n / 3
		P.inp["sig"] = slot == "e" and f == 0
		for mb in m.mobs:
			mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		P.render(DT, 1.0)
		sync.set_process(false)
		sync.call("_process", DT)
		fr.append({"L": _foot(sk, "L"), "R": _foot(sk, "R"), "v": Vector2(P.vel.x, P.vel.z).length(),
				"move": P.ak.anim_id, "up": clips.up_w, "full": clips.act_w})
	for k in ["fire", "sec", "sec_hold", "sig"]:
		P.inp[k] = false
	return fr

## The foot: the shin's end (the --anim-audit point), world frame.
func _foot(sk: Skeleton3D, side: String) -> Vector3:
	var shin := WardenSkeleton.find(sk, "shin." + side)
	var thigh := WardenSkeleton.find(sk, "thigh." + side)
	var gs := sk.get_bone_global_pose(shin)
	var leg := (sk.get_bone_global_rest(shin).origin - sk.get_bone_global_rest(thigh).origin).length()
	return sk.global_transform * (gs.origin + gs.basis.y.normalized() * leg)

## Per foot, the height under which it counts as planted: the lowest PLANT_BAND of its range in the plain run.
func _band(fr: Array) -> Dictionary:
	var out := {}
	for f in ["L", "R"]:
		var lo := INF
		var hi := -INF
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		out[f] = lo + PLANT_BAND * maxf(hi - lo, 0.02)
	return out

## The mean ground speed of a planted foot (central difference; frames next to a gap are skipped) and his mean speed.
func _slide(fr: Array, band: Dictionary) -> Dictionary:
	var slide := 0.0
	var n := 0
	var spd := 0.0
	for p in fr:
		spd += float(p["v"])
	for f in ["L", "R"]:
		for i in range(1, fr.size() - 1):
			if (fr[i][f] as Vector3).y > float(band[f]):
				continue
			var dv: Vector3 = (fr[i + 1][f] as Vector3) - (fr[i - 1][f] as Vector3)
			if dv.length() > 1.0:
				continue
			slide += Vector2(dv.x, dv.z).length() / (2.0 * DT)
			n += 1
	return {"slide": slide / maxi(n, 1), "speed": spd / maxi(fr.size(), 1)}
