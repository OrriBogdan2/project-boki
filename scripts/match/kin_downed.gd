class_name KinDowned
extends RefCounted
## A downed Boki (docs/decisions/0001), replacing the old 8s faint and teleport:
##   - it stays where it fell, marked on screen and the minimap (BokiHud) and glowing in your team colour
##   - its owner rescues it by running into it: a short scoop (rescue_s), and it is back on the shoulder
##     with a good share of its health (rescue_hp). Nobody else can: it can't be hurt, scanned or taken
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
	if rescuable(k) and k.flat_dist(h) < float(r["rescue_r"]) and absf(h.pos.y - k.pos.y) < 2.2:
		k.rescue_t += dt
		if k.rescue_t >= float(r["rescue_s"]):
			rescue(k)
			return
	else:
		k.rescue_t = maxf(0.0, k.rescue_t - dt * 2.0)
	k.down_t -= dt
	if k.down_t <= 0.0:
		come_round(k, false)

## Back on your feet with a share of health: rescued (run into it) or recovered on its own.
static func come_round(k: Kin, rescued: bool) -> void:
	var r := rules()
	k.hp = k.max_hp * float(r["rescue_hp"] if rescued else r["recover_hp"])
	k.down_t = 0.0
	k.rescue_t = 0.0
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

## The scoop: it lifts and shrinks toward your shoulder over rescue_s.
static func scoop_pose(k: Kin) -> void:
	if k.state != "downed" or k.rescue_t <= 0.0 or k.owner_h == null or k.model == null:
		return
	var e := scoop_k(k)
	e = e * e * (3.0 - 2.0 * e)
	k.global_position = k.global_position.lerp(k.owner_h.global_position + Vector3(0, 1.4, 0), e)
	k.model.scale *= lerpf(1.0, 0.55, e)
