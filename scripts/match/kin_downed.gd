class_name KinDowned
extends RefCounted
## A downed Boki (docs/decisions/0001), replacing the old 8s faint and teleport:
##   - it stays where it fell, marked on screen and the minimap (BokiHud) and glowing in your team colour
##   - its owner rescues it by running into it (no key): a 3.5s rescue (rescue_s). The hunter kneels, picks it up and
##     cradles it, rooted and unable to attack, with a rising sound and a progress ring over it, like a support
##     picking up a fallen ally's wisp. A dash cancels it; hard crowd control interrupts it (stun, root, Grounded, a launch or
##     a real knock: Capture.controlled, the same rule as the capture scan; damage and the small shove of most hits do not);
##     the progress then drains back over rescue_drain_s instead of resetting. An enemy hunter standing on the Boki
##     (within contest_r) blocks the pick-up and pauses the progress ("Contested"). At the end it is back on the shoulder
##     with rescue_hp of its health. Nobody else can rescue it: it can't be hurt, scanned or taken
##     while the owner is still in the map (a hunter who goes out leaves it behind as before, Match._leave_one_kin)
##   - otherwise it comes round on its own after 15-20s (trusting Boki sooner) at low health (recover_hp)
##   - a Boki that fell into the abyss can only come round on the timer
##   - while down: no C, no Merge, no carry passives (Kin.ready_to_fight, KinMerge.boki_with_you)
## Numbers: content/rules/boki_system.json "down". State lives on the Kin: down_t, down_total, rescue_t, down_void.

static func rules() -> Dictionary:
	return KinCommand.rules()["down"]

## The Boki went down at its current spot (fell: into the abyss, at the last solid ground it stood on).
static func begin(k: Kin, fell: bool) -> void:
	var r := rules()
	k.state = "downed"
	k.hp = 0.0
	k.target = null
	k.fly = {}
	k.hold_at = Vector3.INF
	k.pend_skill = Vector3.INF
	k.pend_slot = ""
	k.vel = Vector3.ZERO
	k.down_total = lerpf(float(r["recover_s_wary"]), float(r["recover_s_trusting"]), clampf(k.trust / 100.0, 0.0, 1.0))
	k.down_t = k.down_total
	k.rescue_t = 0.0
	k.rescue_on = false
	k.rescue_block = 0.0
	k.down_void = fell
	if fell:
		k.teleport(k.last_safe if k.last_safe != Vector3.INF else (k.owner_h.pos if k.owner_h else k.pos))
	k.m.fx.burst(k.pos + Vector3(0, 0.4, 0), k.sp["color"], 16, 3.0)

## Can the owner scoop it up right now?
static func rescuable(k: Kin) -> bool:
	var h := k.owner_h
	return k.state == "downed" and not k.down_void and h != null and not h.out and not h.extracted and not h.downed and not h.riding and not h.dropping

static func tick(k: Kin, dt: float) -> void:
	var r := rules()
	if not k.down_void:
		k.body_vertical(dt)
	var h := k.owner_h
	if h == null or h.out or h.extracted:
		return
	_rescue(k, h, r, dt)
	if k.state != "downed":
		return                           # (rescued this step)
	k.down_t -= dt
	if k.down_t <= 0.0:
		come_round(k, false)

# ------------------------------------------------------------------ the rescue
static func _near(k: Kin, h: Hunter, reach: float) -> bool:
	return k.flat_dist(h) < reach and absf(h.pos.y - k.pos.y) < 2.2

## Why a running rescue stops ("" = it goes on): "dash" (your choice), "cc" (crowd control, or knocked away), "gone".
static func stop_reason(k: Kin, h: Hunter, r: Dictionary) -> String:
	if not rescuable(k):
		return "gone"
	var own := Capture.hunter_stop(h)
	if own == "dash":
		return "dash"
	if own != "" or not h.grounded or h.gliding or not _near(k, h, float(r["rescue_r"]) + float(r["rescue_slack"])):
		return "cc"
	return ""

