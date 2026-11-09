class_name AirLimits
extends RefCounted
## What you may do in the air: items 162 and 162b.
## - The opening drop (skyship or tutorial) is steering only: the glide heading and the dive. No dash, jump,
##   ability, glove, belt item, weapon or Boki throw until you land; the HUD greys the slots meanwhile. Space
##   only deploys the canopy out of the dive.
## - The glider never opens during an ability or attack animation (a wind-up, a hold, a cast, a dash, a kit
##   move's recovery). Held glide opens it the moment the animation ends, with the speed it left you, so the
##   momentum carries into the glide. A move that travels (a dash, a Lunge) ends with its travel, and a kit's
##   Shift move (a skate) is the dash's, so the glider takes the burst the step it ends (--move-feel-check
##   dashglide_reopen_frames, --airdash-glide-check). A jump off the ground ends the move it left (a slam's
##   recovery doesn't hold the glider shut after you jump out of it). An open glider is never folded by this rule.

## Every press the drop ignores (move, aim and glide stay: they steer).
const TRAVEL_JOIN_S := 0.05      # s: a kit move started this close after a travel or Shift press is that move's
const DROP_KEYS := ["dash", "jump", "fire", "sec", "sec_hold", "sig", "skill", "ult", "throw", "kin_ab", "swap",
		"util1", "util2", "util3", "util4", "gear1", "gear2", "crouch", "interact"]

## The opening drop, in the air: nothing but steering.
static func drop_locked(h: Hunter) -> bool:
	return h != null and h.dropping and not h.grounded

## Drops this step's presses while the drop lasts (before any of them is read).
static func gate_drop(h: Hunter) -> void:
	if not drop_locked(h):
		return
	DropLaunch.gate(h)               # item 163: locked into the squad launch, no keys at all
	for key in DROP_KEYS:
		if key != "jump" or not h.diving:
			h.inp[key] = false
	h.dash_buf = 0.0

## True while an ability or attack animation runs, so the glider can't open yet.
static func glide_locked(h: Hunter) -> bool:
	if h.roll_t > 0.0 or not h.charge.is_empty():
		return true
	var k: ArchKit = h.ak
	if k == null:
		return false
	if k.rmb_down or k.dash_t >= 0.0 or not k.chg.is_empty() or not k.fuse.is_empty():
		return true
	if k.cast_locked() or k.locks_glide():
		return true
	return move_running(k, h)

## A kit move still inside its keys. A held move (a hold pose) counts only through the hold itself above,
## so a pose left on its last key never blocks the glider.
static func move_running(k: ArchKit, h: Hunter) -> bool:
	if k.anim_id == "" or k.anim_at <= maxf(maxf(h.dash_at, k.dash_press_at) + TRAVEL_JOIN_S, h.jump_at):
		return false
	var mv := HunterAnim.km_def(k.anim_id)
	if mv.is_empty() or mv.get("hold", false):
		return false
	var keys: Array = mv["keys"]
	return k.m.time - k.anim_at < float((keys[-1] as Array)[0])
