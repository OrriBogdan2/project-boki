class_name WardenGlb
extends RefCounted
## A Warden's 3D model (docs/art/wardens/RIG_CONTRACT.md): when art/wardens/<name>/<name>.glb exists and the
## player hasn't set that Warden to procedural (Settings > Video > Warden models), the procedural hunter
## Models.hunter built keeps its rig, weapon, glider and hit ring but hides its body, and the .glb's armature
## (WardenSkeleton) follows the rig nodes HunterAnim poses, one bone per node (BONES), so every kit move
## plays on it. Otherwise the procedural model stays as it is: the fallback.

const DIR := "res://art/wardens"
## Each Warden's art name, as in docs/art/gen/wardens/<name>_turnaround.png: the folder and file its .glb has.
const ART := {"bulwark": "bjorn", "archer": "pin", "juggernaut": "zedran", "gunslinger": "vex", "ostra": "ostra",
	"mage": "vireo", "dolm": "tarek", "thief": "sable", "rimewright": "claire", "ashwick": "cinder",
	"tender": "moosh", "dredge": "dredge"}
## Armature bone -> the rig node it follows (paths under the model root).
const BONES := {
	"root": "Rig",
	"hips": "Rig/Torso",
	"head": "Rig/Torso/HeadPivot",
	"upper_arm.L": "Rig/Torso/ArmLPivot",
	"forearm.L": "Rig/Torso/ArmLPivot/Elbow",
	"hand.L": "Rig/Torso/ArmLPivot/Elbow/Hand",
	"upper_arm.R": "Rig/Torso/ArmRPivot",
	"forearm.R": "Rig/Torso/ArmRPivot/Elbow",
	"hand.R": "Rig/Torso/ArmRPivot/Elbow/Hand",
	"thigh.L": "Rig/Legs/LegL",
	"shin.L": "Rig/Legs/LegL/Knee",
	"thigh.R": "Rig/Legs/LegR",
	"shin.R": "Rig/Legs/LegR/Knee",
	"pauldron.L": "Rig/Torso/PauldronL",
	"pauldron.R": "Rig/Torso/PauldronR",
	"skirt": "Rig/Torso/Skirt",
	"cape": "Rig/Torso/Cape",
	"scarf": "Rig/Torso/Scarf",
	"tail": "Rig/Torso/Tail",
	"wings": "Rig/Torso/Wings",
}
const OPTIONAL := ["cape", "scarf", "tail", "wings"]
## Procedural pieces that stay when the .glb dresses the hunter (the contract's "nodes the game keeps").
const KEEP := ["Gun", "Glider", "TeamRing", "Shield", "Shoulder", "Halo", "Focus"]
## glTF material name -> the toon shader's painted surface (RIG_CONTRACT "Materials").
const SLOTS := {"skin": 4, "hair": 5, "cloth": 1, "leather": 2, "metal": 3, "fur": 5, "eyes": 0, "team": 1, "glow": 0}
## Slots a MantleLook colour pick tints: slot -> [the pick in Models.hunter's look, the Warden's own colour].
const TINTS := {"skin": ["skin_col", "skin"], "hair": ["hair_col", "hair_col"], "eyes": ["eye_col", "eyes"]}
const TINT_MAX := 0.35         # a pick moves a painted slot's colour at most this much (x, per channel)
const NO_INK := ["hair", "eyes", "glow"]   # slots drawn without the ink outline shell
## Pieces built as clean geometry (tools/meshy/warden_parts.py), "<slot>-<tag>": they take the ink line even on
## an inkless slot (the hair goes without it for a scan's ragged strands, not for a woven braid).
const INK_TAGS := ["braid"]
## The hero toon shader on a painted atlas, which carries its own light and shade: the toon light on top stays
## soft and near white (no violet shadow, no warm terminator band, no sun self-shadow, no brushwork), so the
## model reads as bright as its paint, as the art does; the shadow floor is 0.37 on a procedural hero.
const PAINTED := {"shade": 0.86, "ramp": 2.6, "shadow_tint": Color(0.97, 0.94, 0.95), "shadow_sat": 0.0, "sss": 0.0,
	"sky_ao": 0.12, "self_shadow": 0.0, "surface": 0, "paint": 0.0, "fres": 1.7, "fres_tint": 0.8, "rim_amount": 0.6,
	"top_light": 1.6, "far_lift": 0.3}
