extends RefCounted
## Sable's animation timing against the source (ext/anim-time-sable), run inside --dancer-combo-check
## (tools/dancer_jug_check.gd). The kit's wind-ups sit in the footage's windows (the bola's 0.4-0.6 s lane, the
## cartwheel's 0.37-0.57 s, the knife in the air one frame after its spin), each clip lasts its kit move, and the
## blend into a move never hides its release: on a standing Sable the skinned clip owns the body, as the new
## channel, by the move's first key. Source numbers and the table: docs/heroes/thief.md, "Animation timing".

const DT := 1.0 / 60.0
const BOLA_CAST := [0.4, 0.6]       # s: footage, the lane's wind-up window
const VAULT := [0.37, 0.57]         # s: footage, the cartwheel (the Vault's flip)
const KNIFE_OUT := 0.2              # s: the dagger is in the air by one frame (0.2 s) of the spin
const SEEN := 0.9                   # share of the clip on show by the move's first key
const LEN_TOL := 0.06               # s: a clip's length against its kit move's last key
## move -> the s by which the blend must have shown the clip (its first key or release)
const BY := {"thf_lmb_r": 0.04, "thf_lmb_l": 0.04, "thf_primed": 0.04, "thf_vault_r": 0.05, "thf_vault_l": 0.05,
		"thf_vault_f": 0.05, "thf_vault_b": 0.05, "thf_vault_twist": 0.05, "thf_exdash": 0.05, "thf_land": 0.04,
		"thf_knife": 0.09, "thf_reset": 0.05, "thf_bola": 0.42, "thf_encore": 0.4}
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
		_blend(mdl, sync, clips)
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

## A standing Sable from rest: how much of the move's clip is on show at each move's first key, and each clip's
## length against the kit move's.
func _blend(mdl: Node3D, sync: WardenGlb.Sync, clips: WardenClips) -> void:
	var an := HunterAnim.new(mdl)
	var st := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	var moves: Dictionary = WardenClips.data("sable")["kmoves"]
	var late: Array = []
	var odd: Array = []
	for k in BY:
		_play(an, sync, st, 40)
		var s2 := st.duplicate()
		s2["kmove"] = k
		var seen := 0.0
		var at := 0.0
		while at < float(BY[k]) - 0.0001:
			s2["kmove_t"] = at
			_play(an, sync, s2, 1)
			at += DT
		seen = clips.act_w * (clips.xf if clips.chan == 1 else 1.0 - clips.xf)
		if seen < SEEN:
			late.append("%s %.2f" % [k, seen])
		var cl: String = (moves[k] as Dictionary)["clip"]
		var end := float(HunterAnim.km_def(k)["keys"][-1][0])
		if not (moves[k] as Dictionary).has("hold_from") and absf(clips.lib.get_animation(cl).length - end) > LEN_TOL:
			odd.append("%s %.2f vs %.2f" % [k, clips.lib.get_animation(cl).length, end])
	A.ok("dancer timing: each move's clip is on show by its first key (%s)" % str(late), late.is_empty())
	A.ok("dancer timing: each clip lasts its kit move (%s)" % str(odd), odd.is_empty())

func _play(an: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, n: int) -> void:
	for i in n:
		an.update(DT, s)
		sync._process(DT)
