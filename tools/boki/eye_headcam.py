"""Head renders of a Boki coat for the Meshy eye edit (Blender only renders and reads the mesh; nothing is painted).

    blender -b -P tools/boki/eye_headcam.py -- <id>.glb <outdir> <v0x> <v1x> <z> <size>
The head is picked on 256-px full-body tiles of the coat (ortho, 0.9 x the bounding-box diagonal): `v0x` is its
column in the front view (from +Y), `v1x` its column in the left view (from -X), `z` its row, `size` its height in px.
Writes front.png, left.png, right.png (flat-lit base colour, 1024 px, the coat alone), cams.json (each ortho camera)
and geo.npz (the posed Body triangles, their UVs) for eye_reproject.py. Eyes are often on the sides: a coat's head
bone can be a placeholder, so the head is picked by eye, not from the rig or the face overlay's eye domes."""

import json
import sys

import bpy
import mathutils
import numpy as np

RES = 1024


def coat():
    body = bpy.data.objects["Body"]
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name != "Body":
            o.hide_render = True
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return ev, ev.to_mesh()


def dump_geo(ev, m, path):
    m.calc_loop_triangles()
    w = np.array(ev.matrix_world)
    co = np.zeros(len(m.vertices) * 3)
    m.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ w[:3, :3].T + w[:3, 3]
    uv = np.zeros(len(m.loops) * 2)
    m.uv_layers.active.data.foreach_get("uv", uv)
    n = len(m.loop_triangles)
    vi = np.zeros(n * 3, int)
    li = np.zeros(n * 3, int)
    m.loop_triangles.foreach_get("vertices", vi)
    m.loop_triangles.foreach_get("loops", li)
    np.savez(path, P=co[vi.reshape(-1, 3)], UV=uv.reshape(-1, 2)[li.reshape(-1, 3)])


def main():
    a = sys.argv[sys.argv.index("--") + 1 :]
    src, out = a[0], a[1]
    v0, v1, pz, sz = map(float, a[2:6])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ev, m = coat()
    pts = [ev.matrix_world @ v.co for v in m.vertices]
    lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
    hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
    c, span = (lo + hi) / 2, (hi - lo).length * 0.9
    head = mathutils.Vector(
        (c.x - (v0 / 256 - 0.5) * span, c.y - (v1 / 256 - 0.5) * span, c.z - (pz / 256 - 0.5) * span)
    )
    hs = sz / 256 * span
    s = bpy.context.scene
    s.render.engine = "BLENDER_WORKBENCH"
    s.display.shading.light = "FLAT"
    s.display.shading.color_type = "TEXTURE"
    s.render.resolution_x = s.render.resolution_y = RES
    s.world = bpy.data.worlds.new("w")
    s.world.color = (0.5, 0.5, 0.5)
    s.view_settings.view_transform = "Standard"
    cam = bpy.data.cameras.new("c")
    cam.type = "ORTHO"
    cam.ortho_scale = hs * 1.7
    cam.clip_end = span * 20
    co = bpy.data.objects.new("c", cam)
    s.collection.objects.link(co)
    s.camera = co
    cams = {}
    for name, d in (("front", (0, -1, 0)), ("left", (1, 0, 0)), ("right", (-1, 0, 0))):
        d = mathutils.Vector(d)
        co.location = head - d * span * 3
        co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        s.render.filepath = f"{out}/{name}.png"
        bpy.ops.render.render(write_still=True)
        rows = [list(r) for r in co.matrix_world.to_3x3()]
        cams[name] = {"loc": list(co.location), "R": rows, "scale": cam.ortho_scale, "res": RES, "d": list(d)}
    json.dump({"H": list(head), "hs": hs, "cams": cams}, open(f"{out}/cams.json", "w"), indent=1)
    dump_geo(ev, m, f"{out}/geo.npz")


main()
