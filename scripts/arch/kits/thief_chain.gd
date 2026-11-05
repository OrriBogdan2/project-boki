class_name ThiefChain
extends RefCounted
## Sable's Vault loop (OWNER_REVIEW_1103 item 53): Vault, empowered bolt, reset, Vault, with no cap. It picks the
## next flip of the routine, so a chain never repeats one clip, and it keeps the Shift presses of a fast loop:
## one mid-flip waits for the flip's end, one made while the empowered bolt flies waits to see if it lands (the
## reset then pays for a real Vault, not the long dash). Owned by ThiefKit (on_dash, _tick, _bolt, _primed_hit).

const ROUTINE_GAP := 2.0       # s after a reset that the next Vault still continues the routine
const PRESS_TAIL := 0.05       # s a held press outlives the flip, so the end of the flip can't drop it
const ROUTINE_LEN := 3         # the routine's flips: cartwheel, somersault, twist

var k: ThiefKit
var step := 0                  # the routine's flip for the next Vault
var gap_t := 0.0
var flying_t := 0.0            # s the thrown empowered bolt can still land
var waiting := false           # a Shift press waits for that bolt
var resets := 0                # (tests, demo)

func _init(kit: ThiefKit) -> void:
	k = kit

## The flip for a Vault going `dir`: alone or out of a broken chain, the source's cartwheel (to her right or left);
## chained, a somersault (the way she goes) and then a twist.
func next_flip(dir: Vector2) -> String:
	var h := k.h
	if gap_t <= 0.0:
		step = 0
	match step % ROUTINE_LEN:
		1:
			return "thf_vault_f" if dir.dot(Vector2(-sin(h.face), -cos(h.face))) >= 0.0 else "thf_vault_b"
		2:
			return "thf_vault_twist"
	return "thf_vault_r" if dir.dot(Vector2(cos(h.face), -sin(h.face))) >= 0.0 else "thf_vault_l"

## The empowered bolt is thrown: it can land for `life` seconds.
func bolt_thrown(life: float) -> void:
	flying_t = life

## ... and it hit, or ran out.
func bolt_ended() -> void:
	flying_t = 0.0

## The Vault is back: the routine moves on.
func on_reset() -> void:
	resets += 1
	step += 1
	gap_t = ROUTINE_GAP

## A Shift press with no charge on the ground while the empowered bolt flies waits for it (true: on_dash stops).
func hold_for_bolt(use_ex: bool) -> bool:
	waiting = use_ex and k.h.grounded and flying_t > 0.0
	return waiting

func tick(dt: float) -> void:
	var h := k.h
	gap_t = maxf(0.0, gap_t - dt)
	flying_t = maxf(0.0, flying_t - dt)
	if h.dash_buf > 0.0 and h.roll_t > 0.0 and (h.dashes >= 1.0 or flying_t > 0.0):
		h.dash_buf = maxf(h.dash_buf, h.roll_t + PRESS_TAIL)      # the shared buffer alone is 0.18s of a 0.48s flip
	if waiting and flying_t <= 0.0:
		waiting = false
		h.do_dash()
