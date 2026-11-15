class_name HunterBody
extends RefCounted
## A procedural Hunter's body (Models.hunter): its materials and every mesh on its rig (legs, torso, head and
## face, hair, the race's parts, arms, the Warden's gear), then merged into a handful of draws. A Warden drawn
## from its .glb skips all of it: Models.hunter builds only the rig's pivots (they drive the .glb's bones) and
## the pieces the .glb keeps (WardenGlb.KEEP), so its first build costs no cold procedural meshes.

## Optional pivots on the torso that parts hang from and a .glb Warden's bones ride (torso space, m).
const RACE_PIVOTS := {"vulpin": {"Tail": Vector3(0, 0.02, 0.26)}, "scalefolk": {"Tail": Vector3(0, 0.0, 0.24)},
	"owlet": {"Tail": Vector3(0, 0.0, 0.26)}, "sprig": {"Wings": Vector3(0, 0.5, 0.3)}}
## A Warden gear's own pivots (z times the build: they sit on the back).
const GEAR_PIVOTS := {"thief": ["Cape", "Scarf"], "archer": ["Cape"], "gunslinger": ["Scarf"], "rimewright": ["Scarf"]}
const GEAR_AT := {"Cape": Vector3(0, 0.56, 0.24), "Scarf": Vector3(0, 0.6, 0.18)}

## The race's and the Warden gear's optional pivots on the torso.
static func pivots(torso: Node3D, rid: String, arch: String, bw: float) -> void:
	var race: Dictionary = RACE_PIVOTS.get(rid, {})
	for nm in race:
		Models._pivot(torso, nm, race[nm])
	for nm in GEAR_PIVOTS.get(arch, []):
		Models._pivot(torso, nm, GEAR_AT[nm] * Vector3(1.0, 1.0, bw))

## The three materials the held weapon is built from (all a .glb Warden's procedural pieces need).
static func gun_mats(team_col: Color) -> Dictionary:
	var m_dark := Models.toon(Color("2b2a33"))
	var m_acc := Models.toon(Color.from_hsv(team_col.h, minf(1.0, team_col.s * 1.08), team_col.v * 0.94))
	var m_gun := Models.shiny(Color("4a4d5c"), 0.5)
	m_acc.set_shader_parameter("rim_amount", 0.75)
	m_acc.set_shader_parameter("gloss", 0.12)
	Models.painted(m_acc, 1, 0.3, 0.3, 0.26)
	Models.painted(m_dark, 2, 0.18, 0.2, 0.2)
	Models.painted(m_gun, 3, 0.12, 0.1, 0.1)
	return {"dark": m_dark, "acc": m_acc, "gun": m_gun}

