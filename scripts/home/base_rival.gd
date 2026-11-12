class_name BaseRival
extends RefCounted
## Rivals from the garden games (briefs/design/GARDEN.md sections 4 and 5), on top of base life's bonds: no
## second relationship system. A Boki that loses to the same Boki twice (any game the Games board lists) marks
## it a rival. The pair's bond drops to rules.bond_mark, so BaseLife's rival stares apply, and rec["grudge"] =
## {uid: {lost, rival, good, game}} keeps what a bond cannot: games lost in a row, whether the game made the
## rivalry, shared good days, the game last lost. Rivals nap and pick toys away from each other, glare when
## they pass, and the loser sometimes walks to the Games board and waits (BaseLife S.ASK): a rematch ask the
## player accepts with the interact key at the board. Winning the rematch, or three shared good days (BaseLife's
## day wrap), settles it. One journal line each way. Tuning: content/rules/base_rival.json.

const ASK_SAY := 6.0      # s between a waiting loser's "?" bubbles

static func rules() -> Dictionary:
	return Content.rules("base_rival")

static func _slot(rec: Dictionary, other: Dictionary) -> Dictionary:
	if not rec.has("grudge"):
		rec["grudge"] = {}
	var uid := String(other["uid"])
	if not rec["grudge"].has(uid):
		rec["grudge"][uid] = {"lost": 0, "rival": false, "good": 0, "game": ""}
	return rec["grudge"][uid]

## Distance on the ground between two points.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func is_rival(a: Dictionary, b: Dictionary) -> bool:
	return BaseLife.bond(a, b) <= float(Content.rules("base_life")["rival_at"])

## A finished game (each game calls it with its winner and loser): the loser's tally grows, the winner's
## clears. A second loss to the same winner marks a rivalry; a win by the one that marked it, over its
## rival, settles it.
static func result(game: String, win: Dictionary, lose: Dictionary) -> void:
	var mine := _slot(lose, win)
	var theirs := _slot(win, lose)
	if bool(theirs["rival"]) and int(theirs["lost"]) > 0:
		_settle(win, lose, "settled things with %s" % lose["name"])
		return
	mine["lost"] = int(mine["lost"]) + 1
	mine["game"] = game
	theirs["lost"] = 0
	if not bool(mine["rival"]) and int(mine["lost"]) >= int(rules()["lose_to_mark"]):
		_mark(lose, win, mine, theirs)

static func _mark(lose: Dictionary, win: Dictionary, mine: Dictionary, theirs: Dictionary) -> void:
	for e in [mine, theirs]:
		e["rival"] = true
		e["good"] = 0
	var gap := float(rules()["bond_mark"]) - BaseLife.bond(lose, win)
	if gap < 0.0:
		BaseLife.add_bond(lose, win, gap)
	CareJournal.note(lose, "marked %s a rival" % win["name"])

static func _settle(marker: Dictionary, rival: Dictionary, words: String) -> void:
	for e in [_slot(marker, rival), _slot(rival, marker)]:
		e["rival"] = false
		e["lost"] = 0
		e["good"] = 0
	if is_rival(marker, rival):
		BaseLife.add_bond(marker, rival, float(rules()["bond_end"]) - BaseLife.bond(marker, rival))
	CareJournal.note(marker, words)

## One in-game day (BaseLife.step, with the trait drift): a day both rivals are in good spirits counts for the pair.
static func day(recs: Array) -> void:
	var R := rules()
	for i in recs.size():
		for j in range(i + 1, recs.size()):
			var e: Dictionary = recs[i].get("grudge", {}).get(String(recs[j]["uid"]), {})
			if not bool(e.get("rival", false)):
				continue
			if Care.need(recs[i], "joy") < float(R["good_joy"]) or Care.need(recs[j], "joy") < float(R["good_joy"]):
				continue
			var theirs := _slot(recs[j], recs[i])
			e["good"] = int(e["good"]) + 1
			theirs["good"] = int(e["good"])
			if int(e["good"]) >= int(R["good_days"]):
				_settle(recs[i], recs[j], "got over it with %s" % recs[j]["name"])

## Is another Boki's rival at or by `at` (its toy, its nap spot)? Used to keep rivals apart.
static func rival_near(h, k: Dictionary, at: Vector3) -> bool:
	var gap := float(rules()["gap"])
	for o in h.kins:
		if o != k and is_rival(k["rec"], o["rec"]) and flat(o["pos"], at) < gap:
			return true
	return false

