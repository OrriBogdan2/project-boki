class_name ObjectiveTracker
extends RefCounted
## Draws the first-expedition objective (FirstObjective): the card under the minimap's clock, a pin or an edge
## arrow in the world on what the line names, and a ring on the minimap. The only state is its edge arrow's layout.

const COL := Color("ffd27a")        # the objective's colour: the pin, the ring and the card's rim
const TICK_COL := Color("8fe3c8")   # a finished step
const CARD_W := 240.0               # px, in HUD units
const CARD_H := 38.0
const TEXT_W := CARD_W - 28.0       # px the line may take (the rim and the right margin)
const GAP := 6.0                    # px under the minimap column
const LINE_PX := 15
const PING_SAME_M := 6.0            # m: a ping this close to the target is on it
const PIPS_R := 3.5                 # px radius of a step pip

static var _edge := EdgeMarker.new()      # the objective's own screen-edge arrow (laid out afresh each frame)

## The card, on the left column under whatever is above it (hud.mm_bottom); moves mm_bottom down.
static func draw(hud) -> void:
	var o: FirstObjective = hud.m.objective
	var p: Hunter = hud.m.player
	if o == null or p == null or p.out or p.extracted or p.dropping or p.riding or not HudReveal.on(hud.m, "objective"):
		return
	var r := Rect2(Vector2(HudStyle.safe_pad(hud.c.size).x, hud.mm_bottom + GAP), Vector2(CARD_W, CARD_H))
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.86), 8)
	hud.c.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(4, r.size.y - 12)), COL)
	var at := r.position + Vector2(16, 28)
	var line := o.text()
	var fit := LINE_PX if TextCache.width(hud.big, line, LINE_PX) < TEXT_W else LINE_PX - 2
	if o.ticked_t > 0.0:      # a step just finished: its tick takes the small label's place
		hud._text(r.position + Vector2(16, 15), "✓  " + o.ticked, 11, TICK_COL, hud.big)
	else:
		hud._text(r.position + Vector2(16, 15), "NEXT", 10, hud.MUTED, hud.big)
	hud._text(at, line, fit, hud.GOLD, hud.big)
	var pr := o.progress()
	for i in pr.y:
		var ctr := Vector2(r.end.x - 14.0 - (pr.y - 1 - i) * 11.0, r.position.y + 11)
		hud.c.draw_circle(ctr, PIPS_R, COL if i <= pr.x else Color(1, 1, 1, 0.18))
	hud.mm_bottom = r.end.y

## The pin over the target (Hud._draw_waypoint), or an arrow at the screen edge when it is off screen. The arrow
## keeps clear of the left column (the minimap, this card, the squad frames), so it has its own rim.
static func world(hud) -> void:
	var o: FirstObjective = hud.m.objective
	var p: Hunter = hud.m.player
	if o == null or p == null or p.out or p.extracted or p.dropping or p.riding or o.exit_pinned():
		return
	var at := o.target_pos()
	if at == Vector3.INF or _pinged(hud.m, at):
		return
	var sz: Vector2 = hud.c.size
	var dir := MarkerDir.off_dir(hud.m.cam, sz, at, p.pos)
	if dir == Vector2.ZERO:
		hud._draw_waypoint(at, o.label(), COL)
		return
	var rim := EdgeMarker.world_rim(sz)
	var left := HudScale.from_edge(MarkerDir.EDGE_LEFT)
	rim.size.x -= left - rim.position.x
	rim.position.x = left
	_edge.begin(rim, hud.WORLD_ARROW)
	_edge.add(dir, COL, EdgeMarker.PRIO_GOAL, o.label(), p.flat_dist(at))
	_edge.draw(hud.c, hud.m.time)

## Is your Boki's own callout (KinCompanion) already marking this spot? Its pin is the same look; one is enough.
static func _pinged(m: Match, at: Vector3) -> bool:
	for pg in m.pings:
		if (pg["pos"] as Vector3).distance_to(at) < PING_SAME_M:
			return true
	return false

## A ring on the minimap over the target (an arrow on its rim when it is off the map).
static func minimap(hud, at: Vector2, on_map: bool, ctr: Vector2) -> void:
	if on_map:
		var pulse := 6.0 + 2.0 * sin(hud.m.time * 5.0)
		hud.c.draw_arc(at, pulse, 0, TAU, 20, COL, 2.5, true)
	else:
		hud.edge_mini.add(at - ctr, COL, EdgeMarker.PRIO_GOAL)
