class_name KeyCarry
extends RefCounted
## Monsters that carry a chest key: the mark (meta "ckey" plus a glint over the head), the key they
## drop when they die, and the two numbers the host adds to a monster's Net snapshot so every game
## shows the glint and a Shrubling's pose (Net 0.14.2).

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
## (a key that falls into the abyss would leave a chest nobody can open).
static func on_mob_dead(m: Match, mb: Mob) -> void:
	if not carries(mb):
		return
	mb.remove_meta("ckey")
	var at := mb.pos + Vector3(0, 0.6, 0)
	if m.world.is_void(mb.pos.x, mb.pos.z):
		var q := m.world.free_spot_near(mb.camp, [], 0.6, 0.4, 30.0)
		at = Vector3(q.x, m.world.ground_at(q.x, q.z) + 0.6, q.z)
	m.drop("ckey", at, 1, "", "", Vector3(randf_range(-1.2, 1.2), randf_range(4.5, 6.0), randf_range(-1.2, 1.2)))
	m.fx.burst(at, KeyModels.BRASS, 12, 3.5, 0.5)
	m.fx.word(at + Vector3(0, 0.6, 0), "KEY", KeyModels.BRASS, false)

# ------------------------------------------------------------------ Net: the monster snapshot extra
## Appended to a non-Blight monster's snapshot: [carries a key, the Shrubling's state index (-1 for others)].
static func mob_extra(mb: Mob) -> Array:
	return [1 if carries(mb) else 0, Shrubling.STATES.find((mb as Shrubling).ss) if mb is Shrubling else -1]

static func apply_mob(mb: Mob, it: Array) -> void:
	if int(it[17]) == 1:
		mark(mb)
	elif carries(mb):
		mb.remove_meta("ckey")
		var g := glint_of(mb)
		if g: g.queue_free()
	if mb is Shrubling and int(it[18]) >= 0 and int(it[18]) < Shrubling.STATES.size():
		(mb as Shrubling).ss = String(Shrubling.STATES[int(it[18])])
