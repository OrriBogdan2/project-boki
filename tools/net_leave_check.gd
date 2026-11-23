extends RefCounted
## --net-leave-check: a player who drops off the relay mid-match, or never joined it, is out on
## every other game (docs/decisions/0061). One headless game is the host of a 2x2 online match; the
## peer list the relay sends is fed in by hand, no second process needed.
##  1. A roster player missing from the peer list when the match starts (they never got there) is
##     out at once, not left standing at spawn where nothing can hit them.
##  2. An enemy carrying the Heartspark drops off the relay: their body is out, their Boki gone, and
##     the host drops the Heartspark where they stood, so the rest of the lobby can still win.
##  3. Hunters whose players are still connected stay in.
## Lines: NETLEAVE ok|FAIL <what>.

const DT := 1.0 / 60.0
const ME := "1"

var main: Node
var bad := 0
var n := 0

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("NETLEAVE %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Net.me = ME
	Net.mode = "server"
	_peers(["2", "3"])        # "4" is on the roster but never reached the relay
	var roster := []
	for p in [[ME, 0], ["2", 0], ["3", 1], ["4", 1]]:
		roster.append({"peer": p[0], "team": p[1], "name": "Hunter" + p[0], "cls": "medium", "weapon": "", "kin": {}})
	var m := Match.new()
	main.add_child(m)
	var nd := {"mid": "nl", "seed": 4242, "host": ME, "teams": 2, "squad": 2, "tier": 0, "roster": roster}
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": "medium",
		"heart": true, "net": nd})
	m.set_process(false)
	m.step(DT)
	var p2: Hunter = m.ents_by_id.get("P2", null)
	var p3: Hunter = m.ents_by_id.get("P3", null)
	var p4: Hunter = m.ents_by_id.get("P4", null)
	ok(p2 != null and p3 != null and p4 != null, "every roster player has a body")
	if p2 == null or p3 == null or p4 == null:
		return _finish()
	ok(p4.out and p4.gone, "a roster player who never reached the relay is out", "out=%s" % p4.out)
	ok(not p3.out and not p2.out, "connected players stay in")
	ok(m.heart != null, "the Heart runs in this match")
	if m.heart:
		m.heart.carrier = p3
	_peers(["2"])
	m.step(DT)
	ok(p3.out and p3.gone, "a player who drops off the relay is out", "out=%s gone=%s" % [p3.out, p3.gone])
	ok(p3.kin == null or p3.kin.dead, "their Boki goes with them")
	ok(m.heart == null or m.heart.carrier == null, "the host drops the Heartspark they carried")
	ok(not p2.out, "the player still connected stays in")
	ok(not m.player.out, "this game's own hunter is untouched")
	_finish()

func _peers(ids: Array) -> void:
	var arr := []
	for id in ids:
		arr.append({"id": id, "p": {"name": "Hunter" + id}})
	Net._on_js_peers([JSON.stringify({"me": ME, "peers": arr})])

func _finish() -> void:
	print("NETLEAVE DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)