const GLOW := 1.6              # emission of the glow slot (mechanical eyes, cracks), x its painted colour
## The ink shell on a painted atlas: half the procedural heroes' width per metre of camera distance (the same
## 4 mm line close up). At the match camera a full-width line round every belt, buckle and candle of a scanned
## model added up to a dark smudge.
const INK_WIDTH := 0.0006
static var _ink: ShaderMaterial
## Empties every .glb exports on its bones (RIG_CONTRACT "Anchor empties"); kits find them with anchor().
const ANCHORS := ["anchor_head_top", "anchor_chest"]
## Settings key: Warden id -> "procedural" for a Warden the player keeps on its procedural model (or a design
## variant's name, art()).
const SETTING := "warden_models"
const WEAPON := "weapon"        # the .glb node that replaces the procedural weapon (RIG_CONTRACT)
const WEAPON_MAG := "weapon_mag"  # its magazine, a child of it
const WEAPON_SPIN := "weapon_spin"  # its spinning barrels, a child of it (HunterAnim spins them while firing)

static var _neutral := {}       # Warden id -> the rig rest of its model in the neutral look (what a .glb is built on)
static var _measuring := false  # building that neutral model: no .glb on it
static var _variants = null     # art name -> the design variant the command line picks (variant())

static func path(arch: String) -> String:
	var nm := art(arch)
	return "%s/%s/%s.glb" % [DIR, nm, nm]

## The folder and file name of a Warden's model: its art name, or a design variant picked for it. A variant is
## another design of the same Warden, built on the same rig and kept beside the shipped model so the two can be
## compared in game (art/wardens/<art>_<tag>/<art>_<tag>.glb, e.g. vex_r3b): `--warden-variant=vex_r3b`
## (comma-separated for several) picks it for the session, and a Settings warden_models value of "vex_r3b"
## for that Warden picks it in the save. A variant whose file is missing falls back to the shipped model.
static func art(arch: String) -> String:
	var nm := String(ART.get(arch, arch))
	var v := variant(nm)
	if v == "":
		var pick := String((Settings.get_v(SETTING) as Dictionary).get(arch, ""))
		v = pick if pick.begins_with(nm + "_") else ""
	return v if v != "" and ResourceLoader.exists("%s/%s/%s.glb" % [DIR, v, v]) else nm

## The variant `--warden-variant=` picks for an art name ("" for none).
static func variant(nm: String) -> String:
	if _variants == null:
		_variants = {}
		for a in OS.get_cmdline_user_args():
			if String(a).begins_with("--warden-variant="):
				for v in String(a).get_slice("=", 1).split(",", false):
					_variants[v.get_slice("_", 0)] = v
	return String((_variants as Dictionary).get(nm, ""))

static func has_model(arch: String) -> bool:
	return arch != "" and ResourceLoader.exists(path(arch))

## A Warden is drawn from its .glb when it has one, unless the player set it to procedural.
static func uses_model(arch: String) -> bool:
	return has_model(arch) and String((Settings.get_v(SETTING) as Dictionary).get(arch, "3d")) != "procedural"

## The player's pick for one Warden: true for its 3D model, false for the procedural one.
static func set_model(arch: String, on: bool) -> void:
	var picks: Dictionary = (Settings.get_v(SETTING) as Dictionary).duplicate()
	if on:
		picks.erase(arch)
	else:
		picks[arch] = "procedural"
	Settings.set_v(SETTING, picks)

