extends RefCounted
## --aim-pitch-check: the body aims across terraces (scripts/match/aim/aim_pitch.gd, scripts/heroes/warden_aim.gd).
## The rule: an aim point 2 tiers up or down tilts the weapon by a pitch inside AimPitch.MAX, flat ground and a cliff
## past what shots climb stay flat. Per Hero with a .glb: held at that aim (the LMB hold, and an ability's cast), the
## weapon bone's pitch against the same frames on flat ground is that pitch (up +), never past the clamp; the feet
## (thighs and shins) do not move. Never touches the save.

const DT := 1.0 / 60.0
const FRAMES := 45              # past the aim ease (aim_k, the pitch's own 10/s)
const TIER := 0.8               # m: World.LEVEL
const DIST := 4.0               # m to the aim point
const TOL := 0.03               # rad
const FEET_TOL := 0.002         # m

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("AIMPITCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var up := AimPitch.rise(2.0 * TIER, DIST)
	var down := AimPitch.rise(-2.0 * TIER, DIST)
	var cap := rad_to_deg(AimPitch.MAX)
	var said := "2 tiers up at %.0f m: %.1f deg, inside the %.0f deg clamp" % [DIST, rad_to_deg(up), cap]
	ok(up > 0.1 and up <= AimPitch.MAX, said)
	ok(down < -0.1 and down >= -AimPitch.MAX, "2 tiers down: %.1f deg" % rad_to_deg(down))
	var flat_rise := AimPitch.rise(0.0, DIST) + AimPitch.rise(AimPitch.DEAD_DY, DIST)
	ok(flat_rise == 0.0, "flat ground (and a rise under the shot's own cut): 0")
	ok(AimPitch.rise(1.0, 0.1) <= AimPitch.MAX, "a cursor on your toes stays inside the clamp")
	ok(AimPitch.rise(Match.AIM_DY_MAX + 0.2, DIST) == 0.0, "a cliff past what shots climb stays flat, like the shot")
	for id in Arch.ids():
		if not WardenClips.data(WardenGlb.art(String(id))).is_empty():
			_hero(String(id), up, down)
	print("AIM_PITCH_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## One Hero held at an aim for FRAMES: the weapon bone's model-space basis, and the feet.
func _held(id: String, pitch: float, cast: bool) -> Dictionary:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	sync.set_process(false)
	var an := HunterAnim.new(m)
	var s := {"grounded": true, "fired": 0.0, "face": 0.0, "aim_pitch": pitch}
	if cast:
		s["cast"] = 0.2
		s["cast_slot"] = "utility"
	for i in FRAMES:
		an.update(DT, s)
		sync._process(DT)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var wb: int = sync.blade_bone if sync.blade_bone >= 0 else WardenSkeleton.find(sk, "hand.R")
	var to_model := m.global_basis.inverse() * sk.global_basis
	var out := {
		"basis": (to_model * sk.get_bone_global_pose(wb).basis).orthonormalized(),
		"feet": ["shin.L", "shin.R"].map(func(b): return sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin),
		"meta": float(m.get_meta(WardenAim.PITCH, 0.0)),
	}
	m.free()
	return out

func _hero(id: String, up: float, down: float) -> void:
	for cast in [false, true]:
		var what := "%s %s" % [id, "ability aim" if cast else "LMB hold"]
		var flat := _held(id, 0.0, cast)
		ok(absf(float(flat["meta"])) < 0.001, "%s: flat ground, no pitch on the body" % what)
		for want in [up, down]:
			var aimed := _held(id, want, cast)
			var r: Basis = (aimed["basis"] as Basis) * (flat["basis"] as Basis).inverse()
			var got := atan2(r.y.z, r.y.y)
			ok(absf(got) <= AimPitch.MAX + TOL and absf(got - want) <= TOL,
					"%s: weapon bone pitched %.1f deg for a %.1f deg aim" % [what, rad_to_deg(got), rad_to_deg(want)])
			var moved := 0.0
			for i in 2:
				moved = maxf(moved, ((aimed["feet"] as Array)[i] as Vector3).distance_to((flat["feet"] as Array)[i]))
			ok(moved <= FEET_TOL, "%s: feet planted (shins moved %.4f m)" % [what, moved])
