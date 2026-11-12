class_name BossNet
extends RefCounted
## What a lair boss shows on its body but the monster snapshot does not carry: the attack under way (and when it
## began), asleep or awake, the phase, enraged. The host sends one "bat" event when any of them changes, never
## per frame (about 35 bytes a change, an attack every second or two). A remote game builds a real Boss (make),
## applies the event (net_in) and reads the wind-up's progress off the synced start time (advance), so
## BossAnim poses it as it does on the host. Net.VERSION 0.24.6.

const ATKS := ["", "phase", "slam", "boulders", "fissure", "dash", "storm", "static", "spit", "lob", "brood", "burrow"]
const F_DORMANT := 1
const F_ENRAGED := 2

## The remote copy of a lair boss: its lair is the one it sleeps in.
static func make(m: Match, nid: String, kind: String, at: Vector3) -> Boss:
	var b := Boss.new()
	b.init_boss(m, nid, kind, at, 1.0, m.lairs.lair_of(at, 1.0))
	return b

## Host, once per boss step: send the state if it changed since the last send.
static func watch(b: Boss) -> void:
	if not b.m.net_on:
		return
	var flags := int(b.dormant) * F_DORMANT + int(b.enraged) * F_ENRAGED
	var key := [b.atk, snappedf(b.atk_began, 0.01), b.phase, flags, snappedf(float(b.md["windup"]), 0.01)]
	if b.has_meta("bat") and b.get_meta("bat") == key:
		return
	b.set_meta("bat", key)
	b.m.net_event(["bat", b.nid, ATKS.find(b.atk), key[1], b.phase, flags, key[4]])

## A remote game: take the host's event.
static func net_in(m: Match, x: Array) -> void:
	var b := m.ents_by_id.get(String(x[1]), null) as Boss
	if b == null:
		return
	var woke := (int(x[5]) & F_DORMANT) == 0 and b.dormant
	b.atk = String(ATKS[int(x[2])]) if int(x[2]) >= 0 and int(x[2]) < ATKS.size() else ""
	b.atk_began = float(x[3])
	b.phase = int(x[4])
	b.dormant = (int(x[5]) & F_DORMANT) != 0
	b.enraged = (int(x[5]) & F_ENRAGED) != 0
	b.md["windup"] = float(x[6])      # (each attack sets its own wind-up seconds; BossAnim.hit_t reads it)
	if woke or b.dormant:
		b.awake_t = 0.0

## A remote game, every frame: the clocks the host's step would have run.
static func advance(b: Boss, delta: float) -> void:
	b.awake_t += delta
	if b.atk != "":
		b.atk_t = maxf(0.0, b.m.time - b.atk_began)
