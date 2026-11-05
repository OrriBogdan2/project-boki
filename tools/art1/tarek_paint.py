# Tarek's paint (exec'd by tarek_build.py): each part's colour at every atlas texel, from the true field. Painted light,
# not a lit render: the toon shader adds only a soft light on top (WardenGlb.PAINTED).
PX = 2048
AMBER = S.hexc("ff9420")
HOT = S.hexc("ffd870")


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


def p_skin(P, N, occ, cav, a):
    return skin(P, N, occ, cav), None


def p_hands(P, N, occ, cav, a):
    c = skin(P, N, occ, cav)
    # amber cracks run from the bracer over the backs of his hands
    Q = T.fold_x(P) - R.wr
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


def p_rock(P, N, occ, cav, a, seeds):
    idx, d1, gap = S.voronoi(P, seeds)
    v = lightness(T.key_shade(N), occ, cav * 0.6, 0.7) + 0.08 * S.fbm(P, 30.0, 6, 3)
    tint = 0.92 + 0.14 * np.sin(idx * 2.7)
    c = tones("94805f", "e2d4b8", "fff8e8", v + 0.16)
    # chipped lighter edges, dark grit
    speck = S.fbm(P, 90.0, 12, 2)
    c = crease(c, np.maximum(cav, 0.0) * 0.8, "241a14", 0.8)
    crack = S.sstep(0.012, 0.006, gap)
    c = S.mix(c, S.hexc("8a3a14")[None, :], crack)
    # only some seams burn, in long runs, as the art draws them
    run = S.sstep(-0.2, 0.05, S.fbm(P, 7.0, 21, 2))
    burn = S.sstep(0.016, 0.007, gap) * run
    spill = S.sstep(0.04, 0.01, gap) * run
    c = S.mix(c, S.hexc("c8501a")[None, :], spill * 0.55)
    c = S.mix(c, S.mix(AMBER[None, :], HOT[None, :], S.sstep(0.007, 0.002, gap)), burn)
    e = S.mix(S.hexc("ff8a1c")[None, :], HOT[None, :], S.sstep(0.007, 0.002, gap)) * burn[:, None]
    return c, e


