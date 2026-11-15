class_name PetReact
extends RefCounted
## What a pat does, by personality (content/rules/pet_react.json). The farm (home.gd) and the rooms
## (interior.gd) both call pet(): it picks the Boki's kind from its traits, plays one short beat from
## clips the game already has (a roll, a flinch, a lean, a stiff stand-off, a purr and a nap) with one
## mood icon, and pays joy and trust, at most `cap` times a farm day so spamming does nothing.
## A shy Boki's first pat only makes it flinch; its second, soon after, is the one it leans into.

static func rules() -> Dictionary:
	return Content.rules("pet_react")

## "shy", "proud", "playful" or "sleepy", from its traits.
static func kind(rec: Dictionary) -> String:
	var r := rules()
	var tr: Dictionary = rec.get("traits", {})
	if float(tr.get("bravery", 0.5)) < float(r["shy_bravery"]):
		return "shy"
	if float(tr.get("temper", 0.5)) > float(r["proud_temper"]):
		return "proud"
	return "playful" if float(tr.get("curiosity", 0.5)) >= float(r["playful_curiosity"]) else "sleepy"

## Pats it has paid for in this farm day (the window restarts with the care days).
static func pats_today(rec: Dictionary) -> int:
	if Care.care_day(rec, "pet_win"):
		rec["pet_n"] = 0
	return int(rec.get("pet_n", 0))

## Pats the Boki k (a farm or room entry): plays the beat and, when `reward` is on, pays it (a
## visit pays nothing and never runs out). Returns
## {"kind", "paid" (joy and trust given), "loves" (it likes scratches), "memory" (first pat of the day)}.
## `h` is the screen (home.gd or interior.gd): ppos, fx, verbs and _toast.
static func pet(h, k: Dictionary, reward := true) -> Dictionary:
	var rec: Dictionary = k["rec"]
	var r := rules()
	var kd := kind(rec)
	var spec: Dictionary = r["kinds"][kd]
	var now_s := Time.get_ticks_msec() / 1000.0
	var out := {"kind": kd, "paid": false, "loves": rec.get("likes", {}).get("play", "") == "pet", "memory": false}
	var first_shy := kd == "shy" and now_s > float(k.get("pet_at", -1.0e9)) + float(r["again_s"])
	k["pet_at"] = now_s
	var can: bool = reward and not first_shy and pats_today(rec) < int(spec["cap"])
	if can:
		rec["pet_n"] = int(rec.get("pet_n", 0)) + 1
		Care.change(rec, "joy", float(spec["joy"]) + (float(r["love_joy"]) if out["loves"] else 0.0))
		var line := Care.trust_up(rec, "pet", Time.get_unix_time_from_system(), "", float(spec["trust"]))
		if line != "":
			h._toast(line)
		out["paid"] = true
		if out["loves"] and Care.discover(rec, "play"):
			h._toast("%s loves scratches" % rec["name"])
		if Care.care_day(rec, "petted"):
			Save.remember(rec, "petted", "got a long scratch behind the ears", 1.5)
			out["memory"] = true
	_beat(h, k, kd, spec, first_shy, can or not reward)
	return out

## The clip and icon for one pat: `first_shy` is the flinch, `paid` is false once it has had enough.
static func _beat(h, k: Dictionary, kd: String, spec: Dictionary, first_shy: bool, paid: bool) -> void:
	var n: Node3D = k["node"]
	var pos: Vector3 = k["pos"]
	var hold := float(spec["hold_s"])
	if kd != "sleepy" and float(k.get("nap_t", 0.0)) > 0.0:
		k["nap_t"] = 0.01      # a gentle pat wakes it up
	h.verbs.play("pat")
	k["t"] = hold
	k["goal"] = pos
	k["hold_t"] = hold
	if not paid and not first_shy:
		if kd == "proud":
			_walk_off(h, n, k)      # one pat is all it allows
		return      # otherwise it has had enough for today: it only looks at you
	k["joy_t"] = 0.9 if kd != "playful" else hold
	var icon := String(spec["icon"])
	if first_shy:
		icon = String(spec["first_icon"])
		k["joy_t"] = 0.0
		_pose(n, "flinch", float(spec["flinch_s"]))
	else:
		h.fx.burst(pos + Vector3(0, 0.9, 0), Color("ff8fb0"), 12, 1.8)
		var pitch := Unique.voice(k["rec"]) * (0.75 if kd == "sleepy" else 1.0)
		Sfx.play(KinVoice.cue(k["rec"]["species"], "happy"), null, -4.0, 0.12, pitch)
	_icon(n, icon)
	match kd:
		"playful": _roll(n, float(spec["roll_s"]))
		"shy":
			if not first_shy:
				_pose(n, "comfort", hold)
		"proud": _walk_off(h, n, k)
		"sleepy": _doze(k, float(spec["nap_s"]))

## It rolls onto its back and over again (the body turns once about its length).
static func _roll(n: Node3D, secs: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var tw := n.create_tween()
	tw.tween_property(body, "rotation:z", TAU, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): body.rotation.z = 0.0)

## A puppet pose (KinPuppet: "flinch", "comfort") for `secs`.
static func _pose(n: Node3D, pose: String, secs: float) -> void:
	n.set_meta("pose", pose)
	var tw := n.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(func(): n.set_meta("pose", ""))

## Stands tall for a beat, then strolls off away from you.
static func _walk_off(h, n: Node3D, k: Dictionary) -> void:
	_pose(n, "alert", float(k["hold_t"]))
	var away: Vector3 = (k["pos"] - h.ppos) * Vector3(1, 0, 1)
	var to: Vector3 = k["pos"] + away.normalized() * float(rules()["away_m"])
	var tw := n.create_tween()
	tw.tween_interval(float(k["hold_t"]))
	tw.tween_callback(func(): _go(k, to))

static func _go(k: Dictionary, to: Vector3) -> void:
	k["goal"] = to
	k["t"] = 3.0

## It purrs and drops into a short nap (the farm's own nap; a room has none, so it only settles).
static func _doze(k: Dictionary, secs: float) -> void:
	k["nap_t"] = maxf(float(k.get("nap_t", 0.0)), secs)
	k["slept"] = 0.0
	k["z_t"] = 0.5

## The mood icon: floats up over its head for a moment.
static func _icon(n: Node3D, text: String) -> void:
	var old := n.get_node_or_null("PetIcon")
	if old:
		old.free()
	var lbl := Label3D.new()
	lbl.name = "PetIcon"
	lbl.text = text
	lbl.font = UI.big
	lbl.font_size = 48
	lbl.pixel_size = 0.013
	lbl.outline_size = 14
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color("ff8fb0") if text == "♥" else UI.INK
	lbl.position.y = 1.25
	n.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", 1.6, 1.4)
	tw.tween_callback(lbl.queue_free)
