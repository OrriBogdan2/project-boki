class_name ModelsGear
## Guns, gear drops and breakables. Moved out of Models; callers still use the Models facade.


## The gun's pieces, shared by hunters and the weapons lying around on the islands: chunky,
## exaggerated hero-shooter shapes (rounded receivers, flared muzzles, fat grips and stocks) with a
## glowing accent per weapon. The barrel runs along -Z; the trigger hand holds near the origin.
static func gun_parts(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	if HeroArms.build(gun, weapon, m_gun, m_dark, m_acc): return      # Dolm's and Ostra's fixed weapons
	var glow := func(c: Color) -> ShaderMaterial: return ModelsBase.toon(c, false, 1.1)
	var stock := func(z0: float, z1: float, h: float, w: float) -> void:
		ModelsBase.part(gun, HeroKit.loft("stock|%.2f|%.2f|%.2f" % [z0, z1, h], [Vector3(0, 0.0, z0), Vector3(0, -0.02, lerpf(z0, z1, 0.5)), Vector3(0, -0.05, z1)], [Vector2(w * 0.5, h * 0.4), Vector2(w * 0.5, h * 0.5), Vector2(w * 0.55, h * 0.75)], 10, Vector3.UP, 0.85), m_dark)
	var grip := func(z: float, h: float) -> void:
		ModelsBase.part(gun, HeroKit.loft("grip|%.2f" % h, [Vector3(0, 0.0, 0), Vector3(0, -h * 0.5, 0.025), Vector3(0, -h, 0.05)], [Vector2(0.026, 0.04), Vector2(0.028, 0.044), Vector2(0.03, 0.046)], 10, Vector3.FORWARD, 0.85), m_dark, Vector3(0, -0.04, z))
	match weapon:
		"smg":
			ModelsBase.part(gun, ModelsBase.box(0.11, 0.13, 0.34), m_gun, Vector3(0, 0, -0.1))
			ModelsBase.part(gun, ModelsBase.box(0.12, 0.05, 0.22), m_acc, Vector3(0, 0.08, -0.12))
			ModelsBase.part(gun, ModelsBase.cyl(0.045, 0.045, 0.2, 14), m_dark, Vector3(0, 0.01, -0.34), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.055, 0.05, 0.05, 14), m_gun, Vector3(0, 0.01, -0.45), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.02, 0.025, 0.2), glow.call(Color("8ff0ff")), Vector3(0.058, 0.02, -0.12))
			grip.call(-0.02, 0.15)
			stock.call(0.07, 0.2, 0.08, 0.05)
		"rifle":
			# a lever-action: walnut stock and forend, a dark receiver with a brass side plate, a long
			# barrel bound in brass, a loop lever; the accent (team or rarity) on the forend cap
			var walnut := ModelsBase.toon(Color("7a4a2e")); ModelsBake.painted(walnut, 2, 0.24, 0.2, 0.2); walnut.set_shader_parameter("gloss", 0.35)
			var brass := ModelsBase.shiny(Color("d6a447"), 0.7)
			ModelsBase.part(gun, HeroKit.loft("lever_rcv", [Vector3(0, 0.0, 0.06), Vector3(0, 0.01, -0.08), Vector3(0, 0.0, -0.2)], [Vector2(0.05, 0.065), Vector2(0.052, 0.07), Vector2(0.045, 0.058)], 10, Vector3.UP, 0.9), m_gun, Vector3(0, 0, -0.04))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(gun, ModelsBase.box(0.006, 0.07, 0.18), brass, Vector3(0.05 * sx, 0.0, -0.12))
			ModelsBase.part(gun, HeroKit.loft("lever_fore", [Vector3(0, -0.02, -0.25), Vector3(0, -0.02, -0.4), Vector3(0, -0.015, -0.54)], [Vector2(0.045, 0.045), Vector2(0.046, 0.044), Vector2(0.04, 0.04)], 10, Vector3.UP, 0.9), walnut)
			ModelsBase.part(gun, ModelsBase.cyl(0.046, 0.046, 0.04, 12), m_acc, Vector3(0, -0.018, -0.565), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.022, 0.026, 0.62, 10), m_dark, Vector3(0, 0.03, -0.53), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.018, 0.018, 0.44, 8), m_dark, Vector3(0, -0.012, -0.44), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				ModelsBase.part(gun, ModelsBase.cyl(0.032, 0.032, 0.02, 10), brass, Vector3(0, 0.02, -0.38 - k * 0.16), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.012, 0.03, 0.02), brass, Vector3(0, 0.065, -0.8))
			var loop := TorusMesh.new(); loop.inner_radius = 0.03; loop.outer_radius = 0.042; loop.rings = 14; loop.ring_segments = 5
			ModelsBase.part(gun, loop, brass, Vector3(0, -0.085, 0.0), Vector3(1.0, 1.0, 1.3), Vector3(0, 0, PI / 2))
			ModelsBase.part(gun, ModelsBase.box(0.016, 0.022, 0.16), glow.call(Color("ffc46a")), Vector3(0.052, 0.04, -0.12))
			grip.call(0.0, 0.16)
			ModelsBase.part(gun, HeroKit.loft("lever_stock", [Vector3(0, 0.0, 0.08), Vector3(0, -0.03, 0.18), Vector3(0, -0.07, 0.3)], [Vector2(0.03, 0.05), Vector2(0.034, 0.06), Vector2(0.036, 0.085)], 10, Vector3.UP, 0.85), walnut)
			ModelsBase.part(gun, ModelsBase.box(0.07, 0.09, 0.02), m_dark, Vector3(0, -0.07, 0.31), Vector3.ONE, Vector3(0.25, 0, 0))
		"sniper":
			ModelsBase.part(gun, ModelsBase.box(0.09, 0.12, 0.5), m_gun, Vector3(0, 0, -0.16))
			ModelsBase.part(gun, ModelsBase.cyl(0.028, 0.03, 0.56, 12), m_dark, Vector3(0, 0.02, -0.66), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.08, 0.06, 0.1), m_acc, Vector3(0, 0.02, -0.96))
			ModelsBase.part(gun, ModelsBase.cyl(0.05, 0.045, 0.3, 14), m_dark, Vector3(0, 0.12, -0.18), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.058, 0.05, 0.06, 14), m_acc, Vector3(0, 0.12, -0.35), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.04, 0.04, 0.02, 14), glow.call(Color("9af0ff")), Vector3(0, 0.12, -0.385), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.03, 0.03, 0.4), glow.call(Color("9af0ff")), Vector3(0.048, 0.0, -0.2))
			grip.call(0.0, 0.16)
			stock.call(0.09, 0.32, 0.14, 0.06)
		"pulse":
			ModelsBase.part(gun, HeroKit.loft("pulse_body", [Vector3(0, 0, 0.1), Vector3(0, 0.01, -0.15), Vector3(0, 0.0, -0.42)], [Vector2(0.065, 0.075), Vector2(0.075, 0.085), Vector2(0.05, 0.06)], 16, Vector3.UP, 0.9), m_gun)
			for k in 3:
				var rr := TorusMesh.new(); rr.inner_radius = 0.06; rr.outer_radius = 0.085; rr.rings = 24; rr.ring_segments = 8
				ModelsBase.part(gun, rr, glow.call(Color("8ff0ff")), Vector3(0, 0.0, -0.2 - k * 0.09), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.06, 0.06, 0.12, 14), glow.call(Color("8ff0ff")), Vector3(0, 0.0, -0.56), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.08, 0.04, 0.2), m_acc, Vector3(0, 0.09, -0.08))
			grip.call(0.0, 0.16)
		"rocket":
			ModelsBase.part(gun, ModelsBase.cyl(0.1, 0.1, 0.62, 16), ModelsBase.toon(Color("5a6a4a")), Vector3(0, 0.04, -0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.14, 0.11, 0.12, 16), ModelsBase.toon(Color("ff7a5a")), Vector3(0, 0.04, -0.58), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.12, 0.13, 0.08, 16), m_dark, Vector3(0, 0.04, 0.12), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.04, 0.08, 0.1), m_acc, Vector3(0, 0.17, -0.2))
			grip.call(-0.05, 0.16)
		"burst_rifle":
			ModelsBase.part(gun, ModelsBase.box(0.09, 0.12, 0.38), m_gun, Vector3(0, 0, -0.1))
			ModelsBase.part(gun, ModelsBase.box(0.1, 0.06, 0.18), m_acc, Vector3(0, 0.08, -0.06))
			ModelsBase.part(gun, ModelsBase.cyl(0.026, 0.03, 0.2, 10), m_dark, Vector3(0, 0.02, -0.38), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.02, 0.02, 0.3), glow.call(Color("d6a8ff")), Vector3(0.05, 0.02, -0.14))
			ModelsBase.part(gun, ModelsBase.cyl(0.04, 0.036, 0.04, 10), glow.call(Color("d6a8ff")), Vector3(0, 0.02, -0.49), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.14)
			stock.call(0.09, 0.18, 0.1, 0.05)
		"shotgun": HeroGearPair.scattergun(gun, m_gun, m_dark, m_acc)      # Dredge's harbour scattergun
		"slugger":
			ModelsBase.part(gun, ModelsBase.cyl(0.1, 0.12, 0.78, 14), m_gun, Vector3(0, 0, -0.26), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.15, 0.15, 0.1, 14), m_acc, Vector3(0, 0, -0.64), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.18)
		"twin_blades":
			# two long curved fighting knives (a forward grip and a reversed one), dark steel with a
			# glowing cutting edge and a team-coloured wrap on the hilt
			var bl := ModelsBase.shiny(Color("5c6170"), 0.75)
			var edge: ShaderMaterial = glow.call(Color("aef4ff"))
			for k in 2:
				var x := 0.06 if k == 0 else -0.12
				var pts := [Vector3(0, 0, 0), Vector3(0, 0.03, -0.2), Vector3(0, 0.01, -0.4), Vector3(0, -0.07, -0.56)] if k == 0 else [Vector3(0, 0, 0), Vector3(0, 0.03, 0.15), Vector3(0, -0.01, 0.32), Vector3(0, -0.08, 0.45)]
				var at := Vector3(x, 0, -0.08) if k == 0 else Vector3(x, -0.06, -0.02)
				var yr := Vector3(0, 0.12 if k == 0 else -0.3, 0)
				ModelsBase.part(gun, HeroKit.loft("dagger2_%d" % k, pts, [Vector2(0.014, 0.06), Vector2(0.016, 0.07), Vector2(0.012, 0.05), Vector2(0.002, 0.004)], 8, Vector3.UP, 1.0), bl, at, Vector3.ONE, yr)
				ModelsBase.part(gun, HeroKit.loft("dagedge2_%d" % k, pts, [Vector2(0.006, 0.016), Vector2(0.006, 0.018), Vector2(0.005, 0.014), Vector2(0.001, 0.002)], 6, Vector3.UP, 1.0), edge, at + Vector3(0, 0.062, 0), Vector3.ONE, yr)
				ModelsBase.part(gun, HeroKit.loft("daggrip%d" % k, [Vector3(0, 0, 0.0), Vector3(0, 0, 0.06 if k == 0 else -0.06), Vector3(0, 0, 0.12 if k == 0 else -0.12)], [Vector2(0.024, 0.03), Vector2(0.026, 0.032), Vector2(0.03, 0.036)], 8, Vector3.UP, 0.9), m_dark, Vector3(x, 0 if k == 0 else -0.06, 0.0 if k == 0 else -0.04))
				ModelsBase.part(gun, HeroKit.loft("dagguard%d" % k, [Vector3(-0.07, 0.03, 0), Vector3(0, 0, 0), Vector3(0.07, -0.03, 0)], [Vector2(0.018, 0.018), Vector2(0.022, 0.022), Vector2(0.016, 0.016)], 8, Vector3.FORWARD, 0.9), m_acc, Vector3(x, 0 if k == 0 else -0.06, -0.06 if k == 0 else -0.04))
		"longsword":
			var steel := ModelsBase.toon(Color("e9e4d4"), true, 0.2)
			ModelsBase.part(gun, HeroKit.loft("lsword", [Vector3(0, 0.02, -0.1), Vector3(0, 0.02, -0.5), Vector3(0, 0.02, -0.9), Vector3(0, 0.02, -1.06)], [Vector2(0.018, 0.065), Vector2(0.016, 0.06), Vector2(0.012, 0.045), Vector2(0.002, 0.004)], 8, Vector3.UP, 1.0), steel)
			ModelsBase.part(gun, ModelsBase.box(0.026, 0.02, 0.72), glow.call(Color("9af0ff")), Vector3(0, 0.02, -0.46))
			ModelsBase.part(gun, HeroKit.loft("lguard", [Vector3(-0.15, 0.04, 0), Vector3(0, 0, 0), Vector3(0.15, 0.04, 0)], [Vector2(0.03, 0.03), Vector2(0.04, 0.04), Vector2(0.024, 0.024)], 10, Vector3.FORWARD, 0.9), m_acc, Vector3(0, 0, -0.06))
			ModelsBase.part(gun, ModelsBase.cyl(0.026, 0.03, 0.18, 10), m_dark, Vector3(0, 0, 0.05), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.sphere(0.04, 12), m_acc, Vector3(0, 0, 0.16))
		"greatsword":
			# a slab of a blade, wider than the juggernaut's helm, with a notched spine, a burning rune
			# channel, a heavy crossguard and a long wrapped grip
			var steel := ModelsBase.shiny(Color("8d929c"), 0.6)
			var dark := ModelsBase.shiny(Color("3d4049"), 0.5)
			var run_m: ShaderMaterial = glow.call(Color("ffb648"))
			var blade := [Vector3(0, 0.02, -0.14), Vector3(0, 0.02, -0.55), Vector3(0, 0.03, -1.0), Vector3(0, 0.03, -1.22), Vector3(0, 0.02, -1.36)]
			ModelsBase.part(gun, HeroKit.loft("gsword2", blade, [Vector2(0.034, 0.15), Vector2(0.032, 0.165), Vector2(0.028, 0.15), Vector2(0.02, 0.1), Vector2(0.003, 0.006)], 8, Vector3.UP, 1.0), steel)
			ModelsBase.part(gun, HeroKit.loft("gsword2b", blade.slice(0, 4), [Vector2(0.042, 0.05), Vector2(0.04, 0.06), Vector2(0.036, 0.05), Vector2(0.02, 0.02)], 8, Vector3.UP, 1.0), dark, Vector3(0, 0.0, 0.0))
			for k in 3:
				ModelsBase.part(gun, ModelsBase.box(0.05, 0.05, 0.05), dark, Vector3(0, 0.13 + 0.01 * k, -0.42 - k * 0.2), Vector3.ONE, Vector3(0, 0, PI * 0.25))
			ModelsBase.part(gun, ModelsBase.box(0.074, 0.03, 0.78), run_m, Vector3(0, 0.025, -0.62))
			ModelsBase.part(gun, HeroKit.loft("gguard2", [Vector3(-0.3, 0.12, 0.04), Vector3(-0.16, 0.02, 0), Vector3(0, -0.01, 0), Vector3(0.16, 0.02, 0), Vector3(0.3, 0.12, 0.04)], [Vector2(0.045, 0.045), Vector2(0.06, 0.06), Vector2(0.07, 0.07), Vector2(0.06, 0.06), Vector2(0.035, 0.035)], 10, Vector3.FORWARD, 0.9), dark, Vector3(0, 0, -0.12))
			ModelsBase.part(gun, ModelsBase.box(0.09, 0.09, 0.05), m_acc, Vector3(0, 0, -0.13), Vector3.ONE, Vector3(0, 0, PI * 0.25))
			ModelsBase.part(gun, ModelsBase.cyl(0.034, 0.038, 0.34, 10), m_dark, Vector3(0, 0, 0.08), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				ModelsBase.part(gun, ModelsBase.cyl(0.041, 0.041, 0.02, 10), m_acc, Vector3(0, 0, 0.0 + k * 0.08), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.sphere(0.06, 12), dark, Vector3(0, 0, 0.27))
		"flamethrower": HeroGearPair.flamer(gun, m_gun, m_dark, m_acc)
		"minigun":
			# a spinning bundle of six barrels on a chunky drum
			ModelsBase.part(gun, ModelsBase.box(0.22, 0.22, 0.36), m_gun, Vector3(0, 0, -0.06))
			ModelsBase.part(gun, ModelsBase.cyl(0.16, 0.16, 0.16, 18), m_acc, Vector3(0.16, -0.04, 0.0), Vector3.ONE, Vector3(0, 0, PI / 2))
			ModelsBase.part(gun, ModelsBase.cyl(0.14, 0.13, 0.12, 18), m_dark, Vector3(0, 0, -0.29), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.15, 0.15, 0.03, 18), glow.call(Color("ffb070")), Vector3(0, 0, -0.24), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var spin := Node3D.new(); spin.name = "Barrels"; spin.position = Vector3(0, 0, -0.56); gun.add_child(spin)
			for k in 6:
				var a := TAU * k / 6.0
				ModelsBase.part(spin, ModelsBase.cyl(0.026, 0.026, 0.56, 8), m_dark, Vector3(cos(a) * 0.078, sin(a) * 0.078, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(spin, ModelsBase.cyl(0.12, 0.12, 0.04, 16), m_gun, Vector3(0, 0, -0.24), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBake.merge_static(spin)
			ModelsBase.part(gun, ModelsBase.box(0.08, 0.18, 0.14), m_dark, Vector3(0, -0.17, 0.0))
		"longbow", "tower_shield":
			PinBjornWeapons.build(gun, weapon, m_dark, m_acc)      # Hem's recurve, Breaker's war hammer and aegis
		"coilcaster":
			# Sparkle's forearm coil: a copper tube wound in rings with a glowing mouth and a bracer grip
			var cop := ModelsBase.shiny(Color("c8793c"), 0.7)
			ModelsBase.part(gun, ModelsBase.cyl(0.04, 0.05, 0.5, 12), m_dark, Vector3(0, 0.0, -0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 6:
				ModelsBase.part(gun, ModelsBase.cyl(0.062, 0.062, 0.022, 12), cop, Vector3(0, 0.0, -0.06 - k * 0.075), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.075, 0.05, 0.07, 12), cop, Vector3(0, 0.0, -0.5), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.sphere(0.045, 10), glow.call(Color("9ff5e0")), Vector3(0, 0.0, -0.55))
			ModelsBase.part(gun, ModelsBase.box(0.09, 0.05, 0.16), m_acc, Vector3(0, 0.05, 0.06))
			grip.call(-0.02, 0.15)
		"quill_rifle":
			# Vex's drum rifle: a squat receiver, a drum of burr charges under it, a long needle barrel
			var bronze := ModelsBase.shiny(Color("b9732f"), 0.6)
			ModelsBase.part(gun, ModelsBase.box(0.1, 0.12, 0.42), m_gun, Vector3(0, 0, -0.12))
			ModelsBase.part(gun, ModelsBase.cyl(0.1, 0.1, 0.1, 14), bronze, Vector3(0, -0.12, -0.14), Vector3.ONE, Vector3(0, 0, PI / 2))
			ModelsBase.part(gun, ModelsBase.cyl(0.02, 0.024, 0.55, 8), m_dark, Vector3(0, 0.02, -0.56), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.box(0.05, 0.05, 0.2), m_acc, Vector3(0, 0.08, -0.14))
			ModelsBase.part(gun, ModelsBase.box(0.016, 0.03, 0.3), glow.call(Color("ffb36a")), Vector3(0.056, 0.0, -0.16))
			grip.call(-0.02, 0.15)
			stock.call(0.07, 0.2, 0.08, 0.05)
		"lantern_crook", "hoar_fan":
			HeroGearCare.weapon(gun, weapon, m_gun, m_dark, m_acc)
		"spellstaff":
			# the Mage's staff: a long rune-carved rod with a glowing focus caught in a ring
			var wood2 := ModelsBase.toon(Color("5a4636"))
			ModelsBase.part(gun, ModelsBase.cyl(0.022, 0.028, 1.15, 10), wood2, Vector3(0, 0, -0.32), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				ModelsBase.part(gun, ModelsBase.cyl(0.032, 0.032, 0.03, 10), m_acc, Vector3(0, 0, -0.2 - k * 0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var rr := TorusMesh.new(); rr.inner_radius = 0.07; rr.outer_radius = 0.095; rr.rings = 20; rr.ring_segments = 8
			ModelsBase.part(gun, rr, m_acc, Vector3(0, 0, -0.98), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.sphere(0.06, 12), glow.call(Color("9ad8ff")), Vector3(0, 0, -0.98))
		"thumper":
			ModelsBase.part(gun, ModelsBase.cyl(0.12, 0.12, 0.62, 14), m_gun, Vector3(0, 0, -0.2), Vector3.ONE, Vector3(PI / 2, 0, 0))
			ModelsBase.part(gun, ModelsBase.cyl(0.15, 0.14, 0.1, 14), m_acc, Vector3(0, 0, -0.52), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.18)

## A piece of gear lying on the ground: a glowing gem-like token with a light beam.
static func gear_drop(col: Color, rar: int) -> Node3D:
	var root := Node3D.new()
	var rc: Color = Data.RARITY[clampi(rar, 0, Data.RARITY.size() - 1)]["color"]
	var spin := Node3D.new(); spin.name = "Spin"; spin.position = Vector3(0, 0.7, 0); root.add_child(spin)
	var core := PrismMesh.new(); core.size = Vector3(0.38, 0.38, 0.38)
	ModelsBase.part(spin, core, ModelsBase.toon(col, true, 0.6), Vector3(0, 0.1, 0))
	ModelsBase.part(spin, core, ModelsBase.toon(col, true, 0.6), Vector3(0, -0.12, 0), Vector3.ONE, Vector3(PI, 0, 0))
	var t := TorusMesh.new(); t.inner_radius = 0.28; t.outer_radius = 0.33
	ModelsBase.part(spin, t, ModelsBase.toon(rc, false, 0.8), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var beam := ModelsBase.part(root, ModelsBase.cyl(0.12, 0.22, 4.0, 10), ModelsBase.glow_mat(Color(col, 0.3)), Vector3(0, 2.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.mesh = ModelsBase.flat_quad(1.2)
	ring.material_override = ModelsBase.ring_mat(rc, 0.12); ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # (a ground ring: no shadow, item 94)
	root.add_child(ring)
	return root

static func gear_pad(col: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(0.5, 0.58, 0.14, 18), ModelsBase.toon(Color("3a3f52")), Vector3(0, 0.07, 0))
	var top := ModelsBase.part(root, ModelsBase.cyl(0.38, 0.38, 0.06, 18), ModelsBase.toon(col, false, 1.0), Vector3(0, 0.16, 0), Vector3.ONE, Vector3.ZERO, "Top")
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func gear_platform(col: Color) -> Node3D:
	var root := Node3D.new()
	ModelsBase.part(root, ModelsBase.cyl(1.6, 1.3, 0.24, 24), ModelsBase.toon(Color("e8dcc0")), Vector3(0, -0.12, 0))
	ModelsBase.part(root, ModelsBase.cyl(1.62, 1.62, 0.06, 24), ModelsBase.toon(col, false, 0.7), Vector3(0, 0.0, 0))
	var g := ModelsBase.part(root, ModelsBase.cyl(1.0, 0.2, 0.7, 18), ModelsBase.glow_mat(Color(col, 0.35)), Vector3(0, -0.6, 0))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func gear_smoke() -> Node3D:
	var root := Node3D.new()
	var m := ModelsBase.toon(Color(0.78, 0.78, 0.84), false)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in 14:
		var a := rng.randf() * TAU; var r := rng.randf_range(0.0, 3.0)
		var s := rng.randf_range(0.9, 1.6)
		var p := ModelsBase.part(root, ModelsBase.sphere(0.8), m, Vector3(cos(a) * r, rng.randf_range(0.4, 1.6), sin(a) * r), Vector3.ONE * s)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## Things that break when shot or dashed through.
static func breakable(kind_s: String) -> Node3D:
	if Flora.v2():
		return PropSculpt.breakable(kind_s)
	if kind_s == "crate":
		var pc := Assets.prop("dungeon/box_small", 0.78, false, {"bright": 1.1})
		if pc: return pc
	elif kind_s in ["barrel", "keg"]:
		# the red powder keg: the barrel's wood painted red, its fuse still glowing on top
		var pb := Assets.prop("dungeon/barrel_small", 0.85, true, {"band": Assets.BAND_WOOD, "paint": Color("d8483a"), "bright": 1.1})
		if pb:
			var top := (pb.get_child(0) as MeshInstance3D).get_aabb().size.y * (pb.get_child(0) as MeshInstance3D).scale.y
			ModelsBase.part(pb, ModelsBase.sphere(0.09, 8), ModelsBase.toon(Color("ffd25a"), false, 0.9), Vector3(0, top + 0.06, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
			return pb
	var root := Node3D.new()
	match kind_s:
		"crate":
			var wood := ModelsBase.toon(Color("a07448")); var dark := ModelsBase.toon(Color("6a4a30"))
			ModelsBase.part(root, ModelsBase.box(0.7, 0.6, 0.7), wood, Vector3(0, 0.3, 0))
			for y in [0.06, 0.54]:
				ModelsBase.part(root, ModelsBase.box(0.74, 0.08, 0.74), dark, Vector3(0, y, 0))
			ModelsBase.part(root, ModelsBase.box(0.08, 0.6, 0.74), dark, Vector3(0, 0.3, 0), Vector3.ONE, Vector3(0, 0, 0.75))
		"pot":
			var clay := ModelsBase.toon(Color("c9825a"))
			ModelsBase.part(root, ModelsBase.sphere(0.3, 14), clay, Vector3(0, 0.3, 0), Vector3(1, 1.05, 1))
			ModelsBase.part(root, ModelsBase.cyl(0.14, 0.18, 0.14, 12), clay, Vector3(0, 0.62, 0))
			ModelsBase.part(root, ModelsBase.cyl(0.31, 0.31, 0.05, 14), ModelsBase.toon(Color("e8c07a")), Vector3(0, 0.36, 0))
		"barrel", "keg":
			var red := ModelsBase.toon(Color("c8483a"), true, 0.15); var band := ModelsBase.toon(Color("3a3440"))
			ModelsBase.part(root, ModelsBase.cyl(0.3, 0.3, 0.75, 14), red, Vector3(0, 0.375, 0))
			for y in [0.12, 0.62]:
				ModelsBase.part(root, ModelsBase.cyl(0.315, 0.315, 0.07, 14), band, Vector3(0, y, 0))
			ModelsBase.part(root, ModelsBase.sphere(0.09, 8), ModelsBase.toon(Color("ffd25a"), false, 0.9), Vector3(0, 0.8, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
	return root
