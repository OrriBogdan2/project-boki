class_name LairBreach
extends RefCounted
## Breaking a lair's gate down: the way into a lair whose entry lists "breach" (every shipped lair since
## the owner's order of 11-11: slower and harder to get into than a vault lock). A Gate Seal of stone
## blocks is braced across the portcullis. It is a ward-family monster (Data.MOBS "gate"), so every shot,
## swing, ability, Boki strike and blast already hurts it, and bots fight it like any monster. It breaks
## in STAGES steps: each new crack drops blocks out of it with debris, a shake, a crumble and a loud ping
## that calls guards, and the lair's label counts it down. Walking away resets nothing: after MEND_IDLE s
## without a hit it knits back slowly, but never past its last crack. The last stage breaks it and the
## gate opens (Lairs.open). On lairs that also have runes or ward stones, each one lit or broken knocks
## SHARE off the seal instead of opening the gate outright.
##
## Time to get in at tier 0 (the seal's 2000 health, Data.MOBS "gate"; --lair-breach-check times it):
## one bot ~2 min, fighting the guards each crack calls; three bots ~20 s. (The dial: 6.5 s pressed perfectly.)

const STAGES := 4  # cracks at 25%, 50% and 75% of the way; the fourth breaks it
const MEND_IDLE := 15.0  # s without a hit before the seal starts to knit back
const MEND_RATE := 0.01  # share of its health it knits back a second after that, never past its last crack
const SHARE := 0.2  # share of the seal a lit rune or a broken ward stone knocks off
const STAGE_GUARDS := 2  # guards each new crack calls out
const STAND := 2.4  # m out from the seal a bot stands to batter it
const PROMPT_R := 4.0  # m from the seal its prompt shows
const LOOK_T := 1.0  # s between a client's looks for the seal among the monsters it was sent
const FALL := [[], ["B30"], ["B32", "B21"], ["B10", "B22", "B31"]]  # blocks each stage knocks out
const CRACK_SFX := ["", "br_crack", "rime_crack", "br_crumble"]  # each stage's crack

var m: Match
var lairs: Lairs


func _init(match_node: Match, lairs_sys: Lairs) -> void:
	m = match_node
	lairs = lairs_sys


## Where a lair's seal stands: on the tile just outside its gate.
static func anchor(l: Dictionary, w: World) -> Vector3:
	var out: Vector2 = l["out"]
	var gc: Vector3 = l["gate_c"]
	var at := Vector3(floor(gc.x) + 0.5 + out.x, 0.0, floor(gc.z) + 0.5 + out.y)
	at.y = w.ground_at(at.x, at.z)
	return at


## The seal across a lair's gate, set when the lair goes live (the host's; clients get it with the monsters).
func spawn(l: Dictionary) -> void:
	var at: Vector3 = l["seal_at"]
	var mb := m.spawn_mob("gate", at)
	mb.teleport(at)
	mb.camp = at
	mb.set_meta("lair", l["i"])
	l["seal"] = mb
	l["seal_hit_at"] = m.time


## The live seal of a lair (null when it's broken, not here yet or the lair has none). A client finds
## it among the monsters the host sent, by where it stands.
func seal_of(l: Dictionary) -> Mob:
	var mb = l.get("seal")
	if mb != null and is_instance_valid(mb) and not (mb as Mob).dead:
		return mb
	if not l.has("seal_at") or not m.net_on or m.is_host or m.time < float(l.get("seal_look", 0.0)):
		return null
	l["seal_look"] = m.time + LOOK_T
	for o in m.mobs:
		if o.mkind == "gate" and not o.dead and o.flat_dist(l["seal_at"]) < 1.0:
			l["seal"] = o
			return o
	return null


## How far it's broken: 0 whole .. STAGES - 1 one crack from breaking.
static func stage_of(mb: Mob) -> int:
	return clampi(int((1.0 - mb.hp / mb.max_hp) * STAGES), 0, STAGES - 1)


## Share of the seal knocked down, 0..1.
static func done_k(mb: Mob) -> float:
	return clampf(1.0 - mb.hp / mb.max_hp, 0.0, 1.0)


## The hunter behind a hit (a Boki's owner), or null.
static func hunter_of(by: Ent) -> Hunter:
	if by is Kin and (by as Kin).owner_h:
		return (by as Kin).owner_h
	return by as Hunter if by is Hunter else null


## A hit landed on the seal (Lairs.on_ward_hit): the mend waits again.
func on_hit(l: Dictionary) -> void:
	l["seal_hit_at"] = m.time


## A lit rune or a broken ward stone knocks a share off the seal. False when the lair has no seal up
## (the caller opens the gate the old way).
func weaken(l: Dictionary, by: Hunter) -> bool:
	var mb := seal_of(l)
	if mb == null:
		return false
	mb.hurt(mb.max_hp * SHARE, by, {"src": "seal"})
	return true


