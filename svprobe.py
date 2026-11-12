import subprocess, os, sys, socket, time
out = os.path.abspath("svprobe"); os.makedirs(out, exist_ok=True)
log = open(os.path.join(out, "probe.txt"), "w")
yd = [sys.executable, os.path.abspath("svprobe_ytdlp")]
log.write("host=%s exe=%s\n" % (socket.gethostname(), sys.executable)); log.flush()
r = subprocess.run(yd + ["-F", "https://youtu.be/IN3TXapMLw0"], capture_output=True, text=True, timeout=300)
log.write("probe rc=%d\n%s\n%s\n" % (r.returncode, r.stdout[-3000:], r.stderr[-1500:])); log.flush()
if r.returncode == 0:
    ids = ["IN3TXapMLw0","2qF1CMkwdMU","c8nW-_8cTZQ","YCVtyUszkg0","QSsYWU1CHsI","_atb6Tr0REs","lG-uyC9ceMk","AslrRj5l5KU","O3Gj3FI6viQ","tDPa-jdhVTI"]
    src = os.path.join(out, "src"); os.makedirs(src, exist_ok=True)
    for i in ids:
        t = time.time()
        r = subprocess.run(yd + ["--no-playlist", "--sleep-requests", "2", "-f", "bv*[height<=1080][ext=mp4],ba[ext=m4a]/ba",
                                 "-o", os.path.join(src, "%(id)s.f%(format_id)s.%(ext)s"), "--write-info-json", "https://youtu.be/" + i],
                           capture_output=True, text=True, timeout=1800)
        log.write("dl %s rc=%d %.0fs\n%s\n" % (i, r.returncode, time.time() - t, (r.stderr or "")[-600:])); log.flush()
        time.sleep(5)
log.close()
