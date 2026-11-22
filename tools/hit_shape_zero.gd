class_name HitShapeZero
extends RefCounted
## The per-ability drivers of --hit-shape-check (docs/HITBOX_SIZE.md, "Zero rows closed"). The plain grid reads
## zero for an input that hurts nobody inside its 1 s window, 7.5 m reach or one press. Each driver below
## gives such an input what it needs: a second press, a longer window, a cursor nearer (or a lane of dummies
## out to 18 m), a ring of dummies for an arc. An input that does no damage by design is listed in NO_DAMAGE
## with the reason, so a zero row that is in neither list fails the check.

const STEP := 0.25               # m between the dummies of a lane
const LANE_FROM := 0.75          # m from the hero to the first dummy of a lane
const ARC_STEP := 2.5            # degrees between the dummies of a ring
const PASSES := 4                # a lane or a ring is read in this many runs, every 4th dummy standing
const HALF := [0, 2]             # the passes of a cross or a ring (every 2nd dummy: 0.5 m / 5 degrees is enough there)
const GAP := 4                   # slots: hits further apart than this belong to two things (a straggler is dropped)

## Inputs that hurt nobody, by design (a heal, a shield, a wall, a move that only carries): the reason, and the
## window and presses the check gives them to prove it (a lane of dummies, nothing may lose health).
const NO_DAMAGE := {
	"archer:rmb": ["a quick tap does nothing and costs nothing (the Heavy Shot is the RMB hold row)", 1.0],
	"archer:dash": ["Spirit Walk: a roll, then walking through rocks; the spirit orb hurts nobody", 3.5],
	"gunslinger:dash": ["Slipstep: a skid, no hit", 1.5],
	"thief:dash": ["Vault: a cartwheel; it only empowers the next shot (the E and LMB rows)", 1.5],
	"rimewright:dash": ["Skate: a glide and an ice strip; the darts thrown from it are the LMB row", 2.5],
	"bulwark:rmb": ["Aegis: a shield; the boop shoves 2.8 m for no damage (card: 'no damage')", 1.5],
	"bulwark:rmb_hold": ["Aegis held: the same shield", 1.5],
	"bulwark:e": ["Mending Ground: heals allies, no damage", 3.0],
	"dolm:e": ["Stone Row: three rocks that stop foes and shots, no damage", 2.0],
	"ostra:dash": ["Lantern Trade: carries everyone in its circle to the hero, no damage", 3.0],
	"tender:dash": ["Relay Step: a skip, no hit", 1.5],
	"dredge:dash": ["Barge: 'it touches nobody' (its card)", 2.0],
	"tender:e": ["Hearthlight: heals allies, a thrown ring only heals", 3.0],
	"tender:x": ["Hearth Call: a heal tether to a teammate", 3.0]}

## Per input: `press` the input pressed (default the row's own), `hold` how long (s), `secs` the window, `again` =
## [[seconds in, input]] second presses, `aim` the cursor distance (m, default 20: past the range, so the cast
## lands at its furthest), `cross` a lane of dummies across the aim line at that distance (width of a lane or
## a cone), `ring` a ring of dummies at that radius (arc of a wall), `self` a burst round the hero (width = 2 x
## reach), `stick` a seed that sticks to the first foe and bursts there (reach = the burst radius), `shot`
## a bullet read on a clear lane (reach = flight, width = its diameter). `lane` is always read.
const DRIVERS := {
	"gunslinger:x": {"secs": 2.4},
	"mage:e": {"secs": 2.0},
	"mage:x": {"secs": 3.5, "again": [[0.9, "x"]]},
	"dolm:rmb_hold": {"secs": 3.0, "self": true},
	"dolm:x": {"secs": 4.0, "cross": 11.0},
	"dolm:dash": {"secs": 3.5, "again": [[0.3, "dash"], [0.6, "dash"]], "shot": true, "cross": 8.4},
	"ostra:e": {"secs": 8.0, "again": [[7.0, "e"]]},
	"tender:rmb": {"secs": 1.5, "shot": true},
	"archer:lmb": {"press": "lmb_hold", "hold": 0.3, "secs": 1.0, "shot": true},
	"archer:e": {"secs": 3.0, "ring": 10.8},
	"archer:x": {"secs": 3.5, "again": [[1.0, "x"], [2.1, "x"]], "cross": 6.0},
	"ashwick:lmb": {"press": "lmb_hold", "hold": 1.0, "secs": 1.6, "cross": 6.6},
	"rimewright:x": {"secs": 5.0, "self": true},
	"juggernaut:rmb": {"secs": 2.0, "cross": 2.5}}

