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
## Procedural pieces that stay when the .glb dresses the hunter (the contract's "nodes the game keeps").
const KEEP := ["Gun", "Glider", "TeamRing", "Shield", "Shoulder", "Halo", "Focus"]
## glTF material name -> the toon shader's painted surface (RIG_CONTRACT "Materials").
const SLOTS := {"skin": 4, "hair": 5, "cloth": 1, "leather": 2, "metal": 3, "fur": 5, "eyes": 0, "team": 1, "glow": 0,
	"card": 0}
## The "card" slot: see-through alpha cards (wings) on their own shader, both sides drawn, no ink.
const CARD: Shader = preload("res://shaders/warden_card.gdshader")
## Slots a MantleLook colour pick tints: slot -> [the pick in Models.hunter's look, the Warden's own colour].
const TINTS := {"skin": ["skin_col", "skin"], "hair": ["hair_col", "hair_col"], "eyes": ["eye_col", "eyes"]}
const TINT_MAX := 0.35         # a pick moves a painted slot's colour at most this much (x, per channel)
const NO_INK := ["hair", "eyes", "glow", "card"]   # slots drawn without the ink outline shell
## Pieces built as clean geometry (tools/meshy/warden_parts.py), "<slot>-<tag>": they take the ink line even on
## an inkless slot (the hair goes without it for a scan's ragged strands, not for a woven braid).
const INK_TAGS := ["braid"]
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
const GLOW := 1.6              # emission of the glow slot (mechanical eyes, cracks), x its painted colour
## The ink shell on a painted atlas: half the procedural heroes' width per metre of camera distance (the same
## 4 mm line close up), and never more than the fit's ink room at a vertex (outline.gdshader ink_mask). At the
## match camera a full-width line round every belt, buckle and candle of a scanned model added up to a smudge.
const INK_WIDTH := 0.0006
const INK_FAR_THIN := 0.8      # the ink this much thinner at the match camera (outline.gdshader far_thin)
## Empties every .glb exports on its bones (RIG_CONTRACT "Anchor empties"); kits find them with anchor().
const ANCHORS := ["anchor_head_top", "anchor_chest"]
## Settings key: Warden id -> "procedural" for a Warden the player keeps on its procedural model (or a design
## variant's name, art()).
const SETTING := "warden_models"
const WEAPON := "weapon"        # the .glb node that replaces the procedural weapon (RIG_CONTRACT)
const WEAPON_MAG := "weapon_mag"  # its magazine, a child of it
const WEAPON_SPIN := "weapon_spin"  # its spinning barrels, a child of it (HunterAnim spins them while firing)
## the second weapon of a twin hold (Sable's left crossbow), a child of WEAPON placed so that HunterAnim's twin
## hold hands it to the left hand (its node x < -0.04: _setup_weapon moves it into the Offhand)
const WEAPON_OFF := "weapon_offhand"

static var _neutral := {}       # Warden id -> the rig rest of its model in the neutral look (what a .glb is built on)
static var _ink: ShaderMaterial  # the painted atlas's ink shell (INK_WIDTH), shared
static var _ink_own := {}        # a warden_look "ink" (as JSON) -> that model's own ink shell
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
	mats.append_array(_toon(glb, lk, MantleLook.warden(arch), look(art(arch))))
	_lights(glb, look(art(arch)))
	_halos(root, glb, look(art(arch)))
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
	var off := weapon.find_child(WEAPON_OFF, true, false) as Node3D
	if off:
		var at := WardenGlb.model_xf(gun, off)
		off.get_parent().remove_child(off)
		off.owner = null
		gun.add_child(off)
		off.transform = at
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
		var anchor_node := glb.find_child(String(hs["anchor"]), true, false) as Node3D
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
static func _toon(glb: Node, lk: Dictionary, warden: Dictionary, own := {}) -> Array:
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
			var m := Models.toon(src.albedo_color if src else Color.WHITE, not slot in NO_INK or tag in INK_TAGS)
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
					m.next_pass = _painted_ink(own.get("ink", {}))
			if slot == "glow":
				m.set_shader_parameter("glow", GLOW)
			var per_slot: Dictionary = (own.get("slots", {}) as Dictionary).get(slot, {})
			var over: Dictionary = (own.get("painted", {}) as Dictionary).merged(per_slot, true)
			for k in over:
				m.set_shader_parameter(k, _param(over[k]))
			(mi as MeshInstance3D).set_surface_override_material(si, m)
			_far_look(m, src, slot, tag, own)
			out.append(m)
	return out

## A model's warden_look "ink" {"far_thin", "color"} gives it its own ink shell: thinner at the match camera
## and a softer colour (Pip's fur tufts and tail clumps: a near-black line there read as black specks).
static func _painted_ink(own_ink: Dictionary = {}) -> ShaderMaterial:
	if not own_ink.is_empty():
		var key := JSON.stringify(own_ink)
		if not _ink_own.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = Models.OUTLINE
			mat.set_shader_parameter("width", INK_WIDTH)
			mat.set_shader_parameter("ink_mask", true)
			mat.set_shader_parameter("far_thin", float(own_ink.get("far_thin", INK_FAR_THIN)))
			if own_ink.has("color"):
				mat.set_shader_parameter("color", _param(own_ink["color"]))
			_ink_own[key] = mat
		return _ink_own[key]
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
## rigidly (firmer at the root than at the tip; a spring_hang_* chain toward straight down from its root), and
## keeps its links' lengths, so a braid trails behind a run,
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
				# a chain named spring_hang_* hangs straight down from its root (a lantern on its bail)
				var hang := skel.get_bone_name(bi).begins_with(PREFIX + "hang_")
				chains.append({"ids": ids, "pts": PackedVector3Array(), "prev": PackedVector3Array(), "hang": hang})

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
			if bool(ch.get("hang", false)):
				for i in range(1, n):
					want[i] = want[i - 1] + Vector3.DOWN * (rest[i] as Transform3D).origin.distance_to(
							(rest[i - 1] as Transform3D).origin) * absf(xf.basis.get_scale().y)
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
				var c := from.dot(to)
				var q := Quaternion(from, to) if c < 0.99999 and c > -0.999 else Quaternion.IDENTITY
				skel.set_bone_global_pose(int(ids[j]), Transform3D(Basis(q) * r.basis, a))
