class_name QuestSeat
extends RefCounted
## One quest seat of Limited Ways Out (docs/decisions/0051-limited-ways-out.md, spec section 11 task 4):
## the Sealed Lair or the Uplink. One explicit state machine (briefs/STATE_MACHINES.md): only go()
## moves `state`, along NEXT; an edge NEXT does not list is counted in `refused` and logged in `trail`,
## never applied. _force() sets it without the table: a client mirroring the host, or a demo.
## QuestSeats (Exits.seats) owns both seats and their schedule and decides every move on the host.
##   LOCKED  before its open time (the lair's gate will not open, the uplink is dark)
##   OPEN    anyone may start it
##   IN_USE  a squad is on it (sealed in with the boss, or charging the uplink); `team` is that squad
##   TAKEN   a squad finished it (`team`); `out` once that squad has left by it. One use: final
##   SHUT    its window ran out unused (final). "Lost to the Blight" is a look of this, not a state

enum S {LOCKED, OPEN, IN_USE, TAKEN, SHUT}
const NEXT := {
	S.LOCKED: [S.OPEN, S.SHUT],
	S.OPEN: [S.IN_USE, S.TAKEN, S.SHUT],
	S.IN_USE: [S.OPEN, S.TAKEN, S.SHUT],
	S.TAKEN: [],
	S.SHUT: [],
}

var m: Match
var kind := ""                 # "lair" or "uplink"
var ref := {}                  # the lair (Lairs.list) or the outpost (Exits.list) it runs on
var open_s := 0.0              # session seconds (content/rules/heart.json "quest")
var shut_s := 0.0
var state := S.LOCKED
var team := -1                 # the squad on it (IN_USE) or that took it (TAKEN)
var out := false               # TAKEN, and that squad has left by it
var trail: Array[String] = []  # "time from>to why", every move (the checks read it)
var refused := 0               # edges NEXT turned down: always 0 in a sane run

func _init(match_node: Match, k: String, r: Dictionary, o: float, s: float) -> void:
	m = match_node
	kind = k
	ref = r
	open_s = o
	shut_s = s

func title() -> String:
	return "the Sealed Lair" if kind == "lair" else "the Uplink"

func go(to: S, why: String, t := -1) -> bool:
	if not (to in NEXT[state]):
		refused += 1
		trail.append("%7.2f refused %s>%s %s" % [m.time, S.keys()[state], S.keys()[to], why])
		return false
	_force(to, why, t)
	return true

## Sets the state without the table. The calls (feed, toast, ping) are each game's own.
func _force(to: S, why: String, t := -1) -> void:
	trail.append("%7.2f %s>%s %s" % [m.time, S.keys()[state], S.keys()[to], why])
	state = to
	team = t if to in [S.IN_USE, S.TAKEN] else -1
	var at: Vector3 = ref.get("c", ref.get("pos", Vector3.ZERO))
	var col: Color = Lairs.color_of(ref) if kind == "lair" else ExitModels.UPLINK
	match to:
		S.OPEN:
			if why == "clock":
				var nm := String(ref.get("name", ""))
				m.add_feed("%s is open: %s, first squad to finish it leaves" % [title().capitalize(), nm])
				m.ping(at, col)
				m.sfx("horn", null, -6.0, 0.8)
				if m.hud and m.player and not m.player.out and not m.player.extracted:
					var dw := m.direction_word(m.player.pos, at)
					m.hud.toast("%s IS OPEN  ·  %s %s" % [title().to_upper(), nm, dw], col)
		S.IN_USE:
			m.add_feed("%s started %s" % [squad(t), title()])
		S.TAKEN:
			m.add_feed("%s took %s" % [squad(t), title()])
		S.SHUT:
			m.add_feed("%s has shut" % title().capitalize())

## "Amber squad" style words for a squad (the name of one of its hunters when that's all we have).
func squad(t: int) -> String:
	for h in m.hunters:
		if h.team == t:
			return "%s's squad" % h.pname
	return "A squad"
