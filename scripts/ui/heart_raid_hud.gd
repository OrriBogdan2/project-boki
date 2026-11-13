class_name HeartRaidHud
extends RefCounted
## Heart Raid's strip at the top of the screen (in place of the Ways Out strip, WaysOutHud.draw): what the
## raid wants from you now, in one line, over a thin bar, and the coming wave's gates on the minimap (a badge
## with its countdown arc, HeartRaidGates). Reads Match.heart_raid only.
##   WAVES  "Wave 3 of 8  ·  next in 0:42  ·  7 monsters"   bar: waves sent
##          "Wave 4 out of the marks in 0:08"                (warn_s before a wave: its gates are marked)
##   BOSS   "Bring down Blighted Cairnback"                bar: the boss's health (the boss bar shows more)
##   HOLD   "Hold the Heart ring  ·  45%"                  bar: the ring's fill

const SIZE := Vector2(380.0, 44.0)
const TOP_Y := 8.0
const TITLE_FS := 11
const LINE_FS := 14

static func draw(hud) -> void:
	var m: Match = hud.m
	var rd: HeartRaid = m.heart_raid
	if rd.phase == HeartRaid.P.BOSS and m.lairs.boss_for(m.player) != null:
		return      # the boss bar has the top of the screen
	var c: Control = hud.c
	var r := Rect2(Vector2(c.size.x * 0.5 - SIZE.x * 0.5, TOP_Y), SIZE)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(HeartRaid.COL, 0.45), 1), r)
	var title := "HEART RAID  ·  %s  ·  SQUAD OF %d" % [HeartRaid.diff_name(rd.difficulty).to_upper(), rd.squad_n]
	HudStyle.ctext(c, Vector2(r.get_center().x, r.position.y + 14), title, TITLE_FS, HeartRaid.COL, 3)
	HudStyle.ctext(c, Vector2(r.get_center().x, r.position.y + 32), line(rd), LINE_FS, HudStyle.INK, 3)
	var bar := Rect2(Vector2(r.position.x + 12, r.end.y - 5), Vector2(r.size.x - 24, 3))
	c.draw_rect(bar, Color(1, 1, 1, 0.12))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill(rd), bar.size.y)), HeartRaid.COL)

static func line(rd: HeartRaid) -> String:
	match rd.phase:
		HeartRaid.P.WAVES:
			if _marked(rd):
				return "Wave %d out of the marks in %s" % [rd.wave + 1, _clock(rd.gates.left())]
			var s := "Wave %d of %d" % [rd.wave, rd.waves_n()] if rd.wave > 0 else "The Blight stirs"
			if rd.wave < rd.waves_n():
				s += "  ·  next in %s" % _clock(rd.next_wave_t - rd.m.sess_time())
			else:
				s += "  ·  the boss is coming"
			return s + ("  ·  %d monsters" % rd.foes.size() if rd.host() else "")
		HeartRaid.P.BOSS:
			return "Bring down %s" % rd.rules()["boss"]["name"]
		HeartRaid.P.HOLD:
			return "Hold the Heart ring  ·  %d%%" % int(rd.m.heart.final_prog * 100.0)
		HeartRaid.P.WON:
			return "The Heart is held"
	return "The raid has fallen"

static func fill(rd: HeartRaid) -> float:
	match rd.phase:
		HeartRaid.P.WAVES:
			return float(rd.wave) / float(rd.waves_n())
		HeartRaid.P.BOSS:
			return clampf(rd.boss.hp / rd.boss.max_hp, 0.0, 1.0) if rd.boss and is_instance_valid(rd.boss) else 0.0
		HeartRaid.P.HOLD:
			return rd.m.heart.final_prog
	return 1.0

static func _clock(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	return "%d:%02d" % [s / 60, s % 60]

## The coming wave's gates are marked (its countdown is on).
static func _marked(rd: HeartRaid) -> bool:
	return rd.phase == HeartRaid.P.WAVES and rd.gates.marked_wave == rd.wave and rd.gates.left() > 0.0

## The coming wave's gates on the minimap: a ring with the countdown's arc filling to the wave.
static func minimap(hud, to_map: Callable, on_map: Callable) -> void:
	var rd: HeartRaid = hud.m.heart_raid
	if not _marked(rd):
		return
	var f := clampf(1.0 - rd.gates.left() / HeartRaid.r("warn_s"), 0.0, 1.0)
	for mk in rd.gates.marks:
		var pv: Vector2 = to_map.call(mk["at"])
		if not on_map.call(pv, 7.0):
			continue
		hud.c.draw_arc(pv, 7.0, 0, TAU, 24, Color(0, 0, 0, 0.7), 4.0, true)
		hud.c.draw_arc(pv, 7.0, -PI * 0.5, -PI * 0.5 + TAU * f, 24, HeartRaid.COL, 2.5, true)
