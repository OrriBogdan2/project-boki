extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in
## the tri budget and carries every clip its file names; each keyed move of its kit has a clip as long as the move (the
## timings are the kit's); the kit's time seeks the clip; through all clips the skinned weapon stays on its bone and the
## Gun and Muzzle lie on the blade you see (item 76b); only one weapon is drawn; moves hand over with no pop; the idle
## and stance loops close with no pop and run long enough to breathe (docs/art/IDLE_AUDIT.md); every cancel the kit's
## Cancels table lists (the file's "cancels" rows) hands over with no pop and settles within a frame of the source
## footage, and a move the kit cuts leaves the hunter's state at once (no frozen pose). Never touches the save.

const TRI_BUDGET := 15000
const OWN_MODELS := {"archer": "hem", "thief": "sable", "tender": "pip", "gunslinger": "vex", "ashwick": "cinder",
	"mage": "ryzz", "dolm": "tarek", "rimewright": "claire", "dredge": "dredge", "bulwark": "breaker",
	"ostra": "ostra", "juggernaut": "kael"}
const DT := 1.0 / 30.0
const FX_ON_BLADE := 0.05      # m: the Muzzle may sit this far off the visible tip
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
const SPIKE := 1.5             # a pop is this much more than the frames either side of it: a jump, not a fast blend
const SEAM_DEG := 1.0          # a standing loop's last key may turn a bone this far from its first
const SEAM_M := 0.01           # and move it this far
const STAND_MIN := 2.0         # s: an idle or stance shorter than this reads as a jitter, not a breath
const SOURCE_FRAME := 0.2      # s: one frame of the 5 fps footage: a cancel's blend is done inside it
const LEAD := 0.5              # s: the legs run this long before a sequence's first move (past any landing)
## Standing loops docs/art/IDLE_AUDIT.md found open: "<id>:<clip>" -> what. Each idle rework removes its entries.
const STAND_OPEN := {
	"bulwark:idle": "head seam 4.2 deg (breathe() at half rate)",
	"bulwark:stance": "head seam 4.2 deg, 1.6 s long",
	"ostra:idle": "x_fing seams 11-13 deg",
	"ostra:stance": "x_fing seams 12-16 deg",
	"dolm:stance": "0.8 s long (a bounce, not a stance)",
}
## Cancels found open: "<id> <from>@<at>><to>" -> what. The hand's speed through a blend of two far-apart arm poses
## peaks mid-arc (a hammer's lever, a cartwheel cut upside down); a cut as the source does would snap the whole
## difference in one frame. Each needs an art pass (a nearer first key on the second clip) that then drops its entry.
const CANCEL_OPEN := {
	"bulwark bul_smash_wind@0.50>bul_ult_wind": "hammer from the wind-up hold to overhead, 0.64 m in a frame",
	"thief thf_vault_f@0.20>thf_encore": "cartwheel cut upside down into the Encore pose, 0.46 m in a frame",
}

var bad := 0
var holder: Node3D
var own := {}                # a clip's own hand path per frame (this Hero), the measure a hand-over is held to
var pops: Array = []         # [pop m, "hero from@t>to"] of every cancel row, worst first (--clip-shots --cancels picks)

