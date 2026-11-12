extends RefCounted
## Part of --boki-anim-audit: every rigged Boki in every state the game plays (home, the garden games, a match and
## its summon), driven through the live BokiRig by the metas and speeds the game sets. Each state must resolve to a
## clip the Boki has, that is not a T-pose, and to the one ROWS names. The table (and the states that would still
## need a clip of their own) is in docs/art/kin/RIGGED_BOKI.md "State coverage".
##   want    the clip the state would have if it had one of its own
##   expect  the clip that plays (equal to want: authored or retargeted; else a fallback; "proc": KinFlinch)
##   metas   what the game sets on the model root; speed: m/s it moves; keep: the clip's shot is still running

const Shots := preload("res://tools/boki_rig_shots.gd")
const Check := preload("res://tools/boki_rig_check.gd")
const BAKED := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry",
	"tend"]
const MOVE_M := 0.002              # m a bone must shift over a clip to count as moving (rotations: Check.T_POSE rad)
const KEYS := ["kstate", "kwork", "kact", "kdown", "happy", "dazed"]
const ROWS := [
	{"s": "idle", "at": "home, garden, match", "want": "idle", "expect": "idle"},
	{"s": "walk", "at": "home, match", "want": "walk", "expect": "walk", "speed": 1.5},
	{"s": "run", "at": "home fetch, match", "want": "run", "expect": "run", "speed": 4.4},
	{"s": "joy", "at": "home, match cheer", "want": "hop", "expect": "hop", "metas": {"happy": true}},
	{"s": "perch", "at": "match, on a shoulder", "want": "idle", "expect": "idle", "metas": {"kstate": "perch"}},
	{"s": "attack", "at": "match", "want": "attack", "expect": "attack", "metas": {"kstate": "attack"}},
	{"s": "ability", "at": "match", "want": "ability", "expect": "ability", "pulse": true},
	{"s": "hit", "at": "match", "want": "hit", "expect": "idle", "proc": true},
	{"s": "stun", "at": "match", "want": "stun", "expect": "idle", "metas": {"dazed": true}},
	{"s": "summon throw", "at": "match", "want": "fly", "expect": "run", "speed": 9.0},
	{"s": "summon recall", "at": "match", "want": "run", "expect": "run", "speed": 6.0},
	{"s": "faint", "at": "match", "want": "faint", "expect": "settle", "metas": {"kdown": true}, "keep": true},
	{"s": "faint held", "at": "match", "want": "faint", "expect": "nap", "metas": {"kdown": true}},
	{"s": "revive", "at": "match", "want": "revive", "expect": "wake", "keep": true},
	{"s": "settle", "at": "home", "want": "settle", "expect": "settle", "metas": {"kstate": "sleep"}, "keep": true},
	{"s": "nap", "at": "home", "want": "nap", "expect": "nap", "metas": {"kstate": "sleep"}},
	{"s": "wake", "at": "home", "want": "wake", "expect": "wake", "keep": true},
	{"s": "chop", "at": "home", "want": "chop", "expect": "chop", "metas": {"kwork": "chop"}},
	{"s": "mine", "at": "home", "want": "mine", "expect": "mine", "metas": {"kwork": "mine"}},
	{"s": "carry", "at": "home", "want": "carry", "expect": "carry", "metas": {"kwork": "carry"}},
	{"s": "tend", "at": "home", "want": "tend", "expect": "tend", "metas": {"kwork": "tend"}},
	{"s": "munch", "at": "home feeder", "want": "munch", "expect": "munch", "metas": {"kact": "munch"}},
	{"s": "ball", "at": "home toy", "want": "nudge", "expect": "nudge", "metas": {"kact": "nudge"}},
	{"s": "post", "at": "home toy", "want": "climb", "expect": "climb", "metas": {"kact": "climb"}},
	{"s": "tub, wade", "at": "home toy, garden", "want": "splash", "expect": "splash", "metas": {"kact": "splash"}},
	{"s": "Tumble rush", "at": "garden", "want": "rush", "expect": "rush", "metas": {"kact": "rush"}},
	{"s": "Tumble brace", "at": "garden", "want": "brace", "expect": "brace", "metas": {"kact": "brace"}},
	{"s": "Tumble dodge", "at": "garden", "want": "dodge", "expect": "dodge", "metas": {"kact": "dodge"}},
	{"s": "Echo hop", "at": "garden", "want": "stonehop", "expect": "stonehop", "metas": {"kact": "stonehop"}},
	{"s": "Echo spin", "at": "garden", "want": "spin", "expect": "spin", "metas": {"kact": "spin"}},
	{"s": "Relay run", "at": "garden", "want": "run", "expect": "run", "speed": 6.0, "burst": true},
	{"s": "Relay bump", "at": "garden", "want": "nudge", "expect": "nudge", "relay": RelayBeats.CLIP_BUMP},
	{"s": "Relay brace", "at": "garden", "want": "brace", "expect": "brace", "relay": RelayBeats.CLIP_BRACE},
	{"s": "Relay duo tap", "at": "garden", "want": "stonehop", "expect": "stonehop", "relay": RelayBeats.CLIP_DUO},
	{"s": "Relay win", "at": "garden", "want": "win", "expect": "hop", "relay": RelayBeats.CLIP_WIN},
	{"s": "Relay sulk", "at": "garden", "want": "sulk", "expect": "idle", "relay": RelayBeats.CLIP_SULK},
]