## The .glb's armature, or null.
static func skeleton(glb: Node) -> Skeleton3D:
	var skels: Array = glb.find_children("*", "Skeleton3D", true, false) if glb else []
	return skels[0] if not skels.is_empty() else null

## One of the model's anchor empties (ANCHORS, or a hero's own), riding its bone; null on a procedural model.
static func anchor(root: Node3D, anchor_name: String) -> Node3D:
	var w := root.get_node_or_null("Warden")
	return w.find_child(anchor_name, true, false) as Node3D if w else null

## Dresses the procedural hunter `root` in its Warden's .glb when it uses one (meta "glb" says which). lk is
## the look Models.hunter built from (MantleLook params): its colour picks tint the painted slots.
## The rig's rest is kept in meta "rig_rest" (tools/warden_build.gd builds the armature on it). The bones follow
## each rig node's move from its rest in the Warden's neutral look, so the player's MantleLook sliders (head,
## legs, build) reshape the 3D model as they do the procedural one.
static func dress(root: Node3D, arch: String, lk: Dictionary) -> void:
	root.set_meta("glb", false)
	root.set_meta("rig_rest", WardenSkeleton.rig_rest(root))
	if _measuring or not uses_model(arch):
		return
	var rest := neutral_rest(arch)
	var scene := load(path(arch)) as PackedScene
	var glb: Node3D = scene.instantiate() as Node3D if scene else null
	var skel := skeleton(glb)
	var bad: Array = WardenSkeleton.mismatches(skel, rest) if skel else ["no armature"]
	if not bad.is_empty():
		push_warning("WardenGlb: %s does not fit the rig (%s); keeping the procedural model" % [path(arch), str(bad)])
		if glb:
			glb.free()
		return
	_hide_body(root)
	glb.name = "Warden"
	root.add_child(glb)
	var sync := Sync.new()
	sync.name = "Sync"
	sync.setup(root, skel, rest)
	glb.add_child(sync)
	var mats: Array = root.get_meta("mats", [])
	mats.append_array(_toon(glb, lk, MantleLook.warden(arch)))
	root.set_meta("mats", mats)
	root.set_meta("glb", true)
	_hold_weapon(root, glb)

## The .glb's own weapon (a mesh named WEAPON, modelled in the Gun node's space) goes into the hands in place
## of the procedural one; the Gun node and its Muzzle stay, so shots and grips are unchanged.
static func _hold_weapon(root: Node3D, glb: Node3D) -> void:
	var weapon := glb.find_child(WEAPON, true, false) as Node3D
	var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	if weapon == null or gun == null:
		return
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	weapon.get_parent().remove_child(weapon)
	weapon.owner = null
	gun.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY
	# its magazine (WEAPON_MAG) becomes the Gun's Mag, which the reload drops out and slaps back in
	var mag := weapon.find_child(WEAPON_MAG, true, false) as Node3D
	var old := gun.get_node_or_null("Mag")
	if old is MeshInstance3D and mag == null:
		(old as MeshInstance3D).mesh = null      # (a weapon modelled whole: the reload still moves the Mag node)
	if mag and old:
		var at := WardenGlb.model_xf(gun, mag)
		gun.remove_child(old)
		old.free()
		mag.get_parent().remove_child(mag)
		mag.owner = null
		gun.add_child(mag)
		mag.transform = at
		mag.name = "Mag"

## The rig rest of the Warden's model in the neutral look (built once a session).
static func neutral_rest(arch: String) -> Dictionary:
	if not _neutral.has(arch):
		_measuring = true
		var look := PlayerLook.neutral()
		var m := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", look, arch)
		_measuring = false
		_neutral[arch] = m.get_meta("rig_rest")
		m.free()
	return _neutral[arch]

## Hides the procedural body's meshes, leaving the KEEP pieces.
static func _hide_body(n: Node) -> void:
	for ch in n.get_children():
		if String(ch.name) in KEEP:
			continue
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
		_hide_body(ch)

