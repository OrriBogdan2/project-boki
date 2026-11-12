class_name KinWisp
extends RefCounted
## The Boki wisp prototype (DECISIONS 2026-11-09, docs/decisions/0038-boki-wisp-proto.md): with the
## "boki_wisps" setting on, a hunter's Boki rides as a small wisp (BokiWispLook) orbiting them at shoulder
## height instead of walking beside them. It is carried by order the whole time, so its carry passives are
## always on; it takes no orders, throws or hits, and its AI (KinTactics, KinCompanion, the walking state
## machine) does not tick. When it is left behind (its hunter goes out in a risky match) it turns back into
## the walking Boki and the old rules run. The summon out of the wisp: KinSummon; stealing: KinSteal. The ult
## waits on WISP_DESIGN_OPEN.md.
## Online: the kin snapshot carries the flag (KinNet), so other games show the wisp too.

const SHOULDER_Y := 1.45      # m above the hunter's feet when their rig has no shoulder bone
const SUMMON_KEY := KEY_F8    # debug builds: burst the own Boki out of its wisp, and again to fold it back

static var _key_held := false

## Do this match's own Boki ride as wisps? The match opts win (a bench or check sets them), then the
## setting. Never in the tutorial: it teaches the walking Boki's orders.
static func mode(m: Node) -> bool:
	var o = m.get("opts")
	if not o is Dictionary or m.get("tut") != null:
		return false
	return bool((o as Dictionary).get("boki_wisps", Settings.get_v("boki_wisps")))

## Its model: the wisp look while a wisp, else the walking Boki.
static func look(k: Kin) -> Node3D:
	if not k.wisp:
		return Models.kin(k.species, k.rec)
	return BokiWispLook.build(k.species, k.rec, BokiWispCosmetics.worn(k.owner_h))

## Turn it into a wisp or back (a snapshot, or a wisp left behind), swapping the model once.
static func set_wisp(k: Kin, on: bool) -> void:
	if k.wisp == on:
		return
	k.wisp = on
	var pop := k.get_node_or_null("Pop")
	if pop:
		pop.free()
	k.remove_meta("xr")        # (the walking model's x-ray shell is set up again on the new model)
	if k.model:
		k.remove_child(k.model)       # (out of the tree now, so the new model keeps its name; set_model frees it)
	k.set_model(look(k))
	if k.summon:
		k.summon.popped(on)

## A merge ended (KinMerge.end): the Boki is a wisp on its hunter's shoulder again, its summon cooldown as it was.
static func rewisp(k: Kin) -> void:
	set_wisp(k, true)
	k.stow()
	k.scale = Vector3.ONE

## The step of a wisp's body. True when it handled it (the caller skips the walking state machine and the AI).
static func ride(k: Kin, dt: float) -> bool:
	if not k.wisp:
		return false
	if KinSteal.ride(k, dt):
		return true
	if k.owner_h == null or KinLoss.guarding(k) or k.state == "dazed":
		set_wisp(k, false)          # left behind: the walking Boki's rules from here
		return false
	if k.state in ["away", "bench", "fused", KinWispForm.STATE]:
		return false          # (the Hunter-down wisp form is KinWispForm's)
	if not k.remote and (k.state != "shoulder" or k.cmd != "return"):
		k.stow()
	if k.state != "shoulder":
		return false
	_summon_key(k)
	k.pos = k.owner_h.pos + Vector3(0, 1.5, 0)
	k.prev = k.pos
	return true

## Its look on screen: orbiting its hunter at shoulder height on its carry slot (CarryWisps: the lead, the second
## in the satchel, a stolen one), facing along the orbit, hopping. True when it drew.
static func render(k: Kin) -> bool:
	if k.summon:
		k.summon.render()
	if k.wisp and KinSteal.loose(k) and k.model:
		CarryWisps.plain(k)
		KinSteal.render(k)
		return true
	var o := k.owner_h
	if CarryWisps.role(k) == "" or o.model == null:
		return false
	if k.ring:
		k.ring.visible = false
	var sh := o.model.get_node_or_null("Rig/Torso/Shoulder") as Node3D
	var y := sh.global_position.y if sh else o.position.y + SHOULDER_Y
	CarryWisps.place(k, o, y, BokiWispCosmetics.worn(o)["orbit"])      # its carry slot's spot and look
	if k.summon and k.summon.fly > 0.0:
		k.global_position = k.summon.streak(k.global_position)
		k.m.fx.burst(k.global_position, k.sp.get("glow", k.sp["color"]), 1, 0.4)
	BokiWispLook.pose(k.model, k.m.time)
	return true

## Where a wisp is at orbit angle a (rad) round a hunter standing at `centre`, its shoulder `y` high. The orbit
## style (BokiWispCosmetics) gives the radius in metres, a constant rise and a wave of `waves` dips a lap.
static func orbit_spot(orbit: Dictionary, a: float, centre: Vector3, y: float) -> Vector3:
	var r: float = orbit["radius"]
	var lift: float = float(orbit["rise"]) + float(orbit["wave"]) * sin(a * int(orbit["waves"]))
	return Vector3(centre.x + cos(a) * r, y + lift, centre.z + sin(a) * r)

## Debug (F8 in a debug build): the player's own Boki bursts out of its wisp (BokiWispPop), and folds back on
## the next press. It stands on the ground under its orbit spot; the summon itself waits on WISP_DESIGN_OPEN.md.
static func _summon_key(k: Kin) -> void:
	if not OS.is_debug_build() or k.remote or k.owner_h != k.m.player:
		return
	var down := Input.is_physical_key_pressed(SUMMON_KEY)
	var pressed := down and not _key_held
	_key_held = down
	if not pressed:
		return
	var pop := k.get_node_or_null("Pop") as BokiWispPop
	if pop == null:
		pop = BokiWispPop.new(k.species, k.rec)
		pop.name = "Pop"
		pop.finished.connect(_summoned.bind(k))
		k.add_child(pop)
		k.model.visible = false
	pop.stand = Vector3(0, k.owner_h.position.y - k.global_position.y, 0)
	pop.rotation.y = k.model.rotation.y
	pop.play(not pop.out)

## The fold ended: the plain wisp takes over again.
static func _summoned(out: bool, k: Kin) -> void:
	if not out:
		var pop := k.get_node("Pop")
		k.remove_child(pop)
		pop.queue_free()
		k.model.visible = true
