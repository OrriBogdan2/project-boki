class_name Capture
extends RefCounted
## Capture by scan (docs/decisions/0002). Replaces the old daze-then-hold-F tame.
##   - the target must be a wild Boki that is knocked out ("dazed")
##   - hold the interact key (F) for hold_s beside it to commit; then the scan runs on its own for scan_s:
##     a beam from you binds the Boki, it dissolves into light and into a capsule, with a rising hum and a
##     pop at the end. No holding needed.
##   - while it runs you are rooted and can aim but not shoot. A dash cancels it (your choice). Crowd control
##     on you (stun, root, a knockback, Grounded, a hex, a grapple) interrupts it; plain damage does not.
##     The Boki's daze timer waits (Kin.scan_by) and picks up again if you are interrupted, so you can retry.
##   - success puts a capsule in your box (Hunter.caught, capacity in content/rules/capture.json); a full box
##     blocks the scan. The capsule stays in the box for the match: it never follows you, fights, or joins
##     your Boki (one active Boki per hunter). It spills into your deathbox like the rest and comes home when
##     you extract.
##   - the beam and the hum are in the world: rivals see and hear it (Match.note_sound), and other players
##     see it through kcmd events (KinNet): scan_start (repeated about once a second, with the progress),
##     scan_stop, scan_done.
## State lives in the hunter's meta "cap": {phase: "hold"|"scan", k, hold|t, seen, remote, beam, hum, ping, beat}.

const HOLD_OVER := 2.5      # s: a scan nobody has confirmed for this long lets the Boki wake up again (a rival's game vanished)
const BEAM_COL := Color("bff0ff")

static func rules() -> Dictionary:
	return Content.rules("capture")

static func box_cap() -> int:
	return int(rules()["box_capacity"])

## Is there a place left in the box?
static func room(h: Hunter) -> bool:
	return h.caught.size() < box_cap()

## "Box full" for the local player (the capsule stays where it was: a deathbox, the ground).
static func full_note(m, h: Hunter) -> void:
	if h.is_local() and m.hud and m.time - float(h.get_meta("cap_full_msg", -9.0)) > 1.5:
		h.set_meta("cap_full_msg", m.time)
		m.hud.toast("Box full (%d/%d): release a capsule first" % [h.caught.size(), box_cap()], Color("ffb0a0"))

static func state(h: Hunter) -> Dictionary:
	return h.get_meta("cap", {})

## Scanning right now (the 4s part): rooted, can aim, cannot shoot.
static func active(h: Hunter) -> bool:
	return state(h).get("phase", "") == "scan"

## 0..1 through the hold that commits (for the fill ring), or through the scan itself.
static func hold_frac(h: Hunter) -> float:
	var st := state(h)
	return clampf(float(st.get("hold", 0.0)) / float(rules()["hold_s"]), 0.0, 1.0) if st.get("phase", "") == "hold" else 0.0

static func scan_frac(h: Hunter) -> float:
	var st := state(h)
	return clampf(float(st.get("t", 0.0)) / float(rules()["scan_s"]), 0.0, 1.0) if st.get("phase", "") == "scan" else 0.0

## Why a scan cannot start ("" if it can).
static func block_reason(h: Hunter, k: Kin) -> String:
	if k == null or k.dead or k.state != "dazed":
		return "Knock it out first"
	if not KinLoss.scannable_by(h, k):
		return "That Boki is on your side"
	if KinLoss.cradled(k):
		return "Its owner is picking it up"
	if h.caught.size() >= box_cap():
		return "Box full (%d/%d): release a capsule first" % [h.caught.size(), box_cap()]
	return ""

# ------------------------------------------------------------------ the hold (the interact handler calls this each step)
## Interact is held beside a dazed Boki: fill the hold, then commit.
static func hold(m, h: Hunter, k: Kin, dt: float) -> void:
	var st := state(h)
	if st.get("phase", "") == "scan":
		return
	var why := block_reason(h, k)
	if why != "":
		if h.is_local() and m.time - float(h.get_meta("cap_msg", -9.0)) > 2.0:
			h.set_meta("cap_msg", m.time)
			if m.hud: m.hud.toast(why, Color("ffb0a0"))
		return
	if st.is_empty():
		st = {"phase": "hold", "k": k, "hold": 0.0, "seen": m.time}
		h.set_meta("cap", st)
	st["hold"] = float(st["hold"]) + dt
	st["seen"] = m.time
	h.set_hold("scan")
	if float(st["hold"]) >= float(rules()["hold_s"]):
		begin(m, h, k)

