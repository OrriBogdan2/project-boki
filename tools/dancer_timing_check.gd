extends RefCounted
## Sable's animation timing against the source (ext/anim-time-sable), run inside --dancer-combo-check
## (tools/dancer_jug_check.gd). The kit's wind-ups sit in the footage's windows (the bola's 0.4-0.6 s lane, the
## cartwheel's 0.37-0.57 s, the knife in the air one frame after its spin), each clip lasts its kit move, and the
## quick moves start on their first pose (ext/anim-sable-first-pose): the clip's frame 0 is the move's first key, not
## the settled pose, so the default blend in shows the move from its first frame. Source numbers and the table:
## docs/heroes/thief.md, "Animation timing".

const BOLA_CAST := [0.4, 0.6]       # s: footage, the lane's wind-up window
const VAULT := [0.37, 0.57]         # s: footage, the cartwheel (the Vault's flip)
const KNIFE_OUT := 0.2              # s: the dagger is in the air by one frame (0.2 s) of the spin
const LEN_TOL := 0.06               # s: a clip's length against its kit move's last key
## the quick moves (they had a short per-move blend in on ext/anim-time-sable): each clip's frame 0 is its first pose
const QUICK := ["thf_lmb_r", "thf_lmb_l", "thf_primed", "thf_vault_r", "thf_vault_l", "thf_vault_f", "thf_vault_b",
		"thf_vault_twist", "thf_exdash", "thf_land", "thf_knife", "thf_reset"]
const MOVED := 60.0                 # deg: frame 0 turns some bone this far from the settled pose
const SETTLED := "lmb_r"            # its last frame: the settled pose (END in sable_clips.py) the quick moves end on
const WHOLE := ["root", "hips"]     # bones the flips turn whole: the rest of the body keeps its own pose
var A

func run(a, m: Match, K: ThiefKit) -> void:
	A = a
	_kit(K)
	var holder := Node3D.new()
	m.add_child(holder)
	var mdl := Models.hunter(Arch.weight("thief"), Data.TEAM_COLORS[0], Arch.signature("thief"), "",
			PlayerLook.neutral(), "thief")
	holder.add_child(mdl)
	var sync := mdl.get_node("Warden").get_node("Sync") as WardenGlb.Sync
	var clips: WardenClips = sync.clips
	A.ok("dancer timing: the skinned clip tree was built", clips != null)
	if clips != null:
		_first_pose(clips)
	holder.queue_free()

## The kit's own clocks, against the footage.
func _kit(K: ThiefKit) -> void:
	var cast := float(K.rmb_def()["bola"]["cast"])
	var flip := float(HunterAnim.km_def("thf_vault_r")["keys"][-1][0])
	var knife := HunterAnim.km_def("thf_knife")["keys"] as Array
	var out_t := 1.0
	for k in knife:
		if (k[1] as Dictionary).has("fl") and absf(float((k[1] as Dictionary)["fy"])) > 6.0:
			out_t = float(k[0])
			break
	A.ok("dancer timing: the bola winds up %.2f s (footage %.1f-%.1f s)" % [cast, BOLA_CAST[0], BOLA_CAST[1]],
			cast >= BOLA_CAST[0] and cast <= BOLA_CAST[1])
	A.ok("dancer timing: the cartwheel lasts %.2f s (footage %.2f-%.2f s)" % [flip, VAULT[0], VAULT[1]],
			flip >= VAULT[0] and flip <= VAULT[1])
	A.ok("dancer timing: the knife leaves the hand by %.2f s of its spin (footage: one frame)" % out_t,
			out_t <= KNIFE_OUT)

## Each quick move's clip against its kit move: frame 0 is already the move (some bone MOVED off the settled pose, so
## the blend in shows the move from its first frame), and the clip lasts the kit move.
func _first_pose(clips: WardenClips) -> void:
	var moves: Dictionary = WardenClips.data("sable")["kmoves"]
	var settled: Array = []
	var odd: Array = []
	var faded: Array = []
	var shown: Array = []
	var rest := clips.lib.get_animation(SETTLED)
	for k in QUICK:
		var mv := moves[k] as Dictionary
		var a := clips.lib.get_animation(String(mv["clip"]))
		var off := _apart(a, 0.0, rest, rest.length)
		shown.append("%s %.0f" % [k, off])
		if off < MOVED:
			settled.append("%s %.0f deg" % [k, off])
		if mv.has("fade"):
			faded.append(k)
		var end := float(HunterAnim.km_def(k)["keys"][-1][0])
		if not mv.has("hold_from") and absf(a.length - end) > LEN_TOL:
			odd.append("%s %.2f vs %.2f" % [k, a.length, end])
	print("dancer timing: frame 0 off the settled pose, deg: ", ", ".join(shown))
	A.ok("dancer timing: each quick move's clip starts on its first pose, not settled (%s)" % str(settled),
			settled.is_empty())
	A.ok("dancer timing: the quick moves blend in at the default fade (%s)" % str(faded), faded.is_empty())
	A.ok("dancer timing: each clip lasts its kit move (%s)" % str(odd), odd.is_empty())

## The largest bone turn (deg) between clip a at t0 and clip b at t1, the whole-body bones left out.
func _apart(a: Animation, t0: float, b: Animation, t1: float) -> float:
	var worst := 0.0
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		if String(a.track_get_path(i).get_concatenated_subnames()) in WHOLE:
			continue
		var q0 := a.rotation_track_interpolate(i, t0)
		var j := b.find_track(a.track_get_path(i), Animation.TYPE_ROTATION_3D)
		if j < 0:
			continue
		var q1 := b.rotation_track_interpolate(j, t1)
		worst = maxf(worst, rad_to_deg(q0.angle_to(q1)))
	return worst
