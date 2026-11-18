class_name ModelsHunter
## Part of the Models split (docs/CODE_HEALTH.md): the hunter body.


## The class emblem on the glider pack (light: a chevron, medium: a diamond, heavy: a shield).
static func class_marks(torso: Node3D, cls: String, bw: float, _m_acc: Material, m_trim: Material) -> void:
	var m_cls := ModelsLook.class_mat(cls)
	var at := Vector3(0, 0.655, 0.27 * bw)
	var tilt := Vector3(-1.05, 0, 0)  # lying back on the rolled wing, facing up and back
	match cls:
		"light":
			for sx in [-1.0, 1.0]:
				ModelsBase.part(
					torso,
					ModelsBase.box(0.035, 0.15, 0.025),
					m_cls,
					at + Vector3(0.045 * sx, 0.0, 0.0),
					Vector3.ONE,
					tilt + Vector3(0, 0, 0.6 * sx)
				)
		"medium":
			ModelsBase.part(
				torso, ModelsBase.box(0.12, 0.12, 0.025), m_cls, at, Vector3.ONE, tilt + Vector3(0, 0, PI * 0.25)
			)
		"heavy":
			ModelsBase.part(
				torso, ModelsBase.box(0.2, 0.16, 0.03), m_cls, at + Vector3(0, 0.01, 0.0), Vector3.ONE, tilt
			)
			ModelsBase.part(
				torso, ModelsBase.box(0.08, 0.06, 0.032), m_trim, at + Vector3(0, 0.012, 0.005), Vector3.ONE, tilt
			)


## A hunter: the class sets the size and hit radius, the archetype (HeroKit.ARCHES; by default the
## class's own) the silhouette and gear, and the look the person inside it: a player's look
## (PlayerLook) becomes the Warden's likeness nudged by the player (MantleLook), or the player's own
## person for a look from MantleLook.at_home(). outfit names a colourway that replaces the palette
## (galleries); "bare" leaves the head uncovered. arch "" takes the look's "arch", else the class default.
static func hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	ShadowPolicy.keep += 1  # a Hunter's parts cast at any size
	var root := _hunter(cls, team_col, weapon, outfit, appearance, arch)
	ShadowPolicy.keep -= 1
	return root


