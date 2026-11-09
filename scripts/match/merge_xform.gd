class_name MergeXform
extends RefCounted
## The transformation and everything that books-ends a merge (docs/decisions/0003). ~0.7s, invulnerable:
##   0.00  anticipation: the Boki leaps up into a light spiral and a type accent in the form's colour, a ~60 ms time dip
##   0.45  contact: white flash, a light column, the camera punches, the silhouette pops in (MergeLook, ease-out-back)
##   0.70  the form is live (KinMerge._go_live)
## Separation plays it backwards for a beat: the shell peels, the type accent rises, the Boki springs out beside you.
## The spiral is ONE particle node per hunter, reused for every merge (no per-frame spawning). Other games see the
## same moments from the "merge" event (the start) and the form appearing in the hunter snapshot (the contact).

const HITSTOP := 0.06           # s: the time dip when the Boki starts to leap in
const SPIRAL := "MergeSpiral"
const ENTER_COLUMN := 2.4       # m: the light column that starts the leap
const CONTACT_COLUMN := 5.0     # m (x form size): the tall column when the form pops in
const RELEASE_COLUMN := 3.0     # m: the column when the form lets go
const SOUND_RANGE_DB := 4.0     # the transformation is louder than a normal ability: rivals hear it at range

static func _snd(form: Dictionary) -> Dictionary:
	var d: Dictionary = form["def"]
	return d.get("sound", {"xform": "ult", "pitch": 1.0, "ult": "boom"})

## The Boki type whose accent this Fusion plays: the species' own, else the form's ("kit" for a kit form).
static func type_of(h: Hunter, form: Dictionary) -> String:
	if h.kin != null and is_instance_valid(h.kin):
		return String((h.kin as Kin).sp.get("type", ""))
	return String(form.get("type", ""))

static func begin(h: Hunter, form: Dictionary) -> void:
	var m := h.m
	var col: Color = form["glow"]
	var sn := _snd(form)
	spiral(h, col, true)
	KinTypeFx.fusion(m.fx, type_of(h, form), h.pos, col, ENTER_COLUMN)
	m.sfx("charge", h.pos, SOUND_RANGE_DB - 6.0, 0.8)
	m.sfx(String(sn["xform"]), h.pos, SOUND_RANGE_DB - 6.0, float(sn["pitch"]) * 0.8)
	if h.is_local():
		m.freeze_frame(HITSTOP)
	var k := MergeKit.of(h)
	if k != null:
		k.play("mf_xform")

## The Boki lands in you: the big moment.
static func contact(h: Hunter, form: Dictionary) -> void:
	var m := h.m
	var col: Color = form["glow"]
	var sn := _snd(form)
	MergeLook.attach(h, form, true)
	pop_fx(m, h.pos, form, type_of(h, form))
	m.sfx(String(sn["xform"]), h.pos, SOUND_RANGE_DB, float(sn["pitch"]))
	m.sfx("ult", h.pos, SOUND_RANGE_DB - 2.0, float(sn["pitch"]))
	m.shake(0.7, h.pos)
	if h.is_local() and m.cam:
		m.cam.punch(0.14)
		if m.hud:
			m.hud.flash(col, 0.25)
	h.squash = 0.35

## The look of the moment, for everyone: a white flash, a tall light column and the type's accent (no ring).
static func pop_fx(m: Match, at: Vector3, form: Dictionary, ty: String) -> void:
	var col: Color = form["glow"]
	m.fx.flash(at + Vector3(0, 1.0, 0), Color.WHITE, 2.6, 0.12)
	KinTypeFx.fusion(m.fx, ty, at, col, CONTACT_COLUMN * float(form["size"]))
	m.fx.spark(at + Vector3(0, 1.0, 0), Vector3.UP, Color(col).lerp(Color.WHITE, 0.5), 18, 8.0, 180.0, 0.4, 6.0, 1.2)

