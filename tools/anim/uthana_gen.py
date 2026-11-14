#!/usr/bin/env python3
"""uthana_gen.py <prompts.tsv> <out dir> <rig:char_id>... [--only label,...] [--floor 0.5] [--workers 4]
For each TSV row (label, rig, prompt): a TTM 3.0 job on Tar (4 s, rewrite off, not fast), then the motion downloaded on Tar
(pelvis height) and on the row's rig character. Stops when the org balance minus the committed estimate would fall under
--floor. Appends every result to <out dir>/ledger.tsv. The API key is read from ~/.config/boki/secrets.env and never printed."""
import json, os, re, subprocess, sys, threading, time, urllib.request, base64
from concurrent.futures import ThreadPoolExecutor
TAR, MODEL, LEN, PRICE = "cXi2eAP19XwQ", "text-to-motion-3.0", 4.0, 0.10
KEY = re.search(r"UTHANA_API_KEY=(\S+)", open(os.path.expanduser("~/.config/boki/secrets.env")).read()).group(1).strip("'\"")
AUTH = "Basic " + base64.b64encode((KEY + ":").encode()).decode()
lock = threading.Lock()
committed = [0.0]

def gql(query, variables=None):
    req = urllib.request.Request("https://uthana.com/graphql", json.dumps({"query": query, "variables": variables or {}}).encode(),
                                 {"Authorization": AUTH, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def balance():
    return float(gql("{ org { payg_total_usd } }")["data"]["org"]["payg_total_usd"])

def download(char, motion, path):
    kind = f"https://uthana.com/motion/animation/motion_viewer/{char}/{motion}/glb/motion.glb?fps=30"
    req = urllib.request.Request(kind, headers={"Authorization": AUTH})
    open(path, "wb").write(urllib.request.urlopen(req, timeout=120).read())

def run(row, chars, out, floor):
    label, rig, prompt = row
    with lock:
        bal = balance()
        if bal - committed[0] - LEN * PRICE < floor:
            return f"{label}\tSKIP\tbalance {bal:.2f}"
        committed[0] += LEN * PRICE
    r = gql("mutation($p:String!,$c:String!,$l:Float){ create_text_to_motion_job(prompt:$p, character_id:$c, length:$l, model:\"%s\","
            " rewrite_prompt:false, fast:false){ job { id } } }" % MODEL, {"p": prompt, "c": TAR, "l": LEN})
    if "errors" in r:
        return f"{label}\tERROR\t{str(r['errors'])[:120]}"
    job = r["data"]["create_text_to_motion_job"]["job"]["id"]
    for _ in range(120):
        time.sleep(5)
        j = gql("query($i:String!){ job(job_id:$i){ status result } }", {"i": job})["data"]["job"]
        if j["status"] == "FINISHED": break
        if j["status"] == "FAILED": return f"{label}\tFAILED\t{job}"
    mot = j["result"]["result"]["id"]
    download(TAR, mot, f"{out}/{label}__tar.glb")
    if rig in chars: download(chars[rig], mot, f"{out}/{label}__{rig}.glb")
    return f"{label}\tOK\t{mot}\t{job}"

if __name__ == "__main__":
    a = [x for x in sys.argv[1:]]
    opt = {"--only": "", "--floor": "0.5", "--workers": "4"}
    for k in opt:
        if k in a: i = a.index(k); opt[k] = a[i + 1]; del a[i:i + 2]
    tsv, out, chars = a[0], a[1], dict(x.split(":") for x in a[2:])
    os.makedirs(out, exist_ok=True)
    rows = [l.rstrip("\n").split("\t") for l in open(tsv) if l.strip() and not l.startswith("#")]
    if opt["--only"]: rows = [r for r in rows if r[0] in opt["--only"].split(",")]
    with ThreadPoolExecutor(int(opt["--workers"])) as ex:
        for res in ex.map(lambda r: run(r, chars, out, float(opt["--floor"])), rows):
            print(res, flush=True)
            open(f"{out}/ledger.tsv", "a").write(time.strftime("%H:%M:%S") + "\t" + res + "\n")
