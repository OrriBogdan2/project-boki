extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in
## the tri budget and carries every clip its file names; each keyed move of its kit has a clip as long as the move (the
## timings are the kit's); the kit's time seeks the clip; through all clips the skinned weapon stays on its bone and the
## Gun and Muzzle lie on the blade you see (item 76b); only one weapon is drawn; moves hand over with no pop; the idle
## and stance loops close with no pop and run long enough to breathe (docs/art/IDLE_AUDIT.md); each walk and run ring's
## loops are one length, so the blended diagonals stay in step; a move whose strike snaps inside the blend-in is at full
## weight on its key; each emote of the wheel has its own clip (a gesture or a .glb clip) that ends within the bubble
## and plays on the right layer; each strike's weapon tip or fist lands on the kit's hit area
## (tools/strike_reach_check.gd). Never touches the save.

const PondWalk := preload("res://tools/pond_walk.gd")
const StrikeReach := preload("res://tools/strike_reach_check.gd")
const TRI_BUDGET := 15000
const OWN_MODELS := {"archer": "hem", "thief": "sable", "tender": "pip", "gunslinger": "vex", "ashwick": "cinder",
	"mage": "ryzz", "dolm": "tarek", "rimewright": "claire", "dredge": "dredge", "bulwark": "breaker",
	"ostra": "ostra", "juggernaut": "kael"}
const DT := 1.0 / 30.0
const FLINCH_LEGS_M := 0.002   # m: a chip hit on the run may move the legs this far off the unhit run
const FLINCH_ARMS_M := 0.01    # m: and must move the hand at least this far (the flinch shows)
const FX_ON_BLADE := 0.05      # m: the Muzzle may sit this far off the visible tip
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
const SEAM_DEG := 1.0          # a standing loop's last key may turn a bone this far from its first
const SEAM_M := 0.01           # and move it this far
const SNAP_MPS := 8.0          # m/s: an arm bone this fast at a clip's start is a strike or release snapping in
const FRAME := 1.0 / 60.0      # s: the game frame the kit clock steps by
const RING_DT := 1.0 / 60.0   # s: a ring's loops may differ this much in length (the BlendSpace2D runs them unsynced)
const POSE_MIN_DEG := 25       # a keyed result pose turns at least one bone this far from the rest
const ROOT_FOOT_M := 0.02      # m: a rooted Hunter's feet move this much more than the idle's own sway through any move
const STAND_MIN := 2.0         # s: an idle or stance shorter than this reads as a jitter, not a breath
const JL_READ_DEG := 15.0      # deg: a take-off or an apex turns some bone at least this far (it reads on screen)
const JL_AGAIN_DEG := 3.0      # deg: the second jump's rise pose may differ from the first by this much
const JL_HOP_DIP_M := 0.015    # m: the hips drop at least this far off a plain jump (the source's small dip)
const JL_DIP_M := 0.03         # m: and at least this far off a terrace drop or a glide's end, the deep crouch...
const JL_DEEPER := 1.25        # ...which is this many times the hop's dip, same stance
const JL_FREE_S := 0.0         # s: running, the land clip never owns the legs: its absorb rides the run on the upper
                               # layer and the legs are the run's from the first frame (the landing never holds the run)
const JL_BACK_MAX := 0.6       # s: the longest a landing may own the body standing (dur 0.4 + the loco fade)
## Standing loops docs/art/IDLE_AUDIT.md found open: "<id>:<clip>" -> what. Each idle rework removes its entries.
const STAND_OPEN := {
	"bulwark:idle": "head seam 4.2 deg (breathe() at half rate)",
	"bulwark:stance": "head seam 4.2 deg, 1.6 s long",
	"ostra:idle": "x_fing seams 11-13 deg",
	"ostra:stance": "x_fing seams 12-16 deg",
}

var bad := 0
var holder: Node3D

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
	var n := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if not WardenClips.data(art_name).has("loco"):      # (no clips yet, as Gil: the rig's poses drive it)
			continue
		n += 1
		await _hero(main, String(id), art_name)
	ok(n > 0, "at least one Hero has clips (%d)" % n)
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
	_jump_land(id, m, sync, clips, dd)
	_emotes(id, dd, clips)
	_rings(id, dd, clips)
	_beats(id, dd, clips)
	_summon_call(id, dd, clips)
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
	await _rooted(id, m, sync, clips, dd)
	await _handover(id, m, sync, clips, dd)
	_snaps(id, m, clips, dd)
	await _carry(id, m, sync, clips, dd)
	await _pond(id, m, sync, clips)
	_recoil(id, m, sync, clips, dd)
	var reach := StrikeReach.new()
	await reach.hero(id, m, sync, dd, holder.get_tree())
	bad += reach.bad
	m.free()
	await _flinch(id)

