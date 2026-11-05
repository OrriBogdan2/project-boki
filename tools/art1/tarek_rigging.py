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
        bone("foot." + sd, "shin." + sd, R.ankle * f, R.ankle * f + S.vec(0, 0.12, -0.04), (0, 0, 1))
        bone("lip." + sd, "head", HC + S.vec(0.062 * sx, 0.1, -0.068), HC + S.vec(0.062 * sx, 0.125, -0.068), (0, 0, 1))
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
          "torso": w_torso, "arms": w_arm, "hands": lambda P: {"hand.R": np.ones(P.shape[0], np.float32)}, "wrap": w_hips, "sash": w_root, "trousers": w_legs,
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
    if slot == "leather":
        t2 = nt.nodes.new("ShaderNodeTexImage")
        t2.image = NRM_IMG
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t2.outputs[0], nm.inputs["Color"])
        nt.links.new(nm.outputs[0], b.inputs["Normal"])
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
    tilt = math.radians(55)
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


def scan_bones(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones

    def bone(nm, parent, head, tail, up):
        e = eb.new(nm)
        e.head, e.tail = Vector(head), Vector(tail)
        e.align_roll(Vector(up))
        e.parent = eb[parent]
        e.use_connect = False

    for sd, sx in (("L", -1.0), ("R", 1.0)):
        f = S.vec(sx, 1, 1)
        bone("foot." + sd, "shin." + sd, R.ankle * f, R.ankle * f + S.vec(0, 0.12, -0.04), (0, 0, 1))
        bone("lip." + sd, "head", HC + S.vec(0.062 * sx, 0.1, -0.068), HC + S.vec(0.062 * sx, 0.125, -0.068), (0, 0, 1))
    bone("jaw", "head", HC + S.vec(0, -0.02, -0.055), HC + S.vec(0, 0.09, -0.125), (0, 0, 1))
    bpy.ops.object.mode_set(mode="OBJECT")


def group_weights(ob):
    names = [g.name for g in ob.vertex_groups]
    W = np.zeros((len(ob.data.vertices), len(names)), np.float32)
    for v in ob.data.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    return names, W


def along_bones(P, pts):
    """The nearest point on a polyline of joints."""
    best = None
    d0 = np.full(P.shape[0], 9e9, np.float32)
    best = np.zeros_like(P)
    for a, b in zip(pts, pts[1:]):
        t = np.clip(T.seg_t(P, a, b), 0, 1)[:, None]
        c = a + (b - a) * t
        d = S.length(P - c)
        m = d < d0
        best[m] = c[m]
        d0[m] = d[m]
    return best


def scan_reshape(ob):
    """The master's balance on the scan: the left arm huge, the right gauntlet slighter; the feet on their own bones."""
    names, W = group_weights(ob)
    ix = {n: i for i, n in enumerate(names)}
    P = verts_np(ob).copy()
    w = lambda *ns: sum(W[:, ix[n]] for n in ns if n in ix)
    f = S.vec(-1, 1, 1)
    wL = np.clip(w("upper_arm.L", "forearm.L", "hand.L"), 0, 1)
    c = along_bones(P, [R.sh * f, R.el * f, R.wr * f])
    P = P + (P - c) * (wL * ARM_L_GROW)[:, None]
    wR = np.clip(w("forearm.R", "hand.R"), 0, 1)
    c = along_bones(P, [R.el, R.wr])
    P = P + (P - c) * (wR * -ARM_R_SHRINK)[:, None]
    ob.data.vertices.foreach_set("co", P.ravel())
    for sd in ("L", "R"):
        g = ob.vertex_groups.new(name="foot." + sd)
        sh = ob.vertex_groups["shin." + sd]
        k = S.sstep(0.15, 0.08, P[:, 2]) * W[:, ix["shin." + sd]]
        for i in np.nonzero(k > 0.01)[0]:
            g.add([int(i)], float(k[i]), "REPLACE")
            sh.add([int(i)], float(W[i, ix["shin." + sd]] - k[i]) + 1e-4, "REPLACE")
    return W, ix


ARM_L_GROW = 0.32
ARM_R_SHRINK = 0.14


def scan_cut_hands(ob, W, ix):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    kill = [bm.verts[i] for i in np.nonzero((W[:, ix["hand.L"]] > 0.35) | (W[:, ix["hand.R"]] > 0.35))[0]]
    log("hands: cut", len(kill), "verts")
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def scan_slots(ob):
    """Stone on the left arm and the right forearm goes to the leather slot, whose emission lights the atlas's hot cracks;
    a hot texel is cut from the atlas over those faces and the chest beside them. Unused slots go."""
    me = ob.data
    names = [m.name for m in me.materials]
    lea = names.index("leather-body")
    names_g = [g.name for g in ob.vertex_groups]
    dom = []
    for v in me.vertices:
        dom.append(names_g[max(v.groups, key=lambda g: g.weight).group] if len(v.groups) else "")
    stone = ("upper_arm.L", "forearm.L", "hand.L", "forearm.R", "hand.R")
    hot = []
    for pl in me.polygons:
        if dom[pl.vertices[0]] in stone:
            pl.material_index = lea
        c = pl.center
        if dom[pl.vertices[0]] in stone or (c.x < 0.0 and c.z > 1.45 and c.y > -0.3):
            hot.append(pl.index)
    tex = next(n.image for n in me.materials[lea].node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = tex.size
    A = np.zeros(w * h * 4, np.float32)
    tex.pixels.foreach_get(A)
    A = A.reshape(h, w, 4)[:, :, :3]
    uv = np.zeros(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    tris = [(pl.loop_indices[0], pl.loop_indices[i], pl.loop_indices[i + 1]) for pi in hot for pl in [me.polygons[pi]] for i in range(1, len(pl.loop_indices) - 1)]
    mask, _, _ = S.rasterize(uv[np.array(tris)], None, w, [np.zeros((len(tris), 3, 1), np.float32)])
    keyed = S.sstep(0.62, 0.8, A[:, :, 0]) * S.sstep(0.3, 0.5, A[:, :, 0] - A[:, :, 2]) * mask
    e = A * keyed[:, :, None]
    im = save_img(e[::2, ::2], "tarek_scan_emit")
    for m in me.materials:
        if m.name in ("leather-body", "skin-body"):
            nt = m.node_tree
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = im
            b = nt.nodes["Principled BSDF"]
            nt.links.new(n.outputs[0], b.inputs["Emission Color"])
            b.inputs["Emission Strength"].default_value = 1.0
    used = set(pl.material_index for pl in me.polygons)
    for i in reversed(range(len(me.materials))):
        if i not in used:
            me.materials.pop(index=i)


def assemble_scan(objs, img, emit):
    arm = bpy.data.objects["Armature"]
    body = bpy.data.objects["Body"]
    body.name = "tarek_body"
    scan_bones(arm)
    W, ix = scan_reshape(body)
    scan_cut_hands(body, W, ix)
    scan_slots(body)
    mats = {"leather": material("leather", img, emit)}
    fists = [o for o in objs if o.name.startswith("fist_")]
    geo, iris, shard = [next(o for o in objs if o.name == n) for n in ("geode", "iris", "shard")]
    for ob in fists:
        ob.data.materials.append(mats["leather"])
        vg = ob.vertex_groups.new(name="hand." + ob.name[-1])
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
        for pl in ob.data.polygons:
            pl.use_smooth = True
    bpy.ops.object.select_all(action="DESELECT")
    for ob in fists:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = fists[0]
    bpy.ops.object.join()
    fm = fists[0]
    fm.name = "tarek_fists"
    fm.modifiers.new("Armature", "ARMATURE").object = arm
    fm.parent = arm
    glow_m = material("glow", img, None)
    global RING_UV
    lu = iris.data.uv_layers.active.data
    RING_UV = lu[len(lu) // 2].uv[:]
    geo.data.materials.append(mats["leather"])
    iris.data.materials.append(glow_m)
    bpy.ops.object.select_all(action="DESELECT")
    geo.select_set(True)
    iris.select_set(True)
    bpy.context.view_layer.objects.active = geo
    bpy.ops.object.join()
    shard.data.materials.append(mats["leather"])
    n_geo, n_shard = K.tris([geo]), K.tris([shard])
    extras = orbits(arm, geo, shard)
    for nm in ("anchor_chest", "anchor_head_top"):
        extras.append(bpy.data.objects[nm])
    for sd, sx in (("L", -1.0), ("R", 1.0)):
        f = S.vec(sx, 1, 1)
        extras.append(K.anchor(arm, "forearm." + sd, "anchor_gauntlet_" + sd, ((R.el + R.wr) * 0.5) * f + S.vec(0.1 * sx, 0.0, 0.0)))
        extras.append(K.anchor(arm, "hand." + sd, "anchor_fist_" + sd, (R.wr + S.vec(0, 0, -0.13)) * f))
    extras.append(K.anchor(arm, "hand.R", "anchor_wrist_R", R.wr))
    extras.append(K.anchor(arm, "hand.R", "weapon_muzzle", R.wr + S.vec(0, 0, -0.17)))
    extras += ground_rings(arm, glow_m, iris)
    log("tris total", K.tris([body, fm]) + 3 * n_geo + 5 * n_shard, "materials", len(body.data.materials))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tarek.blend"))
