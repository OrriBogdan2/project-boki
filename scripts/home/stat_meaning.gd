class_name StatMeaning
extends RefCounted
## The first time Power, Guard, Speed or Focus rises on a save (StatGlint), one plain line on the tip strip
## (the message lane, as HubHints) says what it does in a match and in the garden games. Max one a minute and
## never during a garden game; a tip held back is not counted as seen, so it shows at that stat's next rise.
## The lines are Care.STATS "means"; seen ones live in Save.d["tutorial"]["stat_tips"].

const GAP_S := 60.0      # s between two stat tips
const NOTICE_Y := 100.0  # px: where the lane starts (Home._toast's top)
const GUIDE_DROP := 52.0 # px lower while the goal line is up (Home._toast)

static var last_s := -GAP_S      # when the last tip showed (Time.get_ticks_msec), any home this run

## Stat s just rose on a Boki at home h: says what it does if this save hasn't been told yet.
static func rise(h, s: String) -> void:
	var seen: Dictionary = Save.d["tutorial"].get_or_add("stat_tips", {})
	var now := Time.get_ticks_msec() / 1000.0
	if seen.has(s) or now - last_s < GAP_S or in_game(h) or not Settings.get_v("tips") or Record.clean():
		return
	seen[s] = true
	last_s = now
	var lane := MsgLane.of(h.root_ui)
	lane.top = NOTICE_Y + (GUIDE_DROP if h.guide and h.guide.hint_visible() else 0.0)
	lane.push(String(Care.STATS[s]["means"]), HubHints.TIP_COL, MsgLane.NORMAL, HubHints.TIP_LIFE)

## Is a garden game (the Dash and its relay, Shove, Seek, Spark Volley, Tumble, Echo Steps, the show, fishing) on?
static func in_game(h) -> bool:
	return h.games.any(func(g): return g.state != BaseSeek.S.IDLE if g is BaseSeek else g.run != null) \
			or (h.hrace != null and h.hrace.relay.run != null)
