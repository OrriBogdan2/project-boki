class_name WardenGlb
extends RefCounted
## A Warden's 3D model (docs/art/wardens/RIG_CONTRACT.md): when art/wardens/<name>/<name>.glb exists and the
## player hasn't set that Warden to procedural (Settings > Video > Warden models), the procedural hunter
## Models.hunter built keeps its rig, weapon, glider and hit ring but hides its body, and the .glb's armature
## (WardenSkeleton) follows the rig nodes HunterAnim poses, one bone per node (BONES), so every kit move
## plays on it. Otherwise the procedural model stays as it is: the fallback.

const DIR := "res://art/wardens"
## Each Warden's art name, as in docs/art/gen/wardens/<name>_turnaround.png: the folder and file its .glb has.
const ART := {"bulwark": "breaker", "archer": "hem", "juggernaut": "kael", "gunslinger": "vex", "ostra": "ostra",
	"mage": "ryzz", "dolm": "tarek", "thief": "sable", "rimewright": "claire", "ashwick": "cinder",
	"tender": "pip", "dredge": "dredge"}
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
const LEG_BONES := ["thigh.L", "shin.L", "thigh.R", "shin.R"]
## A Warden's variant of the contract (RIG_CONTRACT "Variant bones"): its own extra bones -> their parents. A .glb of
## that Warden must carry them (WardenSkeleton.mismatches); they are skinned like the rest and follow their parent
## bone, and the Warden's kit poses them on top of that (pose_extra): Dredge's grab-claw fingers, the eye, the winch
## drum, the rope and cargo hook that hang from it, and the tar pool at his feet.
const EXTRA := {
}
## Procedural pieces that stay when the .glb dresses the hunter (the contract's "nodes the game keeps").
const KEEP := ["Gun", "Glider", "TeamRing", "Shield", "Shoulder", "Halo", "Focus"]
## glTF material name -> the toon shader's painted surface (RIG_CONTRACT "Materials").
## "brass" is metal split off by its colour, so a model's look can lift it alone at the match camera (Vex r3f).
const SLOTS := {"skin": 4, "hair": 5, "cloth": 1, "leather": 2, "metal": 3, "brass": 3, "fur": 5, "eyes": 0,
	"team": 1, "glow": 0, "void": 0, "card": 0, "ice": 1, "flame": 0}
## Slots a MantleLook colour pick tints: slot -> [the pick in Models.hunter's look, the Warden's own colour].
const TINTS := {"skin": ["skin_col", "skin"], "hair": ["hair_col", "hair_col"], "eyes": ["eye_col", "eyes"]}
const TINT_MAX := 0.35         # a pick moves a painted slot's colour at most this much (x, per channel)
const GUM_TAG := "gum"         # a bubble drawn with the gloss pass (gum_gloss.gdshader) instead of an ink shell
const NO_INK := ["hair", "eyes", "glow", "card", "flame"]   # slots drawn without the ink outline shell
## The `void` slot is no lit surface but a window onto the Void (shaders/hero_void.gdshader: a drifting
## starfield over its painted colour, Ostra's coat tears); "<void>-<tag>" with a SOFT_TAGS tag also fades
## out toward its tip and edges (a body that dissolves into smoke: Ostra's wisp).
const VOID := preload("res://shaders/hero_void.gdshader")
const SOFT_TAGS := ["wisp"]
## The `flame` slot: strips of living fire (shaders/hero_flame.gdshader), "flame-<tag>"; warden_look's "slots"
## "flame-<tag>" sets its shader parameters. "flame-liquid" is a tank's bubbling fuel behind glass.
const FLAME: Shader = preload("res://shaders/hero_flame.gdshader")
## The "card" slot: see-through alpha cards (wings) on their own shader, both sides drawn, no ink.
const CARD: Shader = preload("res://shaders/warden_card.gdshader")
## Pieces built as clean geometry (tools/meshy/warden_parts.py), "<slot>-<tag>": they take the ink line even on
## an inkless slot (the hair goes without it for a scan's ragged strands, not for a woven braid).
const INK_TAGS := ["braid", "mane", "mane_dk"]
## The hero toon shader on a painted atlas, which carries its own light and shade: the toon light on top stays
## soft and near white (no violet shadow, no warm terminator band, no sun self-shadow, no procedural
## brushwork), a light-coloured rim and top light lift its edges off the ground, and far_lift brightens it at
## the match camera, so the model reads as bright as the art. (A procedural hero's shadow floor is 0.37.)
## The scene's light leans cool and violet (Look: a c4cbe6 ambient, about half the light on a painted model, and a
## blue fill), which turned a painted atlas's skin lilac and its blacks muddy: ambient_cut and own_ambient swap the
## scene's ambient for a warm-neutral one a step brighter, light_neutral takes the hue out of the cool fill (the
## warm key keeps its warmth), dark_lift raises near-black paint one step; the shadow tint is warm. At the match
## camera far_smooth takes the atlas's fine detail out (no speckle) and the ink thins (INK_FAR_THIN); a Hunter's
## signature rim there is rim_far / rim_far_color in its warden_look.json "painted".
const PAINTED := {"shade": 0.86, "ramp": 2.6, "shadow_tint": Color(1.0, 0.95, 0.91), "shadow_sat": 0.0, "sss": 0.0,
	"sky_ao": 0.12, "self_shadow": 0.0, "surface": 0, "paint": 0.0, "fres": 1.3, "fres_tint": 0.95, "rim_amount": 0.5,
	"top_light": 1.0, "far_lift": 0.35, "ambient_cut": 1.0, "own_ambient": Vector3(0.58, 0.54, 0.5),
	"light_neutral": 0.9, "dark_lift": 0.07, "far_smooth": 0.7, "far_smooth_bias": 1.0}
