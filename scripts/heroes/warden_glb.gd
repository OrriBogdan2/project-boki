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
## Root meta a kit sets while a runtime piece of the weapon is out (Grimble's stretched hook arm): the bones the Hero's
## data lists in "hide_while_chain" shrink away (item 76b.4), so one hook shows, never two.
const CHAIN_OUT := "chain_out"
const GRIP_L := "grip_l"                 # meta on a held weapon: warden_look "grip_l", read by HunterAnim
const WEAPON_MUZZLE := "weapon_muzzle"  # an empty on its mouth, a child of it: the Gun's Muzzle moves there

static var _neutral := {}       # Warden id -> the rig rest of its model in the neutral look (what a .glb is built on)
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
	var scene := load(path(arch)) as PackedScene
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
	var sync := Sync.new()
	sync.name = "Sync"
	sync.setup(root, skel, rest)
	glb.add_child(sync)
	sync.use_clips(glb, art(arch))
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
		_hold_weapon(root, glb, float(own.get("weapon_scale", 1.0)), Vector3(off[0], off[1], off[2]), own)
	_hold_shield(root, glb)
	sync.mood = WardenMood.make(root, glb, skel, art(arch))
	_halos(root, glb, look(art(arch)))      # (after the weapon is in the hands: a halo can ride the weapon)
	_smoke(root, look(art(arch)))
	_bloom(root, glb, look(art(arch)))

