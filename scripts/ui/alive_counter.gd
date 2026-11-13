class_name AliveCounter
## Top right of the match HUD: how many squads and how many players are still in the match (a squad
## icon and a number, a person icon and a number; solos show players only), and under it your own
## kills, knocks and gems in a quieter row. Never who is left. Drawn by Hud; the kill feed hangs under it.

const BIG_CELL := Vector2(78.0, 44.0)    # px, one big counter (icon + number)
const BIG_PX := 26           # px, the big numbers
const SMALL_CELL := Vector2(54.0, 26.0)  # px, one of your own numbers
const SMALL_PX := 14         # px
const GAP := 6.0             # px between the two rows

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

## Draws both rows; returns the y the kill feed starts at.
static func draw(c: Control, m: Match) -> float:
	var big := HudStyle.BIG
	var cells: Array = []
	if shows_squads(m):
		cells.append(["squad", str(squads_left(m))])
	cells.append(["person", str(players_left(m))])
	var bw := BIG_CELL.x * cells.size()
	var pad := HudStyle.safe_pad(c.size)
	var r := Rect2(Vector2(c.size.x - pad.x - bw, pad.y), Vector2(bw, BIG_CELL.y))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 10, Color(1, 1, 1, 0.16), 1), r)
	for i in cells.size():
		var x := r.position.x + BIG_CELL.x * i
		Icons.draw(c, String(cells[i][0]), Vector2(x + 22, r.position.y + BIG_CELL.y * 0.5), 11.0, HudStyle.INK)
		HudStyle.text(c, Vector2(x + 38, r.position.y + 31), String(cells[i][1]), BIG_PX, HudStyle.INK, 4, big)
		if i > 0:
			c.draw_line(Vector2(x, r.position.y + 8), Vector2(x, r.end.y - 8), Color(1, 1, 1, 0.16), 1.0)
	var p: Hunter = m.player
	var kills := p.kills if p else 0
	var knocks := p.knocks if p else 0
	var gems := p.gems if p else 0
	var mine := [["knock", kills, Color("ff9a8a")], ["burst", knocks, Color("ffd27a")], ["gem", gems, HudStyle.GOLD]]
	var sw := SMALL_CELL.x * mine.size()
	var sr := Rect2(Vector2(c.size.x - pad.x - sw, r.end.y + GAP), Vector2(sw, SMALL_CELL.y))
	c.draw_style_box(HudStyle.box(Color(0.05, 0.03, 0.08, 0.7), 8, Color(0, 0, 0, 0), 0), sr)
	for i in mine.size():
		var x := sr.position.x + SMALL_CELL.x * i
		var at := Vector2(x + 14, sr.position.y + SMALL_CELL.y * 0.5)
		Icons.draw(c, String(mine[i][0]), at, 6.0, Color(mine[i][2], 0.85))
		HudStyle.text(c, Vector2(x + 24, sr.position.y + 19), str(mine[i][1]), SMALL_PX, mine[i][2], 3, big)
	return sr.end.y + 10.0
