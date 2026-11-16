import shutil, os, socket
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "out"); os.makedirs(out, exist_ok=True)
print("HOST", socket.gethostname())
for p in ["/home/boki/meshy/v95/Cinder/r2/ba1113/cand_BA2.glb",
          "/home/boki/meshy/v95/Cinder/r2/facekeep1112/cand_A_face3.glb"]:
    for q in (p, p.replace("/home/boki/meshy", "/mnt/HC_Volume_107406663/offload/meshy")):
        if os.path.exists(q):
            shutil.copy(q, os.path.join(out, os.path.basename(q))); print("COPIED", q); break
    else: print("MISSING", p)
