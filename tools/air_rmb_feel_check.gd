extends RefCounted
## --air-rmb-feel-check: Kael's jump -> RMB at the apex through the real input path (inp "jump", then inp "sec"
## at the top of the jump), one row per 60 Hz step from the press: height, speed, the Meteor Drop's phase, the
## animation and the hit. Two runs: the Drop ready, and resting (the air press is then the ground Smash).
## Asserts the Drop acts on the step it arrives and lands inside its hang plus the source's 30 m/s fall, the run-up's
## momentum is kept to the press, and a resting press starts the Smash by the tap's release (the source's air
## Smash has the same 0.3 s tap/hold split). docs/MOVEMENT_FEEL.d/1126-jump-air-rmb.md has the numbers.

const AKCheck := preload("res://tools/archetype_check.gd")
const PRESS_TO_HIT_MAX := 0.2  # s: the 0.08 s hang, then a jump's 1.9 m at [game data] 30 m/s (5 frames at least)
const LOG_S := 0.7  # s of rows printed after the press

var ak: AKCheck


func run(main_node: Node) -> void:
	main_node.set_meta("air_rmb_feel_check", self)
	ak = AKCheck.new()
	ak.main = main_node
	var ready_row: Dictionary = _trial(true)
	ak.ok("air rmb: the Drop starts on the press step", ready_row["act_steps"] == 0, str(ready_row["act_steps"]))
	ak.ok(
		"air rmb: press to hit within %.2fs from the apex" % PRESS_TO_HIT_MAX,
		ready_row["hit_s"] > 0.0 and ready_row["hit_s"] <= PRESS_TO_HIT_MAX,
		"%.3fs" % ready_row["hit_s"]
	)
	ak.ok(
		"air rmb: the run-up speed is still there at the press",
		ready_row["v_press"] >= 0.9 * ready_row["v_run"],
		"%.2f of %.2f m/s" % [ready_row["v_press"], ready_row["v_run"]]
	)
	var rest_row: Dictionary = _trial(false)
	var rest_steps: int = rest_row["act_steps"]
	ak.ok("air rmb (Drop resting): a tap's Smash starts on its release", rest_steps <= 1, str(rest_steps))
	print("AKCHECK DONE, %d checks, failures: %d" % [ak.n, ak.fails])
	main_node.get_tree().quit(1 if ak.fails > 0 else 0)


## Runs up, jumps, presses RMB at the apex and logs every step from the press. Returns the summary row.
func _trial(drop_ready: bool) -> Dictionary:
	var r := ak.setup("juggernaut", 5.0)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var dummy: Hunter = r[2]
	var kit: JuggernautKit = hunter.ak
	ak.aim_at(hunter, hunter.pos + Vector3(9.0, 0, 0))
	kit.cd["air"] = 0.0 if drop_ready else 5.0
	hunter.inp["move"] = Vector2(1, 0)
	ak.step(m, 0.5)
	var v_run := Vector2(hunter.vel.x, hunter.vel.z).length()
	hunter.inp["jump"] = true
	m.step(ak.DT)
	hunter.inp["jump"] = false
	var guard := 0
	while hunter.vel.y > 0.0 and guard < 120:
		m.step(ak.DT)
		guard += 1
	var v_press := Vector2(hunter.vel.x, hunter.vel.z).length()
	dummy.teleport(kit.meteor.point())  # where the Drop pressed now hits
	var hp0 := dummy.hp
	var acted := -1
	var hit_s := -1.0
	print("AIRRMB %s  run %.2f m/s, apex %.2f m" % ["ready" if drop_ready else "resting", v_run, hunter.pos.y])
	print("AIRRMB  step     t     y   vy    vh  phase    anim             slam  hit")
	for i in int(LOG_S / ak.DT):
		hunter.inp["sec"] = i == 0
		hunter.inp["sec_hold"] = i == 0
		m.step(ak.DT)
		var busy := kit.meteor.running() or not kit.slam_w.is_empty()
		if acted < 0 and busy:
			acted = i
		if hit_s < 0.0 and dummy.hp < hp0:
			hit_s = (i + 1) * ak.DT
		print(
			(
				"AIRRMB  %3d  %.3f  %.2f  %5.1f  %4.1f  %-7s  %-15s  %-4s  %s"
				% [
					i,
					(i + 1) * ak.DT,
					hunter.pos.y,
					hunter.vel.y,
					Vector2(hunter.vel.x, hunter.vel.z).length(),
					kit.meteor.phase,
					kit.anim_id,
					"yes" if not kit.slam_w.is_empty() else "",
					"HIT" if dummy.hp < hp0 else ""
				]
			)
		)
	hunter.inp["move"] = Vector2.ZERO
	m.queue_free()
	return {"act_steps": acted, "hit_s": hit_s, "v_run": v_run, "v_press": v_press}