## The `ice` slot (Claire's ice costume, spear and blades; Breaker's hammer block): read as clear ice without real
## transparency: a strong cold fresnel rim and a little gloss over the painted atlas.
const ICE := {"fres": 2.6, "fres_color": Color(0.72, 0.9, 1.0), "fres_tint": 0.25, "gloss": 0.45, "rim_amount": 0.8}
const GLOW := 1.6              # emission of the glow slot (mechanical eyes, cracks), x its painted colour
const EMIT := 2.2              # a painted emission layer's strength (a material's emissive texture: veins, cracks)
const EMIT_FLICKER := 0.55     # and how much it crackles
## The ink shell on a painted atlas: half the procedural heroes' width per metre of camera distance (the same
## 4 mm line close up), and never more than the fit's ink room at a vertex (outline.gdshader ink_mask). At the
## match camera a full-width line round every belt, buckle and candle of a scanned model added up to a smudge.
const INK_WIDTH := 0.0006
const INK_FAR_THIN := 0.8       # the ink this much thinner at the match camera (outline.gdshader far_thin)
## Empties every .glb exports on its bones (RIG_CONTRACT "Anchor empties"); kits find them with anchor().
const ANCHORS := ["anchor_head_top", "anchor_chest"]
## Settings key: Warden id -> "procedural" for a Warden the player keeps on its procedural model (or a design
## variant's name, art()).
const SETTING := "warden_models"
const FAR_HIDE_D := 13.0        # m from the camera: "far_hide" pieces stop being drawn
const ORBIT_LOOK := "orbit_look"   # root meta, a world point: the seeing-stones turn to it (DolmKit)
const WEAPON := "weapon"        # the .glb node that replaces the procedural weapon (RIG_CONTRACT)
const WEAPON_MAG := "weapon_mag"  # its magazine, a child of it
const WEAPON_SPIN := "weapon_spin"  # its spinning barrels, a child of it (HunterAnim spins them while firing)
## the second weapon of a twin hold (Sable's left crossbow), a child of WEAPON placed so that HunterAnim's twin
## hold hands it to the left hand (its node x < -0.04: _setup_weapon moves it into the Offhand)
const WEAPON_OFF := "weapon_offhand"
const SHIELD_PATH := "Rig/Torso/ArmLPivot/Elbow/Hand/Shield"
const SHIELD := "shield"        # a shield modelled in the left hand's Shield node's space (Breaker's prow)
## Root meta HunterAnim sets while a Warden skates (0..1): the spring chains named "wing" fold back (Claire);
## below 0 they flare open instead, from a kit move's "wg" channel (-1: wide, Sable's flips and Encore).
const WING_FOLD := "wing_fold"
const WEAPON_THROWN := "weapon_thrown"   # an empty on a skinned weapon: the frame of the piece that leaves the hand
## Root meta a kit sets while a runtime piece of the weapon is out (Kael's chain in the air, Grimble's stretched hook
## arm): the bones the Hero's data lists in "hide_while_chain" shrink away (item 76b.4), so one shows, never two.
const CHAIN_OUT := "chain_out"
const WEAPON_MUZZLE := "weapon_muzzle"  # an empty on its mouth, a child of it: the Gun's Muzzle moves there

