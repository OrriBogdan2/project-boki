class_name KinWisp
extends RefCounted
## Boki are wisps (docs/decisions/0022). On you, a Boki is a small glowing wisp in its species colour orbiting you
## (state "wisp"): no body on a shoulder, a pack or under you. A throw or a summon bursts the wisp into the full Boki
## (a flash, a ring and a quick scale-up); a recall shrinks it back. A mount summons out to be ridden (Kin.ride, the
## Return order). Knocked out, it falls back to you as a dim wisp (KinDowned); a beaten Boki in the world is a wisp on
## the ground (state "dazed") that you scan to receive (Capture). Wisps are for the field and matches only: at home the
## Boki stay full-bodied in the garden (scripts/home never makes a Kin).
## Numbers: content/rules/boki_system.json "wisp". State on the Kin: form_t (render: 0 = wisp, 1 = full body), ride,
## summoned (sent out by a throw: it drifts back into a wisp after auto_wisp_s with nothing to do).

const NODE := "Wisp"

static func rules() -> Dictionary:
	return KinCommand.rules()["wisp"]

## Shown as a wisp: on you (not ridden), knocked out on you, or beaten on the ground.
static func is_wisp(k: Kin) -> bool:
	return (k.state == "wisp" and not under(k)) or k.state == "downed" or k.state == "dazed"

## A ridden mount under you right now (over a glide it rides along as a wisp).
static func under(k: Kin) -> bool:
	return k.ridden() and not k.owner_h.gliding

## Where it orbits its owner right now. Each Boki keeps its own phase (from its id), so two never overlap.
static func orbit_at(k: Kin) -> Vector3:
	var r := rules()
	var h := k.owner_h
	var ph := float(absi(k.nid.hash()) % 1000) / 1000.0 * TAU
	var a := float(k.m.time) * TAU / float(r["period_s"]) + ph
	var rad := float(r["orbit_r"])
	var y := float(r["height"]) + sin(float(k.m.time) * 2.7 + ph) * float(r["bob"])
	return h.pos + Vector3(cos(a) * rad, y, sin(a) * rad)

## Each step on you (Kin._sim_wisp, KinDowned.tick): it follows its orbit; ridden, it is under you.
static func follow(k: Kin) -> void:
	k.pos = k.owner_h.pos if under(k) else orbit_at(k)
	k.prev = k.pos

## The wisp bursts into the full Boki (a throw, a summon to ride): a flash, a ring, and the render scales it up.
static func burst(k: Kin, at: Vector3) -> void:
	var col := Color(k.sp.get("glow", k.sp["color"]))
	k.form_t = 0.0
	k.m.fx.flash(at + Vector3(0, 0.4, 0), col.lerp(Color.WHITE, 0.5), 0.9, 0.1)
	k.m.fx.ring(at, 1.3, Color(col, 0.9), 0.3)
	k.m.fx.burst(at + Vector3(0, 0.4, 0), col, 10, 3.0, 0.35)

## Sent out by a throw: after auto_wisp_s with no fight near and nothing to chase it drifts back into a wisp on you.
## An explicit order (Follow, Guard, Chase) keeps it out (KinFollow.set_cmd clears summoned).
static func tick_out(k: Kin, dt: float) -> void:
	if not k.summoned or k.cmd != "follow" or k.owner_h == null or k.state != "active":
		k.idle_t = 0.0
		return
	var busy := k.target != null or KinFollow.in_combat(k, k.pos) or k.owner_h.downed
	k.idle_t = 0.0 if busy else k.idle_t + dt
	if k.idle_t >= float(rules()["auto_wisp_s"]):
		k.idle_t = 0.0
		if KinFollow.set_cmd(k, "return", null):
			k.ride = false                 # (it drifts back as a wisp; a mount is not summoned under you)

# ------------------------------------------------------------------ how it shows
## Draws the wisp and eases the body in and out. True while it is a wisp (Kin.render skips the body then).
static func render(k: Kin, delta: float) -> bool:
	var r := rules()
	var wisp := is_wisp(k)
	var dur := float(r["shrink_s"] if wisp else r["summon_s"])
	k.form_t = move_toward(k.form_t, 0.0 if wisp else 1.0, delta / maxf(0.01, dur))
	var orb := _orb(k)
	orb.visible = k.form_t < 1.0 and not k.unseen
	if k.model:
		k.model.visible = k.form_t > 0.0
	if not orb.visible:
		return wisp
	var col := Color(k.sp.get("glow", k.sp["color"]))
	var ph := float(absi(k.nid.hash()) % 97)
	var pulse := 1.0 + 0.15 * sin(k.m.time * 5.0 + ph)
	var dim := k.state == "downed"
	var at := k.global_position
	if k.state == "dazed":
		at += Vector3(0, float(r["ground_h"]) + 0.08 * sin(k.m.time * 2.0 + ph), 0)
		if k.scan_by != null and is_instance_valid(k.scan_by):
			var e := Capture.scan_frac(k.scan_by)
			at += Vector3(0, e * 0.9, 0)              # (the scan lifts it toward you)
			pulse *= lerpf(1.0, 0.4, e)
	orb.global_position = at
	orb.scale = Vector3.ONE * float(r["size"]) * pulse * (1.0 - k.form_t)
	var a := float(r["dim"]) if dim else 1.0
	var core: MeshInstance3D = orb.get_child(0)
	var halo: MeshInstance3D = orb.get_child(1)
	(core.material_override as ShaderMaterial).set_shader_parameter("color", Color(col.lerp(Color.WHITE, 0.3), a))
	(halo.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, a * 0.6))
	return wisp

## The body growing out of the wisp (or shrinking into it): Kin.render calls this after it posed the model.
static func grow(k: Kin) -> void:
	if k.model and k.form_t < 1.0:
		var e := k.form_t * k.form_t * (3.0 - 2.0 * k.form_t)
		k.model.scale *= lerpf(0.15, 1.0, e)

static func _orb(k: Kin) -> Node3D:
	var orb: Node3D = k.get_node_or_null(NODE)
	if orb != null:
		return orb
	orb = Node3D.new()
	orb.name = NODE
	orb.top_level = true
	k.add_child(orb)
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.sphere(0.5 if i == 0 else 1.0, 12)
		mi.material_override = Models.glow_mat(Color.WHITE)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(mi)
	return orb
