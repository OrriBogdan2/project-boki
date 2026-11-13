class_name RaceGhost
extends RefCounted
## Ghost laps for the Dash (BaseRace): a time trial against a friend's best lap, with no live netcode.
## Every Run tapes how far each runner is along the lap every TICK (Tape). When a lap at home finishes, the
## fastest Boki's lap is kept if it beats the best on that course (keep_best): a course is the lap's stretch
## layout and length (each garden zone has its own loop), so the weekly "Two streams" loop is a course of
## its own. The visit snapshot carries the laps
## (Social.profile_doc); a visitor at the friend's race post runs their partner against the faded ghost
## (BaseRace.use on a visit), and a ghost beaten sends the friend a "race" gift that pins the winner to their
## showcase wall when they next come home (take_gift).
## On the save: Save.d["ghosts"] = {course: {boki, species, uid, t, track}}, t the lap in s and track the cm
## moved each TICK as base64 bytes (about 0.3 KB a lap). A missing key means no laps: no migration.

const TICK := 0.1            # s between a lap's samples
const MAX_TICKS := 1200      # samples a lap may hold (120 s): longer laps are not kept, a visitor's are cut here
const MAX_STEP := 255        # cm a runner may move in one TICK (one byte)
const MAX_COURSES := 8       # courses a visitor's snapshot may carry (untrusted)
const TRACK_CHARS := MAX_TICKS * 4 / 3 + 4    # base64 characters of the longest track
const FADE := 0.55           # transparency of the ghost's model: 0 solid, 1 gone
const LANE := 1.0            # the ghost's lane, in lane widths right of your Boki

## How far each runner of a Run is along the lap at every TICK since the start.
class Tape:
	var marks: Array = []        # per runner: m along the lap at TICK, 2 TICK, ...
	var _prev: Array = []        # m along the lap at the previous step

	func take(run, dt: float) -> void:
		if marks.is_empty():
			for i in run.dist.size():
				marks.append([])
				_prev.append(0.0)
		var t0: float = run.t - dt
		for i in marks.size():
			var done := float(run.done_t[i])
			var t1: float = done if done >= 0.0 else run.t      # a lap ends on the line, not the frame
			var m: Array = marks[i]
			while (m.size() + 1) * TICK <= t1 and m.size() < MAX_TICKS and t1 > t0:
				var at := (m.size() + 1) * TICK
				m.append(lerpf(float(_prev[i]), float(run.dist[i]), (at - t0) / (t1 - t0)))
			_prev[i] = float(run.dist[i])

## A taped lap played back: m along the lap at any time.
class Replay:
	var marks := PackedFloat32Array()     # m along the lap at TICK, 2 TICK, ...
	var end_t := 0.0                      # s, the lap
	var lap_m := 0.0                      # m, the lap's length

	func dist_at(t: float) -> float:
		if t >= end_t:
			return lap_m
		var k := int(maxf(t, 0.0) / TICK)
		if k < marks.size():
			return lerpf(float(marks[k - 1]) if k > 0 else 0.0, marks[k], t / TICK - k)
		var n := marks.size()        # past the last sample: straight on to the line
		var last := float(marks[n - 1]) if n > 0 else 0.0
		return lerpf(last, lap_m, (t - n * TICK) / maxf(end_t - n * TICK, 0.001))

static func course(stretches: Array) -> String:
	var m := 0.0
	for s in stretches:
		m += float(s.get("len", 0.0))
	return "%s@%d" % ["-".join(stretches.map(func(s): return String(s["kind"]))), roundi(m)]

## Runner i's finished lap of a Run as a saved ghost.
static func lap(run, i: int) -> Dictionary:
	var rec: Dictionary = run.recs[i]
	var bytes := PackedByteArray()
	var at := 0
	for d in run.tape.marks[i]:
		var step := clampi(roundi(float(d) * 100.0) - at, 0, MAX_STEP)
		bytes.append(step)
		at += step
	return {"boki": String(rec["name"]), "species": String(rec["species"]), "uid": String(rec.get("uid", "")),
		"t": snappedf(float(run.done_t[i]), 0.001), "track": Marshalls.raw_to_base64(bytes)}

