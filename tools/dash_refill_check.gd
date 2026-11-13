extends RefCounted
## Dash refill order, for --move-feel-check: spend two charges (or the kit's only one) with real dash
## presses and time each return. The source's charge abilities run ONE timer: the first spent charge
## is back after one recharge, the next one a recharge after that (never both at once, never a timer
## restarted by the second press). Charge k is back k * regen after the first press.

const GAP := 0.8          # s between the two presses
const TOL := 0.12         # s a return may be off its slot
## Kits whose dash needs the key held (a short skate hands part of its charge back, kit data "refund"): s held.
const HOLD := {"rimewright": 2.0}
## Kits whose recharge waits for a hop chain to end (Rock Hop, breah_hop._hold_charge): the longest wait, s.
const CHAIN_WAIT := {"dolm": 1.0}

static func run(c) -> void:
	var cls_was: String = c.P.cls
	var arch_was: String = c.P.arch
	for id in Arch.ORDER:
		c.P.reclass(Arch.weight(id), id)
		c._reset(c.flat, true)
		_kit(c, id)
	c.P.reclass(cls_was, arch_was)
	c.P.set_arch(arch_was)
	c._clear_inp()

## Presses dash GAP apart until `want` charges are spent, then notes when each comes back.
static func _kit(c, id: String) -> void:
	var P: Hunter = c.P
	var want := mini(2, int(P.max_dashes()))
	var regen := P.dash_regen()
	var presses: Array = []
	var returns: Array = []
	var t := 0.0
	var limit := regen * (P.max_dashes() + 1.0) + 3.0
	while t < limit and returns.size() < want:
		if presses.size() < want and P.dashes >= 1.0 and (presses.is_empty() or t >= presses[-1] + GAP):
			var before := P.dashes
			P.inp["move"] = Vector2(1, 0)
			P.inp["dash"] = true
			t += _tick(c)
			P.inp["dash"] = false
			if P.dashes < before - 0.5:
				presses.append(t)
				P.inp["dash_down"] = true
				for i in int(float(HOLD.get(id, 0.0)) / c.DT):
					t += _tick(c)
				P.inp["dash_down"] = false
			continue
		t += _tick(c)
		if presses.size() == want and P.dashes >= P.max_dashes() - want + returns.size() + 1.0 - 1e-4:
			returns.append(t)
	var sizes := "%d pressed, %d came back" % [presses.size(), returns.size()]
	c.ok(presses.size() == want and returns.size() == want, "%s: %s" % [id, sizes])
	if presses.size() != want or returns.size() != want:
		return
	for k in want:
		var slot := regen * float(k + 1)
		var late: float = returns[k] - presses[0] - slot
		var slack: float = TOL + c.DT * 2.0
		var what := "charge %d back %.2fs after the first dash (one timer: %.2fs)"
		c.ok(late >= -slack and late <= slack + float(CHAIN_WAIT.get(id, 0.0)),
			"%s: %s" % [id, what % [k + 1, returns[k] - presses[0], slot]])

static func _tick(c) -> float:
	c.m.step(c.DT)
	return c.DT
