extends "res://tools/archetype_check.gd"
## Tall-ledge climb, run from --archer-combo-check (tools/archer_bulwark_combo_check.gd adds the counts):
## Lace (archer) jumps into a double-high face and mantles up; Vex (gunslinger) cannot
## (briefs/supervive-data/supervive_physics.md: bCanWallJump is on for Myth and Brall only). Prints AKCHECK lines.

## terraces of a double-high face: twice the 2-terrace (1.6 m) ledge everyone climbs
const DOUBLE_HIGH := 4
const RUN_UP := 1.2       # m from the face the jump starts
const JUMP_AT := 8        # frame of the run-up the jump key goes down
const TRY_FRAMES := 150

## Raises a wall `rise` terraces above the strip, its face 3 m east of `home`, and returns its top height.
func _raise(m: Match, home: Vector3, lv: int, rise: int) -> float:
	var W: World = m.world
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(3, 6):
			wl[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + rise
	W.level = wl
	return (lv + rise) * World.LEVEL

## Jumps at the wall from RUN_UP away, pushing in; true when she ends standing on its top.
func _climbs(m: Match, P: Hunter, home: Vector3, top: float) -> bool:
	P.teleport(Vector3(floorf(home.x) + 3.0 - RUN_UP - P.r, home.y, home.z))
	P.vel = Vector3.ZERO
	P.grounded = true
	P.mantle_cd = 0.0
	m.step(DT)
	for i in TRY_FRAMES:
		P.inp["move"] = Vector2.RIGHT
		P.inp["jump"] = i == JUMP_AT
		m.step(DT)
		if P.grounded and absf(P.pos.y - top) < 0.1:
			return true
	return false

func tall() -> void:
	for arch: String in ["archer", "gunslinger"]:
		var r := setup(arch, 7.0)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var top := _raise(m, r[4], r[5], DOUBLE_HIGH)
		var up := _climbs(m, P, r[4], top)
		var lace: bool = arch == "archer"
		var label := "combo archer: tall climb, %s %s a double-high ledge"
		ok(label % [arch, "reaches" if lace else "cannot reach"], up == lace, "up %s" % up)
		await done(m)