## Is an enemy hunter standing on it? You can't pick it up while they are.
static func contested(k: Kin) -> bool:
	if k.state != "downed":
		return false
	var cr := float(rules()["contest_r"])
	for e in k.m.hunters:
		if e.team != k.team and not e.out and not e.downed and not e.dead and k.flat_dist(e) <= cr and absf(e.pos.y - k.pos.y) < 2.2:
			return true
	return false

static func _rescue(k: Kin, h: Hunter, r: Dictionary, dt: float) -> void:
	var need := float(r["rescue_s"])
	if k.rescue_on:
		var why := stop_reason(k, h, r)
		if why != "":
			stop(k, h, why)
			return
		if contested(k):
			return                       # (they stand on it: the progress waits, nothing drains)
		k.rescue_t += dt
		_rescue_fx(k, h, r, dt)
		if k.rescue_t >= need:
			k.rescue_on = false
			h.set_meta("rescue_done_at", k.m.time)
			rescue(k)
		return
	# not rescuing: the progress drains back, and running into it (again) starts it
	k.rescue_block = maxf(0.0, k.rescue_block - dt)
	if k.rescue_t > 0.0:
		k.rescue_t = maxf(0.0, k.rescue_t - dt * need / float(r["rescue_drain_s"]))
	if k.rescue_block <= 0.0 and rescuable(k) and _near(k, h, float(r["rescue_r"])) and stop_reason(k, h, r) == "" and not contested(k):
		k.rescue_on = true
		h.set_meta("rescue_at", k.m.time)
		k.m.sfx("revive_hum", k.pos, -8.0, 1.0)

static func stop(k: Kin, h: Hunter, why: String) -> void:
	k.rescue_on = false
	if why == "dash":
		k.rescue_block = float(rules()["rescue_block_s"])
	if why in ["dash", "cc"]:
		k.m.sfx("kin_unsure", k.pos, -6.0)
		if h.is_local() and k.m.hud:
			k.m.hud.toast_small("Rescue cancelled: run into it to try again" if why == "dash" else "Rescue interrupted: run into it to try again", Color("ffd89a"))

## Hunter._tick: while you rescue you are rooted and can't attack (a dash still cancels it).
static func commit(h: Hunter) -> void:
	var k: Kin = h.kin
	if k == null or not k.rescue_on or k.state != "downed":
		return
	h.inp["move"] = Vector2.ZERO
	for key in ["fire", "jump", "glide", "sig", "sec", "skill", "ult", "kin_ab", "gear1", "gear2", "throw", "reload", "tonic", "kit", "swap"]:
		h.inp[key] = false

## A rising tick while it fills, and a ring that closes round the Boki (the HUD draws the ring from rescue_t).
static func _rescue_fx(k: Kin, h: Hunter, r: Dictionary, dt: float) -> void:
	var f := scoop_k(k)
	var t := float(h.get_meta("rescue_tick", 0.0)) - dt
	if t <= 0.0:
		t = 0.3
		k.m.sfx("heal", k.pos, -12.0, 0.8 + 0.9 * f)
		k.m.fx.burst(k.pos + Vector3(0, 0.5 + 0.6 * f, 0), Color(k.sp.get("glow", k.sp["color"])), 3, 1.5, 0.4, -1.0, 0.7)
	h.set_meta("rescue_tick", t)

## "rs_kneel" / "rs_cradle" while rescuing, "rs_done" for a moment after: the pose id for HunterAnim (and the net snapshot).
static func rescue_pose(h: Hunter) -> String:
	var k: Kin = h.kin
	if k != null and k.rescue_on:
		return "rs_kneel" if scoop_k(k) < float(rules()["rescue_kneel_frac"]) else "rs_cradle"
	if h.m.time - float(h.get_meta("rescue_done_at", -9.0)) < float(rules()["rescue_done_s"]):
		return "rs_done"
	return ""

