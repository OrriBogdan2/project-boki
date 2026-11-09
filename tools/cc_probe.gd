extends RefCounted
## What an invulnerable body ignores besides damage (checks): throws a knock, a tow and a slow status at `t` and
## returns what took hold, e.g. "knock tow slow", or "" when it shrugged all three off.

static func landed(m: Match, t: Ent, by: Ent) -> String:
	var out: PackedStringArray = []
	var v0 := t.vel
	m.displace.knock(t, Vector2(9.0, 0.0), 1.0)
	if (t.vel - v0).length() > 0.5:
		out.append("knock")
	t.vel = v0
	var rec := m.displace.tow(t, by, {"mode": "glide", "dur": 1.0, "spd": 6.0})
	m.displace.tick(0.05)
	if not rec.has("end") or rec["end"] != "proof":
		out.append("tow")
	m.displace.stop(rec)
	var slow0 := t.slow_t
	KitStatus.apply(t, "dsr", 1.0, 0.4)
	if t.slow_t > slow0:
		out.append("slow")
	return " ".join(out)