static var _neutral := {}       # Warden id -> the rig rest of its model in the neutral look (what a .glb is built on)
## .glb path -> its scene, kept once read: a preview freed and built again (the Masks screens) would otherwise
## read the file from disk again, 0.3-1.5 s a Warden
static var _scenes := {}
static var _ink: ShaderMaterial  # the painted atlas's ink shell (INK_WIDTH), shared
static var _gloss_m: ShaderMaterial
static var _measuring := false  # building that neutral model: no .glb on it
static var _variants = null     # art name -> the design variant the command line picks (variant())
static var _look = null         # content/rules/warden_look.json, read once (look())
const LOOK_PATH := "res://content/rules/warden_look.json"
const HALO := preload("res://shaders/warden_halo.gdshader")

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
	if w == null:
		return null
	var an := w.find_child(anchor_name, true, false) as Node3D
	if an == null:
		# (one on the .glb's weapon, which the loader moved under the Gun: Hem's bow, Cinder's flame chamber)
		var gun := root.get_node_or_null("Rig/Torso/Aim/Gun/" + WEAPON)
		an = gun.find_child(anchor_name, true, false) as Node3D if gun else null
	return an

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
	var scene := _scene(arch)
	var glb: Node3D = scene.instantiate() as Node3D if scene else null
	var skel := skeleton(glb)
	var bad: Array = WardenSkeleton.mismatches(skel, rest, extra_bones(arch)) if skel else ["no armature"]
	if not bad.is_empty():
		push_warning("WardenGlb: %s does not fit the rig (%s); keeping the procedural model" % [path(arch), str(bad)])
		if glb:
			glb.free()
		return
	_hide_body(root)
	glb.name = "Warden"
	root.add_child(glb)
	var sync := WardenSync.new()
	sync.name = "Sync"
	sync.setup(root, skel, rest)
	glb.add_child(sync)
	sync.use_clips(glb, art(arch))
	sync.square_blade = float(Arch.body(arch).get("bulk", 1.0)) != 1.0
	var mats: Array = root.get_meta("mats", [])
	mats.append_array(_toon(glb, lk, MantleLook.warden(arch), look(art(arch)), arch))
	_lights(glb, look(art(arch)))
	_far_hide(glb, look(art(arch)))
	root.set_meta("mats", mats)
	root.set_meta("glb", true)
	var own := look(art(arch))
	var off: Array = own.get("weapon_offset", [0.0, 0.0, 0.0])
	if bool(WardenClips.data(art(arch)).get("skinned_weapon", false)):
		_skinned_weapon(root)
	else:
		_hold_weapon(root, glb, float(own.get("weapon_scale", 1.0)), Vector3(off[0], off[1], off[2]))
	_hold_shield(root, glb)
	sync.mood = WardenMood.make(root, glb, skel, art(arch))
	_halos(root, glb, look(art(arch)))      # (after the weapon is in the hands: a halo can ride the weapon)
	WardenFx.smoke(root, look(art(arch)))
	WardenFx.bloom(root, glb, look(art(arch)))

