class_name KeyChest
extends RefCounted
## The one locked chest: its padlock, the prompt, and spending the key. A chest opens only for a
## hunter holding a key, and costs exactly one. (What falls out is ChestLoot.)

static func dress(node: Node3D) -> void:
	var body := node.get_node_or_null("Body") as Node3D
	if body:
		var lk := KeyModels.padlock()
		lk.position = Vector3(0, 0.41, -0.47)
		lk.scale = Vector3.ONE * 1.5
		body.add_child(lk)
	# a brass padlock hanging over the lid that always faces the camera's side, so a locked chest reads from afar
	var fl := KeyModels.padlock()
	fl.name = "LockTag"
	fl.scale = Vector3.ONE * 2.2
	fl.position = Vector3(0, 1.55, 0)
	fl.rotation = Vector3(-0.75, PI - node.rotation.y, 0)
	node.add_child(fl)
	if node.is_inside_tree():
		var tw := fl.create_tween().set_loops()
		tw.tween_property(fl, "position:y", 1.68, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(fl, "position:y", 1.55, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## What the interact prompt says and does beside chest `c` for hunter `h`.
static func prompt(h: Hunter, c: Dictionary) -> Dictionary:
	var k := Settings.key_cap("interact")
	if bool(c.get("free", false)) or h.chest_keys > 0:
		return {
				"kind": "chest", "chest": c,
				"label": "Hold %s to open%s" % [k, "" if bool(c.get("free", false)) else "  ·  uses 1 key"]}
	return {
			"kind": "locked", "chest": c, "label": "Locked  ·  needs a key  ·  monsters with a key glint carry them",
			"col": Color("ffb0a0")}

## Takes the key for opening `c`. False (and nothing changes) when the hunter has none.
static func spend(h: Hunter, c: Dictionary) -> bool:
	if bool(c.get("free", false)):
		return true
	return h != null and take(h, "chest", 1) == 1

## The most chest keys a hunter can hold (content/rules/keys.json "keys" cap).
static func cap() -> int:
	return int(KeyRun.rules()["keys"]["cap"])

## Keys of `kind` ("chest" or "rift") that `h` holds: what the utility belt shows.
static func count(h: Hunter, kind: String) -> int:
	return h.chest_keys if kind == "chest" else h.rift_keys

## Removes up to `n` keys of `kind` from `h` and returns how many it took (the belt spends through this).
static func take(h: Hunter, kind: String, n: int) -> int:
	var taken := mini(n, count(h, kind))
	if kind == "chest":
		h.chest_keys -= taken
	else:
		h.rift_keys -= taken
	return taken

## Adds up to `n` chest keys, never past the cap, and returns how many fit. The rest stay where they were.
static func give(h: Hunter, n: int) -> int:
	var fits := clampi(cap() - h.chest_keys, 0, n)
	h.chest_keys += fits
	return fits

## True when `h` has room for one more chest key (a full hunter walks past a key on the ground).
static func has_room(h: Hunter) -> bool:
	return h.chest_keys < cap()

## Pressing interact at a locked chest with no key: a rattle, at most twice a second.
static func deny(m: Match, h: Hunter, c: Dictionary) -> void:
	if m.time - float(c.get("rattle", -9.0)) < 0.6:
		return
	c["rattle"] = m.time
	m.sfx("lock_rattle", c["pos"], -4.0, 1.0)
	var lk := (c["node"] as Node3D).get_node_or_null("Body/Lock") as Node3D
	if lk:
		var tw := lk.create_tween()
		tw.tween_property(lk, "rotation:z", 0.35, 0.05)
		tw.tween_property(lk, "rotation:z", -0.3, 0.08)
		tw.tween_property(lk, "rotation:z", 0.0, 0.06)
	if h == m.player and m.hud:
		m.hud.toast_small("Locked  ·  needs a key", Color("ffb0a0"))

## The lock falls away as the lid opens.
static func unlock_fx(m: Match, c: Dictionary) -> void:
	var lk := (c["node"] as Node3D).get_node_or_null("Body/Lock") as Node3D
	if lk:
		lk.visible = false
	var tag := (c["node"] as Node3D).get_node_or_null("LockTag") as Node3D
	if tag:
		tag.queue_free()
	m.sfx("unlock", c["pos"], -2.0, 1.1)
	m.fx.burst(c["pos"] + Vector3(0, 0.9, 0), KeyModels.BRASS, 10, 3.0, 0.5)
