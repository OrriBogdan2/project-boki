class_name WardenBulwark
extends RefCounted
## Bjorn, the original Frozen Bulwark (concept sheet docs/art/concepts/bulwark.png on ext/concepts):
## a giant northern ferryman who went down with his ship in the ice and came back. One huge shape
## and a small head: a barrel body in a drowned-navy greatcoat under a big seal-fur collar, short
## planted legs in fur boots, a hood worn back over a bald crown, a forked beard bound in iron rings
## and a laugh. The frost on him never melts: rime on his shoulders, gauntlets and the coat's hem,
## icicles hanging off it. His prow shield and ice-cased oar are his weapon (PinBjornWeapons).
## HeroGear.dress hands him over; c is HeroGear's context.

const COAT := Color("3a5874")         # drowned coat
const COAT_DARK := Color("2a3f56")    # the hood's lining, the coat's turn-ups
const FUR := Color("94795f")          # seal fur
const IRON := Color("66717d")         # ship iron
const GLOVE := Color("98a2ae")        # ship iron, a shade lighter on the gauntlets so they read
const BOOT := Color("6e4a33")         # oiled leather
const TROUSERS := Color("2b3442")
const BEARD := Color("5c5c68")
const BELT := Color("5a3c28")

static func dress(c: Dictionary) -> void:
	var t: Node3D = c["torso"]
	WardenKit.recolour(c, "body", COAT)
	WardenKit.recolour(c, "pants", TROUSERS)
	WardenKit.recolour(c, "leather", BOOT)
	WardenKit.recolour(c, "steel", GLOVE)
	WardenKit.recolour(c, "gold", IRON)       # the belt buckle: ship iron, not gold
	var m := {"coat": WardenKit.cloth(c, COAT), "lining": WardenKit.cloth(c, COAT_DARK), "fur": WardenKit.fur(c, FUR),
		"iron": WardenKit.metal(c, IRON, 0.55), "rime": WardenKit.rime(), "belt": WardenKit.cloth(c, BELT, 2),
		"beard": WardenKit.fur(c, BEARD)}
	_coat(c, t, m)
	_shoulders(c, m)
	_arms(c, m)
	_boots(c, m)
	if not bool(c["bare"]):
		_hood(c, m)
	_face(c, m)

## The greatcoat: iron toggles down the chest, then long skirts split at the front that hang to
## mid-shin, their hem crusted with rime and hung with icicles; the big fur collar over it all.
static func _coat(c: Dictionary, t: Node3D, m: Dictionary) -> void:
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	for k in 3:
		var y := 0.44 - k * 0.11
		Models.part(t, Models.box(0.07, 0.022, 0.03), m["iron"], Vector3(0, y, -0.205 * bw - 0.012))
		Models.part(t, Models.box(0.016, 0.05, 0.022), m["lining"], Vector3(0, y, -0.205 * bw - 0.004))
	var sk: Node3D = c["skirt"]
	var r0 := 0.25 * maxf(bw, cw * 0.9)
	var h := 0.22
	# the split sits at the front (u 0.75): the skirts run from just past it, round the back, to just before it
	var a0 := 0.79
	var a1 := 1.71
	var key := "wb_coat|%.3f" % r0
	Models.part(
		sk,
		HeroKit.drape(key, r0, r0 * 1.28, h, a0, a1, 6.0, 0.05, 0.0, 0.1, 0.02),
		m["coat"],
		Vector3(0, -0.01, 0)
	)
	Models.part(
		sk,
		HeroKit.drape_hem(key, r0, r0 * 1.28, h, a0, a1, 6.0, 0.05, 0.0, 0.1, 0.12),
		m["rime"],
		Vector3(0, -0.01, 0)
	)
	WardenKit.icicles(sk, m["rime"], -h * 1.02, r0 * 1.24, r0 * 1.24 * 0.92, 22, 0.075, 0.71, 0.79)
	# the seal-fur collar: lumpy rolls round the back of the neck and over both shoulders, opening at
	# the front where the ends fall a little down the chest like a stole
	for k in 11:
		var a := lerpf(-0.08, 1.08, k / 10.0) * PI
		var end := absf(k - 5) / 5.0
		var r := lerpf(0.22, 0.13, end * end)
		var at := Vector3(cos(a) * 0.23 * cw, 0.62 - 0.1 * end * end, sin(a) * 0.2 * bw + 0.02)
		Models.part(t, HeroKit.lumpy("wb_fur%d" % (k % 3), Vector3(r, r * 0.72, r), 4.0, 0.12, k * 0.7), m["fur"], at)

