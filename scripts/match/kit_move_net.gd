class_name KitMoveNet
extends RefCounted
## The kit's full-body move on the "st" hunter snapshot (Net 0.16.0, reshaped in 0.24.6), after
## KinNet.hunter_extra (26-30): index AT is the move as "id~n" (n: ArchKit.anim_n, the kit's play count,
## so the same move restarted is a new play for the other game, like KinNet's pose), CLEAR when the kit
## cleared its move (a lowered shield, a cancelled draw), "" when the move is older than LIFE (the copy
## plays it on); AT + 1 is the move's age in seconds.

const AT := 31
const LIFE := 3.0          # seconds a move is still worth sending (the longest is about 2.5s)
const CLEAR := "-"
const DRIFT := 0.3         # s: the copy's clock re-syncs when the sender's age differs by more (a kit moving anim_at)

static func extra(h: Hunter) -> Array:
	var k: ArchKit = h.ak
	if k == null:
		return ["", 0.0]
	if k.anim_id == "":
		return [CLEAR, 0.0]
	if h.m.time - k.anim_at > LIFE:
		return ["", 0.0]
	return ["%s~%d" % [k.anim_id, k.anim_n % 100], snappedf(h.m.time - k.anim_at, 0.05)]

## A remote hunter's move starts when its id~n changes (or the sender's clock moved it), then plays on
## locally like any kit move; CLEAR ends it.
static func apply(h: Hunter, it: Array) -> void:
	if h.ak == null or it.size() <= AT + 1:
		return
	var raw := String(it[AT])
	if raw == "":
		return
	var k: ArchKit = h.ak
	var last := String(h.get_meta("kmove_raw", ""))
	h.set_meta("kmove_raw", raw)
	if raw == CLEAR:
		k.anim_id = ""
		return
	var id := raw.get_slice("~", 0)
	var age := float(it[AT + 1])
	if raw != last or k.anim_id != id or absf((h.m.time - k.anim_at) - age) > DRIFT:
		k.anim_id = id
		k.anim_at = h.m.time - age