## Rows with no input of their own in the standard list.
const EXTRA := {"tender:rmb_burst": {"press": "rmb", "secs": 3.5, "stick": true}}

## Where dummy `i` stands, relative to the hero (+X is the aim line). A burst stops hurting after about a dozen
## foes in a crowd, so a lane and a ring are read in PASSES passes, each with every PASSES-th dummy on its slot
## and the rest parked out of the way (`pick` = the pass, -1 = all).
static func slot(layout: String, i: int, ring_r: float, pick := -1) -> Vector3:
	if pick >= 0 and i % PASSES != pick: return Vector3(-6.0, 0.0, 6.0)
	match layout:
		"lane": return Vector3(LANE_FROM + i * STEP, 0.0, 0.0)
		"cross": return Vector3(ring_r, 0.0, i * STEP)
		"ring":
			var a := deg_to_rad(i * ARC_STEP)
			return Vector3(cos(a), 0.0, sin(a)) * ring_r
	return Vector3.ZERO

## {n, reach, width, arc, src, cap} for the driver of `key` (the check's dummies, hero and match are `c`).
static func measure(c: Object, a: String, kind: String, spec: Dictionary) -> Dictionary:
	var press: String = spec.get("press", kind)
	var hold: float = float(spec.get("hold", c._hold_for(press)))
	var secs: float = float(spec["secs"])
	var out := {"n": 0, "reach": 0.0, "width": 0.0, "arc": 0.0, "src": "lane", "cap": ""}
	var rd: float = c.dummies[0].hit_radius()
	var lane := _read(c, a, press, hold, secs, spec, "lane", 0.0)
	out["n"] = lane.size()
	if lane.is_empty(): return out
	if spec.get("stick", false):
		var best := 0.0
		for pk in HitShapeZero.PASSES:
			var one := _read(c, a, press, hold, secs, spec, "lane", 0.0, [pk])
			if one.is_empty(): continue
			var first: float = one.min()
			for i in one: best = maxf(best, (i - first) * STEP - rd + STEP * float(PASSES) * 0.5)
		return {"n": lane.size(), "reach": best, "width": 2.0 * best, "arc": 0.0, "src": "stick", "cap": ""}
	var far_x: float = LANE_FROM + float(lane.max()) * STEP
	var near_x: float = LANE_FROM + float(lane.min()) * STEP
	out["reach"] = maxf(0.0, far_x - rd + STEP * 0.5)
	out["width"] = maxf(0.0, far_x - near_x - 2.0 * rd + STEP)
	if far_x >= LANE_FROM + float(c.dummies.size() - 2) * STEP: out["cap"] = "r"
	if spec.get("self", false):
		out["width"] = 2.0 * float(out["reach"])
		out["src"] = "lane(self)"
	if spec.get("shot", false):
		c.layout = "grid"
		c._probe(a, press, hold, secs, true, _presses(spec))
		if not c.shot_seen.is_empty():
			var far := 0.0
			for sh in c.shot_seen: far = maxf(far, sh[0])
			out.merge({"reach": far, "width": 2.0 * float(c.shot_seen[0][1]), "src": "shot", "cap": ""}, true)
	if spec.has("cross"):
		var zs := _read(c, a, press, hold, secs, spec, "cross", float(spec["cross"]), HALF)
		if not zs.is_empty():
			out["width"] = maxf(0.0, 2.0 * (float(zs.max()) * STEP - rd + STEP * 0.5 * PASSES / HALF.size()))
			out["src"] = "shot+cross" if spec.get("shot", false) else "lane+cross"
			out["n"] = maxi(int(out["n"]), zs.size())
			if float(zs.max()) >= float(c.dummies.size() - 2): out["cap"] += "w"
	if spec.has("ring"):
		var ang := _read(c, a, press, hold, secs, spec, "ring", float(spec["ring"]), HALF)
		if not ang.is_empty():
			var half := deg_to_rad(ARC_STEP) * 0.5 * PASSES / HALF.size()
			var edge := deg_to_rad(float(ang.max()) * ARC_STEP) - rd / float(spec["ring"]) + half
			out["arc"] = rad_to_deg(maxf(0.0, edge)) * 2.0
			out["src"] = "lane+ring"
			out["n"] = maxi(int(out["n"]), ang.size())
	return out

## The slots (sorted, the biggest cluster only) that lost health with the dummies laid out as `layout`,
## read in PASSES runs (or just the runs in `passes`).
static func _read(c: Object, a: String, press: String, hold: float, secs: float, spec: Dictionary,
		layout: String, at: float, passes: Array = []) -> Array:
	var hit := {}
	c.layout = layout
	c.ring_r = at
	c.aim_d = float(spec.get("aim", 20.0))
	for pk in (passes if not passes.is_empty() else range(PASSES)):
		c.pick = pk
		for i in c._probe(a, press, hold, secs, false, _presses(spec)): hit[i] = true
	c.layout = "grid"
	c.pick = -1
	c.aim_d = 20.0
	return _biggest_cluster(hit.keys())