## Small pieces the match camera only sees as speckle (warden_look "far_hide": node names, Tarek's beads and fist
## shards) are drawn only up to FAR_HIDE_D from the camera; close-ups keep them.
static func _far_hide(glb: Node3D, own: Dictionary) -> void:
	for nm in own.get("far_hide", []):
		for n in glb.find_children(String(nm) + "*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).visibility_range_end = FAR_HIDE_D
			(n as GeometryInstance3D).visibility_range_end_margin = 1.0

## The .glb's own weapon (a mesh named WEAPON, modelled in the Gun node's space) goes into the hands in place
## of the procedural one; the Gun node and its Muzzle stay, so shots and grips are unchanged.
static func _hold_weapon(root: Node3D, glb: Node3D, wscale := 1.0, shift := Vector3.ZERO) -> void:
	var weapon := glb.find_child(WEAPON, true, false) as Node3D
	var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	if weapon == null or gun == null:
		return
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
		mi.set_meta("glb_hidden", true)      # (HunterAnim keeps the .glb weapon's own bounds off the ground)
	weapon.get_parent().remove_child(weapon)
	weapon.owner = null
	# a hammer swings on its own pivot under the Gun (meta hammer_pivot, PinBjornWeapons): it is modelled there
	var seat: Node3D = gun
	for c in gun.get_children():
		if c.has_meta("hammer_pivot") and not c.is_queued_for_deletion():
			seat = c
	seat.add_child(weapon)
	# warden_look "weapon_scale", and "weapon_offset" (m, Gun space: seats the grip in the hand)
	weapon.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * wscale), shift)
	var off := weapon.find_child(WEAPON_OFF, true, false) as Node3D
	if off:
		var at := WardenGlb.model_xf(gun, off)
		off.get_parent().remove_child(off)
		off.owner = null
		gun.add_child(off)
		off.transform = at
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
		mag.set_meta("glb", true)          # (the .glb's own, not the procedural one: --warden-glb-check)

## The rig's procedural prow goes (the .glb draws its own).
static func _hide_shield(root: Node3D) -> void:
	var holder := root.get_node_or_null(SHIELD_PATH) as Node3D
	if holder == null:
		return
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false

## The .glb's shield (SHIELD, modelled in the Shield node's space) replaces the procedural one on the left hand.
static func _hold_shield(root: Node3D, glb: Node3D) -> void:
	var shield := glb.find_child(SHIELD, true, false) as Node3D
	var holder := root.get_node_or_null(SHIELD_PATH) as Node3D
	if shield == null or holder == null:
		return
	_hide_shield(root)
	shield.get_parent().remove_child(shield)
	shield.owner = null
	holder.add_child(shield)
	shield.transform = Transform3D.IDENTITY

## The part of a skinned weapon that truly leaves the hand (item 76b): a plain copy of the mesh `mesh_name` on its own
## node, the grip at the origin, -Z toward the head (WEAPON_THROWN's frame), for the kit to fly and plant. The skinned
## one hides meanwhile (WardenClips "weapon_bone"). null on a procedural model.
static func thrown_piece(root: Node3D, mesh_name: String) -> Node3D:
	var w := root.get_node_or_null("Warden")
	var src := w.find_child(mesh_name, true, false) as MeshInstance3D if w else null
	var sk := skeleton(w)
	var frame := w.find_child(WEAPON_THROWN, true, false) as Node3D if w else null
	if src == null or sk == null or frame == null:
		return null
	var at := frame.get_parent() as BoneAttachment3D
	var base := sk.get_bone_global_rest(WardenSkeleton.find(sk, at.bone_name)) if at else Transform3D.IDENTITY
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	mi.transform = (base * frame.transform).affine_inverse()
	for si in src.get_surface_override_material_count():
		mi.set_surface_override_material(si, src.get_surface_override_material(si))
	var holder := Node3D.new()
	holder.name = "ThrownPiece"
	holder.add_child(mi)
	return holder

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

## Starts reading a Warden's .glb on a loader thread, so the build that needs it later doesn't wait on the disk.
static func fetch(arch: String) -> void:
	var p := path(arch)
	if not uses_model(arch) or _scenes.has(p):
		return
	if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		BackgroundWork.request(p)

## Whether a Warden's model can be built without waiting on the disk (fetch() starts the read when it hasn't).
static func fetched(arch: String) -> bool:
	fetch(arch)
	var p := path(arch)
	return not uses_model(arch) or _scenes.has(p) \
			or ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_IN_PROGRESS

## Whether the Warden's neutral rig rest is known yet (else the next build measures it first: a build of its own).
static func has_rest(arch: String) -> bool:
	return _neutral.has(arch) or not uses_model(arch)

static func _scene(arch: String) -> PackedScene:
	var p := path(arch)
	if not _scenes.has(p):
		var asked := ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		_scenes[p] = BackgroundWork.take(p) if asked else load(p)
	return _scenes[p] as PackedScene

