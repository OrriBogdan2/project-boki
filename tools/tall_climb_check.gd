extends "res://tools/archetype_check.gd"
## Tall-ledge climb, run from --archer-combo-check (tools/archer_bulwark_combo_check.gd adds the counts).
## climb_tall in hunter_move.json is on the source's bCanWallJump Hunters only, and every Hunter with it tops a
## double wall by jumping into it, but not 5 terraces; Lace not with her back to it. Vex, without it, still tops a
## single wall and not a double one. Prints AKCHECK lines.

const SINGLE := 2         # terraces of the single wall everyone climbs (1.6 m)
const DOUBLE_HIGH := 4    # terraces of a double wall: two single walls (3.2 m, source 3 m)
const PLAIN := "gunslinger"   # Vex: the Hunter without climb_tall
## bCanWallJump is on for Myth and Brall only (briefs/supervive-data/supervive_physics.md): Lace and Kael
const SOURCE_TALL := ["archer", "juggernaut"]
const RUN_UP := 1.2       # m from the face the jump starts
const JUMP_AT := 8        # frame of the run-up the jump key goes down
const TRY_FRAMES := 150

## Raises a wall `rise` terraces above the strip, its face 3 m east of `home`. Its tiles are plain ledges: an
## authored map's sheer cliff there can't be caught from the air (Hunter._try_ledge_grab).
func _raise(m: Match, home: Vector3, lv: int, rise: int) -> void:
	var W: World = m.world
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(3, 6):
			var i := W.idx(int(home.x) + dx, int(home.z) + dz)
			wl[i] = lv + rise
			W.sheer.erase(i)
	W.level = wl

## Raises the wall to `rise` and jumps at it from RUN_UP away, keys along `keys`: the highest she stood, in m
## above the strip (the try ends once she stands on the top).
func _stood(m: Match, P: Hunter, home: Vector3, lv: int, rise: int, keys: Vector2) -> float:
	_raise(m, home, lv, rise)
	P.teleport(Vector3(floorf(home.x) + 3.0 - RUN_UP - P.r, home.y, home.z))
	P.vel = Vector3.ZERO
	P.grounded = true
	P.lfloat = {}
	P.grap_cd = 0.0
	P.mantle_cd = 0.0
	m.step(DT)
	var best := 0.0
	for i in TRY_FRAMES:
		P.inp["move"] = keys
		P.inp["jump"] = i == JUMP_AT
		m.step(DT)
		if P.grounded:
			best = maxf(best, P.pos.y - home.y)
		if best > rise * World.LEVEL - 0.1:
			break
	return best

## One row on the hunter of `r` (setup()): she tops a wall `rise` terraces high, or with `want` false she does not.
func _row(r: Array, rise: int, want: bool, what: String, keys := Vector2.RIGHT) -> void:
	var P: Hunter = r[1]
	var best := _stood(r[0], P, r[4], r[5], rise, keys)
	var wall := rise * World.LEVEL
	var label := "combo archer: tall climb, %s %s" % [P.arch, what]
	ok(label, (best > wall - 0.1) == want, "stood %.2f of %.2f m" % [best, wall])

func tall() -> void:
	var climbers := Arch.ids().filter(func(a: String) -> bool: return bool(HunterMove.of(a).get("climb_tall", false)))
	climbers.sort()
	ok("combo archer: tall climb, climb_tall is on the source's Hunters only", climbers == SOURCE_TALL, str(climbers))
	for arch: String in climbers + [PLAIN]:
		var r := setup(arch, 7.0)
		if arch in climbers:
			_row(r, DOUBLE_HIGH, true, "reaches a double-high ledge")
			_row(r, DOUBLE_HIGH + 1, false, "cannot reach 5 terraces")
		else:
			_row(r, DOUBLE_HIGH, false, "cannot reach a double-high ledge")
			_row(r, SINGLE, true, "still reaches a single-high ledge")
		if arch == "archer":
			_row(r, DOUBLE_HIGH, false, "cannot reach it with her back to it", Vector2.LEFT)
		await done(r[0])
