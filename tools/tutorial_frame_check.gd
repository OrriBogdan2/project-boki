extends "res://tools/tutorial_hud_check.gd"
## --tutorial-frame-<starter>-check: framing at the match camera, per starter (Lace, Kael, Vex), at 1280x720: at every step
## the thing to act on (the camp's monster, the pad's sign, the glove, the outpost, the stop) is on screen for most
## of the step (a walk to a far stop: by the time you get there; the marker's edge arrow and the Boki lead the way
## meanwhile) and, where it is a thing, at least MIN_PX tall. One row per step is printed.
## Its own flags, one per starter (--tutorial-frame-archer-check, -juggernaut-, -gunslinger-): the driver cannot
## start a second course in a process that has already played one (it stands at the landing), so each starter
## needs a fresh process. Not a row of --tutorial-hud-check for the same reason.

func run(mn: Node, arch := "") -> void:
	main = mn
	Save.no_write = true
	_framing(arch)
	print("TUTHUD DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
