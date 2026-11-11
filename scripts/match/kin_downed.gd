class_name KinDowned
extends RefCounted
## A downed Boki (docs/decisions/0001), replacing the old 8s faint and teleport:
##   - it stays where it fell, marked on screen and the minimap (BokiHud) and glowing in your team colour
##   - its owner rescues it by running into it (no key): a 3.5s rescue (rescue_s). The hunter picks it up into their
##     arms and carries it while the progress fills, walking at carry_speed_k of normal speed (as a support picks up a
##     fallen ally's wisp), with a rising sound and a progress ring over it. While carrying, dash, jump, glide, firing
##     and every ability are off (blocked, not cancelling). Dash (Shift) or interact (F) puts it down on purpose where
##     you stand (the press is spent on the drop: no dash happens), and it will not be picked up again until you step
##     away or press interact. Running into it picks it up only with no foe within ENEMY_NEAR (else press interact),
##     and not in the middle of a scan, a box revive, a drink/kit/base channel or while carrying a teammate. Hard crowd control (stun, root, Grounded, a launch or a real
##     knock: Capture.controlled, the same rule as the capture scan) drops it: it falls back down, still downed, and the
##     progress is lost. Damage and the small shove of most hits do not. An enemy hunter within contest_r of the Boki
##     blocks the pick-up and pauses the progress ("Contested"). At the end it is back on the shoulder
##     with rescue_hp of its health. Nobody else can rescue it: it can't be hurt, scanned or taken
##     while the owner is still in the map (a hunter who goes out leaves it guarding where it stands, KinLoss)
##   - otherwise it comes round on its own after 15-20s (trusting Boki sooner) at low health (recover_hp)
##   - a Boki that fell into the abyss can only come round on the timer
##   - while down: no C, no Merge, no carry passives (Kin.ready_to_fight, KinMerge.boki_with_you)
## Numbers: content/rules/boki_system.json "down". State lives on the Kin: down_t, down_total, rescue_t, down_void.

const ARMS_FWD := 0.42    # m: how far in front of the carrier the Boki rides
const ARMS_UP := 0.9      # m: the height of the arms above the carrier's feet
const LEAVE_META := "leave"   # on a Boki put down on purpose: no automatic pick-up until the owner steps away
const ENEMY_NEAR := 6.0   # m: with a foe this close, running into the Boki does not pick it up (press interact)
const F_EDGE_S := 0.1     # s: an interact press this recent counts as a fresh press
const BLOCKED_INPUTS := ["jump", "glide", "fire", "sig", "sec", "sec_hold", "skill", "ult", "kin_ab", "gear1", "gear2",
	"throw", "tonic", "kit", "swap", "dash_down"]    # off while carrying (movement and aim stay)

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
	return ((k.state == "downed" and not k.down_void) or KinLoss.guarding(k)) and h != null and not h.out and not h.extracted and not h.downed and not h.riding and not h.dropping

static func tick(k: Kin, dt: float) -> void:
	var r := rules()
	if not k.down_void:
		k.body_vertical(dt)
	var h := k.owner_h
	if h == null or h.out or h.extracted:
		k.rescue_on = false
		k.rescue_t = 0.0
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

## Why a running rescue stops ("" = it goes on): "cc" (crowd control or a launch drops it), "gone" (the Boki or its owner can't).
static func stop_reason(k: Kin, h: Hunter) -> String:
	if not rescuable(k):
		return "gone"
	if Capture.controlled(h) or h.roll_t > 0.0 or h.gliding:
		return "cc"
	return ""

## Is an enemy hunter standing on it? You can't pick it up while they are.
static func contested(k: Kin) -> bool:
	if k.state != "downed" and not KinLoss.guarding(k):
		return false
	var cr := float(rules()["contest_r"])
	for e in k.m.hunters:
		if e.team != k.team and not e.out and not e.downed and not e.dead and k.flat_dist(e) <= cr and absf(e.pos.y - k.pos.y) < 2.2:
			return true
	return false

## A guarding Boki (KinLoss) runs the same cradle while it waits.
static func step_rescue(k: Kin, h: Hunter, dt: float) -> void:
	_rescue(k, h, rules(), dt)

static func _rescue(k: Kin, h: Hunter, r: Dictionary, dt: float) -> void:
	if k.rescue_on:
		var why := stop_reason(k, h)
		if why != "":
			stop(k, h, why)
			return
		_carry(k, h)
		# the rising hum lasts while the carry does: it stops by itself once these calls do (Sfx.loop_hold)
		Sfx.loop_hold("rescue%d" % k.get_instance_id(), "revive_hum", k.pos, -8.0, 0.8 + 0.55 * scoop_k(k))
		if contested(k):
			return                       # (they are on you: the progress waits)
		k.rescue_t += dt
		_rescue_fx(k, h, dt)
		if k.rescue_t >= float(r["rescue_s"]):
			k.rescue_on = false
			h.set_meta("rescue_done_at", k.m.time)
			rescue(k)
		return
	k.rescue_block = maxf(0.0, k.rescue_block - dt)
	if k.has_meta(LEAVE_META) and not _near(k, h, float(r["rescue_r"]) * 1.5):
		k.remove_meta(LEAVE_META)
	if _can_start(k, h, r):
		k.rescue_on = true
		h.set_meta("carry", k)
		h.set_meta("rescue_at", k.m.time)
		h.set_meta("f_edge_t", -9.0)
		if h.ak != null:
			h.ak.drop_holds()

