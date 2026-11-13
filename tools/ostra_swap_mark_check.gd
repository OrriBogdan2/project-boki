extends "res://tools/hero_pair_check.gd"
## Motley's Trade landing sigil, for --ostra-combo-check (docs/heroes/ostra.md; KIT_PARITY Ostra dash row). The
## 1.8 s lob swaps every unit it lands on, so the sigil is the only cue a foe has to step out: it is there at launch,
## fills from 0 to 1 without jumps over the flight, sits on the landing point, and a rival's game (the remote copy,
## fed the Net "zone" events) draws the same sigil filling, and drops it when the Trade is cut short.

const JUMP := 0.05             # most the fill may rise in one 1/60 s step (a 1.8 s flight rises about 0.009)
const ON_SPOT := 0.3           # m: the sigil's centre from the landing point

## Every assertion; returns when done (the caller prints the totals).
func swap_mark(main_node: Node) -> void:
	main = main_node
	var r := setup("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	aim_at(P, r[2].pos)
	HeroZones.capture = true
	HeroZones.sent.clear()
	P.ak.on_dash(false)
	m.step(DT)
	var held: Dictionary = KitLooks.of(m).held.get("os_sigil_to", {})
	ok("swap mark: the landing sigil is there at launch", not held.is_empty() and not K.swap.is_empty())
	if held.is_empty():
		HeroZones.capture = false
		return
	var land: Vector3 = K.swap["land"]
	var flight := float(K.swap["T"])
	var fills := _own_flight(m, K, held["n"], land)
	var trade := _sent("trade")
	ok("swap mark: the cast sends the landing to other games", trade.size() >= 8, str(trade))
	if trade.size() >= 8:
		_remote(m, P, trade, land, flight)
	_cut_short(m, P, K)
	HeroZones.capture = false
	print("PAIRCHECK swap mark fills %s" % str(fills))

## Steps the Trade to its end; asserts the owner's sigil fills 0 -> 1 over the flight on the landing point.
func _own_flight(m: Match, K: OstraKit, n: Node3D, land: Vector3) -> Array:
	var sw0 := K.swaps
	var fills: Array = [float(n.get_meta("fill"))]
	var off := n.global_position.distance_to(land)
	var secs := DT
	while K.swaps == sw0 and secs < 4.0:
		m.step(DT)
		secs += DT
		fills.append(float(n.get_meta("fill")))
		if K.swaps == sw0:
			off = maxf(off, n.global_position.distance_to(land))
	ok("swap mark: it starts empty (fill under 0.02)", float(fills[0]) < 0.02, "%.3f" % fills[0])
	ok("swap mark: it ends full as the lantern lands (fill 1)", float(fills[-1]) >= 0.999, "%.3f" % fills[-1])
	ok(
		"swap mark: it fills over the lob's flight time",
		absf(secs - float(K.dash_def()["time"])) < 0.05, "%.2f s" % secs
	)
	ok("swap mark: the fill only rises, no jumps", _smooth(fills), "max step %.3f" % _max_step(fills))
	ok("swap mark: it sits on the landing point (0.3 m)", off < ON_SPOT, "%.2f m" % off)
	return [snappedf(fills[0], 0.001), snappedf(fills[fills.size() / 2], 0.01), snappedf(fills[-1], 0.001)]

## A rival's game: the same "trade" event builds the sigil, which fills on its own over the flight.
func _remote(m: Match, P: Hunter, trade: Array, land: Vector3, flight: float) -> void:
	var looks := KitLooks.of(m)
	HeroZones.net_in(m, trade)
	var e := _timed(looks, "trade/" + P.nid)
	ok("swap mark online: a rival's game draws the sigil at launch", not e.is_empty())
	if e.is_empty():
		return
	var n: Node3D = e["n"]
	var fills: Array = [float(n.get_meta("fill"))]
	var off := n.global_position.distance_to(land)
	var secs := 0.0
	while not _timed(looks, "trade/" + P.nid).is_empty() and secs < 4.0:
		looks._process(DT)
		secs += DT
		fills.append(float(n.get_meta("fill")))
		off = maxf(off, n.global_position.distance_to(land))
	ok(
		"swap mark online: it fills 0 -> 1 without jumps over the flight",
		float(fills[0]) < 0.02 and float(fills[-1]) >= 0.98 and _smooth(fills) and absf(secs - flight) < 0.05,
		"%.3f -> %.3f in %.2f s, max step %.3f" % [fills[0], fills[-1], secs, _max_step(fills)]
	)
	ok("swap mark online: on the landing point (0.3 m)", off < ON_SPOT, "%.2f m" % off)

## A Trade stunned mid-flight sends "tradego": the rival's sigil goes with the owner's.
func _cut_short(m: Match, P: Hunter, K: OstraKit) -> void:
	P.dashes = P.max_dashes()
	HeroZones.sent.clear()
	P.ak.on_dash(false)
	m.step(DT)
	HeroZones.net_in(m, _sent("trade"))
	P.stun_t = 0.5
	m.step(DT)
	HeroZones.net_in(m, _sent("tradego"))
	ok(
		"swap mark online: a Trade cut short takes the rival's sigil too",
		K.swap.is_empty() and _timed(KitLooks.of(m), "trade/" + P.nid).is_empty()
			and not KitLooks.of(m).held.has("os_sigil_to")
	)
	P.stun_t = 0.0

func _sent(kind: String) -> Array:
	for e in HeroZones.sent:
		if (e as Array).size() > 1 and e[1] == kind:
			return e
	return ["zone", kind, ""]

func _timed(looks: KitLooks, key: String) -> Dictionary:
	for t in looks.timed:
		if t.get("key", "") == key:
			return t
	return {}

func _smooth(fills: Array) -> bool:
	for i in range(1, fills.size()):
		if float(fills[i]) < float(fills[i - 1]) - 0.0001:
			return false
	return _max_step(fills) <= JUMP

func _max_step(fills: Array) -> float:
	var top := 0.0
	for i in range(1, fills.size()):
		top = maxf(top, float(fills[i]) - float(fills[i - 1]))
	return top
