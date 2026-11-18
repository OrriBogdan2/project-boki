extends RefCounted
## The play probe's judge (tools/play_probe.gd): turns one scenario's frame samples into measurements and PASS/FLAG
## lines, and writes play_probe_report.md + play_probe.json. Physics, controls, camera and animation only; damage and
## balance are out of scope. Each FLAG kind has a player-words line and an impact (how much a player would notice).

const DT := 1.0 / 60.0  # s: one frame (the probe runs under --fixed-fps 60)
const STILL := 0.1  # m/s: below this the body counts as stopped
const MOVING := 1.5  # m/s: above this the body counts as moving for the animation checks
const SKATE_RATIO := 0.6  # planted foot speed / body speed above this while running = feet slide
const LATE_S := 0.8  # s after the release: activity past this is the ability still going
const LATE_EVENTS := 2  # activity events past LATE_S that count as "keeps going"
const REST_EPS := 0.004  # rad: a skeleton this close to its rest pose is standing in the T-pose
const CAM_JERK_M := 0.03  # m: the camera's one-frame change of step during a steady run
const BODY_SMOOTH_M := 0.005  # m: the body's own one-frame change of step under this is smooth
const JITTER_M := 0.04  # m: back-and-forth along the push direction while pressed into a wall
## FLAG kind -> [impact 1-10, what a player would say]
const KINDS := {
	"stuck_fire": [9, "the attack keeps going after I let go of the button"],
	"stuck_move": [9, "my hunter keeps walking after I let go of the key"],
	"stuck_geo": [8, "I get stuck on the ground / a wall and can't walk away"],
	"no_control": [8, "after using this I can't move for a while"],
	"glide_stuck": [8, "the glider stays open after I let go of Space or after landing"],
	"through_wall": [7, "I walk or dash into a wall and end up inside it"],
	"out_of_map": [7, "I fell out of the map and nothing brought me back"],
	"tpose": [7, "the hunter snaps into a T-pose"],
	"idle_moving": [6, "the hunter slides along in the idle pose"],
	"offscreen": [6, "the camera loses my hunter"],
	"glide_none": [6, "pressing Space in the air does not open the glider"],
	"tap_none": [5, "tapping this key does nothing"],
	"tap_repeat": [6, "one tap fires again and again"],
	"through_body": [4, "I walk straight through the other hunter / my Boki"],
	"launch": [6, "touching something throws me into the air"],
	"wall_jitter": [5, "pushing into a wall makes my hunter shake"],
	"skate": [4, "the feet slide on the ground while running"],
	"run_in_place": [4, "the legs keep running after I stopped"],
	"slide_stop": [3, "the hunter slides on after I let go"],
	"dash_none": [6, "Shift does not dash"],
	"eaten_input": [5, "pressing this during another move does nothing at all"],
	"cam_jitter": [4, "the camera shakes while I run"],
	"ledge_stop": [3, "a small step up stops me dead"],
}

var rows: Array = []  # {hero, sc, kind, impact, words, detail}
var data := {}  # hero -> scenario -> measurements


## A finding on `hero`'s `sc`.
func flag(hero: String, sc: String, kind: String, detail: String) -> void:
	var k: Array = KINDS[kind]
	rows.append({"hero": hero, "sc": sc, "kind": kind, "impact": int(k[0]), "words": String(k[1]), "detail": detail})
	print("PROBE FLAG %-10s %-18s %-13s %s" % [hero, sc, kind, detail])


func put(hero: String, sc: String, meas: Dictionary) -> void:
	if not data.has(hero):
		data[hero] = {}
	data[hero][sc] = meas
	print("PROBE %s %-10s %-18s %s" % ["FLAG" if flagged(hero, sc) else "PASS", hero, sc, _short(meas)])


func flagged(hero: String, sc: String) -> bool:
	for r in rows:
		if r["hero"] == hero and r["sc"] == sc:
			return true
	return false


# ---------------------------------------------------------------- measurements over samples
static func hspeed(s: Dictionary) -> float:
	var v: Vector3 = s["v"]
	return Vector2(v.x, v.z).length()


## s: frames from `from` until the horizontal speed first reaches `k` of the most it reached in [from, to).
static func rise_s(ss: Array, from: int, to: int, k: float) -> float:
	var top := 0.0
	for i in range(from, mini(to, ss.size())):
		top = maxf(top, hspeed(ss[i]))
	for i in range(from, mini(to, ss.size())):
		if hspeed(ss[i]) >= top * k:
			return (i - from) * DT
	return -1.0


