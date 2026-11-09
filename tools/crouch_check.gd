extends RefCounted
## --crouch-check: every Hero whose clip file has "crouch" (item 143), through the game state (HunterAnim, WardenClips).
## Held: the head comes down a good share of the height, the feet stay on the ground, one foot leads. Going down: a dip
## below the hold and a settle, no pop. Sneaking: the feet step, the head rides level. Coming up: back on the idle, no
## pop. Every Hero with clips must have a crouch, but for LATER, which still stand through one: with the data taken
## away a Hero's clips stand, so nothing changes for those. A Hero with no feet (Motley on his spring) skips the rows
## about them.
## Never touches the save.

const DT := 1.0 / 60.0
const DROP := 0.14         # of the standing head height, at least
const SINK := 0.03         # m: an ankle may go this far under its rest height off the ground's line
const LEAD := 0.1          # m: the feet apart, front to back, held
const POP := 0.12          # m: the head's most in one frame at 60 fps, down or up
const BOB := 0.07          # m: the head's rise and fall over a sneak
const STEP := 0.14         # m: how far a foot travels over a sneak
const K := 8.0             # 1/s: Hunter.render's crouch rate
const SPEED_K := 0.55      # Hunter: the walking speed crouched, of the archetype's run speed
const PLANT := 0.45        # of the crouch speed, at least: what a planted foot carries back (under it the sneak skates)
const PLANTED := 0.012     # m: a foot this close to its lowest over the sneak counts as down
const LATER := ["juggernaut"]    # Kael: landing after art1-integ
const SKATES := ["tender"]  # Pip: her 0.16 m tiptoe stride skates even at the top rate (docs/DEBT.md)

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("CROUCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		var dd := WardenClips.data(art_name)
		if dd.has("crouch"):
			n += 1
			await _hero(main, String(id), art_name)
		elif not dd.is_empty():
			ok(id in LATER, "%s: has clips and a crouch" % id)
	ok(n > 0, "at least one Hero has a crouch (%d)" % n)
	print("CROUCH_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## World position of a bone on the model, feet at y 0.
func _at(m: Node3D, sk: Skeleton3D, bone: String) -> Vector3:
	return m.to_local(sk.to_global(sk.get_bone_global_pose(WardenSkeleton.find(sk, bone)).origin))

func _tick(m: Node3D, a: HunterAnim, sync: Node, ck: float, vel := Vector3.ZERO) -> void:
	a.update(DT, {"vel": vel, "face": 0.0, "grounded": true, "crouch": ck, "fired": 99.0})
	sync.call("_process", DT)

func _hero(main: Node, id: String, art_name: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var a := HunterAnim.new(m)
	for k in 3:
		await main.get_tree().process_frame
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	for k in 30:
		_tick(m, a, sync, 0.0)
	var stand: Vector3 = _at(m, sk, "head")
	var feet := WardenSkeleton.find(sk, _foot(sk, "L")) >= 0
	var rest_l: Vector3 = _at(m, sk, _foot(sk, "L")) if feet else Vector3.ZERO
	var rest_r: Vector3 = _at(m, sk, _foot(sk, "R")) if feet else Vector3.ZERO
	var ck := 0.0
	var last := stand.y
	var pop := 0.0
	var low := INF
	for k in 90:
		ck = move_toward(ck, 1.0, DT * K)
		_tick(m, a, sync, ck)
		var y := _at(m, sk, "hips").y
		var hy := _at(m, sk, "head").y
		pop = maxf(pop, absf(hy - last))
		last = hy
		if k < 40:
			low = minf(low, y)
	var held: Vector3 = _at(m, sk, "head")
	var hips := _at(m, sk, "hips").y
	ok(stand.y - held.y >= stand.y * DROP, "%s: down from %.2f to %.2f m" % [id, stand.y, held.y])
	ok(low < hips - 0.01, "%s: the dip goes %.3f m under the hold, then settles" % [id, hips - low])
	ok(pop <= POP, "%s: no pop going down (%.3f m a frame)" % [id, pop])
	if feet:
		var fl := _at(m, sk, _foot(sk, "L"))
		var fr := _at(m, sk, _foot(sk, "R"))
		var floor_y := minf(rest_l.y, rest_r.y)
		var sunk := minf(fl.y, fr.y)
		ok(sunk >= floor_y - SINK, "%s: the feet stay on the ground (%.3f, standing %.3f)" % [id, sunk, floor_y])
		ok(maxf(fl.y, fr.y) > floor_y + 0.01, "%s: a heel is up, on the ball of the foot" % id)
		ok(absf(fl.z - fr.z) >= LEAD, "%s: one foot leads by %.2f m" % [id, absf(fl.z - fr.z)])
	if bool(WardenClips.data(art_name).get("rig_root", false)):
		var box_y := _at(m, sk, "root").y
		ok(box_y >= 0.02, "%s: the root rides the Rig and stays off the ground (%.3f m)" % [id, box_y])
	var v := Vector3(0, 0, -float(WardenClips.data(art_name)["crouch"].get("speed", 2.4)))
	var hmin := INF
	var hmax := -INF
	var zmin := INF
	var zmax := -INF
	for k in 30:
		_tick(m, a, sync, 1.0, v)
	for k in 90:
		_tick(m, a, sync, 1.0, v)
		var h := _at(m, sk, "head").y
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
		if feet:
			var z := _at(m, sk, _foot(sk, "L")).z
			zmin = minf(zmin, z)
			zmax = maxf(zmax, z)
	if feet:
		ok(zmax - zmin >= STEP, "%s: the sneak steps (%.2f m)" % [id, zmax - zmin])
		var carry := _planted_speed(m, a, sync, sk, float(HunterMove.of(id)["speed"]) * SPEED_K)
		ok(carry >= PLANT or id in SKATES, "%s: the feet plant at the crouch speed (%.2f of it)" % [id, carry])
	ok(hmax - hmin <= BOB, "%s: the head rides level on the sneak (%.3f m)" % [id, hmax - hmin])
	for k in 30:
		_tick(m, a, sync, 1.0)
	last = _at(m, sk, "head").y
	pop = 0.0
	for k in 90:
		ck = move_toward(ck, 0.0, DT * K)
		_tick(m, a, sync, ck)
		var hy := _at(m, sk, "head").y
		pop = maxf(pop, absf(hy - last))
		last = hy
	ok(pop <= POP, "%s: no pop coming up (%.3f m a frame)" % [id, pop])
	ok(absf(last - stand.y) <= 0.04, "%s: back up on the idle (%.2f m, stood %.2f)" % [id, last, stand.y])
	m.free()
	# with no data the clips stand through it
	var dd: Dictionary = WardenClips.data(art_name)
	if bool(dd.get("rig_root", false)):
		return      # (his root rides the Rig, which the procedural crouch lowers: the body above it stays)
	var keep: Dictionary = dd["crouch"]
	dd.erase("crouch")
	var m2 := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m2.set_meta("anim_seed", 1)
	holder.add_child(m2)
	var a2 := HunterAnim.new(m2)
	for k in 3:
		await main.get_tree().process_frame
	var sync2 := m2.get_node("Warden/Sync")
	sync2.set_process(false)
	var sk2 := WardenGlb.skeleton(m2.get_node("Warden"))
	for k in 40:
		_tick(m2, a2, sync2, 0.0)
	var h0 := _at(m2, sk2, "head").y
	for k in 40:
		_tick(m2, a2, sync2, 1.0)
	ok(absf(_at(m2, sk2, "head").y - h0) <= 0.03, "%s: with no crouch data the clips stand through it, as before" % id)
	m2.free()
	dd["crouch"] = keep

## Sneaking at the game's crouch speed: the planted foot's speed back along the ground, as a share of it (1: no skate).
func _planted_speed(m: Node3D, a: HunterAnim, sync: Node, sk: Skeleton3D, speed: float) -> float:
	var v := Vector3(0, 0, -speed)
	var bone := WardenSkeleton.find(sk, _foot(sk, "L"))
	for k in 30:
		_tick(m, a, sync, 1.0, v)
	var prev := sk.to_global(sk.get_bone_global_pose(bone).origin)
	var ys: Array[float] = []
	var vz: Array[float] = []
	for k in 120:
		_tick(m, a, sync, 1.0, v)
		var f := sk.to_global(sk.get_bone_global_pose(bone).origin)
		ys.append(f.y)
		vz.append((f.z - prev.z) / DT)
		prev = f
	var low: float = ys.min()
	var sum := 0.0
	var n := 0
	for i in ys.size():
		if ys[i] <= low + PLANTED:
			sum += vz[i]
			n += 1
	return sum / maxf(n, 1) / speed

## A Hero's foot bone (Breaker's clip bones carry an x_ prefix).
func _foot(sk: Skeleton3D, side: String) -> String:
	return "foot." + side if WardenSkeleton.find(sk, "foot." + side) >= 0 else "x_foot." + side
