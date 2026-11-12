class_name HeroGear
## Each archetype's gear on a hunter (docs/ARCHETYPES.md, Fantasy and Silhouette): the head piece,
## the outer layer of the torso, what hangs from the waist, shoulders, back and arms. The archetype
## owns the silhouette, so it reads the same whatever the race, gender, build or outfit; the outfit
## picks the colourway (coat, trim) and the team colour marks the strongest shapes.
##
## c (built by Models.hunter): torso, skirt (pivot), gear (head pieces, in torso space round the
## head at 0, 0.86, 0), pl / pr (pauldron pivots at the shoulders), arms {"L": [pivot, elbow,
## hand]}, knees {"L": knee}, m (materials by name), bw, cw (chest width), fem, rid, hk (head key),
## bare (no headgear), hand_k.

const HC := Vector3(0, 0.86, 0)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

## Parts on the torso that reach above the shoulders (a bow, a banner) must stay on the torso
## instead of moving onto the head.
static func _stay(mi: MeshInstance3D) -> MeshInstance3D:
	mi.set_meta("stay", true)
	return mi

static func _tp(c: Dictionary, key: String, u0: float, u1: float, v0: float, v1: float, off: float, mat: Material, thick := 0.014, bevel := 0.0) -> MeshInstance3D:
	var bw: float = c["bw"]; var cw: float = c["cw"]
	return _p(c["torso"], HeroKit.torso_patch(key, c["fem"], u0, u1, v0, v1, off, thick, bevel), mat, Vector3(0, 0.33, 0), Vector3(cw, 1.0, bw * 0.9))

## What the archetype wears on its head covers the hair this much: "" none, "hat" (hair shows
## below the brim), "hood", "helm" (only what spills out below shows).
static func cover(arch: String, bare: bool) -> String:
	if bare:
		return ""
	if arch in ["dolm", "ostra"]:
		return GearPair.cover(arch, bare)
	return {"thief": "hood", "archer": "hood", "mage": "", "gunslinger": "hat", "juggernaut": "helm", "bulwark": "hood", "dredge": "helm", "ashwick": "hat", "tender": "hat", "rimewright": "hat"}.get(arch, "")

static func dress(arch: String, c: Dictionary) -> void:
	_belt(c, arch)
	match arch:
		"thief": _thief(c)
		"archer": WardenArcher.dress(c)
		"mage": _mage(c)
		"gunslinger": _gunslinger(c)
		"juggernaut": _juggernaut(c)
		"bulwark": WardenBulwark.dress(c)
		"dredge", "ashwick": HeroGearPair.dress(arch, c)
		"tender", "rimewright": HeroGearCare.dress(arch, c)
		"dolm": GearPair.dolm(c)
		"ostra": GearPair.ostra(c)
	if not bool(c["bare"]):
		_ear_cuffs(c, arch)