static func begin(m, h: Hunter, k: Kin) -> void:
	var st := {"phase": "scan", "k": k, "t": 0.0, "seen": m.time, "remote": false, "beat": 0.0, "ping": 0.0}
	h.set_meta("cap", st)
	k.scan_by = h
	k.scan_at = m.time
	_start_fx(m, h, k, st)
	_send(m, "scan_start", h, k, 0.0)

# ------------------------------------------------------------------ each fixed step
## Runs once per step, after the bots have decided and before the hunters move.
static func tick(m, dt: float) -> void:
	for h in m.hunters:
		var st := state(h)
		if st.is_empty():
			continue
		if st.get("remote", false):
			_tick_remote(m, h, st, dt)
			continue
		if h.out or h.extracted:
			cancel(m, h, "out")
			continue
		if st["phase"] == "hold":
			# let go (or walked off, or the Boki woke): the hold drains away
			if m.time - float(st["seen"]) > 0.2 or not is_instance_valid(st["k"]) or (st["k"] as Kin).state != "dazed":
				h.remove_meta("cap")
			continue
		_tick_scan(m, h, st, dt)

static func _tick_scan(m, h: Hunter, st: Dictionary, dt: float) -> void:
	var kv = st.get("k")                     # (untyped first: the Boki may have been freed)
	var k: Kin = kv if is_instance_valid(kv) else null
	var why := interrupt_reason(h, k)
	if why != "":
		cancel(m, h, why)
		return
	# committed: rooted, aim stays free, no shooting
	h.inp["move"] = Vector2.ZERO
	h.inp["fire"] = false
	h.inp["jump"] = false
	h.inp["glide"] = false
	st["t"] = float(st["t"]) + dt
	k.scan_at = m.time
	var frac := clampf(float(st["t"]) / float(rules()["scan_s"]), 0.0, 1.0)
	_update_fx(m, h, k, st, frac)
	st["ping"] = float(st["ping"]) + dt
	if float(st["ping"]) >= float(rules()["noise_every_s"]):
		st["ping"] = 0.0
		m.note_sound(h, h.pos, "scan")           # rivals and the Blight hear it
	st["beat"] = float(st["beat"]) + dt
	if float(st["beat"]) >= 1.0:
		st["beat"] = 0.0
		_send(m, "scan_start", h, k, frac)       # (a heartbeat: the host keeps the daze timer waiting)
	if frac >= 1.0:
		complete(m, h, k)

const HARD_KNOCK := 8.0       # m/s (|kb| / mass, as Hunter.impulse computes it): a shove this fast (about 1.5m of slide) or a launch counts as being knocked away; a bullet's nudge does not
const LAUNCH_AGE := 0.4       # s: how long after the launch it still counts

## Hard crowd control on a hunter: stun, root, a real knock or a launch, Grounded, a hex, a grapple or a pad flight. It
## interrupts a scan here and a rescue (KinDowned); plain damage and the small shove most hits carry do not.
static func controlled(h: Hunter) -> bool:
	return h.stun_t > 0.0 or h.root_t > 0.0 or h.m.time - h.launched_at < LAUNCH_AGE or KitStatus.grounded(h) or Hex.active(h) or not h.grap.is_empty() or not h.pad.is_empty()

## What stops any channel on the hunter (a scan, a rescue): "dash" (your choice) or "cc" (crowd control). "" = neither.
static func hunter_stop(h: Hunter) -> String:
	if h.inp.get("dash", false) or h.roll_t > 0.0:
		return "dash"
	return "cc" if controlled(h) else ""