def p_bandana(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.04 * T.strokes(P, 40.0, 5)
    c = tones("80705a", "c4b296", "ece2cc", v)
    stain = S.sstep(0.05, 0.4, S.fbm(P, 18.0, 15, 3))
    return crease(S.mix(c, c * S.hexc("c8a888"), stain * 0.7), cav, "4e4032", 0.8), None


def p_vest(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.035 * T.strokes(P, 32.0, 7)
    c = tones("232c3c", "4a5c76", "8ca2bc", v)
    trim = T.vest_trim(P, R)
    c = S.mix(c, tones("34445a", "6f88a6", "a8bdd2", v), trim * 0.8)
    wear = S.sstep(0.28, 0.5, S.fbm(P, 16.0, 17, 3))
    c = S.mix(c, c * S.hexc("d8c8b0") * 1.15, wear * 0.45)
    st = (np.sin(P[:, 2] * 420.0) > 0.2) * S.sstep(0.0035, 0.0015, np.abs(np.abs(P[:, 0]) - (0.066 + 0.1 * np.clip((float(R.waist[2]) + 0.6 - P[:, 2]) / 0.42, 0, 1)) - 0.024)) * (P[:, 1] > 0)
    c = S.mix(c, S.hexc("c8c0b0")[None, :], st * 0.75)
    return crease(c, cav, "16171c"), None


def p_sash(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav) + 0.04 * T.strokes(P, 34.0, 9)
    return crease(tones("7c2410", "d4501e", "fb9a52", v), cav, "34100a"), None


def p_tails(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, 0.85, 0.7) + 0.05 * S.noise(P, 40.0, 3)
    s = a[:, 0]
    c = tones("7c2410", "d4501e", "fb9a52", v)
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
    c = tones("46341c", "93733f", "c4a26a", v)
    dirt = S.sstep(0.62, 0.42, P[:, 2]) * 0.12 + 0.08 * S.sstep(0.1, 0.45, S.fbm(P, 11.0, 25, 3))
    c = S.mix(c, c * S.hexc("c8a888"), dirt)
    # the knee patch and its big stitches
    pa = T.trouser_patch(P)
    m = S.sstep(-0.001, 0.002, pa)
    c = S.mix(c, tones("3a2415", "7c5333", "a87a4e", v), m)
    edge = S.sstep(0.012, 0.007, np.abs(pa - 0.002))
    q = (P - S.vec(0.128, 0.115, 0.71))
    st = S.sstep(0.0, 0.6, np.sin((q[:, 0] + q[:, 2]) * 190.0))
    c = S.mix(c, S.hexc("e8d8b8")[None, :], edge * st * 0.8 * (P[:, 1] > 0.05))
    # the inner faces where the legs part stay in shade
    inner = S.sstep(0.03, 0.012, np.abs(P[:, 0])) * S.sstep(float(R.hip[2]) - 0.1, float(R.hip[2]) - 0.16, P[:, 2])
    c = S.mix(c, S.hexc("4a3620")[None, :], inner)
    return crease(c, cav, "2e2010", 0.55), None


def p_legs(P, N, occ, cav, a):
    c = skin(P, N, occ, cav)
    # dust on the soles and toes
    d = S.sstep(0.045, 0.0, P[:, 2])
    c = S.mix(c, S.hexc("6e5a48")[None, :], d * 0.75)
    return c, None


def p_wraps(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav * 1.3) + 0.05 * T.strokes(P, 40.0, 27)
    return crease(tones("7e705c", "c8bca4", "ece4d0", v), cav, "4a3e30", 0.85), None


def p_harness(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav)
    c = tones("1a1516", "3a3031", "6a5a58", v)
    st = (np.sin((P[:, 0] + P[:, 1] + P[:, 2]) * 300.0) > 0.3) * S.sstep(0.0, 0.3, S.noise(P, 60.0, 3))
    return S.mix(c, S.hexc("8a7a68")[None, :], st * 0.25), None


def p_gear(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav, 0.8)
    v = v + 0.25 * S.sstep(0.65, 0.92, T.key_shade(N))
    return tones("3e444c", "8a939c", "e8eef2", v), None


def p_pouch(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav)
    return crease(tones("544228", "a08a5c", "d0bb8a", v), cav, "2e2414"), None


def p_hair(P, N, occ, cav, a):
    key = T.key_shade(N)
    v = lightness(key, occ, cav, 0.75)
    c = tones("160c0c", "38221f", "76503f", v + 0.1)
    c = crease(c, cav, "060405", 0.9)
    sheen = S.sstep(0.68, 0.9, key) * S.sstep(-0.1, 0.5, S.noise(P * S.vec(1, 1, 0.3), 46.0, 3))
    return S.mix(c, S.hexc("6e6a7e")[None, :], sheen * 0.3), None


def p_locs(P, N, occ, cav, a):
    key = T.key_shade(N)
    ph = a[:, 1] * 6.283 * 2.0 + a[:, 0] * 86.0
    groove = 0.5 + 0.5 * np.sin(ph)
    v = (0.3 + 0.7 * key) * (0.4 + 0.6 * S.sstep(0.05, 0.55, groove)) * (0.55 + 0.45 * occ)
    c = tones("160c0c", "38221f", "7a5244", v * 1.25)
    sheen = S.sstep(0.74, 0.95, key) * S.sstep(0.45, 0.9, groove)
    return S.mix(c, S.hexc("a87a58")[None, :], sheen * 0.45), None


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
    c = tones("6e5e4e", "bcab90", "efe4cc", v + 0.1)
    # the pale banded rim, the crystals going warm toward the eye
    face = S.sstep(0.0, 0.3, Pn[:, 1])
    rim = tones("8c7a68", "dccbb4", "fff4e4", v + 0.1)
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


P_FN = {"head": p_head, "teeth": p_teeth, "torso": p_skin, "arms": p_skin, "hands": p_hands, "legs": p_legs,
        "bandana": p_bandana, "cap": p_hair, "crown": p_sash, "shoulders": p_sash, "vest": p_vest, "wrap": p_wrap, "sash": p_sash, "trousers": p_trousers,
        "wraps": p_wraps, "harness": p_harness, "gear": p_gear, "pouch": p_pouch, "locs": p_locs, "beads": p_beads,
        "crystals": p_crystals, "sash_tails": p_tails, "band_tails": p_band_tails, "geode": p_geode, "iris": p_iris,
        "shard": lambda P, N, o, c, a: p_shard(P, N, o, c, a),
        "bracer_R": lambda P, N, o, c, a: p_rock(P, N, o, c, a, SEEDS_R),
        "bracer_L": lambda P, N, o, c, a: p_rock(P, N, o, c, a, SEEDS_L)}


def p_shard(P, N, occ, cav, a):
    v = lightness(T.key_shade(N), occ, cav, 0.75)
    return tones("3e3128", "85725c", "c9b797", v), None


_rs = np.random.RandomState(7)
HAND_SEEDS = np.stack((np.zeros(9), _rs.uniform(-0.08, 0.08, 9), _rs.uniform(-0.13, 0.04, 9)), 1).astype(np.float32)
ARMS = ("arms", "hands", "bracer_R", "bracer_L")


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
