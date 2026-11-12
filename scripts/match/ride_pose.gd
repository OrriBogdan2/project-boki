class_name RidePose
extends RefCounted
## How each Hunter rides the squad rocket (DropRocket, HunterAnim.ride_k): one shared pose (feet on the peg, both
## hands on the bar, chest to the hull) worn each Hunter's own way. A style leaves out what it keeps from DEF.
##   knee  how deep the knees bend (rad; the hips fold half as much)   wide  the feet apart (rad)
##   lean  the chest in toward the hull (rad; below 0 hangs back off the bar at arm's length)
##   tilt  a standing roll (rad)     sway  the wind's buffet (rad)     rate  its pace (1: the shared pace)
##   grip  the hands' gap, a share of the shoulders'   high  the hands over the shoulder line (rig units)
##   look  the head turned off the hull to the ground (rad, + to its right)   nod  the head down (+) or up (-)
##   bob   a bounce in the knees (rad; the feet stay on the peg)
const DEF := {"knee": 1.5, "wide": 0.1, "lean": 0.2, "tilt": 0.0, "sway": 0.03, "rate": 1.0, "grip": 0.3,
	"high": -0.1, "look": 0.0, "nod": 0.0, "bob": 0.0}
const STYLE := {
	# Lace: tall, eyes on the ground below
	"archer": {"knee": 1.2, "lean": 0.1, "sway": 0.02, "look": 0.55, "nod": 0.3},
	# Kael: hunched, fists wide
	"juggernaut": {"knee": 1.75, "lean": 0.4, "sway": 0.015, "rate": 0.7, "grip": 0.55, "high": 0.0},
	# Vex: hangs back, easy
	"gunslinger": {"knee": 1.2, "lean": -0.12, "tilt": 0.12, "sway": 0.05, "rate": 0.8, "look": -0.5},
	# Albert: square and still
	"bulwark": {"knee": 1.35, "wide": 0.18, "lean": 0.15, "sway": 0.01, "rate": 0.6, "grip": 0.22},
	# Cinder: restless
	"ashwick": {"sway": 0.05, "rate": 1.8, "bob": 0.1, "look": 0.35},
	# Meeko: hugs it
	"tender": {"knee": 1.8, "lean": 0.45, "grip": 0.2, "high": 0.05, "sway": 0.04, "rate": 2.2, "nod": -0.15},
	# Tenzo: bouncing on the peg
	"dolm": {"wide": 0.16, "bob": 0.2, "rate": 1.4, "look": -0.3},
	# Grimble: low and heavy
	"dredge": {"knee": 1.75, "lean": 0.35, "rate": 0.7, "nod": 0.3},
	# Neve: calm, upright
	"rimewright": {"knee": 1.4, "lean": 0.08, "sway": 0.008, "rate": 0.5, "nod": 0.1},
	# Sparkle: chin up, floaty
	"mage": {"knee": 1.3, "tilt": -0.08, "bob": 0.12, "rate": 0.7, "look": 0.4, "nod": -0.2},
	# Sable: coiled, picking a spot
	"thief": {"knee": 1.85, "lean": 0.25, "sway": 0.015, "look": 0.7, "nod": 0.45},
	# Motley: jaunty, head cocked
	"ostra": {"tilt": 0.1, "high": 0.05, "rate": 1.2, "look": -0.4},
	# Gil: plucky, looking up the hull
	"gil": {"knee": 1.6, "sway": 0.035, "rate": 1.5, "nod": -0.25},
}

## `arch`'s ride: DEF with its own style over it.
static func of(arch: String) -> Dictionary:
	var d := DEF.duplicate()
	d.merge(STYLE.get(arch, {}), true)
	return d
