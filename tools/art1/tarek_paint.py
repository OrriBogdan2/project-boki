# Tarek's paint (exec'd by tarek_build.py): each part's colour at every atlas texel, from the true field. Painted light,
# not a lit render: the toon shader adds only a soft light on top (WardenGlb.PAINTED).
PX = 2048
AMBER = S.hexc("ff9420")
HOT = S.hexc("ffb448")


def lightness(key, occ, cav, a=0.74):
    k = S.sstep(0.2, 0.93, key)
    return np.clip((0.15 + a * k) * (0.5 + 0.5 * occ) - 0.3 * np.maximum(cav, 0.0) + 0.14 * np.maximum(-cav, 0.0), 0.0, 1.0)


def tones(dark, mid, lite, v):
    return T.light_ramp(S.hexc(dark), S.hexc(mid), S.hexc(lite), v)


def crease(col, cav, dark="1c100c", k=0.75):
    return S.mix(col, S.hexc(dark)[None, :], np.clip(np.maximum(cav, 0.0) * 1.6, 0, 1) * k)


def skin(P, N, occ, cav):
    v = lightness(T.key_shade(N), occ, cav)
    c = tones("3a2017", "7a4930", "ba805a", v + 0.03 * T.strokes(P, 30.0, 2))
    warm = S.sstep(0.25, 0.5, v) * S.sstep(0.75, 0.5, v)
    c = S.mix(c, S.hexc("9c5a3c")[None, :], warm * 0.22)
    return crease(c, cav, "2a140e", 0.7)


def p_head(P, N, occ, cav, a):
    q = P - HC
    c = skin(P, N, occ, cav)
    lens = T.mouth_lens(q)
    lipd = T.lips(q)
    c = S.mix(c, c * S.hexc("d89080") * 1.15, S.sstep(0.012, 0.006, lipd) * 0.8)                    # lips
    c = S.mix(c, S.hexc("2a0e0c")[None, :], S.sstep(0.002, -0.002, lens))                     # the mouth inside
    # warm cheeks, a lit nose
    Qf = T.fold_x(q)
    c = S.mix(c, c * S.hexc("ffb090") * 1.2, S.sstep(0.06, 0.0, S.length(Qf - S.vec(0.07, 0.11, -0.04))) * 0.35)
    c = S.mix(c, c * 1.3, S.sstep(0.03, 0.0, S.length(q - S.vec(0, 0.15, -0.03))) * 0.5)
    return c, None


def p_teeth(P, N, occ, cav, a):
    q = P - HC
    v = S.sstep(-0.3, 0.8, N[:, 1])
    c = S.mix(S.hexc("c8bfae")[None, :], S.hexc("fbf7ec")[None, :], v)
    gap = np.abs(np.sin(q[:, 0] * 340.0))
    c = S.mix(c * 0.72, c, S.sstep(0.0, 0.28, gap))
    return c, None


def p_torso(P, N, occ, cav, a):
    c = skin(P, N, occ, cav)
    t = T.strata(P, R)
    c = S.mix(c, tones("17141a", "2c2830", "4a4450", T.key_shade(N)), t * 0.92)
    return c, None


def p_arm(P, N, occ, cav, a):
    c = skin(P, N, occ, cav)
    return S.mix(c, S.hexc("1e1a20")[None, :], T.left_tattoos(P, R) * 0.92), None


def p_stone(P, N, occ, cav, a, seeds=None):
    idx, d1, gap = S.voronoi(mx(P) if seeds is None else P, SEEDS_A if seeds is None else seeds)
    v = lightness(T.key_shade(N), occ, cav * 0.5, 0.74) + 0.05 * S.fbm(P, 24.0, 6, 3) + 0.05
    tint = 0.94 + 0.09 * np.sin(idx * 2.7)
    c = tones("3a3e4a", "6c7180", "a4aab8", v) * tint[:, None]
    c = crease(c, np.maximum(cav, 0.0) * 0.7, "2a2c36", 0.75)
    crack = S.sstep(0.0085, 0.0045, gap)
    c = S.mix(c, S.hexc("3a2c30")[None, :], crack)
    hot = S.sstep(0.0065, 0.003, gap)
    core = S.sstep(0.003, 0.001, gap)
    col = S.mix(S.hexc("f06010")[None, :], S.hexc("ffa030")[None, :], core)
    c = S.mix(c, col, hot)
        return c, col * hot[:, None]


