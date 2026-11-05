# Tarek's armature, weights and assembly (exec'd by tarek_build.py).
SLOT = {"head": "skin", "teeth": "skin", "torso": "skin", "arms": "skin", "hands": "skin", "legs": "skin",
        "bandana": "cloth", "band_tails": "cloth", "wrap": "cloth", "sash": "cloth-accent", "skirt": "cloth-accent",
        "sash_tails": "cloth-accent", "trousers": "cloth", "wraps": "cloth", "stone": "leather", "gauntlet": "leather",
        "prayer": "leather", "beads": "metal", "cap": "hair", "locs": "hair"}
FX = float(R.kn[0])


def add_bones(arm):
    """On the contract armature (warden_kit.build_armature): the feet, the fingers, the jaw and the mouth's corners
    (WardenGlb.EXTRA dolm), and the spring chains of the locs, the sash's tails and the bandana's tails."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones

    def bone(nm, parent, head, tail, up=None):
        e = eb.new(nm)
        e.head = Vector(head)
        e.tail = Vector(tail)
        if up is not None:
            e.align_roll(Vector(up))
        e.parent = eb[parent]
        e.use_connect = False
        return e

    for sd, sx in (("L", -1.0), ("R", 1.0)):
        f = S.vec(sx, 1, 1)
        wr = R.wr * f
        K_ = S.vec(0, 0, T.KNUCKLE_Z) * T.HAND_K
        bone("foot." + sd, "shin." + sd, R.ankle * f, R.ankle * f + S.vec(0, 0.12, -0.04), (0, 0, 1))
        bone("lip." + sd, "head", HC + S.vec(0.062 * sx, 0.1, -0.068), HC + S.vec(0.062 * sx, 0.125, -0.068), (0, 0, 1))
        if sd == "R":
            continue        # (his stone fist never opens)
        bone("fingers." + sd, "hand." + sd, wr + K_ * f, wr + (K_ + S.vec(-0.024, 0, -0.054)) * f, (sx, 0, 0))
        bone("fingers2." + sd, "fingers." + sd, wr + (K_ + S.vec(-0.024, 0, -0.054)) * f, wr + (K_ + S.vec(-0.07, 0, -0.11)) * f, (sx, 0, 0))
        th = T.THUMB * T.HAND_K
        bone("thumb." + sd, "hand." + sd, wr + th[0] * f, wr + th[1] * f, (sx, 0, 0))
        bone("thumb2." + sd, "thumb." + sd, wr + th[1] * f, wr + th[3] * f, (sx, 0, 0))
    bone("jaw", "head", HC + S.vec(0, -0.02, -0.055), HC + S.vec(0, 0.09, -0.125), (0, 0, 1))
    for nm, pts in T.CHAINS.items():
        chain(bone, "spring_loc%s_" % nm, "head", np.array(pts, np.float32) + HC)
    for j, (nm, pts) in enumerate(SASH_TAILS.items()):
        chain(bone, "spring_%s_" % nm, "hips", T.smooth_path(np.array(pts, np.float32) + S.vec(0, 0, float(R.waist[2]) + 0.07), 4))
    for j, (nm, pts) in enumerate(BAND_TAILS.items()):
        chain(bone, "spring_%s_" % nm, "head", T.smooth_path(np.array(pts, np.float32) + HC, 3))
    z0 = float(R.waist[2])
    chain(bone, "spring_pb_", "hips", np.array(((0.03, 0.2, z0 + 0.03), (0.15, 0.22, z0 - 0.13), (0.27, 0.16, z0 - 0.27)), np.float32))
    bpy.ops.object.mode_set(mode="OBJECT")


def chain(bone, pre, parent, pts):
    for i in range(len(pts)):
        tail = pts[i + 1] if i + 1 < len(pts) else pts[i] + (pts[i] - pts[i - 1]) * 0.5
        bone(pre + str(i), parent if i == 0 else pre + str(i - 1), pts[i], tail)


def smooth(a, b, x):
    return S.sstep(a, b, x)


def sides(P):
    return ("L", P[:, 0] < 0), ("R", P[:, 0] >= 0)


def w_arm(P):
    z = P[:, 2]
    fore = smooth(R.el[2] + 0.05, R.el[2] - 0.05, z)
    hips = smooth(R.sh[2] - 0.02, R.sh[2] + 0.07, z) * smooth(R.sh[0] + 0.05, R.sh[0] - 0.06, np.abs(P[:, 0])) * 0.8
    out = {"hips": hips}
    for sd, m in sides(P):
        out["forearm." + sd] = fore * m
        out["upper_arm." + sd] = (1 - fore) * (1 - hips) * m
    return out


def w_stone(P):
    """Each slab rides one bone whole: stone doesn't bend, the cracks open instead."""
    idx, _, _ = S.voronoi(mx(P), SEEDS_A)
    sz = SEEDS_A[idx, 2]
    sx = SEEDS_A[idx, 0]
    chest = (sx < R.sh[0] - 0.05) & (sz > R.sh[2] - 0.22)
    fore = sz <= R.el[2] + 0.03
    hand_ = sz <= R.wr[2] - 0.02
    return {"hips": chest * 1.0, "upper_arm.L": (~chest & ~fore) * 1.0, "forearm.L": (~chest & fore & ~hand_) * 1.0, "hand.L": (~chest & hand_) * 1.0}


