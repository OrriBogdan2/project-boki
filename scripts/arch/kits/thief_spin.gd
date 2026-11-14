class_name ThiefSpin
extends RefCounted
## The trail of Sable's Vault flip: while the body turns (the source's Cartwheel leaves a trail that spins with
## it), a hand-side tip and a foot-side tip trace the turn and each leaves a streak behind it, laid in short pieces.
## Nothing at the start or the end of the flip, only the turn itself. Owned by ThiefKit (_tick_trail).

const TURN_FROM := 0.1                 # s into the flip's animation where the turn starts (kmoves_dj.gd thf_vault_*)
const TURN_TO := 0.3                   # ... and where it ends
const TIP_R := 0.95                    # m from her middle to a hand or a foot
const MIDDLE := 0.9                    # m above her feet
const WIDTH := 0.32                    # m: a streak's width
const FADE := 0.3                      # s a piece of the trail takes to fade
const PITCHED := ["thf_vault_f", "thf_vault_b"]     # these turn head over heels; the others turn side over side

var k: ThiefKit
var tips: Array[Vector3] = []          # where the two tips were last step (empty: not turning)
var pieces := 0                        # trail pieces laid (tests)

func _init(kit: ThiefKit) -> void:
	k = kit

## One step: add the piece of trail each tip has covered since the last one.
func tick(col: Color, hot: Color) -> void:
	var u: float = (k.m.time - k.anim_at - TURN_FROM) / (TURN_TO - TURN_FROM)
	if k.anim_id not in ThiefKit.CARTWHEELS or u < 0.0 or u > 1.0 or not k.tells_visible():
		tips.clear()
		return
	var face := k.h.face
	var axis := Vector3(-sin(face), 0, -cos(face)) if k.anim_id in PITCHED else Vector3(cos(face), 0, -sin(face))
	var turn: float = TAU * u * (-1.0 if k.anim_id in ["thf_vault_l", "thf_vault_b"] else 1.0)
	var out := (Vector3.UP * cos(turn) + axis * sin(turn)) * TIP_R
	var mid := k.h.pos + Vector3(0, MIDDLE, 0)
	var now: Array[Vector3] = [mid + out, mid - out]
	if tips.size() == 2:
		for i in 2:
			k.fx().seg(tips[i], now[i], WIDTH, col, hot, FADE)
			pieces += 1
	tips = now