## A Warden's variant bones: the code table above, plus its art's data file (content/rules/warden_anim/<art>.json).
static func extra_bones(arch: String) -> Dictionary:
	var out: Dictionary = (EXTRA.get(arch, {}) as Dictionary).duplicate()
	out.merge(WardenClips.data(art(arch)).get("extra_bones", {}), true)
	return out

## A weapon skinned in the .glb (item 76b): the procedural weapon's meshes go, its Gun node stays as the invisible aim
## and FX reference, which Sync keeps on the blade you see (Sync.apply_blade).
static func _skinned_weapon(root: Node3D) -> void:
	var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	if gun == null:
		return
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
		mi.set_meta("glb_hidden", true)
	var mag := gun.get_node_or_null("Mag") as MeshInstance3D      # (the reload's motion stays, shown or not)
	if mag:
		mag.mesh = null
		mag.visible = false

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

## A model's own shading over the shared painted look (content/rules/warden_look.json, keyed by its art name:
## a design variant has its own): "painted" sets hero-toon parameters on all of its surfaces, "slots" per toon
## slot after that, e.g. a painted skin or gunmetal the shared rim and top light would wash out. {} for none.
static func look(nm: String) -> Dictionary:
	if _look == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOOK_PATH)) if FileAccess.file_exists(LOOK_PATH) \
				else null
		_look = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return (_look as Dictionary).get(nm, {})

## The look's "lights": a small OmniLight3D on each named anchor empty of the model (Pip's lantern glow), so a
## prop that glows also lights what is round it: {"anchor", "colour" [r, g, b], "energy", "range"}.
static func _lights(glb: Node, own: Dictionary) -> void:
	for l in own.get("lights", []):
		var at := glb.find_child(String(l.get("anchor", "")), true, false) as Node3D
		if at == null:
			continue
		var om := OmniLight3D.new()
		om.name = "Light"
		om.light_color = _param(l.get("colour", [1.0, 0.8, 0.5]))
		om.light_energy = float(l.get("energy", 1.0))
		om.omni_range = float(l.get("range", 2.0))
		om.shadow_enabled = false
		at.add_child(om)

## The model's glow halos (warden_look.json "halos": anchor, color, px, near, far, strength): a lens that is a
## pixel wide at the match camera reads as a glow there (shaders/warden_halo.gdshader). Each halo is a small quad
## under the model root, carried by a RemoteTransform3D on its anchor (so nothing walking the .glb's meshes, the
## skin or the bounds, sees it); meta "halo".
static func _halos(root: Node3D, glb: Node3D, own: Dictionary) -> void:
	for hs in own.get("halos", []):
		var anchor_node := anchor(root, String(hs["anchor"]))
		if anchor_node == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Halo_" + String(hs["anchor"])
		var quad := QuadMesh.new()
		quad.size = Vector2(0.04, 0.04)
		mi.mesh = quad
		mi.extra_cull_margin = 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = HALO
		for k in hs:
			if k != "anchor":
				m.set_shader_parameter(k, _param(hs[k]))
		mi.material_override = m
		mi.set_meta("halo", true)
		root.add_child(mi)
		var follow := RemoteTransform3D.new()
		follow.name = "HaloFollow"
		follow.update_scale = false
		anchor_node.add_child(follow)
		follow.remote_path = follow.get_path_to(mi)

## A warden_look value as a shader parameter: [r, g, b(, a)] is a colour.
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
	if ink and ink.get_shader_parameter("ink_mask") == true:
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