## The body's palette from the outfit colour (HeroGear's context "m"): a saturated coat, a pale shirt, dark
## trousers, team colour on the strongest shapes (hood, cape, crest, pauldron tops, shield), gold on the edges.
## A clean value structure (dark trousers and leather, a mid-dark coat, light shirt and trim), each colour set in
## HSV from the outfit's hue so nothing goes muddy; the team colour is kept off the cloth.
static func mats(hero_col: Color, team_col: Color, lk: Dictionary) -> Dictionary:
	var m := gun_mats(team_col)
	var coat_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.1, 0.06, 0.7), clampf(hero_col.v * 0.6, 0.36, 0.6))
	var shirt_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.45, 0.04, 0.3), 0.9)
	m["body"] = Models.toon(coat_col)
	m["shirt"] = Models.toon(shirt_col)
	m["pants"] = Models.toon(Color.from_hsv(fposmod(coat_col.h + 0.02, 1.0), 0.28, 0.2))
	m["leather"] = Models.toon(Color("6b4330").lerp(hero_col, 0.06))
	m["skin"] = Models.toon(lk["skin_col"])
	m["hair"] = Models.toon(lk["hair_col"])
	m["gold"] = Models.shiny(Color("dcaa48"), 0.65)
	m["hero"] = Models.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.05, 0.06, 0.8),
			clampf(hero_col.v * 0.85, 0.45, 0.85)))
	m["trim"] = Models.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.05, 0.75),
			clampf(hero_col.v * 0.95, 0.55, 0.95)))
	# dark gunmetal: the highlights and the fresnel do the work
	m["steel"] = Models.shiny(Color("b0b2b8").lerp(hero_col, 0.06), 0.6)
	m["glow"] = Models.toon(hero_col.lerp(Color.WHITE, 0.35), false, 1.4)
	var soft := StandardMaterial3D.new()
	soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soft.albedo_color = Color(hero_col.lerp(Color.WHITE, 0.5), 0.28)
	soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m["glow_soft"] = soft
	m["bone"] = Models.toon(Color("efe3c8"))
	m["wood"] = Models.toon(Color("7a5236"))
	m["fur"] = Models.toon(Color("4a3428").lerp(hero_col, 0.08))
	m["feather"] = Models.toon(Color("f6f0e2"))
	m["cloak"] = Models.toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.06, 0.6),
			clampf(hero_col.v * 0.5, 0.3, 0.5)))
	m["hat"] = Models.toon(Color("6e4a30").lerp(hero_col, 0.1))
	(m["gold"] as ShaderMaterial).set_shader_parameter("glow", 0.08)
	for k in ["body", "shirt", "hair", "hero", "trim", "cloak", "hat", "feather"]:
		(m[k] as ShaderMaterial).set_shader_parameter("rim_amount", 0.75)
	(m["skin"] as ShaderMaterial).set_shader_parameter("sss", 0.45)
	(m["hair"] as ShaderMaterial).set_shader_parameter("gloss", 0.35)
	(m["leather"] as ShaderMaterial).set_shader_parameter("gloss", 0.15)
	(m["bone"] as ShaderMaterial).set_shader_parameter("gloss", 0.3)
	for k in ["body", "shirt", "pants", "hero", "trim", "cloak", "feather"]:
		Models.painted(m[k], 1, 0.3, 0.3, 0.26)
	Models.painted(m["leather"], 2, 0.26, 0.26, 0.24)
	Models.painted(m["hat"], 2, 0.26, 0.24, 0.24)
	Models.painted(m["skin"], 4, 0.0, 0.0, 0.18)     # no part gradient on skin: the jaw, nose and ears would show seams
	Models.painted(m["hair"], 5, 0.3, 0.24, 0.24)
	Models.painted(m["fur"], 5, 0.3, 0.3, 0.3)
	Models.painted(m["gold"], 3, 0.1, 0.0, 0.0)
	Models.painted(m["steel"], 3, 0.14, 0.12, 0.14)
	(m["steel"] as ShaderMaterial).set_shader_parameter("sky_ao", 0.12)
	Models.painted(m["bone"], 0, 0.3, 0.2, 0.2)
	Models.painted(m["wood"], 2, 0.2, 0.2, 0.2)
	return m