# ------------------------------------------------------------------------------------------ shared
## Under plate the arms wear a dark padded undersuit (the coat colour would read as bare balloon
## sleeves between the plates).
static func _undersuit(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	for sd in ["L", "R"]:
		for nd in [(c["arms"][sd] as Array)[0], (c["arms"][sd] as Array)[1]]:
			for ch in (nd as Node3D).get_children():
				if ch is MeshInstance3D and (ch as MeshInstance3D).material_override == m["body"]:
					(ch as MeshInstance3D).material_override = m["pants"]

## The team colour a shade deeper, for the big cloth or lacquered shape each archetype wears it on
## (the thief's hood, the mage's hat, the gunslinger's serape), so it reads as material rather than
## a flat sticker. One per hunter, cached in m.
static func _deep_acc(m: Dictionary) -> ShaderMaterial:
	if m.has("acc_deep"):
		return m["acc_deep"]
	var d := (m["acc"] as ShaderMaterial).duplicate() as ShaderMaterial
	var tc: Color = d.get_shader_parameter("albedo")
	d.set_shader_parameter("albedo", Color.from_hsv(tc.h, minf(1.0, tc.s * 1.05), tc.v * 0.86))
	m["acc_deep"] = d
	return d

## A belt round the waist with a buckle; heavies wear a broad one.
static func _belt(c: Dictionary, arch: String) -> void:
	var m: Dictionary = c["m"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var heavy := arch in ["juggernaut", "bulwark", "dredge", "ashwick"]
	var h := 0.1 if heavy else 0.065
	var rx := 0.222 * maxf(cw, bw) + 0.01; var rz := 0.214 * bw + 0.008
	_p(c["torso"], HeroKit.band("belt|%.3f|%.3f|%.3f" % [rx, rz, h], rx, rz, h, 0.016), m["leather"], Vector3(0, 0.1, 0))
	var bk := Vector3(0.13, 0.11, 0.03) if heavy else Vector3(0.09, 0.075, 0.025)
	_p(c["torso"], Models.box(bk.x, bk.y, bk.z), m["gold"], Vector3(0, 0.1, -rz - 0.014))
	_p(c["torso"], Models.box(bk.x * 0.5, bk.y * 0.45, bk.z + 0.006), m["leather"], Vector3(0, 0.1, -rz - 0.016))

## Where a vulpin's ears come through a hood, hat or helm: a turned-back cuff of the headgear's
## material round each ear, so the ears read as growing through a cut-out, not clipping.
static func _ear_cuffs(c: Dictionary, arch: String) -> void:
	if String(c["rid"]) != "vulpin" or arch == "archer":
		return
	var m: Dictionary = c["m"]
	var mat: Material = {"thief": _deep_acc(m), "mage": _deep_acc(m), "gunslinger": m["leather"], "juggernaut": m["steel"], "bulwark": m["steel"]}.get(arch, m["acc"])
	for sx in [-1.0, 1.0]:
		var rot := Vector3(0, 0.785, -0.4 * sx)
		var b := Basis.from_euler(rot)
		var base := Vector3(0.17 * sx, 1.16, 0.01) + b * Vector3(0, -0.17, 0)
		_p(c["gear"], HeroKit.cuff(0.11, 0.135, 0.06), mat, base, Vector3(1.0, 1.0, 0.62), rot)

## A sculpted hood over the head with a face opening (oval, open below the chin) that drapes onto
## the shoulders. off: how far it stands off the head; peak: a point up and back; drape: how far
## its lower edge falls and flares.
static func hood_mesh(key: String, hk: String, off := 0.04, open_side := 1.0, open_top := 0.75, open_bot := 1.5, peak := 0.06, drape := 0.15, thick := 0.018) -> ArrayMesh:
	var s: Dictionary = HeroKit.HEADS.get(hk, HeroKit.HEADS["human_m"])
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var st := sin(th)
		var op := lerpf(open_side, open_top, maxf(st, 0.0)) if st >= 0.0 else lerpf(open_side, open_bot, -st)
		var ph := lerpf(op, PI * 0.985, v)
		var d := Vector3(sin(ph) * cos(th), sin(ph) * st, -cos(ph))
		var p := HeroKit.head_pt(d, s) + d * (off + 0.03 * smoothstep(0.2, 0.9, d.z))
		p += d * peak * exp(-d.distance_squared_to(Vector3(0, 0.62, 0.78)) / 0.2)
		var lowk := smoothstep(-0.2, -0.95, d.y)
		p.y -= drape * lowk
		p.x *= 1.0 + 0.55 * lowk * drape / 0.15
		p.z *= 1.0 + 0.3 * lowk * drape / 0.15
		return p
	var ao := func(u: float, v: float) -> float: return lerpf(0.7, 1.0, smoothstep(0.0, 0.25, v))
	return HeroKit.shell("hood|%s|%s" % [key, hk], fn, 44, 18, thick, ao, true, 1.0, 0.35)

## A helm: the hood's shape pulled tight, with a smaller face opening and no drape.
static func helm_mesh(key: String, hk: String, open_side := 0.85, open_top := 0.6, open_bot := 1.25) -> ArrayMesh:
	return hood_mesh("helm" + key, hk, 0.035, open_side, open_top, open_bot, 0.0, 0.03, 0.022)

## A brim: a ring from r_in to r_out round the crown, curling up at the sides (`curl`), dipping at
## the front (`dip`), and wavy like soft felt (`wave`).
static func brim(key: String, r_in: float, r_out: float, curl := 0.0, dip := 0.0, wave := 0.0, zk := 1.08) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var r := lerpf(r_in, r_out, v)
		var y := curl * v * v * pow(cos(th), 2.0) - dip * v * maxf(-sin(th), 0.0) + wave * v * v * sin(th * 3.0 + 0.5)
		return Vector3(cos(th) * r, y, sin(th) * r * zk)
	var ao := func(u: float, v: float) -> float: return lerpf(0.75, 1.0, smoothstep(0.0, 0.4, v))
	return HeroKit.shell("brim|" + key, fn, 56, 6, 0.016, ao, true, 1.0, 0.5)

# ------------------------------------------------------------------------------------------ thief
## The cutpurse, lean and hooded like the assassins of hero games: a deep team-coloured hood with
## a long pointed tail and a rim in the outfit colour round the face, a cloth mask up to the
## eyes, a scarf whose tails stream behind, a short mantle off the left shoulder over two long
## split cloak tails (the left longer), a bandolier of throwing knives across the chest, and wraps
## on the forearms. From the match camera: a team-coloured teardrop with dark streamers behind.
static func _thief(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	# the hood is the thief's primary shape, so it carries the team colour (a shade deeper than the
	# accents, so it reads as cloth) and stays readable from the match camera on any ground
	var hood_m: Material = m["cloak"]
	var team_hood := _deep_acc(m)
	if not bool(c["bare"]):
		_p(c["gear"], hood_mesh("thief", c["hk"], 0.05, 1.0, 0.7, 1.6, 0.09, 0.17), team_hood, HC)
		# the long pointed tail sweeping back and down from the crown
		var tail := [Vector3(0, 1.05, 0.12), Vector3(0, 1.09, 0.32), Vector3(0.02, 1.03, 0.52), Vector3(0.08, 0.88, 0.66), Vector3(0.14, 0.66, 0.72)]
		_p(c["gear"], HeroKit.lock_mesh("thief_tail2", tail, 0.19, 0.4, Vector3.UP, 0.75, 0.1), team_hood)
		# the rim round the face opening, in the team colour
		var s0: Dictionary = HeroKit.HEADS.get(String(c["hk"]), HeroKit.HEADS["human_m"])
		var rim := []
		var rw := []
		for k in 13:
			var th := lerpf(-PI * 0.5, PI * 0.5, k / 12.0)         # from one cheek, over the brow, to the other
			var ph := 0.98 + 0.12 * cos(th)
			var d := Vector3(sin(ph) * sin(th), sin(ph) * cos(th), -cos(ph))
			rim.append(HeroKit.head_pt(d, s0) + d * 0.07 + HC)
			rw.append(Vector2(0.018, lerpf(0.008, 0.02, cos(th))))
		_p(c["gear"], HeroKit.loft("thief_rim|" + String(c["hk"]), rim, rw, 8, Vector3.FORWARD, 1.0), m["trim"])
		# the mask: cloth over the nose, mouth and jaw, tucked under the hood
		_p(c["gear"], mask_mesh("thief", c["hk"], _snout(c)), m["dark"], HC)
		_p(c["gear"], HeroKit.loft("thief_maskedge|%s|%.2f" % [c["hk"], _snout(c)], _mask_edge(c), [Vector2(0.01, 0.008), Vector2(0.012, 0.01), Vector2(0.01, 0.008)], 6, Vector3.UP, 1.0), m["acc"], HC)
	else:
		_p(t, HeroKit.mantle("thief_cowl", 0.2, 0.19, 0.06, 7.0), team_hood, Vector3(0, 0.6, 0.02))
	# jerkin: a leather front with a high collar, and the bandolier of knives across it
	_tp(c, "thief_jerkin", 0.58, 0.92, 0.18, 0.82, 0.012, m["leather"], 0.014, 0.004)
	var bpts := [Vector3(0.2, 0.6, -0.14), Vector3(0.05, 0.42, -0.255), Vector3(-0.12, 0.22, -0.245), Vector3(-0.22, 0.08, -0.17)]
	_p(t, HeroKit.loft("thief_bando", bpts, [Vector2(0.03, 0.01), Vector2(0.032, 0.011), Vector2(0.032, 0.011), Vector2(0.03, 0.01)], 6, Vector3.FORWARD, 0.9), m["dark"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	var bc := HeroKit.curve3(bpts, 4)
	for k in [3, 5, 7, 9]:
		var p: Vector3 = bc[k]
		var d: Vector3 = ((bc[k + 1] as Vector3) - (bc[k - 1] as Vector3)).normalized()
		var rr := atan2(-d.x, -d.y)
		var at := Vector3(p.x * cw, p.y, p.z * bw - 0.016)
		_p(t, Models.box(0.022, 0.05, 0.012), m["leather"], at, Vector3.ONE, Vector3(0, 0, rr + PI * 0.5))
		_p(t, HeroKit.loft("thief_knife", [Vector3(0, 0.0, 0), Vector3(0, 0.045, 0.0), Vector3(0, 0.085, 0.004)], [Vector2(0.016, 0.004), Vector2(0.014, 0.004), Vector2(0.001, 0.001)], 6, Vector3.FORWARD, 1.0), m["steel"], at + Basis(Vector3.BACK, rr + PI * 0.5) * Vector3(0.02, 0.0, 0), Vector3.ONE, Vector3(0, 0, rr + PI * 0.5 - PI * 0.5))
	# the mantle off the left shoulder, and two long split cloak tails behind
	var cape := Models._pivot(t, "Cape", Vector3(0, 0.56, 0.24 * bw))
	_p(cape, HeroKit.drape("thief_cape", 0.25, 0.36, 0.3, 0.12, 0.56, 5.0, 0.08, 0.05, -0.35, 0.016), hood_m, Vector3(0, 0.0, -0.24 * bw), Vector3(cw, 1.0, bw), Vector3(0.05, 0, 0))
	_p(cape, HeroKit.drape_hem("thief_cape", 0.25, 0.36, 0.3, 0.12, 0.56, 5.0, 0.08, 0.05, -0.35, 0.05), m["acc"], Vector3(0, 0.0, -0.24 * bw), Vector3(cw, 1.0, bw), Vector3(0.05, 0, 0))
	for sx in [-1.0, 1.0]:
		var ln := 0.74 if sx < 0.0 else 0.58
		var pts := [Vector3(0.09 * sx, 0.02, 0.0), Vector3(0.12 * sx, -ln * 0.3, 0.07), Vector3(0.13 * sx, -ln * 0.65, 0.12), Vector3(0.12 * sx, -ln, 0.15)]
		_p(cape, HeroKit.loft("thief_ctail%d" % int(sx), pts, [Vector2(0.11, 0.012), Vector2(0.1, 0.012), Vector2(0.075, 0.01), Vector2(0.004, 0.004)], 8, Vector3.BACK, 0.75), hood_m)
		_p(cape, HeroKit.loft("thief_ctailh%d" % int(sx), pts.slice(2), [Vector2(0.078, 0.016), Vector2(0.006, 0.006)], 8, Vector3.BACK, 1.0), m["acc"], Vector3(0, 0, 0.004))
	_p(cape, HeroKit.loft("thief_capetie", [Vector3(-0.28, 0.0, -0.06), Vector3(0, 0.01, 0.03), Vector3(0.26, 0.0, -0.06)], [Vector2(0.03, 0.015), Vector2(0.032, 0.016), Vector2(0.03, 0.015)], 8, Vector3.BACK), m["leather"], Vector3.ZERO, Vector3(cw, 1.0, 1.0))
	# the scarf: its tails stream behind in the team colour
	var scarf := Models._pivot(t, "Scarf", Vector3(0, 0.6, 0.18 * bw))
	for sx in [-1.0, 1.0]:
		_p(scarf, HeroKit.lock_mesh("thief_scarf2%d" % int(sx), [Vector3(0.05 * sx, 0.0, 0.0), Vector3(0.09 * sx, -0.08, 0.16), Vector3(0.13 * sx, -0.2, 0.3 + 0.04 * sx), Vector3(0.16 * sx, -0.32, 0.4)], 0.09, 0.16, Vector3.BACK, 0.8, 0.5), m["acc"])
	# a reversed knife across the small of the back, and pouches on the hips
	_p(t, HeroKit.loft("thief_sheath", [Vector3(-0.2, 0.16, 0.25), Vector3(0, 0.13, 0.29), Vector3(0.18, 0.1, 0.26)], [Vector2(0.03, 0.02), Vector2(0.034, 0.02), Vector2(0.012, 0.01)], 8, Vector3.BACK), m["dark"], Vector3.ZERO, Vector3(1.0, 1.0, bw))
	_p(t, Models.cyl(0.022, 0.026, 0.12, 10), m["leather"], Vector3(-0.27, 0.17, 0.25 * bw), Vector3.ONE, Vector3(0, 0, 1.4))
	_p(t, Models.sphere(0.028, 10), m["gold"], Vector3(-0.34, 0.19, 0.25 * bw))
	for sx in [-1.0, 1.0]:
		_p(t, Models.box(0.09, 0.1, 0.07), m["leather"], Vector3(0.21 * sx * bw, 0.04, -0.06), Vector3.ONE, Vector3(0, 0.45 * sx, 0))
	# asymmetry: a layered leather cap on the left shoulder (the mantle side), a bare right arm
	_p(c["pl"], HeroKit.dome_plate("thief_pad", 0.115, 0.5, 0.8, 0.2, 0.016), m["leather"], Vector3(-0.025, 0.035, 0), Vector3(1.0, 1.0, 1.1), Vector3(0, 0, 0.5))
	_p(c["pl"], HeroKit.dome_plate("thief_pad2", 0.1, 0.45, 0.75, 0.2, 0.014), m["dark"], Vector3(-0.055, -0.03, 0), Vector3(1.0, 1.0, 1.05), Vector3(0, 0, 0.85))
	_wraps(c, m["dark"], m["leather"])

## The thief's mask: cloth over the lower face from cheek to cheek, from just under the eyes to under
## the chin, standing off the head a little and pulled out over a muzzle or a beak.
static func mask_mesh(key: String, hk: String, snout := 0.0) -> ArrayMesh:
	var s: Dictionary = HeroKit.HEADS.get(hk, HeroKit.HEADS["human_m"])
	var fn := func(u: float, v: float) -> Vector3:
		var th := lerpf(-1.35, 1.35, u)
		var ph := lerpf(-0.16 - 0.05 * cos(th * 2.0), -0.86, v)
		var d := Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph))
		var p := HeroKit.head_pt(d, s) + d * lerpf(0.016, 0.006, v)
		p.z -= snout * cos(th) * smoothstep(-0.9, -0.1, ph) * 0.95
		p.z -= 0.012 * exp(-th * th / 0.15)          # pinched over the nose
		return p
	var ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.8, v * v)
	return HeroKit.shell("mask|%s|%s|%.2f" % [key, hk, snout], fn, 24, 8, 0.012, ao, false, 1.0)

## The mask's upper edge, as points (for a team-coloured hem along it).
static func _mask_edge(c: Dictionary) -> Array:
	var s: Dictionary = HeroKit.HEADS.get(String(c["hk"]), HeroKit.HEADS["human_m"])
	var out := []
	for k in 9:
		var th := lerpf(-1.3, 1.3, k / 8.0)
		var ph := -0.16 - 0.05 * cos(th * 2.0)
		var d := Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph))
		var p := HeroKit.head_pt(d, s) + d * 0.022
		p.z -= _snout(c) * cos(th) * smoothstep(-0.9, -0.1, ph) * 0.95
		out.append(p)
	return out