## The result beats (WardenBeats): win, lose and board each map to a clip the .glb plays that is its own (no two beats
## share one), the state's "beat" picks it, and a keyed pose really moves the arms and head off the rest.
func _beats(id: String, dd: Dictionary, clips: WardenClips) -> void:
	var mapped := 0
	var picked := 0
	var used: Array = []
	for nm in WardenBeats.NAMES:
		var b: Dictionary = clips.beats.get(nm, {})
		mapped += 1 if not b.is_empty() else 0
		var pick := clips._pick({"beat": nm, "beat_t": 0.7}, 0.0)
		picked += 1 if not b.is_empty() and pick.get("clip", "") == b["clip"] else 0
		if not b.is_empty():
			used.append(b["clip"])
	var own: bool = used.size() == 3 and used[0] != used[1] and used[1] != used[2] and used[0] != used[2]
	ok(mapped == 3 and picked == 3 and own,
			"%s: win, lose, board mapped to own clips (%d, %d picked: %s)" % [id, mapped, picked, str(used)])
	for nm in dd.get("beats", {}):
		if not dd["beats"][nm].has("pose") or not clips.lib.has_animation("beat_" + String(nm)):
			continue
		var a := clips.lib.get_animation("beat_" + String(nm))
		var most := 0.0
		for i in a.get_track_count():
			var rest := a.rotation_track_interpolate(i, 0.0)
			most = maxf(most, rad_to_deg(rest.angle_to(a.rotation_track_interpolate(i, WardenBeats.INTRO))))
		ok(most >= POSE_MIN_DEG, "%s: the %s pose turns a bone %.0f deg (min %d)" % [id, nm, most, POSE_MIN_DEG])

func _named(dd: Dictionary) -> Array:
	var out: Array = []
	for b in (dd.get("beats", {}) as Dictionary).values():
		if b.has("clip"):
			out.append(b["clip"])
	for mv in (dd.get("kmoves", {}) as Dictionary).values():
		for k in ["clip", "air_clip", "ground_clip"]:
			if mv.has(k):
				out.append(mv[k])
	var lc: Dictionary = dd.get("loco", {})
	out.append(lc.get("idle"))
	out.append(lc.get("stance"))
	out.append_array((lc.get("walk", {}) as Dictionary).values())
	out.append_array((lc.get("run", {}) as Dictionary).values())
	var cr: Dictionary = dd.get("crouch", {})
	if not cr.is_empty():
		out.append_array([cr["idle"], cr["in"], cr["out"]])
		out.append_array((cr["walk"] as Dictionary).values())
	out.append_array((dd.get("act", {}) as Dictionary).values())
	out.append_array((dd.get("emotes", {}) as Dictionary).values())
	var air: Array = (dd.get("air", {}) as Dictionary).values()
	out.append_array(air.filter(func(v): return v is String))     # (not its tilts)
	if dd.has("mantle"):
		out.append(dd["mantle"]["clip"])
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

