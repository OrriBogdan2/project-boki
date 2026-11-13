"""A quick look at a stage .blend: four shaded ortho views (front, side, back, top) of any objects, plus optional close-ups.

  blender -b --factory-startup --python tools/art1/shapes_view.py -- BLEND OUT_PREFIX [options]
  python3 tools/art1/shapes_view.py --help

Replaces the per-hero copies claire_shapes, ryzz_shapes and sable_shapes. Writes OUT_PREFIX_front/side/back/top.png
and OUT_PREFIX_<name>.png for each --closeup.
"""
import argparse
import os
import sys

VIEWS = (("front", (0, 5, 0)), ("side", (5, 0, 0)), ("back", (0, -5, 0)), ("top", (0.001, -2.2, 5)))


def parse(argv):
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("blend", help="the .blend to open")
    p.add_argument("out_prefix", help="output path prefix; views are written as PREFIX_<view>.png")
    p.add_argument("--hide", default="", help="comma list of object names to hide from the render")
    p.add_argument("--scale", type=float, default=2.3, help="ortho scale of the four main views (default 2.3)")
    p.add_argument("--cz", type=float, default=1.0, help="height the main views look at (default 1.0)")
    p.add_argument("--res", default="520x800", help="WxH in px of the main views (default 520x800)")
    p.add_argument("--atlas", default="", help="reload images named PREFIX* from atlas.png next to the .blend (stale atlas after a repaint)")
    p.add_argument("--closeup", action="append", default=[], metavar="NAME:CAM:TARGET:SCALE:PX",
                   help="extra close-up, e.g. head:0,3,1.6:0,0,1.6:0.46:620 (CAM and TARGET are x,y,z; repeatable)")
    return p.parse_args(argv)


def look_at(cam, target):
    from mathutils import Vector
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(sc, path):
    import bpy
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main(argv):
    args = parse(argv)
    import bpy
    from mathutils import Vector
    bpy.ops.wm.open_mainfile(filepath=args.blend)
    for name in filter(None, args.hide.split(",")):
        if name in bpy.data.objects:
            bpy.data.objects[name].hide_render = True
    if args.atlas:
        for img in bpy.data.images:
            if img.name.startswith(args.atlas):
                img.filepath = os.path.join(os.path.dirname(args.blend), "atlas.png")
                img.reload()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 6
    sc.render.resolution_x, sc.render.resolution_y = (int(v) for v in args.res.split("x"))
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.6, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = args.scale
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 2.0
    sun.rotation_euler = (0.9, 0.2, 0.3)
    centre = Vector((0, 0, args.cz))
    for name, offset in VIEWS:
        cam.location = centre + Vector(offset)
        look_at(cam, centre)
        render(sc, "%s_%s.png" % (args.out_prefix, name))
    for spec in args.closeup:
        name, cam_pos, target, scale, px = spec.split(":")
        cam.location = Vector(float(v) for v in cam_pos.split(","))
        look_at(cam, [float(v) for v in target.split(",")])
        cam.data.ortho_scale = float(scale)
        sc.render.resolution_x = sc.render.resolution_y = int(px)
        render(sc, "%s_%s.png" % (args.out_prefix, name))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
