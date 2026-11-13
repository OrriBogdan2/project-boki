class_name DuoTutorialDrive
extends RefCounted
## Test driver: plays the 2v2 tutorial (DuoTutorial) as a player would, so the whole run can be checked
## headless (--duo-tutorial-check), watched (--duo-tutorial --duo-test) and filmed (--gameplay-media clip 9).
## One plain move per beat: walk to the guide, slide, hit the first rival, cast, slide out of shots, hit
## the marked rival, send the Boki, knock out and scan the wild one, stand on the guide's wisp, merge, fight.

const KEYS := ["fire", "sec", "sig", "dash", "jump", "ult", "interact", "throw", "gear1", "gear2"]
const REACH_MELEE := 1.6     # m a blade swings from
const REACH_RANGED := 7.0    # m a gun or bow shoots from
const DODGE_KEEP := 7.0      # m from the rivals while they poke
const RMB_HOLD := 0.5        # s the right click is held each try

static var _last_beat := -1

static func drive(m: Match, tu: DuoTutorial) -> void:
	var p := m.player
	for k in KEYS:
		p.inp[k] = false
	p.inp["move"] = Vector2.ZERO
	if tu.beat != _last_beat:
		_last_beat = tu.beat
		print("DUO beat %d %s t=%.1f" % [tu.beat, tu.id(), m.time])
	if tu.finished or tu.gap_t > 0.0 or p.downed:
		return
	var pulse := fmod(m.time, 0.5) < 0.1      # a tap: pressed for a few steps every half second
	match tu.id():
		"meet", "revive":
			_go(p, tu.guide.pos, 0.6)
		"slide":
			p.inp["move"] = Vector2(cos(m.time), sin(m.time))
			p.inp["dash"] = pulse
		"attack":
			_fight(m, tu.foes[0])
		"sec":
			_fight(m, tu.foes[0], false)
			p.inp["sec"] = fmod(m.time, 1.5) < RMB_HOLD      # held a moment: a kit with a draw looses it on release
			p.inp["sec_hold"] = p.inp["sec"]
		"kin":
			_fight(m, tu.foes[0], false)
			p.inp["sig"] = pulse
		"dodge":
			var f: Hunter = tu.foes[1]
			p.inp["aim"] = f.pos + Vector3(0, 0.9, 0)
			p.inp["move"] = f.dir_to(p) if p.flat_dist(f) < DODGE_KEEP else p.dir_to(f) * 0.3
			p.inp["dash"] = tu.danger()
		"focus":
			_fight(m, tu.foes[1])
		"boki":
			_fight(m, tu.foes[0], false)
			if fmod(m.time, 1.5) < Match.DT:
				KinCommand.tap(p)
		"capture":
			_capture(m, tu)
		"ult":
			_fight(m, tu.foes[0], false)
			p.inp["ult"] = pulse
		"finale":
			var f := _nearest(tu)
			if f:
				_fight(m, f)
				p.inp["sec"] = fmod(m.time, 3.0) < 0.1
				p.inp["sig"] = fmod(m.time, 5.0) < 0.1

## Walk to the target until in reach, aim at it, attack (fire: the attack key as a player works it).
static func _fight(m: Match, f: Hunter, fire := true) -> void:
	var p := m.player
	p.inp["aim"] = f.pos + Vector3(0, 0.9, 0)
	var reach := REACH_MELEE if p.wpn.get("melee", false) else REACH_RANGED
	_go(p, f.pos, reach)
	p.inp["fire"] = fire and TutorialDrive.fire_key(m)

static func _capture(m: Match, tu: DuoTutorial) -> void:
	var p := m.player
	var k := tu.wild
	if k == null or not is_instance_valid(k):
		return
	p.inp["aim"] = k.pos + Vector3(0, 0.4, 0)
	if k.state == "dazed":
		_go(p, k.pos, 1.0)
		p.inp["interact"] = p.flat_dist(k) < 1.6 and Capture.state(p).get("phase", "") != "scan"
		return
	var reach := REACH_MELEE if p.wpn.get("melee", false) else REACH_RANGED * 0.6
	_go(p, k.pos, reach)
	p.inp["fire"] = TutorialDrive.fire_key(m)

static func _go(p: Hunter, at: Vector3, reach: float) -> void:
	var d := Vector2(at.x - p.pos.x, at.z - p.pos.z)
	p.inp["move"] = d.normalized() if d.length() > reach else Vector2.ZERO

static func _nearest(tu: DuoTutorial) -> Hunter:
	var best: Hunter = null
	for f in tu.foes:
		if not f.downed and (best == null or tu.m.player.flat_dist(f) < tu.m.player.flat_dist(best)):
			best = f
	return best
