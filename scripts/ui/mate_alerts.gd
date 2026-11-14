class_name MateAlerts
extends RefCounted
## A teammate going down, coming back or being lost:
##   - their squad row (SquadFrames) carries it: the state label and portrait tint
##   - one short, faint line beside that row as it happens (LINE_S, at most LINE_A opacity)
##   - a sound cue
## The way to them is the squad arrow at the screen edge (Hud._draw_squad_markers) and their world ping
## (DownedMarks.ally_ping, which pops in from the moment in `since`).

const LINE_S := 1.5            # s a line stays up, fade included
const LINE_A := 0.6            # the line's opacity at most
const LINE_PX := 13            # font px
const FADE := 0.4              # s: the line fades out over its last FADE

var last := {}                 # nid -> the teammate's last squad state (Hud._mate_state label)
var lines := {}                # nid -> {"text", "col", "t"}
var since := {}                # nid -> the match time the teammate went down

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
			if now == "WISP":
				since[h.nid] = H.m.time
			_changed(h, was, now)

## The squad row's part: the line beside the row `r`.
func draw_row(H, r: Rect2, h: Hunter) -> void:
	var ln: Dictionary = lines.get(h.nid, {})
	if ln.is_empty():
		return
	var a := LINE_A * clampf((LINE_S - float(ln["t"])) / FADE, 0.0, 1.0)
	H._text(Vector2(r.end.x + 8.0, r.position.y + 34.0), String(ln["text"]), LINE_PX, Color(ln["col"], a), H.big)

func _changed(h: Hunter, was: String, now: String) -> void:
	if now == "ALIVE" and was in ["WISP", "DEATHBOX"]:
		_say(h, "back up", HudStyle.REVIVE)
		Sfx.play("revive", null, -6.0)
	elif now in ["DEATHBOX", "DEAD"] and was in ["WISP", "ALIVE"]:
		_say(h, "eliminated", SideColor.foe())
		Sfx.play("warn", null, -8.0, 0.0, 0.6)
	elif was == "DEATHBOX" and now == "DEAD":
		_say(h, "soul lost", HudStyle.MUTED)

func _say(h: Hunter, text: String, col: Color) -> void:
	lines[h.nid] = {"text": text, "col": col, "t": 0.0}
