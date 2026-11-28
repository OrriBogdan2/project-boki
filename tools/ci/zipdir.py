"""zipdir.py OUT.zip DIR: zip the CONTENTS of DIR (what `cd DIR && zip -qr OUT .` does) with python only, for runners
without a `zip` binary. Keeps file permissions (the Linux build's executable bit)."""

import shutil
import sys

out, src = sys.argv[1], sys.argv[2]
shutil.make_archive(out[:-4] if out.endswith(".zip") else out, "zip", root_dir=src)
