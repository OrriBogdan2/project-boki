extends RefCounted
## --native-flip-check: Sable's Shift (the Vault) on her Meshy-native model flips her (WardenNativeFlip, data
## "flips" in warden_native.json). A real Shift in a training match, posed frame by frame the way a match draws her:
## the flip starts on the press frame, turns her a full turn in the plane she dashes in (her head goes over the way
## she travels, under her hips at the top), the body holds the jump clip and never the attack clip, and she is upright
## (the model back on its own transform) by the frame the dash ends, then back on the run or idle. The same from a
## jump (the air cartwheel, held to the landing). The flip is drawing only: the same dash with the flip switched off
## travels frame for frame the same path, and the ground Vault still covers the kit's 4.5 m in 0.48 s.

const AKCheck := preload("res://tools/archetype_check.gd")
const DT := AKCheck.DT
const FULL := 5.9  # rad: the most the body turns in the flip (a full turn, 6.283 keyed)
const OVER := 0.15  # m: at the quarter turn the head leads the hips this far along the dash's way
const SAME := 0.0001  # m: the flipped and unflipped dashes' positions agree to this, every frame
const GROUND_M := 4.5  # m and s: the Vault (content/archetypes/thief.json "dash"; dancer_feel_check's bounds)
const GROUND_S := 0.48
const DIST_TOL := 0.35
const TIME_TOL := 0.05
var a_x: AKCheck
var n := 0
var bad := 0


