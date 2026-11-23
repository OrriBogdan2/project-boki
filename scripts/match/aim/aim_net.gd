class_name AimNet
extends RefCounted
## The Net side of AimKit (docs/decisions/0061-telegraph-net.md). Remote hunters are puppets: their kits
## don't run on this game, so an `all` telegraph (a slam disc, a landing zone, a lane wind-up) used to
## show on its caster's screen only. Now every `all` entry of a hunter this game runs (its player, the
## host's bots) goes out as one event through Net, and the other games put the same resolved entry under
## their copy of that hunter, so AimShapes draws what the caster's game draws (tinted hostile for a foe).
##   ["tele", nid, id, entry]   show or refresh (entry: AimKit's resolved dict, Vector2 as [x, y], Color as "#hex")
##   ["tele", nid, id]          it ended on the caster's game: drop it
## Kits refresh a telegraph every step; it goes out at most every SEND_GAP and lives LAG longer on the
## receiving game, so the gap between two sends never blinks it.

const SEND_GAP := 0.1  # s between two sends of a refreshed telegraph (one Net flush, Net.tick)
const LAG := 0.25  # s a received telegraph outlives its own keep: a send gap plus the network's jitter
const LOCAL := ["h", "t"]  # entry keys that stay on this game: the hunter node, the last refresh time
const KINDS := ["lane", "dotted", "vee", "cone", "circle", "arc_wall", "swap", "line", "span", "star"]

## Tests read what would go out without a connection (--aimkit-check).
static var capture := false
static var sent_log: Array = []

var sent := {}  # AimDraw key -> [hunter, id, match time of the last send, a newer state waits]


## A local hunter's `all` entry was put: send it now if it is new or the last send is SEND_GAP old, else
## mark it pending, so sweep sends its latest state once the gap is up (a one-off never refreshes).
func out(m: Node, h: Hunter, id: String, e: Dictionary) -> void:
	if h.remote or not (capture or m.net_on):
		return
	var k := AimDraw.key(h, id)
	var now := float(m.time)
	if sent.has(k) and now - float(sent[k][2]) < SEND_GAP:
		sent[k][3] = true
		return
	sent[k] = [h, id, now, false]
	_tx(m, ["tele", h.nid, id, encode(e)])


## After AimDraw prunes: the pending ones whose gap is up go out; every sent telegraph no longer up here is
## dropped on the other games too.
func sweep(m: Node, entries: Dictionary) -> void:
	if sent.is_empty():
		return
	var now := float(m.time)
	for k in sent.keys():
		var s: Array = sent[k]
		if not entries.has(k):
			sent.erase(k)
			if is_instance_valid(s[0]):
				_tx(m, ["tele", (s[0] as Hunter).nid, s[1]])
		elif s[3] and now - float(s[2]) >= SEND_GAP:
			s[2] = now
			s[3] = false
			_tx(m, ["tele", (s[0] as Hunter).nid, s[1], encode(entries[k])])


static func net_in(m: Node, x: Array) -> void:
	if x.size() < 3:
		return
	var h := m.ents_by_id.get(String(x[1]), null) as Hunter
	if h == null or not h.remote:
		return
	var d := AimKit.layer(m)
	if x.size() < 4:
		d.drop(h, String(x[2]))
		return
	if typeof(x[3]) != TYPE_DICTIONARY or not String(x[3].get("kind", "")) in KINDS:
		return
	var e := decode(x[3])
	e["keep"] = float(e.get("keep", AimDraw.KEEP)) + LAG
	d.put(h, String(x[2]), e)


static func encode(e: Dictionary) -> Dictionary:
	var o := {}
	for k in e:
		if k in LOCAL:
			continue
		var v = e[k]
		match typeof(v):
			TYPE_VECTOR2:
				o[k] = [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]
			TYPE_COLOR:
				o[k] = "#" + (v as Color).to_html(true)
			TYPE_FLOAT:
				o[k] = snappedf(v, 0.001)
			_:
				o[k] = v
	return o


static func decode(o: Dictionary) -> Dictionary:
	var e := {}
	for k in o:
		var v = o[k]
		if v is Array and v.size() == 2:
			e[k] = Vector2(float(v[0]), float(v[1]))
		elif v is String and v.begins_with("#"):
			e[k] = Color.html(v)
		else:
			e[k] = v
	return e


static func _tx(m: Node, e: Array) -> void:
	if capture:
		sent_log.append(e)
	if m.net_on:
		m.net_event(e)
