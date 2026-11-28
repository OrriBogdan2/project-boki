"""Geodemole's own clips on the scan rig it shares with Glomwort (root, hips, spine, neck, head): a mole that has grown
heavy enough to sit up on its haunches with a split geode on its back. It sorts stones by colour, so its idle is
tidy, patient and fussy: the head dipping and turning over each stone, the body shuffling a step at a time, the
geode shell rocking on its back. It digs in as its attack and cracks the geode wider as its ability."""

import glomwort_anim
from boki_clips import LOOK_UP, add, eat_ground, s, seq

BONES = glomwort_anim.BONES
HIDE_AT = glomwort_anim.HIDE_AT


def shell(p, t, amp, rate=1, ph=0.0):
    """The geode on its back rocks a beat behind the body (the spine rolls late)."""
    add(p, "spine", rz=amp * s(t, rate, ph - 0.1), rx=0.4 * amp * s(t, rate * 2, ph - 0.1))


def idle(t):
    """Sits up on its haunches sorting: it dips its head to pick a stone, turns it over, sets it on a pile to the left
    or right and checks the pile, the shell shifting with each reach."""
    p = {"root_sc": (1, 1 + 0.015 * s(t, 2), 1)}
    pick = seq(t, [(0, 0), (0.12, 1), (0.3, 1), (0.4, 0), (1, 0)])
    sort = seq(t, [(0, 0), (0.4, 0), (0.5, 1), (0.6, 1), (0.7, 0.2), (0.78, -1), (0.9, -1), (1, 0)])
    add(p, "spine", rx=-0.1 * pick, ry=0.2 * sort, rz=0.03 * sort)
    add(p, "neck", rx=-0.15 * pick)
    add(p, "head", rx=LOOK_UP * 0.3 - 0.25 * pick + 0.04 * s(t, 4) * pick, ry=0.22 * sort, rz=0.05 * s(t, 2))
    add(p, "root", rz=0.02 * sort)
    return p


def shuffle(t, amp):
    """Short shuffling steps on its haunches: small quick hitches, the heavy geode rocking side to side behind."""
    w = s(t, 2)
    p = {"root_at": (0, 0.006 * amp * abs(s(t, 2, 0.25)), 0)}
    add(p, "root", rz=0.05 * amp * s(t, 2), rx=-0.03 * amp)
    add(p, "hips", ry=0.05 * amp * w)
    shell(p, t, 0.06 * amp, rate=2)
    add(p, "head", rx=LOOK_UP * 0.3 + 0.04 * amp * s(t, 4), ry=-0.06 * amp * w)
    return p


def walk(t):
    return shuffle(t, 1.0)


def run(t):
    """A frantic scurry: leaning forward on its fore-claws, short fast scrabbles, the shell bouncing."""
    p = shuffle(t, 1.5)
    p["root_at"] = (0, 0.012 + 0.012 * s(t, 4), 0)
    add(p, "root", rx=-0.24)
    add(p, "spine", rx=-0.1)
    add(p, "head", rx=-0.14)
    return p


def carry(t):
    p = shuffle(t, 0.8)
    add(p, "head", rx=0.08)
    return p


