class_name KinWisp
extends RefCounted
## The Boki wisp prototype (DECISIONS 2026-11-09, docs/decisions/0038-boki-wisp-proto.md): with the
## "boki_wisps" setting on, a hunter's Boki rides as a small wisp (BokiWispLook) orbiting them at shoulder
## height instead of walking beside them. It is carried by order the whole time, so its carry passives are
## always on; it takes no orders, throws or hits, and its AI (KinTactics, KinCompanion, the walking state
## machine) does not tick. When it is left behind (its hunter goes out in a risky match) it turns back into
## the walking Boki and the old rules run. Summon, steal and the ult wait on WISP_DESIGN_OPEN.md.
## Online: the kin snapshot carries the flag (KinNet), so other games show the wisp too.

const SHOULDER_Y := 1.45      # m above the hunter's feet when their rig has no shoulder bone
const ORBIT_R := 0.6          # m from the hunter's middle
const ORBIT_HZ := 0.35        # laps per second: quick enough to read as alive, slow enough to read as a shape

## Do this match's own Boki ride as wisps? The match opts win (a bench or check sets them), then the
## setting. Never in the tutorial: it teaches the walking Boki's orders.
static func mode(m: Node) -> bool:
	var o = m.get("opts")
	if not o is Dictionary or m.get("tut") != null:
		return false
	return bool((o as Dictionary).get("boki_wisps", Settings.get_v("boki_wisps")))

## Its model: the wisp look while a wisp, else the walking Boki.
static func look(k: Kin) -> Node3D:
	return BokiWispLook.build(k.species, k.rec) if k.wisp else Models.kin(k.species, k.rec)

## Turn it into a wisp or back (a snapshot, or a wisp left behind), swapping the model once.
static func set_wisp(k: Kin, on: bool) -> void:
	if k.wisp == on:
		return
	k.wisp = on
	k.remove_meta("xr")        # (the walking model's x-ray shell is set up again on the new model)
	if k.model:
		k.remove_child(k.model)       # (out of the tree now, so the new model keeps its name; set_model frees it)
	k.set_model(look(k))

## The step of a wisp's body. True when it handled it (the caller skips the walking state machine and the AI).
static func ride(k: Kin) -> bool:
	if not k.wisp:
		return false
	if k.owner_h == null or KinLoss.guarding(k) or k.state == "dazed":
		set_wisp(k, false)          # left behind: the walking Boki's rules from here
		return false
	if k.state in ["away", "bench", "fused"]:
		return false
	if not k.remote and (k.state != "shoulder" or k.cmd != "return"):
		k.stow()
	if k.state != "shoulder":
		return false
	k.pos = k.owner_h.pos + Vector3(0, 1.5, 0)
	k.prev = k.pos
	return true

## Its look on screen: orbiting its hunter at shoulder height, facing along the orbit, hopping. True when it drew.
static func render(k: Kin) -> bool:
	var o := k.owner_h
	if not k.wisp or k.state != "shoulder" or o == null or o.model == null:
		return false
	if k.ring:
		k.ring.visible = false
	var sh := o.model.get_node_or_null("Rig/Torso/Shoulder") as Node3D
	var y := sh.global_position.y if sh else o.position.y + SHOULDER_Y
	var a: float = TAU * (k.m.time * ORBIT_HZ + float(k.model.get_meta("phase", 0.0)))
	k.global_position = Vector3(o.position.x + cos(a) * ORBIT_R, y, o.position.z + sin(a) * ORBIT_R)
	k.model.rotation.y = atan2(sin(a), -cos(a))
	k.model.scale = Vector3.ONE
	BokiWispLook.pose(k.model, k.m.time)
	return true
