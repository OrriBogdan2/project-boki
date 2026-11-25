class_name AliveCounter
## The match HUD's counters. Top right: your own match numbers as one row, a small icon over its number for
## knocks, kills, assists and damage dealt, a thin line under the icons, then your gems to the right (held back
## for a new player: HudGroups.own_numbers_shown); the kill feed hangs under it. Right of the minimap: a small
## stack of how many squads and how many players are still in the match (a squad icon and a number, a person icon
## and a number; solos show players only). Never who is left. Drawn by Hud.

const STAT_CELL := Vector2(38.0, 36.0)  # units (1280x720 layout), one of your numbers: icon over number
const STAT_ICON_R := 6.5  # units, the small icons
const STAT_PX := 12  # px, the numbers under them
const GEM_W := 66.0  # units, the currency counter right of the four
const GEM_PX := 16  # px
const STACK_CELL := Vector2(52.0, 24.0)  # units, one of squads / players left (icon + number)
const STACK_PX := 16  # px
const STACK_GAP := 4.0  # units between the two
const STACK_AT := 8.0  # units, right of the minimap


## Squads with at least one Hunter still in the match.
static func squads_left(m: Match) -> int:
	var mask := 0
	for h in m.hunters:
		if not h.out and not h.extracted:
			mask |= 1 << h.team
	var n := 0
	while mask != 0:
		n += mask & 1
		mask >>= 1
	return n


## Hunters (yours, rivals', bots) still in the match; a downed one counts until they are out.
static func players_left(m: Match) -> int:
	var n := 0
	for h in m.hunters:
		if not h.out and not h.extracted:
			n += 1
	return n


## Solo matches show players only: a count of squads that equals the count of players is noise.
static func shows_squads(m: Match) -> bool:
	return int(m.opts.get("squad", 1)) > 1


## Your numbers row for a window of size `sz`: the four stats and the gem counter, hung from the top-right corner
## of the HUD's edge margin (HudStyle.hud_pad).
static func stats_rect(sz: Vector2) -> Rect2:
	var pad := HudStyle.hud_pad(sz)
	var w := STAT_CELL.x * 4.0 + GEM_W
	return Rect2(Vector2(sz.x - pad.x - w, pad.y), Vector2(w, STAT_CELL.y))


## Draws your numbers row; returns the y the kill feed starts at.
static func draw(c: Control, m: Match) -> float:
	var p: Hunter = m.player
	if not HudGroups.own_numbers_shown(p, MapDetail.holding()):
		return HudStyle.hud_pad(c.size).y  # a new player's zeros wait for the first kill, knock or gem (HudGroups)
	var r := stats_rect(c.size)
	SafeArea.note(r)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(1, 1, 1, 0.16), 1), r)
	var big := HudStyle.BIG
	var mine := [
		["burst", p.knocks, Color("ffd27a")],
		["knock", p.kills, Color("ff9a8a")],
		["bond", p.assists, Color("9fdcff")],
		["claw", int(p.dmg_done), HudStyle.INK],
	]
	for i in mine.size():
		var mid := r.position.x + STAT_CELL.x * (float(i) + 0.5)
		Icons.draw(c, String(mine[i][0]), Vector2(mid, r.position.y + 10.0), STAT_ICON_R, Color(mine[i][2], 0.9))
		HudStyle.ctext(c, Vector2(mid, r.position.y + 30.0), str(mine[i][1]), STAT_PX, mine[i][2], 3, big)
	var row_w := STAT_CELL.x * 4.0
	var line_y := r.position.y + 19.0
	c.draw_line(
		Vector2(r.position.x + 5.0, line_y), Vector2(r.position.x + row_w - 5.0, line_y), Color(1, 1, 1, 0.18), 1.0
	)
	c.draw_line(
		Vector2(r.position.x + row_w, r.position.y + 7.0),
		Vector2(r.position.x + row_w, r.end.y - 7.0),
		Color(1, 1, 1, 0.16),
		1.0
	)
	Icons.draw(c, "gem", Vector2(r.position.x + row_w + 14.0, r.get_center().y), 7.0, HudStyle.GOLD)
	HudStyle.text(
		c, Vector2(r.position.x + row_w + 25.0, r.get_center().y + 6.0), str(p.gems), GEM_PX, HudStyle.GOLD, 3, big
	)
	return r.end.y + 8.0


## Squads left and players left, a vertical stack right of the minimap `mm` (a solo match: players only).
static func draw_left(c: Control, m: Match, mm: Rect2) -> void:
	var plain: bool = not (m.duel or m.tut or m.opts.get("arena", false) or m.opts.get("training", false))
	if not (plain and HudReveal.on(m, "counters")) or m.player == null or m.player.riding or m.player.dropping:
		return
	var cells: Array = []
	if shows_squads(m):
		cells.append(["squad", str(squads_left(m))])
	cells.append(["person", str(players_left(m))])
	for i in cells.size():
		var r := Rect2(mm.position + Vector2(mm.size.x + STACK_AT, (STACK_CELL.y + STACK_GAP) * i), STACK_CELL)
		SafeArea.note(r)
		c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(1, 1, 1, 0.16), 1), r)
		Icons.draw(c, String(cells[i][0]), r.position + Vector2(13.0, STACK_CELL.y * 0.5), 7.0, HudStyle.INK)
		HudStyle.text(c, r.position + Vector2(26.0, 18.0), String(cells[i][1]), STACK_PX, HudStyle.INK, 4, HudStyle.BIG)