def p_hands(P, N, occ, cav, a):
    # (the left hand, greyed by the stone arm above it)
    v = lightness(T.key_shade(N), occ, cav, 0.74)
    c = tones("3a3634", "6a6464", "a09a98", v + 0.06)
    # amber cracks run from the bracer over the backs of his hands
    Q = (T.fold_x(P) - R.wr) / T.HAND_K
    seeds = HAND_SEEDS
    q2 = Q * S.vec(0.0, 1.0, 1.0)
    idx, d1, gap = S.voronoi(q2, seeds)
    back = S.sstep(0.0, 0.016, Q[:, 0]) * S.sstep(-0.13, -0.09, Q[:, 2])
    ln = S.sstep(0.0055, 0.0018, gap) * back * S.sstep(-0.05, 0.2, S.noise(P, 16.0, 3))
    c = S.mix(c, S.hexc("5c2410")[None, :], np.minimum(ln * 2.2, 1.0) * back)
    c = S.mix(c, AMBER[None, :], ln)
    e = AMBER[None, :] * ln[:, None]
    # a warm spill at the wrist
    c = S.mix(c, S.hexc("c86a30")[None, :], back * S.sstep(-0.04, 0.03, Q[:, 2]) * 0.3)
    return c, e


def p_bandana(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.04 * T.strokes(P, 40.0, 5)
    c = tones("80705a", "c4b296", "ece2cc", v)
    stain = S.sstep(0.05, 0.4, S.fbm(P, 18.0, 15, 3))
    return crease(S.mix(c, c * S.hexc("c8a888"), stain * 0.7), cav, "4e4032", 0.8), None


def p_sash(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.04 * T.strokes(P, 34.0, 9)
    return crease(tones("6e2010", "c84a1c", "f08c4a", v), cav, "34100a"), None


def p_tails(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, 0.85, 0.7) + 0.05 * S.noise(P, 40.0, 3)
    s = a[:, 0]
    c = tones("6e2010", "c84a1c", "f08c4a", v)
    streak = 0.5 + 0.5 * np.sin(a[:, 1] * 6.28 * 2 + s * 16.0)
    c = S.mix(c, c * 0.72, S.sstep(0.6, 0.95, streak))
    frayed = S.sstep(0.0, 0.1, s - np.maximum(0.0, (a[:, 0].max() - 0.12)))
    return c * (1.0 - 0.25 * frayed)[:, None], None


def p_band_tails(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, 0.85, 0.7)
    return tones("80705a", "c4b296", "ece2cc", v), None


def p_wrap(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.05 * T.strokes(P, 40.0, 19)
    return crease(tones("8d7f6a", "d8cdb6", "f4ecd8", v), cav, "5a4e40"), None


def p_trousers(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav * 0.9) + 0.02 * T.strokes(P, 26.0, 23)
    c = tones("1e1816", "463830", "75604e", v)
    # the tan piping down the outer seam
    Q = T.fold_x(P)
    az = np.arctan2(Q[:, 1], Q[:, 0] - float(R.hip[0]))
    pipe = S.sstep(0.09, 0.05, np.abs(az)) * S.sstep(0.5, 0.48, np.abs(P[:, 2] - 0.8))
    c = S.mix(c, tones("6e5230", "c29a5c", "e6c88c", v), pipe)
    inner = S.sstep(0.03, 0.016, np.abs(P[:, 0])) * S.sstep(float(R.hip[2]) - 0.1, float(R.hip[2]) - 0.16, P[:, 2])
    c = S.mix(c, S.hexc("120e0c")[None, :], inner)
    return crease(c, cav, "0e0a08", 0.55), None


def p_legs(P, N, occ, cav, a):
    c = skin(P, N, occ, cav)
    # dust on the soles and toes
    d = S.sstep(0.045, 0.0, P[:, 2])
    c = S.mix(c, S.hexc("6e5a48")[None, :], d * 0.75)
    return c, None


def p_wraps(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav * 1.3) + 0.05 * T.strokes(P, 40.0, 27)
    return crease(tones("2e2218", "6e5842", "a08a6c", v), cav, "4a3e30", 0.85), None


def p_hair(P, N, occ, cav, a):
    key = T.key_shade(N)
    v = lightness(key, occ, cav, 0.75)
    c = tones("08080c", "18181e", "40424e", v)
    c = crease(c, cav, "060405", 0.9)
    sheen = S.sstep(0.68, 0.9, key) * S.sstep(-0.1, 0.5, S.noise(P * S.vec(1, 1, 0.3), 46.0, 3))
    return S.mix(c, S.hexc("6e6a7e")[None, :], sheen * 0.3), None


def p_locs(P, N, occ, cav, a):
    key = T.key_shade(N)
    ph = a[:, 1] * 6.283 * 2.0 + a[:, 0] * 86.0
    groove = 0.5 + 0.5 * np.sin(ph)
    v = (0.3 + 0.7 * key) * (0.4 + 0.6 * S.sstep(0.05, 0.55, groove)) * (0.55 + 0.45 * occ)
    c = tones("08080c", "16161c", "3c3e4c", v)
    sheen = S.sstep(0.74, 0.95, key) * S.sstep(0.45, 0.9, groove)
    return S.mix(c, S.hexc("6c7694")[None, :], sheen * 0.5), None


def p_beads(P, N, occ, cav, a):
    key = T.key_shade(N)
    kind = a[:, 3]
    v = key * (0.55 + 0.45 * occ)
    copper = tones("4e2a1a", "a4643c", "e8b48a", v + 0.2 * S.sstep(0.74, 0.9, key))
    steel = tones("4a5058", "9aa2aa", "e6ecf0", v + 0.2 * S.sstep(0.74, 0.9, key))
    stone = tones("5a4c40", "ac9a84", "dacdb6", v + 0.06 * S.noise(P, 120.0, 3))
    geo = tones("6a5848", "c4b49c", "f0e6d0", v)
    c = np.where((kind < 0.5)[:, None], copper, np.where((kind < 1.5)[:, None], steel, np.where((kind < 2.5)[:, None], stone, geo)))
    # a scratched band across each ring
    return c, None


def p_crystals(P, N, occ, cav, a):
    key = T.key_shade(N)
    c = S.mix(S.hexc("ff8a1c")[None, :], S.hexc("ffe28a")[None, :], key[:, None])
    return c, None


def p_geode(P, N, occ, cav, a):
    Pn = P / GEO_R
    rad = np.sqrt(Pn[:, 0] ** 2 + Pn[:, 2] ** 2)
    v = lightness(T.key_shade(N), occ, cav * 0.7, 0.65) + 0.08 * S.fbm(Pn, 5.0, 6, 3)
    c = tones("5c5448", "a09482", "d0c6b4", v + 0.05)
    # the pale banded rim, the crystals going warm toward the eye
    face = S.sstep(0.0, 0.3, Pn[:, 1])
    rim = tones("7c7060", "c4b8a4", "ecE2d0", v + 0.05)
    c = S.mix(c, rim, face * S.sstep(0.98, 0.84, rad))
    band = S.sstep(0.03, 0.0, np.abs(rad - 0.82 - 0.02 * np.sin(np.arctan2(Pn[:, 2], Pn[:, 0]) * 6.0)))
    c = S.mix(c, S.hexc("a88a6c")[None, :], band * face * 0.8)
    deep = face * S.sstep(0.74, 0.4, rad)
    c = S.mix(c, S.mix(S.hexc("6e4228")[None, :], S.hexc("f8a858")[None, :], S.sstep(0.62, 0.38, rad)) * (0.55 + 0.6 * v)[:, None], deep)
    e = S.hexc("ff8a1c")[None, :] * (deep * S.sstep(0.55, 0.36, rad) * 0.5)[:, None]
    return crease(c, cav, "2a1c14", 0.6), e


def p_iris(P, N, occ, cav, a):
    Pn = P / GEO_R
    x, z = Pn[:, 0], Pn[:, 2]
    r = np.sqrt(x * x + z * z) / 0.46
    az = np.arctan2(z, x)
    fib = 0.5 + 0.5 * np.sin(az * 34.0 + 3.0 * S.noise(Pn, 8.0, 2)) * (0.6 + 0.4 * np.sin(az * 13.0))
    c = S.ramp(np.clip(1.0 - r + 0.18 * (fib - 0.5), 0, 1), ("7a1e06", "e8560c", "ff9a1e", "ffd25e", "ffe88e"))
    slit = (np.abs(x) / (0.06 * np.sqrt(np.clip(1.0 - (z / 0.36) ** 2, 0.0, 1.0)) + 0.002))
    c = S.mix(S.hexc("1a0704")[None, :], c, S.sstep(0.85, 1.15, slit))
    c = S.mix(c, S.hexc("fff4cc")[None, :], S.sstep(0.09, 0.05, S.length(np.stack((x + 0.13, z - 0.14), -1))))
    return c, c * 0.8


P_FN = {"head": p_head, "teeth": p_teeth, "torso": p_torso, "arms": p_arm, "hands": p_hands, "legs": p_legs,
        "bandana": p_bandana, "cap": p_hair, "skirt": p_sash, "stone": p_stone, "prayer": lambda P, N, o, c, a: p_prayer(P, N, o, c, a), "wrap": p_wrap, "sash": p_sash, "trousers": p_trousers,
        "wraps": p_wraps, "locs": p_locs, "beads": p_beads,
        "sash_tails": p_tails, "band_tails": p_band_tails, "geode": p_geode, "iris": p_iris,
        "shard": lambda P, N, o, c, a: p_shard(P, N, o, c, a),
        "gauntlet": lambda P, N, o, c, a: p_stone(P, N, o, c, a, SEEDS_G)}


def p_prayer(P, N, occ, cav, a):
    v = T.key_shade(N) * (0.55 + 0.45 * occ)
    pale = tones("6c6356", "bdb3a0", "ece6d8", v + 0.05)
    dark = tones("3c2a20", "7a5a44", "b08e70", v)
    return np.where((a[:, 3] > 0.5)[:, None], dark, pale), None


def p_shard(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav, 0.75)
    return tones("7c6648", "c9b796", "f2e6cc", v + 0.1), None


_rs = np.random.RandomState(7)
HAND_SEEDS = np.stack((np.zeros(9), _rs.uniform(-0.08, 0.08, 9), _rs.uniform(-0.13, 0.04, 9)), 1).astype(np.float32)
ARMS = ("arms", "hands", "stone", "gauntlet")


def corners(ob):
    me = ob.data
    me.calc_loop_triangles()
    tr = me.loop_triangles
    n = len(tr)
    lt = np.zeros(n * 3, np.int32)
    tr.foreach_get("loops", lt)
    vt = np.zeros(n * 3, np.int32)
    tr.foreach_get("vertices", vt)
    uv = np.zeros(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)[lt].reshape(n, 3, 2)
    V = verts_np(ob)[vt].reshape(n, 3, 3)
    cn = np.array([c.vector[:] for c in me.corner_normals], np.float32)[lt].reshape(n, 3, 3)
    return uv, V, cn, vt.reshape(n, 3)


def paint_all(objs):
    img = np.zeros((PX, PX, 3), np.float32)
    em = np.zeros((PX, PX, 3), np.float32)
    all_mask = np.zeros((PX, PX), bool)
    g_body, g_all = world_grids()
    for ob in objs:
        t0 = time.time()
        nm = ob.name
        uv, V, Nn, vt = corners(ob)
        attrs = [V, Nn]
        swept = bool(ob.get("swept"))
        if swept:
            attrs.append(ATTR[nm][vt])
        mask, out, _ = S.rasterize(uv, None, PX, attrs)
        idx = np.nonzero(mask)
        if idx[0].size == 0:
            continue
        P = out[0][idx]
        N = out[1][idx]
        N = N / np.maximum(S.length(N), 1e-6)[:, None]
        a = out[2][idx] if swept else None
        if swept:
            f = g_body
            occ = S.occlusion(g_body, P + N * 0.006, N, (0.02, 0.05))
            cav = np.zeros(P.shape[0], np.float32)
        else:
            f = lambda X_: S.chunked(PARTS[nm]["f"], X_)
            for _ in range(2):
                P = P - S.gradient(f, P, 0.0015) * f(P)[:, None]
            N = S.gradient(f, P, 0.002)
            if nm in ("geode", "iris", "shard"):
                occ = S.occlusion(f, P, N, (0.006, 0.014, 0.03))
            else:
                g = g_all if nm in ARMS else g_body
                occ = np.minimum(S.occlusion(f, P, N, (0.006, 0.014, 0.03)), S.occlusion(g, P + N * 0.01, N, (0.016, 0.04, 0.08)) * 0.5 + 0.5)
            cav = S.cavity(f, P, N, 0.005)
        c, e = P_FN[nm](P, N, occ, cav, a)
        img[idx] = c
        if e is not None:
            em[idx] = e
        all_mask |= mask
        log("painted %s: %d texels, %.1f s" % (nm, P.shape[0], time.time() - t0))
    img = S.dilate(img, all_mask, 6)
    em = S.dilate(em, all_mask, 6)
    return save_img(img, "tarek_atlas"), save_img(em[::2, ::2], "tarek_emit")


def save_img(a, name):
    """Our display-space numbers straight into a JPEG (ffmpeg: no colour management in the way)."""
    h, w = a.shape[:2]
    raw = os.path.join(OUT, name + ".rgb")
    (np.clip(a[::-1], 0, 1) * 255.0 + 0.5).astype(np.uint8).tofile(raw)
    path = os.path.join(OUT, name + ".jpg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h), "-i", raw,
                    "-q:v", "3", "-pix_fmt", "yuvj444p", path], check=True)
    os.remove(raw)
    out = bpy.data.images.load(path)
    out.colorspace_settings.name = "sRGB"
    out.pack()
    log("saved", path)
    return out
