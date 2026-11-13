class_name Prematch
extends RefCounted
## The pre-match lobby's rules (docs/decisions/0019-prematch-lobby.md): before an expedition everyone
## loads in, then each squad picks its Hunters in turn (TURN seconds each, no two on a squad alike),
## then the picks lock and the match loads. The screen is PrematchView; the loading screen shows the
## same squad (squad_of). Settings > lobby_enabled (an admin setting) skips all of it.

signal turn_done(i: int)      # squad[i] finished their pick (the view refreshes; your own goes out final)

const TURN := 10.0          # seconds each Hunter has on their pick turn
const GRACE := 3.0          # seconds past a teammate's turn before their pick is made for them (lost or gone)
const LOAD_WAIT := 60.0     # seconds the lobby waits for everyone to load before picking starts anyway
const LOCK_HOLD := 1.0      # seconds "picks locked" shows before the match loads
const CHAT_MAX := 140       # characters in one chat line
## Options that mark a match as something other than a real expedition: no lobby for those.
## "matchmade": a dedicated match server already runs the match when its "start" arrives (OnlineSession).
const NOT_EXPEDITION := [
	"tutorial", "training", "practice", "arena", "duel", "sandbox", "autoplay", "probe", "spectate", "demo_match",
	"matchmade",
]

var opts: Dictionary
var squad: Array                # your squad in pick order: [{name, peer, arch, you, bot, done}]
var turn := -1                  # who in squad is picking: -1 while loading, squad.size() once all picked
var turn_left := TURN
var loaded := {}                # online: peer id -> true, everyone in the roster (all squads)
var load_wait := 0.0
var locked := false
var pick := ""                  # your Hunter (an Arch id), "" until you pick or your turn runs out
var _hold := 0.0
var _launched := false

func _init(o: Dictionary) -> void:
	opts = o
	squad = pick_order(o)
	loaded[Net.me] = true

## A real expedition (offline or online), not training, the tutorial, the arena or a demo.
static func expedition(o: Dictionary) -> bool:
	return int(o.get("teams", 1)) > 1 and not NOT_EXPEDITION.any(func(k): return o.get(k, false))

## Whether this match opens in the lobby (an expedition, with the setting on).
static func wanted(o: Dictionary) -> bool:
	return bool(Settings.get_v("lobby_enabled")) and expedition(o)

## Offline duos and trios: deals your bot squadmates (name and Hunter) into opts["mates"] once, so the
## lobby, the loading screen and the match all show the same ones (Match.make_bot reads them). Every
## mate gets a Hunter nobody else on the squad has (you keep your saved one).
static func deal_mates(o: Dictionary) -> void:
	var n := int(o.get("squad", 1)) - 1
	if n <= 0 or o.has("net") or o.has("mates") or not expedition(o):
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	var taken: Array = [String(o.get("arch", Arch.of_save()))]
	var tags := Names.bot_pool([Save.d.get("name", "Hunter")])
	var mates: Array = []
	for i in n:
		var bot_name: String = tags.pop_back()
		var ak := free_arch(taken, r)
		taken.append(ak)
		mates.append({"name": bot_name, "arch": ak})
	o["mates"] = mates

## A random Hunter not in `taken` (any Hunter if every one is taken).
static func free_arch(taken: Array, r: RandomNumberGenerator, only_open := false) -> String:
	var ids := Arch.ids()
	var pool := ids.filter(func(a): return not taken.has(a) and (not only_open or ClassUnlock.is_open(a)))
	if pool.is_empty():
		pool = ids.filter(func(a): return not taken.has(a))
	if pool.is_empty():
		pool = ids
	return String(pool[r.randi_range(0, pool.size() - 1)])

## Your squad as [{name, peer, arch, you, bot}] (you first): online the roster entries on your team,
## else you and the dealt bot mates. `mine` is your Hunter (the lobby's pick, else your saved one).
static func squad_of(o: Dictionary, mine: String) -> Array:
	var me := String(Save.d.get("name", "Hunter"))
	var out: Array = [{"name": me, "peer": Net.me, "arch": mine, "you": true, "bot": false}]
	if o.has("net"):
		out.clear()
		var roster: Array = o["net"].get("roster", [])
		var team := -1
		for r in roster:
			if String(r["peer"]) == Net.me:
				team = int(r["team"])
		for r in roster:
			if int(r["team"]) != team:
				continue
			var you := String(r["peer"]) == Net.me
			var ak := mine if you else String(r.get("arch", ""))
			out.append({"name": String(r["name"]), "peer": String(r["peer"]), "arch": ak, "you": you, "bot": false})
		out.sort_custom(func(a, b): return bool(a["you"]) and not bool(b["you"]))
	else:
		for m in o.get("mates", []):
			out.append({"name": String(m["name"]), "peer": "", "arch": String(m["arch"]), "you": false, "bot": true})
	return out

## Your squad in pick order, nobody picked yet (a bot keeps its dealt Hunter in "deal"). Offline you
## pick first; online the order is shuffled by the match seed, the same on every client.
static func pick_order(o: Dictionary) -> Array:
	var out := squad_of(o, "")
	for m in out:
		m["deal"] = m["arch"]
		m["arch"] = ""
		m["done"] = false
	if o.has("net"):
		var sd := int(o["net"].get("seed", 0))
		out.sort_custom(func(a, b): return hash("%d|%s" % [sd, a["peer"]]) < hash("%d|%s" % [sd, b["peer"]]))
	return out

