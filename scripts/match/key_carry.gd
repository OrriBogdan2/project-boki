class_name KeyCarry
extends RefCounted
## Monsters that carry a chest key: the mark (meta "ckey" plus a glint over the head), the key they
## drop when they die, and the two numbers the host adds to a monster's Net snapshot so every game
## shows the glint and a Shrubling's pose (Net 0.15.3).

static func carries(mb: Mob) -> bool:
	return mb != null and mb.has_meta("ckey")

## Makes `mb` a key carrier and hangs the glint over it (hidden for a disguised Shrubling).
static func mark(mb: Mob) -> void:
	if carries(mb):
		return
	mb.set_meta("ckey", true)
	var g := KeyGlint.new()
	g.set_height(1.15 + mb.r * 1.3 + float(KeyRun.rules()["keys"]["glint_h"]) - 1.9)
	mb.add_child(g)

static func glint_of(mb: Mob) -> KeyGlint:
	return mb.get_node_or_null("KeyGlint") as KeyGlint

## A carrier died: its key drops, even from a Puffbomb that blew itself up or over the edge
## (a key that falls into the abyss would leave a chest nobody can open). A bonus key may follow.
static func on_mob_dead(m: Match, mb: Mob) -> void:
	KeyBonus.on_mob_dead(m, mb)
	if not carries(mb):
		return
	mb.remove_meta("ckey")
	drop_keys(m, drop_spot(m, mb), 1)

## Where a dead monster's key lands: where it fell, or back by its camp if it fell into the void.
static func drop_spot(m: Match, mb: Mob) -> Vector3:
	if not m.world.is_void(mb.pos.x, mb.pos.z):
		return mb.pos + Vector3(0, 0.6, 0)
	var q := m.world.free_spot_near(mb.camp, [], 0.6, 0.4, 30.0)
	return Vector3(q.x, m.world.ground_at(q.x, q.z) + 0.6, q.z)

## Pops `n` chest keys out at `at`, with the glint burst. They lie on the ground for anyone (bots too).
static func drop_keys(m: Match, at: Vector3, n: int) -> void:
	if n <= 0:
		return
	for i in n:
		var pop := Vector3(randf_range(-1.2, 1.2), randf_range(4.5, 6.0), randf_range(-1.2, 1.2))
		m.drop("ckey", at, 1, "", "", pop)
	m.fx.burst(at, KeyModels.BRASS, 12, 3.5, 0.5)
	m.fx.word(at + Vector3(0, 0.6, 0), "KEY" if n == 1 else "%d KEYS" % n, KeyModels.BRASS, false)

# ------------------------------------------------------------------ Net: the monster snapshot extra
## Appended to a non-Blight monster's snapshot: [carries a key, the Shrubling's state index (-1 for others)].
static func mob_extra(mb: Mob) -> Array:
	var shrub_state := -1
	if mb is Shrubling:
		shrub_state = Shrubling.STATES.find((mb as Shrubling).ss)
	return [1 if carries(mb) else 0, shrub_state]

static func apply_mob(mb: Mob, it: Array) -> void:
	if int(it[17]) == 1:
		mark(mb)
	elif carries(mb):
		mb.remove_meta("ckey")
		var g := glint_of(mb)
		if g: g.queue_free()
	if mb is Shrubling and int(it[18]) >= 0 and int(it[18]) < Shrubling.STATES.size():
		(mb as Shrubling).ss = String(Shrubling.STATES[int(it[18])])