## Hunter._anim_state: the rescue's keyed pose (other games read the id the owner syncs).
static func anim_state(h: Hunter, s: Dictionary) -> void:
	var id := ""
	var t := 0.0
	if h.remote:
		id = String(h.get_meta("kpose", ""))
		t = h.m.time - float(h.get_meta("kpose_at", -9.0))
	else:
		id = rescue_pose(h)
		var k: Kin = h.kin
		if id == "rs_kneel" and k != null:
			t = h.m.time - float(h.get_meta("rescue_at", h.m.time))
		elif id == "rs_cradle" and k != null:
			t = k.rescue_t - float(rules()["rescue_kneel_frac"]) * float(rules()["rescue_s"])
		elif id == "rs_done":
			t = h.m.time - float(h.get_meta("rescue_done_at", h.m.time))
	if id.begins_with("rs_"):
		s["kmove"] = id
		s["kmove_t"] = t
	elif String(s.get("kmove", "")).begins_with("rs_"):
		s.erase("kmove")
		s.erase("kmove_t")

## Back on your feet with a share of health: rescued (run into it) or recovered on its own.
static func come_round(k: Kin, rescued: bool) -> void:
	var r := rules()
	k.hp = k.max_hp * float(r["rescue_hp"] if rescued else r["recover_hp"])
	k.down_t = 0.0
	k.rescue_t = 0.0
	k.rescue_on = false          # (its own recovery can fire mid-rescue: the rescuer is free again)
	k.rescue_block = 0.0
	k.down_void = false
	var from := k.pos
	k._hop_on()
	k.m.fx.burst(k.owner_h.pos + Vector3(0, 1.5, 0), k.sp["color"], 12 if rescued else 8, 2.5)
	k.m.fx.ring(from, 1.2, Color(k.sp["color"], 0.8), 0.3)
	k.m.sfx("recall", k.owner_h.pos, -4.0)
	if rescued:
		k.note("rescued", "you ran in and carried it out", 1.5)
		k.bark("revive")
	k.m.on_kin_up(k, rescued)

static func rescue(k: Kin) -> void:
	k.m.fx.flash(k.pos + Vector3(0, 0.8, 0), Color.WHITE, 1.2, 0.1)           # the finish pop
	k.m.fx.ring(k.pos, 2.0, Color(k.sp.get("glow", k.sp["color"]), 0.9), 0.4)
	k.m.sfx("revive_done", k.pos, -2.0)
	come_round(k, true)

## 0..1 while it is being scooped (the render lifts it toward you).
static func scoop_k(k: Kin) -> float:
	return clampf(k.rescue_t / maxf(0.01, float(rules()["rescue_s"])), 0.0, 1.0)

# ------------------------------------------------------------------ how it shows
const BEACON_H := 3.2     # m: the marker pillar over a downed Boki

## The marker over a downed Boki: a pillar in your team colour that your squad can see from afar.
## (Its screen label and the minimap dot are BokiHud.)
static func render(k: Kin, _delta: float) -> void:
	var show: bool = k.state == "downed" and k.owner_h != null and not k.unseen and k.m.player != null and k.owner_h.team == k.m.player.team
	if show and k.beacon == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12; cm.bottom_radius = 0.5; cm.height = BEACON_H; cm.radial_segments = 12
		mi.mesh = cm
		mi.material_override = Models.aura_mat(Color(k.sp.get("glow", k.sp["color"])), 0.8)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		k.add_child(mi)
		k.beacon = mi
	if k.beacon:
		k.beacon.visible = show
		if show:
			var g: float = k.m.world.ground_at(k.pos.x, k.pos.z)
			k.beacon.global_position = Vector3(k.pos.x, (g if g > World.VOID + 1.0 else k.pos.y) + BEACON_H * 0.5, k.pos.z)
			k.beacon.scale = Vector3(1.0 + 0.12 * sin(k.m.time * 5.0), 1.0, 1.0 + 0.12 * sin(k.m.time * 5.0))

## The rescue: it stays low while the hunter kneels, then is lifted into their arms and cradled there.
static func scoop_pose(k: Kin) -> void:
	if k.state != "downed" or k.rescue_t <= 0.0 or k.owner_h == null or k.model == null:
		return
	var h := k.owner_h
	var f := scoop_k(k)
	var e := smoothstep(float(rules()["rescue_kneel_frac"]), 0.6, f)
	var arms := h.global_position + Vector3(-sin(h.face) * 0.42, 0.9 + 0.04 * sin(k.m.time * 4.0), -cos(h.face) * 0.42)
	k.global_position = k.global_position.lerp(arms, e)
	k.model.scale *= lerpf(1.0, 0.7, e)
