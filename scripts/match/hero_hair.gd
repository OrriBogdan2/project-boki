class_name HeroHair
## Human hair as chunky stylized clumps: a cap of rounded, creased locks that follows the sculpted
## head and comes down in pointed tips (fringe, sides, nape), plus each style's own masses (long
## curtains, a ponytail, a bun, spikes, a mohawk crest, curls, a braid). Under an archetype's hat
## the tall parts are left off; under a hood or helm only what spills out below shows.

const HC := Vector3(0, 0.86, 0)

## How far down the cap reaches round the head: at the front (fringe), the sides and the back,
## and an optional sweep to one side (+ right, - left).
static func _edge(front: float, side: float, back: float, sweep := 0.0) -> Callable:
	return func(u: float) -> float:
		var th := u * TAU
		var f := pow(maxf(-sin(th), 0.0), 1.5)
		var b := pow(maxf(sin(th), 0.0), 1.2)
		var e := lerpf(lerpf(side, front, f), back, b)
		return e + sweep * f * cos(th)

static func _lock(n: Node3D, m: Material, key: String, pts: Array, w: float, flat := 0.5, up := Vector3.UP, blunt := 0.0) -> MeshInstance3D:
	return Models.part(n, HeroKit.lock_mesh("hl|" + key, pts, w, flat, up, 0.6, blunt), m)

static func _cap(n: Node3D, m: Material, hk: String, key: String, e: Callable,
		locks: int, th: float, tip: float) -> void:
	Models.part(n, HeroKit.hair_cap(key, hk, e, locks, th, tip), m, HC)

