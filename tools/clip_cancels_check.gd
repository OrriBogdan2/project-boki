extends RefCounted
## --clip-cancels-check: every cancel the kit's Cancels table lists (the file's "cancels" rows, [from, cut at s, to])
## hands over with no pop, and the next state owns the body within one frame of the source footage (nothing held,
## nothing half-faded; a longer fade the file declares is held to itself). A move the kit cuts leaves the hunter's
## state at once (no frozen pose). Never touches the save.

const DT := 1.0 / 30.0
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
const SPIKE := 1.5             # a pop is this much more than the frames either side of it: a jump, not a fast blend
const SOURCE_FRAME := 0.2      # s: one frame of the 5 fps footage: a cancel's blend is done inside it
const LEAD := 0.5              # s: the legs run this long before a sequence's first move (past any landing)
const RUN := Vector3(0, 0, -4.0)
## Cancels found open: "<id> <from>@<at>><to>" -> what. The hand crosses two far-apart arm poses inside one fade; a
## cut as the source does would snap the whole difference in one frame. Each needs an art pass (a nearer first key on
## the second clip) or a longer "fade", and then drops its entry.
const CANCEL_OPEN := {
	"juggernaut jug_reel@0.30>jug_spin": "1.16 m, the spin's first pose is far from the reel",
	"juggernaut jug_reel@0.30>jug_dash": "0.52 m in one frame into the dash",
	"bulwark bul_smash_wind@0.50>bul_ult_wind": "hammer from the wind-up hold to overhead, 0.74 m in a frame",
	"bulwark bul_lumber@0.20>bul_ult_wind": "0.50 m into the ult wind-up",
	"bulwark bul_throw@0.10>bul_recall": "0.70 m into the recall",
	"dredge dr_blast@0.50>stun": "0.60 m into the stun pose",
	"dredge dr_throw@0.20>dr_shot": "0.62 m into the shot",
	"tender mm_seed_aim@0.50>stun": "0.37 m into the stun pose",
	"tender mm_call_hold@1.00>stun": "0.36 m into the stun pose",
	"tender mm_call_hold@1.00>mm_skip": "0.19 m into the skip",
	"thief thf_bola@0.20>stun": "0.43 m into the stun pose",
	"thief thf_encore_dance@0.80>thf_vault_r": "cartwheel cut into the vault, 0.35 m in a frame",
}

var bad := 0
var holder: Node3D
var own := {}                # a clip's own hand path per frame (this Hero), the measure a hand-over is held to
var pops: Array = []         # [pop m, "hero from@t>to"] of every cancel row, worst first

