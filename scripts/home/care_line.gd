class_name CareLine
extends RefCounted
## The care line over the Boki you stand next to on the farm: what the interact key does (pet, or what it
## needs), feed, play and pick up, each with its live key. What can't be done now is greyed (ok false).

const LINE_M := 2.4  # m above a Boki's feet where its line sits (over its want bubble)
const GREY_A := 0.35  # alpha of an action that can't be done now
const VERBS := {"nap": "Tuck in", "bath": "Give a bath", "brush": "Brush"}


## The line's [key, words, ok] rows for Boki `k`; the hold key keeps its ring (HoldPrompt).
static func pairs(h: Node, k: Dictionary) -> Array:
	var rec: Dictionary = k["rec"]
	var act := KinWants.action(rec, h.POND_EDGE.x > -100.0)
	var no_food := Care.want(rec) == "food" and KinWants.best_food(rec) == ""
	var held: bool = h.carry.k == k
	var lift := "to let go" if held else ("to lead" if HomeCarry.mode_for(rec) == "lead" else "to pick up")
	return [
		[Settings.key_cap("interact"), VERBS.get(act, "Pet"), act != "feed"],
		[Settings.key_cap("interact"), "Feed (no food)" if no_food else "Feed", act == "feed"],
		[Settings.key_cap("play"), "Play", not k.has("fetch")],
		["Hold " + Settings.key_cap("interact"), lift, held or h.carry.can_lift(k)]]


## Greys the actions of `row` (the key row built from `pairs`) that can't be done now (a third item false).
static func grey(row: Control, rows: Array) -> void:
	for i in rows.size():
		if rows[i].size() > 2 and not rows[i][2]:
			(row.get_child(i) as CanvasItem).modulate.a = GREY_A


## Puts `box` over the world point `at`, kept on screen; hides it when `at` is behind the camera.
static func place(box: Control, cam: Camera3D, at: Vector3, vp: Vector2) -> void:
	box.visible = box.visible and not cam.is_position_behind(at)
	var p := cam.unproject_position(at + Vector3.UP * LINE_M) - Vector2(box.size.x * 0.5, box.size.y)
	box.position = p.clamp(Vector2.ZERO, (vp - box.size).max(Vector2.ZERO))