static func human(n: Node3D, style: int, fem: bool, m: Material, hk: String, cov: String) -> void:
	if style == 13:
		return    # bald
	var under := cov in ["hood", "helm"]
	var hat := cov == "hat"
	if under:
		_spill(n, style, m, hk, cov)
		return
	match style:
		0:   # short: a choppy fringe and a tuft on the crown
			_cap(n, m, hk, "short", _edge(0.28, 0.44, 0.6), 11, 0.042, 0.09)
			if not hat:
				for k in 3:
					var a := (k - 1) * 0.45
					var r := HC + Vector3(sin(a) * 0.06, 0.24, 0.02 + cos(a) * 0.02)
					_lock(n, m, "tuft%d" % k, [r, r + Vector3(sin(a) * 0.05, 0.06, -0.02), r + Vector3(sin(a) * 0.1, 0.08, 0.04)], 0.06, 0.5, Vector3.BACK)
		1:   # long: a curtain of locks down the back to the shoulder blades, two framing the face
			_cap(n, m, hk, "long", _edge(0.3, 0.55, 0.68), 12, 0.045, 0.1)
			_curtain(n, m)
			for sx in [-1.0, 1.0]:
				var r := HC + Vector3(0.2 * sx, -0.02, -0.06)
				_lock(n, m, "frame%d" % int(sx), [r, r + Vector3(0.03 * sx, -0.12, 0.0), r + Vector3(0.02 * sx, -0.24, 0.03), r + Vector3(0.0, -0.32, 0.06)], 0.08, 0.45, Vector3(sx, 0, 0))
		2:   # ponytail: swept back to a tie, the tail curling down behind
			_cap(n, m, hk, "pony", _edge(0.26, 0.42, 0.6), 12, 0.04, 0.06)
			Models.part(n, Models.sphere(0.04, 10), Models.toon(Color("e0607e")), HC + Vector3(0, 0.1, 0.25))
			var r := HC + Vector3(0, 0.1, 0.27)
			_lock(n, m, "pony", [r, r + Vector3(0, 0.02, 0.1), r + Vector3(0.01, -0.1, 0.17), r + Vector3(0.03, -0.26, 0.15), r + Vector3(0.05, -0.38, 0.1)], 0.13, 0.7, Vector3.BACK, 0.15)
			_lock(n, m, "pony2", [r, r + Vector3(0.04, -0.02, 0.08), r + Vector3(0.07, -0.14, 0.1), r + Vector3(0.09, -0.24, 0.06)], 0.07, 0.6, Vector3.BACK)
		3:   # bun: smoothed back to a big lumpy bun with a gold pin
			_cap(n, m, hk, "bun", _edge(0.27, 0.44, 0.6), 13, 0.034, 0.05)
			if not hat:
				Models.part(n, HeroKit.lumpy("bun", Vector3(0.11, 0.1, 0.11), 4.0, 0.14, 1.0), m, HC + Vector3(0, 0.23, 0.15))
				Models.part(n, Models.cyl(0.008, 0.008, 0.26, 6), Models.shiny(Color("f2c84a"), 0.6), HC + Vector3(0, 0.25, 0.15), Vector3.ONE, Vector3(0, 0, 1.2))
			else:
				Models.part(n, HeroKit.lumpy("bun", Vector3(0.11, 0.1, 0.11), 4.0, 0.14, 1.0), m, HC + Vector3(0, 0.06, 0.24))
		4:   # spiky: big swept spikes off the crown
			_cap(n, m, hk, "spiky", _edge(0.27, 0.42, 0.55), 9, 0.045, 0.12)
			if not hat:
				for k in 7:
					var a := -1.2 + k * 0.4
					var r := HC + Vector3(sin(a) * 0.15, 0.19 - absf(a) * 0.03, 0.03 + cos(a) * 0.04)
					var d := Vector3(sin(a) * 0.5, 0.75, 0.55).normalized()
					_lock(n, m, "spike%d" % k, [r, r + d * 0.1, r + d * 0.2 + Vector3(0, -0.02, 0.04)], 0.1, 0.55, Vector3.BACK)
		5:   # buzzed: a close crop
			_cap(n, m, hk, "buzz", _edge(0.3, 0.45, 0.6), 18, 0.034, 0.02)
		6:   # bob: straight sides to the jaw and a blunt fringe
			_cap(n, m, hk, "bob", _edge(0.33, 0.66, 0.66), 14, 0.05, 0.05)
		7:   # pigtails
			_cap(n, m, hk, "pig", _edge(0.28, 0.45, 0.6), 12, 0.04, 0.08)
			_pigtails(n, m)
		8:   # a long braid down the back
			_cap(n, m, hk, "braidcap", _edge(0.28, 0.46, 0.62), 12, 0.04, 0.07)
			_braid(n, m)
		9:   # mohawk: a shaved cap under a crest of big locks
			_cap(n, m, hk, "mohawkcap", _edge(0.32, 0.42, 0.6), 18, 0.03, 0.02)
			if not hat:
				for k in 6:
					var z := -0.17 + k * 0.075
					var r := HC + Vector3(0, 0.215 - absf(k - 2.5) * 0.015, z)
					_lock(n, m, "mohawk%d" % k, [r, r + Vector3(0, 0.1, 0.03 + k * 0.01), r + Vector3(0, 0.18, 0.1 + k * 0.012)], 0.11, 0.35, Vector3.RIGHT)
		10:  # afro: a big cloud of round curls
			if not hat:
				Models.part(n, HeroKit.lumpy("afro", Vector3(0.32, 0.3, 0.31), 7.0, 0.08, 0.3), m, HC + Vector3(0, 0.1, 0.06))
			else:
				_cap(n, m, hk, "afrocap", _edge(0.3, 0.6, 0.66), 9, 0.07, 0.04)
			for k in 5:
				var x := -0.13 + k * 0.065
				Models.part(n, HeroKit.lumpy("afrof", Vector3(0.07, 0.065, 0.05), 3.0, 0.12, float(k)), m, HC + Vector3(x, 0.14 - absf(k - 2) * 0.012, -0.18))
		11:  # curly: curls all over
			_cap(n, m, hk, "curlcap", _edge(0.3, 0.46, 0.62), 11, 0.04, 0.05)
			for k in 12:
				var a := TAU * k / 12.0
				var yy := 0.07 + (k % 3) * 0.05
				if hat and yy > 0.1:
					continue
				Models.part(n, HeroKit.lumpy("curl", Vector3(0.07, 0.07, 0.07), 3.0, 0.15, 0.5), m, HC + Vector3(cos(a) * 0.22, yy, sin(a) * 0.2 + 0.03))
		12:  # swoop: a big lock swept across the forehead
			_cap(n, m, hk, "swoopcap", _edge(0.26, 0.44, 0.6, 0.12), 11, 0.045, 0.08)
			var r := HC + Vector3(-0.12, 0.2, -0.12)
			_lock(n, m, "swoop", [r, r + Vector3(0.1, 0.02, -0.08), r + Vector3(0.22, -0.06, -0.1), r + Vector3(0.27, -0.16, -0.06)], 0.16, 0.4, Vector3(0, 0.6, -1.0))
		_:
			_cap(n, m, hk, "short", _edge(0.28, 0.44, 0.6), 11, 0.042, 0.09)