# ------------------------------------------------------------------ loading and turns
## Everyone who has to load before picking starts: the whole roster online (all squads), only you offline.
func loaded_count() -> Vector2i:
	if not opts.has("net"):
		return Vector2i(1, 1)
	var roster: Array = opts["net"].get("roster", [])
	var n := 0
	for r in roster:
		if loaded.has(String(r["peer"])) or _gone(String(r["peer"])):
			n += 1
	return Vector2i(n, roster.size())

## A player finished loading. True the first time we hear from them (the view answers with its own,
## so someone who loaded later hears about everyone who loaded before).
func mark_loaded(peer: String) -> bool:
	if loaded.has(peer):
		return false
	loaded[peer] = true
	return true

## Runs loading, the turns and the lock. True once, the frame the lobby is over and the match should load.
func tick(dt: float) -> bool:
	if _launched:
		return false
	if locked:
		_hold += dt
		_launched = _hold >= LOCK_HOLD
		return _launched
	if turn < 0:
		load_wait += dt
		var lc := loaded_count()
		if lc.x >= lc.y or load_wait >= LOAD_WAIT:
			turn = 0
			_start_turn()
		return false
	turn_left -= dt
	var m: Dictionary = squad[turn]
	if m["you"] and turn_left <= 0.0:
		_finish(pick if pick != "" else free_arch(taken(), _rng(turn), true))
	elif not m["you"] and (turn_left <= -GRACE or _gone(String(m["peer"]))):
		_finish(free_arch(taken(), _rng(turn)))
	return false

## Whose turn it is: squad[turn], or {} while loading or once everyone picked.
func picker() -> Dictionary:
	return squad[turn] if turn >= 0 and turn < squad.size() else {}

func my_turn() -> bool:
	return bool(picker().get("you", false))

## The Hunters your squad has locked in.
func taken() -> Array:
	return squad.filter(func(m): return m["done"]).map(func(m): return m["arch"])

## The squadmate who locked in a Hunter, "" if nobody did.
func taken_by(ak: String) -> String:
	for m in squad:
		if m["done"] and m["arch"] == ak:
			return String(m["name"])
	return ""

## Picks a Hunter on your turn: false off your turn, once locked, for a Hunter that isn't open to you
## or one a squadmate already has. It is final when your turn runs out.
func choose(ak: String) -> bool:
	if not my_turn() or not ClassUnlock.is_open(ak) or taken().has(ak):
		return false
	pick = ak
	squad[turn]["arch"] = ak
	return true

## A squadmate's pick from the lobby channel, only on their turn and only an untaken Hunter; `final`
## ends their turn. True when it changed something.
func remote_pick(peer: String, ak: String, final: bool) -> bool:
	var m := picker()
	if m.is_empty() or m["you"] or String(m["peer"]) != peer or not Arch.exists(ak) or taken().has(ak):
		return false
	m["arch"] = ak
	if final:
		_finish(ak)
	return true

func _start_turn() -> void:
	if turn < squad.size() and squad[turn]["bot"]:
		# bots pick the moment their turn comes: their dealt Hunter, unless a squadmate took it
		var deal := String(squad[turn]["deal"])
		_finish(deal if Arch.exists(deal) and not taken().has(deal) else free_arch(taken(), _rng(turn)))
		return
	if turn >= squad.size():
		locked = true
		return
	turn_left = TURN
	squad[turn]["arch"] = ""

func _finish(ak: String) -> void:
	var i := turn
	squad[i]["arch"] = ak
	squad[i]["done"] = true
	if squad[i]["you"]:
		pick = ak
	turn += 1
	turn_done.emit(i)
	_start_turn()

## The random stream for squad[i]'s auto-pick: from the match seed, so every client deals the same one.
func _rng(i: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%d|%s" % [int(opts.get("seed", 0)), i, squad[i]["name"]])
	return r

func _gone(peer: String) -> bool:
	return peer != Net.me and not Net.peers.has(peer)

## Saves the locked pick and returns the options the match starts with: your Hunter, online every
## squadmate's pick in the roster, offline the bot mates' turn picks.
func launch_opts() -> Dictionary:
	HeroGrid.save_pick(pick)
	var o := opts.duplicate(true)
	o["arch"] = pick
	var by_peer := {}
	for m in squad:
		by_peer[m["peer"]] = m["arch"]
	for r in o.get("net", {}).get("roster", []):
		var ak := String(by_peer.get(String(r["peer"]), ""))
		if Arch.exists(ak):
			r["arch"] = ak
			r["cls"] = Arch.weight(ak)
			r["weapon"] = Arch.signature(ak)
	var bots := squad.filter(func(m): return m["bot"])
	for i in mini(bots.size(), o.get("mates", []).size()):
		o["mates"][i]["arch"] = bots[i]["arch"]
	return o

## A chat line made safe to show and send: trimmed, one line, at most CHAT_MAX characters.
static func clean_chat(s: String) -> String:
	return s.replace("\n", " ").strip_edges().left(CHAT_MAX)
