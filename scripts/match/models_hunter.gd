class_name ModelsHunter
## The hunter body. Moved out of Models; callers still use the Models facade.


## A hunter: the class sets the size and hit radius, the archetype (HeroKit.ARCHES; by default the
## class's own) the silhouette and gear, and the look the person inside it: a player's look
## (PlayerLook) becomes the Warden's likeness nudged by the player (MantleLook), or the player's own
## person for a look from MantleLook.at_home(). outfit names a colourway that replaces the palette
## (galleries); "bare" leaves the head uncovered. arch "" takes the look's "arch", else the class default.
static func hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	ShadowPolicy.keep += 1       # a Hunter's parts cast at any size
	var root := _hunter(cls, team_col, weapon, outfit, appearance, arch)
	ShadowPolicy.keep -= 1
	return root

static func _hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	var um := Unmasked.is_look(appearance)       # your own character: the hunter rig without a hunter's gear
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
			arch = ""            # your own person at home: no Warden's gear, shape or class size
			cls = "medium"
		race = ModelsLook.RACES[int(lk["race"])]
	var rid: String = race["id"]
	var root := Node3D.new()
	var bare := outfit == "bare"
	var oi: int = ModelsLook.OUTFIT_KEYS.find(outfit)
	var hero_col: Color = ModelsLook.OUTFIT_COLS[oi] if oi >= 0 else lk["outfit_col"]
	if um: hero_col = Unmasked.colour(appearance)      # the shroud's colour
	# the outfit is the gear's colourway: a saturated coat, a pale shirt, dark trousers, team colour
	# on the strongest shapes (hood, cape, crest, pauldron tops, shield), gold on the edges
	# a clean value structure (dark trousers and leather, a mid-dark coat, light shirt and trim), each
	# colour set in HSV from the outfit's hue so nothing goes muddy; the team colour is kept off the
	# cloth and only marks the key shapes
	var coat_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.1, 0.06, 0.7), clampf(hero_col.v * 0.6, 0.36, 0.6))
	var shirt_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.45, 0.04, 0.3), 0.9)
	var pants_col := Color.from_hsv(fposmod(coat_col.h + 0.02, 1.0), 0.28, 0.2)
	var m_body := ModelsBase.toon(coat_col)
	var m_shirt := ModelsBase.toon(shirt_col)
	var m_pants := ModelsBase.toon(pants_col)
	var m_leather := ModelsBase.toon(Color("6b4330").lerp(hero_col, 0.06))
	var skin_c: Color = lk["skin_col"]
	var hair_c: Color = lk["hair_col"]
	var m_skin := ModelsBase.toon(skin_c)
	var m_hair := ModelsBase.toon(hair_c)
	var m_dark := ModelsBase.toon(Color("2b2a33"))
	var m_acc := ModelsBase.toon(Color.from_hsv(team_col.h, minf(1.0, team_col.s * 1.08), team_col.v * 0.94))
	var m_gold := ModelsBase.shiny(Color("dcaa48"), 0.65); m_gold.set_shader_parameter("glow", 0.08)
	var m_gun := ModelsBase.shiny(Color("4a4d5c"), 0.5)
	var m_hero := ModelsBase.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.05, 0.06, 0.8), clampf(hero_col.v * 0.85, 0.45, 0.85)))
	var m_trim := ModelsBase.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.05, 0.75), clampf(hero_col.v * 0.95, 0.55, 0.95)))
	var m_steel := ModelsBase.shiny(Color("b0b2b8").lerp(hero_col, 0.06), 0.6)      # dark gunmetal: the highlights and the fresnel do the work
	var m_glow := ModelsBase.toon(hero_col.lerp(Color.WHITE, 0.35), false, 1.4)
	var m_glow_soft := StandardMaterial3D.new()
	m_glow_soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_glow_soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_glow_soft.albedo_color = Color(hero_col.lerp(Color.WHITE, 0.5), 0.28)
	m_glow_soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var m_bone := ModelsBase.toon(Color("efe3c8"))
	var m_wood := ModelsBase.toon(Color("7a5236"))
	var m_fur := ModelsBase.toon(Color("4a3428").lerp(hero_col, 0.08))
	var m_feather := ModelsBase.toon(Color("f6f0e2"))
	var m_cloak := ModelsBase.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.06, 0.6), clampf(hero_col.v * 0.5, 0.3, 0.5)))
	var m_hat := ModelsBase.toon(Color("6e4a30").lerp(hero_col, 0.1))
	for mm in [m_body, m_shirt, m_hair, m_acc, m_hero, m_trim, m_cloak, m_hat, m_feather]:
		(mm as ShaderMaterial).set_shader_parameter("rim_amount", 0.75)
	m_skin.set_shader_parameter("sss", 0.45)
	m_hair.set_shader_parameter("gloss", 0.35)
	m_leather.set_shader_parameter("gloss", 0.15)
	m_bone.set_shader_parameter("gloss", 0.3)
	for mm in [m_body, m_shirt, m_pants, m_acc, m_hero, m_trim, m_cloak, m_feather]:
		ModelsBake.painted(mm, 1, 0.3, 0.3, 0.26)
	ModelsBake.painted(m_leather, 2, 0.26, 0.26, 0.24); ModelsBake.painted(m_hat, 2, 0.26, 0.24, 0.24); ModelsBake.painted(m_dark, 2, 0.18, 0.2, 0.2)
	ModelsBake.painted(m_skin, 4, 0.0, 0.0, 0.18)     # no part gradient on skin: the jaw, nose and ears would show seams
	ModelsBake.painted(m_hair, 5, 0.3, 0.24, 0.24); ModelsBake.painted(m_fur, 5, 0.3, 0.3, 0.3)
	ModelsBake.painted(m_gun, 3, 0.12, 0.1, 0.1); ModelsBake.painted(m_gold, 3, 0.1, 0.0, 0.0); ModelsBake.painted(m_steel, 3, 0.14, 0.12, 0.14); m_steel.set_shader_parameter("sky_ao", 0.12)
	ModelsBake.painted(m_bone, 0, 0.3, 0.2, 0.2); ModelsBake.painted(m_wood, 2, 0.2, 0.2, 0.2)
	m_acc.set_shader_parameter("gloss", 0.12)
	var rig := Node3D.new(); rig.name = "Rig"; root.add_child(rig)
	var legs := Node3D.new(); legs.name = "Legs"; rig.add_child(legs)
	var bw: float = lk["build"]
	bw *= float(ModelsLook.CLASS_LOOK.get(cls, {}).get("build", 1.0)) * float(Arch.body(arch).get("build", 1.0))
	var boot_k := float(ModelsLook.CLASS_LOOK.get(cls, {}).get("boots", 1.0))
	var fem := int(lk["gender"]) == 0
	var heavy_gear := arch in ["juggernaut", "bulwark", "dredge", "ashwick"]
	# legs swing from the hip: a tapered thigh, a knee guard, and a boot in one piece hanging from
	# the knee (so the leg can bend), with a cuff that overlaps the trousers
	var knees := {}
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new(); leg.name = "LegL" if sx < 0.0 else "LegR"
		leg.position = Vector3(0.11 * sx * bw, 0.44, 0)
		legs.add_child(leg)
		ModelsBase.part(leg, ModelsBase.limb(0.108 * bw, 0.068 * bw, 0.34, 0.16), m_pants, Vector3(0, -0.12, 0))
		var knee := Node3D.new(); knee.name = "Knee"; knee.position = Vector3(0, -0.2, 0)
		leg.add_child(knee)
		knees["L" if sx < 0.0 else "R"] = knee
		if not heavy_gear:
			ModelsBase.part(knee, ModelsBase.sphere(0.068, 14), m_pants, Vector3(0, 0.0, 0.0))      # (plate knee cops cover it on heavies)
			ModelsBase.part(knee, HeroKit.dome_plate("kneepad", 0.065, 0.45, 0.8, 0.2, 0.012), m_leather if arch != "thief" else m_dark, Vector3(0, 0.0, -0.045), Vector3.ONE, Vector3(-PI * 0.5 + 0.1, 0, 0))
		ModelsBase.part(knee, HeroKit.boot(boot_k), m_leather, Vector3.ZERO)
		ModelsBase.part(knee, HeroKit.sole(boot_k), m_dark, Vector3.ZERO)
		ModelsBase.part(knee, HeroKit.cuff(0.074, 0.088, 0.06), m_steel if heavy_gear else (m_trim if arch != "thief" else m_leather), Vector3(0, -0.06, 0.005))
	legs.scale.y = lk["limbs"] * float(Arch.body(arch).get("legs", 1.0))      # the Warden's leg length
	var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.42 * legs.scale.y, 0); rig.add_child(torso)
	root.set_meta("hip_y", torso.position.y)      # HunterAnim keeps the torso on the legs at this height
	var chest_w := bw * (0.92 if fem else 1.12) * float(lk["shoulders"])
	# hips, then the sculpted torso (waist, ribcage, chest or bust, shoulder blades), then the neck
	# flaring into the shoulders so the head sits on the body, not on a peg
	ModelsBase.part(torso, ModelsBase.lathe(ModelsBase.smooth_curve(PackedVector2Array([Vector2(0, -0.08), Vector2(0.18, -0.07), Vector2(0.225, -0.02), Vector2(0.22, 0.06), Vector2(0.2, 0.1), Vector2(0, 0.1)]), 3), 40, "hips"),
		m_pants, Vector3(0, 0.02, 0), Vector3((1.04 if fem else 1.0) * bw, 1.0, bw))
	ModelsBase.part(torso, HeroKit.torso(fem), m_body, Vector3(0, 0.33, 0), Vector3(chest_w, 1.0, bw * 0.9))
	var nr := 0.072 if fem else 0.088
	ModelsBase.part(torso, ModelsBase.lathe(ModelsBase.smooth_curve(PackedVector2Array([Vector2(0, 0.0), Vector2(nr * 2.0, 0.0), Vector2(nr * 1.3, 0.035), Vector2(nr, 0.08), Vector2(nr * 0.98, 0.16), Vector2(0, 0.16)]), 3), 28, "neck%.3f" % nr), m_skin, Vector3(0, 0.58, 0))
	var skirt_n := ModelsLook._pivot(torso, "Skirt", Vector3(0, 0.07, 0))
	# the glider pack: a rolled wing on a back plate (under whatever the archetype carries)
	if not um:      # (the Empty's shroud covers its back)
		ModelsBase.part(torso, ModelsBase.box(0.3, 0.32, 0.1), m_leather, Vector3(0, 0.36, 0.24 * bw))
		ModelsBase.part(torso, ModelsBase.cyl(0.075, 0.075, 0.44, 12), ModelsBase.toon(Color("f3eee2")), Vector3(0, 0.56, 0.27 * bw), Vector3.ONE, Vector3(0, 0, PI / 2))
		for sx in [-1.0, 1.0]:
			ModelsBase.part(torso, ModelsBase.cyl(0.08, 0.08, 0.06, 12), m_acc, Vector3(0.2 * sx, 0.56, 0.27 * bw), Vector3.ONE, Vector3(0, 0, PI / 2))
	if not um: ModelsLook._class_marks(torso, cls, bw, m_acc, m_trim)      # (the shroud covers the back it would sit on)
	# head: the sculpted head (jaw, cheeks, brow, chin per race and gender) with its face
	var hk := HeroKit.head_key(rid, fem)
	ModelsBase.part(torso, HeroKit.head(hk), m_skin, Vector3(0, 0.86, 0), Vector3.ONE, Vector3.ZERO, "Head")
	if rid == "human" and not um:
		for sx in [-1.0, 1.0]:
			var ear := HeroKit.loft("ear", [Vector3(0, -0.035, 0), Vector3(0, 0.0, 0.008), Vector3(0, 0.035, 0.02)], [Vector2(0.03, 0.012), Vector2(0.04, 0.014), Vector2(0.022, 0.01)], 10, Vector3.RIGHT, 0.75)
			ModelsBase.part(torso, ear, m_skin, Vector3(0.226 * sx * (1.03 if not fem else 0.98), 0.85, 0.012), Vector3.ONE, Vector3(0, 0.25 * sx, 0))
	if um: Unmasked.face(torso, appearance)
	else: ModelsFace._face(torso, lk, m_dark, m_skin, team_col)
	# what the archetype wears on its head decides how much hair shows (a hat: all but the crown; a
	# hood or helm: only what spills out below)
	var cov := HeroGear.cover(arch, bare)
	var hair_n := Node3D.new(); hair_n.name = "Hair"; torso.add_child(hair_n)
	if rid == "human":
		HeroHair.human(hair_n, int(lk["hair"]), fem, m_hair, hk, cov)
	else:
		ModelsHair._race_hair(hair_n, rid, int(lk["hair"]), m_hair, hair_c, skin_c, cov in ["hood", "helm"])
	ModelsHair._race_parts(torso, rid, m_skin, m_hair, m_dark, skin_c, hair_c, hero_col)
	var gear := Node3D.new(); gear.name = "Gear"; torso.add_child(gear)
	# the arms and the gun move together from the shoulders ("Aim"), for recoil, reloads and poses
	var aim := Node3D.new(); aim.name = "Aim"; aim.position = Vector3(0, 0.5, 0.0); torso.add_child(aim)
	var gun := Node3D.new(); gun.name = "Gun"; gun.position = Vector3(0.22, -0.18, -0.18); aim.add_child(gun)
	# arms: they hang from the shoulders with an elbow and a hand on joints of their own, so HunterAnim
	# can put the hands on the weapon's grips (solving the elbows) or let them swing free.
	# ArmXPivot (shoulder) > sleeve, Elbow > forearm "ArmX" and a cuff, Hand > a mitten glove.
	# Rounded joints overlap at the shoulder and elbow so a bent arm never shows a gap.
	var hk2 := float(ModelsLook.CLASS_LOOK.get(cls, {}).get("hands", 1.0)) * (1.3 if arch == "juggernaut" else 1.0)
	var m_glove: Material = m_skin if um else (m_steel if heavy_gear else (m_dark if arch == "thief" else m_leather))
	var arms := {}
	# (archetype body "arms": long arms as its art draws them; HunterAnim solves the same lengths)
	var arm_k := float(Arch.body(arch).get("arms", 1.0))
	root.set_meta("arm_k", arm_k)
	for sx in [-1.0, 1.0]:
		var sd := "L" if sx < 0.0 else "R"
		var piv := Node3D.new(); piv.name = "Arm%sPivot" % sd; piv.position = Vector3(0.215 * sx * chest_w,
				0.5 * float(Arch.body(arch).get("torso", 1.0)), 0.0)
		piv.position.x *= float(Arch.body(arch).get("shoulder", 1.0))
		torso.add_child(piv)
		ModelsBase.part(piv, ModelsBase.sphere(0.088, 16), m_body, Vector3(0, -0.005, 0), Vector3(1.0, 1.0, 1.0))
		ModelsBase.part(piv, ModelsBase.limb(0.088, 0.064, 0.25, 0.16), m_body, Vector3(0, -0.1, 0))
		var elbow := Node3D.new(); elbow.name = "Elbow"; elbow.position.y = -0.21 * arm_k; piv.add_child(elbow)
		ModelsBase.part(elbow, ModelsBase.sphere(0.064, 14), m_body)
		ModelsBase.part(elbow, ModelsBase.limb(0.068, 0.05, 0.22, 0.14), m_body, Vector3(0, -0.09, 0), Vector3.ONE, Vector3.ZERO, "Arm" + sd)
		var hand := Node3D.new(); hand.name = "Hand"; hand.position.y = -0.235 * arm_k; elbow.add_child(hand)
		ModelsBase.part(hand, HeroKit.mitten(), m_glove, Vector3(0, 0.0, 0.0), Vector3(hk2, hk2, hk2) * Vector3(1.0, 1.0, 1.0))
		ModelsBase.part(hand, HeroKit.thumb(), m_glove, Vector3(-0.042 * sx * hk2, 0.01, -0.03 * hk2), Vector3.ONE * hk2, Vector3(0, 0, 0.35 * sx))
		ModelsBase.part(hand, HeroKit.cuff(0.062 * hk2, 0.078 * hk2, 0.05), m_glove if heavy_gear else m_leather, Vector3(0, 0.065, 0))
		if arch == "juggernaut":
			for k in 3:
				ModelsHair._spike(hand, m_bone, Vector3((k - 1) * 0.03 * hk2, -0.09 * hk2, -0.05 * hk2), Vector3(0, -0.3, -1.0), 0.014, 0.05)
		arms[sd] = [piv, elbow, hand]
	# shoulder pieces hang on their own pivots at the shoulders, which HunterAnim turns part of the
	# way with the arm, so raised arms never come up through the plate
	var pads := {}
	for sx in [-1.0, 1.0]:
		var pd := Node3D.new(); pd.name = "PauldronL" if sx < 0.0 else "PauldronR"
		pd.position = Vector3(0.215 * sx * chest_w, 0.5, 0.0)
		torso.add_child(pd)
		pads["L" if sx < 0.0 else "R"] = pd
	var ctx := {"torso": torso, "skirt": skirt_n, "gear": gear, "pl": pads["L"], "pr": pads["R"], "arms": arms, "knees": knees, "bw": bw, "cw": chest_w,
		"fem": fem, "rid": rid, "hk": hk, "bare": bare, "arch": arch, "hero_col": hero_col,
		"m": {"body": m_body, "shirt": m_shirt, "pants": m_pants, "leather": m_leather, "skin": m_skin, "hair": m_hair, "dark": m_dark, "acc": m_acc,
			"gold": m_gold, "gun": m_gun, "hero": m_hero, "trim": m_trim, "steel": m_steel, "glow": m_glow, "glow_soft": m_glow_soft, "bone": m_bone,
			"wood": m_wood, "fur": m_fur, "feather": m_feather, "cloak": m_cloak, "hat": m_hat}}
	if um: Unmasked.dress(ctx, appearance)
	else: HeroGear.dress(arch, ctx)
	ModelsGear.gun_parts(gun, weapon, m_gun, m_dark, m_acc)
	gun.scale = Vector3.ONE * float(ModelsLook.CLASS_LOOK.get(cls, {}).get("weapon", 1.0))     # heavies carry big guns
	if not gun.has_node("Mag"):
		ModelsBase.part(gun, ModelsBase.box(0.06, 0.15, 0.09), m_acc, Vector3(0, -0.13, -0.24), Vector3.ONE, Vector3(0.15, 0, 0), "Mag")
	if not gun.has_node("Muzzle"):
		var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0, 0.02, -0.75); gun.add_child(muzzle)
	var shoulder := Node3D.new(); shoulder.name = "Shoulder"; shoulder.position = Vector3(-0.3, 0.8, 0.04); torso.add_child(shoulder)
	# a paraglider canopy that unfolds above the pack: an arched wing in stripes, with lines down to the harness
	var glider := Node3D.new(); glider.name = "Glider"; glider.position = Vector3(0, 0.62, 0.12); glider.visible = false
	torso.add_child(glider)
	var gskin := String(lk["glider"])
	glider.set_meta("skin", gskin)
	var gtrail := Gliders.trail(gskin, team_col, hero_col)
	if gtrail:
		gtrail.position = Vector3(0, 1.0, 0.3)
		glider.add_child(gtrail)
	var gset := ModelsBake._glider_set(gskin)
	var g_line := ModelsBase.toon(Color("5a4636"), false)
	for pc in [[gset[0], Gliders.canopy_material(gskin, team_col, hero_col)], [gset[1], g_line]]:
		var gmi := MeshInstance3D.new()
		gmi.mesh = pc[0]
		gmi.material_override = pc[1]
		ShadowPolicy.judge(gmi)
		glider.add_child(gmi)
	var ring := MeshInstance3D.new(); ring.name = "TeamRing"; ring.mesh = ModelsBase.flat_quad(1.0)
	ring.material_override = ModelsBase.ring_mat(team_col, 0.16); ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	# the head and everything on it turn and nod together from the neck
	var head := Node3D.new(); head.name = "HeadPivot"
	head.position = Vector3(0, 0.68 * float(Arch.body(arch).get("torso", 1.0)), 0)
	torso.add_child(head)
	for ch in torso.get_children():
		if ch is MeshInstance3D and (String(ch.name).begins_with("@") or ch.name == "Head") and (ch as Node3D).position.y > 0.72 and not ch.has_meta("stay"):
			torso.remove_child(ch)
			head.add_child(ch)
			(ch as Node3D).position.y -= 0.68
	for nd in [hair_n, gear]:
		torso.remove_child(nd); head.add_child(nd)
		(nd as Node3D).position.y -= 0.68
	# a Warden drawn from its .glb hides this body: its loose parts are dropped, not merged (the pivots stay,
	# they drive the .glb's bones; "Focus" is kept and drawn)
	var drop := WardenGlb.will_dress(arch)
	for nd in [torso, head, hair_n, gear]:
		ModelsBake.merge_static(nd, drop)
	for nm in ["Skirt", "Cape", "Scarf", "PauldronL", "PauldronR", "Focus"]:
		if torso.has_node(nm): ModelsBake.merge_static(torso.get_node(nm), drop and nm != "Focus")
	for nm in ["LegL", "LegR"]:
		ModelsBake.merge_static(legs.get_node(nm), drop)
		ModelsBake.merge_static(legs.get_node(nm + "/Knee"), drop)
	for sd in ["L", "R"]:
		for nd in arms[sd]:
			ModelsBake.merge_static(nd, drop)
	if weapon not in ["twin_blades", "arc_bolts"]:
		ModelsBake.merge_static(gun)      # (the twin blades' second dagger is handed to the left hand by HunterAnim)
	# the race's proportions: head size, how broad the body is, overall height
	var hkk := float(race["head"]) * (1.06 if arch == "thief" else 1.12)    # big-headed like a hero brawler (faces read from the match camera), heroic not chibi; the thief leaner
	hkk *= float(lk["head"]) * float(Arch.body(arch).get("head", 1.0))      # the Warden's head size
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
		legs.scale = Vector3(bk, legs.scale.y, bk)      # (keeps the leg length set above)
		var bks := Vector3(bk, 1.0 + (bk - 1.0) * 0.35, bk)
		for nm in ["Skirt", "Cape", "Scarf"]:
			var pv := torso.get_node_or_null(nm) as Node3D
			if pv:
				pv.position *= bks; pv.scale = bks
		for sd in ["L", "R"]:
			var pd := pads[sd] as Node3D
			pd.position.x *= bk; pd.scale = Vector3(bk, 1.0, bk)
		# arms: thicker or thinner, but the same length (the elbows are solved to the grips)
		for sd in ["L", "R"]:
			var ap := torso.get_node("Arm%sPivot" % sd) as Node3D
			ap.position.x *= bk
			for n in [ap, ap.get_node("Elbow"), ap.get_node("Elbow/Hand")]:
				for ch in (n as Node3D).get_children():
					if ch is MeshInstance3D: (ch as Node3D).scale = Vector3(bk, 1.0, bk)
	if um: Shrouds.bind(root)
	ModelsBake.bake_part_y(root)
	root.set_meta("mats", ModelsBake.collect_mats(root))
	for mm in root.get_meta("mats"):
		var sm := mm as ShaderMaterial
		sm.set_shader_parameter("paint", 0.012)    # clean, sleek surfaces: barely any blotching
		# painted lighting for heroes: deeper, cooler shadows against a warm key, and the baked
		# occlusion in each piece's vertex colour (folds, roots of locks, under brims and plates)
		sm.set_shader_parameter("vertex_ao", true)
		sm.set_shader_parameter("shade", 0.37)
		sm.set_shader_parameter("shadow_tint", Color(0.6, 0.6, 0.86))
		sm.set_shader_parameter("light_tint", Color(1.08, 1.0, 0.9))
		hero_look(sm)
	WardenGlb.dress(root, arch, lk)      # its 3D model, when it has one and uses it (else this procedural one)
	root.set_meta("race", rid)
	root.set_meta("cls", cls)
	root.set_meta("arch", arch)
	root.set_meta("wid", weapon)
	HunterAnim.rest_pose(root)       # hands on the weapon even where nothing animates it (portraits, galleries)
	var rs := float(race["scale"])
	var ck := float(ModelsLook.CLASS_LOOK.get(cls, {}).get("size", 1.0))
	var body := Arch.body(arch)
	var size_k := float(body.get("size", 1.0)) * float(HeroGearPair.body(arch)["size"])
	var bulk := float(body.get("bulk", 1.0))
	var look_k := rs * ck * size_k * float(lk["height"])
	root.scale = Vector3(bulk, 1.0, bulk) * float(Data.CLASSES[cls]["scale"]) * look_k
	# the ring under your feet is the real hitbox: its world radius is hit_r, whatever your size
	var ring_k := 2.0 * Arch.hit_r(arch, Data.CLASSES[cls]) / (float(Data.CLASSES[cls]["scale"]) * look_k)
	ring.scale = Vector3(1.0 / bulk, 1.0, 1.0 / bulk) * ring_k
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
		if v != null: keep[nm] = v
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
		sm.set_shader_parameter("shadow_tint", Color(0.66, 0.66, 0.8))     # metal shadows a cool grey, not violet
	sm.set_shader_parameter("top_light", 1.0)
	if metal:
		sm.set_shader_parameter("gloss", maxf(float(keep.get("gloss", 0.0)), 0.7))