## What stops a scan: "dash" (your choice), crowd control, or the Boki gone. "" keeps it going.
## Plain damage is not on the list.
static func interrupt_reason(h: Hunter, k: Kin) -> String:
	if k == null or not is_instance_valid(k) or k.dead or k.state != "dazed":
		return "gone"
	if h.downed:
		return "down"
	var own := hunter_stop(h)
	if own != "":
		return own
	if h.flat_dist(k) > float(rules()["cancel_range"]):
		return "cc"
	return ""

static func cancel(m, h: Hunter, why: String) -> void:
	var st := state(h)
	if st.is_empty():
		return
	var k = st.get("k")
	h.remove_meta("cap")
	if st.get("phase", "") != "scan":
		return
	_stop_fx(m, h, st)
	if k is Kin and is_instance_valid(k):
		(k as Kin).scan_by = null
		_send(m, "scan_stop", h, k, 0.0)
	if why in ["dash", "cc"]:               # (the player-facing interruptions; a hunter leaving or a Boki gone is quiet)
		if h.is_local() and m.hud:
			m.hud.toast("Scan cancelled: hold %s beside it to try again" % Settings.key_cap("interact") if why == "dash" else "Scan interrupted: hold %s to try again" % Settings.key_cap("interact"), Color("ffd89a"))
		m.sfx("kin_unsure", h.pos, -6.0)

## The match is going away: stop every beam and hum (a loop key outlives the node that started it).
static func teardown(m) -> void:
	for h in m.hunters:
		if not is_instance_valid(h):
			continue
		var st := state(h)
		if not st.is_empty():
			_stop_fx(m, h, st)
			h.remove_meta("cap")

static func complete(m, h: Hunter, k: Kin) -> void:
	var st := state(h)
	h.remove_meta("cap")
	_stop_fx(m, h, st)
	k.scan_by = null
	if not room(h):
		# the box filled while it ran (a deathbox looted, a net catch): it lets go, and rivals see it stop, not finish
		_send(m, "scan_stop", h, k, 0.0)
		full_note(m, h)
		return
	_send(m, "scan_done", h, k, 1.0)
	_pop(m, h, k)
	m._catch(h, k)

## Release a capsule from your box. The Boki goes free (it is not put back in the world).
static func release(m, h: Hunter, idx: int) -> bool:
	if idx < 0 or idx >= h.caught.size():
		return false
	var rec: Dictionary = h.caught[idx]
	h.caught.remove_at(idx)
	m.sfx("kin_happy", h.pos, -4.0)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color(Data.KIN[String(rec["species"])]["color"]), 12, 3.0)
	if h.is_local() and m.hud:
		m.hud.toast("%s was let go" % rec.get("name", "The Boki"), Color("bfe9ff"))
	return true

# ------------------------------------------------------------------ the net
static func _send(m, kind: String, h: Hunter, k: Kin, frac: float) -> void:
	KinNet.event(m, kind, h, h.pos, "%s|%.2f" % [k.nid, frac])

## An event from another game about one of their hunters scanning.
static func on_net(m, h: Hunter, kind: String, extra: String) -> void:
	var parts := extra.split("|")
	var kv = m.ents_by_id.get(parts[0], null)
	var k: Kin = kv if is_instance_valid(kv) and kv is Kin else null
	match kind:
		"scan_start":
			if k == null:
				return
			k.scan_by = h
			k.scan_at = m.time
			var st := state(h)
			var frac := float(parts[1]) if parts.size() > 1 else 0.0
			if st.is_empty() or not st.get("remote", false):
				st = {"phase": "scan", "k": k, "t": frac * float(rules()["scan_s"]), "seen": m.time, "remote": true, "ping": 0.0}
				h.set_meta("cap", st)
				_start_fx(m, h, k, st)
			st["t"] = frac * float(rules()["scan_s"])
			st["seen"] = m.time
		"scan_stop", "scan_done":
			var st2 := state(h)
			if k != null:
				k.scan_by = null
			if not st2.is_empty():
				_stop_fx(m, h, st2)
				h.remove_meta("cap")
			if kind == "scan_done" and k != null:
				_pop(m, h, k)

