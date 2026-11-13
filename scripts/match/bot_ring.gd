class_name BotRing
extends RefCounted
## Bot zone sense: the Blight's tide (Heart.tide_r, Heart.next_r) read by the bot brain (bot.gd).
##   - goals: a goal past the coming ring (the ring two closes ahead less the bot's difficulty margin,
##     Data.BOT_DIFF "ring") is swapped for standing ground on its line in toward the Heart, so a bot
##     outside walks in before the close and a bot inside doesn't wander back out. (One close ahead
##     was too late on small islands: when the last ring left one, the glide over to the Heart's
##     island took off from the outer side, already past the wall.)
##   - fights: a bot fights at the edge, but once the wall is within WALL_NEAR it drops the fight
##     and runs in (must_run).
##   - getting in: while it must run it dashes in where the ground ahead holds, and opens the glider
##     when falling in from a height (run_in). Island crossings use the usual glide routes.

const WALL_NEAR := 2.5      # m: the wall this close (or past us) and the fight is dropped to run in
const DASH_LOOK := 5.0      # m of ground ahead a dash in needs
const GLIDE_DROP := 2.5     # m: falling in from higher than this opens the glider
const STEP_IN := 2.0        # m: step of the search in toward the Heart for standing ground
const SKIP_IN := 6.0        # m further in past a spot the bot found no way to (bot.gd bans it)

## The coming ring's radius for this bot (two closes ahead, less its margin); INF with no tide.
static func safe_r(m: Match, h: Hunter) -> float:
	if m.heart == null or m.heart.site == Vector3.INF:
		return INF
	return Heart.next_r(m, 2) - float((h.ai.get("diff", {}) as Dictionary).get("ring", 4.0))

static func _from_site(m: Match, p: Vector3) -> Vector2:
	return Vector2(p.x - m.heart.site.x, p.z - m.heart.site.z)

## The wall is on us: drop the fight and run in.
static func must_run(m: Match, h: Hunter) -> bool:
	var tr := Heart.tide_r(m)
	return tr > 0.0 and _from_site(m, h.pos).length() > tr - WALL_NEAR

## `goal` when it lies inside the coming ring; else standing ground on its line in toward the Heart
## (past any spot bot.gd banned as having no way there). No goal (INF): the bot's own way in when it
## stands outside, else INF.
static func clamp_goal(m: Match, h: Hunter, goal: Vector3) -> Vector3:
	var sr := safe_r(m, h)
	if sr == INF:
		return goal      # no Heart site (or no tide): nothing to clamp to
	var v := _from_site(m, goal if goal != Vector3.INF else h.pos)
	if v.length() <= sr:
		return goal
	var dir := v.normalized()
	var bans: Dictionary = h.ai.get("banned", {})
	var r := maxf(sr, 0.0)
	while r > 0.0:
		var x := m.heart.site.x + dir.x * r
		var z := m.heart.site.z + dir.y * r
		if not m.world.is_void(x, z) and not m.world.is_block(x, z):
			var p := Vector3(x, m.world.ground_at(x, z), z)
			if float(bans.get(p, -1.0)) <= m.time:
				return p
			r -= SKIP_IN
		r -= STEP_IN
	return m.heart.site

## While it must run: dash along the way in when the ground ahead holds, glide when falling in.
static func run_in(m: Match, h: Hunter) -> void:
	if not must_run(m, h):
		return
	var a := h.ai
	var inp := h.inp
	var mv: Vector2 = inp["move"]
	if h.grounded and float(a["dash_cd"]) <= 0.0 and mv.length() > 0.5 and _ground_ahead(m, h, mv.normalized()):
		a["dash_cd"] = randf_range(1.2, 3.0) / (0.5 + float(a["skill"]))
		inp["dash"] = true
	elif not h.grounded and h.vel.y < 0.0 and h.pos.y - m.world.ground_at(h.pos.x, h.pos.z) > GLIDE_DROP \
			and (h.gliding or h.can_glide()):
		inp["glide"] = true

static func _ground_ahead(m: Match, h: Hunter, d: Vector2) -> bool:
	for k in [0.5, 1.0]:
		if m.world.is_void(h.pos.x + d.x * DASH_LOOK * k, h.pos.z + d.y * DASH_LOOK * k):
			return false
	return true