static func replay(l: Dictionary, lap_m: float) -> Replay:
	var out := Replay.new()
	out.end_t = float(l["t"])
	out.lap_m = lap_m
	var at := 0.0
	for b in Marshalls.base64_to_raw(String(l["track"])):
		at += b / 100.0
		out.marks.append(minf(at, lap_m))
	return out

## Keeps the fastest finished lap of a Run when it beats the best on its course. Returns it, or {}.
static func keep_best(run) -> Dictionary:
	var best := -1
	for i in run.recs.size():
		var t := float(run.done_t[i])
		if t > 0.0 and not run.recs[i].get("visitor", false) and (best < 0 or t < float(run.done_t[best])):
			best = i
	if best < 0 or run.tape.marks[best].size() >= MAX_TICKS:
		return {}
	var key := course(BaseRace.stretches(run.tw))
	var all: Dictionary = Save.d.get("ghosts", {})
	if all.has(key) and float(all[key]["t"]) <= float(run.done_t[best]):
		return {}
	all[key] = lap(run, best)
	Save.d["ghosts"] = all
	return all[key]

## A visitor's laps are untrusted: known species, sane times, short tracks, at most MAX_COURSES.
static func clean(src) -> Dictionary:
	var out := {}
	var all := Social.dict_of(src)
	for key in all.keys().slice(0, MAX_COURSES):
		var l := Social.dict_of(all[key])
		var sp := Social.txt_of(l.get("species"), "", 24)
		var track := Social.txt_of(l.get("track"), "", TRACK_CHARS + 1)
		var t := Social.num_of(l.get("t"))
		var fits := track.length() <= TRACK_CHARS and track.length() % 4 == 0
		if Data.KIN.has(sp) and fits and t > 0.0 and t <= MAX_TICKS * TICK:
			out[Social.txt_of(key, "", 64)] = {"boki": Social.say_of(l.get("boki"), "Kin", 14), "species": sp,
				"uid": Social.txt_of(l.get("uid"), "", 24), "t": t, "track": track}
	return out

## A ghost's look: the friend's Boki pale (the Soul Shrine's ghost palette) and see-through, its owner's name over it.
static func model(l: Dictionary, friend: String, roster: Array) -> Node3D:
	var rec: Dictionary = {}
	for r in roster:
		if String(r.get("uid", "")) == String(l["uid"]) and r["species"] == l["species"]:
			rec = r.duplicate()
	rec["ghost"] = true
	var n := Models.kin(String(l["species"]), rec)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = FADE
	var tag := Label3D.new()
	tag.text = "%s's %s" % [friend, l["boki"]]
	tag.font_size = 26
	tag.pixel_size = 0.004
	tag.modulate = Color(1, 1, 1, 0.7)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 1.0, 0)
	n.add_child(tag)
	return n

## The "race" gift to friend `to` whose `ghost` lap on course `key` your Boki beat with a lap of `lap_t` s
## (img: its portrait).
static func beat_gift(to: String, rec: Dictionary, lap_t: float, ghost_lap: Dictionary, key: String,
		img: String) -> Dictionary:
	return {"to": to, "from": Social.me, "from_name": Save.d.get("name", "Hunter"), "kind": "race", "key": key, "n": 1,
		"t": Social.now_ms(), "boki": rec["name"], "species": rec["species"], "lap_t": snappedf(lap_t, 0.01),
		"ghost": ghost_lap["boki"], "ghost_t": ghost_lap["t"], "img": img}

