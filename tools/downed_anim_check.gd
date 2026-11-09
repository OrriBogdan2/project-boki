extends RefCounted
## --downed-anim-check: going down reads before the Wisp (docs/decisions/0019-downed-wisp.md). For all 12 Heroes,
## a knock plays the hero's hit clip as a 0.3-0.4 s fall with the hero still on screen, the Wisp fades in on the last
## frames and only then does the hero hide; a revive plays the clip back as a short rise, no pop. The downed timers
## and the Wisp's round look are not touched. A remote-driven Hunter plays the same (it follows `downed` alone).
## Prints PASS/FAIL. Never touches the save.

const DT := 1.0 / 60.0
const FALL_MIN := 0.3        # s: the shortest fall that still reads
const FALL_MAX := 0.4        # s: the longest before it drags
const RISE_MAX := 0.4        # s
const PER_HERO := 10         # checks one Hero runs: a script error must not pass as an empty run

var bad := 0
var ran := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"      # no autoplay drink over the rise
		h.inp["move"] = Vector2.ZERO
	for a in Arch.ids():
		_hero(String(a), m.player, false)
	var mate: Hunter = m.hunters.filter(func(x): return x.team == m.player.team and x != m.player)[0]
	_hero("remote", mate, true)
	ok(ran >= PER_HERO * (Arch.ids().size() + 1), "every check ran (%d)" % ran)
	print("DOWNEDANIM %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	ran += 1
	print("DOWNEDANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame() -> void:
	m.step(DT)
	for h in m.hunters:
		h.render(DT, 1.0)
		var sync: Node = h.model.get_node_or_null("Warden/Sync") if h.model else null
		if sync:
			sync.set_process(false)
			sync.call("_process", DT)

func _clip_of(h: Hunter) -> String:
	var clips := h.model.get_node("Warden/Sync").get("clips") as WardenClips
	return clips.cur if clips else ""

func _fade_of(h: Hunter) -> float:
	var mats: Array = HunterWisp.node_of(h).get_meta("mats", [])
	return float((mats[0] as ShaderMaterial).get_shader_parameter("fade"))

## One Hero goes down and gets up again; `remote`: driven from outside, so only `downed` moves.
func _hero(id: String, h: Hunter, remote: bool) -> void:
	var tag := "[%s] " % id
	var foe: Hunter = m.hunters.filter(func(x): return x.team != h.team)[0]
	if not remote:
		h.reclass(Arch.weight(id), id)
	h.hp = h.max_hp
	for i in 10:
		_frame()
	var states: Dictionary = WardenClips.data(WardenGlb.art(h.arch)).get("states", {})
	var hit := String((states.get("hit", {}) as Dictionary).get("front", ""))
	ok(hit != "" and h.model.visible, tag + "up: the hero shows and has a hit clip (%s)" % hit)
	m.knock(h, foe, {})
	h.down_hp = 1e6
	h.remote = remote
	var t := 0.0
	var shown_t := 0.0
	var fall_clip := true
	var fall_up := true
	var last_k := -1.0
	var fade_early := false
	var fade_end := 0.0
	while t < 0.6 and HunterWisp.mode_of(h) != HunterWisp.ON:
		_frame()
		t += DT
		var k := HunterWisp.fall_k(h)
		if HunterWisp.mode_of(h) != HunterWisp.IN:
			break
		fall_clip = fall_clip and _clip_of(h) == hit
		fall_up = fall_up and k >= last_k
		last_k = k
		shown_t = t
		if t < 0.2:
			fade_early = fade_early or _fade_of(h) > 0.05
		fade_end = _fade_of(h)
	_frame()
	ok(shown_t >= FALL_MIN - DT and shown_t <= FALL_MAX + DT, tag + "the hero stays up for the fall (%.2f s)" % shown_t)
	ok(fall_clip and fall_up, tag + "it plays the hit clip, forward")
	ok(not fade_early and fade_end > 0.5, tag + "the Wisp fades in on the last frames only (end %.2f)" % fade_end)
	ok(not h.model.visible and HunterWisp.node_of(h) != null, tag + "then the hero hides and the Wisp stands in")
	ok(h.downed and not h.out, tag + "still downed, not out: the fall only paints")
	if remote:
		h.downed = false      # a remote's revive arrives as the flag clearing
	else:
		m.revive_hunter(h, null)
	_frame()
	ok(h.model.visible and HunterWisp.mode_of(h) == HunterWisp.OUT, tag + "revived: the hero shows at once, no pop")
	var rise_clip := true
	var rise_down := true
	last_k = 2.0
	t = 0.0
	while HunterWisp.mode_of(h) == HunterWisp.OUT and t < 1.0:
		var k := HunterWisp.fall_k(h)
		rise_clip = rise_clip and _clip_of(h) == hit
		rise_down = rise_down and k <= last_k
		last_k = k
		_frame()
		t += DT
	ok(rise_clip and rise_down, tag + "the rise plays the clip backwards")
	var up_again: bool = t <= RISE_MAX + DT and HunterWisp.node_of(h) == null and h.model.visible
	ok(up_again, tag + "up again in %.2f s, Wisp gone" % t)
	ok(HunterWisp.fall_k(h) < 0.0, tag + "no fall state is left on the hunter")
	h.remote = false