## Every surface onto a hero-toon material for its slot: the baked atlas as its albedo, the baked AO in the
## vertex colour, tinted by the player's pick where the slot takes one; the model's own look (look()) last.
static func _toon(glb: Node, lk: Dictionary, warden: Dictionary, own := {}, arch := "") -> Array:
	var out: Array = []
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si) as BaseMaterial3D
			var slot := String(src.resource_name).get_slice("-", 0) if src else ""      # ("<slot>-<texture>")
			if slot == "card":
				var cm := ShaderMaterial.new()
				cm.shader = CARD
				if src and src.albedo_texture:
					cm.set_shader_parameter("albedo_tex", src.albedo_texture)
				cm.set_shader_parameter("use_tex", src != null and src.albedo_texture != null)
				var card_look: Dictionary = (own.get("slots", {}) as Dictionary).get("card", {})
				for k in card_look:
					cm.set_shader_parameter(k, _param(card_look[k]))
				(mi as MeshInstance3D).set_surface_override_material(si, cm)
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				out.append(cm)
				continue
			# the ink shell on the body's silhouette only: on the scan's thin hair strands it poked through as
			# lines across the face
			var tag := String(src.resource_name).get_slice("-", 1) if src else ""
			if slot == "void":
				var vm := _void(src, tag in SOFT_TAGS)
				(mi as MeshInstance3D).set_surface_override_material(si, vm)
				out.append(vm)
				continue
			if slot == "flame":
				var fm := ShaderMaterial.new()
				fm.shader = FLAME
				fm.set_shader_parameter("liquid", tag == "liquid")
				var flame_look: Dictionary = (own.get("slots", {}) as Dictionary).get("flame-" + tag, {})
				for k in flame_look:
					fm.set_shader_parameter(k, _param(flame_look[k]))
				(mi as MeshInstance3D).set_surface_override_material(si, fm)
				out.append(fm)
				continue
			var ink := not slot in NO_INK or tag in INK_TAGS      # (a Hunter's "no_ink" tags: _far_look)
			var m := Models.toon(src.albedo_color if src else Color.WHITE, ink)
			# (a Meshy model's vertex colour holds the ink room, not baked AO)
			m.set_shader_parameter("vertex_ao", false)
			m.set_shader_parameter("surface", int(SLOTS.get(slot, 1)))
			Models.hero_look(m)
			if src and src.albedo_texture:
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("albedo", _tint(slot, lk, warden))
				for k in PAINTED:
					m.set_shader_parameter(k, PAINTED[k])
				if m.next_pass:
					m.next_pass = _painted_ink()
			else:
				# a flat-painted model (hand-modelled, one colour a material, no atlas): the procedural heroes'
				# clean painted look (Models.hunter), the slot's surface shading on top
				m.set_shader_parameter("paint", 0.012)
				m.set_shader_parameter("shadow_tint", Color(0.6, 0.6, 0.86))
				m.set_shader_parameter("light_tint", Color(1.08, 1.0, 0.9))
			var hot := String(src.resource_name).ends_with("-hot") if src else false
			if slot == "glow" or hot:
				m.set_shader_parameter("glow", GLOW)
				# ("<slot>-<texture>-hot": only the atlas's hot texels glow, keyed per texel: Kael's arm cracks)
				m.set_shader_parameter("glow_key", hot)
				_glow_colours(m, arch, tag)
			if src and src.normal_enabled and src.normal_texture:
				m.set_shader_parameter("normal_tex", src.normal_texture)
				m.set_shader_parameter("use_nrm", true)
			if src and src.emission_enabled and src.emission_texture:
				m.set_shader_parameter("emit_tex", src.emission_texture)
				m.set_shader_parameter("use_emit", true)
				m.set_shader_parameter("emit", EMIT)
				m.set_shader_parameter("emit_flicker", EMIT_FLICKER)
				_emit_colour(m, arch)
			if tag == GUM_TAG:
				m.next_pass = _gloss()      # (a gum bubble: a glossy see-through skin over its toon pass, no ink)
			if slot == "ice":
				for k in ICE:
					m.set_shader_parameter(k, ICE[k])
			var per_slot: Dictionary = (own.get("slots", {}) as Dictionary).get(slot, {})
			# (then "<slot>-<tag>": Vex's woven braids, "hair-braid", calmer than the scan's hair)
			per_slot = per_slot.merged((own.get("slots", {}) as Dictionary).get(slot + "-" + tag, {}), true)
			var over: Dictionary = (own.get("painted", {}) as Dictionary).merged(per_slot, true)
			for k in over:
				var v = _param(over[k])
				# (a look's albedo is a correction on top of the player's colour pick, never in place of it)
				if k == "albedo" and v is Color and src and src.albedo_texture:
					v = (v as Color) * _tint(slot, lk, warden)
				m.set_shader_parameter(k, v)
			(mi as MeshInstance3D).set_surface_override_material(si, m)
			_far_look(m, src, slot, tag, own)
			out.append(m)
	return out

