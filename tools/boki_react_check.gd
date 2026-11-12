extends RefCounted
## --boki-react-check: a Boki visibly reacts when it is hit (KinFlinch, driven by KinPuppet and BokiRig).
## Per body plan (quad, biped, flyer, serpent, blob, on the primitive bodies, at each weight) and per rigged
## species (art/kin), it hits the model the way Oomph.react does and steps its drivers by hand:
##  - the farther of body and head has moved at least MIN_READ of its height within READ_T of the hit;
##  - a bigger hit moves it farther than a chip hit;
##  - the jolt is back under a quarter of its peak inside the window for its weight (light snaps back, heavy
##    carries the hit);
##  - no part detaches (parts and bones stay put in Flex space) and Flex never squashes out of shape.
## Then in a real match, owned, rival and wild Boki each get the "hit" meta from Ent.hurt, and a burn tick does not.
## Prints BOKIREACT PASS/FAIL lines. No renderer.

const READ_T := 0.1          # s: a hit must read by then
const MIN_READ := 0.03       # share of the Boki's height its farthest point has moved by READ_T
const SETTLED := 0.25        # the jolt is over when it is back under this share of its peak
const RUN_S := 1.2           # s followed after a hit
const STEP := 1.0 / 60.0
const MAX_PART := 0.2        # share of height a part or bone may leave its place in Flex space
const MIN_SCALE := 0.65      # Flex stays inside these scales
const MAX_SCALE := 1.35
const CHIP := 0.05           # share of max health: a chip hit, and a big one
const BIG := 0.35
## Settle time a Boki of each weight should show (s). Light under mass 1.0, medium under 1.6, then heavy.
const WEIGHT := {"light": [0.14, 0.30], "medium": [0.18, 0.38], "heavy": [0.24, 0.45]}
const MASS := {"light": 0.8, "medium": 1.3, "heavy": 2.0}
## One primitive-bodied species per plan (the rigged models are tried one by one below).
const PLANS := {"quad": "cindle", "biped": "zapple", "flyer": "wisplet", "serpent": "zephyrak", "blob": "basaltoad"}

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("BOKIREACT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	BokiRig.enabled = false
	for plan in PLANS:
		for weight in MASS:
			await _case(main, "%s %s" % [plan, weight], String(PLANS[plan]), weight, float(MASS[weight]))
	BokiRig.enabled = true
	for id in boki_species():
		var mass := KinLib.kin(id).mass
		await _case(main, "rigged %s" % id, id, weight_of(mass), mass)
	await _in_match(main)
	print("BOKIREACT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func weight_of(mass: float) -> String:
	if mass < 1.0:
		return "light"
	return "medium" if mass < 1.6 else "heavy"

## Every species with a rigged model.
func boki_species() -> Array:
	var ids := []
	for id in BokiRig.FRAME:
		if BokiRig.has(id):
			ids.append(id)
	ids.sort()
	return ids

## One model with its drivers, stepped by hand.
class Subject:
	var k: Node3D
	var pup: KinPuppet
	var rig: BokiRig
	var flex: Node3D

	func _init(species: String, holder: Node3D) -> void:
		k = Models.kin(species, {})
		holder.add_child(k)
		for c in k.get_children():
			if c is KinPuppet:
				pup = c
		rig = k.get_node_or_null("Body/Flex/BokiRig") as BokiRig
		flex = k.get_node("Body/Flex") as Node3D
		pup.set_process(false)
		if rig:
			rig.set_process(false)

	func step() -> void:
		pup._process(STEP)
		if rig:
			rig.player.advance(STEP)
			rig._process(STEP)

	## Flex-space spot of every part (primitive bodies) or bone (rigged).
	func places() -> Array:
		var out := []
		var inv := flex.global_transform.affine_inverse()
		if rig:
			var sk := rig.skeleton()
			for i in sk.get_bone_count():
				out.append((inv * sk.global_transform * sk.get_bone_global_pose(i)).origin)
		else:
			for mi in flex.find_children("*", "MeshInstance3D", true, false):
				out.append(inv * (mi as Node3D).global_position)
		return out

	## The model's bounds in Flex space.
	func box() -> AABB:
		var bb := AABB()
		var first := true
		var inv := flex.global_transform.affine_inverse()
		for mi in flex.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).contains("Shadow"):
				continue
			var b := inv * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		return bb

func _case(main: Node, label: String, species: String, weight: String, mass: float) -> void:
	var a := Subject.new(species, holder)
	var ctl := Subject.new(species, holder)       # the same Boki left alone: its idle motion is not the hit's
	await main.get_tree().process_frame
	ctl.pup.phase = a.pup.phase
	ok((a.rig != null) == BokiRig.enabled, "%s: %s body" % [label, "rigged" if a.rig else "primitive"])
	var box := a.box()
	var chip := _hit(a, ctl, box, Vector3(0, 0, 1), CHIP, mass)
	var big := _hit(a, ctl, box, Vector3(1, 0, 0), BIG, mass)
	var band: Array = WEIGHT[weight]
	print("BOKIREACT %-18s h %.2f m mass %.1f | chip %.3f %.2f s | big %.3f %.2f s | part %.3f" % [
		label, box.size.y, mass, chip["read"], chip["settle"], big["read"], big["settle"],
		maxf(chip["part"], big["part"])])
	ok(chip["read"] >= MIN_READ, "%s: a chip hit moves %.3f of its height by %.1f s" % [label, chip["read"], READ_T])
	ok(big["read"] >= MIN_READ, "%s: a big hit moves %.3f of its height by %.1f s" % [label, big["read"], READ_T])
	ok(big["peak"] > chip["peak"], "%s: a big hit moves farther (%.3f vs %.3f m)" % [label, big["peak"], chip["peak"]])
	for r in [chip, big]:
		var in_band: bool = r["settle"] >= band[0] and r["settle"] <= band[1]
		ok(in_band, "%s: settles in %.2f s (%s: %.2f to %.2f)" % [label, r["settle"], weight, band[0], band[1]])
		ok(r["part"] <= MAX_PART, "%s: no part detaches (worst %.3f of height)" % [label, r["part"]])
		var shaped: bool = r["scale_lo"] >= MIN_SCALE and r["scale_hi"] <= MAX_SCALE
		ok(shaped, "%s: Flex stays in shape (scale %.2f to %.2f)" % [label, r["scale_lo"], r["scale_hi"]])
	a.k.queue_free()
	ctl.k.queue_free()

## One hit on a resting model `a`, followed for RUN_S against `ctl`. Returns read (share of height at READ_T), peak (m),
## settle (s), part (worst share of height a part or bone left its place) and Flex's scale range.
func _hit(a: Subject, ctl: Subject, box: AABB, push: Vector3, frac: float, mass: float) -> Dictionary:
	for i in 90:
		a.step()
		ctl.step()
	var body := Vector3(box.get_center().x, box.position.y + box.size.y * 0.4, box.get_center().z)
	var head := Vector3(box.get_center().x, box.end.y - box.size.y * 0.1, box.position.z + box.size.z * 0.15)
	KinFlinch.hit(a.k, push, frac, mass)
	var r := {"read": 0.0, "peak": 0.0, "settle": 0.0, "part": 0.0, "scale_lo": 9.0, "scale_hi": 0.0}
	var series := []
	for i in int(RUN_S / STEP):
		a.step()
		ctl.step()
		var t := (i + 1) * STEP
		var d := maxf(_gap(a, ctl, body), _gap(a, ctl, head))
		series.append([t, d])
		r["peak"] = maxf(r["peak"], d)
		if t <= READ_T + 0.0001:
			r["read"] = maxf(r["read"], d / box.size.y)
		var pa := a.places()
		var pc := ctl.places()
		for j in pa.size():
			r["part"] = maxf(r["part"], (pa[j] as Vector3).distance_to(pc[j]) / box.size.y)
		for c in 3:
			r["scale_lo"] = minf(r["scale_lo"], a.flex.scale[c])
			r["scale_hi"] = maxf(r["scale_hi"], a.flex.scale[c])
	for s in series:
		if float(s[1]) > SETTLED * r["peak"]:
			r["settle"] = float(s[0])
	return r

## How far apart a spot on the hit model and the same spot on the control are, in the world.
func _gap(a: Subject, ctl: Subject, spot: Vector3) -> float:
	return a.flex.to_global(spot).distance_to(ctl.flex.to_global(spot))

# ------------------------------------------------------------------ in a match
## Owned, rival and wild Boki take the hit through Ent.hurt; a burn tick is not a hit.
func _in_match(main: Node) -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var p: Hunter = m.player
	var foe: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != p and o.team != p.team and foe == null:
			foe = o
	var wild := m.spawn_wild(Save.new_kin("puddlet", "Wob"), p.pos + Vector3(6, 0, 0), false)
	var targets := {"owned": p.kin, "rival": foe.kin, "wild": wild}
	for who in targets:
		var k: Kin = targets[who]
		ok(k != null and k.model != null, "match: a %s Boki exists" % who)
		if k == null or k.model == null:
			continue
		var before := _count(k)
		k.hurt(3.0, p if who == "wild" else foe, {})
		ok(_count(k) == before + 1, "match: a %s Boki flinches when hurt" % who)
		k.hurt(2.0, p, {"src": "burn", "tick": true})
		ok(_count(k) == before + 1, "match: a burn tick on a %s Boki is not a hit" % who)
	m.queue_free()

func _count(k: Kin) -> int:
	return int((k.model.get_meta("hit", {"n": 0}) as Dictionary)["n"])