static func _hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	var um := Unmasked.is_look(appearance)  # your own character: the hunter rig without a hunter's gear
	var lk: Dictionary
	var race: Dictionary
	if um:
		# the Unmasked as MantleLook's own-person params (every slider neutral), its build and colour
		lk = MantleLook.own(PlayerLook.clean(Unmasked.legacy(appearance)))
		lk["build"] = float(Unmasked.BUILD_WIDTH[int(Unmasked.clean(appearance)["build"])])
		lk["skin_col"] = Unmasked.VOID_SKIN
		race = Unmasked.race(appearance)
		arch = "unmasked"
	else:
		arch = HeroKit.arch_for(cls, arch, appearance)
		lk = MantleLook.params(arch, appearance)
		if lk["own"]:
			arch = ""  # your own person at home: no Warden's gear, shape or class size
			cls = "medium"
		race = ModelsLook.RACES[int(lk["race"])]
	var rid: String = race["id"]
	var root := Node3D.new()
	var bare := outfit == "bare"
	var oi: int = ModelsLook.OUTFIT_KEYS.find(outfit)
	var hero_col: Color = ModelsLook.OUTFIT_COLS[oi] if oi >= 0 else lk["outfit_col"]
	if um:
		hero_col = Unmasked.colour(appearance)  # the shroud's colour
	# a Warden drawn from its .glb hides this body: only its rig (the pivots drive the .glb's bones) and the pieces
	# the .glb keeps are built, not the body's meshes (HunterBody)
	var rig_only := WardenGlb.will_dress(arch)
	var mats: Dictionary = HunterBody.gun_mats(team_col) if rig_only else HunterBody.mats(hero_col, team_col, lk)
	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var legs := Node3D.new()
	legs.name = "Legs"
	rig.add_child(legs)
	var bw: float = lk["build"]
	bw *= float(ModelsLook.CLASS_LOOK.get(cls, {}).get("build", 1.0)) * float(Arch.body(arch).get("build", 1.0))
	var fem := int(lk["gender"]) == 0
	# legs swing from the hip, the boot hangs from the knee (so the leg can bend)
	var knees := {}
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if sx < 0.0 else "LegR"
		leg.position = Vector3(0.11 * sx * bw, 0.44, 0)
		legs.add_child(leg)
		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0, -0.2, 0)
		leg.add_child(knee)
		knees["L" if sx < 0.0 else "R"] = knee
	legs.scale.y = lk["limbs"] * float(Arch.body(arch).get("legs", 1.0))  # the Warden's leg length
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.42 * legs.scale.y, 0)
	rig.add_child(torso)
	root.set_meta("hip_y", torso.position.y)  # HunterAnim keeps the torso on the legs at this height
	var chest_w := bw * (0.92 if fem else 1.12) * float(lk["shoulders"])
	var skirt_n := ModelsLook._pivot(torso, "Skirt", Vector3(0, 0.07, 0))
	HunterBody.pivots(torso, rid, arch, bw)
	# the arms and the gun move together from the shoulders ("Aim"), for recoil and poses
	var aim := Node3D.new()
	aim.name = "Aim"
	aim.position = Vector3(0, 0.5, 0.0)
	torso.add_child(aim)
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0.22, -0.18, -0.18)
	aim.add_child(gun)
	# arms hang from the shoulders with an elbow and a hand on joints of their own: ArmXPivot (shoulder) > Elbow > Hand
	var arms := {}
	# (archetype body "arms": long arms as its art draws them; HunterAnim solves the same lengths)
	var arm_k := float(Arch.body(arch).get("arms", 1.0))
	root.set_meta("arm_k", arm_k)
	for sx in [-1.0, 1.0]:
		var sd := "L" if sx < 0.0 else "R"
		var piv := Node3D.new()
		piv.name = "Arm%sPivot" % sd
		piv.position = Vector3(0.215 * sx * chest_w, 0.5 * float(Arch.body(arch).get("torso", 1.0)), 0.0)
		piv.position.x *= float(Arch.body(arch).get("shoulder", 1.0))
		torso.add_child(piv)
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position.y = -0.21 * arm_k
		piv.add_child(elbow)
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position.y = -0.235 * arm_k
		elbow.add_child(hand)
		arms[sd] = [piv, elbow, hand]
	# shoulder pieces hang on their own pivots at the shoulders, which HunterAnim turns part of the
	# way with the arm, so raised arms never come up through the plate
	var pads := {}
	for sx in [-1.0, 1.0]:
		var pd := Node3D.new()
		pd.name = "PauldronL" if sx < 0.0 else "PauldronR"
		pd.position = Vector3(0.215 * sx * chest_w, 0.5, 0.0)
		torso.add_child(pd)
		pads["L" if sx < 0.0 else "R"] = pd
	ModelsGear.gun_parts(gun, weapon, mats["gun"], mats["dark"], mats["acc"])
	gun.scale = Vector3.ONE * float(ModelsLook.CLASS_LOOK.get(cls, {}).get("weapon", 1.0))  # heavies carry big guns
	if not gun.has_node("Mag"):
		ModelsBase.part(
			gun,
			ModelsBase.box(0.06, 0.15, 0.09),
			mats["acc"],
			Vector3(0, -0.13, -0.24),
			Vector3.ONE,
			Vector3(0.15, 0, 0),
			"Mag"
		)
	if not gun.has_node("Muzzle"):
		var muzzle := Node3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0, 0.02, -0.75)
		gun.add_child(muzzle)
	var shoulder := Node3D.new()
	shoulder.name = "Shoulder"
	shoulder.position = Vector3(-0.3, 0.8, 0.04)
	torso.add_child(shoulder)
	# a paraglider canopy that unfolds above the pack: an arched wing in stripes, with lines down to the harness
	var glider := Node3D.new()
	glider.name = "Glider"
	glider.position = Vector3(0, 0.62, 0.12)
	glider.visible = false
	torso.add_child(glider)
	var gskin := String(lk["glider"])
	glider.set_meta("skin", gskin)
	var gtrail := Gliders.trail(gskin, team_col, hero_col)
	if gtrail:
		gtrail.position = Vector3(0, 1.0, 0.3)
		glider.add_child(gtrail)
	var gset := ModelsBake._glider_set(gskin)
	for pc in [
		[gset[0], Gliders.canopy_material(gskin, team_col, hero_col)],
		[gset[1], ModelsBase.toon(Color("5a4636"), false)]
	]:
		var gmi := MeshInstance3D.new()
		gmi.mesh = pc[0]
		if pc[0] == gset[0]:
			gmi.name = "Canopy"  # GliderHeat sets its heat on this material
		gmi.material_override = pc[1]
		ShadowPolicy.judge(gmi)
		glider.add_child(gmi)
	var ring := MeshInstance3D.new()
	ring.name = "TeamRing"
	ring.mesh = ModelsBase.flat_quad(1.0)
	ring.material_override = SideRings.mat(team_col, 0.16)
	ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	# the head and everything on it turn and nod together from the neck
	var head := Node3D.new()
	head.name = "HeadPivot"
	head.position = Vector3(0, 0.68 * float(Arch.body(arch).get("torso", 1.0)), 0)
	torso.add_child(head)
	if not rig_only:
		HunterBody.dress(
			{
				"torso": torso,
				"legs": legs,
				"skirt": skirt_n,
				"pl": pads["L"],
				"pr": pads["R"],
				"arms": arms,
				"knees": knees,
				"bw": bw,
				"cw": chest_w,
				"fem": fem,
				"rid": rid,
				"bare": bare,
				"arch": arch,
				"hero_col": hero_col,
				"m": mats,
				"cls": cls,
				"um": um,
				"look": appearance,
				"lk": lk,
				"team_col": team_col
			}
		)
	if weapon not in ["twin_blades", "arc_bolts"]:
		ModelsBake.merge_static(gun)  # (the twin blades' second dagger is handed to the left hand by HunterAnim)
	# the race's proportions: head size, how broad the body is, overall height
	# big-headed like a hero brawler (faces read from the match camera), heroic not chibi; the thief leaner
	var hkk := float(race["head"]) * (1.06 if arch == "thief" else 1.12)
	hkk *= float(lk["head"]) * float(Arch.body(arch).get("head", 1.0))  # the Warden's head size
	var bk := float(race["bulk"]) * float(HeroGearPair.body(arch)["bulk"])
	head.scale = Vector3(hkk * float(lk["face_w"]), hkk * float(lk["jaw"]), hkk)
	# (a Warden can stand taller in the neck)
	head.position.y += (hkk - 1.0) * 0.05 + float(Arch.body(arch).get("neck", 0.0))
	if bk != 1.0:
		for ch in torso.get_children():
			if ch is MeshInstance3D and not String(ch.name).begins_with("Tail") and ch.name != "Wings":
				(ch as Node3D).scale = Vector3(bk, 1.0 + (bk - 1.0) * 0.35, bk)
		aim.scale = Vector3(lerpf(1.0, bk, 0.75), 1.0, 1.0)
		shoulder.position.x *= bk
		legs.scale = Vector3(bk, legs.scale.y, bk)  # (keeps the leg length set above)
		var bks := Vector3(bk, 1.0 + (bk - 1.0) * 0.35, bk)
		for nm in ["Skirt", "Cape", "Scarf"]:
			var pv := torso.get_node_or_null(nm) as Node3D
			if pv:
				pv.position *= bks
				pv.scale = bks
		for sd in ["L", "R"]:
			var pd := pads[sd] as Node3D
			pd.position.x *= bk
			pd.scale = Vector3(bk, 1.0, bk)
		# arms: thicker or thinner, but the same length (the elbows are solved to the grips)
		for sd in ["L", "R"]:
			var ap := torso.get_node("Arm%sPivot" % sd) as Node3D
			ap.position.x *= bk
			for n in [ap, ap.get_node("Elbow"), ap.get_node("Elbow/Hand")]:
				for ch in (n as Node3D).get_children():
					if ch is MeshInstance3D:
						(ch as Node3D).scale = Vector3(bk, 1.0, bk)
	if um:
		Shrouds.bind(root)
	ModelsBake.bake_part_y(root)
	root.set_meta("mats", ModelsBake.collect_mats(root))
	for mm in root.get_meta("mats"):
		var sm := mm as ShaderMaterial
		sm.set_shader_parameter("paint", 0.012)  # clean, sleek surfaces: barely any blotching
		# painted lighting for heroes: deeper, cooler shadows against a warm key, and the baked
		# occlusion in each piece's vertex colour (folds, roots of locks, under brims and plates)
		sm.set_shader_parameter("vertex_ao", true)
		sm.set_shader_parameter("shade", 0.37)
		sm.set_shader_parameter("shadow_tint", Color(0.6, 0.6, 0.86))
		sm.set_shader_parameter("light_tint", Color(1.08, 1.0, 0.9))
		hero_look(sm)
	WardenGlb.dress(root, arch, lk)  # its 3D model, when it has one and uses it (else this procedural one)
	root.set_meta("race", rid)
	root.set_meta("cls", cls)
	root.set_meta("arch", arch)
	root.set_meta("wid", weapon)
	HunterAnim.rest_pose(root)  # hands on the weapon even where nothing animates it (portraits, galleries)
	var rs := float(race["scale"])
	var ck := float(ModelsLook.CLASS_LOOK.get(cls, {}).get("size", 1.0))
	var body := Arch.body(arch)
	var size_k := float(body.get("size", 1.0)) * float(HeroGearPair.body(arch)["size"])
	var bulk := WardenBulk.apply(root, float(body.get("bulk", 1.0)))  # (a .glb Warden thins its skin instead)
	var look_k := rs * ck * size_k * float(lk["height"])
	root.scale = bulk * float(Data.CLASSES[cls]["scale"]) * look_k
	# the ring under your feet is the real hitbox: its world radius is hit_r, whatever your size
	var ring_k := 2.0 * Arch.hit_r(arch, Data.CLASSES[cls]) / (float(Data.CLASSES[cls]["scale"]) * look_k)
	ring.scale = Vector3.ONE / bulk * ring_k
	var torso_node := root.find_child("Torso", true, false) as Node3D
	if torso_node != null:
		torso_node.scale.x *= float(body.get("chest", 1.0))
	return root