func ok(cond: bool, what: String) -> void:
	print("CLIP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for id in OWN_MODELS:
		_own_model(String(id), String(OWN_MODELS[id]))
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)        # (one Hero, while iterating on its clips)
	var n := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if WardenClips.data(art_name).is_empty() or (only != "" and String(id) != only):
			continue
		n += 1
		await _hero(main, String(id), art_name)
	ok(n > 0, "at least one Hero has clips (%d)" % n)
	pops.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(pops.size(), 10):
		print("CLIP worst-cancel %d: %.3f m %s" % [i + 1, pops[i][0], pops[i][1]])
	await _feed_state(main)
	print("CLIP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A Hero's own .glb, wearing its clips: a bad merge of WardenGlb falls back to the procedural body in silence.
func _own_model(id: String, art_name: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	var own := WardenGlb.art(id) == art_name and WardenGlb.has_model(id) and bool(m.get_meta("glb", false))
	ok(own and sync != null and sync.get("clips") != null,
			"%s: its own %s.glb with clips, not the fallback" % [id, art_name])
	m.free()

func _hero(main: Node, id: String, art_name: String) -> void:
	var dd := WardenClips.data(art_name)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	ok(sync != null and sync.get("clips") != null, "%s: wears clips" % id)
	if sync == null or sync.get("clips") == null:
		m.free()
		return
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or not mesh is ArrayMesh:
			continue
		for si in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	ok(tris > 0 and tris <= TRI_BUDGET, "%s: %d tris, weapon included (budget %d)" % [id, tris, TRI_BUDGET])
	var missing: Array = []
	var named: Array = _named(dd)
	for c in named:
		if not clips.lib.has_animation(String(c)):
			missing.append(c)
	ok(missing.is_empty(), "%s: the file's %d clips are in the .glb (missing %s)" % [id, named.size(), str(missing)])
	_timings(id, dd, clips)
	_standing(id, dd, clips)
	# one weapon: the procedural pieces are hidden
	sync.call("_keep_one_weapon")     # (the first frame takes what the build added last: a Mag)
	var shown := 0
	var which := ""
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		# (an emptied Mag draws nothing: HunterAnim still shows it for the reload's motion)
		if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
			shown += 1
			which += " " + String(gun.get_path_to(mi))
	ok(shown == 0, "%s: one weapon drawn (%d procedural pieces showing:%s)" % [id, shown, which])
	_sliders(id, sync)
	_sway(id, m, sync, dd)
	await _on_blade(id, m, sync, clips)
	# "bone_scale" (item 137): the size holds over every clip that keys the bone
	for nm in dd.get("bone_scale", {}):
		var sk := WardenGlb.skeleton(m.get_node("Warden"))
		var want := float(dd["bone_scale"][nm])
		ok(absf(sk.get_bone_pose_scale(WardenSkeleton.find(sk, String(nm))).y - want) < 0.001,
				"%s: %s holds its size %.2f over the clips" % [id, nm, want])
	own = {}
	await _handover(id, m, sync, clips, dd)
	await _cancels(id, m, sync, clips, dd)
	m.free()

func _named(dd: Dictionary) -> Array:
	var out: Array = []
	for mv in (dd.get("kmoves", {}) as Dictionary).values():
		out.append(mv["clip"])
	var lc: Dictionary = dd.get("loco", {})
	out.append(lc.get("idle"))
	out.append(lc.get("stance"))
	out.append_array((lc.get("walk", {}) as Dictionary).values())
	out.append_array((lc.get("run", {}) as Dictionary).values())
	var cr: Dictionary = dd.get("crouch", {})
	if not cr.is_empty():
		out.append_array([cr["idle"], cr["in"], cr["out"]])
		out.append_array((cr["walk"] as Dictionary).values())
	out.append_array((dd.get("air", {}) as Dictionary).values())
	for k in dd.get("states", {}):
		var v = dd["states"][k]
		if v is String:
			out.append(v)
	return out

## A body on a spring (data "sway") lags a change of speed, leans away from it, and settles.
func _sway(id: String, m: Node3D, sync: Node, dd: Dictionary) -> void:
	var sw: WardenSway = sync.get("sway")
	if not dd.has("sway"):
		return
	ok(sw != null, "%s: sways on its spring" % id)
	if sw == null:
		return
	sw.step(DT)
	for i in 6:
		m.position.z -= 0.15 * (i + 1)
		sw.step(DT)
	var peak := sw.lean.y
	for i in 240:
		sw.step(DT)
	ok(peak > 0.03 and sw.lean.length() < 0.01, "%s: accelerating forward leans it back (%.3f rad), then settles (%.4f)"
			% [id, peak, sw.lean.length()])
	m.position = Vector3.ZERO

## Each mapped kit move: its clip lasts as long as the move's keys (a held move: at least to its last key).
## The idle and stance loops: the last key meets the first on every track (no pop at the loop), and the loop is
## long enough to carry a breath. Entries in STAND_OPEN are reported, not failed.
func _standing(id: String, dd: Dictionary, clips: WardenClips) -> void:
	for clip in ["idle", "stance"]:
		var anim_name := String(dd.get("loco", {}).get(clip, clip))
		if not clips.lib.has_animation(anim_name):
			continue
		var anim := clips.lib.get_animation(anim_name)
		var worst := 0.0
		var where := ""
		for t in anim.get_track_count():
			var n := anim.track_get_key_count(t)
			if n < 2 or anim.track_get_key_time(t, n - 1) < anim.length - 0.001:
				continue
			var gap := 0.0
			match anim.track_get_type(t):
				Animation.TYPE_ROTATION_3D:
					var q0: Quaternion = anim.track_get_key_value(t, 0)
					gap = rad_to_deg(q0.angle_to(anim.track_get_key_value(t, n - 1))) / SEAM_DEG
				Animation.TYPE_POSITION_3D:
					var p0: Vector3 = anim.track_get_key_value(t, 0)
					gap = p0.distance_to(anim.track_get_key_value(t, n - 1)) / SEAM_M
			if gap > worst:
				worst = gap
				where = String(anim.track_get_path(t)).get_slice(":", 1)
		var good := worst <= 1.0 and anim.length >= STAND_MIN
		var what := "%s: %s loop seam %.1fx the limit (worst %s), %.1f s long (min %.1f)" % [
				id, clip, worst, where if where != "" else "none", anim.length, STAND_MIN]
		var key := "%s:%s" % [id, clip]
		if STAND_OPEN.has(key):
			var stale := " (now passes: drop it from STAND_OPEN)" if good else ""
			print("CLIP open %s [%s]%s" % [what, STAND_OPEN[key], stale])
			ok(not good, "%s: STAND_OPEN entry still needed" % key)
		else:
			ok(good, what)

func _timings(id: String, dd: Dictionary, clips: WardenClips) -> void:
	var worst := 0.0
	var where := ""
	var moves: Dictionary = dd.get("kmoves", {})
	for km in moves:
		var def := HunterAnim.km_def(String(km))
		if def.is_empty():
			continue
		var end_t := float(def["keys"][-1][0])
		var length := clips.lib.get_animation(String(moves[km]["clip"])).length
		var off := maxf(end_t - length, 0.0) if moves[km].has("hold_from") else absf(length - end_t)
		if off > worst:
			worst = off
			where = "%s, clip %.3f s, keys %.3f s" % [km, length, end_t]
	ok(worst <= 0.034, "%s: every clip lasts as long as its kit move (worst %.3f s, %s)" % [id, worst, where])
	var unmapped: Array = []
	var pre: String = {"juggernaut": "jug_"}.get(id, "")
	for km in KMovesDJ.MOVES:
		if pre != "" and String(km).begins_with(pre) and not moves.has(km):
			unmapped.append(km)
	ok(unmapped.is_empty(), "%s: all its kit moves have a clip (missing %s)" % [id, str(unmapped)])

## Through every clip the Gun and Muzzle follow the blade, and the blade keeps its length on the hand.
func _on_blade(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var tip := sync.get("blade_tip") as Node3D
	var muzzle := sync.get("muzzle") as Node3D
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hb := int(sync.get("blade_bone"))
	var rest := tip.position.length()
	var far := 0.0
	var drift := 0.0
	var n := 0
	for nm in clips.lib.get_animation_list():
		var length := clips.lib.get_animation(nm).length
		for i in 4:
			clips.force = {"clip": String(nm), "t": length * (i + 0.5) / 4.0}
			for k in 3:
				sync.call("_process", DT)
			await holder.get_tree().process_frame
			var sees: Vector3 = sk.global_transform * (sk.get_bone_global_pose(hb) * tip.position)
			far = maxf(far, muzzle.global_position.distance_to(sees))
			var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
			# (a weapon that grows and shrinks on its bone, Motley's orb, keeps its point)
			var body_k := absf((sk.global_transform.basis * sk.get_bone_global_pose(hb).basis).get_scale().x)
			drift = maxf(drift, absf(hand.distance_to(sees) / body_k - rest))
			n += 1
	clips.force = {}
	ok(far <= FX_ON_BLADE, "%s: the Muzzle stays on the visible tip in %d frames (worst %.3f m)" % [id, n, far])
	ok(drift <= 0.02, "%s: the blade never leaves the hand (worst drift %.3f m)" % [id, drift])

## The clips keep rotations only on the contract bones, so MantleLook's sliders (bone offsets) stay on under them; and
## the death state has its time on screen.
func _sliders(id: String, sync: Node) -> void:
	var clips: WardenClips = sync.get("clips")
	var strays := 0
	var sk := clips.skel
	var offsets: Array = clips.d.get("offset_bones", [])      # (Motley's hips ride the spring: the clips move them)
	var names: Array = []
	for b in WardenGlb.BONES:
		if b != "root" and WardenSkeleton.find(sk, b) >= 0:
			names.append(sk.get_bone_name(WardenSkeleton.find(sk, b)))
	for nm in clips.lib.get_animation_list():
		var a := clips.lib.get_animation(nm)
		for i in a.get_track_count():
			var bn := String(a.track_get_path(i).get_concatenated_subnames())
			if a.track_get_type(i) != Animation.TYPE_ROTATION_3D and bn in names and not bn in offsets:
				strays += 1
	ok(strays == 0, "%s: no clip keys a contract bone's offset (%d tracks), the sliders stay on" % [id, strays])
	ok((sync.get("look_pose") as Array).size() >= 10, "%s: the look's bone offsets are held under the clips" % id)
	var stays := float(sync.get("root").get_meta(WardenClips.DEATH_T, 0.0))
	ok(not (clips.d.get("states", {}) as Dictionary).has("dead") or stays > 0.0,
			"%s: a knocked-out Hero stays on screen for its death clip" % id)

## The anim state a sequence step asks for: a kit move at `t` s, "" the legs, "stun", "glide". A move or a stun out of
## the glider closes it and plays in the fall (the source casts from the air); the legs are the ground.
static func feed(s: Dictionary, st: String, t: float) -> void:
	s.erase("kmove")
	s["stun"] = st == "stun"
	s["gliding"] = st == "glide"
	if st == "glide" or st == "":
		s["grounded"] = st == ""
	if st != "" and st != "stun" and st != "glide":
		s["kmove"] = st
		s["kmove_t"] = t

## A "cancels" row [from, cut at s, to] as a sequence: the legs, the move to its cut, then what cuts it.
static func cancel_seq(row: Array) -> Array:
	return [["", LEAD], [String(row[0]), float(row[1])], [String(row[2]), 2.0 * SOURCE_FRAME]]

## The clip a sequence step shows, "" when it is the legs or the glider.
static func clip_of(dd: Dictionary, st: String) -> String:
	if st == "stun":
		return String(dd.get("states", {}).get("stun", ""))
	var moves: Dictionary = dd.get("kmoves", {})
	return String(moves[st]["clip"]) if moves.has(st) else ""

## The kit's own flow (data "flow") handed over as the game does: no pop, then the clips own the body.
func _handover(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var seq: Array = [["", 0.4]]
	seq.append_array(dd.get("flow", []))
	seq.append(["", 0.4])
	var r := await _run_seq(m, sync, clips, dd, seq)
	var height := 1.6 * absf(m.scale.y)
	ok(float(r[0]) <= POP * height,
			"%s: moves hand over without a pop (worst %.3f m over the clip's own, %s; limit %.3f)"
			% [id, r[0], r[1], POP * height])
	ok(clips.proc_w <= 0.0, "%s: the clips own the body after the run" % id)
	var s: Dictionary = m.get_meta(WardenClips.STATE)
	s["kmove"] = "no_such_move"
	for k in 12:
		sync.call("_process", DT)
	ok(clips.proc_w >= 1.0, "%s: a move with no clip hands back to the rig" % id)

## Every cancel of the kit's Cancels table (data "cancels": [from, cut at s, to]): the cut move hands over with no pop,
## and the next state owns the body within one frame of the source footage: nothing held, nothing half-faded.
func _cancels(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var rows: Array = dd.get("cancels", [])
	if rows.is_empty():
		return
	var height := 1.6 * absf(m.scale.y)
	var worst := 0.0
	var where := ""
	var late: Array = []
	for row in rows:
		var r := await _run_seq(m, sync, clips, dd, cancel_seq(row), 2)
		var what := "%s %s@%.2f>%s" % [id, row[0], row[1], row[2] if row[2] != "" else "legs"]
		pops.append([float(r[0]), what])
		print("CLIP pop %.3f m %s (%s)" % [r[0], what, r[1]])
		if CANCEL_OPEN.has(what):
			var stale := " (now passes: drop it from CANCEL_OPEN)" if float(r[0]) <= POP * height else ""
			print("CLIP open %s %.3f m [%s]%s" % [what, r[0], CANCEL_OPEN[what], stale])
			ok(float(r[0]) > POP * height, "%s: CANCEL_OPEN entry still needed" % what)
		elif float(r[0]) > worst:
			worst = float(r[0])
			where = what
		if not bool(r[2]):
			late.append(what)
	ok(worst <= POP * height,
			"%s: %d cancels hand over without a pop (worst %.3f m over the clip's own, %s; limit %.3f)"
			% [id, rows.size(), worst, where, POP * height])
	ok(late.is_empty(), "%s: every cancel's blend is done within %.1f s of the cut (late: %s)"
			% [id, SOURCE_FRAME, str(late)])

## True when the layers show `st` alone: the legs (or the glider) with no action left, or the move at full weight.
func _settled(clips: WardenClips, dd: Dictionary, st: String) -> bool:
	if st == "" or st == "glide":
		var off := clips.act_w <= 0.001 and clips.up_w <= 0.001
		return off and (st == "" or clips.glide_w >= 0.999 and clips.air_w >= 0.999)
	var mv: Dictionary = dd.get("kmoves", {}).get(st, {})
	var layer: WardenClips.Layer = clips.up if mv.get("upper", false) else clips.act   # (the run: "moving" is upper)
	var w := clips.up_w if layer == clips.up else clips.act_w
	var clips_of: Array = [clip_of(dd, st), mv.get("alt", "")]
	return w >= 0.999 and absf(layer.xf - layer.chan) < 0.001 and layer.cur in clips_of

## A sequence [[state, s], ...] fed frame by frame as the game does: [worst pop m, where (with the frames either side),
## settled]. A strike is meant
## to snap, so a pop is the hand moving further in a frame than the clip alone moves it there (the clip's own path,
## sampled once) and further than in the frames either side (SPIKE): a jump, where a fast blend carries on. Pops
## count from step `judge` on (a cancel: the cut itself; the move's own start and loop are the flow's business).
## Settled: each step's state after the lead-in owns the body SOURCE_FRAME after it begins.
func _run_seq(m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary, seq: Array, judge := 1) -> Array:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	for st in seq:
		var clip := clip_of(dd, String(st[0]))
		if clip == "" or own.has(clip):
			continue
		clips.force = {"clip": clip, "t": 0.0}
		for k in 10:
			sync.call("_process", DT)
		await holder.get_tree().process_frame
		var path: Array = []
		var t := 0.0
		var last_p := hand.global_position
		while t < float(st[1]):
			clips.force = {"clip": clip, "t": minf(t, clips.lib.get_animation(clip).length - 0.001)}
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			path.append(hand.global_position.distance_to(last_p))
			last_p = hand.global_position
			t += DT
		own[clip] = path
	clips.force = {}
	var s := {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var last := Vector3.INF
	var overs: Array = []       # per frame: how far past the clip's own step the hand moved (0: not measured)
	var at: Array = []
	var settled := true
	for k in seq.size():
		var st: Array = seq[k]
		var clip := clip_of(dd, String(st[0]))
		var t := 0.0
		var i := 0
		var judged: bool = k == 0
		while t < float(st[1]):
			feed(s, String(st[0]), t)
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			t += DT
			i += 1
			if not judged and t >= SOURCE_FRAME - 0.0001:
				judged = true
				settled = settled and _settled(clips, dd, String(st[0]))
			var p := hand.global_position
			var over := 0.0
			# (to the clip's end only: past it the move fades to the legs, the clip's own path can't say how far)
			if last != Vector3.INF and clips.proc_w <= 0.0 and own.has(clip) and i <= (own[clip] as Array).size() \
					and t <= clips.lib.get_animation(clip).length and k >= judge:
				var path: Array = own[clip]
				var clip_step := 0.0
				for j in range(maxi(i - 3, 0), mini(i + 2, path.size())):      # (a frame or two either way: the fade)
					clip_step = maxf(clip_step, float(path[j]))
				over = maxf(p.distance_to(last) - clip_step, 0.0)
			overs.append(over)
			at.append("%s @%.2f" % [st[0], t])
			last = p
	var worst := 0.0
	var where := ""
	for i in overs.size():
		var before := float(overs[i - 1]) if i > 0 else 0.0
		var after := float(overs[i + 1]) if i + 1 < overs.size() else 0.0
		if float(overs[i]) > worst and float(overs[i]) > SPIKE * maxf(before, after):
			worst = float(overs[i])
			where = "%s, %.3f before, %.3f after" % [at[i], before, after]
	return [worst, where, settled]

## The hunter's own feed: a kit move the kit cuts (its anim_id emptied) leaves the state the same frame, so no clip
## freezes on its cut frame (DECISIONS 2026-11-07: a hold animation never shows without the hold input).
func _feed_state(main: Node) -> void:
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("bulwark", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	P.ak.play("bul_guard")
	P._anim_state(1.0)
	var shown := String(P.anim_s.get("kmove", "")) == "bul_guard"
	P.ak.anim_id = ""
	P._anim_state(1.0)
	ok(shown and not P.anim_s.has("kmove"),
			"a kit move the kit cuts leaves the hunter's anim state at once (shown %s, left %s)"
			% [shown, P.anim_s.has("kmove")])
	await ac.done(m)
