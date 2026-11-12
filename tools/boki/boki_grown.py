"""Evo's mutations as parts of a rigged Boki: one bone each, shown only on a Boki that has grown them (BokiDna).
grown_parts(a) -> id: (parent bone, bone head, look, tris, primitives); `a` is the species' anchor table."""
from boki_sdf import Cone, Ellipsoid, frame, v3
from vespyx_sides import SIDES


def mir(p, sx):
    return v3(p[0] * sx, p[1], p[2])


def pair(fn):
    return [p for _, sx in SIDES for p in fn(sx)]


def tipped(a, bone, key, tip_r=0.004, tip_k=1.0):
    pa, pb, r = a[key]
    return lambda sx: [Cone("c", bone, mir(pa, sx), mir(pb, sx), r, tip_r * tip_k, k=0)]


def grown_parts(a):
    side = v3(1, 0, 0)
    back_n = len(a["back"])

    def antenna_tips(sx):
        return [Ellipsoid("t", "part_antennae", mir(a["antenna"][1], sx) * 1.0, v3(0.034, 0.034, 0.034), k=0)]

    def spots(sx):
        return [Ellipsoid("s", "part_spots", v3(sx * x, y, z), v3(0.016, r, r), k=0) for x, y, z, r in a["spots"]]

    def wings(sx):
        n = v3(0, 1, 0.3)
        root, t0, t1 = a["wing"]
        return [Cone("w0", "part_wings", mir(root, sx), mir(t0, sx), 0.040, 0.012, k=0.0, flat=0.22, flat_axis=n),
                Cone("w1", "part_wings", mir(root, sx), mir(t1, sx), 0.034, 0.010, k=0.02, flat=0.22, flat_axis=n)]

    def fins(sx):
        return [Cone("f", "part_fins", mir(a["fin"][0], sx), mir(a["fin"][1], sx), 0.055, 0.006, k=0, flat=0.2,
                     flat_axis=side)]

    y0, z0, dy, dz = a["crest"]
    return {
        "horns": ("head", v3(*a["head_top"]), "shell", 90, pair(tipped(a, "part_horns", "horn"))),
        "spikes": ("spine", v3(*a["back_at"]), "shell", 110, [
            Cone("s%d" % i, "part_spikes", v3(*p), v3(p[0], p[1] + 0.11, p[2] + 0.035), 0.042, 0.004, k=0, flat=0.45,
                 flat_axis=side) for i, p in enumerate(a["back"])]),
        "fangs": ("head", v3(*a["fang_at"]), "white", 40, pair(tipped(a, "part_fangs", "fang", 0.002))),
        "brow": ("head", v3(*a["brow_at"]), "shell", 110, [
            Cone("b" + sd, "part_brow", mir(a["brow"][0], sx), mir(a["brow"][1], sx), a["brow"][2], 0.018, k=0.012)
            for sd, sx in SIDES]),
        "plates": ("spine", v3(*a["back_at"]), "shell", 130, [
            Ellipsoid("p0", "part_plates", v3(*a["plates"]), v3(*a["plate_r"]), k=0),
            Ellipsoid("p1", "part_plates", v3(*a["back"][back_n - 1]), v3(*a["plate_r"]), k=0.004)]),
        "shell": ("hips", v3(*a["shell_c"]), "shell", 170, [
            Ellipsoid("s", "part_shell", v3(*a["shell_c"]), v3(*a["shell_r"]), k=0)]),
        "club": (a["tail_bone"], v3(*a["club_at"]), "shell", 120, [
            Ellipsoid("c", "part_club", v3(*a["club_at"]), v3(a["club_r"], a["club_r"], a["club_r"] * 0.66),
                      rot=frame(a["club_dir"], v3(1, 0, 0)), k=0)]),
        "antennae": ("head", v3(*a["head_top"]), "shell", 60, pair(tipped(a, "part_antennae", "antenna", 0.008))),
        "antenna_tips": ("part_antennae", None, "glow", 50, pair(antenna_tips)),
        "spots": ("hips", v3(*a["spots_at"]), "glow", 100, pair(spots)),
        "third_eye": ("head", v3(*a["third_eye"]), "glow", 40, [
            Ellipsoid("e", "part_third_eye", v3(*a["third_eye"]), v3(0.030, 0.034, 0.018), k=0)]),
        "crest": ("head", v3(*a["crest_at"]), "shell", 110, [
            Cone("c%d" % i, "part_crest", v3(0, y0 - i * 0.05, z0 + i * dz),
                 v3(0, y0 - i * 0.05 + 0.13 - i * 0.02, z0 + i * dz + dy), 0.046, 0.005, k=0, flat=0.3, flat_axis=side)
            for i in range(3)]),
        "wings": ("spine", v3(*a["wing_at"]), "shell", 110, pair(wings)),
        "fins": ("hips", v3(*a["fin_at"]), "shell", 70, pair(fins)),
    }