## Small pieces the match camera only sees as speckle (warden_look "far_hide": node names, Tarek's beads and fist
## shards) are drawn only up to FAR_HIDE_D from the camera; close-ups keep them.
static func _far_hide(glb: Node3D, own: Dictionary) -> void:
	for nm in own.get("far_hide", []):
		for n in glb.find_children(String(nm) + "*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).visibility_range_end = FAR_HIDE_D
			(n as GeometryInstance3D).visibility_range_end_margin = 1.0

## A model's wisps of smoke off its held weapon (warden_look.json "smoke": colour [r, g, b, a], amount, life (s),
## size (m), rise (m/s); Kael's demon blade): dark soft puffs from along the weapon's length that drift up and
## fade, in world space so they trail behind a swing.
static func _smoke(root: Node3D, own: Dictionary) -> void:
	var sm: Dictionary = own.get("smoke", {})
	var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	var weapon := gun.get_node_or_null(WEAPON) as Node3D if gun else null
	# (a skinned weapon: "at" names an anchor on it, "box" the half size round that anchor)
	var at_anchor := anchor(root, String(sm.get("at", ""))) if sm.has("at") else null
	if sm.is_empty() or (weapon == null and at_anchor == null):
		return
	var box := AABB()
	var meshes: Array = []
	if weapon is MeshInstance3D:
		meshes.append(weapon)
	if weapon:
		meshes.append_array(weapon.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		var a := (mi as MeshInstance3D).get_aabb()
		box = a if box.size == Vector3.ZERO else box.merge(a)
	if at_anchor:
		box = AABB(Vector3.ONE * -0.2, Vector3.ONE * 0.4)
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = int(sm.get("amount", 16))
	p.lifetime = float(sm.get("life", 1.4))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	# (along the blade only: the weapon's box past its grip end, `from` of its length)
	var k := float(sm.get("from", 0.3))
	var ax := 0
	for i in 3:
		if box.size[i] > box.size[ax]:
			ax = i
	var c := box.get_center()
	var ext := box.size * 0.5
	c[ax] += ext[ax] * k
	ext[ax] *= 1.0 - k
	p.position = c
	p.emission_box_extents = ext * 0.8
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, float(sm.get("rise", 0.5)), 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = curve
	var col := _param(sm.get("color", [0.05, 0.04, 0.05, 0.45])) as Color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.set_color(1, Color(col, 0.0))
	ramp.add_point(0.25, col)
	ramp.add_point(0.6, Color(col, col.a * 0.6))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	var sz := float(sm.get("size", 0.12))
	q.size = Vector2(sz, sz)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(at_anchor if at_anchor else weapon).add_child(p)

## A model's soft glow around what burns (warden_look.json "bloom": a list of {at: "weapon" or an anchor name,
## color [r, g, b, a], size (m), count (along the weapon's length, from `from` of it), depth_test}): additive
## camera-facing puffs, so a white-hot blade core or a magma arm glows past its own edges like the art's bloom
## instead of reading as flat white paint. World-sized, so it shrinks with the model at the match camera.
static func _bloom(root: Node3D, glb: Node3D, own: Dictionary) -> void:
	for b in own.get("bloom", []):
		var at := String(b.get("at", "weapon"))
		var col := _param(b.get("color", [1.0, 0.9, 0.7, 0.35])) as Color
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = not bool(b.get("depth_test", false))
		m.albedo_color = col
		m.albedo_texture = _puff()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var sz := float(b.get("size", 0.2))
		if at == "weapon":
			var gun := root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
			var weapon := gun.get_node_or_null(WEAPON) as Node3D if gun else null
			if weapon == null or not weapon is MeshInstance3D:
				continue
			var box := (weapon as MeshInstance3D).get_aabb()
			var ax := 0
			for i in 3:
				if box.size[i] > box.size[ax]:
					ax = i
			var n := int(b.get("count", 5))
			var k0 := float(b.get("from", 0.35))
			for j in n:
				var p := box.get_center()
				p[ax] = box.position[ax] + box.size[ax] * lerpf(k0, 0.95, (j + 0.5) / n)
				weapon.add_child(_bloom_quad(m, sz, p))
		else:
			var a := glb.find_child(at, true, false) as Node3D
			if a:
				# (on the root, following the anchor like the halos: the model's own surfaces stay toon-only)
				var q := _bloom_quad(m, sz, Vector3.ZERO)
				root.add_child(q)
				var follow := RemoteTransform3D.new()
				follow.name = "BloomFollow"
				follow.update_scale = false
				follow.update_rotation = false
				a.add_child(follow)
				follow.remote_path = follow.get_path_to(q)

static func _bloom_quad(m: Material, sz: float, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Bloom"
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.set_meta("glb_hidden", true)      # (kept out of the model's own bounds, like the hidden procedural parts)
	return mi

static var _puff_tex: Texture2D
## A soft round puff (a radial fall-off), made once.
static func _puff() -> Texture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff_tex = t
	return _puff_tex

## The .glb's own weapon (a mesh named WEAPON, modelled in the Gun node's space) goes into the hands in place
## of the procedural one; the Gun node and its Muzzle stay, so shots and grips are unchanged.
static func _hold_weapon(root: Node3D, glb: Node3D, wscale := 1.0, shift := Vector3.ZERO, own := {}) -> void:
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
	# warden_look "grip_l" (Gun space): the support hand's place on a hilt the hold's own "gl" would overshoot
	if own.has("grip_l"):
		weapon.set_meta(GRIP_L, Vector3(own["grip_l"][0], own["grip_l"][1], own["grip_l"][2]))
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

## Each frame, after the hunter's animation, puts every mapped bone where its rig node has moved it.
class Sync extends Node:
	var root: Node3D
	var skel: Skeleton3D
	var links: Array = []       # [bone index, rig node, node rest (model space) inverse, bone rest (skeleton space)]
	var springs := Springs.new()  # the spring_ bone chains (braids) swinging on top
	var rigid_legs := {}        # bone index -> true: legs retargeted without the Legs node's shear (retarget_rigid)
	var orbits := Orbits.new()    # the orbit_ props (seeing-stones) circling their bone
	var sway: WardenSway          # a body that lags on its spring, tumbling props (WardenSway), or null
	var clips: WardenClips        # a Hero's hand-keyed clips, or null: the bones follow the rig (BONES)
	var blade_root: Node3D        # a skinned weapon's FX points (item 76b), riding its bone
	var blade_tip: Node3D
	var blade_bone := -1
	var blade_root_bone := -1     # (the bone blade_root rides; data "root_bone", else blade_bone)
	var gun: Node3D
	var muzzle: Node3D
	var hand_nodes: Array = []    # [rig hand, its bone index]: the kits read the hands off the rig
	var built: Array = []         # the rig's weapon and prow last hidden (ids; _keep_one_weapon)
	var mood: WardenMood          # a face on glass and a hanging companion, when the art has them
	var hide_out: Array = []      # bone indices that shrink away while CHAIN_OUT
	var look_pose: Array = []     # [bone index, position, scale]: the player's sliders under the clips (_look_pose)
	var rig_root: Array = []      # data "rig_root": the root bone stays on the Rig under the clips (a hover)

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
		orbits.setup(skel)      # (the glTF import hangs a node riding a bone on a BoneAttachment3D under it)

	## Plays the Hero's clips when its art has them; and finds a skinned weapon's FX points.
	func use_clips(glb: Node3D, art_name: String) -> void:
		var dd := WardenClips.data(art_name)
		if bool(dd.get("legs_rigid", false)):
			for b in LEG_BONES:
				rigid_legs[WardenSkeleton.find(skel, b)] = true
		var bl: Dictionary = dd.get("blade", {})
		if not bl.is_empty():
			blade_root = glb.find_child(String(bl["root"]), true, false) as Node3D
			blade_tip = glb.find_child(String(bl["tip"]), true, false) as Node3D
			blade_bone = WardenSkeleton.find(skel, String(bl.get("bone", "hand.R")))
			# ("root_bone": the root empty rides another bone than the tip: Vex's barrels on the arm)
			blade_root_bone = WardenSkeleton.find(skel, String(bl.get("root_bone", bl.get("bone", "hand.R"))))
			gun = root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
			muzzle = gun.get_node_or_null("Muzzle") as Node3D if gun else null
		for b in dd.get("hide_while_chain", []):
			hide_out.append(WardenSkeleton.find(skel, String(b)))
		clips = WardenClips.make(root, glb, skel, art_name)
		sway = WardenSway.make(root, skel, dd.get("sway", {}))
		if clips:
			_look_pose()
			root.set_meta(WardenClips.DEATH_T, float((dd.get("states", {}) as Dictionary).get("dead_t", 0.0)))
		if clips and bool(dd.get("rig_root", false)):
			rig_root = links.filter(func(l): return int(l[0]) == WardenSkeleton.find(skel, "root"))
		if clips:
			for sd in ["L", "R"]:
				var nd := root.get_node_or_null(String(BONES["hand." + sd])) as Node3D
				var bi := WardenSkeleton.find(skel, "hand." + sd)
				if nd and bi >= 0:
					hand_nodes.append([nd, bi])

	## Hunter.equip rebuilds the rig's weapon and prow (a new match, a practice swap): on a skinned weapon those pieces
	## must stay hidden, so one weapon is drawn in every mode (item 76b.5).
	func _keep_one_weapon() -> void:
		if gun == null:
			return
		var holder := root.get_node_or_null(SHIELD_PATH)
		var last := gun.get_child(gun.get_child_count() - 1)
		var now := [last.get_instance_id(), holder.get_instance_id() if holder else 0]
		if now != built:
			built = now
			WardenGlb._skinned_weapon(root)
			WardenGlb._hide_shield(root)

	func _process(dt: float) -> void:
		_keep_one_weapon()
		if clips:
			_play(dt)
			springs.still = clips.cur in clips.d.get("still", [])
		else:
			apply()
			apply_blade()
		springs.fold = float(root.get_meta(WING_FOLD, 0.0))
		springs.step(dt)
		apply_blade()       # (again: a weapon that hangs on a chain, Pip's lantern, moved with the springs)
		orbits.look = root.get_meta(ORBIT_LOOK, Vector3.INF)
		orbits.step(dt)
		if mood:
			mood.step(dt)
		if sway:
			sway.tumble(dt, orbits.pivots)
		if bool(root.get_meta(CHAIN_OUT, false)):
			for bi in hide_out:
				skel.set_bone_pose_scale(int(bi), Vector3.ONE * 0.001)

	func apply() -> void:
		for l in links:
			skel.set_bone_global_pose(int(l[0]), _rig_pose(l))

	func _rig_pose(l: Array) -> Transform3D:
		var now := WardenGlb.model_xf(root, l[1])
		return WardenGlb.retarget_rigid(now, l) if rigid_legs.has(int(l[0])) else WardenGlb.retarget(now, l)

	## The player's MantleLook sliders under the clips: each contract bone's offset and scale for this look, against the
	## neutral rig the clips were keyed on. The clips key rotations; these stay on the bones (WardenClips strips the
	## position and scale tracks of the contract bones, the root's position aside).
	func _look_pose() -> void:
		var now: Dictionary = root.get_meta("rig_rest", {})
		var glob := {}
		for b in BONES:
			var bi := WardenSkeleton.find(skel, b)
			for l in links:
				if int(l[0]) == bi and now.has(b):
					glob[bi] = WardenGlb.retarget(now[b] as Transform3D, l)
		for bi in glob:
			var par := skel.get_bone_parent(int(bi))
			if par < 0 or not glob.has(par):
				continue
			var local: Transform3D = (glob[par] as Transform3D).affine_inverse() * (glob[bi] as Transform3D)
			look_pose.append([int(bi), local.origin, local.basis.get_scale()])

	## The clips' pose, mixed with the retargeted rig while a state hands over (clips.proc_w), then the rig's hands and
	## the Gun laid on what is shown, so kit FX leave the bodies you see.
	func _play(dt: float) -> void:
		for o in look_pose:
			skel.set_bone_pose_position(int(o[0]), o[1])
			skel.set_bone_pose_scale(int(o[0]), o[2])
		clips.step(dt)
		var w := clips.proc_w
		if w >= 1.0:
			apply()
		elif w > 0.0:
			var poses: Array = []
			for l in links:
				poses.append(skel.get_bone_global_pose(int(l[0])))
			for i in links.size():
				var l: Array = links[i]
				var pose: Transform3D = poses[i]
				skel.set_bone_global_pose(int(l[0]), pose.interpolate_with(
						_rig_pose(l), w))
		for l in rig_root:
			skel.set_bone_global_pose(int(l[0]), WardenGlb.retarget(WardenGlb.model_xf(root, l[1]), l))
		if sway:
			sway.step(dt)
		if w < 1.0:
			var inv := skel.global_transform
			for h in hand_nodes:
				(h[0] as Node3D).global_position = inv * skel.get_bone_global_pose(int(h[1])).origin
		apply_blade()

	## The Gun on the skinned blade: its origin at the blade's root, -Z along the blade, the Muzzle on the tip.
	func apply_blade() -> void:
		if blade_tip == null or blade_root == null or gun == null or not gun.is_inside_tree():
			return
		# (from the bone, not the attachment nodes: those update after the skeleton does, a frame late)
		var hand := skel.global_transform * skel.get_bone_global_pose(blade_bone)
		var a := skel.global_transform * skel.get_bone_global_pose(blade_root_bone) * blade_root.position
		var b := hand * blade_tip.position
		if a.distance_squared_to(b) < 0.000000000001:
			return
		var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT
		gun.global_transform = Transform3D(Basis.looking_at(b - a, up), a)
		if muzzle:
			muzzle.global_position = b

## Hanging pieces on bone chains (RIG_CONTRACT "Spring chains"): bones named spring_<name>_<i>, each the next
## one's parent, the first a child of a contract bone (a braid hangs from the head). Each chain is a rope of its
## joints in world space: it keeps its momentum (damped), is pulled back toward the shape it has riding its parent
## rigidly (firmer at the root than at the tip; a spring_hang_* chain toward straight down from its root), and
## keeps its links' lengths, so a braid trails behind a run,
## swings out of a turn and settles when she stands. The last bone is the tip (no skin of its own).
class Springs:
	const PREFIX := "spring_"
	const PULL := 0.2           # the share of the way back to the rest shape per 1/60 s, at the root
	const PULL_TIP := 0.07      # and at the tip
	const DAMP := 0.84          # the velocity kept per 1/60 s
	const WIND := 0.09          # m: how far a scarf tail's tip ripples at rest
	const FLOOR_CHAIN := PREFIX + "scarftail_tail"     # a tail lies on the ground, not through it (the feet's height)
	const FLOOR_UP := 0.04      # m its joints stay over the model's origin
	const FOLD := 0.75          # radians a folded wing tips back about the side axis through its root
	const TUCK := 0.8           # and turns in behind the back about the vertical
	const FLARE := 1.15         # radians a flared wing swings out to her side about the front-back axis
	var skel: Skeleton3D
	var chains: Array = []      # {ids: bone indices root -> tip, pts, prev: joint positions (world), wing}
	var fold := 0.0             # how far the wing chains are folded (1) or flared (-1) (WING_FOLD)
	var wind_t := 0.0
	var calm := false           # no ripple (a check measuring how a chain settles)
	var still := false          # no ripple: a statue pose (data "still": Claire's Rimelock)

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
				# (a "hang" chain, spring_hang<name>_<i>: a chain or rope whose rest shape is straight down from its
				# root, not riding its parent: Kael's Warchain hangs from his fist whichever way the arm points;
				# a "wing" chain folds back while the Warden skates, WING_FOLD)
				chains.append({"ids": ids, "pts": PackedVector3Array(), "prev": PackedVector3Array(),
					"hang": skel.get_bone_name(bi).begins_with(PREFIX + "hang"),
					"wing": skel.get_bone_name(bi).begins_with(PREFIX + "wing"),
					"wind": skel.get_bone_name(bi).begins_with(PREFIX + "scarftail"),
					"floor": skel.get_bone_name(bi).begins_with(FLOOR_CHAIN)})

	func _spring(bi: int) -> bool:
		return skel.get_bone_name(bi).begins_with(PREFIX)

	func step(dt: float) -> void:
		if chains.is_empty() or not skel.is_inside_tree():
			return
		var xf := skel.global_transform
		var inv := xf.affine_inverse()
		var k := clampf(dt * 60.0, 0.0, 3.0)
		wind_t += dt
		for ch in chains:
			var ids: Array = ch["ids"]
			var par := skel.get_bone_parent(int(ids[0]))
			# each joint riding the parent rigidly: its rest relative to the parent's
			var base := skel.get_bone_global_pose(par) * skel.get_bone_global_rest(par).affine_inverse()
			var rest: Array = []
			var want := PackedVector3Array()
			# a wing folds: its rest shape tipped back (+Z, behind) and turned in, about its root
			var turn := Transform3D.IDENTITY
			if bool(ch["wing"]) and absf(fold) > 0.001:
				var r0: Transform3D = base * skel.get_bone_global_rest(int(ids[0]))
				var r1: Transform3D = base * skel.get_bone_global_rest(int(ids[ids.size() - 1]))
				var out := signf(r1.origin.x - r0.origin.x)
				var tip_in := Basis(Vector3.UP, -out * TUCK * fold)
				# (a wing hanging down from its root, Sable's moth wings, tips the other way to go back too)
				var up := 1.0 if r1.origin.y >= r0.origin.y else -1.0
				if fold > 0.0:
					turn = Transform3D(Basis(Vector3.RIGHT, up * FOLD * fold) * tip_in, Vector3.ZERO)
				else:
					turn = Transform3D(Basis(Vector3.BACK, up * out * FLARE * fold), Vector3.ZERO)
				turn = Transform3D(Basis.IDENTITY, r0.origin) * turn * Transform3D(Basis.IDENTITY, -r0.origin)
			for bi in ids:
				var r: Transform3D = turn * base * skel.get_bone_global_rest(int(bi))
				rest.append(r)
				want.append(xf * r.origin)
			var n := want.size()
			if ch["wind"] and not calm and not still:
				# (a long cloth tail never hangs dead: a slow travelling ripple, stronger toward its tip)
				for i in range(1, n):
					var u := float(i) / float(n - 1)
					var ripple := Vector3(sin(wind_t * 1.9 - i * 0.7), 0.35 * sin(wind_t * 1.3 - i * 0.9), 0.0)
					want[i] += xf.basis * ripple * WIND * u * u
			if ch["hang"]:
				for i in range(1, n):
					var seg := (xf * (rest[i] as Transform3D).origin).distance_to(
							xf * (rest[i - 1] as Transform3D).origin)
					want[i] = want[i - 1] + Vector3.DOWN * seg
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
				if bool(ch["wing"]) and fold < -0.3:
					pull = lerpf(pull, 1.0, 0.85)      # (flared through a flip: the wing turns with her, no twist)
				pts[i] = p.lerp(want[i], 1.0 - pow(1.0 - pull, k))
			pts[0] = want[0]
			prev[0] = want[0]
			for i in range(1, n):
				var d := pts[i] - pts[i - 1]
				var ln := want[i].distance_to(want[i - 1])
				pts[i] = pts[i - 1] + d.normalized() * ln if d.length() > 1e-5 else want[i]
				if ch["floor"]:
					pts[i].y = maxf(pts[i].y, xf.origin.y + FLOOR_UP)
			ch["pts"] = pts
			ch["prev"] = prev
			for j in n - 1:
				var r: Transform3D = rest[j]
				var a := inv * pts[j]
				var from := ((rest[j + 1] as Transform3D).origin - r.origin).normalized()
				var to := (inv * pts[j + 1] - a).normalized()
				var c := from.dot(to)
				var q := Quaternion(from, to) if c < 0.99999 and c > -0.999 else Quaternion.IDENTITY
				skel.set_bone_global_pose(int(ids[j]), Transform3D(Basis(q) * r.basis, a))

## Props on an orbit (RIG_CONTRACT "Orbits"): a .glb node named orbit_<name> riding a bone carries unskinned
## props (Tarek's three seeing-stones round his head, each built facing out from the orbit's centre). Each frame
## the node turns round its own up axis (its rest is upright) at ORBIT_HZ, so every prop circles the bone
## and keeps facing outward, and each prop bobs on its own phase. The orbit is data here; nothing is baked.
class Orbits:
	const PREFIX := "orbit_"
	const ORBIT_HZ := 0.12      # turns a second
	const BOB := 0.025          # m, each prop up and down
	const BOB_HZ := 0.5
	const LOOKERS := "orbit_stones"   # the orbit whose props are eyes (Tarek's seeing-stones)
	const LOOK_RATE := 7.0      # 1/s: how fast they turn to what they watch
	var look := Vector3.INF     # world point they watch (ORBIT_LOOK), INF for none
	var pivots: Array = []      # [node, its rest transform, [prop, its rest position]...]
	var t := 0.0

	func setup(glb: Node) -> void:
		for n in glb.find_children(PREFIX + "*", "Node3D", true, false):
			var nd := n as Node3D
			if nd is MeshInstance3D or nd.get_child_count() == 0:
				continue
			var props: Array = []
			for ch in nd.get_children():
				if ch is Node3D:
					props.append([ch, (ch as Node3D).position, (ch as Node3D).quaternion])
			pivots.append([nd, nd.transform, props])

	func step(dt: float) -> void:
		t += dt
		for pv in pivots:
			var nd: Node3D = pv[0]
			var rest: Transform3D = pv[1]
			nd.transform = rest * Transform3D(Basis(Vector3.UP, TAU * ORBIT_HZ * t), Vector3.ZERO)
			var props: Array = pv[2]
			for i in props.size():
				var pr: Node3D = props[i][0]
				pr.position = (props[i][1] as Vector3) + Vector3.UP * BOB * sin(TAU * BOB_HZ * t + i * 2.1)
				if nd.name == LOOKERS and pr.is_inside_tree():
					_face(pr, props[i][2], dt)

	## A seeing-stone's eye (-Z on the prop) turns toward what the kit is watching, then back to looking outward.
	func _face(pr: Node3D, rest: Quaternion, dt: float) -> void:
		var want := rest
		if look.is_finite() and pr.global_position.distance_squared_to(look) > 0.01:
			var to := Basis.looking_at(look - pr.global_position, Vector3.UP).get_rotation_quaternion()
			want = (pr.get_parent() as Node3D).global_basis.get_rotation_quaternion().inverse() * to
		pr.quaternion = pr.quaternion.slerp(want, 1.0 - exp(-LOOK_RATE * dt))