func tick(l: Dictionary, dt: float) -> void:
	if l["state"] != "sealed" or not l.has("seal_at"):
		return
	var mb := seal_of(l)
	if mb == null:
		return
	var out: Vector2 = l["out"]
	mb.face = atan2(out.x, out.y)  # (its slab's -z toward the bars)
	if not mb.remote:
		# a wall: knocks and pulls don't move it
		mb.pos = l["seal_at"]
		mb.prev = mb.pos
		mb.vel = Vector3.ZERO
		_mend(l, mb, dt)
	var was := int(l.get("seal_stage", 0))
	var now := stage_of(mb)
	for k in range(was + 1, now + 1):
		_crack(l, mb, k)
	l["seal_stage"] = maxi(was, now)
	_show(l, mb)


func _mend(l: Dictionary, mb: Mob, dt: float) -> void:
	if m.time - float(l.get("seal_hit_at", 0.0)) < MEND_IDLE:
		return
	var cap := mb.max_hp * (1.0 - float(l.get("seal_stage", 0)) / STAGES) - 0.01
	if mb.hp < cap:
		mb.hp = minf(cap, mb.hp + mb.max_hp * MEND_RATE * dt)


## A new crack: its blocks fall out in a burst of rubble, the ground shakes, it crumbles loudly, everyone
## near hears it and guards come.
func _crack(l: Dictionary, mb: Mob, k: int) -> void:
	var slab: Node3D = mb.model.get_node_or_null("Slab") if mb.model else null
	if slab:
		slab.get_node("Crack%d" % k).visible = true
		for bn in FALL[k]:
			var b: Node3D = slab.get_node(bn)
			b.visible = false
			if m.brk:
				m.brk.show_break(b.global_position, "stone", 14 + 4 * k)
	var col := Lairs.color_of(l)
	m.fx.dust(mb.pos, 10)
	m.fx.burst(mb.pos + Vector3(0, 1.5, 0), col, 16 + 8 * k, 3.5 + k, 0.6, 6.0)
	m.sfx(CRACK_SFX[k], mb.pos, 2.0 + k, 0.9 - 0.05 * k)
	m.sfx("boom", mb.pos, -6.0 + 2.0 * k, 0.6)
	Shake.big(m, mb.pos, "lair_crack", null, k)
	var by := hunter_of(mb.last_hit_by)
	if by:
		lairs.loud(l, mb.pos, by, "The gate of %s cracks (%d of %d)" % [l["name"], k, STAGES])
		if by == m.player and m.hud:
			m.hud.toast("GATE CRACKED  ·  %d OF %d  ·  guards are coming" % [k, STAGES], col)
	var out: Vector2 = l["out"]
	lairs.call_guards(l, mb.pos + Vector3(out.x, 0, out.y) * 2.0, STAGE_GUARDS)


## The seal shudders under each hit; the label over the gate says how far it's broken.
func _show(l: Dictionary, mb: Mob) -> void:
	var slab: Node3D = mb.model.get_node_or_null("Slab") if mb.model else null
	if slab:
		slab.position.x = sin(m.time * 70.0) * 0.05 if mb.flash_t > 0.0 else 0.0
	var pct := int(done_k(mb) * 100.0)
	if pct == int(l.get("seal_pct", -1)):
		return
	l["seal_pct"] = pct
	var lbl: Label3D = l["nodes"]["label"]
	lbl.text = "%s\nSealed  ·  the gate %d%% broken" % [l["name"], pct]


## The seal gives way: a burst of rubble right across the gap, and the gate opens.
func broken(l: Dictionary, mb: Mob, credit: Hunter) -> void:
	var out: Vector2 = l["out"]
	var side := Vector3(-out.y, 0, out.x)
	if m.brk:
		for sx in [-1.0, 0.0, 1.0]:
			m.brk.show_break(mb.pos + side * sx + Vector3(0, 1.2, 0), "stone", 28)
	m.sfx("br_crumble", mb.pos, 6.0, 0.7)
	Shake.big(m, mb.pos, "lair_break")
	l["seal_stage"] = STAGES
	lairs.open(l, credit, "breach")


## The gate opened some other way (a dial, a seat, a test): the seal goes with it, quietly.
func clear(l: Dictionary) -> void:
	var mb = l.get("seal")
	if mb != null and is_instance_valid(mb) and not (mb as Mob).dead:
		(mb as Mob).dead = true
		(mb as Mob).visible = false


## For checks that cover the older ways in (--boss-check): the lair's gate goes back to a dial, its seal gone.
func as_dial(l: Dictionary) -> void:
	clear(l)
	l.erase("seal_at")
	l["entry"] = (l["entry"] as Array).map(func(e): return "dial" if e == "breach" else e)


## What the seal says to someone standing at it.
func prompt(l: Dictionary, h: Hunter) -> Dictionary:
	var mb := seal_of(l)
	if mb == null or h.flat_dist(mb) > PROMPT_R:
		return {}
	return {
		"kind": "lair",
		"what": "breach",
		"lair": l,
		"col": Lairs.color_of(l),
		"label": "Break the gate down  ·  %d%% done  ·  each crack calls guards" % int(done_k(mb) * 100.0)
	}


## Where a bot stands to batter a lair's seal.
static func stand(l: Dictionary) -> Vector3:
	var out: Vector2 = l["out"]
	return l["seal_at"] + Vector3(out.x, 0, out.y) * STAND