static func top_speed(ss: Array, from: int, to: int) -> float:
	var top := 0.0
	for i in range(from, mini(to, ss.size())):
		top = maxf(top, hspeed(ss[i]))
	return top


## s from `from` until the body is stopped (STILL), -1 for never.
static func stop_s(ss: Array, from: int) -> float:
	for i in range(from, ss.size()):
		if hspeed(ss[i]) < STILL:
			return (i - from) * DT
	return -1.0


static func flat_dist(ss: Array, a: int, b: int) -> float:
	var pa: Vector3 = ss[clampi(a, 0, ss.size() - 1)]["p"]
	var pb: Vector3 = ss[clampi(b, 0, ss.size() - 1)]["p"]
	return Vector2(pb.x - pa.x, pb.z - pa.z).length()


static func peak_y(ss: Array, from: int) -> float:
	var y0: float = (ss[from]["p"] as Vector3).y
	var top := y0
	for i in range(from, ss.size()):
		top = maxf(top, (ss[i]["p"] as Vector3).y)
	return top - y0


## s in the air from `from`: the first ungrounded frame to the next grounded one.
static func air_s(ss: Array, from: int) -> float:
	var up := -1
	for i in range(from, ss.size()):
		if up < 0 and not ss[i]["g"]:
			up = i
		elif up >= 0 and ss[i]["g"]:
			return (i - up) * DT
	return -1.0


## Activity events (shots, swings, casts, kit moves, slot uses) in [a, b).
static func acts(ss: Array, a: int, b: int) -> int:
	var n := 0
	for i in range(maxi(0, a), mini(b, ss.size())):
		n += int(ss[i]["act"])
	return n


## s from `from` to the last frame with activity, -1 for none.
static func last_act_s(ss: Array, from: int) -> float:
	var last := -1
	for i in range(from, ss.size()):
		if int(ss[i]["act"]) > 0:
			last = i
	return (last - from) * DT if last >= 0 else -1.0


## Rising edges of the dash (roll) state in [a, b).
static func dash_starts(ss: Array, a: int, b: int) -> int:
	var n := 0
	for i in range(maxi(1, a), mini(b, ss.size())):
		if ss[i]["dash"] and not ss[i - 1]["dash"]:
			n += 1
	return n


static func first(ss: Array, from: int, key: String) -> int:
	for i in range(from, ss.size()):
		if ss[i][key]:
			return i - from
	return -1


## Two frames of a plain run on the ground: the camera has nothing to do but follow.
static func _run_step(a: Dictionary, b: Dictionary) -> bool:
	return (
		a["g"]
		and b["g"]
		and not a["dash"]
		and not b["dash"]
		and not a["shk"]
		and not b["shk"]
		and hspeed(a) > MOVING
		and absf(hspeed(a) - hspeed(b)) < 0.05
		and absf((a["p"] as Vector3).y - (b["p"] as Vector3).y) < 0.01
	)


