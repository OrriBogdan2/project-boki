extends RefCounted
## --rig-standard-check: every Hunter's 3D model keeps the shared rig standard (docs/RIG_STANDARD.md). Per Hunter:
## the armature has the contract's bones and its variant bones, each on its rig node; the attachment points
## exist (the weapon and its muzzle, the shield, the anchors); the rest pose has the arms hanging; and the
## weapon stays in the hand in every animation state (the run, the casts, every keyed move of the kit that
## keeps a hand on the weapon): the weapon's bounds hold the trigger hand's grip, and the hand stays on it.
## Never touches the save.

const DT := 1.0 / 60.0
const SETTLE := 40             # frames a state runs before it is measured
const GRIP_ON_WEAPON := 0.06   # m: the grip may sit this far outside the weapon's bounds (seated in the hand)
const HAND_ON_GRIP := 0.09     # m: the hand may be this far off its grip while a state plays (still holds it)
const ARM_HANG := 0.45         # m: at rest a hand hangs within this of under its shoulder (no T-pose)
## Hunters that carry a shield on the left hand (HERO_ANCHORS of --warden-model-check).
const SHIELDED := ["bulwark"]
## Holds that are no weapon in the hand: a palm (Pip's lantern crook is hers by the kit) has nothing to seat.
const NO_SEAT := ["palm"]
## Each Hunter's keyed-move name prefix.
const PREFIX := {"bulwark": "bul_", "archer": "arc_", "gunslinger": "gunslinger_", "mage": "mage_", "thief": "thf_",
	"dolm": "breah_", "ostra": "ostra_", "rimewright": "tm_", "ashwick": "as_", "juggernaut": "jug", "dredge": "dr_",
	"tender": "mm_"}
const MOVE_TABLES := [HunterAnim.KMOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES, KMovesVV.MOVES, KMovesStone.MOVES,
	KMovesCare.MOVES, KMovesPair.MOVES]

var bad := 0
var holder: Node3D
var tree: SceneTree
var verbose := false

