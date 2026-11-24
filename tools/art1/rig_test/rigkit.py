import bpy, math, numpy as np, mathutils


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and len(o.vertex_groups) > 0]
    body = max(meshes, key=lambda o: len(o.data.vertices))
    return arm, body, meshes


def pose(arm, clip, frame):
    ad = arm.animation_data or arm.animation_data_create()
    act = bpy.data.actions[clip]
    ad.action = act
    try:
        ad.action_slot = act.slots[0]
    except Exception:
        pass
    bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()


def evalverts(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ob = o.evaluated_get(dg)
    me = ob.to_mesh()
    P = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    M = np.array(o.matrix_world)
    P = P @ M[:3, :3].T + M[:3, 3]
    ob.to_mesh_clear()
    return P


def edges(o):
    me = o.data
    E = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", E)
    return E.reshape(-1, 2)


def tris(o):
    me = o.data
    me.calc_loop_triangles()
    T = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", T)
    return T.reshape(-1, 3)


def get_weights(o):
    n = len(o.data.vertices)
    names = [g.name for g in o.vertex_groups]
    W = np.zeros((n, len(names)))
    for v in o.data.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    return names, W


def set_weights(o, names, W, thr=1e-4):
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)
    gs = [o.vertex_groups.new(name=n) for n in names]
    for i in range(W.shape[0]):
        for j in np.nonzero(W[i] > thr)[0]:
            gs[j].add([i], float(W[i, j]), "REPLACE")


def clip_frames(arm, clip, n=6):
    a = bpy.data.actions[clip]
    f0, f1 = a.frame_range
    return sorted(set(int(round(x)) for x in np.linspace(f0, f1, n)))


def setup_render(px=640):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = px
    sc.render.resolution_y = px
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_object_outline = False
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    w.color = (0.55, 0.62, 0.55)
    sc.world = w
    sc.view_settings.view_transform = "Standard"
    cam = bpy.data.cameras.new("c")
    co = bpy.data.objects.new("c", cam)
    bpy.context.scene.collection.objects.link(co)
    sc.camera = co
    for o in bpy.data.objects:
        if o.type == "MESH" and (o.name.startswith("ground") or o.name.startswith("Icosphere")):
            o.hide_render = True
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        t = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name != "v95b"]
        if t:
            m.node_tree.nodes.active = t[0]
    return co


def aim(co, pos, target, lens=None, ortho=None):
    co.location = mathutils.Vector(pos)
    d = mathutils.Vector(target) - co.location
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if ortho:
        co.data.type = "ORTHO"
        co.data.ortho_scale = ortho
    else:
        co.data.type = "PERSP"
        co.data.angle = math.radians(lens or 30)


def shot(co, path, pos, target, **k):
    aim(co, pos, target, **k)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# views: (name, pos, target, fov/ortho) in Blender coords (front = -Y, up = Z). h = height scale
def views(H):
    D = 10 * H
    return {
        "game": ((0, 0.41 * D, 0.4 * H + 0.91 * D), (0, 0, 0.4 * H), dict(lens=8.6)),
        "eye": ((1.1 * H, 2.3 * H, 0.55 * H), (0, 0, 0.5 * H), dict(lens=30)),
        "knee": ((0.8 * H, 1.4 * H, 0.25 * H), (0, 0, 0.36 * H), dict(lens=40)),
        "crotch": ((0.25 * H, 1.0 * H, 0.28 * H), (0, 0, 0.3 * H), dict(lens=30)),
        "tailside": ((1.0 * H, -0.5 * H, 0.5 * H), (0, -0.12 * H, 0.48 * H), dict(lens=16)),
        "back": ((-1.0 * H, -2.2 * H, 0.55 * H), (0, 0, 0.5 * H), dict(lens=30)),
    }