## Under a hood or a helm: a few locks of fringe at the forehead (hoods only), and whatever hangs
## below it (long hair, a braid, pigtails, a ponytail).
static func _spill(n: Node3D, style: int, m: Material, hk: String, cov: String) -> void:
	if cov == "hood" and style not in [5, 9]:
		for k in 3:
			var x := (k - 1) * 0.075
			var r := HC + Vector3(x, 0.17, -0.17)
			_lock(n, m, "spill%d" % k, [r, r + Vector3(x * 0.2, -0.05, -0.04), r + Vector3(x * 0.4 + 0.01, -0.1, -0.05)], 0.07, 0.45, Vector3(0, 0.3, -1.0))
	match style:
		1:
			_curtain(n, m, true)
		2:
			if cov == "hood":
				var r := HC + Vector3(0.12, -0.1, -0.1)
				_lock(n, m, "ponyspill", [r, r + Vector3(0.04, -0.1, -0.02), r + Vector3(0.05, -0.22, 0.0)], 0.09, 0.5, Vector3.RIGHT)
		6:
			if cov == "hood":
				for sx in [-1.0, 1.0]:
					var r := HC + Vector3(0.17 * sx, 0.0, -0.1)
					_lock(n, m, "bobspill%d" % int(sx), [r, r + Vector3(0.0, -0.08, 0.0), r + Vector3(-0.02 * sx, -0.14, 0.0)], 0.08, 0.5, Vector3(sx, 0, 0))
		7:
			_pigtails(n, m)
		8:
			_braid(n, m)

## Long hair: locks fanned round the back of the head down to the shoulder blades.
static func _curtain(n: Node3D, m: Material, low := false) -> void:
	for k in 9:
		var a := lerpf(-1.35, 1.35, k / 8.0)
		var r := HC + Vector3(sin(a) * 0.2, -0.02 if not low else -0.12, cos(a) * 0.17 + 0.03)
		var out := Vector3(sin(a), 0, cos(a))
		var ln := 0.38 - absf(a) * 0.07 + (k % 2) * 0.04
		_lock(n, m, "curtain%d%s" % [k, low], [r, r + out * 0.06 + Vector3(0, -ln * 0.4, 0), r + out * 0.07 + Vector3(0, -ln * 0.8, 0.02), r + out * 0.04 + Vector3(sin(a) * 0.03, -ln, 0.0)], 0.1, 0.32, out)

static func _pigtails(n: Node3D, m: Material) -> void:
	for sx in [-1.0, 1.0]:
		var r := HC + Vector3(0.22 * sx, 0.06, 0.12)
		Models.part(n, Models.sphere(0.04, 8), Models.toon(Color("e0607e")), r)
		_lock(n, m, "pigtail%d" % int(sx), [r, r + Vector3(0.06 * sx, -0.06, 0.04), r + Vector3(0.1 * sx, -0.18, 0.06), r + Vector3(0.09 * sx, -0.3, 0.04)], 0.11, 0.75, Vector3(sx, 0, 0), 0.1)

static func _braid(n: Node3D, m: Material) -> void:
	for k in 6:
		var w := 0.065 - k * 0.005
		Models.part(n, HeroKit.lumpy("braid", Vector3(1, 1, 1), 2.0, 0.12, 0.2), m, HC + Vector3(0.0, -0.02 - k * 0.075, 0.27 + k * 0.012), Vector3(w * 1.1, w * 0.95, w * 0.85), Vector3(0, 0, 0.5 * (k % 2 * 2 - 1)))
	Models.part(n, Models.sphere(0.03, 6), Models.toon(Color("e0607e")), HC + Vector3(0, -0.47, 0.34))