## Builds the body on the rig Models.hunter made. c is HeroGear's context (torso, skirt, pl/pr, arms, knees, bw,
## cw, fem, rid, bare, arch, hero_col, m) plus what the body reads: cls, um, look (the appearance), lk, team_col,
## legs. Adds "gear" and "hk" to it.
static func dress(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var torso: Node3D = c["torso"]
	var arch: String = c["arch"]
	var heavy_gear := arch in ["juggernaut", "bulwark", "dredge", "ashwick"]
	_legs(c, heavy_gear)
	_torso(c)
	var gear := Node3D.new()
	gear.name = "Gear"
	torso.add_child(gear)
	c["gear"] = gear
	_arms(c, heavy_gear)
	if c["um"]: Unmasked.dress(c, c["look"])
	else: HeroGear.dress(arch, c)
	_onto_head(torso)
	_merge(c)

## Legs swing from the hip: a tapered thigh, a knee guard, and a boot in one piece hanging from the knee (so the
## leg can bend), with a cuff that overlaps the trousers.
static func _legs(c: Dictionary, heavy_gear: bool) -> void:
	var m: Dictionary = c["m"]
	var bw: float = c["bw"]
	var boot_k := float(Models.CLASS_LOOK.get(c["cls"], {}).get("boots", 1.0))
	var thief: bool = c["arch"] == "thief"
	var m_cuff: Material = m["leather"] if thief else m["trim"]
	if heavy_gear:
		m_cuff = m["steel"]
	for sd in ["L", "R"]:
		var leg := (c["legs"] as Node3D).get_node("Leg" + sd) as Node3D
		Models.part(leg, Models.limb(0.108 * bw, 0.068 * bw, 0.34, 0.16), m["pants"], Vector3(0, -0.12, 0))
		var knee: Node3D = c["knees"][sd]
		if not heavy_gear:
			# (plate knee cops cover it on heavies)
			Models.part(knee, Models.sphere(0.068, 14), m["pants"], Vector3(0, 0.0, 0.0))
			Models.part(knee, HeroKit.dome_plate("kneepad", 0.065, 0.45, 0.8, 0.2, 0.012),
					m["dark"] if thief else m["leather"], Vector3(0, 0.0, -0.045), Vector3.ONE,
					Vector3(-PI * 0.5 + 0.1, 0, 0))
		Models.part(knee, HeroKit.boot(boot_k), m["leather"], Vector3.ZERO)
		Models.part(knee, HeroKit.sole(boot_k), m["dark"], Vector3.ZERO)
		Models.part(knee, HeroKit.cuff(0.074, 0.088, 0.06), m_cuff, Vector3(0, -0.06, 0.005))

## Hips, the sculpted torso (waist, ribcage, chest or bust, shoulder blades), the neck flaring into the shoulders
## so the head sits on the body, the glider pack, then the head with its face and hair, and the race's parts.
static func _torso(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var torso: Node3D = c["torso"]
	var bw: float = c["bw"]
	var fem: bool = c["fem"]
	var um: bool = c["um"]
	var rid: String = c["rid"]
	var lk: Dictionary = c["lk"]
	Models.part(torso, Models.lathe(Models.smooth_curve(PackedVector2Array([Vector2(0, -0.08), Vector2(0.18, -0.07),
			Vector2(0.225, -0.02), Vector2(0.22, 0.06), Vector2(0.2, 0.1), Vector2(0, 0.1)]), 3), 40, "hips"),
			m["pants"], Vector3(0, 0.02, 0), Vector3((1.04 if fem else 1.0) * bw, 1.0, bw))
	Models.part(torso, HeroKit.torso(fem), m["body"], Vector3(0, 0.33, 0), Vector3(c["cw"], 1.0, bw * 0.9))
	var nr := 0.072 if fem else 0.088
	Models.part(torso, Models.lathe(Models.smooth_curve(PackedVector2Array([Vector2(0, 0.0), Vector2(nr * 2.0, 0.0),
			Vector2(nr * 1.3, 0.035), Vector2(nr, 0.08), Vector2(nr * 0.98, 0.16), Vector2(0, 0.16)]), 3), 28,
			"neck%.3f" % nr), m["skin"], Vector3(0, 0.58, 0))
	if not um:      # (the Empty's shroud covers its back: no glider pack, no class marks)
		Models.part(torso, Models.box(0.3, 0.32, 0.1), m["leather"], Vector3(0, 0.36, 0.24 * bw))
		Models.part(torso, Models.cyl(0.075, 0.075, 0.44, 12), Models.toon(Color("f3eee2")),
				Vector3(0, 0.56, 0.27 * bw), Vector3.ONE, Vector3(0, 0, PI / 2))
		for sx in [-1.0, 1.0]:
			Models.part(torso, Models.cyl(0.08, 0.08, 0.06, 12), m["acc"], Vector3(0.2 * sx, 0.56, 0.27 * bw),
					Vector3.ONE, Vector3(0, 0, PI / 2))
		Models.class_marks(torso, c["cls"], bw, m["acc"], m["trim"])
	# the sculpted head (jaw, cheeks, brow, chin per race and gender) with its face
	var hk := HeroKit.head_key(rid, fem)
	c["hk"] = hk
	Models.part(torso, HeroKit.head(hk), m["skin"], Vector3(0, 0.86, 0), Vector3.ONE, Vector3.ZERO, "Head")
	if rid == "human" and not um:
		for sx in [-1.0, 1.0]:
			var ear := HeroKit.loft("ear", [Vector3(0, -0.035, 0), Vector3(0, 0.0, 0.008), Vector3(0, 0.035, 0.02)],
					[Vector2(0.03, 0.012), Vector2(0.04, 0.014), Vector2(0.022, 0.01)], 10, Vector3.RIGHT, 0.75)
			Models.part(torso, ear, m["skin"], Vector3(0.226 * sx * (0.98 if fem else 1.03), 0.85, 0.012),
					Vector3.ONE, Vector3(0, 0.25 * sx, 0))
	if um: Unmasked.face(torso, c["look"])
	else: Models.hunter_face(torso, lk, m["dark"], m["skin"], c["team_col"])
	# what the archetype wears on its head decides how much hair shows (a hat: all but the crown; a hood or
	# helm: only what spills out below)
	var cov := HeroGear.cover(c["arch"], c["bare"])
	var hair_n := Node3D.new()
	hair_n.name = "Hair"
	torso.add_child(hair_n)
	if rid == "human":
		HeroHair.human(hair_n, int(lk["hair"]), fem, m["hair"], hk, cov)
	else:
		Models.race_hair(hair_n, rid, int(lk["hair"]), m["hair"], lk["hair_col"], lk["skin_col"],
				cov in ["hood", "helm"])
	Models.race_parts(torso, rid, m["skin"], m["hair"], m["dark"], lk["skin_col"], lk["hair_col"], c["hero_col"])

## Arms hang from the shoulders with an elbow and a hand on joints of their own, so HunterAnim can put the hands
## on the weapon's grips (solving the elbows) or let them swing free: a sleeve on the shoulder, a forearm "ArmX"
## and a cuff on the elbow, a mitten glove on the hand. Rounded joints overlap so a bent arm never shows a gap.
static func _arms(c: Dictionary, heavy_gear: bool) -> void:
	var m: Dictionary = c["m"]
	var arch: String = c["arch"]
	var hk2 := float(Models.CLASS_LOOK.get(c["cls"], {}).get("hands", 1.0)) * (1.3 if arch == "juggernaut" else 1.0)
	var m_glove: Material = m["dark"] if arch == "thief" else m["leather"]
	if heavy_gear:
		m_glove = m["steel"]
	if c["um"]:
		m_glove = m["skin"]
	for sd in ["L", "R"]:
		var sx := -1.0 if sd == "L" else 1.0
		var piv: Node3D = c["arms"][sd][0]
		var elbow: Node3D = c["arms"][sd][1]
		var hand: Node3D = c["arms"][sd][2]
		Models.part(piv, Models.sphere(0.088, 16), m["body"], Vector3(0, -0.005, 0), Vector3(1.0, 1.0, 1.0))
		Models.part(piv, Models.limb(0.088, 0.064, 0.25, 0.16), m["body"], Vector3(0, -0.1, 0))
		Models.part(elbow, Models.sphere(0.064, 14), m["body"])
		Models.part(elbow, Models.limb(0.068, 0.05, 0.22, 0.14), m["body"], Vector3(0, -0.09, 0), Vector3.ONE,
				Vector3.ZERO, "Arm" + sd)
		Models.part(hand, HeroKit.mitten(), m_glove, Vector3(0, 0.0, 0.0), Vector3(hk2, hk2, hk2))
		Models.part(hand, HeroKit.thumb(), m_glove, Vector3(-0.042 * sx * hk2, 0.01, -0.03 * hk2), Vector3.ONE * hk2,
				Vector3(0, 0, 0.35 * sx))
		Models.part(hand, HeroKit.cuff(0.062 * hk2, 0.078 * hk2, 0.05), m_glove if heavy_gear else m["leather"],
				Vector3(0, 0.065, 0))
		if arch == "juggernaut":
			for k in 3:
				Models._spike(hand, m["bone"], Vector3((k - 1) * 0.03 * hk2, -0.09 * hk2, -0.05 * hk2),
						Vector3(0, -0.3, -1.0), 0.014, 0.05)

## The head and everything on it turn and nod together from the neck: the head-high parts, the hair and the
## gear on the head move onto the HeadPivot.
static func _onto_head(torso: Node3D) -> void:
	var head := torso.get_node("HeadPivot") as Node3D
	for ch in torso.get_children():
		if ch is MeshInstance3D and (String(ch.name).begins_with("@") or ch.name == "Head") \
				and (ch as Node3D).position.y > 0.72 and not ch.has_meta("stay"):
			torso.remove_child(ch)
			head.add_child(ch)
			(ch as Node3D).position.y -= 0.68
	for nm in ["Hair", "Gear"]:
		var nd := torso.get_node(nm) as Node3D
		torso.remove_child(nd)
		head.add_child(nd)
		nd.position.y -= 0.68

## Bakes each rig node's loose parts into one mesh per look.
static func _merge(c: Dictionary) -> void:
	var torso: Node3D = c["torso"]
	var head := torso.get_node("HeadPivot")
	for nd in [torso, head, head.get_node("Hair"), head.get_node("Gear")]:
		Models.merge_static(nd)
	for nm in ["Skirt", "Cape", "Scarf", "PauldronL", "PauldronR"]:
		if torso.has_node(nm): Models.merge_static(torso.get_node(nm))
	for sd in ["L", "R"]:
		var leg := (c["legs"] as Node3D).get_node("Leg" + sd) as Node3D
		Models.merge_static(leg)
		Models.merge_static(leg.get_node("Knee"))
		for nd in c["arms"][sd]:
			Models.merge_static(nd)
