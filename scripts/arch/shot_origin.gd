class_name ShotOrigin
extends RefCounted
## Where a Hero's rounds leave the model (content/shot_origins.json, docs/HERO_VFX.md "Shot origins"). Per Hero and
## move: "at", the muzzle measured on the v2 model as [side, forward] m from the feet along the aim, taken shot by shot
## (two crossbows, two hands), which the round itself uses so every machine starts it in the same place; and "nodes",
## the .glb empties the muzzle flash sits on. A seated round keeps its height and still ends where it would have.

const PATH := "res://content/shot_origins.json"
## A round this far along its flight (in seconds of it) is fresh enough to seat.
const FRESH := 0.05

static var _data: Dictionary = {}

static func data(arch: String, move: String) -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"": {}}
	return (_data.get(arch, {}) as Dictionary).get(move, {})

## Where round `n` of a move leaves, at `fallback`'s height; `fallback` when the Hero has no measured origin.
static func point(h: Hunter, move: String, n: int, fallback: Vector3) -> Vector3:
	var at: Array = data(h.arch, move).get("at", [])
	if at.is_empty():
		return fallback
	var o: Array = at[n % at.size()]
	var d := h.aim_dir()
	var side := float(o[0])
	var ahead := float(o[1])
	return Vector3(h.pos.x + d.x * ahead - d.y * side, fallback.y, h.pos.z + d.y * ahead + d.x * side)

## Where the flash of the attack key's latest round sits: the model's muzzle node, else `fallback`.
static func flash(h: Hunter, fallback: Vector3) -> Vector3:
	var nodes: Array = data(h.arch, "lmb").get("nodes", [])
	if nodes.is_empty() or h.model == null or not h.model.is_inside_tree():
		return fallback
	var node := WardenGlb.anchor(h.model, String(nodes[h.shot_n % nodes.size()]))
	return node.global_position if node != null else fallback

## Moves a fresh round to leave from `at`. Its speed stays and it still ends where it would have, so it gets the time
## (and the turn) back; a slowing slug just leaves from there.
static func seat(sd: Dictionary, at: Vector3) -> void:
	var was: Vector3 = sd["pos"]
	var vel: Vector2 = sd["vel"]
	var to := Vector2(was.x, was.z) + vel * float(sd["life"]) - Vector2(at.x, at.z)
	if vel.length() > 0.1 and to.length() > 0.1 and not (sd["x"] as Dictionary).has("decel"):
		var life := to.length() / vel.length()
		if sd.has("life0"):
			sd["life0"] = float(sd["life0"]) + life - float(sd["life"])
		sd["life"] = life
		sd["vel"] = to.normalized() * vel.length()
	sd["pos"] = at
	sd["prev"] = at
	sd["start"] = at
	sd["seated"] = true

## Each step (ArchKit.tick): the attack key's rounds fired since the last step (`seen` = the Hunter's shot count then)
## leave from the model's muzzle. Returns the shot count to pass next time.
static func tick(h: Hunter, seen: int) -> int:
	if h.shot_n == seen or not data(h.arch, "lmb").has("at"):
		return h.shot_n
	var shots: Array = h.m.shots
	for i in range(shots.size() - 1, -1, -1):
		var sd: Dictionary = shots[i]
		if sd["by"] != h or sd.has("seated") or (sd["x"] as Dictionary).has("src"):
			continue
		var was: Vector3 = sd["pos"]
		var gone := Vector2(was.x - sd["start"].x, was.z - sd["start"].z).length()
		if gone > (sd["vel"] as Vector2).length() * FRESH:
			break
		seat(sd, point(h, "lmb", h.shot_n, was))
	return h.shot_n