## Moves a hunter's toon material onto the hero shader (hero_toon.gdshader) with the same settings,
## plus the hero tuning: a crisper light/shadow split, shadows that keep their colour, a coloured
## fresnel rim (cool on metal, the surface's own colour elsewhere) and a little top light.
static func hero_look(sm: ShaderMaterial) -> void:
	if sm.shader != ModelsBase.TOON:
		return
	var keep := {}
	for u in ModelsBase.TOON.get_shader_uniform_list():
		var nm := String(u["name"])
		var v = sm.get_shader_parameter(nm)
		if v != null:
			keep[nm] = v
	sm.shader = ModelsBase.HERO
	for nm in keep:
		sm.set_shader_parameter(nm, keep[nm])
	var surf := int(keep.get("surface", 0))
	var metal := surf == 3
	sm.set_shader_parameter("ramp", 0.5)
	sm.set_shader_parameter("shadow_sat", 0.4)
	sm.set_shader_parameter("fres", 0.75 if surf == 4 else (1.15 if metal else 1.0))
	sm.set_shader_parameter("fres_tint", 0.55 if metal else 0.7)
	if metal:
		sm.set_shader_parameter("shadow_tint", Color(0.66, 0.66, 0.8))  # metal shadows a cool grey, not violet
	sm.set_shader_parameter("top_light", 1.0)
	if metal:
		sm.set_shader_parameter("gloss", maxf(float(keep.get("gloss", 0.0)), 0.7))
