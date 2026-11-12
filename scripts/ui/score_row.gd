class_name ScoreRow
extends RefCounted
## Top right of the match HUD, after the owner's 11-12 reference (scripts/ui/HUD_SPEC.md): a row of
## counter icons (squads left, your kills, your knocks) on a thin rule with diamond ends, each count
## under its icon; your gems right of it as the big currency number; what you carry home (seeds, the
## capture box, the backpack) in a small line under it. Right-anchored; positions are layout px.

const ICON_Y := 17.0         # icon centres (ref y 27 of the game picture at 2000 wide)
const ICON_S := 6.5          # Icons scale (ref icons ~15 px at 1080p)
const PITCH := 28.0          # px between counters
const FIRST_R := 108.0       # px from the right edge to the rightmost counter's centre
const RULE_Y := 29.5         # the thin rule between icons and counts
const RULE_PAD := 14.0       # px the rule runs past the outer icons
const NUM_Y := 44.0          # counts' baseline
const NUM_FS := 12
const CUR_R := 38.0          # px from the right edge to the currency number's right end
const CUR_Y := 23.0          # its baseline
const CUR_FS := 20
const CUR_COL := Color("e8f8d0")    # sampled
const COIN_R := 22.0         # px from the right edge to the gem's centre
const RULE_COL := Color("9cb8ce")   # sampled
const CARRY_Y := 60.0        # the carry line's baseline
const CARRY_FS := 11
const PAD := 14.0            # px from the right edge

## Draws the row; returns the y under it (where the kill feed starts).
static func draw(H, sz: Vector2) -> float:
	var c: CanvasItem = H.c
	var m: Match = H.m
	var p: Hunter = m.player
	var teams := {}
	for h in m.hunters:
		if not h.out and not h.extracted: teams[h.team] = true
	var cells := [["paw", teams.size(), HudStyle.INK], ["knock", p.kills if p else 0, Color("ff9a8a")],
		["burst", p.knocks if p else 0, Color("ffd27a")]]
	var x_last := sz.x - FIRST_R
	var x_first := x_last - PITCH * (cells.size() - 1)
	c.draw_line(Vector2(x_first - RULE_PAD, RULE_Y), Vector2(x_last + RULE_PAD, RULE_Y), Color(RULE_COL, 0.8), 1.0)
	for x in [x_first - RULE_PAD, x_last + RULE_PAD]:
		_diamond(c, Vector2(x, RULE_Y), 3.0)
	for i in cells.size():
		var x := x_first + PITCH * i
		Icons.draw(c, String(cells[i][0]), Vector2(x, ICON_Y), ICON_S, cells[i][2])
		HudStyle.ctext(c, Vector2(x, NUM_Y), str(cells[i][1]), NUM_FS, HudStyle.INK)
	if p == null:
		return NUM_Y + 10.0
	var gems := "%d" % p.gems
	var gw := TextCache.width(HudStyle.BIG, gems, CUR_FS)
	HudStyle.text(c, Vector2(sz.x - CUR_R - gw, CUR_Y), gems, CUR_FS, CUR_COL if p.gems > 0 else HudStyle.MUTED)
	Icons.draw(c, "gem", Vector2(sz.x - COIN_R, CUR_Y - 7.0), 9.0, HudStyle.GOLD)
	_carry(H, sz, p)
	return CARRY_Y + 8.0

## Seeds and the capture box, then the backpack (slots used, red when full; hover for it).
static func _carry(H, sz: Vector2, p: Hunter) -> void:
	var seeds := 0
	for sd in p.seeds: seeds += int(p.seeds[sd])
	var right := sz.x - PAD
	if not H.m.opts.get("training", false):
		var full := p.pack.size() >= p.pack_cap
		var pcol := HudStyle.INK if p.pack.size() > 0 else HudStyle.MUTED
		if full:
			pcol = Color("ffb0a0")
		var pt := "%d/%d" % [p.pack.size(), p.pack_cap]
		var pw := TextCache.width(HudStyle.BIG, pt, CARRY_FS)
		HudStyle.text(H.c, Vector2(right - pw, CARRY_Y), pt, CARRY_FS, pcol, 3)
		Icons.draw(H.c, "satchel", Vector2(right - pw - 9.0, CARRY_Y - 4.0), 6.0, pcol)
		H.hover_spots.append([Rect2(Vector2(right - pw - 18.0, CARRY_Y - 13.0), Vector2(pw + 20.0, 18)), "pack"])
		right -= pw + 26.0
	var st := "%d seeds · %s" % [seeds, CaptureHud.box_text(p)]
	var sw := TextCache.width(HudStyle.BIG, st, CARRY_FS - 1)
	HudStyle.text(H.c, Vector2(right - sw, CARRY_Y), st, CARRY_FS - 1, CaptureHud.box_col(p, HudStyle.MUTED), 3)

static func _diamond(c: CanvasItem, at: Vector2, r: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r),
			at + Vector2(-r, 0)]), RULE_COL)
