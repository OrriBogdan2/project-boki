"""The map rule for the Limited Ways Out mode (briefs/specs/LIMITED_WAY_OUTS.md section 8), shared by the
map generators. A map authors "heart": [x, y] (the Throne / vault crown), the quest sites (lairs, uplink
outposts) and nothing else; the Heart Gate is picked by the match seed at GATE_DIST from the heart.
Numbers come from content/rules/heart.json ("map" and the tide), in metres on the 216 m design; `scale`
(the map's "ways_scale", 1.412 on the 305 m Hollow Crown) stretches radii and bands, never times."""
import json, math, os

_R = json.load(open(os.path.join(os.path.dirname(__file__), "..", "content", "rules", "heart.json")))
_M = _R["map"]
TIDE_START, TIDE_CLOSE = _R["tide_start_s"], _R["tide_close_s"]   # s: the Blight ring starts closing, and takes this long
RING_R0, RING_R1 = _R["tide_r0"], _R["tide_r1"]   # m: the ring's first and final radius (the final ring holds from 10:00)
WINDOW = _M["seat_window_s"]                      # s: a quest seat's site stays inside the ring this long after it opens
OPENS = {"lair": _R["quest"]["lair_open_s"], "uplink": _R["quest"]["uplink_open_s"]}
GATE_DIST = _R["gate_dist"]                       # m: heart to Heart Gate (inside the final ring)
GATE_CLEAR = _M["gate_clear"]                     # m: every uplink outpost is at least this far from the Gate
UPLINK_BAND = tuple(_M["uplink_band"])            # m: uplink outposts from the heart
UPLINK_APART = _M["uplink_apart_deg"]             # degrees round the heart between the two outposts
GATE_ARC_MIN = _M["gate_arc_min_deg"]             # degrees of seeded gate angle that must be on ground and clear


def ring_r(t, scale=1.0):
    """Blight ring radius in metres t seconds into the match."""
    f = min(1.0, max(0.0, (t - TIDE_START) / TIDE_CLOSE))
    return (RING_R0 + (RING_R1 - RING_R0) * f) * scale


def _ang(heart, p):
    return math.degrees(math.atan2(p[1] - heart[1], p[0] - heart[0])) % 360.0


def _apart(a, b):
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def gate_arc(heart, outposts, ground, scale=1.0):
    """Whole degrees of Heart Gate angle that stand on ground and keep 60 m (scaled) from every outpost."""
    hx, hz = heart
    ok = []
    for a in range(360):
        gx = hx + GATE_DIST * scale * math.cos(math.radians(a))
        gz = hz + GATE_DIST * scale * math.sin(math.radians(a))
        if ground(gx, gz) and all(math.hypot(gx - o[0], gz - o[1]) >= GATE_CLEAR * scale for o in outposts):
            ok.append(a)
    return ok


def check(heart, outposts, lairs, ground, scale=1.0, gate_ground=None):
    """Problems with the Ways Out sites (empty = fine), plus the clear gate angles for the report.
    `ground(x, z)`: solid ground; `gate_ground` (default the same) is what the Gate may stand on."""
    probs = []
    if not heart or not ground(heart[0], heart[1]):
        return ["heart %s missing or not on ground" % (heart,)], []
    seats = [("lair " + L["id"], L["at"], "lair") for L in lairs] + [("outpost %s" % (o[:2],), o, "uplink") for o in outposts]
    for name, p, kind in seats:
        d = math.hypot(p[0] - heart[0], p[1] - heart[1])
        end = ring_r(OPENS[kind] + WINDOW, scale)
        if d > end:
            probs.append("%s is %.1f m from the heart: the ring (%.1f m) has passed it %d s after it opens" % (name, d, end, WINDOW))
        if d <= RING_R1 * scale:
            probs.append("%s is %.1f m from the heart, inside the final ring (%.1f m)" % (name, d, RING_R1 * scale))
    lo, hi = UPLINK_BAND[0] * scale, UPLINK_BAND[1] * scale
    if len(outposts) != 2:
        probs.append("%d uplink outposts, want 2" % len(outposts))
    for o in outposts:
        d = math.hypot(o[0] - heart[0], o[1] - heart[1])
        if not lo <= d <= hi:
            probs.append("outpost %s is %.1f m from the heart, want %.0f-%.0f" % (o[:2], d, lo, hi))
    if len(outposts) == 2 and _apart(_ang(heart, outposts[0]), _ang(heart, outposts[1])) < UPLINK_APART:
        probs.append("the two outposts are under %d degrees apart round the heart" % UPLINK_APART)
    arc = gate_arc(heart, outposts, gate_ground or ground, scale)
    if len(arc) < GATE_ARC_MIN:
        probs.append("only %d degrees of Heart Gate angle are on ground and %.0f m from both outposts (want %d)"
                     % (len(arc), GATE_CLEAR * scale, GATE_ARC_MIN))
    return probs, arc
