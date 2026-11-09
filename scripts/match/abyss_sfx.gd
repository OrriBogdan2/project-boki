class_name AbyssSfx
extends RefCounted
## The abyss's sounds for one Hunter (sounds from tools/gen_sfx_abyss.py, set in content/sfx/abyss.json).
## Runs for every Hunter on every machine from what is synced (position, velocity, gliding, the overheat
## flag), so teammates hear it too: yours is 2D, everyone else's sits at their position.
##   whoosh   wind rising past you as you fall under an island's lip
##   catch    the glider (or its abyss lift) grabs you: your fall turns into a climb
##   strain   a loop while an overheated glider lifts you at half strength
##   fallout  the point of no return; Match.on_fell plays it for the one who fell, a remote hunter's
##            copy plays it here when its owner reports them out

const FALL_VY := -2.0       # m/s: falling at least this fast under the lip means a fall (whoosh)
const CATCH_VY := 0.5       # m/s: climbing faster than this under a gliding hunter means the lift has them
const WHOOSH_DB := -4.0
const CATCH_DB := -2.0
const STRAIN_DB := -9.0
const FALLOUT_DB := -2.0
enum Phase { IDLE, FALLING, CAUGHT }

var _phase := Phase.IDLE
var _deep := false          # last step: under the lip in the air (a remote hunter's fall-out follows it)

func tick(h: Hunter, dt: float) -> void:
	var was_deep := _deep
	_deep = h.below_lip and not h.grounded and not h.out and not h.dropping
	if h.remote and h.out and was_deep:
		_deep = false
		fall_out(h)
	if not _deep:
		_phase = Phase.IDLE
		return
	if h.vel.y < FALL_VY:
		if _phase == Phase.IDLE:
			_play(h, "abyss_whoosh", WHOOSH_DB)
		_phase = Phase.FALLING
	elif _phase == Phase.FALLING and h.gliding and h.vel.y > CATCH_VY:
		_phase = Phase.CAUGHT
		_play(h, "abyss_catch", CATCH_DB)
	if h.gliding and h.vel.y > 0.0 and h.glide_fuel <= 0.001:
		Sfx.loop_hold("abyss_strain%d" % h.get_instance_id(), "abyss_strain", _at(h), STRAIN_DB)

static func fall_out(h: Hunter) -> void:
	_play(h, "abyss_fallout", FALLOUT_DB)

static func _at(h: Hunter) -> Variant:
	return null if h.is_local() else h.pos

static func _play(h: Hunter, sname: String, db: float) -> void:
	Sfx.play(sname, _at(h), db, 0.05)
