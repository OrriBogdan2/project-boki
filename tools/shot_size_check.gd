extends RefCounted
## --shot-size-check: every Hunter's LMB projectile keeps a readable core at the default camera distance.
## Fires each of the 12 kits' primary at a dummy, then reads the radius of the shot's visual floor
## (ShotFloor's hot core inside a side-coded rim) and converts it to screen pixels at 720p and 1080p
## with the default camera, at the farthest a shot can be in view, against ShotFloor.MIN_CORE_PX (1.5x at
## 1080p); tools/shot_size_shots.gd measures it on rendered frames. Also asserts the beacon is visual only
## (the shot's hit radius is the same before and after it is drawn) and that a foe's rim reads differently
## from a friend's.
## Prints SHOTSIZE PASS/FAIL and a DONE line.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const HEROES := [
	"gunslinger", "juggernaut", "ashwick", "tender", "dolm", "archer", "dredge", "rimewright", "mage", "bulwark",
	"thief", "ostra",
]
const MELEE := ["juggernaut", "bulwark"]      # their primary is a swing, not a projectile (checked as such)
const HOLD := {"archer": 0.7}                # s of LMB held before the release (a drawn bow); the rest tap
const STREAM := ["ashwick"]                   # a flame stream, drawn as fire not as a shot (checked as such)

func ok(name_: String, cond: bool, info := "") -> void:
	n += 1
	print("SHOTSIZE %-44s %s  %s" % [name_, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## On-screen pixels across `radius` metres at the farthest point in the default view, a screen `h_px` tall.
static func px_across(radius: float, h_px: float) -> float:
	return radius * 2.0 * ShotFloor.px_per_m(ShotFloor.far_depth(), h_px)

func run(main_node: Node) -> void:
	main = main_node
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	for arch in HEROES:
		await _hero(ac, arch)
	print("SHOTSIZE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _hero(ac: RefCounted, arch: String) -> void:
	var rig: Array = ac.setup(arch, 14.0)
	var m: Match = rig[0]
	var P: Hunter = rig[1]
	var T: Hunter = rig[2]
	var found := {}
	var held := 0.0
	var t := 0.0
	while t < 1.6 and found.is_empty():
		P.inp["fire"] = held < float(HOLD.get(arch, 0.1))      # a tap, or the draw a bow needs
		held += DT
		ac.step(m, DT)
		t += DT
		for s in m.shots:
			if s["by"] == P and ShotFloor.wants(s):
				found = s
				break
	P.inp["fire"] = false
	var tag := "%s LMB" % arch
	if found.is_empty():
		ok(tag + " fires a shot", arch in MELEE or arch in STREAM, "no projectile (swing or stream)")
		await ac.done(m)
		return
	var r_hit: float = found["r"]
	m.shot_floor.sync(1.0)
	var beacon: MeshInstance3D = null
	for b in m.shot_floor.pool:
		if b.visible and b.global_position.distance_to(found["pos"]) < 0.01:
			beacon = b
	ok(tag + " has a beacon on the shot", beacon != null)
	if beacon != null:
		var r_core: float = (beacon.mesh as SphereMesh).radius
		var p720 := px_across(r_core, 720.0)
		var p1080 := px_across(r_core, 1080.0)
		var own := px_across(float(found.get("vr", 0.0)), 720.0)      # its sphere's radius (0 under a kit skin)
		var info := "%.1f px (own sphere %.1f)" % [p720, own]
		ok(tag + " core >= floor at 720p", p720 >= ShotFloor.MIN_CORE_PX - 0.01, info)
		ok(tag + " core >= floor at 1080p", p1080 >= ShotFloor.MIN_CORE_PX * 1.5 - 0.01, "%.1f px" % p1080)
		var rim_mat := ShotFloor.rim_mat(beacon)
		var rim_mine: Color = rim_mat.get_shader_parameter("color")      # (the player's own shot: a friend's)
		var rim_core := (beacon.get_child(0) as MeshInstance3D).mesh as SphereMesh
		ok(tag + " rim wider than core", rim_core.radius > r_core)
		found["by"] = T      # the same shot, fired by the opposing team
		m.shot_floor.sync(1.0)
		var rim_foe: Color = rim_mat.get_shader_parameter("color")
		var coded := not rim_foe.is_equal_approx(rim_mine)
		ok(tag + " rim is side-coded", coded, "%s vs %s" % [rim_foe.to_html(), rim_mine.to_html()])
		found["by"] = P
	ok(tag + " hit radius unchanged by the beacon", is_equal_approx(float(found["r"]), r_hit), "%.3f m" % r_hit)
	await ac.done(m)
