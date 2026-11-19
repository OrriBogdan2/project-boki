class_name ExtractGoal
extends RefCounted
## The one-line objective under the clock at the top-centre: which way out to go for, where it is and how to use it
## ("Uplink open · 140 m  ·  Hold F at the outpost until the lift opens"). The seat is the open one, else the one
## that opens soonest; taken, lost and in-use seats are not offered (your own quest has the QuestTracker card).
## A new player (HudReveal.newcomer) is only pointed at the seats in hud_groups.json "newcomer_seats" and gets this
## line in place of the four-seat strip. Reads WaysOutHud.seats and WaysOutMap.sites; draws with HudStyle.

const H := 28.0           # px: the pill's height (the QuestTracker card's slot)
const PAD := 12.0         # px inside the pill, left and right
const BADGE_R := 8.0      # px: the seat's map badge, so the line and the map read as the same thing
const GAP := 10.0         # px between the badge, the status and the how

## The seat index the line points at, or -1 when no seat is on offer.
static func pick(m: Match, newcomer: bool) -> int:
	var sd := WaysOutHud.seats(m)
	var at := WaysOutMap.sites(m)
	var allowed: Array = HudGroups.rules()["newcomer_seats"]      # (JSON numbers are floats)
	var best := -1
	var best_k := INF
	for i in 4:
		var st := int(sd[i]["st"])
		if at[i] == Vector3.INF or (newcomer and not float(i) in allowed) or st > WaysOutHud.St.OPEN:
			continue
		var k := float(sd[i]["t"]) if st == WaysOutHud.St.LOCKED else -1.0
		if k < best_k:
			best = i
			best_k = k
	return best

## "Uplink opens 4:12" or "Uplink open · 140 m".
static func status(m: Match, i: int, s: Dictionary) -> String:
	var name: String = WaysOutMap.WORDS[i]
	if int(s["st"]) == WaysOutHud.St.LOCKED:
		var t := int(ceil(float(s["t"])))
		return "%s opens %d:%02d" % [name, t / 60, t % 60]
	return "%s open · %d m" % [name, int(m.player.flat_dist(WaysOutMap.sites(m)[i]))]

static func how(i: int) -> String:
	return String(HudGroups.rules()["goal_how"][i]).replace("%F", Settings.key_cap("interact"))

## Is the line drawn now? Not while your squad is on a quest seat (its own card), you are out, or a raid has its
## own strip.
static func shown(m: Match) -> bool:
	var p: Hunter = m.player
	if p == null or p.out or p.extracted or m.heart_raid or not HudGroups.ways_out_shown(m):
		return false
	return QuestTracker.seat_of(m, p.team) == null

## Draws the pill centred at the top, y = `top`. `dim` fades it back (the strip's slot under it keeps its place).
static func draw(hud, top: float, newcomer: bool) -> void:
	var m: Match = hud.m
	var i := pick(m, newcomer)
	if i < 0 or not shown(m):
		return
	var c: Control = hud.c
	var s: Dictionary = WaysOutHud.seats(m)[i]
	var st := status(m, i, s)
	var how_txt := how(i)
	var sw := TextCache.width(HudStyle.BIG, st, 14)
	var hw := TextCache.width(HudStyle.BODY, how_txt, 13)
	var w := PAD * 2.0 + BADGE_R * 2.0 + GAP + sw + GAP + hw
	var r := Rect2(Vector2(c.size.x * 0.5 - w * 0.5, top), Vector2(w, H))
	SafeArea.note_as("ways_strip", r)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 9, Color(1, 1, 1, 0.14), 1), r)
	var x := r.position.x + PAD
	WaysOutMap.badge(c, Vector2(x + BADGE_R, r.get_center().y), BADGE_R * 0.8, i, s, m.time)
	x += BADGE_R * 2.0 + GAP
	HudStyle.text(c, Vector2(x, r.position.y + 19), st, 14, HudStyle.INK, 3)
	HudStyle.text(c, Vector2(x + sw + GAP, r.position.y + 19), how_txt, 13, HudStyle.MUTED, 3, HudStyle.BODY)