## Rime-crusted iron plates on the shoulders under the fur, frost on top and icicles on the edge.
static func _shoulders(c: Dictionary, m: Dictionary) -> void:
	for sd in ["L", "R"]:
		var sx := -1.0 if sd == "L" else 1.0
		var pv: Node3D = c["pl"] if sd == "L" else c["pr"]
		var tilt := Vector3(0, 0, -0.42 * sx)
		var at := Vector3(0.07 * sx, 0.02, 0.0)
		Models.part(pv, HeroKit.box_plate("wb_pad", 0.14, 0.16, 0.1, 0.022, 0.5, 3.0), m["iron"], at, Vector3.ONE, tilt)
		Models.part(
			pv,
			HeroKit.box_plate("wb_padfrost", 0.11, 0.13, 0.085, 0.02, 0.3, 3.0),
			m["rime"],
			at + Vector3(0.0, 0.025, 0),
			Vector3.ONE,
			tilt
		)
		var b := Basis.from_euler(tilt)
		for k in 4:
			var z := (k - 1.5) * 0.085
			Models._spike(
				pv,
				m["rime"],
				at + b * Vector3(0.13 * sx, -0.035, z * 0.85),
				Vector3(0.2 * sx, -1.0, 0),
				0.016,
				0.06 + 0.025 * (k % 2)
			)
		Models.part(
			pv,
			HeroKit.lumpy("wb_padfur", Vector3(0.11, 0.07, 0.13), 5.0, 0.16),
			m["fur"],
			Vector3(-0.02 * sx, 0.1, 0.0)
		)

## Fur cuffs at the wrists and rime grown over the backs of the iron gauntlets.
static func _arms(c: Dictionary, m: Dictionary) -> void:
	for sd in ["L", "R"]:
		var elbow: Node3D = (c["arms"][sd] as Array)[1]
		var hand: Node3D = (c["arms"][sd] as Array)[2]
		WardenKit.fur_roll(elbow, m["fur"], "cuff", Vector3(0, -0.17, 0), 0.07, 0.04)
		Models.part(elbow, HeroKit.cuff(0.07, 0.085, 0.09), m["iron"], Vector3(0, -0.11, 0))
		for k in 3:
			var at := Vector3((k - 1) * 0.028, -0.02 - (k % 2) * 0.02, 0.05)
			Models.part(
				hand,
				Models.crystal(0.018, 0.06, 5),
				m["rime"],
				at,
				Vector3.ONE,
				Vector3(0.9, 0.3 * (k - 1), 0)
			)

## Fur-topped boots: a fat fur roll round each boot top.
static func _boots(c: Dictionary, m: Dictionary) -> void:
	for sd in ["L", "R"]:
		var kn: Node3D = c["knees"][sd]
		WardenKit.fur_roll(kn, m["fur"], "boot", Vector3(0, -0.06, 0.0), 0.085, 0.045, 6.0)

## The hood worn back over his bald crown: it frames the head from behind and falls onto the collar.
static func _hood(c: Dictionary, m: Dictionary) -> void:
	var g: Node3D = c["gear"]
	var hk: String = c["hk"]
	Models.part(g, HeroGear.hood_mesh("wb_hood", hk, 0.075, 1.5, 1.45, 2.2, 0.0, 0.12, 0.024), m["coat"], HeroGear.HC)

