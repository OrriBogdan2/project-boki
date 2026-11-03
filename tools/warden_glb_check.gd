extends RefCounted
## --warden-glb-check (docs/art/wardens/RIG_CONTRACT.md): the .glb loader's bone table covers every rig node
## HunterAnim poses; every Warden without art/wardens/<id>/<id>.glb builds the procedural model (the fallback),
## its body shown and nothing added; a Warden whose .glb exists loads it, with its body meshes hidden.

## Every node HunterAnim binds (HunterAnim._init) that a body mesh can hang on.
const ANIM_PARTS := ["Rig", "Rig/Torso", "Rig/Torso/HeadPivot", "Rig/Torso/ArmLPivot", "Rig/Torso/ArmLPivot/Elbow",
	"Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Torso/ArmRPivot", "Rig/Torso/ArmRPivot/Elbow",
	"Rig/Torso/ArmRPivot/Elbow/Hand",
	"Rig/Legs/LegL", "Rig/Legs/LegL/Knee", "Rig/Legs/LegR", "Rig/Legs/LegR/Knee", "Rig/Torso/PauldronL",
	"Rig/Torso/PauldronR", "Rig/Torso/Skirt", "Rig/Torso/Cape", "Rig/Torso/Scarf", "Rig/Torso/Tail", "Rig/Torso/Wings"]

var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("WARDENGLB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var mapped := WardenGlb.BONES.values()
	var unmapped := ANIM_PARTS.filter(func(p): return not p in mapped)
	ok(unmapped.is_empty(), "every rig node HunterAnim poses has a bone (unmapped %s)" % str(unmapped))
	ok(
		WardenGlb.path("bulwark") == "res://art/wardens/bulwark/bulwark.glb",
		"a Warden's file is art/wardens/<id>/<id>.glb"
	)
	ok(
		not WardenGlb.has_model("") and not WardenGlb.has_model("no_such_warden"),
		"no archetype, or one with no file, has no .glb"
	)
	var fallback: Array = []
	var loaded: Array = []
	for a in Arch.ids():
		var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
		var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
		if WardenGlb.has_model(a):
			if bool(m.get_meta("glb", false)) and m.has_node("Warden") and not head.visible:
				loaded.append(a)
			else:
				print("WARDENGLB %s has a .glb that did not load" % a)
		elif not bool(m.get_meta("glb", true)) and not m.has_node("Warden") and head.visible:
			fallback.append(a)
		m.free()
	ok(fallback.size() + loaded.size() == Arch.ids().size(),
			"every Warden builds: %d from their .glb %s, %d procedural (the fallback)" % [
				loaded.size(),
				str(loaded),
				fallback.size()
			])
	print("WARDENGLB %d checks, %d failed" % [n, bad])
	print("WARDENGLB_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()