static func _tick_remote(m, h: Hunter, st: Dictionary, dt: float) -> void:
	var k = st.get("k")
	if not is_instance_valid(k) or m.time - float(st["seen"]) > HOLD_OVER:
		_stop_fx(m, h, st)
		h.remove_meta("cap")
		return
	st["t"] = minf(float(rules()["scan_s"]), float(st["t"]) + dt)
	_update_fx(m, h, k, st, clampf(float(st["t"]) / float(rules()["scan_s"]), 0.0, 1.0))

# ------------------------------------------------------------------ how it looks and sounds
static func _start_fx(m, h: Hunter, k: Kin, st: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "ScanBeam"
	m.add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = Models.cyl(1.0, 1.0, 1.0, 12)
	mi.rotation.x = PI / 2.0
	mi.material_override = Models.glow_mat(Color(BEAM_COL, 0.5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	st["beam"] = root
	st["hum"] = "scanhum" + h.nid
	Sfx.loop_start(st["hum"], "revive_hum", h.pos, 0.0, float(rules()["hear_range"]))
	m.fx.ring(k.pos, 1.4, Color(BEAM_COL, 0.8), 0.4)

static func _update_fx(m, h: Hunter, k: Kin, st: Dictionary, frac: float) -> void:
	var root = st.get("beam")
	if root is Node3D and is_instance_valid(root):
		var a: Vector3 = h.pos + Vector3(0, 1.1, 0)
		var b: Vector3 = k.pos + Vector3(0, 0.5, 0)
		var d := b - a
		(root as Node3D).global_position = a + d * 0.5
		if d.length() > 0.05:
			(root as Node3D).look_at(b, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
		var w := (0.05 + 0.09 * (1.0 - frac * 0.5)) * (1.0 + 0.25 * sin(m.time * 22.0))
		(root as Node3D).scale = Vector3(w, w, d.length())
	var rp: Array = rules()["rise_pitch"]
	Sfx.loop_set(String(st.get("hum", "")), h.pos, lerpf(float(rp[0]), float(rp[1]), frac))
	if randf() < 0.5:
		m.fx.burst(k.pos + Vector3(randf_range(-0.3, 0.3), 0.3 + frac * 1.2, randf_range(-0.3, 0.3)), BEAM_COL, 1, 1.2, 0.5, -3.0, 0.6)

static func _stop_fx(m, h: Hunter, st: Dictionary) -> void:
	var root = st.get("beam")
	if root is Node3D and is_instance_valid(root):
		(root as Node3D).queue_free()
	st.erase("beam")
	if st.has("hum"):
		Sfx.loop_stop(String(st["hum"]))
		st.erase("hum")

## The finish: a bright pop and the capsule flying to the hunter.
static func _pop(m, h: Hunter, k: Kin) -> void:
	var col: Color = Data.KIN[k.species]["color"]
	m.sfx("scan_pop", k.pos, 0.0)
	m.fx.burst(k.pos + Vector3(0, 0.6, 0), Color.WHITE, 20, 5.0, 0.5, -2.0, 1.2)
	m.fx.burst(k.pos + Vector3(0, 0.6, 0), col, 16, 3.5, 0.6)
	m.fx.ring(k.pos, 1.8, Color(BEAM_COL, 0.9), 0.45)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16; sm.height = 0.32
	cap.mesh = sm
	cap.material_override = Models.glow_mat(Color(col.lerp(Color.WHITE, 0.5), 0.95))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(cap)
	cap.global_position = k.pos + Vector3(0, 0.6, 0)
	var tw := cap.create_tween()
	tw.tween_property(cap, "global_position", h.pos + Vector3(0, 1.2, 0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(cap.queue_free)

## The Boki coming apart into light as the scan fills (Kin.render calls this last).
static func dissolve(k: Kin) -> void:
	if k.scan_by == null or k.model == null or not is_instance_valid(k.scan_by):
		return
	var st := state(k.scan_by)
	if st.get("phase", "") != "scan":
		return
	var e := clampf(float(st["t"]) / float(rules()["scan_s"]), 0.0, 1.0)
	e = e * e * (3.0 - 2.0 * e)
	k.model.scale *= lerpf(1.0, 0.12, e)
	k.model.rotation.y += e * 6.0
	k.global_position += Vector3(0, e * 0.9, 0)
