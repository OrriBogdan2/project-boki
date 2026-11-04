"""Image I/O for Blender's bundled numpy python, through ffmpeg (no PIL on this box)."""
import json, subprocess
import numpy as np

def size(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "json", path], capture_output=True, check=True).stdout
    s = json.loads(out)["streams"][0]
    return s["width"], s["height"]

def load(path, alpha=False):
    w, h = size(path)
    fmt, c = ("rgba", 4) if alpha else ("rgb24", 3)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", fmt, "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, w, c).astype(np.float32) / 255.0

def save(arr, path):
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    h, w, c = a.shape
    fmt = {3: "rgb24", 4: "rgba"}[c]
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", fmt, "-s", "%dx%d" % (w, h),
                    "-i", "-", path], input=a.tobytes(), check=True)
