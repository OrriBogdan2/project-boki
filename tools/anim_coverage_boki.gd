extends RefCounted
## --anim-coverage-check, the Boki rows: every species with a rigged .glb in the game (art/kin/<id>/<id>.glb, a
## BokiRig.FRAME row; the Bokidex 3D models) through the eight garden states. A cell names what the live rig plays:
## `clip` (the species' own clip, baked in its .glb), `shared` (a .glb clip with the same motion as another species':
## the generic clip set, no motion of its own), `proc` (built at runtime by BokiHomeClips from a .glb clip: the munch
## from idle, the nap from sleep) or `missing` (no clip, a clip that holds one pose, or one that never leaves the idle
## pose). Read off the Animation resources of a live rig (Shots.rigged_kin), so it sees what the game sees.
## Never touches the save.

const Shots := preload("res://tools/boki_rig_shots.gd")
const COLS := ["idle", "walk", "run", "attack", "cast", "hop", "eat", "sleep"]
## The clip the game plays for each state (BokiRig._state_clip): a cheer or leap is hop, eating at a feeder is munch
## (HomeToys._act), a garden nap is settle, nap, wake (BokiRig._lying), of which the nap is held.
const PLAYS := {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"attack": "attack",
	"cast": "ability",
	"hop": "hop",
	"eat": "munch",
	"sleep": "nap"
}
const BUILT := ["munch", "nap"]  # BokiHomeClips: built from the species' idle and sleep
const STILL_DEG := 2.0  # no bone turns more than this over the clip: it holds one pose
const NEAR_IDLE_DEG := 3.0  # every pose within this of a pose idle passes through: it shows idle
const SAMPLES := 16


## {species: [cells]} for every rigged species with a .glb, plus {"_sig": ...} kept out of the rows.
static func rows(main: Node) -> Dictionary:
	var sigs := {}  # "clip|signature" -> species with that motion
	var stats := {}  # species -> {state: [present, motion, from_idle, sig]}
	var ids: Array = BokiRig.FRAME.keys()
	ids.sort()
	for id in ids:
		if not FileAccess.file_exists(BokiRig.PATH % [id, id]):
			continue
		var k: Node3D = Shots.rigged_kin(id)
		main.add_child(k)
		await main.get_tree().process_frame
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		stats[id] = _states(rig.player)
		for s in COLS:
			var st: Array = stats[id][s]
			if st[0] and not PLAYS[s] in BUILT:
				var key := "%s|%s" % [PLAYS[s], st[3]]
				sigs[key] = sigs.get(key, 0) + 1
		k.free()
	var out := {}
	for id in stats:
		var row: Array = []
		for s in COLS:
			row.append(_cell(s, stats[id][s], sigs))
		out[id] = row
	return out


static func _cell(state: String, st: Array, sigs: Dictionary) -> String:
	if not st[0] or (state != "sleep" and float(st[1]) < STILL_DEG) or (state != "idle" and not st[2]):
		return "missing"
	if PLAYS[state] in BUILT:
		return "proc"
	return "shared" if int(sigs.get("%s|%s" % [PLAYS[state], st[3]], 0)) > 1 else "clip"


## state -> [has the clip, deg its bones turn over it, leaves the idle pose, motion signature].
static func _states(player: AnimationPlayer) -> Dictionary:
	var idle := _sample(player.get_animation("idle")) if player.has_animation("idle") else {}
	var out := {}
	for s in COLS:
		var c: String = PLAYS[s]
		if not player.has_animation(c):
			out[s] = [false, 0.0, false, ""]
			continue
		var smp := _sample(player.get_animation(c))
		out[s] = [true, _motion(smp), _off_idle(smp, idle) > NEAR_IDLE_DEG, _sig(smp)]
	return out


## bone -> [Quaternion at SAMPLES even steps over the clip], rotation tracks only.
static func _sample(a: Animation) -> Dictionary:
	var out := {}
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(i) == 0:
			continue
		var qs: Array = []
		for n in SAMPLES:
			qs.append(a.rotation_track_interpolate(i, a.length * n / float(SAMPLES)).normalized())
		out[String(a.track_get_path(i).get_concatenated_subnames())] = qs
	return out


## The largest turn (deg) of any bone away from its first key.
static func _motion(smp: Dictionary) -> float:
	var top := 0.0
	for b in smp:
		for q in smp[b]:
			top = maxf(top, rad_to_deg((q as Quaternion).angle_to(smp[b][0])))
	return top


## How far (deg) the clip gets from the idle loop: over its poses, the largest distance to the nearest idle pose
## (a pose's distance: its bone furthest from that idle pose's).
static func _off_idle(smp: Dictionary, idle: Dictionary) -> float:
	var top := 0.0
	for n in SAMPLES:
		var near := INF
		for u in SAMPLES:
			var far := 0.0
			for b in smp:
				if idle.has(b):
					far = maxf(far, rad_to_deg((smp[b][n] as Quaternion).angle_to(idle[b][u])))
			near = minf(near, far)
		top = maxf(top, near)
	return top


## The clip's motion: each bone's turn (whole deg) from its first key at every sample. A turn's size does not depend
## on the rest pose, so two species playing one shared clip over different rests sign the same.
static func _sig(smp: Dictionary) -> String:
	var bones := smp.keys()
	bones.sort()
	var s := ""
	for b in bones:
		s += b
		for q in smp[b]:
			s += ",%d" % roundi(rad_to_deg((q as Quaternion).angle_to(smp[b][0])))
	return str(s.hash())


## Species, worst first: most `missing` cells, then most `shared`, then the lowest Field Book number (met first).
static func worst(rows_v: Dictionary) -> Array:
	var ids: Array = rows_v.keys()
	ids.sort_custom(func(a, b): return _rank(rows_v[a], a) < _rank(rows_v[b], b))
	return ids


static func _rank(row: Array, id: String) -> String:
	var dex := FieldBook.number(id)
	return "%02d%02d%03d%s" % [99 - row.count("missing"), 99 - row.count("shared"), dex if dex > 0 else 999, id]


## Backlog-ready lines for the n worst species.
static func backlog(rows_v: Dictionary, n: int) -> String:
	var s := ""
	for id in worst(rows_v).slice(0, n):
		var row: Array = rows_v[id]
		var miss: Array = []
		var shared: Array = []
		for i in COLS.size():
			if row[i] == "missing":
				miss.append(COLS[i])
			elif row[i] == "shared":
				shared.append(COLS[i])
		var miss_s := ", ".join(miss) if miss else "none"
		var shared_s := ", ".join(shared) if shared else "none"
		s += (
			(
				"- [anim] Boki %s (No. %d): %d missing (%s), %d on the shared clip set (%s); author its own clips in "
				% [id, FieldBook.number(id), miss.size(), miss_s, shared.size(), shared_s]
			)
			+ "tools/boki/%s_anim.py, rebuild the .glb, rerun --anim-coverage-check\n" % id
		)
	return s
