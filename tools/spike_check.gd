extends RefCounted
## --spike-check (docs/SPIKE_SLAM.md): every ability whose data carries a spike drives a gliding foe to the
## ground within SPEC_T and stuns it on landing; the dives (Kael's Meteor Drop, Tenzo's hop and dive landings,
## Grimble's air Anchor) hit the same foe without spiking it. Runs in the archetype check's flat strip.
## Prints "SPIKECHECK <name> PASS|FAIL" and "SPIKECHECK DONE, failures: N".

const SPEC_T := 0.6         # s: from a 2.5m glide to the ground once spiked (Spike.FALL_VY gives about 0.15s)
const LIFT := 2.5           # m: the foe's glide height over the strike

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("SPIKECHECK %-60s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _dolm()
	await _dredge()
	await _kael()
	print("SPIKECHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Puts T gliding `up` m over `at` with a full glider (a plain hit can't overheat it).
func _glide(T: Hunter, at: Vector3, up: float) -> void:
	ak.fresh(T)
	T.teleport(at + Vector3(0, up, 0))
	T.grounded = false
	T.gliding = true
	T.glide_fuel = 1.0
	T.shot_down = false

## Steps until T lands (glide held all the way, so only a spike brings it down fast); s, or -1 past `limit`.
func _land_t(m: Match, T: Hunter, limit: float) -> float:
	var t := 0.0
	while t < limit:
		T.inp["glide"] = true
		ak.step(m, ak.DT)
		t += ak.DT
		if T.grounded:
			T.inp["glide"] = false
			return t
	T.inp["glide"] = false
	return -1.0

## A spike: hurt, driven down at once, on the ground within SPEC_T, stunned by the landing.
func _spiked(m: Match, T: Hunter, what: String) -> void:
	var hit: float = ak.dmg(T)
	var vy := T.vel.y
	var t := _land_t(m, T, 2.0)
	ok("%s spikes a glider: hit, driven down, landed in %.1fs" % [what, SPEC_T],
			hit > 0.0 and vy <= Spike.FALL_VY + 0.1 and t >= 0.0 and t <= SPEC_T,
			"took %.0f, vy %.1f, landed after %.2fs" % [hit, vy, t])
	ok("%s: the landing stuns (the shared spike landing)" % what, T.stun_t > 0.3 and not T.shot_down,
			"stun %.2f" % T.stun_t)

## A dive: it hits the foe in the air but does not spike it.
func _not_spiked(T: Hunter, what: String) -> void:
	ok("%s hits a glider but does not spike (a dive)" % what,
			ak.dmg(T) > 0.0 and not T.shot_down and T.vel.y > Spike.FALL_VY + 1.0,
			"took %.0f, vy %.1f, shot_down %s" % [ak.dmg(T), T.vel.y, T.shot_down])

## Tenzo's Quakefall: the tap slam spikes; the hop and dive landings (a slam at his feet) do not.
func _dolm() -> void:
	var r: Array = ak.setup("dolm", 2.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DolmKit = P.ak
	ak.aim_at(P, T.pos)
	_glide(T, K.slam.tap_spot(), LIFT)
	var d0 := K.dunks
	K._slam(0.0, false)
	ok("Quakefall tap counts its spike", K.dunks == d0 + 1, "dunks %d" % (K.dunks - d0))
	_spiked(m, T, "Quakefall tap")
	_glide(T, P.pos + Vector3(1.3, 0, 0), 1.0)
	K._slam(0.5, true)
	_not_spiked(T, "Quakefall hop/dive landing")
	await ak.done(m)

## Grimble's Anchor Drop: the ground slam spikes; the air dive's landing does not.
func _dredge() -> void:
	var r: Array = ak.setup("dredge", 1.6)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	K.slam_dir = Vector2(1, 0)
	_glide(T, P.pos + Vector3(1.6, 0, 0), 1.2)
	K._anchor()
	_spiked(m, T, "Anchor Drop")
	_glide(T, P.pos + Vector3(1.2, 0, 0), 1.0)
	K._quake(K.ground(P.pos), 4.0)
	_not_spiked(T, "Anchor Drop air dive")
	await ak.done(m)

## Kael's Meteor Drop (air RMB) is a dive: the owner's call (11-10), it never spikes.
func _kael() -> void:
	var r: Array = ak.setup("juggernaut", 0.6)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	_glide(T, P.pos + Vector3(0.6, 0, 0), 1.0)
	K.meteor._hit(P.pos)
	_not_spiked(T, "Kael Meteor Drop")
	await ak.done(m)