func ok(cond: bool, what: String) -> void:
	print("CANCELS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)        # (one Hero, while iterating on its clips)
	var n := 0
	for id in Arch.ids():
		var dd := WardenClips.data(WardenGlb.art(String(id)))
		if not dd.has("cancels") or (only != "" and String(id) != only):
			continue
		n += 1
		await _hero(String(id), dd)
	ok(n > 0, "at least one Hero lists cancels (%d)" % n)
	pops.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(pops.size(), 10):
		print("CANCELS worst %d: %.3f m %s" % [i + 1, pops[i][0], pops[i][1]])
	await _feed_state(main)
	print("CANCELS_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String, dd: Dictionary) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	if sync == null or sync.get("clips") == null:
		ok(false, "%s: wears clips" % id)
		m.free()
		return
	sync.set_process(false)
	own = {}
	var clips: WardenClips = sync.get("clips")
	var height := 1.6 * absf(m.scale.y)
	var worst := 0.0
	var where := ""
	var late: Array = []
	var rows: Array = dd["cancels"]
	for row in rows:
		var r := await _run_seq(m, sync, clips, dd, _cancel_seq(row), 2)
		var what := "%s %s@%.2f>%s" % [id, row[0], row[1], row[2] if row[2] != "" else "legs"]
		pops.append([float(r[0]), what])
		print("CANCELS pop %.3f m %s (%s)" % [r[0], what, r[1]])
		if CANCEL_OPEN.has(what):
			var stale := " (now passes: drop it from CANCEL_OPEN)" if float(r[0]) <= POP * height else ""
			print("CANCELS open %s %.3f m [%s]%s" % [what, r[0], CANCEL_OPEN[what], stale])
			ok(float(r[0]) > POP * height, "%s: CANCEL_OPEN entry still needed" % what)
		elif float(r[0]) > worst:
			worst = float(r[0])
			where = what
		if not bool(r[2]):
			late.append(what)
	ok(worst <= POP * height, "%s: %d cancels hand over with no pop (worst %.3f m, %s; limit %.3f)"
			% [id, rows.size(), worst, where, POP * height])
	ok(late.is_empty(), "%s: every cancel's blend is done within %.1f s of the cut (late: %s)"
			% [id, SOURCE_FRAME, str(late)])
	m.free()

## A "cancels" row [from, cut at s, to] as a sequence: the legs, the move to its cut, then what cuts it.
static func _cancel_seq(row: Array) -> Array:
	return [["", LEAD], [String(row[0]), float(row[1])], [String(row[2]), 2.0 * SOURCE_FRAME]]

## The anim state a sequence step asks for: a kit move at `t` s, "" the legs, "stun", "glide". A move or a stun out of
## the glider closes it and plays in the fall (the source casts from the air); the legs are the ground.
static func _feed(s: Dictionary, dd: Dictionary, st: String, t: float) -> void:
	s.erase("kmove")
	s["stun"] = st == "stun"
	s["gliding"] = st == "glide"
	if st == "glide" or st == "":
		s["grounded"] = st == ""
	if st != "" and st != "stun" and st != "glide":
		s["kmove"] = st
		s["kmove_t"] = t
	# (a move that turns its side to the way he goes is fed that facing)
	s["face"] = float(dd.get("kmoves", {}).get(st, {}).get("heading_off", 0.0))

## The clip a sequence step shows, "" when it is the legs or the glider.
static func _clip_of(dd: Dictionary, st: String) -> String:
	if st == "stun":
		return String(dd.get("states", {}).get("stun", ""))
	var moves: Dictionary = dd.get("kmoves", {})
	return String(moves[st]["clip"]) if moves.has(st) else ""

## How long step `k`'s blend may take: a source frame, or what the data declares for it (the move's "fade" in, the
## cut move's "fade_out" back to the legs): a longer fade is a feel choice the file states, and is held to itself.
static func _window(dd: Dictionary, seq: Array, k: int) -> float:
	var moves: Dictionary = dd.get("kmoves", {})
	var st := String(seq[k][0])
	if st == "" or st == "glide":
		return maxf(SOURCE_FRAME, float(moves.get(String(seq[k - 1][0]), {}).get("fade_out", 0.0)) + DT)
	return maxf(SOURCE_FRAME, float(moves.get(st, {}).get("fade", 0.0)) + DT)

## True when the layers show `st` alone: the legs (or the glider) with no action left, or the move at full weight on
## whichever layer plays it (a move cast from the air keeps the fall legs under it). A move cut shorter than the
## window has ended by then and cannot own the body.
static func _settled(clips: WardenClips, dd: Dictionary, st: String) -> bool:
	if st == "" or st == "glide":
		var off := clips.act_w <= 0.001 and clips.up_w <= 0.001
		return off and (st == "" or clips.glide_w >= 0.999 and clips.air_w >= 0.999)
	var mv: Dictionary = dd.get("kmoves", {}).get(st, {})
	if float(mv.get("cut", 1e9)) <= SOURCE_FRAME:
		return true
	var clips_of: Array = [_clip_of(dd, st), mv.get("alt", "")]
	var on_up: bool = clips.up_w >= 0.999 and absf(clips.xf_u - clips.chan_u) < 0.001 and clips.cur_u in clips_of
	var on_act: bool = clips.act_w >= 0.999 and absf(clips.xf - clips.chan) < 0.001 and clips.cur in clips_of
	return on_up or on_act

## The clip alone, played at its own pace: the hand's step per frame, the measure a hand-over is held to.
func _own_path(m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary, st: String, hold: float) -> void:
	var clip := _clip_of(dd, st)
	if clip == "" or own.has(clip):
		return
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var lead := float(dd.get("kmoves", {}).get(st, {}).get("lead", 0.0))      # (the game seeks kmove_t + lead)
	clips.force = {"clip": clip, "t": 0.0}
	for k in 10:
		sync.call("_process", DT)
	await holder.get_tree().process_frame
	var path: Array = []
	var t := 0.0
	var last_p := hand.global_position
	while t < hold:
		clips.force = {"clip": clip, "t": clampf(t + lead, 0.0, clips.lib.get_animation(clip).length - 0.001)}
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		path.append(hand.global_position.distance_to(last_p))
		last_p = hand.global_position
		t += DT
	own[clip] = path

## A sequence [[state, s], ...] fed frame by frame as the game does: [worst pop m, where (with the frames either side),
## settled]. A strike is meant to snap, so a pop is the hand moving further in a frame than the clip alone moves it
## there (the clip's own path, sampled once) and further than in the frames either side (SPIKE): a jump, where a fast
## blend carries on. Pops count from step `judge` on (a cancel: the cut itself). Settled: each step's state after the
## lead-in owns the body SOURCE_FRAME after it begins.
func _run_seq(m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary, seq: Array, judge: int) -> Array:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	for st in seq:
		await _own_path(m, sync, clips, dd, String(st[0]), float(st[1]))
	clips.force = {}
	var s := {"vel": RUN, "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var last := Vector3.INF
	var overs: Array = []       # per frame: how far past the clip's own step the hand moved (0: not measured)
	var at: Array = []
	var settled := true
	for k in seq.size():
		var st: Array = seq[k]
		var clip := _clip_of(dd, String(st[0]))
		var t := 0.0
		var i := 0
		var judged: bool = k == 0
		while t < float(st[1]):
			_feed(s, dd, String(st[0]), t)
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			t += DT
			i += 1
			if not judged and t >= _window(dd, seq, k) - 0.0001:
				judged = true
				settled = settled and _settled(clips, dd, String(st[0]))
			var p := hand.global_position
			var over := 0.0
			# (to the clip's end only: past it the move fades to the legs, the clip's own path can't say how far)
			if last != Vector3.INF and clips.proc_w <= 0.0 and own.has(clip) and i <= (own[clip] as Array).size() \
					and t <= clips.lib.get_animation(clip).length and k >= judge:
				var path: Array = own[clip]
				var clip_step := 0.0
				for j in range(maxi(i - 3, 0), mini(i + 2, path.size())):      # (a frame or two either way: the fade)
					clip_step = maxf(clip_step, float(path[j]))
				over = maxf(p.distance_to(last) - clip_step, 0.0)
			overs.append(over)
			at.append("%s @%.2f" % [st[0], t])
			last = p
	var worst := 0.0
	var where := ""
	for i in overs.size():
		var before := float(overs[i - 1]) if i > 0 else 0.0
		var after := float(overs[i + 1]) if i + 1 < overs.size() else 0.0
		if float(overs[i]) > worst and float(overs[i]) > SPIKE * maxf(before, after):
			worst = float(overs[i])
			where = "%s, %.3f before, %.3f after" % [at[i], before, after]
	return [worst, where, settled]

## The hunter's own feed: a kit move the kit cuts (its anim_id emptied) leaves the state the same frame, so no clip
## freezes on its cut frame (a hold animation never shows without the hold input).
func _feed_state(main: Node) -> void:
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("bulwark", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	P.ak.play("bul_guard")
	P._anim_state(1.0)
	var shown := String(P.anim_s.get("kmove", "")) == "bul_guard"
	P.ak.anim_id = ""
	P._anim_state(1.0)
	var left := String(P.anim_s.get("kmove", ""))
	ok(shown and left == "",
			"a kit move the kit cuts leaves the hunter's anim state at once (shown %s, left '%s')"
			% [shown, left])
	await ac.done(m)
