class_name QuestTracker
extends RefCounted
## The quest tracker under the Ways Out strip. DECISIONS 11-10: a quest exit is a race, the first squad to finish
## it leaves; 11-08: show only what is needed now. While your squad is on a quest seat (QuestSeats: IN_USE
## with your squad, sealed in with the Sealed Lair's boss or charging the Uplink), one compact card: the quest in
## plain words, your squad's progress, the leading rival squad's progress on a quest seat as a thin second bar,
## and how far you are from the site. Hidden otherwise, and while the boss bar is up: inside the fight that bar is
## the objective and shows the same progress. Reads Exits.seats; drawn with HudStyle on the Hud's canvas.

const GAP := 3.0  # px between the strip and the card
const H := 28.0  # px: the card's height, so it ends above the message lane (Hud.msgs.top, y 84)
const PAD := 10.0  # px inside the card, left and right
const BASE_Y := 13.0  # px from the card's top to the text's baseline
const BAR_Y := 17.0  # px from the card's top to your squad's bar
const BAR_H := 4.0  # px: your squad's bar
const RIVAL_H := 2.0  # px: the leading rival's bar, 2 px under yours
const FS := 12  # font px of the words and the numbers
const LABEL_FS := 11  # font px of the seat's name
const WORDS := {"lair": ["SEALED LAIR", "Defeat the boss"], "uplink": ["UPLINK", "Hold the yard to charge it"]}


## The quest seat this squad is on now, or null (also outside Ways Out).
static func seat_of(m: Match, team: int) -> QuestSeat:
	if m.exits == null or m.exits.seats == null:
		return null
	for s: QuestSeat in m.exits.seats.seats():
		if s.state == QuestSeat.S.IN_USE and s.team == team:
			return s
	return null


## The quest seat a rival of this squad is on that is furthest along, or null when no rival is on one.
static func rival_seat(m: Match, team: int) -> QuestSeat:
	if m.exits == null or m.exits.seats == null:
		return null
	var best: QuestSeat = null
	for s: QuestSeat in m.exits.seats.seats():
		var rival_on_it := s.state == QuestSeat.S.IN_USE and s.team >= 0 and s.team != team
		if rival_on_it and (best == null or progress(m, s) > progress(m, best)):
			best = s
	return best


## How far the squad on `s` is, 0 to 1: the uplink's charge, or the health taken off the lair's boss.
static func progress(m: Match, s: QuestSeat) -> float:
	if s.kind == "uplink":
		return clampf(float(s.ref.get("prog", 0.0)), 0.0, 1.0)
	var b: Boss = m.lairs.boss_of(s.ref) if m.lairs else null
	if b == null or b.max_hp <= 0.0:
		return 0.0
	return clampf(1.0 - b.hp / b.max_hp, 0.0, 1.0)


## The card's numbers: your squad's progress, the leading rival's (when one is on a quest seat) and how far the
## player is from the site.
static func numbers(m: Match, s: QuestSeat, rival: QuestSeat) -> String:
	var t := "%d%%" % roundi(progress(m, s) * 100.0)
	if rival:
		t += "  ·  rival %d%%" % roundi(progress(m, rival) * 100.0)
	return t + "  ·  %d m" % roundi(m.player.flat_dist(s.site()))


## Draws the card under the Ways Out strip (`strip`, its rect) for the player's squad, or nothing.
static func draw(hud, strip: Rect2) -> void:
	var m: Match = hud.m
	var p: Hunter = m.player
	if p == null or p.out or p.extracted:
		return
	var s := seat_of(m, p.team)
	if s == null or (m.lairs and m.lairs.boss_for(p) != null):
		return
	var rival := rival_seat(m, p.team)
	var c: Control = hud.c
	var r := Rect2(Vector2(strip.position.x, strip.end.y + GAP), Vector2(strip.size.x, H))
	SafeArea.note_as("quest_tracker", r)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(1, 1, 1, 0.14), 1), r)
	var squad := _squad_col(p.team)
	var words: Array = WORDS[s.kind]
	var base := r.position.y + BASE_Y
	HudStyle.text(c, Vector2(r.position.x + PAD, base), words[0], LABEL_FS, squad, 3)
	var wx := r.position.x + PAD + TextCache.width(HudStyle.BIG, words[0], LABEL_FS) + 8.0
	HudStyle.text(c, Vector2(wx, base), words[1], FS, HudStyle.INK, 3, HudStyle.BODY)
	var nums := numbers(m, s, rival)
	var nx := r.end.x - PAD - TextCache.width(HudStyle.BIG, nums, FS)
	HudStyle.text(c, Vector2(nx, base), nums, FS, HudStyle.INK, 3)
	var bar := Rect2(r.position + Vector2(PAD, BAR_Y), Vector2(r.size.x - PAD * 2.0, BAR_H))
	HudStyle.strip(c, bar, progress(m, s), squad)
	if rival:
		var thin := Rect2(bar.position + Vector2(0.0, BAR_H + 2.0), Vector2(bar.size.x, RIVAL_H))
		HudStyle.strip(c, thin, progress(m, rival), _squad_col(rival.team))


static func _squad_col(team: int) -> Color:
	return Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()]