## The second presses of a driver, fresh (a press is marked done when made).
static func _presses(spec: Dictionary) -> Array:
	var out: Array = []
	for p in spec.get("again", []): out.append([p[0], p[1]])
	return out

static func _biggest_cluster(idx: Array) -> Array:
	idx.sort()
	var best: Array = []
	var cur: Array = []
	for i in idx:
		if not cur.is_empty() and i - cur[-1] > GAP:
			if cur.size() > best.size(): best = cur
			cur = []
		cur.append(i)
	return cur if cur.size() > best.size() else best

## The kit's JSON numbers for the driver's rows (the far edge of the footprint, its width, the arc).
static func content(c: Object, a: String, kind: String) -> Dictionary:
	var ak: Object = c.p.ak
	var key := a + ":" + kind
	var o := {"reach": 0.0, "width": 0.0, "arc": 0.0}
	match key:
		"gunslinger:x", "mage:x":
			var d: Dictionary = ak.x_def()
			o = {"reach": float(d["range"]) + float(d["radius"]), "width": 2.0 * float(d["radius"]), "arc": 0.0}
		"mage:e":
			var e: Dictionary = ak.e_def()
			o = {"reach": float(e["reach"]) + float(e["radius"]), "width": 2.0 * float(e["radius"]), "arc": 0.0}
		"dolm:rmb_hold":
			var sl: Dictionary = ak.rmb_def()["slam"]
			o = {"reach": float(sl["radius"][1]), "width": 2.0 * float(sl["radius"][1]), "arc": 0.0}
		"dolm:x":
			var x: Dictionary = ak.x_def()
			o = {"reach": float(x["range"]), "width": float(x["len"]), "arc": 0.0}
		"dolm:dash":
			var dd: Dictionary = ak.dash_def()
			var chain := float(dd["hops"]) * float(dd["dist"]) + float(dd["rock_range"])
			o = {"reach": chain, "width": 2.0 * float(dd["land_r"]), "arc": 0.0}
		"ostra:e":
			var oe: Dictionary = ak.e_def()
			o = {"reach": float(oe["reach"]) + float(oe["rmax"]), "width": 2.0 * float(oe["rmax"]), "arc": 0.0}
		"tender:rmb":
			var seed: Dictionary = ak.rmb_def()["seed"]
			o = {"reach": float(seed["range"]), "width": 2.0 * float(seed["hit_r"]), "arc": 0.0}
		"tender:rmb_burst":
			var sd: Dictionary = ak.rmb_def()["seed"]
			o = {"reach": float(sd["burst_r"]), "width": 2.0 * float(sd["burst_r"]), "arc": 0.0}
		"archer:lmb":
			o = {"reach": float(c.p.wpn["range"]), "width": 2.0 * float(c.p.wpn["size"]), "arc": 0.0}
		"archer:e":
			var he: Dictionary = ak.e_def()
			var far := float(he["reach"]) + float(he["width"]) * 0.5
			o = {"reach": far, "width": float(he["width"]), "arc": float(he["deg"])}
		"archer:x":
			var st: Dictionary = ak.x_def()
			o = {"reach": float(st["range"]), "width": float(st["width"]), "arc": 0.0}
		"ashwick:lmb":
			var hose: Dictionary = ak.lmb_def()
			o = {"reach": float(hose["range"]) + float(hose["w1"]) * 0.5, "width": float(hose["w1"]), "arc": 0.0}
		"rimewright:x":
			var rx: Dictionary = ak.x_def()
			o = {"reach": float(rx["radius"]), "width": 2.0 * float(rx["radius"]), "arc": 0.0}
		"juggernaut:rmb":
			var sm: Dictionary = ak.rmb_def()["slam"]
			o = {"reach": float(sm["len"]), "width": float(sm["width"]), "arc": 0.0}
	return o

## True when `key` hurt nobody in its proving window (a NO_DAMAGE row must stay at zero).
static func hurt_nobody(c: Object, a: String, kind: String) -> bool:
	var secs: float = float(NO_DAMAGE[a + ":" + kind][1])
	var hit := _read(c, a, kind, c._hold_for(kind), secs, {}, "lane", 0.0, HALF)
	if not hit.is_empty(): print("HSCHECK ", a, ":", kind, " hurt slots ", hit)
	return hit.is_empty()