## A nap spot away from every rival here, or INF-vector (Vector3.INF) when it has none near to avoid.
static func nap_spot(h, k: Dictionary) -> Vector3:
	if not rival_near(h, k, k["pos"]):
		return Vector3.INF
	var here: int = maxi(h.world.island_of(k["pos"].x, k["pos"].z), 0)
	for _i in 8:
		var at: Vector3 = h.world.random_ground(here)
		if not rival_near(h, k, at):
			return at
	return Vector3.INF

## Rivals that pass close show a short glare bubble (per Boki, on a cooldown).
static func glare(h, k: Dictionary, dt: float) -> void:
	k["glare_t"] = float(k.get("glare_t", 0.0)) - dt
	if float(k["glare_t"]) > 0.0:
		return
	var R := rules()
	for o in h.kins:
		if o != k and flat(o["pos"], k["pos"]) < float(R["glare_at"]) and is_rival(k["rec"], o["rec"]):
			h._emote(k, "#")
			k["glare_t"] = float(R["glare_cd"])
			return

# ------------------------------------------------------------------ the rematch ask
## The kin entry the loser `k` wants a rematch with, or {}: it holds a grudge, the rival is out and rested, the
## Games board is up and nothing is running.
static func foe(h, k: Dictionary) -> Dictionary:
	var board: BaseBoard = h.hboard
	if board == null or not is_instance_valid(board.board) or board.games().any(func(g): return g[2].running()):
		return {}
	var rested := float(BaseRace.rules()["min_energy"])
	if Care.need(k["rec"], "energy") < rested or Time.get_ticks_msec() < int(k.get("ask_after", 0)):
		return {}
	for o in h.kins:
		var e: Dictionary = k["rec"].get("grudge", {}).get(String(o["rec"]["uid"]), {})
		if bool(e.get("rival", false)) and int(e["lost"]) > 0 and not BaseLife._taken(o) \
				and Care.need(o["rec"], "energy") >= rested and board.has_game(String(e["game"])):
			return o
	return {}

## A roaming loser sometimes goes to ask. True when it started (BaseLife.choose).
static func ask(life: BaseLife, k: Dictionary) -> bool:
	var other := foe(life.h, k)
	if other.is_empty() or randf() > float(rules()["ask_chance"]):
		return false
	var e: Dictionary = k["rec"]["grudge"][String(other["rec"]["uid"])]
	if not life.machine(k).go(BaseLife.S.ASK, "rematch"):
		return false
	k["life_ask"] = {"foe": other, "game": String(e["game"])}
	k["ask_after"] = Time.get_ticks_msec() + int(float(rules()["ask_cd"]) * 1000.0)
	return true

## Walks to the board and waits there; gives up after ask_secs, or when the rival or a game is taken.
static func ask_tick(life: BaseLife, k: Dictionary, m: Fsm, dt: float) -> void:
	var h = life.h
	var board: Node3D = h.hboard.board
	if m.since >= float(rules()["ask_secs"]) or not is_instance_valid(board) or BaseLife._taken(k["life_ask"]["foe"]):
		m.go(BaseLife.S.ROAM, "gave up")
		return
	if flat(k["pos"], board.position) > BaseBoard.REACH * 0.7:
		k["goal"] = h.world.free_spot_near(board.position + Vector3(0, 0, 1.0), [], 0.6)
		return
	k["goal"] = k["pos"]
	(k["node"] as Node3D).rotation.y = PI
	k["ask_say"] = float(k.get("ask_say", 0.0)) - dt
	if float(k["ask_say"]) <= 0.0:
		h._emote(k, "?")
		k["ask_say"] = ASK_SAY

## The Boki waiting at the board right now, or {}.
static func waiting(h) -> Dictionary:
	var at: Vector3 = h.hboard.board.position
	for k in h.kins:
		if k.has("life_ask") and k.has("life") and (k["life"] as Fsm).is_in(BaseLife.S.ASK) \
				and flat(k["pos"], at) <= BaseBoard.REACH * 1.2:
			return k
	return {}

## The player accepts: the pair is set for the game it lost (BaseRace.entrants), and the Games board starts it.
static func accept(h, k: Dictionary) -> void:
	var ask: Dictionary = k["life_ask"]
	h.hrace.pair_force = [k, ask["foe"]]
	(k["life"] as Fsm).go(BaseLife.S.ROAM, "accepted")
	h.hboard.start_game(String(ask["game"]))