## Bracers on both forearms: leather with cross-wraps.
static func _wraps(c: Dictionary, m_wrap: Material, m_cuff: Material) -> void:
	for sd in ["L", "R"]:
		var el: Node3D = (c["arms"][sd] as Array)[1]
		_p(el, HeroKit.cuff(0.056, 0.066, 0.1), m_cuff, Vector3(0, -0.15, 0))
		for k in 2:
			_p(el, HeroKit.band("wrap", 0.062, 0.062, 0.014, 0.006), m_wrap, Vector3(0, -0.125 - k * 0.045, 0), Vector3.ONE, Vector3(0.25 * (1 - 2 * k), 0, 0))

# ------------------------------------------------------------------------------------------ mage
## Sparkle, the storm-kite runner: no hat and no robe. Flight goggles pushed up on a swept-back head,
## a cropped jacket over a short split kite-tail, copper coils round both forearms, a copper rod mast
## on the back flying a pennant in the team colour, and a belt of glass insulators.
static func _mage(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var team := _deep_acc(m)
	var copper := Models.shiny(Color("c8793c"), 0.7)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		var hb := HC + Vector3(0, 0.15, -0.02)
		_p(g, HeroKit.band("vir_goggle_band", 0.215, 0.225, 0.05, 0.012), m["leather"], hb + Vector3(0, 0.0, 0.0), Vector3.ONE, Vector3(-0.2, 0, 0))
		for sx in [-1.0, 1.0]:
			_p(g, Models.cyl(0.062, 0.062, 0.04, 14), copper, hb + Vector3(0.095 * sx, 0.03, -0.2), Vector3.ONE, Vector3(PI / 2 - 0.2, 0, 0))
			_p(g, Models.cyl(0.046, 0.046, 0.045, 14), m["glow"], hb + Vector3(0.095 * sx, 0.03, -0.205), Vector3.ONE, Vector3(PI / 2 - 0.2, 0, 0))
		_p(g, Models.box(0.05, 0.03, 0.03), copper, hb + Vector3(0, 0.03, -0.215))
	# the cropped jacket's tails: a short split skirt in the outfit colour, hem trimmed in copper
	var sk: Node3D = c["skirt"]
	var r0 := 0.232 * maxf(bw, cw * 0.95); var r1 := 0.36 * bw
	for side in [[0.8, 1.235], [1.265, 1.7]]:
		var a0: float = side[0]; var a1: float = side[1]
		var key := "vir_tail%.3f|%.3f" % [a0, r0]
		_p(sk, HeroKit.drape(key, r0, r1, 0.3, a0, a1, 8.0, 0.06, 0.02, 0.1), m["body"], Vector3(0, -0.02, 0.01))
		_p(sk, HeroKit.drape_hem(key, r0, r1, 0.3, a0, a1, 8.0, 0.06, 0.02, 0.1, 0.06), copper, Vector3(0, -0.02, 0.01))
	# a zip placket and high collar
	_tp(c, "vir_zip", 0.71, 0.73, 0.05, 0.9, 0.01, copper, 0.01)
	_p(t, HeroKit.drape("vir_collar", 0.17, 0.25, 0.2, 0.55, 0.95, 3.0, 0.0, 0.0, 0.0, 0.012), m["body"], Vector3(0, 0.56, 0.02), Vector3.ONE, Vector3(PI, 0, 0))
	# the mast: a copper rod up the spine with a crossbar, flying a kite pennant in the team colour
	var mast := Node3D.new(); mast.name = "Mast"; mast.position = Vector3(0.0, 0.5, 0.2 * bw); t.add_child(mast)
	_p(mast, Models.cyl(0.014, 0.018, 1.0, 8), copper, Vector3(0, 0.45, 0), Vector3.ONE, Vector3(0.12, 0, 0))
	_p(mast, Models.cyl(0.01, 0.01, 0.5, 6), copper, Vector3(0, 0.82, 0.05), Vector3.ONE, Vector3(0.12, 0, PI / 2))
	_p(mast, Models.sphere(0.03, 8), m["glow"], Vector3(0, 0.99, 0.12))
	_p(mast, HeroKit.lock_mesh("vir_pennant", [Vector3(0.0, 0.8, 0.08), Vector3(0.0, 0.62, 0.22), Vector3(0.0, 0.5, 0.42), Vector3(0.0, 0.42, 0.62)], 0.16, 0.02, Vector3.RIGHT, 0.8, 0.5), team)
	# a belt of glass insulators
	for k in 5:
		var a := PI * (0.15 + k * 0.17)
		_p(t, Models.cyl(0.026, 0.02, 0.06, 8), m["glow_soft"], Vector3(cos(a) * 0.23 * cw, 0.02, -sin(a) * 0.2 * bw), Vector3.ONE, Vector3(0.0, 0, 0))
	# the shoulder: one big insulator stack on the left
	_p(t, Models.sphere(0.075, 10), copper, Vector3(-0.3 * cw, 0.62, 0.0))
	_p(t, Models.sphere(0.05, 10), m["glow"], Vector3(-0.3 * cw, 0.7, 0.0))
	# the coils round both forearms, wound in copper rings round a glowing core
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, Models.cyl(0.07, 0.07, 0.26, 12), m["leather"], Vector3(0, -0.1, 0))
		for k in 5:
			var wr := TorusMesh.new(); wr.inner_radius = 0.07; wr.outer_radius = 0.088; wr.rings = 24; wr.ring_segments = 6
			_p(e2, wr, copper, Vector3(0, -0.02 - k * 0.05, 0))
		_p(e2, Models.sphere(0.04, 8), m["glow"], Vector3(0, -0.27, 0))

