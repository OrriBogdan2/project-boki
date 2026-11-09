extends RefCounted
## Sparkle's bubblegum: she blows the bubble up and pops it (kit move mage_gum, clip "gum"), as an idle fidget, on a
## knock and after Kitefall. The bubble itself is on the model (bone "gum"); the pop is the sound mage_bubble_pop.

const IDLE_EVERY := 9.0        # s standing around between fidgets
const RETRY := 2.0             # s before trying again when she's busy
const POP_AT := 0.9            # s into the move: the clip's pop
const STILL := 0.5             # m/s
const QUIET := 0.7             # s since her last move before the gum may play

var kit: MageKit
var wait := IDLE_EVERY
var blows := 0                 # (tests)

func _init(owner_kit: MageKit) -> void:
	kit = owner_kit

func tick(dt: float) -> void:
	wait -= dt
	if wait > 0.0:
		return
	wait = RETRY
	if Vector2(kit.h.vel.x, kit.h.vel.z).length() < STILL and not kit.busy() and blow():
		wait = IDLE_EVERY

## Blows and pops it, unless a move of hers is playing. True when it started.
func blow() -> bool:
	var h := kit.h
	if h == null or not is_instance_valid(h) or h.dead or h.downed:
		return false
	if kit.anim_id != "" and kit.m.time - kit.anim_at < QUIET:
		return false
	kit.play("mage_gum")
	blows += 1
	kit.m.later(POP_AT, _pop)
	return true

func _pop() -> void:
	if kit.h != null and is_instance_valid(kit.h):
		kit.m.sfx("mage_bubble_pop", kit.h.pos, -8.0)
