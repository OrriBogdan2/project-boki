class_name WaysOutLook
extends RefCounted
## What a way-out seat looks like from across the island (docs/decisions/0051-limited-ways-out.md, spec section 9),
## and how each seat's own state maps onto one of five looks. Pure data in, no nodes: SeatBeacon draws it.
##   LOCKED  dim short stub in grey-blue and a countdown glyph to the opening
##   OPEN    a tall clear beam in neutral light
##   IN_USE  the beam in the using squad's colour, the ring filling with the hold
##   TAKEN   the beam collapses and the seat goes dark (it was used once)
##   LOST    smothered: low dark-violet haze and a dark ring (the Blight's tide covers it, or its window shut)
## No bursts and no expanding rings on a change: the look just swaps. The ground ring is the seat's real radius.

enum St {LOCKED, OPEN, IN_USE, TAKEN, LOST}

const BEAM_H := 38.0                  # m, a lit column (reads from across the island at match zoom)
const STUB_H := 8.0                   # m, a locked seat's stub / the smother's height
const COLLAPSE_S := 0.7               # a used seat's beam sinks this fast (s)
## Per state: the SideColor tone of its beam (an open seat: clear cool-white light, nobody's colour; a used one
## gone dark; the Blight's smother), beam alpha, beam height (m), ring alpha. In use takes the using squad's colour.
const LOOKS := {
	St.LOCKED: {"tone": "beam_locked", "a": 0.4, "h": STUB_H, "ring_a": 0.3},
	St.OPEN: {"tone": "beam_open", "a": 0.7, "h": BEAM_H, "ring_a": 0.85},
	St.IN_USE: {"tone": "", "a": 0.55, "h": BEAM_H, "ring_a": 0.95},
	St.TAKEN: {"tone": "beam_dark", "a": 0.0, "h": 0.0, "ring_a": 0.2},
	St.LOST: {"tone": "beam_lost", "a": 0.6, "h": STUB_H, "ring_a": 0.55},
}
const WORD_MINE := "OURS"
const WORD_RIVAL := "RIVAL"

## One seat's reading: its look, the squad using it and the viewer's own squad (-1: none), the seconds to its
## opening, the hold 0..1.
static func read(m: Match, st: int, team := -1, left := 0.0, prog := 0.0) -> Dictionary:
	return {"st": st, "team": team, "viewer": SideColor.viewer(m), "left": left, "prog": prog}

## The colour of a look for a reading (IN_USE takes the squad's colour as the viewer sees it: squad or rival).
static func color_of(rd: Dictionary) -> Color:
	if int(rd["st"]) == St.IN_USE:
		return SideColor.of_team(int(rd["viewer"]), int(rd["team"])) if int(rd["team"]) >= 0 else Color.WHITE
	return SideColor.tone(LOOKS[int(rd["st"])]["tone"])

## The word floating over a seat: its countdown while locked, whose it is while a squad uses it (a label, so the
## squad and the rival never read by hue alone).
static func tag(rd: Dictionary) -> String:
	match int(rd["st"]):
		St.LOCKED:
			return clock(float(rd["left"]))
		St.IN_USE:
			if int(rd["team"]) >= 0:
				return WORD_MINE if int(rd["team"]) == int(rd["viewer"]) else WORD_RIVAL
	return ""

## The Blight's tide covers a site (needs the Heart: no tide, no loss).
static func smothered(m: Match, p: Vector3) -> bool:
	return Heart.tide_out(m, p) > 0.0

static func clock(s: float) -> String:
	var n := int(ceilf(maxf(s, 0.0)))
	return "%d:%02d" % [n / 60, n % 60]

# ------------------------------------------------------------------ readings of the four seats
## The Heart's early seat, drawn at the Gate: locked until the Heartspark is charged, open while it is out to
## be taken, in use while carried, taken once the Gate fired.
static func early(m: Match) -> Dictionary:
	var h := m.heart
	if h.early_team >= 0:
		return read(m, St.TAKEN)
	if h.state == Heart.S.DONE:
		return read(m, St.LOST)
	if smothered(m, h.gate):
		return read(m, St.LOST)
	if h.state == Heart.S.CARRIED and h.carrier != null:
		return read(m, St.IN_USE, h.carrier.team, 0.0, 1.0)
	if h.spark_live():
		return read(m, St.OPEN)
	var charged_at := Heart.r("wake_s") + Heart.r("charge_s")
	var left := Heart.r("charge_s") - h.charge if h.state == Heart.S.CHARGING else charged_at - m.sess_time()
	return read(m, St.LOCKED, -1, left)

## The Heart's final seat, drawn at the Heart: locked until final_s, open, in use while a squad holds the ring.
static func final(m: Match) -> Dictionary:
	var h := m.heart
	match h.state:
		Heart.S.DONE:
			return read(m, St.TAKEN)
		Heart.S.FINAL:
			if h.final_team >= 0:
				return read(m, St.IN_USE, h.final_team, 0.0, h.final_prog)
			return read(m, St.OPEN)
	return read(m, St.LOCKED, -1, Heart.r("final_s") - m.sess_time())

## A boss lair's escape updraft (Lairs): dormant lairs are no seat (null). `seat_open` and `shut_at` are the
## match times the seat opens and shuts, when the quest schedule sets them (spec task 4; absent: always open);
## a seat nobody used by its shut time is lost.
static func lair(m: Match, L: Dictionary) -> Variant:
	var s := String(L["state"])
	if s == "dormant" or (m.exits and m.exits.seats and not L.get("seat", false)):
		return null      # (with the quest seats on, only the Sealed Lair is a way out)
	if s == "cleared" and not L.get("up_on", false):
		return read(m, St.TAKEN)
	if L.get("up_on", false) or s == "awake":
		var ins: Array = L.get("sealed_in", [])
		return read(m, St.IN_USE, (ins[0] as Hunter).team if not ins.is_empty() else -1, 0.0, 1.0)
	if m.time >= float(L.get("shut_at", INF)) or smothered(m, L["up"]):
		return read(m, St.LOST)
	var opens := float(L.get("seat_open", 0.0))
	return read(m, St.OPEN) if m.time >= opens else read(m, St.LOCKED, -1, opens - m.time)

## An outpost's uplink (Exits): idle open, held (charging, or the lift lit) in use, a lift ridden or shut taken.
## A dark outpost (not the Uplink seat) is no seat (null).
static func uplink(m: Match, x: Dictionary) -> Variant:
	if x.get("dark", false):
		return null
	if x.get("taken", false):
		return read(m, St.TAKEN)
	if m.time >= float(x.get("shut_at", INF)) or smothered(m, x["pos"]):
		return read(m, St.LOST)
	var s := String(x["state"])
	if s in ["charging", "fizzling", "open"] and int(x["team"]) >= 0:
		return read(m, St.IN_USE, int(x["team"]), 0.0, 1.0 if s == "open" else float(x["prog"]))
	if m.time < float(x["open_at"]):
		return read(m, St.LOCKED, -1, float(x["open_at"]) - m.time)
	return read(m, St.OPEN)
