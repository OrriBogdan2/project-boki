extends "res://tools/abyss_check.gd"
## --abyss-fall-check: a walk off an island's lip against the source [game data], at the match camera:
##  1. the fall: on the speed cap inside a second (12 m/s at the lip easing to 10 m/s by 16.5 m under,
##     AbyssFallSlow: the cap has eased to ~11.3 by the time gravity gets you there), about 2 s from the lip
##     to the point of no return
##  2. control: the keys barely steer a fall (AirControl 0.015 of your ground acceleration): held back toward
##     the island you still drift away and are lost; only the glider, or a ledge in reach, saves you
##  3. the camera: the usual view down to 1 m under the lip, then it pulls out with your depth (eased, never
##     a pop) to most of the abyss zoom by the bottom, and is back to the usual view 1.5 s after the lift
##     carries you over the lip
##  4. the save: glide pressed 15 m under brings you back over the lip, overheated too (half strength, slower)
## Prints "ACHECK ok|FAIL ..." lines, a depth table and "ACHECK DONE, failures: N".

const SAVE_DEPTH := 15.0        # m under the lip the late glider is pressed at
const SAVE_WAIT := 2.5          # s the lift has to reach the lip in
const BACK_AT_LIP := 1.5        # s over the lip for the view to be back to the usual one
const ROW_EVERY := 0.25         # s between the printed rows
const KEYS_AT := 0.3            # s into the fall the key goes down (right at the rim a key still reads as a
								# push into the ledge and its float takes you: --abyss-check)

## Walks off rim `e`, then falls with `keys` held from KEYS_AT on; glide is pressed `glide_at` m under the
## lip (0: never) with `fuel` heat. Rows of [t since the lip, depth, vy, camera abyss zoom] each step, plus
## what happened.
func _fall(e: Dictionary, keys: Vector2, glide_at: float, fuel: float) -> Dictionary:
	var d: Vector2 = e["dir"]
	var top: float = e["top"]
	_reset(Vector3(e["ex"] - d.x * 1.2, top, e["ez"] - d.y * 1.2), Vector3.ZERO)
	h.grounded = true
	h.last_gy = top
	m.cam.abyss_k = 0.0
	var r := {"rows": [], "fell": false, "fall_t": -1.0, "press_t": -1.0, "lip_t": -1.0, "low": 0.0,
		"out": 0.0, "side": 0.0, "land": false, "zoom_back": 9.0}
	var t0 := -1.0
	var t := 0.0
	while t < 8.0:
		var depth := top - h.pos.y
		var held := keys if t - t0 >= KEYS_AT else Vector2.ZERO
		h.inp["move"] = d if t0 < 0.0 else held
		h.inp["glide"] = t0 >= 0.0 and glide_at > 0.0 and (depth >= glide_at or h.gliding)
		if h.inp["glide"] and fuel <= 0.0:
			h.glide_fuel = 0.0
		if h.inp["glide"] and float(r["press_t"]) < 0.0:
			r["press_t"] = t - t0
		m.step(Match.DT)
		_frame(Match.DT)
		t += Match.DT
		if h.pos.distance_to(marker) < 0.01:
			r["fell"] = true
			r["fall_t"] = t - t0
			break
		if t0 < 0.0:
			if not h.grounded and w.is_void(h.pos.x, h.pos.z):
				t0 = t
			continue
		depth = top - h.pos.y
		r["rows"].append([t - t0, depth, h.vel.y, m.cam.abyss_wide()])
		r["low"] = maxf(float(r["low"]), depth)
		var off := Vector2(h.pos.x, h.pos.z) - Vector2(e["ex"], e["ez"])
		r["out"] = off.dot(d)
		r["side"] = off.dot(Vector2(-d.y, d.x))
		if not w.is_void(h.pos.x, h.pos.z):
			r["land"] = true
		if float(r["lip_t"]) < 0.0 and h.gliding and h.pos.y >= top - 0.5:
			r["lip_t"] = t - t0
		if float(r["lip_t"]) >= 0.0 and t - t0 >= float(r["lip_t"]) + BACK_AT_LIP:
			r["zoom_back"] = m.cam.abyss_wide()
			break
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	return r

func _table(rows: Array) -> void:
	var next := 0.0
	for row in rows:
		if float(row[0]) + 0.001 >= next:
			print("ACHECK   t %.2f  depth %5.1f m  vy %6.2f m/s  cam x%.3f" % [row[0], row[1], row[2], row[3]])
			next += ROW_EVERY