## A `void` surface: the starfield over its painted colour, soft (fading out) for a smoke piece.
static func _void(src: BaseMaterial3D, soft: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VOID
	if src and src.albedo_texture:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("soft", soft)
	return m

## A Warden's glow colours from its archetype's "model_glow" {core, edge (hex), strength (the emission)}: the
## cracks and glowing pieces take them instead of their painted colour, so the glow can change without a
## rebake. A flat piece tagged "edge"
## (glow-<name>_edge) takes the edge colour.
static func _glow_colours(m: ShaderMaterial, arch: String, tag: String) -> void:
	var g: Dictionary = Arch.def(arch).get("model_glow", {}) if arch != "" else {}
	if g.is_empty():
		return
	var core := Color(String(g.get(tag, g.get("core", "ffffff"))))     # (a tag's own: Kael's scarf embers)
	var edge := Color(String(g.get("edge", g.get("core", "ffffff"))))
	# (a halo layer, glow-<name>_halo*, keeps its own dimmer painted colour: the bloom's fall-off)
	if tag.contains("_halo"):
		m.set_shader_parameter("glow_core", Color(edge, 0.0))
		m.set_shader_parameter("glow_edge", Color(edge, 0.0))
		return
	m.set_shader_parameter("glow_core", core if not tag.ends_with("_edge") else edge)
	m.set_shader_parameter("glow_edge", edge)
	if g.has("strength"):
		m.set_shader_parameter("glow", float(g["strength"]))

## The emission layer in the archetype's "model_glow" core colour (Sparkle's pink scar, charm, piping and veins): the
## layer is a mask then, so the colour can change without a rebake.
static func _emit_colour(m: ShaderMaterial, arch: String) -> void:
	var g: Dictionary = Arch.def(arch).get("model_glow", {}) if arch != "" else {}
	if g.has("core"):
		m.set_shader_parameter("emit_tint", Color(String(g["core"])))

static func _gloss() -> ShaderMaterial:
	if _gloss_m == null:
		_gloss_m = ShaderMaterial.new()
		_gloss_m.shader = load("res://shaders/gum_gloss.gdshader")
	return _gloss_m

static func _painted_ink() -> ShaderMaterial:
	if _ink == null:
		_ink = ShaderMaterial.new()
		_ink.shader = Models.OUTLINE
		_ink.set_shader_parameter("width", INK_WIDTH)
		_ink.set_shader_parameter("ink_mask", true)
		_ink.set_shader_parameter("far_thin", INK_FAR_THIN)
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

## retarget for a leg bone without the shear (warden_anim "legs_rigid": Tarek): the rig's Legs node is scaled by
## the archetype's leg length on y only (Models.hunter), so a leg swung inside it is sheared, which a thin
## procedural leg hides but a baggy trouser and a big foot don't. The bone keeps retarget's origin and turns as the
## rig's leg points; along that line it shortens as the rig's leg does, and its girth stays.
static func retarget_rigid(now: Transform3D, link: Array) -> Transform3D:
	var xf := retarget(now, link)
	var rest := (link[2] as Transform3D).affine_inverse()
	var d := now.basis.y.normalized()
	var k := now.basis.y.length() / maxf(rest.basis.y.length(), 1e-6)
	var turn := _along_y(now.basis) * _along_y(rest.basis).inverse()
	var stretch := Basis.IDENTITY
	for i in 3:
		stretch[i] += d * d[i] * (k - 1.0)      # (I + (k - 1) d d^T: a scale by k along d)
	xf.basis = stretch * turn * (link[3] as Transform3D).basis
	return xf

## A basis's rotation keeping its y axis's direction (the leg's line), x then z made square to it.
static func _along_y(b: Basis) -> Basis:
	var y := b.y.normalized()
	var x := (b.x - y * b.x.dot(y)).normalized()
	return Basis(x, y, x.cross(y))

## The inner classes live in their own files; the old names stay.
const Sync := preload("res://scripts/heroes/warden_sync.gd")
const Springs := preload("res://scripts/heroes/warden_springs.gd")
const Orbits := preload("res://scripts/heroes/warden_orbits.gd")