## Every surface onto a hero-toon material for its slot: the baked atlas as its albedo, the baked AO in the
## vertex colour, tinted by the player's pick where the slot takes one.
static func _toon(glb: Node, lk: Dictionary, warden: Dictionary) -> Array:
	var out: Array = []
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si) as BaseMaterial3D
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""      # ("<slot>-<texture>")
			# the ink shell on the body's silhouette only: on the scan's thin hair strands it poked through as
			# lines across the face
			var tag := String(src.resource_name).get_slice("-", 1) if src else ""
			var m := Models.toon(src.albedo_color if src else Color.WHITE, not slot in NO_INK or tag in INK_TAGS)
			# (no baked AO in a Meshy model's vertex colour: the array is absent and would read as noise)
			m.set_shader_parameter("vertex_ao", false)
			m.set_shader_parameter("surface", int(SLOTS.get(slot, 1)))
			Models.hero_look(m)
			if src and src.albedo_texture:
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("albedo", _tint(slot, lk, warden))
				# (metal keeps its gloss and rim)
				for k in PAINTED:
					m.set_shader_parameter(k, PAINTED[k])
				if m.next_pass:
					m.next_pass = _painted_ink()
			if slot == "glow":
				m.set_shader_parameter("glow", GLOW)
			(mi as MeshInstance3D).set_surface_override_material(si, m)
			out.append(m)
	return out

static func _painted_ink() -> ShaderMaterial:
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = Models.OUTLINE
		_ink.set_shader_parameter("width", INK_WIDTH)
		_ink.set_shader_parameter("ink_mask", true)      # (the fit's ink room in the vertex colour)
	return _ink

## How far the player's colour pick moves a painted slot from the Warden's own colour (white: not at all).
static func _tint(slot: String, lk: Dictionary, warden: Dictionary) -> Color:
	if not TINTS.has(slot) or not lk.has(TINTS[slot][0]):
		return Color.WHITE
	var pick: Color = lk[TINTS[slot][0]]
	var own: Color = warden[TINTS[slot][1]]
	var k := func(a: float, b: float) -> float: return clampf(a / maxf(b, 0.05), 1.0 - TINT_MAX, 1.0 + TINT_MAX)
	return Color(k.call(pick.r, own.r), k.call(pick.g, own.g), k.call(pick.b, own.b))

