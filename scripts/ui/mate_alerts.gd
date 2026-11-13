class_name MateAlerts
extends RefCounted
## A teammate going down, coming back or being lost, on their squad row (Hud._draw_squad):
##   - a knocked teammate's row wears a pink-red italic KNOCKED tag on its top edge and a red X in a white
##     arrow pointing at it; a dead one a grey DEAD tag and a grey X (the portrait greys itself)
##   - coming back or being lost: one short, faint line beside that row (LINE_S, at most LINE_A opacity)
##     and a sound cue
## Going down is also the ALLY KNOCKED banner top-centre, with its own sound (KnockBanner). The way to
## them is the squad arrow at the screen edge (Hud._draw_squad_markers), and the revive cue shows only
## once you are close (DownedMarks).

const LINE_S := 1.5            # s a line stays up, fade included
const LINE_A := 0.6            # the line's opacity at most
const LINE_PX := 13            # font px
const FADE := 0.4              # s: the line fades out over its last FADE
const KNOCKED_COL := Color("ff4a6e")   # the KNOCKED tag and the X on its arrow
const DEAD_COL := Color("9aa0ad")      # the DEAD tag and its X
const TAG_PX := 13             # font px of the tag on the row's top edge
const ARROW := Vector2(30, 26)  # px: the arrow beside the row, pointing back at it
const ARROW_GAP := 6.0         # px between the row and its arrow

var last := {}                 # nid -> the teammate's last squad state (Hud._mate_state label)
var lines := {}                # nid -> {"text", "col", "t"}

## Watches the squad for changes of state (a line and a sound for each) and ages the lines.
func track(H, p: Hunter, delta: float) -> void:
	for nid in lines.keys():
		lines[nid]["t"] = float(lines[nid]["t"]) + delta
		if float(lines[nid]["t"]) >= LINE_S:
			lines.erase(nid)
	if p == null:
		return
	for h in H.m.hunters:
		if h == p or h.team != p.team:
			continue
		var now := String(H._mate_state(h)[0])
		var was := String(last.get(h.nid, now))
		last[h.nid] = now
		if now != was:
			_changed(h, was, now)

## The squad row `r`'s part (its portrait at `pr`): the KNOCKED or DEAD tag and arrow, and the line beside it.
func draw_row(H, r: Rect2, pr: Rect2, h: Hunter, state: String) -> void:
	var line_x := r.end.x + 8.0
	var tag := ""
	if state == "WISP":
		tag = "KNOCKED"
	elif state in ["DEATHBOX", "DEAD"]:
		tag = "DEAD"
	if tag != "":
		var col := KNOCKED_COL if tag == "KNOCKED" else DEAD_COL
		HudStyle.text(H.c, Vector2(pr.end.x + 8.0, r.position.y + 4.0), tag, TAG_PX, col, 4, HudStyle.big_italic())
		_arrow(H.c, Vector2(r.end.x + ARROW_GAP, r.get_center().y), col, tag == "DEAD")
		line_x += ARROW.x + ARROW_GAP
	var ln: Dictionary = lines.get(h.nid, {})
	if ln.is_empty():
		return
	var a := LINE_A * clampf((LINE_S - float(ln["t"])) / FADE, 0.0, 1.0)
	H._text(Vector2(line_x, r.position.y + 34.0), String(ln["text"]), LINE_PX, Color(ln["col"], a), H.big)

## A white arrow (greyed for the dead) with its tip at `tip`, pointing left at the row, an X of `col` in it.
func _arrow(c: CanvasItem, tip: Vector2, col: Color, dim: bool) -> void:
	var back := tip.x + ARROW.x
	var half := ARROW.y * 0.5
	var shape := PackedVector2Array([tip, Vector2(tip.x + half, tip.y - half), Vector2(back, tip.y - half),
		Vector2(back, tip.y + half), Vector2(tip.x + half, tip.y + half)])
	c.draw_colored_polygon(shape, Color(0.62, 0.64, 0.7) if dim else Color.WHITE)
	var at := Vector2(tip.x + ARROW.x * 0.6, tip.y)
	var k := half * 0.5
	var x_col := col.darkened(0.3) if dim else col
	c.draw_line(at - Vector2(k, k), at + Vector2(k, k), x_col, 4.0, true)
	c.draw_line(at + Vector2(-k, k), at + Vector2(k, -k), x_col, 4.0, true)

func _changed(h: Hunter, was: String, now: String) -> void:
	if now == "ALIVE" and was in ["WISP", "DEATHBOX"]:
		_say(h, "back up", HudStyle.REVIVE)
		Sfx.play("revive", null, -6.0)
	elif now in ["DEATHBOX", "DEAD"] and was in ["WISP", "ALIVE"]:
		_say(h, "eliminated", HudStyle.FOE)
		Sfx.play("warn", null, -8.0, 0.0, 0.6)
	elif was == "DEATHBOX" and now == "DEAD":
		_say(h, "soul lost", HudStyle.MUTED)

func _say(h: Hunter, text: String, col: Color) -> void:
	lines[h.nid] = {"text": text, "col": col, "t": 0.0}
