#!/usr/bin/env python3
"""RECIPE_95 driver (docs/art/wardens/RECIPE_95.md): one Warden from its art to a shipped 3D model, from a spec
(art/wardens/src/<name>_recipe.json). Run from the hero's worktree; every step logs to <raw>/logs/<step>.log.

  python3 tools/meshy/recipe.py SPEC STEP [STEP ...]

Steps, in order (the ones marked * need your eyes on their output before the next):
  art        the sheets from the art branch (git show) into <raw>/art, webp -> png
  crop     * 9:16 crops of the turnaround's views (<raw>/crops; spec "views")
  edit     * Meshy image-to-image of every view with the spec's prompt ("edits"; 9 credits a view, in parallel);
             <raw>/edits_sheet.png puts crops over edits; redo a view with `edit:<view>`
  prep       the chosen edits padded square into <raw>/in ("use": view -> edit dir; "flat_ground": view -> flat_ground.py
             args, the background flattened first)
  meshy    * the Meshy variants in parallel ("meshy.variants"; ~40 credits each); <raw>/variants.png compares them
  bake       the kept variant baked to the clean low mesh (spec "bake": the bake spec)
  grid     * gridded front/side renders of the low mesh (<raw>/grid_*.png, 500 px/m) for the fit spec's joints
  rig        godot --warden-rig-json for the archetype (after setting its body in content/archetypes/<arch>.json)
  fit        fit_warden.py with the fit spec (spec "fit"), then the Godot import with the atlases lossless
  shots      in-game shots (--warden-shots + the Arena match frame and its x4 crop) and the composites vs the art
             into <raw>/shots (spec "shots_worktree" runs them in another worktree, e.g. one with the stance)
  checks     every Warden check through the godot queue wrapper (fresh XDG each), health --strict, style_lint
  balance    the Meshy balance
  loop       fit + shots: the iteration on the fit spec
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TOOLS = os.path.join(ROOT, "tools", "meshy")
BLENDER = os.path.expanduser(os.environ.get("BLENDER", "~/tools/blender-4.5.15-linux-x64/blender"))
BPY = os.path.expanduser(os.environ.get("BPY", "~/tools/blender-4.5.15-linux-x64/4.5/python/bin/python3.11"))
CHECKS = ["--warden-glb-check", "--warden-model-check", "--mantle-look-check", "--move-feel-check",
          "--weapon-clip-check", "--warden-stance-check"]


def log(*a):
    print("RECIPE", *a, flush=True)


def run(cmd, logname, cwd=None, check=True):
    os.makedirs(os.path.join(RAW, "logs"), exist_ok=True)
    path = os.path.join(RAW, "logs", logname + ".log")
    t0 = time.time()
    with open(path, "w") as f:
        rc = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=cwd or ROOT)
    log("%s: rc %d, %.0f s -> %s" % (logname, rc, time.time() - t0, path))
    if check and rc != 0:
        sys.exit("step %s failed (see %s)" % (logname, path))
    return path


def bl(script, *args):
    return [BLENDER, "-b", "--factory-startup", "--python", os.path.join(TOOLS, script), "--"] + list(args)


def py(script, *args):
    return [BPY, "-I", os.path.join(TOOLS, script)] + list(args)


def grep(path, *keys):
    for line in open(path, errors="replace"):
        if any(k in line for k in keys):
            print("   ", line.rstrip()[:220])


# ------------------------------------------------------------------------------------------------ steps
def step_art():
    a = SPEC["art"]
    out = os.path.join(RAW, "art")
    os.makedirs(out, exist_ok=True)
    for key, rel in a.items():
        if key == "ref":
            continue
        base = os.path.join(out, key)
        ext = rel.rsplit(".", 1)[-1]
        data = subprocess.run(["git", "show", "%s:%s" % (a["ref"], rel)], capture_output=True, cwd=ROOT, check=True).stdout
        open(base + "." + ext, "wb").write(data)
        if ext != "png":
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", base + "." + ext, base + ".png"], check=True)
        log("art", key, "->", base + ".png")


def step_crop():
    if SPEC.get("crop_from"):
        # (separate square views instead of a turnaround sheet, e.g. Cinder: each crop is its art, whole)
        os.makedirs(os.path.join(RAW, "crops"), exist_ok=True)
        pad = SPEC.get("crop_pad")   # [size, x, y, canvas, grey]: the view shrunk onto a wider grey canvas (a tail that
        for view, key in SPEC["crop_from"].items():          # runs off the art's edge gets room to end in the frame)
            src, dst = os.path.join(RAW, "art", key + ".png"), os.path.join(RAW, "crops", view + ".png")
            if pad:
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vf", "scale=%d:%d,pad=%d:%d:%d:%d:color=0x%s"
                                % (pad[0], pad[0], pad[3], pad[3], pad[1], pad[2], pad[4]), dst], check=True)
            else:
                subprocess.run(["cp", src, dst], check=True)
            log("crop", view, "<-", key)
        return
    vj = os.path.join(RAW, "views.json")
    json.dump({"views": SPEC["views"]} if isinstance(SPEC["views"], list) else {"auto": SPEC["views"]["auto"]},
              open(vj, "w"))
    p = run(py("sheet_crops.py", os.path.join(RAW, "art", "turnaround.png"), os.path.join(RAW, "crops"), vj), "crop")
    grep(p, "SHEETCROP", "found")


def step_edit(only=None):
    procs = []
    for view, prompt in SPEC["edits"].items():
        if only and view not in only:
            continue
        out = os.path.join(RAW, SPEC.get("use", {}).get(view, "edit_" + view))
        cmd = ["python3", "-I", os.path.join(TOOLS, "meshy_task.py"), "edit", out, os.path.join(RAW, "crops", view + ".png"),
               "--prompt", prompt, "--aspect", SPEC.get("edit_aspect", "9:16")]
        procs.append((view, subprocess.Popen(cmd, stdout=open(out.rstrip("/") + ".log", "w"), stderr=subprocess.STDOUT,
                                             cwd=ROOT)))
    for view, pr in procs:
        log("edit", view, "rc", pr.wait())
    _sheet([os.path.join(RAW, "crops", v + ".png") for v in SPEC["edits"]],
           [os.path.join(RAW, SPEC.get("use", {}).get(v, "edit_" + v), "image0.png") for v in SPEC["edits"]],
           os.path.join(RAW, "edits_sheet.png"))


def step_prep():
    args = []
    for v in SPEC["edits"]:
        src = os.path.join(RAW, SPEC.get("use", {}).get(v, "edit_" + v), "image0.png")
        if v in SPEC.get("flat_ground", {}):
            # (the background flattened to one grey: a padded crop's rectangle, a floor band or shadow; flat_ground.py)
            flat = os.path.join(RAW, "flat", v + ".png")
            os.makedirs(os.path.dirname(flat), exist_ok=True)
            run(py("flat_ground.py", src, flat, *[str(x) for x in SPEC["flat_ground"][v]]), "flat_" + v)
            src = flat
        args.append("%s=%s" % (v, src))
    for v in SPEC.get("unedited", []):
        args.append("%s=%s" % (v, os.path.join(RAW, "crops", v + ".png")))
    run(py("pad_views.py", os.path.join(RAW, "in"), *args), "prep")


def step_meshy():
    views = [os.path.join(RAW, "in", v + ".png") for v in SPEC["meshy"].get("order", ["front", "tq", "side", "back"])]
    procs = []
    for name, opt in SPEC["meshy"]["variants"].items():
        out = os.path.join(RAW, "run" + name)
        cmd = ["python3", "-I", os.path.join(TOOLS, "meshy_task.py"), "create", out] + views + ["--texture-refs"] + views
        for k, v in opt.items():
            cmd += ["--" + k.replace("_", "-"), str(v)]
        procs.append((name, out, subprocess.Popen(cmd, stdout=open(out + ".log", "w"), stderr=subprocess.STDOUT, cwd=ROOT)))
    rows = []
    for name, out, pr in procs:
        log("meshy", name, "rc", pr.wait())
        thumbs = [os.path.join(out, "thumb_%s.png" % t) for t in ("front", "right", "back", "left")]
        if all(os.path.exists(t) for t in thumbs):
            row = os.path.join(RAW, "_variant_%s.png" % name)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum((["-i", t] for t in thumbs), []) +
                           ["-filter_complex", "[0][1][2][3]hstack=4", row], check=True)
            rows.append(row)
    if rows:
        run(bl("compose.py", os.path.join(RAW, "variants.png"), "rows", *rows), "variants")
    step_balance()


def step_bake():
    p = run(bl("bake_warden.py", os.path.join(ROOT, SPEC["bake"])), "bake")
    grep(p, "BAKEWARDEN low", "BAKEWARDEN wrote", "Traceback")


def step_grid():
    low = os.path.expanduser(json.load(open(os.path.join(ROOT, SPEC["bake"])))["out"])
    if not os.path.exists(low):
        # (no bake yet: the kept Meshy run itself, for the bake spec's head centre)
        low = os.path.join(RAW, "run" + SPEC["meshy"]["keep"], "glb.glb")
    run(bl("grid_renders.py", low, os.path.join(RAW, "grid")), "grid")
    log("read the joints on", os.path.join(RAW, "grid_front.png"), "and", os.path.join(RAW, "grid_right.png"),
        "(500 px/m about the origin; Meshy frame: +Z up, facing -Y, her right -X)")


def step_rig():
    run(["godot", "--headless", "--path", ROOT, "--", "--warden-rig-json", "--warden=" + SPEC["arch"]], "rig", check=False)


def step_fit():
    p = run(bl("fit_warden.py", os.path.join(ROOT, SPEC["fit"])), "fit")
    grep(p, "FITWARDEN tris", "FITWARDEN wrote", "warp:", "Traceback", "Error")
    _import(ROOT)


def _import(wt):
    run(["godot", "--headless", "--path", wt, "--import"], "import", cwd=wt, check=False)
    d = os.path.join(wt, "art", "wardens", SPEC["name"])
    for f in os.listdir(d):
        p = os.path.join(d, f)
        if f.endswith(".jpg.import") or f.endswith(".png.import"):
            s = open(p).read()
            s2 = s.replace("compress/mode=1", "compress/mode=0").replace("compress/mode=2", "compress/mode=0")
            s2 = s2.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
            if s2 != s:
                open(p, "w").write(s2)
        if f.endswith(".glb.import"):
            s = open(p).read()
            s2 = s.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
            s2 = s2.replace("meshes/force_disable_compression=false", "meshes/force_disable_compression=true")
            if s2 != s:
                open(p, "w").write(s2)
    run(["godot", "--headless", "--path", wt, "--import"], "import2", cwd=wt, check=False)


def step_shots():
    wt = SPEC.get("shots_worktree", ROOT)
    if wt != ROOT:
        _import(wt)
    out = os.path.join(RAW, "shots")
    subprocess.run(["rm", "-rf", out])
    os.makedirs(os.path.join(out, "sheets"), exist_ok=True)
    subprocess.run(["cp", os.path.join(RAW, "art", "turnaround.png"), os.path.join(out, "sheets", SPEC["arch"] + ".png")])
    x = ["timeout", "900", "xvfb-run", "-a", "godot", "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
         "--resolution", "1280x720", "--path", wt, "--"]
    extra = SPEC.get("shot_args", [])
    a = subprocess.Popen(x + ["--warden-shots", "--wardens=" + SPEC["arch"], "--shots-dir=" + out,
                              "--sheets=" + os.path.join(out, "sheets")] + extra,
                         stdout=open(os.path.join(out, "log.txt"), "w"), stderr=subprocess.STDOUT, cwd=wt)
    # (a clean review frame: no tip banner, the hero moved onto clear ground: spec "demo_at" "dx,dz")
    clear = ["--no-tips"] + (["--demo-at=" + SPEC["demo_at"]] if SPEC.get("demo_at") else [])
    b = subprocess.Popen(x + ["--arena=" + SPEC["arch"], "--record=2", "--arena-demo=pose_clear", "--demo-zoom=1.0",
                              "--arena-shot=" + os.path.join(out, "match.png")] + clear + extra,
                         stdout=open(os.path.join(out, "match.log"), "w"), stderr=subprocess.STDOUT, cwd=wt)
    log("shots rc", a.wait(), "match rc", b.wait())
    crop = SPEC.get("match_crop") or _hero_crop(os.path.join(out, "match.log"))      # (pose_clear: the review frame)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(out, "match.png"), "-vf",
                    "crop=%s,scale=800:680:flags=neighbor" % crop, os.path.join(out, "match_x4.png")])
    grep(os.path.join(out, "log.txt"), "does not fit", "SHADER ERROR", "SCRIPT ERROR", "WARDEN_SHOTS_DONE")
    _composites(out)


def _hero_crop(match_log):
    """The x4 crop (w:h:x:y, 200x170 px) centred on the hero, from the review frame's DEMO_HERO_RECT line."""
    for line in open(match_log, errors="replace"):
        if line.startswith("DEMO_HERO_RECT "):
            x, y, w, h = (int(v) for v in line.split()[1].split(","))
            return "200:170:%d:%d" % (max(0, x + w // 2 - 100), max(0, y + h // 2 - 85))
    return "200:170:540:270"


def _composites(out):
    g = os.path.join(out, SPEC["arch"])
    art = os.path.join(RAW, "art")
    c = os.path.join(out, "compare")
    os.makedirs(c, exist_ok=True)
    pairs = [("vs_turnaround.png", "rows", [os.path.join(art, "turnaround.png"), os.path.join(g, "turnaround_close.png")]),
             ("vs_turnaround_game.png", "rows", [os.path.join(art, "turnaround.png"), os.path.join(g, "turnaround_game.png")]),
             ("closeup_vs_art.png", "cols", [os.path.join(art, k + ".png") for k in ("face", "portrait")
                                             if os.path.exists(os.path.join(art, k + ".png"))] + [os.path.join(g, "closeup_front.png")]),
             ("closeup_34_vs_art.png", "cols", [os.path.join(art, k + ".png") for k in ("portrait", "head_sheet")
                                                if os.path.exists(os.path.join(art, k + ".png"))] + [os.path.join(g, "closeup.png")]),
             ("match_vs_art.png", "cols", [os.path.join(art, "portrait.png"), os.path.join(out, "match_x4.png")]),
             ("back_34.png", "cols", [os.path.join(g, "back_34.png")])]
    for name, mode, imgs in pairs:
        imgs = [i for i in imgs if os.path.exists(i)]
        if imgs:
            run(bl("compose.py", os.path.join(c, SPEC.get("tag", "s") + "_" + name), mode, *imgs), "compose_" + name, check=False)
    log("composites in", c, "(score them: RECIPE_95.md 'Self-score')")


def step_checks():
    wt = SPEC.get("checks_worktree", ROOT)
    procs = []
    # (the kit's combo check by its own flag, spec "combo_check", e.g. --gunslinger-combo-check or
    # --hero-combo-check: see scripts/main.gd; an unknown flag would start the game and hang until the timeout)
    for flag in CHECKS + ([SPEC["combo_check"]] if SPEC.get("combo_check") else []):
        cwd = SPEC.get("stance_worktree", wt) if flag == "--warden-stance-check" else wt
        path = os.path.join(RAW, "logs", "check" + flag.replace("-", "_") + ".log")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        procs.append((flag, path, subprocess.Popen(["timeout", "1500", "godot", "--headless", "--path", cwd, "--", flag],
                                                   stdout=open(path, "w"), stderr=subprocess.STDOUT, cwd=cwd)))
    for flag, path, pr in procs:
        pr.wait()
        verdict = [line.strip() for line in open(path, errors="replace") if any(
            k in line for k in ("_DONE", "DONE,", "failed", "failures", "CLIP PASS", "CLIP FAIL"))]
        log("%-24s %s" % (flag, verdict[-1] if verdict else "no verdict: read " + path))
    for name, cmd in (("health", ["python3", "tools/health.py", "--strict"]),
                      ("style", ["python3", "tools/style_lint.py", "--strict"])):
        p = run(cmd, name, check=False)
        grep(p, "HEALTH", "STYLE OK", "STYLE FAIL")
    s = subprocess.run(["git", "grep", "-n", "msy" + "_"], capture_output=True, cwd=ROOT)
    log("secret grep:", "CLEAN" if s.returncode == 1 else "FOUND SOMETHING: do not commit")


def step_balance():
    subprocess.run(["python3", "-I", os.path.join(TOOLS, "meshy_task.py"), "balance"], cwd=ROOT)


def _sheet(tops, bottoms, out):
    rows = []
    for k, group in enumerate((tops, bottoms)):
        group = [g for g in group if os.path.exists(g)]
        if not group:
            continue
        row = os.path.join(RAW, "_sheet_%d.png" % k)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum((["-i", g] for g in group), []) +
                       ["-filter_complex", "".join("[%d]scale=-1:1376[s%d];" % (i, i) for i in range(len(group))) +
                        "".join("[s%d]" % i for i in range(len(group))) + "hstack=%d" % len(group), row])
        rows.append(row)
    if rows:
        run(bl("compose.py", out, "rows", *rows), "edits_sheet", check=False)


STEPS = {"art": step_art, "crop": step_crop, "edit": step_edit, "prep": step_prep, "meshy": step_meshy, "bake": step_bake,
         "grid": step_grid, "rig": step_rig, "fit": step_fit, "shots": step_shots, "checks": step_checks,
         "balance": step_balance}


def main(a):
    global SPEC, RAW
    if len(a) < 2:
        sys.exit(__doc__)
    SPEC = json.load(open(a[0]))
    RAW = os.path.expanduser(SPEC["raw"])
    os.makedirs(RAW, exist_ok=True)
    for st in a[1:]:
        if st == "loop":
            step_fit()
            step_shots()
        elif st.startswith("edit:"):
            step_edit(st.split(":", 1)[1].split(","))
        else:
            STEPS[st]()


SPEC = {}
RAW = ""
if __name__ == "__main__":
    main(sys.argv[1:])
