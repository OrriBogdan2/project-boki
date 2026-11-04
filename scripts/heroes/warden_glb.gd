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
## A Warden's variant of the contract (RIG_CONTRACT "Variant bones"): its own extra bones -> their parents. A .glb of
## that Warden must carry them (WardenSkeleton.mismatches); they are skinned like the rest and follow their parent
## bone, and the Warden's kit poses them on top of that (pose_extra): Dredge's grab-claw fingers, the eye, the winch
## drum, the rope and cargo hook that hang from it, and the tar pool at his feet.
const EXTRA := {
	"dredge": {"eye": "head", "claw1.L": "hand.L", "claw1_tip.L": "claw1.L", "claw2.L": "hand.L",
		"claw2_tip.L": "claw2.L", "claw3.L": "hand.L", "claw3_tip.L": "claw3.L", "winch": "hips", "rope1": "hips",
		"rope2": "rope1", "hook": "rope2", "pool": "root"},
}
## Procedural pieces that stay when the .glb dresses the hunter (the contract's "nodes the game keeps").
const KEEP := ["Gun", "Glider", "TeamRing", "Shield", "Shoulder", "Halo", "Focus"]
## glTF material name -> the toon shader's painted surface (RIG_CONTRACT "Materials").
const SLOTS := {"skin": 4, "hair": 5, "cloth": 1, "leather": 2, "metal": 3, "fur": 5, "eyes": 0, "team": 1, "glow": 0}
## Slots a MantleLook colour pick tints: slot -> [the pick in Models.hunter's look, the Warden's own colour].
const TINTS := {"skin": ["skin_col", "skin"], "hair": ["hair_col", "hair_col"], "eyes": ["eye_col", "eyes"]}
const TINT_MAX := 0.35         # a pick moves a painted slot's colour at most this much (x, per channel)
const NO_INK := ["hair", "eyes", "glow"]   # slots drawn without the ink outline shell
## Materials "<slot>-<tag>" so tagged go without it too (thin ooze read as planks; the lens's line cut the orb).
const NO_INK_TAGS := ["tar", "crack", "glass", "gash"]
## A Warden's own settings for its painted atlas, on top of the shared ones (Dredge: tarnished brass, rough spec).
const LOOK := {"dredge": {"gloss": 0.0, "sheen": 0.0, "rim_far": 0.35, "rim_far_color": Color(1.0, 0.78, 0.3)}}
## And per slot of a Warden's painted atlas (Dredge: the eye glows brighter, so it shows at the match camera).
const LOOK_SLOT := {"dredge": {"glow": {"glow": 3.2, "rim_far": 0.0}}}
const PAINTED_SHADE := 0.72     # a painted atlas's shadow floor (the hero shader's own is 0.37)
const PAINTED_RAMP := 2.6       # and its terminator, softer than the hero shader's 0.5
## The scene's light leans cool and violet (Look: a c4cbe6 ambient, about half the light on a painted model, and a
## blue fill), which turned a painted atlas's skin lilac and its blacks muddy: ambient_cut and own_ambient swap the
## scene's ambient for a warm-neutral one a step brighter, light_neutral takes the hue out of the cool fill (the
## warm key keeps its warmth), dark_lift raises near-black paint one step; the shadow tint is warm.
## (The shared fix, ext/warden-vex-r3b 16c18b4f.)
## At the match camera far_smooth takes the atlas's fine detail out (no speckle) and the ink thins (INK_FAR_THIN);
## a Hunter's signature rim there is rim_far / rim_far_color in LOOK (ext/warden-vex-r3b f4b59cb3).
const PAINTED_LOOK := {"shadow_tint": Color(1.0, 0.95, 0.91), "ambient_cut": 1.0,
	"own_ambient": Vector3(0.58, 0.54, 0.5), "light_neutral": 0.9, "dark_lift": 0.07, "far_smooth": 0.7,
	"far_smooth_bias": 1.0}
const INK_FAR_THIN := 0.8       # the ink this much thinner at the match camera (outline.gdshader far_thin)
static var _ink: ShaderMaterial    # the painted models' ink: the procedural heroes' line, thinned at the match camera
const GLOW := 1.6              # emission of the glow slot (mechanical eyes, cracks), x its painted colour
## Empties every .glb exports on its bones (RIG_CONTRACT "Anchor empties"); kits find them with anchor().
const ANCHORS := ["anchor_head_top", "anchor_chest"]
## Settings key: Warden id -> "procedural" for a Warden the player keeps on its procedural model.
const SETTING := "warden_models"
const WEAPON := "weapon"        # the .glb node that replaces the procedural weapon (RIG_CONTRACT)
const WEAPON_MAG := "weapon_mag"  # its magazine, a child of it
const WEAPON_SPIN := "weapon_spin"  # its spinning barrels, a child of it (HunterAnim spins them while firing)
const WEAPON_MUZZLE := "weapon_muzzle"  # an empty on its mouth, a child of it: the Gun's Muzzle moves there