# ------------------------------------------------------------------------------------------ gunslinger
## Vex, the burr-and-needle marksman: a snug visored cap, a cropped open jacket over a vest, a
## long streaming scarf in the team colour, a bandolier of spiked burr charges and one big bronze
## pauldron. No hat brim, no serape, no duster.
static func _gunslinger(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var team := _deep_acc(m)
	var bronze := Models.shiny(Color("b9732f"), 0.6)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		var hb := HC + Vector3(0, 0.13, 0.0)
		var cap := _p(g, Models.sphere(0.225, 18), m["hat"], hb + Vector3(0, 0.03, 0.01), Vector3(1.0, 0.72, 1.08))
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_p(g, HeroKit.band("mar_capband", 0.214, 0.226, 0.05, 0.012), team, hb + Vector3(0, -0.03, 0.0))
		_p(g, Models.box(0.3, 0.018, 0.17), m["hat"], hb + Vector3(0, -0.01, -0.24), Vector3.ONE, Vector3(0.18, 0, 0))
		_p(g, Models.box(0.3, 0.012, 0.03), team, hb + Vector3(0, -0.012, -0.325), Vector3.ONE, Vector3(0.18, 0, 0))
		_p(g, Models.cyl(0.012, 0.012, 0.16, 6), bronze, hb + Vector3(0.18, 0.12, 0.08), Vector3.ONE, Vector3(0.5, 0, 0.3))
	# the cropped jacket tails
	var sk: Node3D = c["skirt"]
	var r0 := 0.234 * maxf(bw, cw * 0.95); var r1 := 0.38 * bw
	for side in [[0.8, 1.235], [1.265, 1.7]]:
		var a0: float = side[0]; var a1: float = side[1]
		var key := "mar_tail%.3f|%.3f" % [a0, r0]
		_p(sk, HeroKit.drape(key, r0, r1, 0.34, a0, a1, 8.0, 0.06, 0.02, 0.1), m["body"], Vector3(0, -0.02, 0.01))
		_p(sk, HeroKit.drape_hem(key, r0, r1, 0.34, a0, a1, 8.0, 0.06, 0.02, 0.1, 0.06), m["trim"], Vector3(0, -0.02, 0.01))
	_tp(c, "mar_vest", 0.69, 0.81, 0.16, 0.86, 0.01, m["shirt"], 0.012)
	# the scarf: wound at the throat, two long ends streaming behind (the animation sways "Scarf")
	var scarf := Models._pivot(t, "Scarf", Vector3(0, 0.6, 0.18 * bw))
	_p(t, HeroKit.mantle("mar_scarf_wrap", 0.13, 0.13, 0.05, 5.0), team, Vector3(0, 0.67, -0.01))
	for sx in [-1.0, 1.0]:
		_p(scarf, HeroKit.lock_mesh("mar_scarf%d" % int(sx), [Vector3(0.03 * sx, 0.06, 0.0), Vector3(0.08 * sx, -0.04, 0.16), Vector3(0.12 * sx, -0.2, 0.36), Vector3(0.14 * sx, -0.4, 0.5)], 0.09, 0.2, Vector3.BACK, 0.8, 0.4), team)
	# the bandolier of burr charges: small spiked spheres in a leather strap
	var bpts := [Vector3(0.2, 0.6, -0.14), Vector3(0.05, 0.42, -0.255), Vector3(-0.12, 0.22, -0.245), Vector3(-0.22, 0.08, -0.17)]
	_p(t, HeroKit.loft("mar_bandolier", bpts, [Vector2(0.032, 0.01), Vector2(0.034, 0.011), Vector2(0.034, 0.011), Vector2(0.032, 0.01)], 6, Vector3.FORWARD, 0.9), m["leather"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	var bc := HeroKit.curve3(bpts, 6)
	for k in range(3, bc.size() - 3, 3):
		var p: Vector3 = bc[k]
		var bp := Vector3(p.x * cw, p.y, p.z * bw - 0.03)
		_p(t, Models.sphere(0.034, 8), bronze, bp)
		for sa in 4:
			var ang := sa * PI * 0.5 + 0.4
			_p(t, Models.crystal(0.012, 0.045, 4), m["glow"], bp + Vector3(cos(ang), sin(ang), 0.3).normalized() * 0.04, Vector3.ONE, Vector3(0, 0, ang - PI * 0.5))
	# one big bronze pauldron on the left shoulder, rimmed in the team colour
	_p(t, Models.sphere(0.115, 14), bronze, Vector3(-0.3 * cw, 0.62, 0.0), Vector3(1.2, 0.7, 1.1))
	_p(t, HeroKit.band("mar_pauld", 0.1, 0.13, 0.03, 0.01), team, Vector3(-0.3 * cw, 0.6, 0.0), Vector3.ONE, Vector3(0, 0, 0.1))
	# a drum-mag pouch on the right hip
	var hp := Vector3(0.25 * bw, -0.02, -0.03)
	_p(t, Models.cyl(0.07, 0.07, 0.09, 14), bronze, hp + Vector3(0, 0.0, 0), Vector3.ONE, Vector3(0, 0, PI / 2))
	_p(t, Models.cyl(0.05, 0.05, 0.095, 14), m["leather"], hp, Vector3.ONE, Vector3(0, 0, PI / 2))
	# knee guards
	for sd in ["L", "R"]:
		var kn: Node3D = c["knees"][sd]
		_p(kn, Models.sphere(0.065, 10), bronze, Vector3(0, -0.02, -0.07), Vector3(1.0, 0.8, 0.7))

# ------------------------------------------------------------------------------------------ juggernaut
## The wrecking ball, a top-heavy brute built like the great heavies of hero games: a closed great
## helm whose only feature is a burning visor slit, horns sweeping forward off the helm, the
## biggest shoulders in the game (stacked angular plates enamelled in the team colour, a row of
## spikes on top), a fur mantle, a great back plate, and gauntlets like anvils. From the match
## camera it reads as two huge team-coloured shoulders, a pair of horns and a glowing bar.
static func _juggernaut(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var visor := Models.toon(Color("ffb648"), false, 1.7)
	visor.set_shader_parameter("rim_amount", 0.0)
	var halo_m := StandardMaterial3D.new()
	halo_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_m.albedo_color = Color(1.0, 0.55, 0.18, 0.4)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		_p(g, helm_mesh("jugg", c["hk"], 0.88, 0.6, 1.3), m["steel"], HC)
		# the faceplate: a closed visor over the whole face, jutting at the jaw, with a slit
		_p(g, faceplate("jugg", c["hk"], _snout(c)), m["steel"], HC)
		var slit := []
		for k in 9:
			var th := lerpf(-1.0, 1.0, k / 8.0)
			var d := Vector3(sin(th) * cos(0.06), sin(0.06), -cos(th) * cos(0.06))
			slit.append(HeroKit.head_pt(d, HeroKit.HEADS.get(String(c["hk"]), HeroKit.HEADS["human_m"])) + d * 0.075 + Vector3(0, 0, -_snout(c) * cos(th) * 0.5) + HC)
		var sw := []
		for k in 9:
			var e := 1.0 - pow(absf(k / 4.0 - 1.0), 3.0)
			sw.append(Vector2(0.016, lerpf(0.012, 0.036, e)))
		_p(g, HeroKit.loft("jugg_slit|%s|%.2f" % [c["hk"], _snout(c)], slit, sw, 6, Vector3.UP, 1.0), visor)
		var halo := []
		for k in 9:
			var e := 1.0 - pow(absf(k / 4.0 - 1.0), 3.0)
			halo.append(Vector2(0.03, lerpf(0.03, 0.075, e)))
		var hl := _p(g, HeroKit.loft("jugg_halo|%s|%.2f" % [c["hk"], _snout(c)], slit, halo, 6, Vector3.UP, 1.0), halo_m)
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a heavy brow ridge over the slit and a raised centre ridge down the faceplate
		_p(g, HeroKit.loft("jugg_brow2", [Vector3(-0.25, 0.95, -0.13), Vector3(-0.12, 0.965, -0.29), Vector3(0, 0.975, -0.315), Vector3(0.12, 0.965, -0.29), Vector3(0.25, 0.95, -0.13)], [Vector2(0.032, 0.022), Vector2(0.04, 0.026), Vector2(0.044, 0.028), Vector2(0.04, 0.026), Vector2(0.032, 0.022)], 10, Vector3.UP, 0.9), m["steel"])
		_p(g, HeroKit.loft("jugg_ridge2", [Vector3(0, 1.13, -0.04), Vector3(0, 1.1, -0.22), Vector3(0, 1.0, -0.3)], [Vector2(0.03, 0.03), Vector2(0.036, 0.034), Vector2(0.028, 0.026)], 8, Vector3.FORWARD, 0.9), m["steel"])
		# horns: thick at the root, sweeping out, back, then forward and up (seen from above: a crescent)
		for sx in [-1.0, 1.0]:
			var horn := [Vector3(0.2 * sx, 0.98, 0.02), Vector3(0.36 * sx, 1.0, 0.04), Vector3(0.5 * sx, 1.08, -0.02), Vector3(0.56 * sx, 1.22, -0.14), Vector3(0.52 * sx, 1.36, -0.28)]
			_p(g, HeroKit.loft("jugg_hhorn2%d" % int(sx), horn, [Vector2(0.075, 0.075), Vector2(0.062, 0.062), Vector2(0.046, 0.046), Vector2(0.026, 0.026), Vector2(0.003, 0.003)], 14, Vector3.UP, 0.75), m["bone"])
			_p(g, HeroKit.band("jugg_hornring", 0.082, 0.082, 0.04, 0.014), m["gold"], Vector3(0.24 * sx, 0.985, 0.025), Vector3.ONE, Vector3(0, 0, PI * 0.5 - 0.1 * sx))
	# a breastplate, a great back plate over the pack
	_tp(c, "jugg_breast", 0.56, 0.94, 0.1, 0.72, 0.022, m["steel"], 0.02, 0.012)
	_tp(c, "jugg_belly", 0.6, 0.9, 0.7, 0.9, 0.028, m["trim"], 0.018, 0.008)
	_p(t, HeroKit.loft("jugg_ridge", [Vector3(0, 0.6, -0.23), Vector3(0, 0.45, -0.275), Vector3(0, 0.25, -0.265)], [Vector2(0.018, 0.016), Vector2(0.022, 0.02), Vector2(0.016, 0.014)], 8, Vector3.FORWARD), m["gold"], Vector3.ZERO, Vector3(1.0, 1.0, bw))
	# the team's emblem on the chest: a glowing plate
	_p(t, Models.box(0.1, 0.1, 0.03), m["acc"], Vector3(0, 0.42, -0.29 * bw), Vector3.ONE, Vector3(0.12, 0, PI * 0.25))
	_p(t, Models.box(0.05, 0.05, 0.036), visor, Vector3(0, 0.42, -0.296 * bw), Vector3.ONE, Vector3(0.12, 0, PI * 0.25))
	var back := func(u: float, v: float) -> Vector3:
		var x := lerpf(-0.3, 0.3, u)
		var y := lerpf(0.66, 0.12, v)
		return Vector3(x, y, 0.28 + 0.14 * (1.0 - pow(x / 0.32, 2.0)) * 0.6 - 0.05 * v * v)
	var back_ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.85, v)
	_p(t, HeroKit.shell("jugg_back", back, 16, 10, 0.03, back_ao, false, -1.0), m["steel"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	for sx in [-1.0, 1.0]:
		for k in 2:
			_p(t, Models.sphere(0.022, 8), m["gold"], Vector3(0.24 * sx * cw, 0.6 - k * 0.4, (0.36 - k * 0.04) * bw))
	# a fur mantle round the neck and over the shoulders, dark against the plate
	_p(t, HeroKit.mantle("jugg_fur|%.3f" % cw, 0.25 * cw, 0.23 * bw, 0.11, 9.0, 0.25), m["fur"], Vector3(0, 0.575, 0.04))
	# the plate skirt: two rows of tassets and a hanging tabard in the outfit colour
	var sk: Node3D = c["skirt"]
	var r0 := 0.25 * maxf(bw, cw * 0.9)
	_p(sk, HeroKit.drape("jugg_skirt|%.3f" % r0, r0, r0 * 1.3, 0.24, 0.0, 1.0, 7.0, 0.06, 0.0, 0.0), m["pants"], Vector3(0, -0.02, 0.0))
	_tassets(c, sk, r0, 2, 6, m["steel"], m["gold"])
	_p(sk, HeroKit.sheet("jugg_flap2", 0.2, 0.34, 0.34, 0.0, -0.04, 1, 0.07), m["hero"], Vector3(0, -0.04, -r0 - 0.03), Vector3.ONE, Vector3(0, PI, 0))
	# pauldrons: big angular stacked plates, the top one enamelled in the team colour with a raised
	# steel rim and a row of spikes; they overhang the arm like a roof
	for sd in ["L", "R"]:
		var sx := -1.0 if sd == "L" else 1.0
		var pv: Node3D = c["pl"] if sd == "L" else c["pr"]
		var tilt := Vector3(0, 0, -0.34 * sx)
		_p(pv, HeroKit.box_plate("jugg_padtop", 0.25, 0.27, 0.14, 0.03, 0.55, 2.6), m["acc"], Vector3(0.05 * sx, 0.06, 0), Vector3.ONE, tilt)
		_p(pv, HeroKit.box_plate("jugg_padrim", 0.265, 0.285, 0.03, 0.016, 0.22, 2.6), m["steel"], Vector3(0.05 * sx, 0.06, 0) + Basis.from_euler(tilt) * Vector3(0, -0.02, 0), Vector3.ONE, tilt)
		for k in 2:
			var tk := Vector3(0, 0, (-0.5 - k * 0.16) * sx)
			_p(pv, HeroKit.box_plate("jugg_padlame%d" % k, 0.23 - k * 0.015, 0.25 - k * 0.015, 0.1, 0.024, 0.6, 2.8), m["steel"], Vector3((0.1 + k * 0.035) * sx, -0.03 - k * 0.07, 0), Vector3.ONE, tk)
			_p(pv, HeroKit.box_plate("jugg_padlrim%d" % k, 0.24 - k * 0.015, 0.26 - k * 0.015, 0.02, 0.012, 0.2, 2.8), m["gold"], Vector3((0.1 + k * 0.035) * sx, -0.03 - k * 0.07, 0) + Basis.from_euler(tk) * Vector3(0, -0.045, 0), Vector3.ONE, tk)
		for k in 3:
			var z := (k - 1) * 0.12
			var at := Vector3(0.05 * sx, 0.06, 0) + Basis.from_euler(tilt) * Vector3(0.05 * sx, 0.135, z)
			Models._spike(pv, m["steel"], at, Basis.from_euler(tilt) * Vector3(0.35 * sx, 1.0, z * 0.8), 0.034 - absf(k - 1) * 0.006, 0.13 - absf(k - 1) * 0.03)
	# under the plate the arms wear a dark padded undersuit (the coat colour would read as bare
	# balloon sleeves between the plates)
	_undersuit(c)
	# plated upper arms: two overlapping rings under the pauldron
	for sd in ["L", "R"]:
		var ap: Node3D = (c["arms"][sd] as Array)[0]
		for k in 2:
			_p(ap, HeroKit.cuff(0.094 - k * 0.008, 0.104 - k * 0.008, 0.08), m["steel"], Vector3(0, -0.07 - k * 0.07, 0))
	# gauntlets like anvils: a plated forearm that swells to the wrist, a big flared cuff, knuckle plates
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.075, 0.13, 0.17), m["steel"], Vector3(0, -0.14, 0))
		_p(e2, HeroKit.cuff(0.128, 0.136, 0.03), m["gold"], Vector3(0, -0.07, 0))
		_p(e2, HeroKit.band("jugg_gstrap", 0.1, 0.1, 0.025, 0.01), m["acc"], Vector3(0, -0.17, 0))
		var hand: Node3D = (c["arms"][sd] as Array)[2]
		_p(hand, HeroKit.dome_plate("jugg_knuck", 0.07, 0.5, 0.6, 0.1, 0.016), m["steel"], Vector3(0, -0.06, -0.035), Vector3(1.35, 1.0, 1.0), Vector3(-PI * 0.5 - 0.3, 0, 0))
	_greaves(c, m["steel"], m["gold"])

## How far a race's face sticks out in front (muzzles, beaks), for closed helms.
static func _snout(c: Dictionary) -> float:
	return {"scalefolk": 0.14, "owlet": 0.08, "vulpin": 0.09}.get(String(c["rid"]), 0.0)

## A closed visor over the face: a plate following the sculpted head from the brow to under the
## chin, from cheek to cheek, standing off it and jutting forward at the jaw.
static func faceplate(key: String, hk: String, snout := 0.0) -> ArrayMesh:
	var s: Dictionary = HeroKit.HEADS.get(hk, HeroKit.HEADS["human_m"])
	var fn := func(u: float, v: float) -> Vector3:
		var th := lerpf(-1.35, 1.35, u)
		var ph := lerpf(0.45, -1.05, v)
		var d := Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph))
		var p := HeroKit.head_pt(d, s) + d * 0.062
		var low := smoothstep(0.0, -0.9, ph)
		p.z -= 0.05 * low * (1.0 - absf(sin(th)))       # the jaw juts
		p.z -= snout * cos(th) * smoothstep(0.45, -0.2, ph) * 0.9    # room for a muzzle or a beak
		p.x *= 1.0 + 0.08 * low
		return p
	var ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.82, smoothstep(0.6, 1.0, v)) * lerpf(0.85, 1.0, sin(u * PI))
	return HeroKit.shell("face|%s|%s|%.2f" % [key, hk, snout], fn, 26, 14, 0.022, ao, false, 1.0)