func ok(cond: bool, what: String) -> void:
	print("RIG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	verbose = OS.get_cmdline_user_args().has("--verbose")
	holder = Node3D.new()
	main.add_child(holder)
	var ids := Arch.ids()
	ok(ids.size() == 12, "12 Hunters (%d)" % ids.size())
	for id in ids:
		_hunter(String(id))
	print("RIG_STANDARD_DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

func _model(id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	return m

func _hunter(id: String) -> void:
	var m := _model(id)
	ok(m.has_node("Warden"), "%s: wears its 3D model" % id)
	if not m.has_node("Warden"):
		m.free()
		return
	_skeleton(id, m)
	_attachments(id, m)
	_rest(id, m)
	_states(id, m)
	m.free()

func _skeleton(id: String, m: Node3D) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var wrong: Array = WardenSkeleton.mismatches(sk, WardenGlb.neutral_rest(id), WardenGlb.extra_bones(id))
	ok(wrong.is_empty(), "%s: the armature is the standard one, on the rig's nodes %s" % [id, str(wrong)])

func _attachments(id: String, m: Node3D) -> void:
	var gun := m.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	var missing: Array = []
	for a in WardenGlb.ANCHORS:
		if WardenGlb.anchor(m, a) == null:
			missing.append(a)
	if gun == null or gun.get_node_or_null("Muzzle") == null:
		missing.append("Gun/Muzzle")
	if id in SHIELDED and m.get_node_or_null("Rig/Torso/ArmLPivot/Elbow/Hand/Shield") == null:
		missing.append("Shield")
	var an := HunterAnim.new(m)
	var skinned := bool(WardenClips.data(WardenGlb.art(id)).get("skinned_weapon", false))
	if skinned and WardenGlb.anchor(m, WardenGlb.WEAPON_MUZZLE) == null:
		missing.append(WardenGlb.WEAPON_MUZZLE)      # (item 76b: its FX points are empties on the skinned weapon)
	if not skinned and not an.hold in NO_SEAT and gun and gun.find_child(WardenGlb.WEAPON, true, false) == null:
		missing.append("weapon")
	ok(missing.is_empty(), "%s: carries the standard attachment points (missing %s)" % [id, str(missing)])

func _rest(id: String, m: Node3D) -> void:
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hang := 0.0
	var down := true
	for side in ["L", "R"]:
		var up := sk.get_bone_global_rest(WardenSkeleton.find(sk, "upper_arm." + side)).origin
		var hd := sk.get_bone_global_rest(WardenSkeleton.find(sk, "hand." + side)).origin
		hang = maxf(hang, absf(hd.x - up.x))
		down = down and hd.y < up.y
	ok(down and hang <= ARM_HANG, "%s: the rest pose has the arms hanging (%.2f m out)" % [id, hang])

## The states a Hunter plays: the run, the swings and casts, then every keyed move of its kit.
func _states(id: String, m: Node3D) -> void:
	var an := HunterAnim.new(m)
	var gun := an.gun
	if gun == null or an.hold in NO_SEAT:
		return
	var weapon := gun.find_child(WardenGlb.WEAPON, true, false) as Node3D
	var worst_seat := 0.0
	if weapon:
		worst_seat = _grip_off_weapon(gun, weapon, an)
		ok(worst_seat <= GRIP_ON_WEAPON, "%s: the weapon sits in the trigger hand (the grip is %.3f m off its bounds)"
				% [id, worst_seat])
	var worst := 0.0
	var where := ""
	var states: Array = [["run", {"vel": Vector3(0, 0, -4.6)}]]
	for slot in ["utility", "ult"]:
		states.append(["cast " + slot, {"cast": 0.15, "cast_slot": slot}])
	for mv in _moves(id):
		if _frees_hands(HunterAnim.km_def(mv)):
			continue
		for t in _times(HunterAnim.km_def(mv)):
			states.append([mv + " @%.2f" % t, {"kmove": mv, "kmove_t": t}])
	for st in states:
		var s: Dictionary = {"fired": 99.0, "face": 0.0, "grounded": true}
		s.merge(st[1], true)
		for k in SETTLE:
			an.update(DT, s)
		var d := _hand_off(an)
		if verbose:
			print("RIG   %s %s: hand %.3f m off its grip" % [id, st[0], d])
		if d > worst:
			worst = d
			where = String(st[0])
	ok(worst <= HAND_ON_GRIP, "%s: the hand keeps the weapon in all %d states (worst %.3f m, in %s)"
			% [id, states.size(), worst, where])

func _moves(id: String) -> Array:
	var out: Array = []
	for t in MOVE_TABLES:
		for mv in t:
			if String(mv).begins_with(PREFIX[id]):
				out.append(mv)
	return out

## A move that keys a free hand (fl, fr) lets go of the weapon on purpose (a throw, a cast from the palm).
func _frees_hands(def: Dictionary) -> bool:
	for k in def["keys"]:
		if (k[1] as Dictionary).has("fl") or (k[1] as Dictionary).has("fr"):
			return true
	return false

## Each key time of a move and the midpoint to the next.
func _times(def: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = def["keys"]
	for i in keys.size():
		out.append(float(keys[i][0]))
		if i + 1 < keys.size():
			out.append((float(keys[i][0]) + float(keys[i + 1][0])) * 0.5)
	return out

## How far the trigger hand is from the grip on the weapon (m, world).
func _hand_off(an: HunterAnim) -> float:
	var grip: Vector3 = an.hd["gr"]
	var at := an.gun.global_transform * grip
	return at.distance_to(an.hand_r.global_position)

## How far the grip is outside the weapon's meshes' bounds, in the Gun's space (m, 0 when inside).
func _grip_off_weapon(gun: Node3D, weapon: Node3D, an: HunterAnim) -> float:
	var grip: Vector3 = an.hd["gr"]
	var box := AABB()
	var first := true
	var meshes := weapon.find_children("*", "MeshInstance3D", true, false)
	if weapon is MeshInstance3D:
		meshes.append(weapon)
	for mi in meshes:
		var xf := WardenGlb.model_xf(gun, mi as Node3D)
		var bb := xf * (mi as MeshInstance3D).get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if first:
		return 0.0
	var c := grip.clamp(box.position, box.end)
	return c.distance_to(grip)
