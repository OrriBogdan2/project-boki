class_name BurrowSwap
extends RefCounted
## A Boki changing places with a sleeper in the Boki Burrow, on screen: the one going to sleep walks
## to the door and slips in, the one waking up steps out of the door and wanders off. The roster
## change itself is KinBox (nothing new is saved: "boxed" and "box_slot" as before).

## Where the Burrow's door is (in front of the mound, which faces +Z before it is turned).
static func door(h: Node) -> Vector3:
	return h.BURROW_AT + h._turn(Vector3(0, 0, 1.55), h.burrow_r)

## The Boki on the island for a record, or {}.
static func kin_of(h: Node, rec: Dictionary) -> Dictionary:
	for k in h.kins:
		if k["rec"] == rec: return k
	return {}

## Puts the sleeper out and the island Boki to bed (a free spot out: sleeper only, out_rec is {}).
## Returns "" or why not. The walking is done by step() on the next frames.
static func swap(h: Node, out_rec: Dictionary, in_rec: Dictionary) -> String:
	var why := KinBox.swap(out_rec, in_rec) if not out_rec.is_empty() else KinBox.to_farm(in_rec)
	if why != "": return why
	Save.save_game()
	var walk := float(KinBox.rules()["walk_secs"])
	var leaving := kin_of(h, out_rec)
	if not leaving.is_empty():
		for key in ["chase", "task", "job", "fetch", "called_t"]: leaving.erase(key)
		if leaving.has("indoors"):      # napping in the house: nothing to see, it is just gone
			KinIndoors.left(leaving)
			(leaving["node"] as Node3D).queue_free()
			h.kins.erase(leaving)
		else:
			leaving["burrow_t"] = walk * 4.0      # gives up if it can't find the way in
			leaving["burrow_in"] = true
			leaving["goal"] = door(h)
	var taken: Array = h.kins.map(func(o): return o["pos"])
	var spot: Vector3 = h.world.free_spot_near(door(h) + Vector3(randf_range(-1.5, 1.5), 0, 2.5), taken, 1.3)
	var waking: Dictionary = h._add_kin(in_rec, door(h))
	waking["burrow_t"] = walk
	waking["goal"] = spot
	waking["t"] = walk
	if h.hb: h.hb.assign_beds()
	h._refresh_burrow()
	Sfx.play("thump", door(h), -12.0, 0.1, 1.2)
	return ""

## Moves a Boki that is on its way through the door (key "burrow_t"; "burrow_in" if it is going to
## sleep). True when it has gone in and is no longer on the island.
static func step(h: Node, k: Dictionary, d: float) -> bool:
	k["t"] = 1.0
	k["burrow_t"] = float(k["burrow_t"]) - d
	if not k.has("burrow_in"):
		if float(k["burrow_t"]) <= 0.0: k.erase("burrow_t")
		return false
	k["goal"] = door(h)
	var pos: Vector3 = k["pos"]
	if Vector2(pos.x - door(h).x, pos.z - door(h).z).length() > 0.7 and float(k["burrow_t"]) > 0.0:
		return false
	(k["node"] as Node3D).queue_free()
	h.kins.erase(k)
	return true