## The model-space transform of a rig node (chained up to the model root, so it works out of the tree too).
static func model_xf(root: Node3D, nd: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = nd
	while cur != root and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

## The pose a bone takes for its rig node's pose `now` (model space): the node's move since its rest, applied
## to the bone's rest. `link` is one of Sync.links.
static func retarget(now: Transform3D, link: Array) -> Transform3D:
	return now * (link[2] as Transform3D) * (link[3] as Transform3D)

## Each frame, after the hunter's animation, puts every mapped bone where its rig node has moved it.
class Sync extends Node:
	var root: Node3D
	var skel: Skeleton3D
	var links: Array = []       # [bone index, rig node, node rest (model space) inverse, bone rest (skeleton space)]
	var springs := Springs.new()  # the spring_ bone chains (braids) swinging on top

	func setup(model: Node3D, skeleton: Skeleton3D, rest: Dictionary) -> void:
		root = model
		skel = skeleton
		process_priority = 10       # after Match renders the hunters (HunterAnim.update)
		for b in BONES:
			var bi := WardenSkeleton.find(skel, b)
			var nd := root.get_node_or_null(String(BONES[b])) as Node3D
			if bi < 0 or nd == null:
				continue
			links.append([bi, nd, (rest[b] as Transform3D).affine_inverse(), skel.get_bone_global_rest(bi)])
		links.sort_custom(func(a, c): return int(a[0]) < int(c[0]))     # parents before children
		springs.setup(skel)

	func _process(dt: float) -> void:
		apply()
		springs.step(dt)

	func apply() -> void:
		for l in links:
			skel.set_bone_global_pose(int(l[0]), WardenGlb.retarget(WardenGlb.model_xf(root, l[1]), l))

## Hanging pieces on bone chains (RIG_CONTRACT "Spring chains"): bones named spring_<name>_<i>, each the next
## one's parent, the first a child of a contract bone (a braid hangs from the head). Each chain is a rope of its
## joints in world space: it keeps its momentum (damped), is pulled back toward the shape it has riding its parent
## rigidly (firmer at the root than at the tip), and keeps its links' lengths, so a braid trails behind a run,
## swings out of a turn and settles when she stands. The last bone is the tip (no skin of its own).
class Springs:
	const PREFIX := "spring_"
	const PULL := 0.2           # the share of the way back to the rest shape per 1/60 s, at the root
	const PULL_TIP := 0.07      # and at the tip
	const DAMP := 0.84          # the velocity kept per 1/60 s
	var skel: Skeleton3D
	var chains: Array = []      # {ids: bone indices root -> tip, pts, prev: joint positions (world)}

	func setup(skeleton: Skeleton3D) -> void:
		skel = skeleton
		for bi in skel.get_bone_count():
			var par := skel.get_bone_parent(bi)
			if not _spring(bi) or par < 0 or _spring(par):
				continue
			var ids: Array = [bi]
			var cur := bi
			while true:
				var kids: Array = Array(skel.get_bone_children(cur)).filter(func(c): return _spring(c))
				if kids.is_empty():
					break
				cur = int(kids[0])
				ids.append(cur)
			if ids.size() >= 2:
				chains.append({"ids": ids, "pts": PackedVector3Array(), "prev": PackedVector3Array()})

	func _spring(bi: int) -> bool:
		return skel.get_bone_name(bi).begins_with(PREFIX)

	func step(dt: float) -> void:
		if chains.is_empty() or not skel.is_inside_tree():
			return
		var xf := skel.global_transform
		var inv := xf.affine_inverse()
		var k := clampf(dt * 60.0, 0.0, 3.0)
		for ch in chains:
			var ids: Array = ch["ids"]
			var par := skel.get_bone_parent(int(ids[0]))
			# each joint riding the parent rigidly: its rest relative to the parent's
			var base := skel.get_bone_global_pose(par) * skel.get_bone_global_rest(par).affine_inverse()
			var rest: Array = []
			var want := PackedVector3Array()
			for bi in ids:
				var r: Transform3D = base * skel.get_bone_global_rest(int(bi))
				rest.append(r)
				want.append(xf * r.origin)
			var n := want.size()
			var pts: PackedVector3Array = ch["pts"]
			var prev: PackedVector3Array = ch["prev"]
			if pts.size() != n or pts[0].distance_to(want[0]) > 1.5:      # (the first frame, or a teleport)
				pts = want.duplicate()
				prev = want.duplicate()
			for i in range(1, n):
				var p := pts[i]
				var v := (p - prev[i]) * pow(DAMP, k)
				prev[i] = p
				p += v
				var pull := lerpf(PULL, PULL_TIP, float(i) / float(n - 1))
				pts[i] = p.lerp(want[i], 1.0 - pow(1.0 - pull, k))
			pts[0] = want[0]
			prev[0] = want[0]
			for i in range(1, n):
				var d := pts[i] - pts[i - 1]
				var ln := want[i].distance_to(want[i - 1])
				pts[i] = pts[i - 1] + d.normalized() * ln if d.length() > 1e-5 else want[i]
			ch["pts"] = pts
			ch["prev"] = prev
			for j in n - 1:
				var r: Transform3D = rest[j]
				var a := inv * pts[j]
				var from := ((rest[j + 1] as Transform3D).origin - r.origin).normalized()
				var to := (inv * pts[j + 1] - a).normalized()
				var q := Quaternion(from, to) if from.dot(to) < 0.99999 and from.dot(to) > -0.999 else Quaternion.IDENTITY
				skel.set_bone_global_pose(int(ids[j]), Transform3D(Basis(q) * r.basis, a))
