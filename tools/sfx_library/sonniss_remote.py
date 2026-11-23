#!/usr/bin/env python3
"""List or partly extract Sonniss GDC bundle zips on the your.org mirror using HTTP range requests,
so only the wanted packs/files are downloaded (the bundles are 9-48 GB each).

  sonniss_remote.py list OUT.jsonl                 # every member of every bundle part (names, sizes)
  sonniss_remote.py get  PICK.txt DEST_DIR CAP_GB  # PICK.txt lines: <bundle-key>\t<member path>

Free public mirror, no login. DEST_DIR is PRIVATE: the Sonniss licence forbids redistributing the
files as sound effects (see answer.md of job sfx-lib-1113). Run with python3 -I.
"""

import io, json, os, re, sys, time, urllib.parse, urllib.request, zipfile

MIRROR = "https://ftpmirror.your.org/pub/misc/"
# bundle key -> (directory, list of part file names fetched from the directory index)
BUNDLES = {
    "2015": "sonniss/",
    "2016": "sonniss2016/",
    "2017": "sonniss2017/",
    "2018": "sonniss2018/",
    "2019": "sonniss2019/",
    "2020": "sonniss2020/",
}
UA = {"User-Agent": "boki-sfx-library/1.0"}


class HttpFile(io.RawIOBase):
    """Read-only seekable file over HTTP Range requests, with a 4 MB read-ahead block."""

    BLOCK = 4 << 20

    def __init__(self, url):
        self.url, self.pos, self.buf, self.buf_at = url, 0, b"", 0
        req = urllib.request.Request(url, method="HEAD", headers=UA)
        self.size = int(urllib.request.urlopen(req, timeout=60).headers["Content-Length"])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def _fetch(self, start, n):
        for attempt in range(5):
            try:
                req = urllib.request.Request(self.url, headers={**UA, "Range": "bytes=%d-%d" % (start, start + n - 1)})
                return urllib.request.urlopen(req, timeout=120).read()
            except Exception:
                time.sleep(2 * (attempt + 1))
        raise IOError("range fetch failed " + self.url)

    def read(self, n=-1):
        if n < 0:
            n = self.size - self.pos
        n = min(n, self.size - self.pos)
        if n <= 0:
            return b""
        if not (self.buf_at <= self.pos and self.pos + n <= self.buf_at + len(self.buf)):
            self.buf_at, self.buf = self.pos, self._fetch(self.pos, max(n, self.BLOCK if n < self.BLOCK else n))
        out = self.buf[self.pos - self.buf_at : self.pos - self.buf_at + n]
        self.pos += len(out)
        return out

    def readinto(self, b):
        d = self.read(len(b))
        b[: len(d)] = d
        return len(d)


def parts(key):
    html = (
        urllib.request.urlopen(urllib.request.Request(MIRROR + BUNDLES[key], headers=UA), timeout=60)
        .read()
        .decode("latin1")
    )
    names = re.findall(r'href="([^"?]+\.zip)"', html)
    return [MIRROR + BUNDLES[key] + n for n in names]


def fix(name):  # zip names that are not flagged utf-8 are cp437 in python; the packs use utf-8 or latin1
    return name


def cmd_list(out):
    with open(out, "w") as f:
        for key in BUNDLES:
            for url in parts(key):
                try:
                    z = zipfile.ZipFile(HttpFile(url))
                except Exception as e:
                    print("skip", url, e, file=sys.stderr)
                    continue
                for i in z.infolist():
                    if i.is_dir() or not i.filename.lower().endswith((".wav", ".flac", ".ogg", ".mp3")):
                        continue
                    f.write(
                        json.dumps(
                            {
                                "bundle": key,
                                "part": urllib.parse.unquote(url.rsplit("/", 1)[1]),
                                "url": url,
                                "name": i.filename,
                                "size": i.file_size,
                            }
                        )
                        + "\n"
                    )
                print("listed", key, url.rsplit("/", 1)[1], flush=True)


def cmd_get(pick, dest, cap_gb):
    want = {}
    for line in open(pick, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        url, name = line.split("\t", 1)
        want.setdefault(url, []).append(name)
    total = 0
    for url, names in want.items():
        z = zipfile.ZipFile(HttpFile(url))
        have = {i.filename: i for i in z.infolist()}
        for n in names:
            i = have.get(n)
            key = url.split("/")[-2].replace("sonniss", "") or "2015"
            path = os.path.join(dest, key, n)
            if i is None or os.path.exists(path):
                continue
            if total + i.file_size > cap_gb * (1 << 30):
                print("cap reached")
                return
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with z.open(i) as src, open(path, "wb") as dst:
                dst.write(src.read())
            total += i.file_size
        print("got", url.rsplit("/", 1)[1], "%.2f GB so far" % (total / (1 << 30)), flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "list":
        cmd_list(sys.argv[2])
    else:
        cmd_get(sys.argv[2], sys.argv[3], float(sys.argv[4]))
