extends RefCounted
## --contact-check: the v95-swapped Hunters (docs/heroes/V95_CONTACT.md). For LMB, RMB and one signature move each:
## the kit's hit (seconds into the move, from its kit) plus the move's "lead" (warden_anim) is the clip time the game
## shows at the hit. The clip's own contact is a strong tip stroke (the Muzzle's speed against the body), from its
## peak to where the tip has slowed down; the hit must lie within CONTACT_S of one.
## Prints "CONTACT" lines; a move more than CONTACT_S off fails.

const CONTACT_S := 0.05    # s: how far the hit may sit from the clip's own contact
const DT := 1.0 / 60.0
const FIRST_K := 0.4       # a stroke is a tip peak at least this share of the window's fastest
const END_K := 0.25        # the stroke is over when the tip is down to this share of its peak speed
const MIN_STROKE := 4.0    # m/s: a clip whose tip never moves this fast has no strike stroke
const STROKE_S := 0.35     # s: the window the strike is looked for in: the clip's start to this long after the hit
## hero id -> [[kit move, kit hit s into the move, label], ...]: LMB, RMB, a signature move
const HITS := {
	"gunslinger": [["gunslinger_lmb", 0.0, "LMB"], ["gunslinger_rmb", 0.0, "RMB"], ["gunslinger_x", 0.14, "X"]],
	"ashwick": [["as_lance", 0.2, "LMB"], ["as_shot", 0.0, "RMB"], ["as_cloak", 0.0, "E"]],
	"thief": [["thf_lmb_r", 0.0, "LMB"], ["thf_bola", 0.4, "RMB"], ["thf_knife", 0.12, "E"]],
	"juggernaut": [["jug_slash_r", 0.0, "LMB"], ["jug_slam", 0.6, "RMB"], ["jug_wave", 0.0, "LMB held"]],
	"bulwark": [["bul_smash", 0.0, "LMB"], ["bul_slamshield", 0.0, "RMB"], ["bul_ult_slam", 0.0, "X"]],
	"tender": [["mm_shot_r", 0.0, "LMB"], ["mm_seed", 0.0, "RMB"], ["mm_hearth", 0.0, "E"]],
	"ostra": [["ostra_orb", 0.0, "LMB"], ["ostra_snap", 0.0, "RMB"], ["ostra_swap", 0.0, "E"]],
	"rimewright": [["tm_dart_r", 0.0, "LMB"], ["tm_spear", 0.0, "RMB"], ["tm_freeze", 0.0, "E"]],
	"mage": [["mage_lmb_r", 0.0, "LMB"], ["mage_rmb", 0.0, "RMB"], ["mage_e_snap", 0.0, "E"]],
}

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	var holder := Node3D.new()
	main.add_child(holder)
	for id in HITS:
		await _hero(holder, String(id))
	print("CONTACT_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(holder: Node3D, id: String) -> void:
	var dd := WardenClips.data(WardenGlb.art(id))
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var tip := sync.get("muzzle") as Node3D
	for hit in HITS[id]:
		var mv: Dictionary = dd["kmoves"][hit[0]]
		var clip := String(mv["clip"])
		var length := clips.lib.get_animation(clip).length
		var at := minf(float(hit[1]) + float(mv.get("lead", 0.0)), length - 0.001)
		var track: Array = []
		clips.force = {"clip": clip, "t": 0.0}      # (settled on its first frame: no blend from the last clip)
		for k in 30:
			sync.call("_process", 0.05)
		var t := 0.0
		while t <= length:
			clips.force = {"clip": clip, "t": t}
			for k in 3:
				sync.call("_process", DT)
			await holder.get_tree().process_frame
			track.append(tip.global_position - m.global_position)
			t += DT
		clips.force = {}
		var speed: Array = [0.0, 0.0]
		for i in range(2, track.size()):
			speed.append(((track[i] as Vector3) - (track[i - 1] as Vector3)).length() / DT)
		var st := _stroke(speed, at)
		var near := clampi(int(round(at / DT)), st[0], st[1])
		var off: float = st[2]
		var pass_it := off <= CONTACT_S
		print("CONTACT %s %-5s %-16s %-14s hit %.3f s (lead %.2f), strike %.3f..%.3f s, off %.3f s, tip %.3f m "
				% ["ok  " if pass_it else "FAIL", hit[2], hit[0], clip, at, float(mv.get("lead", 0.0)),
				st[0] * DT, st[1] * DT, off, (track[int(round(at / DT))] as Vector3).distance_to(track[near])]
				+ "from the strike pose, %s" % ("PASS" if off <= CONTACT_S else "FAIL"))
		if not pass_it:
			bad += 1
	m.free()

## The strong tip stroke nearest the hit: [first frame, last frame, seconds the hit lies off it].
func _stroke(speed: Array, at: float) -> Array:
	var last := mini(speed.size() - 2, int((at + STROKE_S) / DT))
	var top := 0.0
	for i in range(2, last + 1):
		top = maxf(top, float(speed[i]))
	if top < MIN_STROKE:      # a smooth reach, no snap to measure: the pose at the hit is the contact
		return [2, 2, 0.0]
	var out := [2, 2, 99.0]      # (no stroke: the clip opens on the strike, its first frame is the contact)
	for i in range(2, last + 1):
		var v := float(speed[i])
		if v < FIRST_K * top or v <= float(speed[i + 1]) or (i > 2 and v < float(speed[i - 1])):
			continue
		var end := i      # the stroke is over where the tip is down to END_K of its peak
		while end < speed.size() - 1 and float(speed[end]) > END_K * v:
			end += 1
		var gap := maxf(maxf(i - at / DT, at / DT - end), 0.0) * DT
		if gap < float(out[2]):
			out = [i, end, gap]
	return out