## The ways down, running and standing (tools/jump_land_check.gd), printed as "JL" rows. The jump: the take-off and
## the apex read (the pose turns), every jump reads like the first (the rise clip starts over). Every way: the landing
## dips at once (the hop a little, the drop and the glide's end deeper: HunterAnim.land_tier; Motley's hips ride his
## spring: no dip to read), a kerb plays no landing, running the legs never leave the run, and the body is back
## within the data's promise: "moving" (or "dur") plus the loco fade, never longer than JL_BACK_MAX.
func _jump_land(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var jl := preload("res://tools/jump_land_check.gd")
	var ld: Dictionary = dd.get("land", {})
	for running: bool in [true, false]:
		var hop_dip := 0.0
		for way: String in ["jump", "drop", "glide", "kerb"]:
			var r: Dictionary = jl.measure(m, sync, clips, running, way)
			var tag := "%s %s" % [way, "run" if running else "still"]
			print("JL %s %s off=%.1f again=%.1f apex=%.1f dip=%.3f dip_t=%.2f legs=%.2f back=%.2f held=%.2f settle=%.2f"
					% [id, tag, r["off"], r["again"], r["apex"], r["dip"], r["dip_t"], r["legs"], r["back"], r["held"],
					r["settle"]])
			if way == "jump":
				ok(r["off"] >= JL_READ_DEG and r["apex"] >= JL_READ_DEG,
						"%s %s: take-off (%.0f deg) and apex (%.0f deg) read" % [id, tag, r["off"], r["apex"]])
				ok(r["again"] <= JL_AGAIN_DEG, "%s %s: the next jump takes off like the first (%.1f deg off)"
						% [id, tag, r["again"]])
				hop_dip = -r["dip"]
			if way == "kerb":
				ok(r["held"] <= 0.0, "%s %s: a step down plays no landing (clip weight %.2f)" % [id, tag, r["held"]])
				continue
			if not dd.has("sway"):
				var deep := way != "jump"
				var need := maxf(JL_DIP_M, hop_dip * JL_DEEPER) if deep else JL_HOP_DIP_M
				ok(r["dip"] <= -need and r["dip_t"] <= jl.DIP_WINDOW,
						"%s %s: the landing dips %.3f m (%s, at least %.3f), lowest at %.2f s"
						% [id, tag, -r["dip"], "the deep crouch" if deep else "the hop's dip", need, r["dip_t"]])
			var tier: Dictionary = ld.get("drop" if way != "jump" else "hop", {})
			var hold := float(tier.get("moving", tier.get("dur", 0.0))) if running else float(tier.get("dur", 0.0))
			var promise := hold + WardenClips.FADE_LOCO + jl.DT
			ok(r["back"] > 0.0 and r["back"] <= minf(promise, JL_BACK_MAX),
					"%s %s: the body is back %.2f s after touchdown (data %.2f, max %.2f)"
					% [id, tag, r["back"], promise, JL_BACK_MAX])
			if running:
				ok(r["legs"] <= JL_FREE_S, "%s %s: the legs are the run's again by %.2f s (max %.2f), no hold"
						% [id, tag, r["legs"], JL_FREE_S])

## The emote wheel (Truce.EMOTES): every emote names a different clip of this Hunter that ends before its bubble does.
## A "g_" gesture keys only bones of the data's "upper" list and always plays on the upper layer; a .glb clip does when
## he moves and owns the body when he stands. Once the clip has ended nothing of it plays.
func _emotes(id: String, dd: Dictionary, clips: WardenClips) -> void:
	var map: Dictionary = dd.get("emotes", {})
	var seen := {}
	var bad: Array = []
	for e in Truce.EMOTES:
		var clip := String(map.get(e["id"], ""))
		if not clips.lib.has_animation(clip) or clips.lib.get_animation(clip).length > Truce.BUBBLE_T:
			bad.append(e["id"])
		seen[clip] = true
	var n := Truce.EMOTES.size()
	ok(bad.is_empty() and seen.size() == n, "%s: %d wheel emotes, %d clips, within %.1f s (bad %s)"
			% [id, n, seen.size(), Truce.BUBBLE_T, str(bad)])
	var wrong: Array = []
	for e in Truce.EMOTES:
		var clip := String(map.get(e["id"], ""))
		var anim := clips.lib.get_animation(clip)
		var upper := not clip.begins_with(WardenGestures.PREFIX) or _keys_upper(anim, dd)
		if not _emote_plays(clips, String(e["id"]), clip) or not upper:
			wrong.append(e["id"])
	ok(wrong.is_empty(), "%s: emotes play upper-body moving, full-body standing, then end (wrong %s)"
			% [id, str(wrong)])

## The state's emote picks this clip: standing on its own layer, moving on the upper one, and not after its end.
func _emote_plays(clips: WardenClips, emote: String, clip: String) -> bool:
	var s := {"emote": emote, "emote_t": 0.3, "vel": Vector3.ZERO}
	var gesture := clip.begins_with(WardenGestures.PREFIX)
	var still := clips._pick(s, 0.0)
	s["vel"] = Vector3(0, 0, -4)
	var moving := clips._pick(s, 0.0)
	s["emote_t"] = clips.lib.get_animation(clip).length + 0.01
	return still.get("clip", "") == clip and bool(still.get("upper", false)) == gesture \
			and bool(moving.get("upper", false)) and clips._pick(s, 0.0).get("clip", "") != clip

## The summon call (warden_anim "summon_call"): a gesture of about 0.3 s on the upper layer, so he runs and aims under
## it; a kit move owns the arms, so it never plays over one; once it has ended nothing of it plays.
func _summon_call(id: String, dd: Dictionary, clips: WardenClips) -> void:
	var clip := String(dd.get("summon_call", ""))
	var anim := clips.lib.get_animation(clip) if clips.lib.has_animation(clip) else null
	ok(anim != null and absf(anim.length - 0.3) < 0.05 and _keys_upper(anim, dd),
			"%s: summon call %s is ~0.3 s, upper bones only" % [id, clip])
	if anim == null:
		return
	var s := {"call_t": 0.1, "vel": Vector3(0, 0, -4)}
	var run := clips._pick(s, 0.0)
	s["kmove"] = String(dd.get("kmoves", {}).keys()[0])
	var cast := clips._pick(s, 0.0)
	s.erase("kmove")
	s["call_t"] = anim.length + 0.01
	var over: bool = run.get("clip", "") == clip and bool(run.get("upper", false)) and cast.get("clip", "") != clip
	ok(over and clips._pick(s, 0.0).get("clip", "") != clip,
			"%s: the call plays on the upper layer, not over a cast, then ends" % id)

## A gesture (it keys only a few bones) moves nothing outside the upper layer's bones.
func _keys_upper(anim: Animation, dd: Dictionary) -> bool:
	for t in anim.get_track_count():
		if anim.track_get_path(t).get_concatenated_subnames() not in dd.get("upper", []):
			return false
	return true
## A walk or run ring: the back and side loops last as long as the forward one, or a diagonal's two feet drift apart.
func _rings(id: String, dd: Dictionary, clips: WardenClips) -> void:
	for gait in ["walk", "run"]:
		var ring: Dictionary = dd.get("loco", {}).get(gait, {})
		if not ring.has("f") or not clips.lib.has_animation(String(ring["f"])):
			continue
		var f_len := clips.lib.get_animation(String(ring["f"])).length
		var off := ""
		for k in ring:
			var clip := String(ring[k])
			var k_len := clips.lib.get_animation(clip).length if clips.lib.has_animation(clip) else f_len
			if absf(k_len - f_len) > RING_DT:
				off += " %s %.3f" % [k, k_len]
		var what := off if off != "" else " all match"
		ok(off == "", "%s: the %s loops are one length (f %.3f s;%s)" % [id, gait, f_len, what])

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
	var act_off := 0.0
	for verb in dd.get("act", {}):
		var pick := clips._pick({"act": verb, "act_t": 0.4}, 0.0)
		var clip := String(dd["act"][verb])
		ok(pick.get("clip") == clip and is_equal_approx(float(pick.get("t", -1.0)), 0.4),
				"%s: the home %s plays its own clip, seeked to the verb's clock" % [id, verb])
		act_off = maxf(act_off, absf(clips.lib.get_animation(clip).length - float(HunterVerbs.LENGTH[verb])))
	ok(act_off <= 0.034, "%s: its garden clips last as long as the home verbs (off %.3f s)" % [id, act_off])
	var unmapped: Array = []
	var pre: String = {"juggernaut": "jug_"}.get(id, "")
	for km in KMovesDJ.MOVES:
		if pre != "" and String(km).begins_with(pre) and not moves.has(km):
			unmapped.append(km)
	ok(unmapped.is_empty(), "%s: all its kit moves have a clip (missing %s)" % [id, str(unmapped)])
	# the shared actions: a stomp clip is the game's cycle with the slam at Life's hit beat, a drink clip is the drink
	var st: Dictionary = dd.get("states", {})
	for k in ["stomp", "drink"]:
		if not st.has(k):
			continue
		var want := float(Life.R["stomp_cycle"]) if k == "stomp" else UtilityUse.channel("tonic", "time")
		var dur := clips.lib.get_animation(String(st[k])).length
		ok(absf(dur - want) <= 0.034, "%s: its %s clip lasts the game's %.2f s" % [id, k, want])

## Through every clip the Gun and Muzzle follow the blade, and the blade keeps its length on the hand. A blade tip
## that a floating companion carries (Meeko's sun circles her, off its bone) keeps its place on that companion instead.
func _on_blade(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var tip := sync.get("blade_tip") as Node3D
	var muzzle := sync.get("muzzle") as Node3D
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hb := int(sync.get("blade_bone"))
	var rest := tip.position.length()
	var carrier: WardenCompanions.Part = null
	var floating := sync.get("companions") as WardenCompanions
	for part: WardenCompanions.Part in (floating.parts if floating else []):
		for an in part.anchors:
			if an[0] == tip:
				carrier = part
				rest = (an[1] as Vector3).length()
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
			if carrier:
				hand = carrier.node.global_position
				body_k = absf(sk.global_transform.basis.get_scale().x)
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

## Rooted (a foe's Root, the state's "rooted"), the legs stay planted while the body casts: through every kit move the
## feet move under ROOT_FOOT_M over the idle's sway, though the velocity says he runs (Rimelock's statue is frozen).
func _rooted(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var feet: Array = []
	for nm in ["shin.L", "shin.R"]:
		var kids := sk.get_bone_children(WardenSkeleton.find(sk, nm))
		feet.append(kids[0] if not kids.is_empty() else WardenSkeleton.find(sk, nm))
	var s := {"vel": Vector3(0, 0, -3.0), "face": 0.0, "grounded": true, "rooted": true}
	m.set_meta(WardenClips.STATE, s)
	for k in 12:
		sync.call("_process", DT)
	await holder.get_tree().process_frame
	clips.still_t = 0.0
	clips.stance_w = 0.0
	for k in 20:
		sync.call("_process", DT)
	await holder.get_tree().process_frame
	var rest: Array = []
	for b in feet:
		rest.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
	var moves: Dictionary = dd.get("kmoves", {})
	var worst := 0.0
	var where := ""
	var sway := 0.0      # (the idle's own weight shift moves a heavy Hero's feet; a cast adds to it)
	for k in 45:
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		sway = maxf(sway, _foot_dist(sk, feet, rest))
	for km in moves:
		if (dd.get("still", []) as Array).has(moves[km]["clip"]):
			continue
		var length := minf(clips.lib.get_animation(String(moves[km]["clip"])).length, 1.5)
		var t := 0.0
		clips.still_t = 0.0      # (the standing stance after 6 s still is its own pose, not the cast's)
		while t < length:
			s["kmove"] = km
			s["kmove_t"] = t
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			var d := _foot_dist(sk, feet, rest)
			if d > worst:
				worst = d
				where = "%s @%.2f" % [km, t]
			t += DT
	s.erase("kmove")
	m.set_meta(WardenClips.STATE, {})
	ok(worst <= sway + ROOT_FOOT_M, "%s: rooted, feet planted over every move (worst %.3f, %s; idle %.3f)"
			% [id, worst, where, sway])

## How far the furthest-moved foot has gone from where it stood.
func _foot_dist(sk: Skeleton3D, feet: Array, rest: Array) -> float:
	var far := 0.0
	for i in feet.size():
		far = maxf(far, (sk.global_transform * sk.get_bone_global_pose(feet[i]).origin).distance_to(rest[i]))
	return far

## Moves handed over as the game does, the state fed frame by frame. A strike is meant to snap, so a pop is the hand
## moving further in a frame than the clip alone moves it there: that excess stays small against the Hero's height.
func _handover(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var moves: Dictionary = dd.get("kmoves", {})
	var seq: Array = [["", 0.4]]
	seq.append_array(dd.get("flow", []))
	seq.append(["", 0.4])
	var own := {}
	for st in seq:
		if st[0] == "" or own.has(st[0]):
			continue
		var clip := String(moves[st[0]]["clip"])
		var lead := float(moves[st[0]].get("lead", 0.0))      # (the game seeks kmove_t + lead, floored at 0)
		var rate := float(moves[st[0]].get("rate", 1.0))      # (and plays "rate" clip s per kit s)
		clips.force = {"clip": clip, "t": 0.0}
		for k in 10:
			sync.call("_process", DT)
		await holder.get_tree().process_frame
		var path: Array = []
		var t := 0.0
		var last_p := hand.global_position
		while t < float(st[1]):
			var ct := clampf(t * rate + lead, 0.0, clips.lib.get_animation(clip).length - 0.001)
			clips.force = {"clip": clip, "t": ct}
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			path.append(hand.global_position.distance_to(last_p))
			last_p = hand.global_position
			t += DT
		own[st[0]] = path
	clips.force = {}
	var s := {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var last := Vector3.INF
	var worst := 0.0
	var where := ""
	for st in seq:
		var t := 0.0
		var i := 0
		while t < float(st[1]):
			s["kmove"] = st[0]
			s["kmove_t"] = t
			# (a move that turns its side to the way he goes is fed that facing)
			s["face"] = float(moves.get(st[0], {}).get("heading_off", 0.0))
			if st[0] == "":
				s.erase("kmove")
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			var p := hand.global_position
			if last != Vector3.INF and clips.proc_w <= 0.0 and own.has(st[0]):
				var path: Array = own[st[0]]
				var clip_step := 0.0
				for j in range(maxi(i - 2, 0), mini(i + 3, path.size())):      # (a frame or two either way: the fade)
					clip_step = maxf(clip_step, float(path[j]))
				var over := p.distance_to(last) - clip_step
				if over > worst:
					worst = over
					where = "%s @%.2f" % [st[0], t]
			last = p
			t += DT
			i += 1
	var height := 1.6 * absf(m.scale.y)
	ok(worst <= POP * height, "%s: moves hand over without a pop (worst %.3f m over the clip's own, %s; limit %.3f)"
			% [id, worst, where, POP * height])
	ok(clips.proc_w <= 0.0, "%s: the clips own the body after the run" % id)
	s["kmove"] = "no_such_move"
	for k in 12:
		sync.call("_process", DT)
	ok(clips.proc_w >= 1.0, "%s: a move with no clip hands back to the rig" % id)

## "recoil": a shot kicks the arms by the file's degrees and settles in its time; sustained fire stays under the cap;
## the legs and the shot's own state do not move. The clip is held still so only the kick can move a bone.
func _recoil(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	if not dd.has("recoil"):
		return
	var deg := float(dd["recoil"]["deg"])
	var settle := float(dd["recoil"]["settle"])
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var arm := WardenSkeleton.find(sk, "upper_arm.R")
	var leg := WardenSkeleton.find(sk, "thigh.R")
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "fired": 99.0}
	m.set_meta(WardenClips.STATE, s)
	clips.force = {"clip": String(dd["loco"]["idle"]), "t": 0.0}
	for k in 12:
		sync.call("_process", DT)
	var arm0 := sk.get_bone_pose_rotation(arm)
	var leg0 := sk.get_bone_pose_rotation(leg)
	s["fired"] = 0.0
	sync.call("_process", DT)
	var kick := rad_to_deg(arm0.angle_to(sk.get_bone_pose_rotation(arm)))
	ok(kick >= deg * 0.6 and kick <= deg * 1.05, "%s: a shot kicks the arm %.2f deg (file %.1f)" % [id, kick, deg])
	ok(rad_to_deg(leg0.angle_to(sk.get_bone_pose_rotation(leg))) < 0.01, "%s: the legs do not kick" % id)
	var peak := kick
	for i in 8:       # (a burst: a shot every 0.12 s)
		s["fired"] = 0.0
		for k in 4:
			sync.call("_process", 0.03)
			peak = maxf(peak, rad_to_deg(arm0.angle_to(sk.get_bone_pose_rotation(arm))))
			s["fired"] = 0.03 * (k + 1)
	ok(peak <= deg * 1.5 + 0.2, "%s: sustained fire peaks %.2f deg (cap %.1f)" % [id, peak, deg * 1.5])
	var t := 0.0
	while t < settle * 1.5 + 0.3:
		s["fired"] = 0.5 + t
		sync.call("_process", DT)
		t += DT
	var rest := rad_to_deg(arm0.angle_to(sk.get_bone_pose_rotation(arm)))
	ok(rest < deg * 0.1, "%s: the kick settles (%.3f deg left)" % [id, rest])
	clips.force = {}

## A hit mid-run (item: additive flinch): the legs run exactly as they would unhit, the spine and arms flinch on top;
## standing still, or a stagger, takes the whole body. Two identical models run the same 1 s, one of them hit.
func _flinch(id: String) -> void:
	var calm := await _run_hit(id, 99.0, 1.0, 4.0)
	var hit := await _run_hit(id, 0.0, 1.0, 4.0)
	ok(calm.size() > 0 and hit.size() == calm.size(), "%s: flinch run recorded (%d frames)" % [id, calm.size()])
	var legs := 0.0
	var arms := 0.0
	for i in mini(calm.size(), hit.size()):
		legs = maxf(legs, absf(float(hit[i]["legs"]) - float(calm[i]["legs"])))
		arms = maxf(arms, float(hit[i]["hand"].distance_to(calm[i]["hand"])))
	ok(legs <= FLINCH_LEGS_M, "%s: a hit mid-run leaves the legs on the run (foot slide off by %.4f m, limit %.3f)"
			% [id, legs, FLINCH_LEGS_M])
	ok(arms >= FLINCH_ARMS_M, "%s: a hit mid-run flinches the arms (hand moves %.3f m, min %.3f)"
			% [id, arms, FLINCH_ARMS_M])
	var still := await _run_hit(id, 0.0, 1.0, 0.0)
	var stagger := await _run_hit(id, 0.0, Oomph.HEAVY_FLINCH, 4.0)
	var mid := hit.size() / 3
	ok(float(still[mid]["act"]) > 0.5, "%s: a hit standing still takes the whole body" % id)
	ok(float(stagger[mid]["act"]) > 0.5, "%s: a stagger on the run takes the whole body" % id)
	ok(float(hit[mid]["act"]) <= 0.0, "%s: a chip hit on the run leaves the body to the legs" % id)

## 1 s of play at `speed` m/s, hit at the start (hit_t 99: none); per frame: leg bone sum, right hand, act_w.
func _run_hit(id: String, hit_t: float, hit_k: float, speed: float) -> Array:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var s := {"vel": Vector3(0, 0, -speed), "face": 0.0, "grounded": true, "hit_t": 99.0, "hit_k": hit_k,
			"hit_dir": Vector2(0, -1)}
	m.set_meta(WardenClips.STATE, s)
	for k in 30:
		sync.call("_process", DT)
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var out: Array = []
	var t := 0.0
	while t < 1.0:
		s["hit_t"] = t if hit_t < 1.0 else 99.0
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		var legs := 0.0
		for b in ["thigh.L", "thigh.R", "shin.L", "shin.R"]:
			var o := sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin
			legs += o.x * 1.0 + o.y * 3.0 + o.z * 7.0
		out.append({"legs": legs, "hand": hand.global_position, "act": clips.act_w})
		t += DT
	m.free()
	return out
## Snaps (docs/MOVEMENT_FEEL.md, Strike snaps): a clip whose strike or release key, where its fastest arm bone stops,
## lands inside the blend-in carries a shorter "fade", so the strike pose is at full weight from locomotion on its key.
## (An authored fade longer than FADE marks a wind-up blend, not a strike.)
func _snaps(id: String, m: Node3D, clips: WardenClips, dd: Dictionary) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var arms := [WardenSkeleton.find(sk, "upper_arm.L"), WardenSkeleton.find(sk, "upper_arm.R")]
	var bones: Array = []
	for bi in sk.get_bone_count():
		var up := bi
		while up >= 0 and not up in arms:
			up = sk.get_bone_parent(up)
		if up >= 0 and not sk.get_bone_name(bi).begins_with("spring_"):
			bones.append(bi)
	clips.tree.active = false
	var moves: Dictionary = dd.get("kmoves", {})
	var snaps: Array = []
	var late: Array = []
	for km in moves:
		var key := _strike_key(sk, clips.lib.get_animation(String(moves[km]["clip"])), bones)
		if key < 0.0 or key >= WardenClips.FADE - 0.005 or float(moves[km].get("fade", 0.0)) > WardenClips.FADE:
			continue
		snaps.append(km)
		var w := _weight_on(m, clips, String(km), key)
		if w < 0.99:
			late.append("%s %.2f at %.3f s" % [km, w, key])
	clips.tree.active = true
	ok(late.is_empty(), "%s: %d moves snap inside the %.1f s blend, each at full weight on its key (%s)"
			% [id, snaps.size(), WardenClips.FADE, ", ".join(late)])

## s: where the clip's fastest arm bone stops (its speed back under a third), if it snaps (SNAP_MPS) in its first 0.4 s;
## -1 when it does not.
func _strike_key(sk: Skeleton3D, an: Animation, bones: Array) -> float:
	var step := FRAME / 2.0
	var last: Array = []
	var top := 0.0
	var top_bone := 0
	var speeds := {}
	var t := 0.0
	sk.reset_bone_poses()      # (bones the clip does not key stay at rest, not where the last check left them)
	while t <= minf(an.length, 0.4):
		_clip_pose(sk, an, t)
		var now: Array = bones.map(func(bi): return sk.get_bone_global_pose(bi).origin)
		for i in last.size():
			var v := (now[i] as Vector3).distance_to(last[i]) / step
			(speeds.get_or_add(i, []) as Array).append(v)
			if v > top:
				top = v
				top_bone = i
		last = now
		t += step
	if top < SNAP_MPS:
		return -1.0
	var sp: Array = speeds[top_bone]
	var k := sp.find(top)
	while k < sp.size() - 1 and float(sp[k]) > 0.35 * top:
		k += 1
	return k * step

## The clip's own pose at `t`, straight onto the skeleton (the blend tree off).
func _clip_pose(sk: Skeleton3D, an: Animation, t: float) -> void:
	for tr in an.get_track_count():
		var bi := sk.find_bone(an.track_get_path(tr).get_concatenated_subnames())
		if bi < 0:
			continue
		match an.track_get_type(tr):
			Animation.TYPE_POSITION_3D: sk.set_bone_pose_position(bi, an.position_track_interpolate(tr, t))
			Animation.TYPE_ROTATION_3D: sk.set_bone_pose_rotation(bi, an.rotation_track_interpolate(tr, t))
			Animation.TYPE_SCALE_3D: sk.set_bone_pose_scale(bi, an.scale_track_interpolate(tr, t))

## The move's weight on screen when the kit clock reaches `key`, started from standing as the game feeds it.
func _weight_on(m: Node3D, clips: WardenClips, km: String, key: float) -> float:
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	for i in 30:
		clips.step(FRAME)
	var t := 0.0
	while true:
		s["kmove"] = km
		s["kmove_t"] = t
		clips.step(FRAME)
		if t >= key - 0.001:
			break
		t += FRAME
	var side := clips.xf if clips.chan == 1 else 1.0 - clips.xf
	return maxf(clips.up_w, clips.act_w * side)
## The rescue carry (WardenCarry): the walk legs stay on the clips, both wrists come in round the socket the Boki
## rides at, the data's weapon bones are put away, the legs keep stepping, and it lets go when the carry ends.
func _carry(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hips := WardenSkeleton.find(sk, "hips")
	var s := {"vel": Vector3(0, 0, -3.6), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var plain := await _stride(sync, sk)
	s["kmove"] = WardenCarry.MOVE
	s["kmove_t"] = 0.5
	var stride := await _stride(sync, sk)
	var socket: Vector3 = m.get_meta(WardenCarry.SOCKET, Vector3.INF)
	ok(clips.proc_w <= 0.0 and clips.carry_w >= 1.0 and socket != Vector3.INF,
			"%s: the carry lies over the clips, not the rig, and leaves a socket" % id)
	var height := 1.6 * absf(m.scale.y)
	var hips_at := sk.global_transform * sk.get_bone_global_pose(hips).origin
	var worst := 0.0
	var front := INF
	for side in ["L", "R"]:
		var wrist := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand." + side)).origin
		worst = maxf(worst, wrist.distance_to(socket))
		front = minf(front, hips_at.z - wrist.z)       # (the model faces -Z)
	ok(worst <= 0.3 * height and front > 0.05 * height,
			"%s: both wrists cradle the Boki at the chest (%.2f m from the socket, %.2f m in front of the hips)"
			% [id, worst, front])
	ok(socket.y > hips_at.y and socket.y < hips_at.y + 0.9 * height,
			"%s: the Boki rides at chest height (%.2f m over the hips)" % [id, socket.y - hips_at.y])
	var clear := _clear(sk, socket, height)
	ok(clear > 0.1, "%s: the Boki rides in front of the chest, not in it (%.2f m clear)" % [id, clear])
	var held := 0.0
	for nm in dd.get("carry_stow", []):
		held = maxf(held, sk.get_bone_pose_scale(WardenSkeleton.find(sk, String(nm))).x)
	ok(held < 0.01, "%s: the weapon bones the data stows are put away (%.3f)" % [id, held])
	if not (dd.get("carry_drop", []) as Array).is_empty():
		var bare := not clips.drop.is_empty()
		for h in clips.drop:
			bare = bare and h[0].mesh == h[2] and _tris(h[2]) < _tris(h[1])
		ok(bare, "%s: the weapon modelled into the hand leaves the shown mesh" % id)
	ok(plain < 0.02 or stride >= plain * 0.75,
			"%s: the legs keep stepping under it (%.2f m of stride, %.2f m without)" % [id, stride, plain])
	s["kmove"] = "rs_done"
	for k in 20:
		sync.call("_process", DT)
		await holder.get_tree().process_frame
	ok(clips.proc_w <= 0.0, "%s: the stand-up beat stays on the clips" % id)
	s.erase("kmove")
	for k in 20:
		sync.call("_process", DT)
		await holder.get_tree().process_frame
	var back := 1.0
	for nm in dd.get("carry_stow", []):
		back = minf(back, sk.get_bone_pose_scale(WardenSkeleton.find(sk, String(nm))).x)
	for h in clips.drop:
		back = back if h[0].mesh == h[1] else 0.0
	ok(clips.carry_w <= 0.0 and not m.has_meta(WardenCarry.SOCKET) and back > 0.5,
			"%s: the carry lets go (socket gone, weapon back, size %.2f)" % [id, back])

## How far the socket lies in front of the body's surface at its height and across it (the meshes' rest vertices
## within a band round the socket; the model faces -Z, at rest about the skeleton).
func _clear(sk: Skeleton3D, socket: Vector3, height: float) -> float:
	var at := sk.global_transform.affine_inverse() * socket
	var front := INF
	for n in sk.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or not mi.visible:
			continue
		for si in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				if absf(v.y - at.y) < 0.06 * height and absf(v.x - at.x) < 0.1 * height:
					front = minf(front, v.z)
	return front - at.z if front != INF else 1.0

## A mesh's triangle count.
func _tris(m: Mesh) -> int:
	var n := 0
	for si in m.get_surface_count():
		n += m.surface_get_array_index_len(si) / 3
	return n

## How far the right shin swings front to back over 40 frames of the state.
func _stride(sync: Node, sk: Skeleton3D) -> float:
	var shin := WardenSkeleton.find(sk, "shin.R")
	var lo := INF
	var hi := -INF
	for k in 40:
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		var z := (sk.global_transform * sk.get_bone_global_pose(shin).origin).z
		lo = minf(lo, z)
		hi = maxf(hi, z)
	return hi - lo
## The pond walk (tools/pond_walk.gd): the right move for each depth. Wading is the run with the knees hauled up (higher
## than the rig's plain walk at that speed); swimming is a flutter kick and, in a hand the kit lets go of, a stroke,
## both at the pace of the swim (slower treading water); the weapon stays in its hand; the clips stand aside.
func _pond(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var bi := {}
	for b in ["hand.L", "upper_arm.L", "shin.L", "shin.R"]:
		bi[b] = WardenSkeleton.find(sk, b)
	var tip := sync.get("blade_tip") as Node3D
	var muzzle := sync.get("muzzle") as Node3D
	var hb := int(sync.get("blade_bone"))
	var rest := tip.position.length()
	var height := 1.6 * absf(m.scale.y)
	var anim := HunterAnim.new(m)
	var walk_speed: float = PondWalk.DRY_SPEED * HomeWater.WADE_SPEED
	clips.force = {"proc": true}
	var plain := 0.0      # the rig's plain walk at the wading speed: its highest knee
	for i in 45:
		anim.update(DT, {"vel": Vector3(0, 0, -walk_speed), "face": 0.0, "grounded": true, "fired": 99.0})
		sync.call("_process", DT)
		if i > 15:
			plain = maxf(plain, maxf(_pos(sk, m, bi["shin.L"]).y, _pos(sk, m, bi["shin.R"]).y))
	clips.force = {}
	var rows: Array = []
	var held := [0.0, 0.0]      # worst Muzzle-off-the-tip, blade-off-the-hand in the water (the callback fills it)
	var sample := func(info: Dictionary) -> void:
		var row := {"phase": info["phase"], "depth": info["depth"], "proc": clips.proc_w, "state": info["state"]}
		for b in bi:
			row[b] = _pos(sk, m, bi[b])
		row["hand.L"] -= row["upper_arm.L"]      # (the hand about its shoulder: the body's bob stays out of the stroke)
		rows.append(row)
		if info["depth"] > 0:
			var sees: Vector3 = sk.global_transform * (sk.get_bone_global_pose(hb) * tip.position)
			var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
			var body_k := absf((sk.global_transform.basis * sk.get_bone_global_pose(hb).basis).get_scale().x)
			held[0] = maxf(held[0], muzzle.global_position.distance_to(sees))
			held[1] = maxf(held[1], absf(hand.distance_to(sees) / body_k - rest))
	await PondWalk.new().walk(holder.get_tree(), m, sync, anim, sample)
	var flags_ok := true
	var peak := {"wade": 0.0}
	for r in rows:
		var st: Dictionary = r["state"]
		flags_ok = flags_ok and bool(st["wade"]) == (r["depth"] == 1) and bool(st["swim"]) == (r["depth"] == 2)
		if r["phase"] == "wade" and float(r["proc"]) >= 1.0:
			peak["wade"] = maxf(peak["wade"], maxf((r["shin.L"] as Vector3).y, (r["shin.R"] as Vector3).y))
	ok(flags_ok, "%s: pond walk: wade in the shallows, swim in the deep, neither on the bank" % id)
	var legs := KMovesStone.gait(id) > 0.5      # (a hoverer's legs barely walk: it floats through the water)
	ok(not legs or peak["wade"] >= plain + 0.02 * height,
			"%s: wading hauls the knees up (%.2f m vs %.2f m plain at the same speed)" % [id, peak["wade"], plain])
	var kick := [_rate(rows, "swim", "shin.L", 1), _rate(rows, "tread", "shin.L", 1)]
	var kick_swim := absf(kick[0] - HunterSwim.KICK_PER_STROKE * HunterSwim.HZ_FULL) < 0.5
	var kick_tread := absf(kick[1] - HunterSwim.KICK_PER_STROKE * HunterSwim.HZ_TREAD) < 0.5
	ok(not legs or (kick_swim and kick_tread and kick[1] < kick[0]),
			"%s: swim kicks at the swim pace (%.1f Hz swimming, %.1f treading)" % [id, kick[0], kick[1]])
	var stroke := [_rate(rows, "swim", "hand.L", 2), _rate(rows, "tread", "hand.L", 2)]
	var strokes := _range(rows, "swim", "hand.L", 2) >= 0.1 * height      # (a hand on the weapon barely moves)
	var stroke_swim := absf(stroke[0] - HunterSwim.HZ_FULL) < 0.5
	var stroke_tread := absf(stroke[1] - HunterSwim.HZ_TREAD) < 0.5
	ok(not strokes or (stroke_swim and stroke_tread),
			"%s: %s (%.1f strokes/s swimming, %.1f treading)" % [id,
			"its free hand strokes at the swim pace" if strokes else "both hands stay on the weapon",
			stroke[0], stroke[1]])
	ok(held[0] <= FX_ON_BLADE and held[1] <= 2.0 * HunterAnim.WEAPON_SLACK,
			"%s: the weapon stays in its hand in the water (%.3f m off the tip, %.3f m off the hand)" % [
			id, held[0], held[1]])
	var ends: Array = rows.filter(func(r): return r["phase"] in ["swim", "tread", "wade"])
	ok(ends.slice(int(ends.size() / 4.0)).all(func(r): return float(r["proc"]) >= 1.0),
			"%s: the clips stand aside while it wades and swims" % id)
	ok(float(rows[rows.size() - 1]["proc"]) <= 0.0, "%s: and take the body back on dry ground" % id)

func _pos(sk: Skeleton3D, m: Node3D, bone: int) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(bone).origin - m.global_position

## How far one limb signal travels over a phase.
func _range(rows: Array, phase: String, bone: String, axis: int) -> float:
	var lo := 9.0
	var hi := -9.0
	for r in rows:
		if r["phase"] == phase:
			lo = minf(lo, (r[bone] as Vector3)[axis])
			hi = maxf(hi, (r[bone] as Vector3)[axis])
	return hi - lo

## Cycles a second of one limb signal over a phase, after the ease-in (a swing up through the middle of its range
## and back down past a quarter of it counts once, so a jitter does not).
func _rate(rows: Array, phase: String, bone: String, axis: int) -> float:
	var sel: Array = rows.filter(func(r): return r["phase"] == phase)
	sel = sel.slice(mini(18, sel.size() - 1))
	var vals: Array = sel.map(func(r): return (r[bone] as Vector3)[axis])
	var lo := float(vals.min())
	var hi := float(vals.max())
	var cycles := 0
	var up := false
	for v in vals:
		if float(v) > lerpf(lo, hi, 0.65) and not up:
			up = true
			cycles += 1
		elif float(v) < lerpf(lo, hi, 0.35):
			up = false
	return cycles / maxf(0.01, vals.size() * DT)