static var _neutral := {}       # Warden id -> the rig rest of its model in the neutral look (what a .glb is built on)
static var _measuring := false  # building that neutral model: no .glb on it

static func path(arch: String) -> String:
	var nm := String(ART.get(arch, arch))
	return "%s/%s/%s.glb" % [DIR, nm, nm]

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
	var bad: Array = WardenSkeleton.mismatches(skel, rest, EXTRA.get(arch, {})) if skel else ["no armature"]
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
	mats.append_array(_toon(glb, lk, MantleLook.warden(arch), arch))
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
	# its mouth (WEAPON_MUZZLE) becomes where the Gun's Muzzle sits (a weapon shorter or longer than the procedural one)
	var mouth := weapon.find_child(WEAPON_MUZZLE, true, false) as Node3D
	var muzzle := gun.get_node_or_null("Muzzle") as Node3D
	if mouth and muzzle:
		muzzle.transform = WardenGlb.model_xf(weapon, mouth)
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

## Poses one of the Warden's variant bones (EXTRA) on its rest, riding its parent: turned by `rot` about its head
## (an axis in model space as the model rests: Vector3.RIGHT turns a drum about its side-to-side axle), scaled by `scl`
## (zero hides what rides it). False on a procedural model or a bone the .glb lacks.
static func pose_extra(root: Node3D, bone: String, rot := Quaternion.IDENTITY, scl := Vector3.ONE) -> bool:
	var sk := extra_skeleton(root)
	var bi := WardenSkeleton.find(sk, bone) if sk else -1
	if bi < 0:
		return false
	var g := sk.get_bone_global_rest(bi).basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * (g.inverse() * rot * g))
	sk.set_bone_pose_scale(bi, scl)
	return true

## The armature of a hunter drawn from its .glb (null on a procedural one), for its kit's variant bones.
static func extra_skeleton(root: Node3D) -> Skeleton3D:
	if root == null or not bool(root.get_meta("glb", false)):
		return null
	return skeleton(root.get_node_or_null("Warden"))

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
static func _toon(glb: Node, lk: Dictionary, warden: Dictionary, arch := "") -> Array:
	var out: Array = []
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si) as BaseMaterial3D
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""      # ("<slot>-<texture>")
			# the ink shell on the body's silhouette only: on the scan's thin hair strands it poked through as
			# lines across the face
			var tag := String(src.resource_name).get_slice("-", 1) if src else ""
			var ink := not slot in NO_INK and not tag in NO_INK_TAGS
			var m := Models.toon(src.albedo_color if src else Color.WHITE, ink)
			# (no baked AO in a Meshy model's vertex colour: the array is absent and would read as noise)
			m.set_shader_parameter("vertex_ao", false)
			m.set_shader_parameter("surface", int(SLOTS.get(slot, 1)))
			Models.hero_look(m)
			if src and src.albedo_texture:
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("albedo", _tint(slot, lk, warden))
				# the atlas is painted already: no procedural brushwork on top (it is scaled per triangle,
				# so on a scanned mesh's long thin triangles it shows as facets); metal keeps its gloss and rim
				m.set_shader_parameter("surface", 0)
				m.set_shader_parameter("paint", 0.0)
				# and its light and shade are painted in too: a soft, light toon ramp on top, so the scan's
				# small bumps don't break into hard light/shadow facets (STYLE.md's flat painted read)
				m.set_shader_parameter("shade", PAINTED_SHADE)
				m.set_shader_parameter("ramp", PAINTED_RAMP)
				m.set_shader_parameter("shadow_sat", 0.0)
				m.set_shader_parameter("self_shadow", 0.0)
				for k in PAINTED_LOOK:
					m.set_shader_parameter(k, PAINTED_LOOK[k])
				if m.next_pass:
					m.next_pass = _painted_ink()
				var own: Dictionary = LOOK.get(arch, {}).duplicate()
				own.merge(LOOK_SLOT.get(arch, {}).get(slot, {}), true)
				for k in own:
					m.set_shader_parameter(k, own[k])
			else:
				# a flat-painted model (hand-modelled, one colour a material, no atlas: Dredge): the procedural
				# heroes' clean painted look (Models.hunter), the slot's surface shading on top
				m.set_shader_parameter("paint", 0.012)
				m.set_shader_parameter("shadow_tint", Color(0.6, 0.6, 0.86))
				m.set_shader_parameter("light_tint", Color(1.08, 1.0, 0.9))
			if slot == "glow":
				m.set_shader_parameter("glow", float(LOOK_SLOT.get(arch, {}).get("glow", {}).get("glow", GLOW)))
				m.set_shader_parameter("shade", 1.0)      # (a light source: no shadow side, which read as a dark claw)
			(mi as MeshInstance3D).set_surface_override_material(si, m)
			_far_look(m, src, slot, tag, {"painted": LOOK.get(arch, {}), "slots": LOOK_SLOT.get(arch, {})})
			out.append(m)
	return out

