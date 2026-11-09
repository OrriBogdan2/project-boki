#!/usr/bin/env python3
"""Batch-generate Boki sheets with Nano Banana Pro (Gemini API).

Usage (from the repo root):
  export GEMINI_API_KEY="your key"        # never commit or paste it anywhere
  python3 briefs/boki-art/batch/gen_boki.py            # run every job that has no output yet
  python3 briefs/boki-art/batch/gen_boki.py --push     # same, then commit and push the images
  python3 briefs/boki-art/batch/gen_boki.py --only chuggamus_r2,ringrove
"""
import argparse, json, os, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
JOBS = HERE / "jobs.json"
OUT = HERE / "out"
RESULTS = HERE / "results.json"
MODEL = os.environ.get("BOKI_MODEL", "gemini-3-pro-image")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--push", action="store_true", help="git commit and push the new images")
    ap.add_argument("--only", default="", help="comma-separated job ids")
    ap.add_argument("--size", default=None, help="override size, e.g. 2K")
    ap.add_argument("--parallel", type=int, default=8, help="images generated at the same time")
    ap.add_argument("--watch", action="store_true", help="keep running: pull new jobs every minute, generate, push")
    a = ap.parse_args()
    if not os.environ.get("GEMINI_API_KEY"):
        sys.exit("GEMINI_API_KEY is not set. Run: export GEMINI_API_KEY=\"your key\"")
    try:
        from google import genai
        from google.genai import types
        from PIL import Image
    except ImportError:
        sys.exit("Missing packages. Run: python3 -m pip install --upgrade google-genai pillow")

    import google.genai as _g
    has_size = "image_size" in getattr(types.ImageConfig, "model_fields", {})
    print(f"google-genai {getattr(_g, '__version__', '?')}, Python {sys.version.split()[0]}, 4K support: {has_size}")
    if not has_size:
        print("WARNING: this google-genai is too old for 4K. Images will come out at the default size.")
        print("To fix: python3 -m pip install --upgrade 'google-genai>=1.50'  (needs Python 3.10+)\n")
    client = genai.Client()
    jobs = json.loads(JOBS.read_text())
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    OUT.mkdir(exist_ok=True)
    results = json.loads(RESULTS.read_text()) if RESULTS.exists() else []
    made = []
    import threading
    from concurrent.futures import ThreadPoolExecutor
    lock = threading.Lock()
    tasks = []
    for job in jobs:
        if only and job["id"] not in only:
            continue
        for run in range(1, job.get("runs", 2) + 1):
            if not any((OUT / f"{job['id']}_{run}.{e}").exists() for e in ("jpg", "png")):
                tasks.append((job, run))
    print(f"{len(tasks)} images to make, {a.parallel} at a time")

    def do(task):
        job, run = task
        dest = OUT / f"{job['id']}_{run}.jpg"
        refs = [Image.open(ROOT / r) for r in job.get("refs", [])]
        entry = {"id": job["id"], "name": job.get("name"), "run": run, "file": str(dest.relative_to(ROOT))}
        for attempt in range(3):
            try:
                resp = client.models.generate_content(
                    model=MODEL,
                    contents=[job["prompt"], *refs],
                    config=types.GenerateContentConfig(
                        response_modalities=["IMAGE"],
                        image_config=types.ImageConfig(
                            aspect_ratio=job.get("aspect", "16:9"),
                            **({"image_size": a.size or job.get("size", "4K")} if has_size else {}),
                        ),
                    ),
                )
                img = None
                for cand in resp.candidates or []:
                    for part in (cand.content.parts if cand.content else []):
                        if getattr(part, "inline_data", None) and part.inline_data.data:
                            img = part.inline_data.data
                if img is None:
                    reason = resp.candidates[0].finish_reason if resp.candidates else "no candidates"
                    raise RuntimeError(f"no image returned ({reason})")
                import io
                Image.open(io.BytesIO(img)).convert("RGB").save(dest, "JPEG", quality=92)
                entry["ok"] = True
                entry.pop("error", None)
                print(f"   saved {dest.name}", flush=True)
                break
            except Exception as e:
                entry["ok"] = False
                entry["error"] = str(e)[:300]
                if "API_KEY_INVALID" in str(e) or "PERMISSION_DENIED" in str(e):
                    print("\nSTOPPING: the API key was rejected. Set it again with: export GEMINI_API_KEY=\"your key\"", flush=True)
                    os._exit(2)
                print(f"   {job['id']} run {run} attempt {attempt+1} failed: {entry['error']}", flush=True)
                time.sleep(10 * (attempt + 1))
        with lock:
            results.append(entry)
            RESULTS.write_text(json.dumps(results, indent=2))
            if entry.get("ok"):
                made.append(dest)
                if a.push and len(made) % 8 == 0:
                    push(len(made))

    def push(n):
        subprocess.run(["git", "add", str(OUT), str(RESULTS)], cwd=ROOT)
        subprocess.run(["git", "commit", "-q", "-m", f"Boki batch: {n} images so far"], cwd=ROOT)
        subprocess.run(["git", "pull", "--rebase", "--autostash", "-q"], cwd=ROOT)
        subprocess.run(["git", "push", "-q"], cwd=ROOT)
        print(f"   pushed ({n} so far)", flush=True)

    with ThreadPoolExecutor(max_workers=a.parallel) as ex:
        list(ex.map(do, tasks))
    print(f"\nDone: {len(made)} new images in {OUT}")
    if a.push and made:
        subprocess.run(["git", "add", str(OUT), str(RESULTS)], cwd=ROOT, check=True)
        subprocess.run(["git", "commit", "-m", f"Boki batch: {len(made)} new images"], cwd=ROOT, check=True)
        subprocess.run(["git", "pull", "--rebase"], cwd=ROOT, check=True)
        subprocess.run(["git", "push"], cwd=ROOT, check=True)
        print("Pushed.")
    elif not made:
        print("Nothing new to generate.")

def watch():
    print("Watch mode: checking for new jobs every 60 s. Press Ctrl+C to stop.")
    while True:
        subprocess.run(["git", "pull", "--rebase", "--autostash", "-q"], cwd=ROOT)
        rc = subprocess.run([sys.executable, __file__, "--push"] + [x for x in sys.argv[1:] if x != "--watch"], cwd=ROOT).returncode
        if rc not in (0, None):
            print("run exited with", rc)
        time.sleep(60)

if __name__ == "__main__":
    if "--watch" in sys.argv:
        watch()
    else:
        main()
