class_name PressDeny
extends RefCounted
## A refused ability press (on cooldown, no charge left, stunned or hexed, a kit's lock-out such as Cinder's Flue
## Flight): the slot's frame pulses red once (HudSlot.DENY_T) and a quiet ui_deny tick plays, at most once per
## THROTTLE_S per slot so a mashed key never rattles. Hunter._ab_feedback and the home dash slot send every deny
## here. A press DashFlow (or a kit's own buffer) is still holding never gets here: it only denies once it lets go.

const THROTTLE_S := 0.3      # s: the shortest gap between two denies on the same slot
const VOL_DB := -14.0        # dB: the tick sits under the fight

static var last := {}        # slot id -> Time.get_ticks_msec() of its last deny
static var raised := 0       # denies that went out (checks read it)

## `host` keeps the per-slot animation state (Hud or HomeDashSlot: slot_fx). False when throttled.
static func raise(host, slot: String) -> bool:
	var now := Time.get_ticks_msec()
	if last.has(slot) and now - int(last[slot]) < int(THROTTLE_S * 1000.0):
		return false
	last[slot] = now
	raised += 1
	host.slot_fx[slot] = {"kind": "deny", "t": 0.0}
	Sfx.play("ui_deny", null, VOL_DB)
	return true