## A "race" gift from a visitor who beat your ghost: pins their Boki to your showcase wall. Returns the away line.
static func take_gift(g: Dictionary, who: String) -> String:
	var sp := Social.txt_of(g.get("species"), "", 24)
	var lap_t := Social.num_of(g.get("lap_t"))
	var ghost_t := Social.num_of(g.get("ghost_t"))
	if not Save.d.get("ghosts", {}).has(Social.txt_of(g.get("key"), "", 64)) or not Data.KIN.has(sp) \
			or lap_t <= 0.0 or lap_t >= ghost_t:
		return ""
	var boki := Social.say_of(g.get("boki"), "Kin", 14)
	var ghost_boki := Social.say_of(g.get("ghost"), "Kin", 14)
	var img := Social.txt_of(g.get("img"), "", BaseShowcase.IMG_CHARS)
	BaseShowcase.add({"name": boki, "species": sp}, {"name": ("Beat %s's lap" % ghost_boki).substr(0, 24)}, img)
	return "%s's %s beat %s's Dash lap (%.1f s to %.1f s). It is on your showcase wall." % [
		who, boki, ghost_boki, lap_t, ghost_t]

# ------------------------------------------------------------------ racing a friend's ghost on a visit
var race: BaseRace
var ghost := {}              # the friend's lap on this course ({} when not racing)
var play: Replay = null
var node: Node3D = null      # the ghost's model

func _init(r: BaseRace) -> void:
	race = r

func here() -> Dictionary:
	return race.h.visit.get("ghosts", {}).get(course(BaseRace.stretches(BaseRace.tweak("dash"))), {})

func label() -> String:
	var l := here()
	if l.is_empty():
		return "%s has no Dash lap on this course yet" % race.h.visit["name"]
	return "Race the ghost of %s's %s (%.1f s)" % [race.h.visit["name"], l["boki"], float(l["t"])]

## Your partner against the friend's best lap on their loop, you cheering as in any Dash.
func start() -> void:
	var rec := Save.active_kin()
	ghost = here()
	if rec.is_empty() or ghost.is_empty():
		race.h._toast("Bring a partner Boki to race" if rec.is_empty() else label())
		ghost = {}
		return
	play = replay(ghost, BaseRace.lap())
	node = model(ghost, race.h.visit["name"], race.h.visit.get("roster", []))
	race.h.add_child(node)
	race.begin([race.h.add_kin(rec, 0)])     # your partner joins the friend's Boki for the lap

func tick(run) -> void:
	var d := play.dist_at(run.t)
	var s := 0
	while s < run.ends.size() - 1 and d >= float(run.ends[s]):
		s += 1
	var from := float(run.ends[s - 1]) if s > 0 else 0.0
	var f := clampf((d - from) / (float(run.ends[s]) - from), 0.0, 1.0)
	node.position = race.track_at(s, f, LANE * float(BaseRace.rules()["lane"]))
	node.rotation.y = race.heading(s, f)

## The race is over (or left): the card, and a gift for the friend when the ghost was beaten.
func finish(run, finished: bool) -> void:
	var mine_k: Dictionary = race.runners[0]
	var body: Node3D = mine_k["node"]
	if finished:
		var mine := float(run.done_t[0])
		var won := mine < float(ghost["t"])
		var rec: Dictionary = run.recs[0]
		if won:
			var img := BaseShowcase.snap(race.h.get_viewport(), race.h.cam, body.global_position + Vector3(0, 0.5, 0))
			var key := course(BaseRace.stretches(run.tw))
			Social.add_doc("gifts", beat_gift(race.h.visit_id, rec, mine, ghost, key, img))
		var friend: String = race.h.visit["name"]
		var times := "%s %.2f s  ·  %s's %s %.2f s" % [rec["name"], mine, friend, ghost["boki"], float(ghost["t"])]
		if won:
			var pinned := ["It goes on %s's showcase wall" % friend, UI.GOLD]
			race.show_card("%s beat the ghost!" % rec["name"], [[times, UI.INK], pinned])
		else:
			var again := ["Cheer on every mark and try again", UI.MUTED]
			race.show_card("The ghost got there first", [[times, UI.INK], again])
	race.h.kins.erase(mine_k)
	body.queue_free()
	node.queue_free()
	ghost = {}
	play = null
