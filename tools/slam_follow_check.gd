extends RefCounted
## --slam-follow-check: the slams' follow-through on the clips (docs/art/SLAM_FOLLOW.md). Each slam clip is driven
## through WardenClips on the kit's clock (60 fps, the move it comes out of first) and its strike point (the blade's
## tip or the fist) is traced: the impact (the strike's stop), how long it holds there, the recoil after, and when the
## body is handed back to the legs, against the kit's hit and the end of its keys (HunterAnim.km_def, the recover).
## --shots-dir=<dir> (GPU): also every 3rd frame of each slam from 0.2 s before the hit, as the clips play it now
## and without its follow-through keys (time, fade, blend_out): <dir>/<move>/{after,before}/f000.png.
## Never touches the save.

const DT := 1.0 / 60.0
const STRIKE_F := 18          # frames before the kit's hit the strike is looked for
const HOLD_V := 1.5            # m/s: the strike point slower than this (2.5 cm a frame) has stopped: the impact
const HOLD_R := 0.03           # m: the impact pose holds while the strike point stays this close to where it stopped
const WHIP := 20.0             # m/s: the strike point's fastest frame while the body goes back to the legs
const LAND_EARLY := 2          # frames the impact may land before the kit's hit (the swing reads into it)
const LAND_LATE := 3           # frames it may land after
const HOLD := [3, 9]           # frames the impact pose holds, at least and at most (a beat, not a freeze)
const RECOVER_OFF := 0.05      # s: the body is back on the legs within this of the kit's recover
## [Hero id, kit move, the move it comes out of ("" none), strike point ("tip" or a bone), the kit's hit (s)]
const SLAMS := [
	["juggernaut", "jug_slam", "", "tip", 0.6],
	["juggernaut", "jug_meteor_land", "jug_meteor", "tip", 0.0],
	["dolm", "breah_slam", "breah_crouch", "hand.R", 0.6],
	["dolm", "breah_slam_land", "", "hand.R", 0.0],
	["dredge", "dr_anchor", "", "hand.L", 0.38],
	["dredge", "dr_quake", "dr_dive", "hand.L", 0.0],
	["bulwark", "bul_smash", "bul_smash_wind", "tip", 0.0],
	["bulwark", "bul_ult_slam", "bul_ult_wind", "tip", 0.0],
]

const SHOT_KEYS := ["time", "fade", "blend_out"]
var bad := 0
var holder: Node3D
var shots := ""
var stage: RefCounted      # (the clip shots' stage: sky, light, ground, camera)

func ok(cond: bool, what: String) -> void:
	print("SLAM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
	if shots != "":
		await _stage(main)
	for sl in SLAMS:
		await _slam(sl, false)
		if shots != "":
			await _slam(sl, true)
	print("SLAM_FOLLOW_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _stage(main: Node) -> void:
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(240, 240)
	main.get_viewport().size = Vector2i(240, 240)
	stage = load("res://tools/clip_shots.gd").new()
	stage.set("tree", main.get_tree())
	stage.call("_stage", main)
	var cam: Camera3D = stage.get("cam")
	cam.fov = 30.0
	cam.position = Vector3(0, 1.4, 7.0)
	cam.look_at(Vector3(0, 1.0, 0))
	for k in 30:
		await main.get_tree().process_frame       # (past the title's fade)

## (before: the move without its follow-through keys, shots only)
func _slam(sl: Array, before: bool) -> void:
	var id := String(sl[0])
	var km := String(sl[1])
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if before:
		clips.d = clips.d.duplicate(true)
		for k in SHOT_KEYS:
			(clips.d["kmoves"][km] as Dictionary).erase(k)
	m.rotation.y = deg_to_rad(110.0)
	var dir := shots.path_join(km).path_join("before" if before else "after")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var tip := sync.get("blade_tip") as Node3D
	var bi := -1 if String(sl[3]) == "tip" else WardenSkeleton.find(sk, String(sl[3]))
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var t := 0.0
	while t < 0.5:        # standing, then the move it comes out of
		if sl[2] != "" and t >= 0.2:
			s["kmove"] = sl[2]
			s["kmove_t"] = t - 0.2
		sync.call("_process", DT)
		t += DT
	var end_t := float(HunterAnim.km_def(km)["keys"][-1][0])
	var ps: Array = []
	var speeds: Array = []
	var handed := -1.0
	var last := Vector3.INF
	t = 0.0
	while t < end_t + 0.4:
		s["kmove"] = km
		s["kmove_t"] = t
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		var p := tip.global_position if bi < 0 else sk.global_transform * sk.get_bone_global_pose(bi).origin
		speeds.append(0.0 if last == Vector3.INF else p.distance_to(last) / DT)
		ps.append(p)
		last = p
		if handed < 0.0 and t > 0.0 and clips.act_w <= 0.0 and clips.up_w <= 0.0:
			handed = t
		var f := roundi(t / DT)
		if shots != "" and f % 3 == 0 and t >= float(sl[4]) - 0.2:
			await stage.call("_grab", dir.path_join("f%03d.png" % f))
		t += DT
	m.free()
	if not before:
		_judge(id, km, float(sl[4]), end_t, ps, speeds, handed)

## The impact: the strike's fastest frame in the beat before the kit's hit, then its first still frame. The hold runs
## while it stays put; the recoil is how far it springs back up in the 0.3 s after; the blend-out is its fastest
## frame while the body goes back to the legs (a whip there undoes the weight).
func _judge(id: String, km: String, hit: float, end_t: float, ps: Array, speeds: Array, handed: float) -> void:
	var hf := roundi(hit / DT)
	var top := maxi(hf - STRIKE_F, 1)
	for i in range(top, mini(hf + LAND_LATE, speeds.size() - 1) + 1):
		if float(speeds[i]) > float(speeds[top]):
			top = i
	var at := top
	while at < speeds.size() - 1 and float(speeds[at]) >= HOLD_V:
		at += 1
	var hold := 0
	while at + hold < ps.size() and (ps[at + hold] as Vector3).distance_to(ps[at]) < HOLD_R:
		hold += 1
	var after := at + hold
	var recoil := 0.0
	for i in range(after, mini(after + int(0.3 / DT), ps.size())):
		recoil = maxf(recoil, (ps[i] as Vector3).y - (ps[at] as Vector3).y)
	var whip := 0.0
	for i in range(roundi((end_t - 0.3) / DT), speeds.size()):
		whip = maxf(whip, float(speeds[i]))
	var lands := at - hf
	var rec := end_t - hit
	var shown := (handed if handed >= 0.0 else 99.0) - hit
	print(("SLAM %s %s: strike %.0f m/s at f%d, impact f%d (kit hit f%d, %+d), hold %d f, recoil %.2f m, "
			+ "blend-out top %.1f m/s, back to the legs %.2f s after the hit (kit recover %.2f s)")
			% [id, km, float(speeds[top]), top, at, hf, lands, hold, recoil, whip, shown, rec])
	ok(lands >= -LAND_EARLY and lands <= LAND_LATE,
			"%s %s: the impact lands on the kit's hit (%+d f)" % [id, km, lands])
	ok(hold >= HOLD[0] and hold <= HOLD[1], "%s %s: the impact holds %d f (%d-%d)" % [id, km, hold, HOLD[0], HOLD[1]])
	ok(absf(shown - rec) <= RECOVER_OFF,
			"%s %s: back to the legs on the kit's recover (%.2f vs %.2f s)" % [id, km, shown, rec])
	ok(whip <= WHIP, "%s %s: no whip going back to the legs (%.1f m/s, at most %.0f)" % [id, km, whip, WHIP])
