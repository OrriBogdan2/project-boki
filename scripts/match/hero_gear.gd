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
	return {"thief": "hood", "archer": "", "mage": "hat", "gunslinger": "hat", "juggernaut": "helm", "bulwark": "helm"}.get(arch, "")

static func dress(arch: String, c: Dictionary) -> void:
	_belt(c, arch)
	match arch:
		"thief": _thief(c)
		"archer": _archer(c)
		"mage": _mage(c)
		"gunslinger": _gunslinger(c)
		"juggernaut": _juggernaut(c)
		"bulwark": _bulwark(c)
	if not bool(c["bare"]):
		_ear_cuffs(c, arch)

# ------------------------------------------------------------------------------------------ shared
## A belt round the waist with a buckle; heavies wear a broad one.
static func _belt(c: Dictionary, arch: String) -> void:
	var m: Dictionary = c["m"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var heavy := arch in ["juggernaut", "bulwark"]
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
	var mat: Material = {"thief": m["acc"], "mage": m["hero"], "gunslinger": m["leather"], "juggernaut": m["steel"], "bulwark": m["steel"]}.get(arch, m["acc"])
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
	var team_hood := (m["acc"] as ShaderMaterial).duplicate() as ShaderMaterial
	var tc: Color = team_hood.get_shader_parameter("albedo")
	team_hood.set_shader_parameter("albedo", Color.from_hsv(tc.h, minf(1.0, tc.s * 1.05), tc.v * 0.86))
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

# ------------------------------------------------------------------------------------------ archer
## The warden of high ground: tall and upright, a long bow slung high across the back (its tip over
## the head), a quiver of fletched arrows, a hood worn down under a feathered crest, a long cloak.
static func _archer(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	if not bool(c["bare"]):
		# a circlet with a crest of three feathers rising behind
		_p(c["gear"], HeroKit.band("archer_circlet", 0.235, 0.25, 0.026, 0.008), m["gold"], HC + Vector3(0, 0.1, 0.01), Vector3.ONE, Vector3(0.32, 0, 0))
		for k in 3:
			var a := (k - 1) * 0.3
			var root := HC + Vector3(sin(a) * 0.1, 0.16, 0.2)
			var pts := [root, root + Vector3(sin(a) * 0.06, 0.12, 0.08), root + Vector3(sin(a) * 0.14, 0.26, 0.2), root + Vector3(sin(a) * 0.2, 0.32, 0.36)]
			_p(c["gear"], HeroKit.lock_mesh("archer_feather%d" % k, pts, 0.09 - absf(k - 1) * 0.015, 0.2, Vector3.BACK, 0.75, 0.25), m["feather"] if k != 1 else m["acc"])
	# the hood worn down: a soft roll round the neck
	_p(t, HeroKit.mantle("archer_cowl", 0.21, 0.2, 0.065, 6.0), m["cloak"], Vector3(0, 0.6, 0.03))
	# tunic panel and a leather chest guard over the left side
	_tp(c, "archer_guard", 0.6, 0.78, 0.2, 0.6, 0.014, m["leather"], 0.014, 0.004)
	_p(t, HeroKit.loft("archer_strap", [Vector3(0.2, 0.6, -0.12), Vector3(0.02, 0.38, -0.25), Vector3(-0.2, 0.12, -0.2)], [Vector2(0.026, 0.008), Vector2(0.028, 0.008), Vector2(0.026, 0.008)], 6, Vector3.FORWARD, 0.9), m["leather"], Vector3.ZERO, Vector3(c["cw"], 1.0, bw))
	# a long cloak to the knees
	var cape := Models._pivot(t, "Cape", Vector3(0, 0.56, 0.24 * bw))
	_p(cape, HeroKit.drape("archer_cloak", 0.26, 0.4, 0.82, 0.05, 0.45, 7.0, 0.09, 0.03, 0.0, 0.016), m["cloak"], Vector3(0, 0.0, -0.22 * bw), Vector3(c["cw"], 1.0, bw), Vector3(0.06, 0, 0))
	_p(cape, HeroKit.drape_hem("archer_cloak", 0.26, 0.4, 0.82, 0.05, 0.45, 7.0, 0.09, 0.03, 0.0, 0.06), m["trim"], Vector3(0, 0.0, -0.22 * bw), Vector3(c["cw"], 1.0, bw), Vector3(0.06, 0, 0))
	# the long bow slung across the back, its upper tip rising over the left shoulder above the head
	var bow := []
	for k in 9:
		var s := float(k) / 8.0 * 2.0 - 1.0
		bow.append(Vector3(0.0, s * 0.82, 0.13 * (1.0 - s * s) - 0.05 * pow(absf(s), 6.0)))
	var bow_mi := _p(t, HeroKit.loft("archer_bow", bow, [Vector2(0.018, 0.024), Vector2(0.026, 0.03), Vector2(0.034, 0.036), Vector2(0.026, 0.03), Vector2(0.018, 0.024)], 8, Vector3.RIGHT, 1.0), m["wood"], Vector3(0.0, 0.56, 0.36 * bw), Vector3.ONE, Vector3(0.12, 0, 0.5))
	_stay(bow_mi)
	_stay(_p(t, Models.cyl(0.004, 0.004, 1.6, 4), m["shirt"], Vector3(0.0, 0.56, 0.34 * bw), Vector3.ONE, Vector3(0.12, 0, 0.5)))
	for e in [-1.0, 1.0]:
		var tip := Basis.from_euler(Vector3(0.12, 0, 0.5)) * Vector3(0, 0.82 * e, -0.05) + Vector3(0.0, 0.56, 0.36 * bw)
		_stay(_p(t, Models.sphere(0.03, 8), m["gold"], tip))
	_stay(_p(t, Models.cyl(0.04, 0.04, 0.12, 12), m["leather"], Vector3(0.0, 0.56, 0.4 * bw) + Basis.from_euler(Vector3(0.12, 0, 0.5)) * Vector3(0, 0, 0.12), Vector3.ONE, Vector3(0.12, 0, 0.5)))
	# the quiver at the right shoulder, arrows fletched in the team colour
	var qb := Vector3(0.18, 0.4, 0.3 * bw)
	var qr := Vector3(0.3, 0, -0.35)
	_p(t, Models.lathe(Models.smooth_curve(PackedVector2Array([Vector2(0, -0.22), Vector2(0.06, -0.21), Vector2(0.07, 0.0), Vector2(0.078, 0.2), Vector2(0.084, 0.22), Vector2(0.0, 0.22)]), 2), 18, "quiver"), m["leather"], qb, Vector3.ONE, qr)
	_p(t, Models.cyl(0.088, 0.088, 0.03, 18), m["gold"], qb + Basis.from_euler(qr) * Vector3(0, 0.2, 0), Vector3.ONE, qr)
	for k in 4:
		var off := Vector3((k % 2) * 0.04 - 0.02, 0.0, (k / 2) * 0.04 - 0.02)
		var top := qb + Basis.from_euler(qr) * (off + Vector3(0, 0.36, 0))
		_stay(_p(t, Models.cyl(0.007, 0.007, 0.3, 4), m["wood"], qb + Basis.from_euler(qr) * (off + Vector3(0, 0.2, 0)), Vector3.ONE, qr))
		_stay(_p(t, HeroKit.lock_mesh("arrow_fletch", [Vector3(0, -0.07, 0), Vector3(0, 0.0, 0), Vector3(0, 0.05, 0)], 0.05, 0.15, Vector3.BACK, 1.0, 0.5), m["acc"] if k % 2 == 0 else m["feather"], top, Vector3.ONE, qr + Vector3(0, k * 0.8, 0)))
	# one leather pauldron on the bow arm, and a bracer
	_p(c["pl"], HeroKit.dome_plate("archer_pad", 0.12, 0.5, 0.8, 0.22, 0.018), m["leather"], Vector3(-0.03, 0.035, 0), Vector3(1.0, 1.0, 1.1), Vector3(0, 0, 0.5))
	_p(c["pl"], HeroKit.dome_plate("archer_pad2", 0.11, 0.42, 0.7, 0.2, 0.016), m["cloak"], Vector3(-0.06, -0.03, 0), Vector3(1.0, 1.0, 1.05), Vector3(0, 0, 0.85))
	_wraps(c, m["leather"], m["leather"])

# ------------------------------------------------------------------------------------------ mage
## The runecaster: a wide hat with a tall bent crown, a robe whose hem flares, a high-collared
## mantle, a floating focus orb in a ring of runes, and glowing runes on the hem and hat band.
static func _mage(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		_p(g, brim("mage", 0.18, 0.5, 0.03, 0.05, 0.035, 1.05), m["hero"], HC + Vector3(0, 0.15, 0.01), Vector3.ONE, Vector3(-0.1, 0, 0))
		var crown := [Vector3(0, 0.0, 0), Vector3(0, 0.16, 0.01), Vector3(0, 0.32, 0.05), Vector3(0.03, 0.44, 0.13), Vector3(0.1, 0.48, 0.26)]
		var cwid := [Vector2(0.22, 0.23), Vector2(0.17, 0.18), Vector2(0.11, 0.11), Vector2(0.065, 0.065), Vector2(0.012, 0.012)]
		_p(g, HeroKit.loft("mage_crown", crown, cwid, 22, Vector3.FORWARD, 0.85), m["hero"], HC + Vector3(0, 0.15, 0.02), Vector3.ONE, Vector3(-0.1, 0, 0))
		_p(g, HeroKit.band("mage_hatband", 0.205, 0.215, 0.05, 0.012), m["gold"], HC + Vector3(0, 0.19, 0.01), Vector3.ONE, Vector3(-0.1, 0, 0))
		_p(g, Models.crystal(0.03, 0.08, 6), m["glow"], HC + Vector3(0, 0.2, -0.235), Vector3.ONE, Vector3(-0.1, 0, 0))
	# the robe: a long hem to the shins, open at the front over the legs, trimmed in gold with runes
	var sk: Node3D = c["skirt"]
	var r0 := 0.232 * maxf(bw, cw * 0.95); var r1 := 0.42 * bw
	for side in [[0.79, 1.71]]:
		var a0: float = side[0]; var a1: float = side[1]
		var key := "mage_robe%.2f|%.3f" % [a0, r0]
		_p(sk, HeroKit.drape(key, r0, r1, 0.42, a0, a1, 7.0, 0.07, 0.015, 0.08), m["body"], Vector3(0, -0.02, 0.01))
		_p(sk, HeroKit.drape_hem(key, r0, r1, 0.42, a0, a1, 7.0, 0.07, 0.015, 0.08, 0.1), m["gold"], Vector3(0, -0.02, 0.01))
	for k in 9:
		var a := (0.95 + k * 0.1) * TAU
		var p := Vector3(cos(a) * r1 * 0.93, -0.02 - 0.42 * 0.9 * (1.0 + 0.08 * clampf(sin(a), 0.0, 1.0)), sin(a) * r1 * 0.92 * 0.93)
		_p(sk, Models.box(0.022, 0.035, 0.01), m["glow"], p + Vector3(cos(a), 0, sin(a) * 0.92) * 0.02, Vector3.ONE, Vector3(0, -a + PI * 0.5, 0.4 * (k % 2 - 0.5)))
	# the robe's bodice: a deep V over the shirt, gold trim down its edges, a sash in the team colour
	_tp(c, "mage_v", 0.71, 0.79, 0.1, 0.55, 0.008, m["shirt"], 0.01)
	for sx in [-1.0, 1.0]:
		_p(t, HeroKit.loft("mage_lapel%d" % int(sx), [Vector3(0.1 * sx, 0.62, -0.17), Vector3(0.05 * sx, 0.45, -0.235), Vector3(0.0, 0.26, -0.235)], [Vector2(0.02, 0.008), Vector2(0.022, 0.009), Vector2(0.016, 0.008)], 6, Vector3.FORWARD, 0.9), m["gold"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	var rx := 0.225 * maxf(cw, bw) + 0.02; var rz := 0.214 * bw + 0.018
	_p(t, HeroKit.band("mage_sash|%.3f" % rx, rx, rz, 0.05, 0.014), m["acc"], Vector3(0, 0.04, 0), Vector3.ONE, Vector3(0, 0, 0.06))
	_p(t, HeroKit.lock_mesh("mage_sashtail", [Vector3(0.12, 0.04, -rz), Vector3(0.14, -0.08, -rz - 0.03), Vector3(0.15, -0.26, -rz - 0.04)], 0.07, 0.15, Vector3.FORWARD, 0.85, 0.6), m["acc"])
	# the mantle: a capelet over both shoulders with a high collar behind the neck
	_p(t, HeroKit.drape("mage_mantle|%.3f" % cw, 0.2 * cw, 0.34 * cw, 0.17, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.014), m["acc"], Vector3(0, 0.63, 0.0))
	_p(t, HeroKit.drape_hem("mage_mantle|%.3f" % cw, 0.2 * cw, 0.34 * cw, 0.17, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.14), m["gold"], Vector3(0, 0.63, 0.0))
	_p(t, HeroKit.drape("mage_collar", 0.17, 0.26, 0.22, 0.57, 0.93, 3.0, 0.0, 0.0, 0.0, 0.012), m["acc"], Vector3(0, 0.56, 0.02), Vector3(1.0, 1.0, 1.0), Vector3(PI, 0, 0))
	# the focus: an orb floating off the left hand inside a ring of runes (bobbed by HunterAnim)
	var focus := Node3D.new(); focus.name = "Focus"; focus.position = Vector3(-0.42, 0.3, -0.12)
	t.add_child(focus)
	var orb := _p(focus, Models.sphere(0.075, 18), m["glow"])
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p(focus, Models.sphere(0.115, 16), m["glow_soft"])
	var ring := TorusMesh.new(); ring.inner_radius = 0.135; ring.outer_radius = 0.15; ring.rings = 36; ring.ring_segments = 6
	_p(focus, ring, m["glow"], Vector3.ZERO, Vector3.ONE, Vector3(0.5, 0, 0.3))
	for k in 6:
		var a := TAU * k / 6.0
		_p(focus, Models.box(0.024, 0.036, 0.008), m["glow"], Basis.from_euler(Vector3(0.5, 0, 0.3)) * Vector3(cos(a) * 0.19, 0, sin(a) * 0.19), Vector3.ONE, Vector3(0.5, -a, 0.3))
	# a rune ring round the casting wrist
	var el: Node3D = (c["arms"]["L"] as Array)[1]
	var wr := TorusMesh.new(); wr.inner_radius = 0.085; wr.outer_radius = 0.097; wr.rings = 28; wr.ring_segments = 6
	_p(el, wr, m["glow"], Vector3(0, -0.2, 0))
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.06, 0.1, 0.12), m["body"], Vector3(0, -0.16, 0))
		_p(e2, HeroKit.cuff(0.098, 0.104, 0.025), m["gold"], Vector3(0, -0.21, 0))

# ------------------------------------------------------------------------------------------ gunslinger
## The duelist: a wide-brimmed hat, a long split-tail duster that flares, a popped collar and a
## shoulder cape, a bandolier of brass rounds, a holstered sidearm on the hip.
static func _gunslinger(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		var hb := HC + Vector3(0, 0.155, 0.01)
		var hr := Vector3(-0.08, 0, 0.04)
		_p(g, brim("gun", 0.19, 0.47, 0.11, 0.035, 0.0, 1.08), m["hat"], hb, Vector3.ONE, hr)
		var crown := func(u: float, v: float) -> Vector3:
			var th := u * TAU
			var r := 0.205 * (0.88 + 0.12 * v) * sin(minf(v / 0.28, 1.0) * PI * 0.5)
			var x := cos(th) * r; var z := sin(th) * r * 1.12
			var y := lerpf(0.21, 0.0, v) - 0.05 * exp(-x * x / 0.004) * (1.0 - smoothstep(0.0, 0.6, v)) + 0.02 * (1.0 - v) * cos(th * 2.0)
			return Vector3(x, y, z)
		var crown_ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.8, v * v)
		_p(g, HeroKit.surf("gun_crown", crown, 40, 14, crown_ao), m["hat"], hb, Vector3.ONE, hr)
		_p(g, HeroKit.band("gun_hatband", 0.208, 0.232, 0.045, 0.01), m["acc"], hb + Vector3(0, 0.03, 0), Vector3.ONE, hr)
		_p(g, HeroKit.lock_mesh("gun_hatfeather", [Vector3(0.18, 0.06, 0.04), Vector3(0.24, 0.14, 0.12), Vector3(0.27, 0.22, 0.24)], 0.05, 0.2, Vector3.RIGHT, 0.8, 0.3), m["feather"], hb, Vector3.ONE, hr)
	# the duster: open at the front, split up the back, flaring to the shins
	var sk: Node3D = c["skirt"]
	var r0 := 0.234 * maxf(bw, cw * 0.95); var r1 := 0.4 * bw
	for side in [[0.8, 1.235], [1.265, 1.7]]:
		var a0: float = side[0]; var a1: float = side[1]
		var key := "gun_duster%.3f|%.3f" % [a0, r0]
		_p(sk, HeroKit.drape(key, r0, r1, 0.44, a0, a1, 8.0, 0.08, 0.02, 0.06), m["body"], Vector3(0, -0.02, 0.01))
		_p(sk, HeroKit.drape_hem(key, r0, r1, 0.44, a0, a1, 8.0, 0.08, 0.02, 0.06, 0.07), m["trim"], Vector3(0, -0.02, 0.01))
	# the coat over the chest: open over a vest in the shirt colour, with broad lapels
	_tp(c, "gun_vest", 0.69, 0.81, 0.16, 0.86, 0.01, m["shirt"], 0.012)
	for k in 3:
		_p(t, Models.sphere(0.014, 8), m["gold"], Vector3(0.0, 0.42 - k * 0.09, -0.236 * bw))
	for sx in [-1.0, 1.0]:
		_p(t, HeroKit.loft("gun_lapel%d" % int(sx), [Vector3(0.13 * sx, 0.62, -0.15), Vector3(0.1 * sx, 0.5, -0.235), Vector3(0.065 * sx, 0.3, -0.24), Vector3(0.06 * sx, 0.14, -0.235)], [Vector2(0.05, 0.01), Vector2(0.055, 0.012), Vector2(0.03, 0.01), Vector2(0.02, 0.008)], 6, Vector3.FORWARD, 0.85), m["body"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	# the popped collar and a short cape over the shoulders
	_p(t, HeroKit.drape("gun_collar", 0.18, 0.24, 0.17, 0.55, 0.95, 4.0, 0.0, 0.0, 0.0, 0.014), m["body"], Vector3(0, 0.56, 0.02), Vector3(cw * 0.95, 1.0, bw * 0.95), Vector3(PI, 0, 0))
	_p(t, HeroKit.drape("gun_capelet|%.3f" % cw, 0.21 * cw, 0.35 * cw, 0.16, 0.0, 1.0, 7.0, 0.05, 0.0, 0.25, 0.014), m["body"], Vector3(0, 0.63, 0.01))
	_p(t, HeroKit.drape_hem("gun_capelet|%.3f" % cw, 0.21 * cw, 0.35 * cw, 0.16, 0.0, 1.0, 7.0, 0.05, 0.0, 0.25, 0.12), m["trim"], Vector3(0, 0.63, 0.01))
	# the bandolier across the chest, loaded with brass
	var bpts := [Vector3(0.2, 0.6, -0.14), Vector3(0.05, 0.42, -0.255), Vector3(-0.12, 0.22, -0.245), Vector3(-0.22, 0.08, -0.17)]
	_p(t, HeroKit.loft("gun_bandolier", bpts, [Vector2(0.032, 0.01), Vector2(0.034, 0.011), Vector2(0.034, 0.011), Vector2(0.032, 0.01)], 6, Vector3.FORWARD, 0.9), m["leather"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	var bc := HeroKit.curve3(bpts, 6)
	for k in range(3, bc.size() - 3, 2):
		var p: Vector3 = bc[k]
		var d: Vector3 = ((bc[k + 1] as Vector3) - (bc[k - 1] as Vector3)).normalized()
		var rr := atan2(-d.x, -d.y)
		_p(t, Models.cyl(0.0105, 0.0105, 0.05, 6), m["gold"], Vector3(p.x * cw, p.y, p.z * bw - 0.012), Vector3.ONE, Vector3(0, 0, rr + PI * 0.5))
	# the holster on the right hip, a revolver's grip standing out of it
	var hp := Vector3(0.25 * bw, -0.02, -0.03)
	_p(t, HeroKit.loft("gun_holster", [Vector3(0, 0.07, 0), Vector3(0, -0.04, -0.01), Vector3(0, -0.14, -0.03)], [Vector2(0.034, 0.05), Vector2(0.036, 0.05), Vector2(0.02, 0.03)], 10, Vector3.RIGHT, 0.85), m["leather"], hp, Vector3.ONE, Vector3(0.12, 0, 0.12))
	_p(t, HeroKit.loft("gun_grip", [Vector3(0, 0.06, 0.0), Vector3(0, 0.13, 0.03), Vector3(0, 0.16, 0.07)], [Vector2(0.018, 0.026), Vector2(0.02, 0.028), Vector2(0.022, 0.03)], 8, Vector3.RIGHT, 0.9), m["dark"], hp, Vector3.ONE, Vector3(0.12, 0, 0.12))
	_p(t, Models.cyl(0.032, 0.032, 0.03, 12), m["gold"], hp + Vector3(0, 0.075, -0.004), Vector3.ONE, Vector3(0.12, 0, 0.12))
	# a neckerchief whose ends trail behind
	var scarf := Models._pivot(t, "Scarf", Vector3(0, 0.6, 0.18 * bw))
	_p(t, HeroKit.mantle("gun_kerchief", 0.12, 0.12, 0.035, 5.0), m["acc"], Vector3(0, 0.66, -0.01))
	for sx in [-1.0, 1.0]:
		_p(scarf, HeroKit.lock_mesh("gun_kerchief%d" % int(sx), [Vector3(0.02 * sx, 0.06, 0.0), Vector3(0.06 * sx, -0.02, 0.08), Vector3(0.1 * sx, -0.16, 0.12)], 0.07, 0.18, Vector3.BACK, 0.8, 0.4), m["acc"])
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.062, 0.088, 0.09), m["body"], Vector3(0, -0.165, 0))
		_p(e2, HeroKit.cuff(0.086, 0.09, 0.02), m["trim"], Vector3(0, -0.2, 0))

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
	for sd in ["L", "R"]:
		for nd in [(c["arms"][sd] as Array)[0], (c["arms"][sd] as Array)[1]]:
			for ch in (nd as Node3D).get_children():
				if ch is MeshInstance3D and (ch as MeshInstance3D).material_override == m["body"]:
					(ch as MeshInstance3D).material_override = m["pants"]
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

# ------------------------------------------------------------------------------------------ bulwark
## The squad's shield: a great helm with a visor slit and a square crest, a tower shield on the
## back with a banner pole over it, layered plate skirt over a tabard, square pauldrons, a cape.
static func _bulwark(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		# the bucket: boxy, a little deeper in front for snouts and beaks
		var snout: float = {"scalefolk": 0.14, "owlet": 0.08, "vulpin": 0.05}.get(String(c["rid"]), 0.0)
		var helm := func(u: float, v: float) -> Vector3:
			var n := HeroKit.sdir(u, lerpf(0.0, 0.8, v))
			var k := 3.6
			var d := pow(pow(absf(n.x), k) + pow(absf(n.y), k) + pow(absf(n.z), k), 1.0 / k)
			var p := (n / d).lerp(n, 0.2)
			var p2 := Vector3(p.x * 0.255, p.y * 0.27, p.z * (0.262 + snout * clampf(-p.z, 0.0, 1.0)))
			p2.y += 0.04
			return p2
		var helm_ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.78, v * v)
		_p(g, HeroKit.shell("bul_helm|%.2f" % snout, helm, 40, 16, 0.022, helm_ao, true, 1.0, 0.3), m["steel"], HC)
		var fz := -0.262 - snout - 0.005
		_p(g, Models.box(0.32, 0.034, 0.03), m["glow"], HC + Vector3(0, 0.02, fz + 0.01))
		_p(g, Models.box(0.034, 0.16, 0.03), m["glow"], HC + Vector3(0, -0.06, fz + 0.01))
		_p(g, HeroKit.band("bul_helmrim|%.2f" % snout, 0.265, 0.275 + snout * 0.5, 0.03, 0.01), m["gold"], HC + Vector3(0, -0.17, -snout * 0.4))
		_p(g, HeroKit.loft("bul_crest", [Vector3(0, 0.27, -0.22), Vector3(0, 0.35, -0.08), Vector3(0, 0.35, 0.12), Vector3(0, 0.27, 0.26)], [Vector2(0.03, 0.06), Vector2(0.032, 0.09), Vector2(0.032, 0.09), Vector2(0.03, 0.05)], 8, Vector3.RIGHT, 0.85, 3), m["acc"], HC + Vector3(0, -0.03, 0), Vector3(1.0, 1.0, 1.0))
	# breastplate with a tabard over it, a gorget
	_tp(c, "bul_breast", 0.55, 0.95, 0.08, 0.75, 0.022, m["steel"], 0.02, 0.012)
	_tp(c, "bul_tabard", 0.69, 0.81, 0.3, 0.92, 0.04, m["hero"], 0.012)
	_p(t, Models.box(0.1, 0.1, 0.02), m["gold"], Vector3(0, 0.36, -0.29 * bw), Vector3.ONE, Vector3(0.1, 0, PI * 0.25))
	_p(t, HeroKit.drape("bul_gorget|%.3f" % cw, 0.13, 0.27 * cw, 0.1, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.02), m["steel"], Vector3(0, 0.69, 0.0))
	_p(t, HeroKit.drape_hem("bul_gorget|%.3f" % cw, 0.13, 0.27 * cw, 0.1, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.2), m["gold"], Vector3(0, 0.69, 0.0))
	# plate skirt: three rows of tassets over a tabard flap
	var sk: Node3D = c["skirt"]
	var r0 := 0.25 * maxf(bw, cw * 0.9)
	_p(sk, HeroKit.drape("bul_skirt|%.3f" % r0, r0, r0 * 1.25, 0.26, 0.0, 1.0, 7.0, 0.05, 0.0, 0.0), m["pants"], Vector3(0, -0.02, 0.0))
	_tassets(c, sk, r0, 3, 7, m["steel"], m["gold"])
	_p(sk, HeroKit.sheet("bul_flap", 0.18, 0.36, 0.36, 0.0, -0.05, 0, 0.0), m["hero"], Vector3(0, -0.02, -r0 - 0.07), Vector3.ONE, Vector3(0, PI, 0))
	# the cape, behind the shield
	var cape := Models._pivot(t, "Cape", Vector3(0, 0.58, 0.25 * bw))
	_p(cape, HeroKit.drape("bul_cape", 0.27, 0.42, 0.8, 0.04, 0.46, 6.0, 0.07, 0.02, 0.0, 0.016), m["acc"], Vector3(0, 0.0, -0.24 * bw), Vector3(cw, 1.0, bw), Vector3(0.05, 0, 0))
	# the tower shield on the back: a tall curved slab with a steel rim, a boss and the hero emblem
	var shield := func(u: float, v: float) -> Vector3:
		var x := lerpf(-0.3, 0.3, u)
		var y := lerpf(0.42, -0.5, v)
		var y2 := y - 0.06 * pow(x / 0.3, 2.0) * smoothstep(0.0, -0.5, y)
		return Vector3(x, y2, 0.08 * (1.0 - pow(x / 0.3, 2.0)))
	var sp := Vector3(0, 0.38, 0.44 * bw)
	var shield_ao := func(u: float, v: float) -> float: return lerpf(0.82, 1.0, smoothstep(0.0, 0.2, minf(minf(u, 1.0 - u), minf(v, 1.0 - v))))
	_p(t, HeroKit.shell("bul_shield", shield, 18, 16, 0.035, shield_ao, false, -1.0), m["acc"], sp)
	var rim := []
	for k in 13:
		var a := float(k) / 12.0
		rim.append(Vector3(lerpf(-0.31, 0.31, a), 0.43, 0.035 * (1.0 - pow(lerpf(-1.0, 1.0, a), 2.0))))
	_p(t, HeroKit.loft("bul_rimtop", rim, [Vector2(0.024, 0.024), Vector2(0.024, 0.024)], 8, Vector3.BACK, 1.0, 2), m["steel"], sp)
	for sx in [-1.0, 1.0]:
		_p(t, HeroKit.loft("bul_rimside%d" % int(sx), [Vector3(0.31 * sx, 0.43, 0.0), Vector3(0.31 * sx, -0.1, 0.0), Vector3(0.28 * sx, -0.5, 0.0), Vector3(0.0, -0.56, 0.02)], [Vector2(0.024, 0.024), Vector2(0.024, 0.024)], 8, Vector3.BACK, 1.0), m["steel"], sp)
	_p(t, Models.sphere(0.075, 14), m["gold"], sp + Vector3(0, 0.0, 0.1), Vector3(1.0, 1.0, 0.55))
	_p(t, Models.box(0.05, 0.62, 0.02), m["hero"], sp + Vector3(0, -0.05, 0.095))
	_p(t, Models.box(0.4, 0.05, 0.02), m["hero"], sp + Vector3(0, 0.12, 0.09))
	# the banner pole over the shield, its pennant in the team colour
	var pole := _stay(_p(t, Models.cyl(0.016, 0.016, 1.3, 8), m["wood"], Vector3(-0.2, 0.68, 0.36 * bw), Vector3.ONE, Vector3(0.05, 0, 0.12)))
	pole.set_meta("stay", true)
	var top := Vector3(-0.2, 0.68, 0.36 * bw) + Basis.from_euler(Vector3(0.05, 0, 0.12)) * Vector3(0, 0.65, 0)
	_stay(_p(t, Models.sphere(0.035, 10), m["gold"], top))
	_stay(_p(t, Models.cyl(0.012, 0.012, 0.36, 6), m["wood"], top + Vector3(0.14, -0.05, 0.0), Vector3.ONE, Vector3(0, 0, PI * 0.5 - 0.12)))
	_stay(_p(t, HeroKit.sheet("bul_banner", 0.34, 0.42, 0.3, 0.0, 0.05, 2, 0.08, 0.01), m["acc"], top + Vector3(0.14, -0.06, 0.0), Vector3.ONE, Vector3(0, PI * 0.5, -0.12)))
	# square pauldrons: three stepped lames with a raised gold edge
	for sd in ["L", "R"]:
		var sx := -1.0 if sd == "L" else 1.0
		var pv: Node3D = c["pl"] if sd == "L" else c["pr"]
		for k in 3:
			var plate := HeroKit.box_plate("bul_pad%d" % k, 0.19 - k * 0.012, 0.2 - k * 0.012, 0.13, 0.024)
			_p(pv, plate, m["acc"] if k == 0 else m["steel"], Vector3((0.035 + k * 0.045) * sx, 0.07 - k * 0.075, 0.0), Vector3.ONE, Vector3(0, 0, (-0.3 - k * 0.32) * sx))
		_p(pv, HeroKit.box_plate("bul_padrim", 0.2, 0.21, 0.02, 0.012, 0.25), m["gold"], Vector3(0.035 * sx, 0.07, 0.0) + Basis.from_euler(Vector3(0, 0, -0.3 * sx)) * Vector3(0, -0.005, 0), Vector3.ONE, Vector3(0, 0, -0.3 * sx))
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.07, 0.1, 0.14), m["steel"], Vector3(0, -0.15, 0))
		_p(e2, HeroKit.cuff(0.098, 0.104, 0.022), m["gold"], Vector3(0, -0.085, 0))
	_greaves(c, m["steel"], m["gold"])
