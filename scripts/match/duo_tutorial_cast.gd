class_name DuoTutorialCast
extends RefCounted
## The 2v2 tutorial's other three hunters (DuoTutorial): the guide on your side and the two rivals. All
## three are ordinary bots (Bot); after they think, this trims what they may do for the beat, as the Arena
## trims its sparring bot. A knocked rival is back at its corner after a beat; the guide never bleeds out.

const KEYS := ["fire", "dash", "jump", "sig", "sec", "ult", "gear1", "gear2", "throw"]
const BESIDE := 2.4          # m to your side the guide keeps when she follows
const FOLLOW_SLACK := 1.2    # m she lets you drift before she walks after you
const STRAFE_HZ := 0.9       # rad/s of a strafing rival's side-to-side
const WILD_AHEAD := 5.0      # m in front of you the wild Boki turns up
const WILD_HP := 0.3         # of its health the wild Boki arrives with (two or three hits)
const KEEP_R := 12.9         # m from the ring's centre: past this a hunter is in or over the wall (its tiles start ~12)
const BACK_R := 11.5         # m from the centre such a hunter is put back at

var tu: DuoTutorial
var m: Match
var foe_mode := "still"
var guide_mode := "follow"
var _down_t := {}            # rival -> s it has been down
var kept := 0                # times a hunter was put back inside the ring (a hard knock over the wall)

func _init(owner_tut: DuoTutorial) -> void:
	tu = owner_tut
	m = owner_tut.m

## The guide: an archetype other than yours, on your team, no Boki of her own (one less thing to read).
func spawn_guide(at: Vector3) -> Hunter:
	var arch := String(tu.cfg["guide"])
	if Arch.exists(String(m.opts.get("arch", ""))) and String(m.opts["arch"]) == arch:
		arch = String(tu.cfg["guide_alt"])
	var g := _bot(m.player.team, arch, HeroTitle.base_name(arch), at, "medium")
	g.face = 0.0
	return g

## Rival i (content: name, archetype) at its corner, dealing foe_dmg of a bot's usual damage.
func spawn_foe(i: int, at: Vector3) -> Hunter:
	var pick: Array = tu.cfg["foes"][i]
	var f := _bot(m.player.team + 1, String(pick[1]), String(pick[0]), at, "easy")
	(f.ai["diff"] as Dictionary)["dmg"] = float(tu.cfg["foe_dmg"])
	return f

func _bot(team: int, arch: String, pname: String, at: Vector3, diff: String) -> Hunter:
	var kit := {"arch": arch, "weapon": Arch.signature(arch)}
	var h := m.make_hunter(m.next_id("duo"), team, Arch.weight(arch), pname, "bot", {}, at, kit)
	h.ai = m.bot_brain.new_mind(m.rng, float(Data.BOT_DIFF[diff]["skill"]), Data.BOT_DIFF[diff].duplicate())
	h.tonics = 0
	return h

## The capture beat's wild Boki, a few steps in front of you, already roughed up.
func spawn_wild() -> Kin:
	var p := m.player
	var ahead := Vector2(DuoTutorial.RING_C.x - p.pos.x, DuoTutorial.RING_C.y - p.pos.z).normalized() * WILD_AHEAD
	var at := Vector3(p.pos.x + ahead.x, p.pos.y, p.pos.z + ahead.y)
	var rec := Save.new_kin(String(Data.common_kin()[2]), "", m.kin_seed("duo_wild"))
	var k := m.spawn_wild(rec, at)
	k.hp = k.max_hp * WILD_HP
	return k

## Knocks the wild Boki out for you (the stall help): the guide's bonk.
func daze(k: Kin) -> void:
	k.hurt(k.hp + 1.0, tu.guide)

## A beat starts: what the rivals and the guide may do in it.
func begin(foes_how: String, guide_how: String) -> void:
	foe_mode = foes_how
	guide_mode = guide_how
	if guide_mode == "down" and not tu.guide.downed:
		m.knock(tu.guide, tu.foes[0], {})

func tick(dt: float) -> void:
	for i in tu.foes.size():
		_foe(tu.foes[i], i, dt)
	_guide()
	for h in [m.player, tu.guide] + tu.foes:
		_keep_in(h)
	if m.truce:
		m.truce.offers.clear()      # (sparring partners don't offer a truce)