## The weak surge has no Boki to fly in: just the flash.
static func flash_only(m: Match, at: Vector3, form: Dictionary) -> void:
	var col: Color = form["glow"]
	m.fx.flash(at + Vector3(0, 1.0, 0), Color.WHITE, 1.8, 0.1)
	m.fx.spark(at + Vector3(0, 1.0, 0), Vector3.UP, col, 10, 5.0, 180.0, 0.4, 4.0, 1.0)

## The merge is over: the shell peels (backwards pop), shards fly, the Boki springs out (KinMerge calls merge_pop).
static func separate(h: Hunter, form: Dictionary, why: String) -> void:
	var m := h.m
	var col: Color = form["glow"]
	MergeLook.peel(h)
	if why == "shell":
		h.set_meta("shell_break_at", m.time)           # (the plate's bar flashes, BokiHud)
		h.set_meta("shell_break_col", col)
		# the shell broke: a louder crack, shards everywhere
		m.fx.flash(h.pos + Vector3(0, 1.0, 0), Color.WHITE, 2.0, 0.1)
		m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 30, 7.0, 0.6)
		m.fx.spark(h.pos + Vector3(0, 1.0, 0), Vector3.UP, Color(col).lerp(Color.WHITE, 0.4), 20, 9.0, 180.0, 0.45, 8.0, 1.2)
		m.sfx("armor_break", h.pos, 2.0, 0.9)
		m.shake(0.5, h.pos)
		if h.is_local() and m.hud:
			m.hud.toast_small("SHELL BROKEN", col)
	else:
		KinTypeFx.fusion(m.fx, type_of(h, form), h.pos, col, RELEASE_COLUMN)
		m.sfx("recall", h.pos, -2.0, 1.3)
	spiral(h, col, false)
	KinNet.event(m, "merge_end", h, h.pos, why)

## The ultimate's cracking tell (Shatter): the shell splits along bright seams for `secs` before the burst.
static func crack(h: Hunter, form: Dictionary, secs: float) -> void:
	var m := h.m
	var col: Color = form["glow"]
	m.sfx("armor_hit", h.pos, 0.0, 1.4)
	for i in 3:
		m.later(secs * float(i) / 3.0, func():
			if is_instance_valid(h) and not h.out:
				m.fx.spark(h.pos + Vector3(0, 1.1, 0), Vector3.UP, Color(col).lerp(Color.WHITE, 0.6), 10, 6.0, 180.0, 0.3, 4.0, 1.0)
				m.sfx("armor_hit", h.pos, -4.0, 1.2 + 0.2 * float(i)))
	MergeLook.crackle(h, secs)