## 1. the fall and 3. the camera on the way down, from the rows of a no-keys fall.
func _check_fall(fall: Dictionary) -> void:
	var rows: Array = fall["rows"]
	_table(rows)
	var zmax := HunterMove.abyss_cam_zoom
	var step_max := zmax * (1.0 - exp(-HunterMove.abyss_cam_ease * Match.DT)) + 1e-4
	var deep := HunterMove.abyss_slow_to - 0.5
	var t_cap := -1.0        # when the fall first rides the cap (at that depth)
	var vy_deep := 0.0
	var zoom_lip := 1.0
	var zoom_end := 1.0
	var pop := 0.0
	var dip := 0.0
	var last_z := 1.0
	for row in rows:
		var band := HunterMove.abyss_band(float(row[1]))
		var cap_here := lerpf(HunterMove.fall_max, HunterMove.abyss_fall_max, band)
		if t_cap < 0.0 and float(row[2]) <= -(cap_here - 0.1):
			t_cap = row[0]
		if float(row[1]) >= deep:
			vy_deep = row[2]
		if float(row[1]) <= HunterMove.abyss_slow_from:
			zoom_lip = maxf(zoom_lip, float(row[3]))
		pop = maxf(pop, float(row[3]) - last_z)
		dip = maxf(dip, last_z - float(row[3]))
		last_z = row[3]
		zoom_end = row[3]
	ok(fall["fell"], "a walk off the lip with no keys is lost to the abyss after %.2f s" % fall["fall_t"])
	ok(t_cap > 0.0 and t_cap < 1.0, "the fall is on the speed cap in %.2f s" % t_cap)
	var slow := HunterMove.abyss_fall_max
	var deep_txt := "...and has eased to %.1f m/s %.1f m under (AbyssFallSlow %.0f -> %.0f)"
	deep_txt = deep_txt % [-vy_deep, deep, HunterMove.fall_max, slow]
	ok(vy_deep < 0.0 and -vy_deep <= slow + 0.35 and -vy_deep >= slow - 0.4, deep_txt)
	var fall_t := float(fall["fall_t"])
	ok(fall_t >= 1.8 and fall_t <= 2.3, "the lip to the point of no return takes %.2f s (1.8-2.3)" % fall_t)
	var lip_txt := "the view is the usual one down to %.0f m under the lip (x%.3f)"
	ok(zoom_lip <= 1.001, lip_txt % [HunterMove.abyss_slow_from, zoom_lip])
	var end_txt := "it has pulled out to x%.3f by the point of no return (>= x%.3f)"
	ok(zoom_end >= 1.0 + zmax * 0.6, end_txt % [zoom_end, 1.0 + zmax * 0.6])
	ok(dip <= 1e-4, "the pull-out never backs off on the way down (%.4f)" % dip)
	ok(pop <= step_max, "the pull-out eases, never pops (%.4f per step, cap %.4f)" % [pop, step_max])

## 2. control: a key sideways moves you no more than AirControl allows; a key back doesn't bring you back.
func _check_control(e: Dictionary) -> void:
	var d: Vector2 = e["dir"]
	var side := _fall(e, Vector2(-d.y, d.x), 0.0, 1.0)
	var held := float(side["fall_t"]) - KEYS_AT
	var steer := h.ground_accel * HunterMove.air_control * held * held * 0.5
	var moved := absf(float(side["side"]))
	var side_txt := "a key held sideways from %.1f s moves you %.2f m by the end (AirControl: at most %.2f m)"
	ok(side["fell"] and moved > 0.05 and moved <= steer + 0.1, side_txt % [KEYS_AT, moved, steer])
	var back := _fall(e, -d, 0.0, 1.0)
	var back_txt := "held back toward the island from %.1f s you still drift away (%.1f m out) and are lost"
	ok(back["fell"] and not back["land"] and float(back["out"]) > 2.0, back_txt % [KEYS_AT, back["out"]])

## 4. the save, and 3. the camera on the way back.
func _check_save(e: Dictionary) -> void:
	var full := _fall(e, Vector2.ZERO, SAVE_DEPTH, 1.0)
	var hot := _fall(e, Vector2.ZERO, SAVE_DEPTH, 0.0)
	var full_up := float(full["lip_t"]) - float(full["press_t"])
	var hot_up := float(hot["lip_t"]) - float(hot["press_t"])
	var row := "ACHECK glide pressed %.1f s after the lip, %.0f m under: cool heat lifts to the lip in %.2f s"
	row += " (low %.1f m), overheated in %.2f s (low %.1f m)"
	print(row % [full["press_t"], SAVE_DEPTH, full_up, full["low"], hot_up, hot["low"]])
	var saved: bool = not full["fell"] and float(full["lip_t"]) > 0.0 and full_up <= SAVE_WAIT
	ok(saved, "glide pressed %.0f m under brings you back over the lip" % SAVE_DEPTH)
	var saved_hot: bool = not hot["fell"] and float(hot["lip_t"]) > 0.0 and hot_up <= SAVE_WAIT
	ok(saved_hot, "...an overheated glider too (half strength)")
	ok(hot_up > full_up * 1.3, "...slower than a cool one (%.2f vs %.2f s)" % [hot_up, full_up])
	var low := float(hot["low"])
	ok(low < KILL_DEPTH, "...without crossing the point of no return (%.1f m < %.1f)" % [low, KILL_DEPTH])
	var back_txt := "the view is back to the usual one %.1f s after the lift carries you over the lip (x%.3f)"
	ok(float(full["zoom_back"]) <= 1.03, back_txt % [BACK_AT_LIP, full["zoom_back"]])

func run(main: Node) -> void:
	_open(main)
	var edges := _edges(6)
	ok(edges.size() > 0, "found test rims (%d)" % edges.size())
	var e: Dictionary = edges[0]
	_check_fall(_fall(e, Vector2.ZERO, 0.0, 1.0))
	_check_control(e)
	_check_save(e)
	m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
