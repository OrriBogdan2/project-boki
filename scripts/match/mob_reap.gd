class_name MobReap
extends RefCounted
## Frees a dead camp monster once its death fx has played out (docs/BUGHUNT_1111.md item 7), so `mobs`
## and the scene stay flat in a long Training Grounds or rolling session. The one place a mob leaves
## `mobs` and `ents_by_id`. Lair bosses, the Blight and shrublings stay until the match ends (lairs and
## nests hold on to them), and so does everything online (snapshots address mobs by id).

const GRACE_S := 2.0  # s after the dissolve: shots, drops and bot thinking that still name the body let go


## Every sim step, after the monsters ticked.
static func tick(m: Match) -> void:
	if m.net_on:
		return
	var gone: Array = []
	for mb in m.mobs:
		if not mb.dead or mb is Boss or mb is Blight or mb is Shrubling:
			continue
		if not mb.has_meta("reap_at"):
			var starts := maxf(float(mb.get_meta("dis_at", m.time)), m.time)
			mb.set_meta("reap_at", starts + MobDissolve.duration(mb.r) + GRACE_S)
		elif m.time >= float(mb.get_meta("reap_at")):
			gone.append(mb)
	for mb in gone:
		_free(m, mb)


static func _free(m: Match, mb: Mob) -> void:
	m.mobs.erase(mb)
	m.ents_by_id.erase(mb.nid)
	for h in m.hunters:
		if h.last_hit_by == mb:
			h.last_hit_by = null
		if h.burn_by == mb:
			h.burn_by = null
		for key in ["tgt", "seen"]:
			if h.ai.get(key) == mb:
				h.ai[key] = null
		if (h.ai.get("ignore", {}) as Dictionary).get("e") == mb:
			h.ai.erase("ignore")
	for k in m.kins:
		if k.last_hit_by == mb:
			k.last_hit_by = null
		if k.burn_by == mb:
			k.burn_by = null
		if k.target == mb:
			k.target = null
		if k.strike_at == mb:
			k.strike_at = null
		if k.chase_target == mb:
			k.chase_target = null
		if k.angry_at == mb:
			k.angry_at = null
	mb.queue_free()