# ---------------------------------------------------------------- checks every scenario gets
## The body and picture checks that hold in every scenario: T-pose, idle pose while moving, feet sliding, legs
## running in place, the camera losing the hunter, falling out of the map.
func common(hero: String, sc: String, ss: Array, meas: Dictionary) -> void:
	var tpose := 0
	var idle_mv := 0
	var run_n := 0
	var skate := []
	var in_place := 0
	var off := 0
	var jerk := 0.0
	var prev_sp := -1.0
	for i in ss.size():
		var s: Dictionary = ss[i]
		if s["rest"] >= 0.0 and s["rest"] < REST_EPS:
			tpose += 1
		var sp := hspeed(s)
		if s["g"] and sp > MOVING and s["lp"] >= 0.0 and s["lp"] < 0.15 and s["aw"] < 0.3 and not s["dash"]:
			idle_mv += 1
		var steady := absf(sp - prev_sp) < 0.05  # legs carry it: no move or knock speeding it up or down
		prev_sp = sp
		if s["g"] and sp > MOVING and steady and not s["dash"] and s["foot"] >= 0.0:
			run_n += 1
			skate.append(s["foot"] / sp)
		if i >= 1 and i + 1 < ss.size() and _run_step(ss[i - 1], s) and _run_step(s, ss[i + 1]):
			var c: Vector3 = ss[i + 1]["cam"] - 2.0 * (s["cam"] as Vector3) + ss[i - 1]["cam"]
			var b: Vector3 = ss[i + 1]["p"] - 2.0 * (s["p"] as Vector3) + ss[i - 1]["p"]
			if b.length() < BODY_SMOOTH_M:  # (a shove that moved the body itself is not the camera's jolt)
				jerk = maxf(jerk, c.length())
		if s["g"] and sp < 0.05 and s["lp"] > 0.5:
			in_place += 1
		if not s["scr"]:
			off += 1
	meas["tpose_f"] = tpose
	meas["idle_moving_f"] = idle_mv
	meas["in_place_f"] = in_place
	meas["offscreen_f"] = off
	meas["cam_jerk_mm"] = snappedf(jerk * 1000.0, 0.1)
	if jerk > CAM_JERK_M:
		flag(
			hero, sc, "cam_jitter", "camera jumps %.0f mm in one frame while the hunter runs steadily" % (jerk * 1000.0)
		)
	if not skate.is_empty():
		skate.sort()
		meas["foot_slip"] = snappedf(skate[skate.size() / 2], 0.01)
	if tpose >= 3:
		flag(hero, sc, "tpose", "%d frames with the skeleton at its rest pose" % tpose)
	if idle_mv >= 12:
		flag(
			hero, sc, "idle_moving", "%d frames moving > %.1f m/s with the idle blend (loco < 0.15)" % [idle_mv, MOVING]
		)
	if sc in ["run", "sneak"] and run_n >= 20 and float(meas["foot_slip"]) > SKATE_RATIO:
		flag(hero, sc, "skate", "planted foot moves at %.0f%% of the body speed" % (100.0 * float(meas["foot_slip"])))
	if in_place >= 18:
		flag(hero, sc, "run_in_place", "%d frames stopped with the walk/run blend > 0.5" % in_place)
	if off >= 6:
		flag(hero, sc, "offscreen", "%d frames with the hunter off screen" % off)
	if ss.size() > 0 and ss[-1]["low"]:
		flag(hero, sc, "out_of_map", "ends %.1f m under the lowest ground" % float(ss[-1]["low_by"]))


## While a key was pressed into a wall from frame `a` to `b`: how far the body went back and forth along `dir`.
static func jitter(ss: Array, a: int, b: int, dir: Vector2) -> float:
	var along := []
	for i in range(maxi(0, a), mini(b, ss.size())):
		var p: Vector3 = ss[i]["p"]
		along.append(Vector2(p.x, p.z).dot(dir))
	var back := 0.0
	for i in range(1, along.size()):
		back = maxf(back, float(along[i - 1]) - float(along[i]))
	return back


# ---------------------------------------------------------------- report
func write(dir: String, cmd: String, heroes: Array, clips: Dictionary, meta: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("play_probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"meta": meta, "flags": rows, "measure": data}, "\t"))
	f.close()
	var by := rows.duplicate()
	by.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["impact"]) > int(y["impact"]))
	var out := PackedStringArray()
	out.append("# Play probe report")
	out.append("")
	out.append("Rerun: `%s`" % cmd)
	out.append(
		(
			"Build: %s. Heroes: %s. Frames: %d at 60 fps. FLAGs: %d."
			% [meta.get("sha", "?"), ", ".join(heroes), int(meta.get("frames", 0)), rows.size()]
		)
	)
	out.append("Real InputEvents through Input.parse_input_event; damage and balance are out of scope.")
	out.append("")
	out.append("## FLAGs, most noticeable first")
	out.append("")
	out.append("| impact | hero | scenario | what a player sees | measured | clip |")
	out.append("|---|---|---|---|---|---|")
	for r in by:
		var key := "%s_%s" % [r["hero"], r["sc"]]
		out.append(
			(
				"| %d | %s | %s | %s | %s | %s |"
				% [r["impact"], r["hero"], r["sc"], r["words"], r["detail"], clips.get(key, "")]
			)
		)
	out.append("")
	out.append("## Measurements per hero")
	for hero in heroes:
		out.append("")
		out.append("### %s" % hero)
		out.append("")
		var per: Dictionary = data.get(hero, {})
		for sc in per:
			var mark := "FLAG" if flagged(hero, sc) else "PASS"
			out.append("- %s `%s` %s" % [mark, sc, _short(per[sc])])
	f = FileAccess.open(dir.path_join("play_probe_report.md"), FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()


static func _short(meas: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in meas:
		var v: Variant = meas[k]
		if v is int and int(v) == 0 and String(k).ends_with("_f"):
			continue
		parts.append("%s=%s" % [k, str(snappedf(v, 0.01)) if v is float else str(v)])
	return " ".join(parts)
