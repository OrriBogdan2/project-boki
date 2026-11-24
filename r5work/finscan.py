import bpy,sys,bmesh,mathutils,json
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
out={}
for o in bpy.data.objects:
    if o.type!='MESH': continue
    me=o.data
    print('MESH',o.name,len(me.polygons),'mats',[(m.name,m.blend_method if hasattr(m,'blend_method') else '') for m in me.materials])
    for m in me.materials:
        print(' mat',m.name,'use_backface_culling',m.use_backface_culling,'blend',getattr(m,'surface_render_method',getattr(m,'blend_method','')))
    bm=bmesh.new(); bm.from_mesh(me)
    bnd=[e for e in bm.edges if e.is_boundary]
    nm=[e for e in bm.edges if not e.is_manifold]
    print(' verts',len(bm.verts),'boundary edges',len(bnd),'nonmanifold',len(nm))
    # find head top: highest z cluster; list boundary edge verts with z>0.8*max
    zs=[v.co.z for v in bm.verts]; zmax=max(zs); ymax=max(v.co.y for v in bm.verts)
    print(' bbox z',min(zs),zmax,'y',min(v.co.y for v in bm.verts),ymax)
    import collections
    # bone names for verts
    vgn={g.index:g.name for g in o.vertex_groups}
    def bones(v):
        return sorted([(round(g.weight,2),vgn[g.group]) for g in me.vertices[v.index].groups],reverse=True)[:3]
    cl=[e for e in bnd]
    pts=[(v.co.x,v.co.y,v.co.z) for e in cl for v in e.verts]
    print(' boundary verts sample', len(pts))
    hb=collections.Counter()
    for e in bnd:
        for v in e.verts:
            b=bones(v); hb[b[0][1] if b else 'none']+=1
    print(' boundary by main bone',hb.most_common(12))
    # edge loops of boundary in head region
    head=[e for e in bnd if all(bones(v) and bones(v)[0][1] in ('Head','head_end','Spine02','Neck','HeadTop_End','Spine01') for v in e.verts)]
    print(' head boundary edges',len(head))
    for e in head[:40]:
        print('  ',[tuple(round(c,3) for c in v.co) for v in e.verts],[bones(v)[:2] for v in e.verts])
    # flipped normals: faces whose normal opposes a neighbor face across a manifold edge strongly
    flips=0
    for f in bm.faces:
        for e in f.edges:
            if e.is_manifold:
                g=[x for x in e.link_faces if x!=f][0]
                if f.normal.dot(g.normal)<-0.5: flips+=1;break
    print(' faces with strongly opposing neighbour',flips)
    # degenerate faces
    deg=[f for f in bm.faces if f.calc_area()<1e-10]
    print(' degenerate faces',len(deg))