## Can the owner pick it up right now? Walking into it does it when no foe is close and it was not just put down;
## a fresh interact press does it either way.
static func _can_start(k: Kin, h: Hunter, r: Dictionary) -> bool:
	if k.rescue_block > 0.0 or not rescuable(k) or not h.grounded or not _near(k, h, float(r["rescue_r"])):
		return false
	if Capture.active(h) or h.box_reviving() or h.kit_t > 0.0 or h.drink_t > 0.0 or h.base_t > 0.0:
		return false
	if not CareUtil.carried_of(k.m, h).is_empty() or stop_reason(k, h) != "" or contested(k):
		return false
	if k.m.time - float(h.get_meta("f_edge_t", -9.0)) < F_EDGE_S:
		return true
	return not k.has_meta(LEAVE_META) and not _foe_near(h)

static func _foe_near(h: Hunter) -> bool:
	for e in h.m.hunters:
		if e.team != h.team and not e.out and not e.downed and not e.extracted and h.flat_dist(e) < ENEMY_NEAR:
			return true
	return false

## The Boki rides in the owner's arms (its spot follows them, on the ground; the render lifts it, scoop_pose).
static func _carry(k: Kin, h: Hunter) -> void:
	var at := KinLoss.ground(k.m, h.pos + Vector3(-sin(h.face), 0.0, -cos(h.face)) * ARMS_FWD)
	k.teleport(at if at != Vector3.INF else h.pos)

## The carry ends: the Boki falls back down where the owner is (still downed or guarding), the progress is lost and it
## cannot be picked up again for a moment. "drop" is the owner's choice (Shift or interact); it also stays down until
## they step away.
static func stop(k: Kin, h: Hunter, why: String) -> void:
	k.rescue_on = false
	k.rescue_t = 0.0
	k.rescue_block = float(rules()["rescue_block_s"])
	h.set_meta("f_edge_t", -9.0)
	if why == "drop":
		k.set_meta(LEAVE_META, true)
	var at := KinLoss.ground(k.m, h.pos)
	if at != Vector3.INF:
		k.teleport(at)
	if why == "cc":
		k.m.sfx(KinVoice.cue(k.species, "unsure"), k.pos, -6.0)
		if h.is_local() and k.m.hud:
			k.m.hud.toast_small("Dropped it", Color("ffd89a"))

## Speed factor while carrying a Boki (Hunter._physics).
static func carry_speed(h: Hunter) -> float:
	return float(rules()["carry_speed_k"]) if KinLoss.rescuing(h) != null else 1.0

## Hunter._tick: tracks fresh interact presses; while you carry your Boki nothing fires, you cannot jump or glide, and
## Shift or interact puts it down (that press is spent on the drop).
static func commit(h: Hunter) -> void:
	var f := bool(h.inp.get("interact", false))
	if f != bool(h.get_meta("f_prev", false)):
		h.set_meta("f_prev", f)
		if f:
			h.set_meta("f_edge_t", h.m.time)
	var k := KinLoss.rescuing(h)
	if k == null:
		return
	if h.inp.get("dash", false) or h.m.time - float(h.get_meta("f_edge_t", -9.0)) < F_EDGE_S:
		stop(k, h, "drop")
	h.inp["dash"] = false
	for key in BLOCKED_INPUTS:
		h.inp[key] = false
	h.dash_buf = 0.0
	h.jump_buf = 0.0

## A rising tick while it fills, and a ring that closes round the Boki (the HUD draws the ring from rescue_t).
static func _rescue_fx(k: Kin, h: Hunter, dt: float) -> void:
	var f := scoop_k(k)
	var t := float(h.get_meta("rescue_tick", 0.0)) - dt
	if t <= 0.0:
		t = 0.3
		k.m.sfx("heal", k.pos, -12.0, 0.8 + 0.9 * f)
		k.m.fx.burst(k.pos + Vector3(0, 0.5 + 0.6 * f, 0), Color(k.sp.get("glow", k.sp["color"])), 3, 1.5, 0.4, -1.0, 0.7)
	h.set_meta("rescue_tick", t)

## "rs_carry" while carrying, "rs_done" for a moment after: the pose id for HunterAnim (and the net snapshot).
static func rescue_pose(h: Hunter) -> String:
	if KinLoss.rescuing(h) != null:
		return "rs_carry"
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
		var k := KinLoss.rescuing(h)
		if id == "rs_carry" and k != null:
			t = h.m.time - float(h.get_meta("rescue_at", h.m.time))
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
	KinLoss.reclaimed(k)
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
	var show: bool = (k.state == "downed" or KinLoss.guarding(k)) and k.owner_h != null and not k.unseen and k.m.player != null and k.owner_h.team == k.m.player.team
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

## The rescue: the Boki is lifted into the carrier's arms and stays there (render only; its spot already follows them).
static func scoop_pose(k: Kin) -> void:
	if not (k.state == "downed" or KinLoss.guarding(k)) or k.rescue_t <= 0.0 or k.owner_h == null or k.model == null:
		return
	var h := k.owner_h
	var lift := smoothstep(0.0, float(rules()["carry_lift_s"]), k.rescue_t)
	var bob := 0.04 * sin(k.m.time * 4.0)
	var arms := h.global_position + Vector3(-sin(h.face) * ARMS_FWD, ARMS_UP + bob, -cos(h.face) * ARMS_FWD)
	k.global_position = k.global_position.lerp(arms, lift)
	k.model.scale *= lerpf(1.0, 0.7, lift)
