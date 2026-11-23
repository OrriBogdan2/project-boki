class_name BossNet
extends RefCounted
## What a lair boss shows on its body but the monster snapshot does not carry: the attack under way (and how long
## ago it began), asleep or awake, the phase, enraged. The host sends one "bat" event when any of them changes, never
## per frame (about 35 bytes a change, an attack every second or two). A remote game builds a real Boss (make),
## applies the event (net_in) and counts the wind-up's progress from the synced age on its own frame time (advance;
## the match clocks of two games drift up to 0.5 s apart, so a start time would show the strike late), so
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
	b.m.net_event(["bat", b.nid, ATKS.find(b.atk), snappedf(b.atk_t, 0.01), b.phase, flags, key[4]])

## A remote game: take the host's event.
static func net_in(m: Match, x: Array) -> void:
	var b := m.ents_by_id.get(String(x[1]), null) as Boss
	if b == null:
		return
	var woke := (int(x[5]) & F_DORMANT) == 0 and b.dormant
	b.atk = String(ATKS[int(x[2])]) if int(x[2]) >= 0 and int(x[2]) < ATKS.size() else ""
	b.atk_t = float(x[3])      # (how far into the attack the host was when it sent)
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
		b.atk_t += delta