def w_gauntlet(P):
    idx, _, _ = S.voronoi(P, SEEDS_G)
    hand_ = SEEDS_G[idx, 2] <= R.wr[2] - 0.02
    return {"forearm.R": (~hand_) * 1.0, "hand.R": hand_ * 1.0}


def w_skirt(P):
    z = P[:, 2]
    leg = smooth(R.waist[2] - 0.02, R.waist[2] - 0.32, z) * 0.75
    out = {"root": 1 - leg}
    for sd, m in sides(P):
        out["thigh." + sd] = leg * m
    return out


def w_prayer(P, a):
    strand = a[:, 2] == 11
    d = a[:, 0]
    u = np.clip(d / 0.34, 0.0, 1.0)
    root = smooth(0.08, 0.0, d) * strand
    return {"hips": ((~strand) * 1.0 + root).astype(np.float32), "spring_pb_0": (strand * (1 - root) * (1 - u)).astype(np.float32), "spring_pb_1": (strand * (1 - root) * u).astype(np.float32)}


def w_hand(P):
    Q = (T.fold_x(P) - R.wr) / T.HAND_K
    z = Q[:, 2]
    kz = T.KNUCKLE_Z
    f1 = smooth(kz + 0.012, kz - 0.012, z)
    f2 = smooth(kz - 0.036, kz - 0.058, z)
    d_t = S.polyline(Q, list(T.THUMB), 0.0)
    d_i = S.polyline(Q, T.finger_pts(T.FINGERS[0][0], T.FINGERS[0][1]), 0.0)
    th = (d_t < d_i - 0.002) & (d_t < 0.036) & (Q[:, 1] > 0.05)
    tt = T.seg_t(Q, T.THUMB[0], T.THUMB[3])
    t2 = smooth(0.34, 0.46, tt)
    fore = smooth(-0.015, 0.02, z)
    out = {}
    for sd, m in sides(P):
        m = m.astype(np.float32)
        out["forearm." + sd] = fore * m
        out["fingers." + sd] = f1 * (1 - f2) * (~th) * m
        out["fingers2." + sd] = f2 * (~th) * m
        out["thumb." + sd] = (1 - t2) * th * m
        out["thumb2." + sd] = t2 * th * m
        out["hand." + sd] = (1 - fore) * (1 - f1 * (~th)) * (~th) * m
    return out


def w_head(P):
    q = P - HC
    neck = smooth(-0.1, -0.16, q[:, 2])
    # the lower face rides the jaw; the corners of the mouth ride their own bones
    xs, ys, zs = T.mouth_arc()
    line = -0.084 + 4.4 * q[:, 0] ** 2
    below = smooth(line + 0.003, line - 0.008, q[:, 2]) * smooth(-0.05, 0.02, q[:, 1]) * smooth(-0.175, -0.13, q[:, 2])
    side = smooth(0.098, 0.07, np.abs(q[:, 0]))
    jaw = below * side * (1 - neck)
    out = {"hips": neck, "jaw": jaw}
    rest = 1 - neck
    lipw = 0
    for sd, sx in (("L", -1.0), ("R", 1.0)):
        d = S.length(q - S.vec(0.066 * sx, 0.098, -0.07))
        w = smooth(0.042, 0.008, d) * (1 - neck)
        out["lip." + sd] = w * 0.9
        lipw = lipw + w * 0.9
    out["jaw"] = jaw * (1 - lipw)
    out["head"] = np.maximum(rest - out["jaw"] - lipw, 0.0)
    return out


