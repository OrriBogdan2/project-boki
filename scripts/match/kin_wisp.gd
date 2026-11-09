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
const PLATE_NEAR := 4.0       # m: a Hunter this near a wisp's own can have its plate under the wisp on screen

## The screen this frame, built once a frame for every wisp (BokiWispClear judges on screen): the view, your
## aim line, the cursor and your hit circle, and which wisps may shed sparkles (instance id -> 1).
static var _frame := -1
static var _view: BokiWispClear.View
static var _line := PackedVector2Array()
static var _yours: Array[Rect2] = []
static var _rects: Array[Rect2] = []
static var _sparkly := {}

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

## Its look on screen: riding its hunter at shoulder height on the side away from the aim, dimmed over your
## aim line, the cursor and plates, its trail short while its hunter fires (BokiWispClear). True when it drew.
static func render(k: Kin) -> bool:
	var o := k.owner_h
	if not k.wisp or k.state != "shoulder" or o == null or o.model == null:
		return false
	if k.ring:
		k.ring.visible = false
	_see(k.m)
	var sh := o.model.get_node_or_null("Rig/Torso/Shoulder") as Node3D
	var y := sh.global_position.y if sh else o.position.y + SHOULDER_Y
	var aim := o.aim_dir()
	var at := BokiWispClear.place(_view, o.position, y, aim, line_len(o), k.model, k.m.time)
	k.global_position = at
	k.model.rotation.y = atan2(-aim.x, -aim.y)      # looks where its hunter aims
	k.model.scale = Vector3.ONE
	BokiWispLook.pose(k.model, k.m.time)
	var fade := BokiWispClear.alpha(_view, at, _line, _plates(k.m, at))
	BokiWispClear.apply(k.model, fade, o.fire_cd > 0.0, _sparkly.has(k.get_instance_id()))
	return true

## How far a hunter's aim line runs (m), as Match draws it: to the cursor, or the full range for max-range guns.
static func line_len(h: Hunter) -> float:
	var aim: Vector3 = h.inp["aim"]
	var reach := float(h.wpn["range"])
	if String(h.wpn.get("aim", "")) == "max":
		return reach
	return minf(Vector2(aim.x - h.pos.x, aim.z - h.pos.z).length(), reach)

## Builds this frame's screen once (see _frame).
static func _see(m: Node) -> void:
	if _frame == Engine.get_process_frames():
		return
	_frame = Engine.get_process_frames()
	var cam: Camera3D = m.cam
	_view = BokiWispClear.View.new(cam.global_transform, cam.fov, cam.get_viewport().get_visible_rect().size)
	_line = PackedVector2Array()
	_yours.clear()
	var p: Hunter = m.player
	if p:
		_yours.append(BokiWispClear.ground_rect(_view, p.position, BokiWispClear.HIT_R))
		if not p.out and not p.downed and not p.extracted:
			_line = BokiWispClear.aim_line(_view, p.position, p.aim_dir(), line_len(p))
			_yours.append(BokiWispClear.cursor_rect(_view.px(p.inp["aim"])))
	var wisps: Array = m.kins.filter(func(x: Kin): return x.wisp and x.state == "shoulder")
	var dists := PackedFloat32Array()
	for w: Kin in wisps:
		dists.append(w.pos.distance_to(p.pos) if p else 0.0)
	var on := BokiWispClear.sparkly(dists)
	_sparkly.clear()
	for i in wisps.size():
		if on[i]:
			_sparkly[wisps[i].get_instance_id()] = 1

## Yours (cursor, hit circle) plus the plates of the hunters near this wisp, as screen rects.
static func _plates(m: Node, at: Vector3) -> Array[Rect2]:
	_rects.assign(_yours)
	for h: Hunter in m.hunters:
		if not h.out and not h.extracted and Vector2(h.pos.x - at.x, h.pos.z - at.z).length() < PLATE_NEAR:
			_rects.append(BokiWispClear.plate_rect(_view, h.position, HudPlate.plate_offset(h)))
	return _rects