# ------------------------------------------------------------------ the spiral (one pooled node per hunter)
## A ring of light drawing in around you (inward = true) or flying out (the separation). Reuses the hunter's node.
static func spiral(h: Hunter, col: Color, inward: bool) -> void:
	var p := h.get_node_or_null(SPIRAL) as CPUParticles3D
	if p == null:
		p = CPUParticles3D.new()
		p.name = SPIRAL
		p.amount = 40
		p.lifetime = 0.45
		p.one_shot = true
		p.explosiveness = 0.85
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = 1.7
		p.tangential_accel_min = 18.0
		p.tangential_accel_max = 24.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
		p.position = Vector3(0, 1.0, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 6
		sm.rings = 3
		p.mesh = sm
		p.emitting = false
		h.add_child(p)
	p.material_override = Models.glow_mat(col)
	p.gravity = Vector3(0, 2.0, 0)
	p.radial_accel_min = -30.0 if inward else 16.0
	p.radial_accel_max = -36.0 if inward else 22.0
	p.emitting = false
	p.restart()
	p.emitting = true

# ------------------------------------------------------------------ the Boki's part in it
## Kin.render, state "fused": during the transformation the Boki flies in on a spiral. Returns true when it posed itself.
static func boki_pose(k: Kin) -> bool:
	var h := k.owner_h
	if h == null or h.merge_st.is_empty() or String(h.merge_st.get("phase", "")) != "xform":
		return false
	var st: Dictionary = h.merge_st
	var rules := MergeForm.data()
	var u := clampf((float(rules["xform_s"]) - float(st["xt"])) / float(rules["xform_contact_s"]), 0.0, 1.0)
	if u >= 1.0 and bool(st["contact"]) and MergeForm.has_kit(st["form"]):
		k.visible = false
		return true
	var e := u * u * (3.0 - 2.0 * u)
	var from: Vector3 = st.get("from", h.pos + Vector3(0, 1.5, 0))
	var to: Vector3 = h.pos + Vector3(0, 1.1, 0)
	var ang := u * TAU * 1.5
	var rad := (1.0 - e) * 0.9
	var p := from.lerp(to, e) + Vector3(cos(ang) * rad, sin(u * PI) * 1.6, sin(ang) * rad)
	k.global_position = p
	k.model.rotation.y = ang * 2.0
	k.model.scale = Vector3.ONE * lerpf(0.85, 0.35, e)
	return true

# ------------------------------------------------------------------ other games
## The "merge" event: a rival (or a friend) started the transformation. The same spiral, with the sound.
static func on_event(m: Match, at: Vector3, form: Dictionary, h: Hunter) -> void:
	if form.is_empty():
		return
	var col: Color = form["glow"]
	var sn := _snd(form)
	if h != null:
		spiral(h, col, true)
	KinTypeFx.fusion(m.fx, String(form.get("type", "")), at, col, ENTER_COLUMN)
	m.sfx("charge", at, SOUND_RANGE_DB - 6.0, 0.8)
	m.sfx(String(sn["xform"]), at, SOUND_RANGE_DB - 6.0, float(sn["pitch"]) * 0.8)

## The form appeared in a remote hunter's snapshot: the contact moment, here.
static func on_remote_look(h: Hunter, form: Dictionary) -> void:
	var m := h.m
	var sn := _snd(form)
	pop_fx(m, h.pos, form, type_of(h, form))
	m.sfx(String(sn["xform"]), h.pos, SOUND_RANGE_DB, float(sn["pitch"]))
	m.shake(0.4, h.pos)

## A remote hunter's cast ("mcast" event): the tell and the hit, drawn here. extra = "slot|x|z|radius|seconds".
static func on_cast(m: Match, h: Hunter, at: Vector3, extra: String) -> void:
	var p := extra.split("|")
	if p.size() < 5:
		return
	var col: Color = Color(1, 1, 1)
	if h.has_meta("mf_glow"):
		col = h.get_meta("mf_glow")
	var tgt := Vector3(float(p[1]), at.y, float(p[2]))
	var rad := float(p[3])
	var secs := float(p[4])
	match p[0]:
		"ult":
			m.fx.word(h.pos + Vector3(0, 3.0, 0), "ULTIMATE", col, true)
			m.sfx("warn", h.pos, -2.0, 0.7)
			if rad > 0.5:
				var tele: Node3D = m.fx.telegraph_circle(tgt, rad, Color(col, 0.9))
				var tw := tele.create_tween()
				tw.tween_method(func(k: float): if is_instance_valid(tele): m.fx.telegraph_progress(tele, k), 0.0, 1.0, maxf(0.3, secs * 0.6))
				tw.tween_callback(func(): if is_instance_valid(tele): m.fx.end_telegraph(tele))
		"lmb", "e":
			m.fx.ring(h.pos, maxf(1.2, rad), Color(col, 0.7), 0.25)
		"rmb":
			m.fx.ring(h.pos, 1.4, Color(col, 0.7), 0.3)
		"blink":
			m.fx.bolt(h.pos + Vector3(0, 1.0, 0), tgt + Vector3(0, 1.0, 0), col)
			m.sfx("zap", tgt, -4.0, 1.5)