var bad := 0
var _seen := {}                    # states whose table line is printed

func ok(cond: bool, what: String) -> void:
	print("BOKICOVER %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

## One species through every row; its clips are then checked for a T-pose.
func species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	var used := {}
	for row: Dictionary in ROWS:
		var clip := _play(k, rig, row)
		used[clip] = true
		var has := rig.player.has_animation(clip) and rig.player.get_animation(clip).length > 0.1
		ok(has and clip == row["expect"], "%s: %s plays %s" % [id, row["s"], clip])
		_row(row)
		if row.get("proc", false):
			ok(_flinches(k, rig), "%s: a hit springs its body (KinFlinch)" % id)
	for clip: String in used:
		ok(_moves(rig, clip), "%s: %s leaves the bind pose and moves" % [id, clip])
	k.queue_free()

## The clip the rig picks for `row`, after the game's metas for it are set.
func _play(k: Node3D, rig: BokiRig, row: Dictionary) -> String:
	for key in KEYS:
		k.remove_meta(key)
	for key: String in row.get("metas", {}):
		k.set_meta(key, row["metas"][key])
	if row.get("pulse", false):
		k.set_meta("pulse", rig._pulse + 1)
	if not row.get("keep", false):
		rig._shot_left = 0.0
	rig._speed = float(row.get("speed", 0.0))
	if row.has("relay"):
		RelayBeats._play(k, row["relay"])
	rig._pick_clip(0.016)
	var clip := rig.clip
	if row.get("burst", false):
		k.set_meta("kburst", 1.6)
		rig._pick_clip(0.016)
		k.remove_meta("kburst")
	return clip

## False for a clip that never leaves the bind pose (a T-pose) or holds one pose (frozen). A one-shot may start and
## end on the bind pose, so only the farthest sampled frame counts.
func _moves(rig: BokiRig, clip: String) -> bool:
	var skel := rig.skeleton()
	rig.clip = ""                      # play it afresh, so no fade from the clip before blends in
	rig.set_clip(clip, 0.0)
	var length := rig.player.get_animation(clip).length
	var far := 0.0
	var spread := 0.0
	var first: Array = []
	var first_at: Array = []
	for f in Check.T_FRAMES + 1:
		rig.seek(length * float(f) / float(Check.T_FRAMES))
		for b in skel.get_bone_count():
			var q := skel.get_bone_pose_rotation(b)
			far = maxf(far, q.angle_to(skel.get_bone_rest(b).basis.get_rotation_quaternion()))
			var at := skel.get_bone_pose_position(b)
			if f == 0:
				first.append(q)
				first_at.append(at)
			else:
				spread = maxf(spread, maxf(q.angle_to(first[b]), at.distance_to(first_at[b]) / MOVE_M * Check.T_POSE))
	return far >= Check.T_POSE and spread >= Check.T_POSE

func _flinches(k: Node3D, rig: BokiRig) -> bool:
	KinFlinch.hit(k, Vector3(0, 0, 1), 0.3, 1.0)
	rig._flinch.update(rig.root, 0.05)
	rig._keep_flex()
	return rig.flex.rotation.length() > 0.001 or not rig.flex.scale.is_equal_approx(Vector3.ONE)

## The table line, once per state (a row asserts the same clip for every species).
func _row(row: Dictionary) -> void:
	var kind := "authored" if row["expect"] in BAKED else "retargeted"
	if row["expect"] != row["want"]:
		kind = "fallback, " + kind
	if row.get("proc", false):
		kind = "proc"
	var s: String = row["s"]
	if _seen.has(s):
		return
	_seen[s] = true
	print("BOKICOVER ROW %s | %s | %s | %s" % [s, row["at"], row["expect"], kind])
