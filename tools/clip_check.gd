extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in
## the tri budget and carries every clip its file names; each keyed move of its kit has a clip as long as the move (the
## timings are the kit's); the kit's time seeks the clip; through all clips the skinned weapon stays on its bone and the
## Gun and Muzzle lie on the blade you see (item 76b); only one weapon is drawn; moves hand over with no pop; the idle
## and stance loops close with no pop and run long enough to breathe (docs/art/IDLE_AUDIT.md). Never touches the save.

const TRI_BUDGET := 15000
const OWN_MODELS := {"archer": "hem", "thief": "sable", "tender": "pip", "gunslinger": "vex", "ashwick": "cinder",
	"mage": "ryzz", "dolm": "tarek", "rimewright": "claire", "dredge": "dredge", "bulwark": "breaker",
	"ostra": "ostra", "juggernaut": "kael"}
const DT := 1.0 / 30.0
const FLINCH_LEGS_M := 0.002   # m: a chip hit on the run may move the legs this far off the unhit run
const FLINCH_ARMS_M := 0.01    # m: and must move the hand at least this far (the flinch shows)
const FX_ON_BLADE := 0.05      # m: the Muzzle may sit this far off the visible tip
const NO_STRIDE_M := 0.05      # m: a shin swinging less than this does not step (Motley hovers: his legs hang, 0.024 m)
const HAND_PIECE_M := 0.25     # m: carrying, a shown piece on one hand alone may reach this far (a hand, not a weapon)
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
const SEAM_DEG := 1.0          # a standing loop's last key may turn a bone this far from its first
const SEAM_M := 0.01           # and move it this far
const ROOT_FOOT_M := 0.02      # m: a rooted Hunter's feet move this much more than the idle's own sway through any move
const STAND_MIN := 2.0         # s: an idle or stance shorter than this reads as a jitter, not a breath
## s: a clip ends on the 30 fps frame nearest its kit move's last key (half a frame, plus float slack), so a clip one
## frame short (Grimble's 2.07 s blast after the v95 re-export, kit 2.1 s) fails instead of snapping to idle early
const END_OFF := DT / 2.0 + 0.001
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
	ok(missing.is_empty(), "%s: the file's %d clips are in the .glb (missing %s; glb_add_clips.py restores)"
			% [id, named.size(), str(missing)])
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
	await _rooted(id, m, sync, clips, dd)
	await _handover(id, m, sync, clips, dd)
	await _carry(id, m, sync, clips, dd)
	m.free()
	await _flinch(id)

## Every clip name the file holds anywhere (a swap that drops one leaves the Hero silently procedural): the kit moves
## (and their "alt"), loco, crouch, air, land, home acts (pat, feed, cheer), states (hit front and back), weapon_out.
func _named(dd: Dictionary) -> Array:
	var out: Array = []
	for mv in (dd.get("kmoves", {}) as Dictionary).values():
		out.append(mv["clip"])
		if mv.has("alt"):
			out.append(mv["alt"])
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
	out.append(dd.get("land", {}).get("clip"))
	out.append_array((dd.get("act", {}) as Dictionary).values())
	for k in dd.get("states", {}):
		var v = dd["states"][k]
		if v is String:
			out.append(v)
		elif v is Dictionary:
			out.append_array([v["front"], v["back"]])
	if dd.has("weapon_out"):
		out.append(dd["weapon_out"]["clip"])
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
	ok(worst <= END_OFF, "%s: every clip lasts as long as its kit move (worst %.3f s, %s)" % [id, worst, where])
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
	var idle_len := clips.lib.get_animation(String((dd["loco"] as Dictionary)["idle"])).length
	for k in ceili(idle_len / DT):      # (the whole idle loop: a foot shift can come late in it)
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
	if not (dd.get("carry_drop", []) + dd.get("carry_drop_surfaces", []) as Array).is_empty():
		var bare := not clips.drop.is_empty()
		for h in clips.drop:
			bare = bare and h[0].mesh == h[2] and _tris(h[2]) < _tris(h[1])
		ok(bare, "%s: the weapon modelled into the hand leaves the shown mesh" % id)
	for gone in dd.get("carry_drop_surfaces", []):
		ok(_surface_tris(clips.drop, String(gone)) <= 1, "%s: the fused weapon (%s) is hidden" % [id, gone])
	var loose := _hand_piece(sk)
	ok(loose <= HAND_PIECE_M,
			"%s: no weapon rides a hand into the Boki (longest piece on a hand alone %.2f m, limit %.2f)"
			% [id, loose, HAND_PIECE_M])
	ok(plain < NO_STRIDE_M or stride >= plain * 0.75,
			"%s: the legs keep stepping under it (%.3f m of stride, %.3f m without)" % [id, stride, plain])
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

## The furthest any piece of the shown skinned meshes that rides one hand alone reaches from it (m; 0: none). Read
## off the meshes, not the data, so a weapon skinned into a hand the data forgot shows here.
func _hand_piece(sk: Skeleton3D) -> float:
	var most := 0.0
	for n in sk.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or not mi.visible or not mi.mesh is ArrayMesh:
			continue
		var head := WardenCarry.hand_heads(mi.skin, sk, ["hand.L", "hand.R"])
		for si in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(si)
			if arrays[Mesh.ARRAY_BONES] == null:
				continue
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var piece := WardenCarry.pieces(idx, arrays[Mesh.ARRAY_VERTEX])
			var reach := WardenCarry.on_hands(arrays, head, piece)
			for t in range(0, idx.size(), 3):   # (only what a triangle draws: a stripped mesh keeps the weapon's
				if idx[t] != idx[t + 1]:        # vertices, and an emptied surface one degenerate triangle)
					most = maxf(most, float(reach.get(piece[idx[t]], 0.0)))
	return most

## The most triangles a shown mesh still draws on the named surface (an emptied one keeps a single degenerate one).
func _surface_tris(held: Array, surface: String) -> int:
	var most := 0
	for h in held:
		var shown := (h[0] as MeshInstance3D).mesh
		for si in shown.get_surface_count():
			if shown.surface_get_name(si) == surface:
				most = maxi(most, shown.surface_get_array_index_len(si) / 3)
	return most

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