## His face over the shared one: bushy brows, a walrus moustache, a laughing open mouth, and a beard
## that grows thick along the jaw and parts into two forks bound in iron rings.
static func _face(c: Dictionary, m: Dictionary) -> void:
	var g: Node3D = c["gear"]
	var hk: String = c["hk"]
	var s: Dictionary = HeroKit.HEADS.get(hk, HeroKit.HEADS["human_m"])
	var hc := HeroGear.HC
	# the beard along the jaw: a thin shell over the lower face (under the mouth in front, up to the
	# ears at the sides), then clumps hanging from the jaw that gather into the two forks
	var jaw := func(u: float, v: float) -> Vector3:
		var th := lerpf(-1.7, 1.7, u)
		var top := lerpf(-0.52, -0.02, smoothstep(0.35, 1.5, absf(th)))
		var ph := lerpf(top, -1.3, v)
		var d := Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph))
		return HeroKit.head_pt(d, s) + d * 0.014
	var jaw_ao := func(u: float, v: float) -> float: return lerpf(0.8, 1.0, smoothstep(0.0, 0.3, v))
	Models.part(g, HeroKit.surf("wb_beard|" + hk, jaw, 30, 12, jaw_ao), m["beard"], hc)
	for k in 9:
		var th := lerpf(-1.35, 1.35, k / 8.0)
		var d := Vector3(sin(th) * cos(-0.62), sin(-0.62), -cos(th) * cos(-0.62))
		var root: Vector3 = HeroKit.head_pt(d, s) + d * 0.01
		var sx := signf(th) if absf(th) > 0.05 else 1.0      # (the middle clump leans right)
		var reach := lerpf(0.42, 0.24, absf(th) / 1.35)
		var tip := Vector3(0.06 * sx, -reach, -0.36 + absf(th) * 0.06)
		var mid := root.lerp(tip, 0.5) + Vector3(0, 0.02, -0.04)
		Models.part(
			g,
			HeroKit.lock_mesh("wb_clump%d|%s" % [k, hk], [root, mid, tip], 0.07, 0.55, Vector3.FORWARD, 0.75, 0.2),
			m["beard"],
			hc
		)
	# the mouth, open in a laugh, cut into the beard under the moustache
	Models.part(
		g,
		Models.sphere(0.034, 10),
		Models.toon(Color("3a1c22"), false),
		hc + Vector3(0, -0.098, -0.236),
		Vector3(1.35, 0.7, 0.45)
	)
	Models.part(
		g,
		Models.box(0.062, 0.012, 0.012),
		Models.toon(Color("f4ecdc"), false),
		hc + Vector3(0, -0.084, -0.246)
	)
	# the two forks, each bound near its tip with an iron ring
	for sx in [-1.0, 1.0]:
		var pts := [
			hc + Vector3(0.03 * sx, -0.22, -0.24),
			hc + Vector3(0.05 * sx, -0.32, -0.31),
			hc + Vector3(0.06 * sx, -0.42, -0.36),
			hc + Vector3(0.055 * sx, -0.5, -0.36)]
		Models.part(g, HeroKit.lock_mesh("wb_fork%d" % int(sx), pts, 0.075, 0.6, Vector3.FORWARD, 0.8, 0.3), m["beard"])
		Models.part(
			g,
			HeroKit.cuff(0.034, 0.036, 0.036),
			m["iron"],
			hc + Vector3(0.06 * sx, -0.43, -0.36),
			Vector3.ONE,
			Vector3(-0.1, 0, 0)
		)
		# the moustache: a heavy sweep from under the nose, out and down over the corners of the mouth
		var mo := [
			hc + Vector3(0.008 * sx, -0.045, -0.255),
			hc + Vector3(0.06 * sx, -0.06, -0.25),
			hc + Vector3(0.11 * sx, -0.09, -0.22),
			hc + Vector3(0.13 * sx, -0.13, -0.19)]
		Models.part(
			g,
			HeroKit.lock_mesh("wb_moust%d" % int(sx), mo, 0.036, 0.75, Vector3.FORWARD, 0.85, 0.5),
			m["beard"]
		)
		# brows: bushy, lifted at the outer ends
		var br := [
			hc + Vector3(0.035 * sx, 0.072, -0.224),
			hc + Vector3(0.095 * sx, 0.09, -0.212),
			hc + Vector3(0.15 * sx, 0.088, -0.175)
		]
		Models.part(g, HeroKit.lock_mesh("wb_brow%d" % int(sx), br, 0.042, 0.55, Vector3.FORWARD, 0.9, 0.8), m["beard"])
