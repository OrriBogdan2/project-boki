"""Drops every mesh part (primitive) on the named materials from a .glb, with the materials, textures, images, accessors
and buffer bytes only they used. A mesh left with no part goes with its node. Nothing else changes: the bytes of every
kept part, clip, skin and image are copied as they are (no Blender, no re-export).
Use: a v95 master's own copy of a prop that the game .glb already carries skinned (Kael's two master swords, painted
by "v95c", sat in the body mesh beside the game's skinned sword: three swords, the master's two smeared over the leg
bones).
Run: python3 tools/art1/glb_drop_mats.py in.glb out.glb <material>[,<material>...]
A name ending in * is a prefix, a name starting with * a suffix ("*-v95c")."""
import sys

from glb_add_clips import prune, read, write


def named(name, pats):
    for p in pats:
        if p == name or (p.endswith("*") and name.startswith(p[:-1])) or (p.startswith("*") and name.endswith(p[1:])):
            return True
    return False


def tex_infos(o, out):
    if isinstance(o, dict):
        if isinstance(o.get("index"), int):
            out.append((o, "index"))
        for v in o.values():
            tex_infos(v, out)
    elif isinstance(o, list):
        for v in o:
            tex_infos(v, out)
    return out


def compact(j, key, refs):
    """Keeps the j[key] entries the (dict, key) refs name, in order, and points the refs at their new places."""
    keep = sorted({d[k] for d, k in refs})
    at = {old: new for new, old in enumerate(keep)}
    for d, k in refs:
        d[k] = at[d[k]]
    if key in j:
        j[key] = [j[key][i] for i in keep]
        if not j[key]:
            del j[key]


def drop(j, pats):
    mats = j.get("materials", [])
    gone = {i for i, m in enumerate(mats) if named(m.get("name", ""), pats)}
    tris = 0
    for m in j["meshes"]:
        for p in m["primitives"]:
            if p.get("material") in gone:
                tris += j["accessors"][p["indices"]]["count"] // 3
        m["primitives"] = [p for p in m["primitives"] if p.get("material") not in gone]
    empty = {i for i, m in enumerate(j["meshes"]) if not m["primitives"]}
    dead = {i for i, n in enumerate(j["nodes"]) if n.get("mesh") in empty}
    for i in dead:
        assert not j["nodes"][i].get("children"), "a dropped mesh's node has children"
    held = [(s, "skeleton") for s in j.get("skins", []) if "skeleton" in s]
    held += [(c["target"], "node") for a in j.get("animations", []) for c in a["channels"] if "node" in c["target"]]
    assert not dead & ({d[k] for d, k in held} | {x for s in j.get("skins", []) for x in s["joints"]}), "node in use"
    keep = [i for i in range(len(j["nodes"])) if i not in dead]
    at = {old: new for new, old in enumerate(keep)}
    j["nodes"] = [j["nodes"][i] for i in keep]
    for d, k in held:
        d[k] = at[d[k]]
    for o in j["nodes"] + j.get("scenes", []) + j.get("skins", []):
        for k in ("children", "nodes", "joints"):
            if k in o:
                o[k] = [at[x] for x in o[k] if x in at]
    compact(j, "meshes", [(n, "mesh") for n in j["nodes"] if "mesh" in n])
    compact(j, "materials", [(p, "material") for m in j["meshes"] for p in m["primitives"] if "material" in p])
    compact(j, "textures", tex_infos(j.get("materials", []), []))
    tex = j.get("textures", [])
    ext = [e for t in tex for e in (t.get("extensions") or {}).values() if "source" in e]
    compact(j, "images", [(t, "source") for t in tex + ext if "source" in t])
    compact(j, "samplers", [(t, "sampler") for t in tex if "sampler" in t])
    return sorted(mats[i]["name"] for i in gone), tris, len(dead)


def main():
    src, dst, pats = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
    j, bin_ = read(src)
    names, tris, nodes = drop(j, pats)
    if not names:
        sys.exit("glb_drop_mats: no material matches %s" % pats)
    write(dst, j, prune(j, bin_))
    print("glb_drop_mats: dropped %d triangles on %s (%d nodes); images left %s" % (
        tris, names, nodes, [im.get("name") for im in j.get("images", [])]))


if __name__ == "__main__":
    main()