def w_torso(P):
    z = P[:, 2]
    head = smooth(R.neck[2] - 0.05, R.neck[2] + 0.04, z)
    root = smooth(R.waist[2] + 0.13, R.waist[2] + 0.02, z) * 0.7
    sh = smooth(R.sh[0] - 0.08, R.sh[0] + 0.02, np.abs(P[:, 0])) * smooth(R.sh[2] - 0.2, R.sh[2] - 0.08, z)
    out = {"head": head, "root": root}
    for sd, m in sides(P):
        out["upper_arm." + sd] = sh * m * 0.8
    out["hips"] = np.maximum(1 - head - root - sh * 0.8, 0.0)
    return out


def w_hips(P):
    return {"hips": np.ones(P.shape[0], np.float32)}


def w_root(P):
    z = P[:, 2]
    r = smooth(R.waist[2] + 0.14, R.waist[2] + 0.03, z)
    return {"root": r, "hips": 1 - r}


def w_legs(P, foot=True):
    z = P[:, 2]
    hip = smooth(R.hip[2] - 0.09, R.hip[2] - 0.2, z)         # 1: in the leg
    kn = smooth(R.kn[2] + 0.075, R.kn[2] - 0.075, z)
    ft = smooth(0.14, 0.075, z) if foot else z * 0
    top = 1 - hip
    rw = smooth(R.waist[2] + 0.1, R.waist[2] + 0.0, z)
    out = {"root": top * rw * 0.8 + top * 0.2, "hips": top * (1 - rw) * 0.8}
    for sd, m in sides(P):
        m = m.astype(np.float32)
        out["thigh." + sd] = hip * (1 - kn) * m
        out["shin." + sd] = hip * kn * (1 - ft) * m
        out["foot." + sd] = hip * kn * ft * m
    return out




def w_swept(nm, P, a):
    d = a[:, 0]
    ci = a[:, 2].astype(int)
    out = {}
    if nm in ("locs", "beads", "crystals"):
        names = CHAIN_NAMES
        roots = "head"
        lens = {c: float(np.linalg.norm(np.diff(np.array(T.CHAINS[c]), axis=0), axis=1).sum()) for c in names}
        offs = {c: 0.1 for c in names}
    else:
        names = {7: "sa", 8: "sb", 9: "ba", 10: "bb"}
        roots = "hips" if nm == "sash_tails" else "head"
    root_w = np.zeros(P.shape[0], np.float32)
    uniq = np.unique(ci)
    for c in uniq:
        m = ci == c
        if nm in ("locs", "beads", "crystals"):
            cn = names[c]
            pre = "spring_loc%s_" % cn
            cnt = len(T.CHAINS[cn])
            L = lens[cn]
            start = 0.1
        else:
            cn = names[c]
            pre = "spring_%s_" % cn
            cnt = 4 if cn in SASH_TAILS else 3
            L = float(d[m].max()) * 1.0
            start = 0.02
        u = np.clip((d[m] - start) / max(L, 0.05), 0.0, 1.0) * (cnt - 2) if cnt > 2 else np.zeros(m.sum())
        lo = np.clip(u.astype(int), 0, cnt - 2)
        t = u - lo
        rw = smooth(start + 0.06, start - 0.03, d[m])
        root_w[m] = rw
        for b in range(cnt - 1):
            w = np.zeros(P.shape[0], np.float32)
            w[m] = ((lo == b) * (1 - t) + (lo + 1 == b) * t) * (1 - rw)
            out[pre + str(b)] = out.get(pre + str(b), 0) + w
    out[roots] = root_w
    return out


WEIGHT = {"head": w_head, "teeth": lambda P: {"head": np.ones(P.shape[0], np.float32)},
          "bandana": lambda P: {"head": np.ones(P.shape[0], np.float32)}, "cap": lambda P: {"head": np.ones(P.shape[0], np.float32)},
          "stone": w_stone, "gauntlet": w_gauntlet, "skirt": w_skirt,
          "torso": w_torso, "arms": w_arm, "hands": w_hand, "wrap": w_hips, "sash": w_root, "trousers": w_legs,
          "legs": w_legs, "wraps": w_legs,
          }


