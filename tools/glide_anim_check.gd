extends RefCounted
## --glide-anim-check: the glide set (WardenGlide, docs/art/anim_audit/GLIDE_SET.md) on every Hero with clips.
## Per Hero: each glide state's clip is in the .glb (open, hold, lean left and right, overheat struggle, close), the
## open and close are as quick as the source's ("instant": the canopy bites in ~0.13 s), the loops loop; played
## through the model: a fall shows no hold, the open plays over the first moment and hands to the hold, the steer leans
## the body both ways within a beat and lets go, a remote Hunter's turning heading leans it too, an overheated glider
## plays the struggle, a shut glider plays the close and the hold is gone within the air fade, a landing out of a glide
## is the land clip with no close. Then one live Hunter: falling without the glide input never shows the hold pose.
## Never touches the save.

const DT := 1.0 / 60.0
const OPEN_MAX := 0.3        # s: the open is over by then (source: the glider opens "instantly", catch ~0.13 s)
const CLOSE_MAX := 0.2       # s: the close too (source: open and close are instant)
const POSE_DEG := 8.0        # a state's clip must turn some contract bone at least this far from the hold
const BANK_DEG := 8.0        # full steer leans the body at least this far off the straight hold
const LEAN_BY := 0.2         # s: the lean is 60% in by then
const LEAN_OFF := 0.35       # s: and 80% out by then once the keys let go
const HOLD_OFF := 0.15       # s: the hold is gone this long after the glider shuts (AIR_FADE 0.12 + a frame)
const BONES := ["hips", "head", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R",
	"shin.L", "shin.R"]

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("GLIDE_ANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ORDER:
		if not WardenClips.data(WardenGlb.art(String(id))).is_empty():
			n += 1
			_hero(String(id))
	ok(n == Arch.ORDER.size(), "every Hunter has clips (%d of %d)" % [n, Arch.ORDER.size()])
	await _live(main)
	print("GLIDE_ANIM_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String) -> void:
	var art_name := WardenGlb.art(id)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.clips == null:
		ok(false, "%s: plays its clips" % id)
		m.free()
		return
	var cl := sync.clips
	var ai: Dictionary = cl.d["air"]
	var missing: Array = []
	for k in ["glide", "open", "close", "lean_l", "lean_r", "burn"]:
		if not ai.has(k) or not cl.lib.has_animation(String(ai[k])):
			missing.append(k)
	ok(missing.is_empty(), "%s (%s): a clip for every glide state (missing %s)" % [id, art_name, str(missing)])
	if not missing.is_empty():
		m.free()
		return
	var open_len := cl.lib.get_animation(String(ai["open"])).length
	var close_len := cl.lib.get_animation(String(ai["close"])).length
	ok(open_len <= OPEN_MAX and close_len <= CLOSE_MAX, "%s: open %.2f s <= %.2f, close %.2f s <= %.2f" % [id,
			open_len, OPEN_MAX, close_len, CLOSE_MAX])
	var loops := WardenGlide.loops(ai).all(func(c): return cl.lib.get_animation(String(c)).loop_mode == Animation.LOOP_LINEAR)
	ok(loops, "%s: the leans and the struggle loop" % id)
	var an := HunterAnim.new(m)
	var fall := {"vel": Vector3(0, -12.0, -2.0), "face": 0.0, "grounded": false, "gliding": false}
	var top := 0.0
	for i in 30:
		_play(an, sync, fall, 1)
		top = maxf(top, _hold_w(cl))
	ok(top == 0.0, "%s: a fall shows no hold (hold weight up to %.2f)" % [id, top])
	var glide := {"vel": Vector3(0, -1.4, -5.0), "face": 0.0, "grounded": false, "gliding": true}
	_play(an, sync, glide, 6)
	var open_w := cl.glide.open_w()
	var mid := _pose(cl)
	_play(an, sync, glide, 40)
	var hold := _pose(cl)
	ok(open_w > 0.5 and _diff(mid, hold) >= POSE_DEG and cl.glide.open_w() == 0.0 and _hold_w(cl) > 0.99,
			"%s: the open plays (weight %.2f at 0.1 s, %.0f deg off the hold) and hands to the hold (%.2f)" % [id,
			open_w, _diff(mid, hold), _hold_w(cl)])
	var straight := _bank(m, cl)
	var right := glide.duplicate()
	right["steer_in"] = Vector2(1, 0)
	_play(an, sync, right, int(LEAN_BY / DT))
	var lean_in := cl.glide.lean
	_play(an, sync, right, 30)
	var bank_r := _bank(m, cl)
	var leaned := _pose(cl)
	var tree_lean := float(cl.tree.get("parameters/glide_lean/blend_amount"))
	_play(an, sync, glide, int(LEAN_OFF / DT))
	var lean_out := cl.glide.lean
	var left := glide.duplicate()
	left["steer_in"] = Vector2(-1, 0)
	_play(an, sync, left, 40)
	var bank_l := _bank(m, cl)
	ok(lean_in >= 0.6 and lean_out <= 0.2, "%s: the lean responds (%.2f by %.2f s) and lets go (%.2f after %.2f s)"
			% [id, lean_in, LEAN_BY, lean_out, LEAN_OFF])
	ok(bank_r > straight + BANK_DEG and bank_l < straight - BANK_DEG and _diff(leaned, hold) >= POSE_DEG
			and absf(tree_lean - 1.0) < 0.05, "%s: steer leans the body right %.0f / left %.0f deg (straight %.0f), the clip blend at %.2f"
			% [id, bank_r, bank_l, straight, tree_lean])
	var turning := glide.duplicate()
	for i in 30:
		turning["vel"] = Vector3(5.0 * sin(i * 3.0 * DT), -1.4, -5.0 * cos(i * 3.0 * DT))   # heading turns right at 3 rad/s
		turning["face"] = -i * 3.0 * DT                                                      # (facing along it)
		_play(an, sync, turning, 1)
	ok(cl.glide.lean > 0.5, "%s: with no keys (a remote Hunter) a turning heading leans it (%.2f)" % [id, cl.glide.lean])
	var burn := glide.duplicate()
	burn["burn"] = true
	_play(an, sync, burn, 24)
	ok(cl.glide.burn_w > 0.99 and _diff(_pose(cl), hold) >= POSE_DEG, "%s: overheated, the struggle plays (%.2f, %.0f deg off the hold)"
			% [id, cl.glide.burn_w, _diff(_pose(cl), hold)])
	_play(an, sync, glide, 30)
	_play(an, sync, fall, 3)
	var close_w := cl.glide.close_w()
	_play(an, sync, fall, int(HOLD_OFF / DT) - 3)
	var hold_after := _hold_w(cl)
	_play(an, sync, fall, 20)
	ok(close_w > 0.5 and hold_after < 0.01 and cl.glide.close_w() == 0.0 and cl.glide_w == 0.0,
			"%s: shut in the air the close plays (%.2f), the hold is gone by %.2f s (%.2f), the fall is back" % [id,
			close_w, HOLD_OFF, hold_after])
	_play(an, sync, glide, 30)
	var landed := {"vel": Vector3(0, 0, -3.0), "face": 0.0, "grounded": true, "gliding": false}
	_play(an, sync, landed, 3)
	ok(cl.glide.close_w() == 0.0 and cl.cur == String(cl.d["land"]["clip"]), "%s: a landing out of a glide is the land clip (%s), no close"
			% [id, cl.cur])
	m.free()

## One live Hunter high over the ground: with no glide input it falls with no hold; held, it opens and holds; let go,
## the hold is gone within the air fade.
func _live(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight("juggernaut"), "arch": "juggernaut", "weapon": Arch.signature("juggernaut")})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	h.teleport(h.pos + Vector3(0, 40.0, 0))
	var sync := h.model.get_node("Warden/Sync") as WardenGlb.Sync
	sync.set_process(false)
	var cl := sync.clips
	var phases := [["fall", false, 0.8], ["held", true, 0.8], ["let go", false, HOLD_OFF]]
	for ph in phases:
		var top := 0.0
		var glided := false
		for i in int(float(ph[2]) / Match.DT):
			h.inp["move"] = Vector2.ZERO
			h.inp["glide"] = ph[1]
			m.step(Match.DT)
			h.render(Match.DT, 1.0)
			sync._process(Match.DT)
			top = maxf(top, _hold_w(cl)) if ph[0] != "let go" else _hold_w(cl)
			glided = glided or h.gliding
		if ph[0] == "fall":
			ok(not glided and top == 0.0, "live: no glide input, no glider and no hold pose (hold weight up to %.2f)" % top)
		elif ph[0] == "held":
			ok(glided and _hold_w(cl) > 0.99, "live: the glide input held opens the glider into the hold (%.2f)" % _hold_w(cl))
		else:
			ok(not h.gliding and top < 0.01, "live: let go, the hold is gone within %.2f s (%.2f)" % [HOLD_OFF, top])
	m.queue_free()
	await main.get_tree().process_frame

## How much of the plain hold pose shows (under the open and the dive).
func _hold_w(cl: WardenClips) -> float:
	return cl.glide_w * (1.0 - cl.dive_w) * (1.0 - cl.glide.open_w())

func _play(an: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, n: int) -> void:
	for i in n:
		an.update(DT, s)
		sync._process(DT)

func _pose(cl: WardenClips) -> Dictionary:
	var out := {}
	for b in BONES:
		var bi := WardenSkeleton.find(cl.skel, b)
		if bi >= 0:
			out[b] = cl.skel.get_bone_global_pose(bi).basis.get_rotation_quaternion()
	return out

## The most any bone turned from one pose to the other, in degrees.
func _diff(a: Dictionary, b: Dictionary) -> float:
	var most := 0.0
	for k in a:
		if b.has(k):
			most = maxf(most, rad_to_deg((a[k] as Quaternion).angle_to(b[k] as Quaternion)))
	return most

## The hips-to-head line's sideways lean in the model's frame, degrees (+: to its right).
func _bank(m: Node3D, cl: WardenClips) -> float:
	var inv := m.global_transform.affine_inverse() * cl.skel.global_transform
	var sk := cl.skel
	var up := inv * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin \
			- inv * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin
	return rad_to_deg(asin(clampf(up.x / maxf(up.length(), 0.01), -1.0, 1.0)))