func ok(cond: bool, what: String) -> void:
	n += 1
	print("NATIVEFLIP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	WardenNative.contract_only = false
	a_x = AKCheck.new()
	a_x.main = main
	var on: Dictionary = await _dash(true, false)
	var off: Dictionary = await _dash(false, false)
	_ground(on)
	var path_on: Array = on["path"]
	var path_off: Array = off["path"]
	var worst := 0.0
	for i in mini(path_on.size(), path_off.size()):
		worst = maxf(worst, (path_on[i] as Vector3).distance_to(path_off[i]))
	ok(
		path_on.size() == path_off.size() and worst <= SAME,
		"the flip moves nothing: %d frames, flipped vs not %.6f m apart at most" % [path_on.size(), worst]
	)
	ok(
		absf(float(on["dist"]) - GROUND_M) < DIST_TOL and absf(float(on["end"]) - GROUND_S) < TIME_TOL,
		(
			"the ground Vault is still the kit's: %.2f m in %.2f s (%.1f m in %.2f s)"
			% [on["dist"], on["end"], GROUND_M, GROUND_S]
		)
	)
	_air(await _dash(true, true))
	print("NATIVEFLIP DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## One Vault to her right (she faces -Z), posed every frame; `flips` false switches the flip layer off.
func _dash(flips: bool, air: bool) -> Dictionary:
	var r = a_x.setup("thief", 8.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var home: Vector3 = r[4]
	var nat := p.model.get_node_or_null(^"Warden/Native") as WardenNative
	var out := {"native": nat != null, "path": [], "frames": [], "dist": 0.0, "end": -1.0, "press": ""}
	if nat == null:
		await a_x.done(m)
		return out
	if not flips:
		nat.flip.ids = []
	p.teleport(home)
	p.face = 0.0
	_pose(p, nat)
	if air:
		p.do_jump()
		for i in 6:
			_frame(m, p, nat)
	p.inp["move"] = Vector2(1, 0)
	p.do_dash()
	_pose(p, nat)
	out["press"] = nat.flip.cur
	out["way"] = Vector3(p.roll_dir.x, 0.0, p.roll_dir.y).normalized()
	var from := p.pos
	var t := 0.0
	var landed_for := 0
	while t < 1.6 and landed_for < 12:
		var was_rolling := p.roll_t > 0.0
		_frame(m, p, nat)
		t += DT
		if was_rolling and p.roll_t <= 0.0 and float(out["end"]) < 0.0:
			out["end"] = t
			out["dist"] = p.flat_dist(from)
		if float(out["end"]) >= 0.0 and p.grounded:
			landed_for += 1
		(out["path"] as Array).append(p.pos)
		(out["frames"] as Array).append(_look(p, nat, t))
	p.inp["move"] = Vector2.ZERO
	await a_x.done(m)
	return out


func _frame(m: Match, p: Hunter, nat: WardenNative) -> void:
	m.step(DT)
	_pose(p, nat)


## What a match's draw does each frame for her: HunterAnim's state, then the native model's own frame.
func _pose(p: Hunter, nat: WardenNative) -> void:
	p.render(DT, 1.0)
	nat._process(DT)


func _look(p: Hunter, nat: WardenNative, t: float) -> Dictionary:
	var sk := nat.skel
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var hips := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin
	return {
		"t": t,
		"kmove": p.ak.anim_id,
		"flip": nat.flip.cur,
		"angle": nat.flip.angle,
		"clip": String(nat.player.assigned_animation),
		"upright": nat.flip.glb.transform.is_equal_approx(nat.flip.base),
		"rolling": p.roll_t > 0.0,
		"grounded": p.grounded,
		"head": head,
		"hips": hips,
		"cur": nat.cur,
	}


## The ground Vault: starts on the press, a full turn over the way she goes, the jump clip under it, upright when
## the dash ends, then the run or idle.
func _ground(r: Dictionary) -> void:
	ok(bool(r["native"]), "Sable is drawn on her Meshy-native model")
	if not bool(r["native"]):
		return
	var frames: Array = r["frames"]
	var nat_jump := String(WardenNative.entry("sable")["clips"]["jump"])
	var nat_attack := String(WardenNative.entry("sable")["clips"]["attack"])
	ok(String(r["press"]).begins_with("thf_vault"), "the Shift press frame starts the flip (%s)" % r["press"])
	var most := 0.0
	var quarter := {}
	var top := {}
	var clips := {}
	var end_i := -1
	for i in frames.size():
		var f: Dictionary = frames[i]
		if String(f["flip"]) != "":
			clips[f["clip"]] = true
			most = maxf(most, float(f["angle"]))
			if quarter.is_empty() and float(f["angle"]) >= PI * 0.5:
				quarter = f
			if top.is_empty() and float(f["angle"]) >= PI:
				top = f
		if end_i < 0 and not bool(f["rolling"]):
			end_i = i
	ok(most >= FULL, "she turns a full turn (%.2f rad)" % most)
	var way: Vector3 = r["way"]
	var lead := -1.0
	if not quarter.is_empty():
		lead = ((quarter["head"] as Vector3) - (quarter["hips"] as Vector3)).dot(way)
	ok(lead >= OVER, "her head goes over the way she dashes: %.2f m ahead of the hips at the quarter turn" % lead)
	var under := not top.is_empty() and (top["head"] as Vector3).y < (top["hips"] as Vector3).y
	ok(under, "at the top of the flip her head is under her hips")
	ok(
		clips.has(nat_jump) and not clips.has(nat_attack),
		"the body holds the jump clip, not the attack (%s)" % str(clips.keys())
	)
	var upright := end_i >= 0 and bool(frames[end_i]["upright"]) and String(frames[end_i]["flip"]) == ""
	ok(upright, "upright on the frame the dash ends (%.2f s)" % (float(frames[end_i]["t"]) if end_i >= 0 else -1.0))
	var after: Dictionary = frames[-1]
	ok(String(after["cur"]) in ["run", "walk", "idle"], "then back on the loop clips (%s)" % after["cur"])


## From a jump: the air cartwheel turns her and holds until she touches down, upright on the landing.
func _air(r: Dictionary) -> void:
	var frames: Array = r["frames"]
	var most := 0.0
	var land_i := -1
	for i in frames.size():
		var f: Dictionary = frames[i]
		if String(f["flip"]) != "":
			most = maxf(most, float(f["angle"]))
		if land_i < 0 and i > 0 and bool(f["grounded"]) and not bool(frames[i - 1]["grounded"]):
			land_i = i
	ok(String(r["press"]) != "", "the Shift from a jump starts the air flip (%s)" % r["press"])
	ok(most >= FULL, "the air flip turns a full turn (%.2f rad)" % most)
	var clean := land_i >= 0
	for i in range(maxi(land_i, 0), frames.size()):
		clean = clean and bool(frames[i]["upright"])
	ok(clean, "upright from the landing on (landed at frame %d)" % land_i)