def set_weights(ob):
    P = verts_np(ob)
    if ob.name == "prayer":
        w = w_prayer(P, ATTR[ob.name])
    elif ob.get("swept"):
        w = w_swept(ob.name, P, ATTR[ob.name])
    else:
        w = WEIGHT[ob.name](P)
    names = list(w)
    M = np.stack([np.asarray(w[n], np.float32) * np.ones(P.shape[0], np.float32) for n in names], 1)
    M = np.maximum(M, 0.0)
    tot = M.sum(1)
    if (tot <= 1e-5).any():
        log("WARN unweighted verts in", ob.name, int((tot <= 1e-5).sum()))
        M[tot <= 1e-5, 0] = 1.0
        tot = M.sum(1)
    M /= tot[:, None]
    for j, n in enumerate(names):
        vg = ob.vertex_groups.new(name=n)
        nz = np.nonzero(M[:, j] > 0.004)[0]
        for i in nz:
            vg.add([int(i)], float(M[i, j]), "REPLACE")


def material(slot, img, emit):
    m = bpy.data.materials.new("%s-tarek" % slot if "-" not in slot else slot)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 1.0
    if emit is not None:
        e = nt.nodes.new("ShaderNodeTexImage")
        e.image = emit
        nt.links.new(e.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 1.0
    return m


def assemble(objs, img, emit):
    arm = K.build_armature(RIG)
    add_bones(arm)
    arm.name = "Armature"
    # (beads and crystals are their own mesh: speckle at the match camera, drawn close up only, warden_look far_hide)
    small = [o for o in objs if o.name in ("beads", "crystals")]
    body = [o for o in objs if o.name not in ("geode", "iris", "shard", "beads", "crystals")]
    geo, iris, shard = [next(o for o in objs if o.name == n) for n in ("geode", "iris", "shard")]
    mats = {}
    for ob in body:
        slot = SLOT[ob.name]
        if slot not in mats:
            mats[slot] = material(slot, img, emit if slot in ("leather", "skin") else None)
        ob.data.materials.append(mats[slot])
        set_weights(ob)
        ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons)) if ob.name not in ROCK else None
    for ob in small:
        slot = SLOT[ob.name]
        if slot not in mats:
            mats[slot] = material(slot, img, None)
        ob.data.materials.append(mats[slot])
        set_weights(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in small:
        ob.select_set(True)
    beads = small[0]
    beads.name = "tarek_beads"
    beads.data.name = "tarek_beads"
    log("beads mesh fixed:", beads.data.validate(verbose=True))
    beads.modifiers.new("Armature", "ARMATURE").object = arm
    beads.parent = arm
    bpy.ops.object.select_all(action="DESELECT")
    for ob in body:
        ob.select_set(True)
    main_ob = next(o for o in body if o.name == "head")
    bpy.context.view_layer.objects.active = main_ob
    bpy.ops.object.join()
    main_ob.name = "tarek_body"
    log("mesh fixed:", main_ob.data.validate(verbose=True))
    main_ob.data.name = "tarek_body"
    mod = main_ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    main_ob.parent = arm
    # the stones: three instances on an orbit round his head
    global RING_UV
    lu = iris.data.uv_layers.active.data
    RING_UV = lu[len(lu) // 2].uv[:]
    rock_m = mats["leather"]
    glow_m = material("glow", img, None)
    geo.data.materials.append(rock_m)
    iris.data.materials.append(glow_m)
    bpy.ops.object.select_all(action="DESELECT")
    geo.select_set(True)
    iris.select_set(True)
    bpy.context.view_layer.objects.active = geo
    bpy.ops.object.join()
    shard.data.materials.append(rock_m)
    log("stone mesh fixed:", geo.data.validate(verbose=True), shard.data.validate(verbose=True))
    n_geo, n_shard = K.tris([geo]), K.tris([shard])
    extras = orbits(arm, geo, shard)
    # anchors the kit's FX read (76b): the fists are the weapon, so the punches and throws leave them
    extras.append(K.anchor(arm, "head", "anchor_head_top", HC + S.vec(0, 0, 0.2)))
    extras.append(K.anchor(arm, "hips", "anchor_chest", S.vec(0, 0.12, R.sh[2] - 0.06)))
    for sd, sx in (("L", -1.0), ("R", 1.0)):
        f = S.vec(sx, 1, 1)
        extras.append(K.anchor(arm, "forearm." + sd, "anchor_gauntlet_" + sd, ((R.el + R.wr) * 0.5) * f + S.vec(0.1 * sx, 0.0, 0.0)))
        extras.append(K.anchor(arm, "hand." + sd, "anchor_fist_" + sd, (R.wr + S.vec(0, 0, -0.13)) * f))
    # (the Gun node, which kit FX read, rides the right fist: WardenClips "blade")
    extras.append(K.anchor(arm, "hand.R", "anchor_wrist_R", R.wr))
    extras.append(K.anchor(arm, "hand.R", "weapon_muzzle", R.wr + S.vec(0, 0, -0.17)))
    extras += ground_rings(arm, glow_m, iris)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tarek.blend"))
    log("tris total", K.tris([main_ob, beads]) + 3 * n_geo + 5 * n_shard)
    K.export(os.path.join(OUT, "tarek.glb"), [arm, main_ob, beads] + extras, image_format="JPEG")


def ground_rings(arm, mat, uv_from):
    """The glowing rings under his feet: two broken arcs on the ground (they travel with him)."""
    bm = bmesh.new()
    for rad, w, arcs in ((0.62, 0.016, ((0.1, 2.9), (3.4, 5.9))), (0.46, 0.013, ((1.2, 3.9), (4.5, 6.9)))):
        for a0, a1 in arcs:
            n = 12
            vs = []
            for i in range(n + 1):
                a = a0 + (a1 - a0) * i / n
                t = 1.0 - abs(2.0 * i / n - 1.0) ** 3
                for r in (rad - w * t, rad + w * t):
                    vs.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0.03)))
            for i in range(n):
                bm.faces.new((vs[i * 2], vs[i * 2 + 1], vs[i * 2 + 3], vs[i * 2 + 2]))
    me = bpy.data.meshes.new("ground_rings")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    lay = me.uv_layers.new(name="UVMap")
    for d in lay.data:
        d.uv = RING_UV       # (one amber texel of the iris)
    # (on an orbit_ empty on the armature, not a bone: they keep to the ground and turn slowly, WardenGlb.Orbits)
    e = bpy.data.objects.new("orbit_ground", None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    ob = bpy.data.objects.new("ground_rings", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = e
    return [e, ob]


STONES = ({"angle": 300, "height": 0.2, "k": 1.0}, {"angle": 60, "height": 0.27, "k": 1.05}, {"angle": 180, "height": 0.15, "k": 0.92})


def orbits(arm, geo, shard):
    c = HC + S.vec(0, 0, 0.0)
    e = bpy.data.objects.new("orbit_stones", None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = "head"
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(Vector(c))
    bpy.context.view_layer.update()
    out = [e]
    tilt = math.radians(50)
    for i, it in enumerate(STONES):
        a = math.radians(it["angle"])
        d = Vector((-math.sin(a), math.cos(a), 0))
        o = bpy.data.objects.new("stone_%d" % i, geo.data)
        bpy.context.scene.collection.objects.link(o)
        o.parent = e
        p = Vector(c) + d * 0.45 + Vector((0, 0, it["height"]))
        # (its face out and tipped up toward the high match camera)
        M = Matrix.Rotation(-a, 4, "Z") if False else Matrix.Rotation(a, 4, "Z")
        M = M @ Matrix.Rotation(tilt, 4, "X")
        o.matrix_world = Matrix.Translation(p) @ M @ Matrix.Scale(it["k"], 4)
        an = bpy.data.objects.new("anchor_stones_%d" % i, None)
        bpy.context.scene.collection.objects.link(an)
        an.parent = o
        an.location = (0, 0.06, 0)
        out += [o, an]
    bpy.data.objects.remove(geo)
    s = bpy.data.objects.new("orbit_shards", None)
    bpy.context.scene.collection.objects.link(s)
    s.parent = arm
    s.parent_type = "BONE"
    s.parent_bone = "hand.R"
    bpy.context.view_layer.update()
    cs = R.wr + S.vec(0, 0, -0.1)
    s.matrix_world = Matrix.Translation(Vector(cs))
    out.append(s)
    for i in range(5):
        a = 2 * math.pi * i / 5
        o = bpy.data.objects.new("shard_%d" % i, shard.data)
        bpy.context.scene.collection.objects.link(o)
        o.parent = s
        o.matrix_world = Matrix.Translation(Vector(cs) + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, (i % 3 - 1) * 0.05))) @ Matrix.Rotation(a * 1.7, 4, "X")
        out.append(o)
    bpy.data.objects.remove(shard)
    return out
