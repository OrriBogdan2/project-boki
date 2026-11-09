"""ART-1 garden set (DECISIONS 2026-11-09): what every Hunter's three home moves share, in the keys posekit solves. A Hunter's clips file gives the poses
(its own kneel, hand and weapon); this gives the timing and the weight, so the three read as the same craft: the body drops first, the hand follows, a
move ends by returning to ready.
clips(C, ready, P, feel): pet (1.3 s: kneel in, three slow strokes, rise), give (1.0 s: crouch, the snack held out, rise), cheer (0.8 s: dip, spring, pump, land).
P poses (dicts of keys; each inherits from ready): kneel, pet_a (hand down on the head), pet_b (stroked back), give, give_in (the hand drawn a little back),
dip, up, peak, pump. feel: "lead" s the hand trails the body, "snap" 0..1 how crisp the cheer's spring is (a bored Hunter low, a bright one high)."""
CHEER_T = (0.12, 0.26, 0.4, 0.52, 0.8)


def clips(C, ready, P, feel):
    lead = feel.get("lead", 0.06)
    pet = C("pet", 1.3, [
        (0.0, ready), (0.3 + lead, P["pet_a"], "out"), (0.56, P["pet_b"]), (0.76, P["pet_a"]), (0.94, P["pet_b"]), (1.3, ready)])
    give = C("give", 1.0, [
        (0.0, ready), (0.26 + lead, P["give"], "out"), (0.48, P["give_in"]), (0.6, P["give"]), (0.74, P["give"]), (1.0, ready)])
    s = feel.get("snap", 0.5)
    t_dip, t_up, t_peak, t_pump, t_end = CHEER_T
    cheer = C("cheer", t_end, [
        (0.0, ready), (t_dip, P["dip"]), (t_up - 0.06 * s, P["up"], "out"), (t_peak, P["peak"]),
        (t_pump, P["pump"]), (t_end, ready)])
    return [pet, give, cheer]