## The ring is closed: a hunter knocked into or over the wall lands back on the floor beside it.
func _keep_in(h: Hunter) -> void:
	var off := Vector2(h.pos.x, h.pos.z) - DuoTutorial.RING_C
	if off.length() <= KEEP_R:
		return
	kept += 1
	var back := DuoTutorial.RING_C + off.normalized() * BACK_R
	h.teleport(Vector3(back.x, m.world.ground_at(back.x, back.y), back.y))
	h.vel = Vector3.ZERO

func _foe(f: Hunter, i: int, dt: float) -> void:
	f.reveal_t = maxf(f.reveal_t, 0.3)       # (always in sight: nothing hides in a sparring ring)
	if f.downed:
		_down_t[f] = float(_down_t.get(f, 0.0)) + dt
		if float(_down_t[f]) >= float(tu.cfg["knock_hold"]):
			_back_up(f, i)
		return
	var p := m.player
	match foe_mode:
		"still", "hold":
			_hush(f)
			f.inp["move"] = _toward(f, tu.foe_home(i), 0.6) if foe_mode == "hold" else Vector2.ZERO
			f.inp["aim"] = p.pos + Vector3(0, 0.9, 0)
		"strafe":
			_hush(f)
			f.inp["move"] = Vector2(sin(m.time * STRAFE_HZ + i * PI), 0.0)
		"poke":
			var fire: bool = f.inp["fire"] and _bursting(i)
			_hush(f)
			f.inp["fire"] = fire
			f.inp["aim"] = p.pos + Vector3(0, 0.9, 0)
		"fight":
			f.inp["ult"] = false

## In a poke beat the rivals take turns: one short burst each, then a rest to slide in.
func _bursting(i: int) -> bool:
	var on := float(tu.cfg["poke_on"])
	var cycle := on + float(tu.cfg["poke_off"])
	return fmod(m.time + i * cycle * 0.5, cycle) < on

func _back_up(f: Hunter, i: int) -> void:
	_down_t.erase(f)
	m.revive_hunter(f, null)
	f.hp = f.max_hp
	f.teleport(tu.foe_home(i))
	if foe_mode in ["fight", "full"]:
		tu.bark("foe_back")

func _guide() -> void:
	var g := tu.guide
	g.reveal_t = maxf(g.reveal_t, 0.3)
	if g.downed:
		g.down_hp = Data.MATCH["down_hp"]      # (she waits for you: no bleeding out)
		if guide_mode != "down":
			m.revive_hunter(g, null)
		return
	match guide_mode:
		"wait":
			_hush(g)
			g.inp["move"] = Vector2.ZERO
			g.inp["aim"] = m.player.pos + Vector3(0, 0.9, 0)
		"follow", "down":
			_hush(g)
			g.inp["move"] = _toward(g, _beside(), FOLLOW_SLACK)
			var near := _nearest_foe(g)
			if near:
				g.inp["aim"] = near.pos + Vector3(0, 0.9, 0)
		"focus":
			if tu.focus and not tu.focus.downed:
				g.ai["tgt"] = tu.focus
				g.inp["aim"] = tu.focus.pos + Vector3(0, 0.9, 0)
				_mark(tu.focus)

## Where the guide stands when she follows: at your side, square to where you aim.
func _beside() -> Vector3:
	var p := m.player
	var fwd := p.aim_dir()
	var side := Vector2(-fwd.y, fwd.x) * BESIDE
	return Vector3(p.pos.x + side.x, p.pos.y, p.pos.z + side.y)

## Her enemy ping follows the rival she marked.
func _mark(f: Hunter) -> void:
	for pg in m.pings:
		if pg.get("by") == tu.guide:
			pg["pos"] = Vector3(f.pos.x, f.pos.y, f.pos.z)

func _nearest_foe(h: Hunter) -> Hunter:
	var best: Hunter = null
	for f in tu.foes:
		if not f.downed and (best == null or h.flat_dist(f) < h.flat_dist(best)):
			best = f
	return best

func _toward(h: Hunter, at: Vector3, slack: float) -> Vector2:
	var d := Vector2(at.x - h.pos.x, at.z - h.pos.z)
	return d.normalized() if d.length() > slack else Vector2.ZERO

static func _hush(h: Hunter) -> void:
	for k in KEYS:
		h.inp[k] = false