def hop(t):
    """A startled-happy hop: a flat crouch, a short high pop with the claws up, landing with a rattle of crystals."""
    air = seq(t, [(0, 0), (0.18, -0.8), (0.34, 0.3), (0.5, 1), (0.66, 0.3), (0.78, -0.8), (0.9, 0.1), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    rattle = seq(t, [(0, 0), (0.78, 0), (0.84, 1), (0.92, -0.7), (1, 0)])
    p = {"root_at": (0, 0.12 * up - 0.03 * down, 0)}
    p["root_sc"] = (1 + 0.12 * down, 1 - 0.16 * down + 0.08 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.08 * up - 0.05 * down)
    add(p, "spine", rz=0.07 * rattle)
    add(p, "head", rx=LOOK_UP * 0.3 + 0.12 * up - 0.1 * down)
    return p


def dig(t):
    """Attack: rears up on its haunches, then drops and rakes both claws down and back, the head and the shell lunging
    after them."""
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, 1), (0.48, 0), (1, 0)])
    rake = seq(t, [(0.4, 0), (0.5, 1), (0.64, 1), (0.84, 0.15), (1, 0)])
    p = {"root_at": (0, 0.03 * wind - 0.03 * rake, 0.02 * wind - 0.11 * rake)}
    p["root_sc"] = (1, 1 + 0.04 * wind - 0.1 * rake, 1 + 0.08 * rake)
    add(p, "root", rx=-0.28 * wind + 0.38 * rake)
    add(p, "spine", rx=-0.08 * wind + 0.12 * rake, rz=0.05 * s(t, 8) * rake)
    add(p, "head", rx=0.1 * wind - 0.3 * rake)
    return p


def crack(t):
    """Its E: tucks its head in and braces, the geode on its back shuddering, then the crack gapes wider with a
    sharp pop and the whole body rings like struck crystal."""
    k = seq(t, [(0, 0), (0.4, -1), (0.55, -1), (0.62, 1), (0.8, 0.4), (1, 0)])
    dn = max(-k, 0)
    up = max(k, 0)
    ring = seq(t, [(0, 0), (0.58, 0), (0.62, 1), (0.8, 0.5), (1, 0)])
    p = {"root_at": (0, 0.05 * up - 0.025 * dn, 0)}
    p["root_sc"] = (1 + 0.1 * dn - 0.03 * up + 0.03 * ring * s(t, 15), 1 - 0.12 * dn + 0.08 * up, 1 + 0.1 * dn)
    add(p, "root", rx=0.18 * up - 0.08 * dn, rz=0.06 * ring * s(t, 15))
    add(p, "spine", rx=-0.14 * dn + 0.1 * up, rz=0.06 * (0.3 * dn + ring) * s(t, 15))
    add(p, "head", rx=LOOK_UP * 0.3 - 0.35 * dn + 0.3 * up)
    return p


def sort_eat(t):
    """Eat: picks the food up, turns it over, sets it aside, then nibbles quick and tidy bites."""
    p = eat_ground(t)
    add(p, "spine", rx=-0.08)
    add(p, "head", ry=0.12 * s(t, 1), rx=0.04 * s(t, 3))
    return p


def pet(t):
    """Lets itself be petted for a moment, then goes back to its stones; leans in, head tilted, the crystals
    chiming with a tiny rock."""
    lean = 0.5 + 0.5 * s(t, 1)
    p = {}
    shell(p, t, 0.03, rate=2)
    add(p, "root", rz=0.03 * s(t, 1, 0.25))
    add(p, "head", rx=LOOK_UP * 0.3 + 0.08 * lean, rz=0.2 * lean, ry=0.08 * lean)
    return p


def curl(t):
    """Sleep: slumped forward over its stones with its snout on its claws, the geode shell a rounded hump rising and
    falling."""
    br = s(t, 1)
    p = {"root_at": (0, -0.07, 0)}
    p["root_sc"] = (1.06 + 0.015 * br, 0.84 + 0.03 * br, 1.05)
    add(p, "root", rx=-0.1)
    add(p, "spine", rx=-0.14)
    add(p, "head", rx=-0.3, ry=0.15, rz=0.06)
    return p


CLIPS = dict(glomwort_anim.CLIPS)
CLIPS.update(
    {
        "idle": (3.6, True, idle),
        "walk": (0.7, True, walk),
        "run": (0.4, True, run),
        "hop": (0.9, True, hop),
        "carry": (0.8, True, carry),
        "pet": (2.2, True, pet),
        "attack": (0.8, False, dig),
        "ability": (1.5, False, crack),
        "sleep": (4.0, True, curl),
        "eat": (2.0, True, sort_eat),
    }
)
