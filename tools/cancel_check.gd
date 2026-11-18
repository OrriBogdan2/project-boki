extends RefCounted
## --cancel-check: every cancel the kit's Cancels table lists (the "cancels" rows [from, cut at s, to] of
## content/rules/warden_anim/<art>.json) hands over with no pop, and the next state owns the body within one frame of
## the target feel's footage (docs/art/wardens/CLIPS.md, "cancels"). A pop is the hand moving further in one frame than
## the clip's own path does and further than the frames either side of it (a jump, where a fast blend carries on).
## --only=<hero id> while iterating. Never touches the save.

const DT := 1.0 / 30.0
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
const SPIKE := 1.5             # a pop is this many times the frames either side of it
const SETTLE := 0.2            # s: a cancel's blend is done inside this (one frame of the footage)
const LEAD := 0.5              # s: the legs run this long before the first move (past any landing)
const TOP := 5                 # the worst cancels printed

var bad := 0
var holder: Node3D
var own := {}                  # clip -> the hand's own step per frame (this Hero)
var worst: Array = []          # [pop m, "hero from@t>to"], every row

func ok(cond: bool, what: String) -> void:
	print("CANCEL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var n := 0
	for id in Arch.ids():
		var dd := WardenClips.data(WardenGlb.art(String(id)))
		if dd.has("cancels") and (only == "" or only == String(id)):
			n += 1
			await _hero(String(id), dd)
	ok(n > 0, "at least one Hero lists cancels (%d)" % n)
	worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for i in mini(worst.size(), TOP):
		print("CANCEL worst %d: %.3f m %s" % [i + 1, worst[i][0], worst[i][1]])
	print("CANCEL_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String, dd: Dictionary) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	own = {}
	var limit := POP * 1.6 * absf(m.scale.y)
	var rows: Array = dd["cancels"]
	var late: Array = []
	var top := 0.0
	var top_at := ""
	for row in rows:
		var what := "%s %s@%.2f>%s" % [id, row[0], row[1], row[2] if row[2] != "" else "legs"]
		var win := _window(dd, String(row[0]), String(row[2]))
		var r := await _run(m, sync, clips, dd, [["", LEAD], [row[0], row[1]], [row[2], 2.0 * win]], win)
		worst.append([r[0], what])
		if float(r[0]) > top:
			top = float(r[0])
			top_at = what
		if not bool(r[1]):
			late.append(what)
	ok(top <= limit, "%s: %d cancels hand over without a pop (worst %.3f m over the clip's own, %s; limit %.3f)"
			% [id, rows.size(), top, top_at, limit])
	ok(late.is_empty(), "%s: every cancel's blend is done in a footage frame (%.1f s) or its own fade (late: %s)"
			% [id, SETTLE, str(late)])
	m.free()

## How long the blend into `to` may take: a frame of the footage, or the data's own fade (into a move) or fade_out
## (back to the legs off `from`) when a move keys it longer.
static func _window(dd: Dictionary, from: String, to: String) -> float:
	var moves: Dictionary = dd.get("kmoves", {})
	var fade: float = float(moves.get(to, {}).get("fade", WardenClips.FADE)) if to != "" \
			else float(moves.get(from, {}).get("fade_out", WardenClips.FADE_LOCO))
	return maxf(SETTLE, fade + DT)

## The clip a state shows: "" for the legs, the glider and the stun's clip.
static func clip_of(dd: Dictionary, st: String) -> String:
	if st == "stun":
		return String(dd.get("states", {}).get("stun", ""))
	var moves: Dictionary = dd.get("kmoves", {})
	return String(moves[st]["clip"]) if moves.has(st) else ""

## The anim state a step asks for: a kit move at `t` s, "" the legs, "stun", "glide". A move or a stun out of the
## glider closes it and plays in the fall; the legs are the ground.
static func feed(s: Dictionary, st: String, t: float) -> void:
	s.erase("kmove")
	s["stun"] = st == "stun"
	s["gliding"] = st == "glide"
	if st == "glide" or st == "":
		s["grounded"] = st == ""
	if st != "" and st != "stun" and st != "glide":
		s["kmove"] = st
		s["kmove_t"] = t

## True when the layers show `st` alone: the legs (or the glider) with no action left, or the move at full weight.
static func settled(clips: WardenClips, dd: Dictionary, st: String) -> bool:
	if st == "" or st == "glide":
		var off := clips.act_w <= 0.001 and clips.up_w <= 0.001
		return off and (st == "" or clips.glide_w >= 0.999 and clips.air_w >= 0.999)
	var up: Variant = dd.get("kmoves", {}).get(st, {}).get("upper", false)
	var upper := up is String or bool(up)
	var w := clips.up_w if upper else clips.act_w
	var xf := clips.xf_u if upper else clips.xf
	return w >= 0.999 and absf(xf - float(clips.chan_u if upper else clips.chan)) < 0.001

## A sequence [[state, s], ...] fed frame by frame as the game does: [worst pop m, settled]. Pops count from the second
## step on (the cut itself; the first move's own start is the flow's business). Settled: the last step owns the body
## `win` s after it begins.
func _run(m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary, seq: Array, win: float) -> Array:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	for st in seq:
		var clip := clip_of(dd, String(st[0]))
		if clip == "" or own.has(clip):
			continue
		clips.force = {"clip": clip, "t": 0.0}
		for k in 10:
			sync.call("_process", DT)
		var path: Array = []
		var last_p := hand.global_position
		for i in int(clips.lib.get_animation(clip).length / DT):
			clips.force = {"clip": clip, "t": i * DT}
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			path.append(hand.global_position.distance_to(last_p))
			last_p = hand.global_position
		own[clip] = path
	clips.force = {}
	var s := {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var overs: Array = []       # per frame: how far past the clip's own step the hand moved (0: not measured)
	var last := Vector3.INF
	var done := true
	for k in seq.size():
		var st: Array = seq[k]
		var path: Array = own.get(clip_of(dd, String(st[0])), [])
		var t := 0.0
		var i := 0
		while t < float(st[1]):
			feed(s, String(st[0]), t)
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			t += DT
			i += 1
			if k == seq.size() - 1 and absf(t - win) < DT / 2.0:
				done = done and settled(clips, dd, String(st[0]))
			var p := hand.global_position
			var over := 0.0
			if last != Vector3.INF and clips.proc_w <= 0.0 and k >= 1 and i <= path.size():
				var clip_step := 0.0
				for j in range(maxi(i - 3, 0), mini(i + 2, path.size())):      # (a frame or two either way: the fade)
					clip_step = maxf(clip_step, float(path[j]))
				over = maxf(p.distance_to(last) - clip_step, 0.0)
			overs.append(over)
			last = p
	var top := 0.0
	for i in overs.size():
		var near := maxf(float(overs[i - 1]) if i > 0 else 0.0, float(overs[i + 1]) if i + 1 < overs.size() else 0.0)
		if float(overs[i]) > SPIKE * near:
			top = maxf(top, float(overs[i]))
	return [top, done]
