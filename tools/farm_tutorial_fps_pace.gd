extends "res://tools/farm_tutorial_low_fps.gd"
## The garden half of --tutorial-fps-pace-check: the five garden steps (meet, patch, eat, toy, out) played in the
## home's own frame loop at a fixed fps cap (no stalls), with every drawn frame judged: the objective strip
## (the guide's StripView, TutorialStrip geometry) is up while a step is open, and no span over GAP_S has neither the
## strip nor the world marker. `rows` is the table (docs/TUTORIAL_PACE.md section 6).

const PACE := preload("res://tools/tutorial_fps_pace_check.gd")
const BUDGET_S := 20.0  # s a garden step may take (the bot acts at once, so this is the guide's own reaction)

var rows: Array = []
var by_step := {}  # step id -> {frames, miss, gap, worst}
var run_fps := 30


func ok(cond: bool, what: String) -> void:
	print("FPSPACE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


## One round at `fps`: the garden course, then its rows.
func round_at(m: Node, fps: int) -> void:
	main = m
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var quality_was = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "low"
	Settings.apply("quality")
	run_fps = fps
	by_step.clear()
	await _round("garden %d fps" % fps, fps, false)
	Settings.v["quality"] = quality_was
	Settings.apply("quality")
	for id in by_step:
		var s: Dictionary = by_step[id]
		var t := float(s["t"])
		ok(t <= BUDGET_S, "garden %d fps %s: %.1f s, budget %.0f s" % [fps, id, t, BUDGET_S])
		var tag := "garden %d fps %s" % [fps, id]
		ok(float(s["worst"]) <= PACE.GAP_S, "%s: longest span with no prompt %.1f s" % [tag, s["worst"]])
		ok(int(s["miss"]) == 0, "%s: the strip is up on all %d frames (%d without)" % [tag, s["frames"], s["miss"]])
		rows.append(
			[
				"garden",
				str(fps),
				String(id),
				"banner",
				"%.1f" % t,
				"%.0f" % BUDGET_S,
				"%d/%d" % [s["miss"], s["frames"]],
				"%.1f" % s["worst"]
			]
		)


func _frame() -> void:
	await super()
	var id := FarmTutorial.current()
	if id == "" or guide == null or not is_instance_valid(guide):
		return
	var s: Dictionary = by_step.get(id, {"t": 0.0, "frames": 0, "miss": 0, "gap": 0.0, "worst": 0.0})
	by_step[id] = s
	var dt := main.get_tree().root.get_process_delta_time()
	s["t"] += dt
	s["frames"] += 1
	var up := _strip_up(guide)
	if not up:
		s["miss"] += 1
	var marker: bool = is_instance_valid(guide.marker) and guide.marker.visible and guide.marker.text != ""
	s["gap"] = 0.0 if (up or marker) else float(s["gap"]) + dt
	s["worst"] = maxf(float(s["worst"]), float(s["gap"]))


## The garden's strip is on screen: it has its line, it is shown, and its rect is a slim strip in the top band.
static func _strip_up(g: FarmGuide) -> bool:
	if not g.hint_visible() or not g.hint_box.visible or g.hint_text() == "":
		return false
	var sz: Vector2 = g.hint_box.size
	var r: Rect2 = g.hint_box.rect()
	return (
		Rect2(Vector2.ZERO, sz).intersects(r)
		and r.size.y <= sz.y * TutorialStrip.HEIGHT_FRAC + 0.5
		and r.end.y <= sz.y * PACE.TOP_BAND
	)
