class_name LootFeed
extends Control
## What you just picked up, as a short column at the bottom right over the weapon card: an icon, the
## name and a count per row. The same thing again within MERGE_S adds to its row ("Gems  x12") instead
## of a new one; at most MAX_ROWS rows (a new one pushes the oldest out); each row fades after LIFE.
## Pickups used to toast into the message lane (MsgLane) and all play the one pickup sound; this keeps
## them out of the lane and gives each row its own tick, pitched by rarity. While the lane keeps to its
## fight budget (`fight`, set by Hud like MsgLane.fight) only rare things tick.

const MERGE_S := 2.0       # s: the same thing again within this adds to its row
const MAX_ROWS := 4        # rows on show at most
const LIFE := 3.0          # s a row stays before it fades (a merge starts it again)
const FADE := 0.4          # s of the fade, at the end of LIFE
const RARE := 2            # Data.RARITY index (Rare) from which a pickup ticks even in a fight
const ROW_H := 26.0        # px per row
const ROW_W := 230.0       # px wide
const RIGHT := 18.0        # px from the screen's right edge (the weapon card's margin)
const BOTTOM := 160.0      # px from the screen's bottom: over the slot row above the weapon card
const TICK_DB := -8.0      # the pickup tick's volume
const TICK_PITCH := 0.08   # pitch added per rarity step
const GEM_COL := Color("ffd36a")

var fight := false         ## true while the message lane keeps to its fight budget: only rare things tick
var rows: Array[Dictionary] = []   # newest last: {name, icon, col, n, rar, t}
var font: Font = preload("res://fonts/Rubik.ttf")

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The feed of `h`'s HUD when `h` is the local player, else null (a bot or another player picked it up).
static func of(m: Match, h) -> LootFeed:
	return m.hud.loot if h == m.player and m.hud else null

## A Loot item (gear, a valuable) picked up by `h`. True when it went in the player's feed.
static func got_item(m: Match, h, it: Dictionary) -> bool:
	var feed := of(m, h)
	if feed:
		feed.add(Loot.icon_of(it), Loot.name_of(it), 1, Loot.col_of(it), Loot.rar_of(it))
	return feed != null

## Gems or seeds that `h` walked over (Match._collect); `gems` is how many the gem was worth to them.
static func ground(m: Match, h, p: Dictionary, gems: int) -> void:
	var feed := of(m, h)
	if feed == null:
		return
	match String(p["kind"]):
		"gem": feed.add("gem", "Gems", gems, GEM_COL)
		"seed":
			var crop: Dictionary = Data.CROPS[p["key"]]
			feed.add("seed", "%s seed" % crop["name"], int(p["v"]), crop["color"])

## One pickup: a row, or `n` more on the row of the same name if it came within MERGE_S.
func add(icon: String, nm: String, n: int, col: Color, rar := 0) -> void:
	if n <= 0:
		return
	if audible(fight, rar):
		Sfx.play("pickup", null, TICK_DB, 0.03, 1.0 + TICK_PITCH * rar)
	for r in rows:
		if r["name"] == nm and float(r["t"]) < MERGE_S:
			r["n"] = int(r["n"]) + n
			r["t"] = 0.0
			return
	rows.append({"name": nm, "icon": icon, "col": col, "n": n, "rar": rar, "t": 0.0})
	if rows.size() > MAX_ROWS:
		rows.pop_front()

## Does a pickup of rarity `rar` tick? Always, except in a fight, where only rare things do.
static func audible(in_fight: bool, rar: int) -> bool:
	return not in_fight or rar >= RARE

## The rows' age, the faded ones gone.
func tick(dt: float) -> void:
	if rows.is_empty():
		return
	for r in rows:
		r["t"] = float(r["t"]) + dt
	rows = rows.filter(func(r): return float(r["t"]) < LIFE)
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

## How opaque a row of age `t` is: whole until LIFE - FADE, then down to 0 at LIFE.
static func alpha(t: float) -> float:
	return clampf((LIFE - t) / FADE, 0.0, 1.0)

func _draw() -> void:
	var y := size.y - BOTTOM
	for i in range(rows.size() - 1, -1, -1):      # newest at the bottom
		var r: Dictionary = rows[i]
		var a := alpha(float(r["t"]))
		var col: Color = r["col"]
		var box := Rect2(Vector2(size.x - RIGHT - ROW_W, y - ROW_H), Vector2(ROW_W, ROW_H - 3.0))
		draw_rect(box, Color(HudStyle.SHADE, HudStyle.SHADE.a * a))
		draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), Color(col, a))
		Icons.draw(self, String(r["icon"]), box.position + Vector2(16.0, box.size.y * 0.5), 7.0, Color(col, a))
		var label := String(r["name"]) + ("  x%d" % int(r["n"]) if int(r["n"]) > 1 else "")
		draw_string(font, box.position + Vector2(30.0, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, ROW_W - 36.0, 14,
				Color(col.lerp(Color.WHITE, 0.35), a))
		y -= ROW_H