def stretch_metrics(arm, body, clips=None, nf=6, names=None):
    """per clip: worst edge stretch (posed/rest length), share of edges >2x, >3x; also worst thigh-L/R cross-triangle area ratio"""
    E = edges(body)
    T = tris(body)
    pose(arm, "idle", 0)
    # rest = bind pose: evaluate with no action
    arm.animation_data.action = None
    bpy.context.view_layer.update()
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    P0 = evalverts(body)
    arm.data.pose_position = "POSE"
    L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1) + 1e-9
    A0 = np.linalg.norm(np.cross(P0[T[:, 1]] - P0[T[:, 0]], P0[T[:, 2]] - P0[T[:, 0]]), axis=1) / 2 + 1e-12
    hz = arm.data.bones["thigh.L"].head_local[2]
    ax = abs(arm.data.bones["upper_arm.L"].head_local[0])
    lowv = (P0[:, 2] < hz + 0.02) & (np.abs(P0[:, 0]) < 0.85 * ax)
    lowe = lowv[E[:, 0]] & lowv[E[:, 1]]
    lowt = lowv[T[:, 0]] & lowv[T[:, 1]] & lowv[T[:, 2]]
    res = {}
    clips = clips or [a.name for a in bpy.data.actions]
    for c in clips:
        worst = 0
        p2 = 0
        p3 = 0
        wa = 0
        n = 0
        lw = 0
        lp = 0
        la = 0
        for f in clip_frames(arm, c, nf):
            pose(arm, c, f)
            P = evalverts(body)
            r = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1) / L0
            ar = np.linalg.norm(np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]]), axis=1) / 2 / A0
            lw = max(lw, float(np.percentile(r[lowe], 99.9)))
            lp += float((r[lowe] > 2).mean())
            la = max(la, float(np.percentile(ar[lowt], 99.9)))
            worst = max(worst, float(np.percentile(r, 99.99)))
            p2 += float((r > 2).mean())
            p3 += float((r > 3).mean())
            wa = max(wa, float(np.percentile(ar, 99.99)))
            n += 1
        res[c] = (worst, 100 * p2 / n, 100 * p3 / n, wa, lw, 100 * lp / n, la)
    return res


def web_metric(arm, body, clips):
    """midline-crossing triangles below the hips (rest): worst posed/rest area and the total posed area / rest area, per clip (+worst frame)"""
    T = tris(body)
    arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    P0 = evalverts(body)
    arm.data.pose_position = "POSE"
    hz = arm.data.bones["thigh.L"].head_local[2]
    xs = P0[T][:, :, 0]
    zs = P0[T][:, :, 2]
    cross = (xs.min(1) < -0.005) & (xs.max(1) > 0.005) & (zs.max(1) < hz + 0.02)
    Tc = T[cross]
    A0 = np.linalg.norm(np.cross(P0[Tc[:, 1]] - P0[Tc[:, 0]], P0[Tc[:, 2]] - P0[Tc[:, 0]]), axis=1) / 2 + 1e-9
    out = {}
    for c in clips:
        if c not in bpy.data.actions:
            continue
        f0, f1 = bpy.data.actions[c].frame_range
        best = (0, 0, 0)
        for f in range(int(f0), int(f1) + 1):
            pose(arm, c, f)
            P = evalverts(body)
            A = np.linalg.norm(np.cross(P[Tc[:, 1]] - P[Tc[:, 0]], P[Tc[:, 2]] - P[Tc[:, 0]]), axis=1) / 2
            tot = float(A.sum() / A0.sum())
            mx = float(np.percentile(A / A0, 99))
            if tot > best[0]:
                best = (tot, mx, f)
        out[c] = best
    return out, int(cross.sum())


def tail_gap(arm, body, clips, key="tail", nf=8):
    names, W = get_weights(body)
    dom = W.argmax(1)
    istail = np.array([names[d] == "tail" or names[d].startswith("spring_scarftail_tail") for d in dom])
    arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    P0 = evalverts(body)
    arm.data.pose_position = "POSE"
    tz = P0[istail]
    root = istail & (P0[:, 2] >= np.percentile(tz[:, 2], 85))  # the tail's top end (highest 15%)
    body_ok = (
        ~istail
        & (np.abs(P0[:, 0]) < 0.3)
        & (P0[:, 2] > 0.6)
        & (P0[:, 2] < 1.5)
        & (
            np.array(
                [
                    not (n.startswith(("upper_arm", "forearm", "hand", "fingers", "thumb", "head", "spring")))
                    for n in [names[d] for d in dom]
                ]
            )
        )
    )
    from mathutils import kdtree

    out = {"tail_verts": int(istail.sum()), "root_verts": int(root.sum()), "body_ref": int(body_ok.sum())}

    def gap(P):
        kd = kdtree.KDTree(int(body_ok.sum()))
        for k, i in enumerate(np.nonzero(body_ok)[0]):
            kd.insert(P[i], k)
        kd.balance()
        return float(np.median([kd.find(tuple(p))[2] for p in P[root][:: max(1, int(root.sum()) // 60)]]))

    out["rest"] = gap(P0)
    res = {}
    for c in clips:
        if c not in bpy.data.actions:
            continue
        g = []
        for f in clip_frames(arm, c, nf):
            pose(arm, c, f)
            g.append(gap(evalverts(body)))
        res[c] = (float(np.mean(g)), float(np.max(g)))
    out["clips"] = res
    return out
