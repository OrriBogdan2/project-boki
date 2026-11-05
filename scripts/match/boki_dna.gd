class_name BokiDna
extends SkeletonModifier3D
## The inborn shapes (Unique.roll) on a rigged Boki: proportions and ear and tail shapes as a tweak over the clips, and
## the small extras (tufts, birthmark) on their bones. KinModels' bodies get these from Unique._variants.

const LEVEL_GROW := 0.3        # as Evo.dress
const SPLAY := 0.32            # rad, as Unique._variants
const FOLD := 0.8
const KINK := 0.32
const BOB := 0.7
const TUFT_SHAPE := Vector3(0.8, 1.4, 0.8)
const HIP := 0.22              # m: longer legs stand it taller by about this x the roll
const EAR_TIP := Vector3(0.218, 0.838, -0.081)    # model space (right side)
const TAIL_TIP := Vector3(0, 0.77, 0.10)
const MARKS := {"left flank": Vector3(-0.115, 0.25, 0.09), "right flank": Vector3(0.115, 0.25, 0.09),
	"back": Vector3(0, 0.335, 0.10), "chest": Vector3(0, 0.235, -0.165)}

## Grown parts that are more than one bone.
const PART_EXTRA := {}

var skel: Skeleton3D
var tweaks: Array = []         # [bone index, Basis] applied after the clip poses it
var shown: Array = []          # [bone index, size] of grown parts: at rest, instead of collapsed

## Applies a Boki's rolls (`d`, Unique.of) to its skeleton. `mats` is Models.kin's material list.
static func wear(skeleton: Skeleton3D, flex: Node3D, d: Dictionary, mats: Array, rec: Dictionary) -> void:
	var mod := BokiDna.new()
	mod.skel = skeleton
	skeleton.add_child(mod)
	mod._proportions(flex, d)
	mod._shapes(d, mats)
	mod._birthmark(d, mats)
	mod._grown(rec.get("muts", []))

func _process_modification_with_delta(_delta: float) -> void:
	for s in shown:
		var i: int = s[0]
		var rest := skel.get_bone_rest(i)
		skel.set_bone_pose(i, Transform3D(rest.basis.scaled_local(Vector3.ONE * float(s[1])), rest.origin))
	for t in tweaks:
		var i: int = t[0]
		var pose := skel.get_bone_pose(i)
		skel.set_bone_pose(i, Transform3D(pose.basis * (t[1] as Basis), pose.origin))

func _bone_rest(bone: String) -> Basis:
	return skel.get_bone_global_rest(skel.find_bone(bone)).basis.orthonormalized()

## Rotation in the creature's own axes as a tweak on a bone.
func _turn(bone: String, axis: Vector3, angle: float) -> void:
	var rest := _bone_rest(bone)
	tweaks.append([skel.find_bone(bone), rest.inverse() * Basis(axis, angle) * rest])

func _grow(bone: String, k: float) -> void:
	tweaks.append([skel.find_bone(bone), Basis.from_scale(Vector3.ONE * k)])

func _proportions(flex: Node3D, d: Dictionary) -> void:
	var ear := float(d.get("ear", 1.0))
	var limb := float(d.get("limb", 1.0))
	for sd in ["L", "R"]:
		_grow("ear1." + sd, ear)
		_grow("fleg1." + sd, limb)
		_grow("hleg1." + sd, limb)
	_grow("tail1", float(d.get("tail", 1.0)))
	flex.position.y += HIP * (limb - 1.0) * 0.9

func _shapes(d: Dictionary, mats: Array) -> void:
	var tuft_m: Material = mats[1]
	match String(d.get("ears", "standard")):
		"splayed":
			_turn("ear1.L", Vector3.BACK, SPLAY)
			_turn("ear1.R", Vector3.BACK, -SPLAY)
		"folded":
			_turn("ear2.L", Vector3.RIGHT, -FOLD)
			_turn("ear2.R", Vector3.RIGHT, -FOLD)
		"tufted":
			var tuft := Models.sphere(0.03, 6)
			_stick("ear2.L", EAR_TIP * Vector3(-1, 1, 1), tuft, tuft_m, "Tuft", TUFT_SHAPE)
			_stick("ear2.R", EAR_TIP, tuft, tuft_m, "Tuft", TUFT_SHAPE)
	match String(d.get("tailv", "standard")):
		"tufted":
			_stick("tail7", TAIL_TIP, Models.sphere(0.07, 8), tuft_m, "TailTuft", Vector3(1.0, 1.0, 0.7))
		"kinked":
			var side := 1.0 if int(d.get("mark_seed", 0)) % 2 == 0 else -1.0
			_turn("tail3", Vector3.BACK, KINK * side)
		"bobbed":
			_grow("tail1", BOB)

## Evo's mutations: each is a part of the mesh on a bone of its own, bigger with its level.
func _grown(muts: Array) -> void:
	for m in muts:
		var id := String(m["id"])
		var k := 1.0 + (int(m["lv"]) - 1) * LEVEL_GROW
		if id == "tail_long":
			_grow("tail1", 1.0 + 0.12 * k)
		_show("part_" + id, k)
		for extra in PART_EXTRA.get(id, []):
			_show(String(extra), 1.0)

func _show(bone: String, k: float) -> void:
	var i := skel.find_bone(bone)
	if i >= 0:
		shown.append([i, k])

func _birthmark(d: Dictionary, mats: Array) -> void:
	var b: Variant = d.get("birth", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() < 2 or not MARKS.has(String(b[1])):
		return
	var col := Unique._albedo(mats[0]) as Color
	col = col.darkened(0.5) if col.v > 0.45 else col.lightened(0.55)
	var at: Vector3 = MARKS[String(b[1])]
	var mark := _stick("hips", at, Models.sphere(0.05, 8), Models.toon(col, false), "Birthmark", Vector3(0.9, 0.9, 0.9))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A small mesh on a bone, at `at` in the model's rest pose.
func _stick(bone: String, at: Vector3, mesh: Mesh, mat: Material, node_name: String, scl: Vector3) -> MeshInstance3D:
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone
	skel.add_child(hold)
	var local := skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * at
	return Models.part(hold, mesh, mat, local, scl, Vector3.ZERO, node_name)