static func _painted_ink() -> ShaderMaterial:
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = Models.OUTLINE
		_ink.set_shader_parameter("far_thin", INK_FAR_THIN)
		_ink.set_shader_parameter("far_cut", INK_FAR_CUT)
	return _ink

static func _param(v: Variant) -> Variant:
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if (v as Array).size() > 3 else 1.0)
	return v

## The match-zoom read (ext/warden-matchzoom; hero_toon.gdshader far_*, outline.gdshader far_cut and glow_shell),
## on a painted atlas: from 8 to 18 m (by size on screen) the pale fresnel drops to a third, the gloss, sheen and
## light rims go, the rest is anti-aliased, stray texels are clamped to their coarser mip, rim_far becomes a broad
## band in the signature colour and whatever glows is a step brighter. A Hunter's warden_look.json "painted" or
## "slots" set any of these keys to tune them.
const FAR_LOOK := {"far_fres": 0.35, "far_spec": 0.0, "far_aa": 1.0, "far_clamp": 0.8, "far_rim_soft": 1.0,
	"far_glow": 0.6}
const INK_FAR_CUT := 0.55      # the ink gone from ~13.5 m (outline.gdshader far_cut): a sub-pixel line is dark dots
## The glow slot's halo shell at the match camera (outline.gdshader glow_shell): eyes, lenses and cracks read as a
## glow there, not a pixel. A Hunter's "glow_shell" overrides these ({"glow_px": 0}: none).
const GLOW_SHELL := {"glow_px": 1.4, "glow_k": 1.3, "glow_near": 7.0, "glow_far": 14.0}
static var _far_inks := {}       # [ink shell, the Hunter's "ink" as JSON] -> that shell with its far_cut

## A surface's match-zoom read (FAR_LOOK), after its own look; and the Hunter's warden_look.json keys:
## "no_ink" (material tags or slots without the ink shell: thin crossbows, a gum bubble), "ink" {"far_cut",
## "far_thin", "color"} for its ink shell, "glow_shell" for the glow pieces' halo.
static func _far_look(m: ShaderMaterial, src: BaseMaterial3D, slot: String, tag: String, own: Dictionary) -> void:
	if m.shader != Models.HERO or not (src and src.albedo_texture):
		return
	var set_by: Dictionary = (own.get("painted", {}) as Dictionary).merged(
			(own.get("slots", {}) as Dictionary).get(slot, {}), true)
	for k in FAR_LOOK:
		if not set_by.has(k):
			m.set_shader_parameter(k, FAR_LOOK[k])
	var ink := m.next_pass as ShaderMaterial
	if ink and ink.get_shader_parameter("ink_mask") == true:      # (null on an ink that never set it)
		var no_ink: Array = own.get("no_ink", [])
		if tag in no_ink or slot in no_ink:
			m.next_pass = null
		else:
			var own_ink: Dictionary = own.get("ink", {})
			var key := [ink, JSON.stringify(own_ink)]
			if not _far_inks.has(key):
				var far := ink.duplicate() as ShaderMaterial
				far.set_shader_parameter("far_cut", INK_FAR_CUT)
				for k in own_ink:
					far.set_shader_parameter(k, _param(own_ink[k]))
				_far_inks[key] = far
			m.next_pass = _far_inks[key]
	if slot == "glow" and m.next_pass == null:
		var cfg: Dictionary = GLOW_SHELL.merged(own.get("glow_shell", {}), true)
		if float(cfg["glow_px"]) > 0.0:
			var sh := ShaderMaterial.new()
			sh.shader = Models.OUTLINE
			sh.set_shader_parameter("glow_shell", true)
			sh.set_shader_parameter("glow_tex", src.albedo_texture)
			for k in cfg:
				sh.set_shader_parameter(k, _param(cfg[k]))
			m.next_pass = sh

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

	func _process(_dt: float) -> void:
		apply()

	func apply() -> void:
		for l in links:
			skel.set_bone_global_pose(int(l[0]), WardenGlb.retarget(WardenGlb.model_xf(root, l[1]), l))