static func _skull(t: Node3D, m: Dictionary, p: Vector3, a: float) -> void:
	_p(t, Models.sphere(0.034, 10), m["bone"], p, Vector3(1.0, 0.95, 0.9))
	_p(t, Models.box(0.04, 0.022, 0.03), m["bone"], p + Vector3(0, -0.028, -0.006), Vector3.ONE, Vector3(0, a, 0))
	for sx in [-1.0, 1.0]:
		_p(t, Models.sphere(0.009, 6), m["dark"], p + Basis(Vector3.UP, -a) * Vector3(0.012 * sx, 0.002, -0.029))

## Rows of plates hanging round the hips (tassets): each row a ring of curved plate segments with
## small gaps, lower and wider than the row above, a gold edge along each hem. The front of the
## last row is left open over the legs.
static func _tassets(c: Dictionary, sk: Node3D, r0: float, rows: int, per: int, m_plate: Material, m_rim: Material) -> void:
	for row in rows:
		var rr := r0 + 0.02 + row * 0.028
		var y := -0.03 - row * 0.075
		for k in per:
			var a0 := (float(k) + 0.5 * (row % 2)) / per + 0.012
			var a1 := a0 + 1.0 / per - 0.024
			var mid := fposmod((a0 + a1) * 0.5, 1.0)
			if row == rows - 1 and absf(mid - 0.75) < 0.6 / per:
				continue
			var key := "tasset%.3f|%.3f|%d" % [rr, a0, per]
			_p(sk, HeroKit.drape(key, rr, rr * 1.16, 0.12, a0, a1, 0.0, 0.0, 0.0, 0.0, 0.018, 3), m_plate, Vector3(0, y, 0))
			_p(sk, HeroKit.drape_hem(key, rr, rr * 1.16, 0.12, a0, a1, 0.0, 0.0, 0.0, 0.0, 0.18), m_rim, Vector3(0, y, 0))

## Plate over the shins and knee cops.
static func _greaves(c: Dictionary, m_plate: Material, m_rim: Material) -> void:
	for sd in ["L", "R"]:
		var kn: Node3D = c["knees"][sd]
		_p(kn, HeroKit.cuff(0.084, 0.096, 0.13), m_plate, Vector3(0, -0.1, 0))
		_p(kn, HeroKit.dome_plate("kneecop", 0.07, 0.45, 0.8, 0.2, 0.014), m_plate, Vector3(0, 0.0, -0.05), Vector3.ONE, Vector3(-PI * 0.5 + 0.1, 0, 0))
		_p(kn, Models.sphere(0.016, 6), m_rim, Vector3(0, 0.0, -0.115))
