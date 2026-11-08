class_name Prematch
extends RefCounted
## The pre-match lobby's rules (docs/decisions/0019-prematch-lobby.md): before an expedition you get
## DURATION seconds to pick your Hunter, meet your squad and plan; at 0 the picks lock and the match
## loads. The screen is PrematchView; the loading screen shows the same squad (squad_of).
## Settings > lobby_enabled (an admin setting) skips all of it for the plain loading screen.

const DURATION := 90.0      # seconds the lobby runs
const LOCK_HOLD := 1.0      # seconds "picks locked" shows before the match loads
const CHAT_MAX := 140       # characters in one chat line
## Options that mark a match as something other than a real expedition: no lobby for those.
const NOT_EXPEDITION := [
	"tutorial", "training", "practice", "arena", "duel", "sandbox", "autoplay", "probe", "spectate", "demo_match",
]

var opts: Dictionary
var left := DURATION
var locked := false
var pick := ""                  # your Hunter (an Arch id)
var peer_picks := {}            # online: peer id -> the Hunter they picked
var _hold := 0.0
var _launched := false

func _init(o: Dictionary) -> void:
	opts = o
	pick = Arch.of_save()

## A real expedition (offline or online), not training, the tutorial, the arena or a demo.
static func expedition(o: Dictionary) -> bool:
	return int(o.get("teams", 1)) > 1 and not NOT_EXPEDITION.any(func(k): return o.get(k, false))

## Whether this match opens in the lobby (an expedition, with the setting on).
static func wanted(o: Dictionary) -> bool:
	return bool(Settings.get_v("lobby_enabled")) and expedition(o)

## Offline duos and trios: deals your bot squadmates (name and Hunter) into opts["mates"] once, so the
## lobby, the loading screen and the match all show the same ones (Match.make_bot reads them).
static func deal_mates(o: Dictionary) -> void:
	var n := int(o.get("squad", 1)) - 1
	if n <= 0 or o.has("net") or o.has("mates") or not expedition(o):
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	var ids := Arch.ids()
	var mates: Array = []
	for i in n:
		var bot_name: String = Names.BOT[r.randi_range(0, Names.BOT.size() - 1)]
		mates.append({"name": bot_name, "arch": String(ids[r.randi_range(0, ids.size() - 1)])})
	o["mates"] = mates

## Your squad as [{name, arch, you}] (you first): online the roster entries on your team, else you and
## the dealt bot mates. `mine` is your Hunter (the lobby's pick, else your saved one).
static func squad_of(o: Dictionary, mine: String, picks := {}) -> Array:
	var out: Array = [{"name": String(Save.d.get("name", "Hunter")), "arch": mine, "you": true}]
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
			var peer := String(r["peer"])
			var ak := mine if you else String(picks.get(peer, r.get("arch", "")))
			out.append({"name": String(r["name"]), "peer": peer, "arch": ak, "you": you})
		out.sort_custom(func(a, b): return bool(a["you"]) and not bool(b["you"]))
	else:
		for m in o.get("mates", []):
			out.append({"name": String(m["name"]), "arch": String(m["arch"]), "you": false})
	return out

## Counts the lobby down. True once, the frame the lobby is over and the match should load.
func tick(dt: float) -> bool:
	if _launched:
		return false
	if not locked:
		left = maxf(0.0, left - dt)
		locked = left <= 0.0
		return false
	_hold += dt
	_launched = _hold >= LOCK_HOLD
	return _launched

## Picks a Hunter. False once picks are locked, or for a Hunter that isn't open to you.
func choose(ak: String) -> bool:
	if locked or not ClassUnlock.is_open(ak):
		return false
	pick = ak
	return true

## Saves the locked pick and returns the options the match starts with: your Hunter, and online every
## teammate's pick in the roster.
func launch_opts() -> Dictionary:
	HeroGrid.save_pick(pick)
	var o := opts.duplicate(true)
	o["arch"] = pick
	for r in o.get("net", {}).get("roster", []):
		var ak := pick if String(r["peer"]) == Net.me else String(peer_picks.get(String(r["peer"]), ""))
		if Arch.exists(ak):
			r["arch"] = ak
			r["cls"] = Arch.weight(ak)
			r["weapon"] = Arch.signature(ak)
	return o

## A chat line made safe to show and send: trimmed, one line, at most CHAT_MAX characters.
static func clean_chat(s: String) -> String:
	return s.replace("\n", " ").strip_edges().left(CHAT_MAX)
