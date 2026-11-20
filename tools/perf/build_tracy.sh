#!/bin/bash
# Builds the Tracy profiling pieces on Linux x86_64 (docs/PERF.md). Needs git, g++, python3 and network once.
#   perf_tracy/                the extension (tracy.gdextension + .so), loaded by the engine when present
#   tools/perf/bin/            tracy-capture and tracy-csvexport (CLI, no GUI)
# Both folders are untracked and the export presets exclude perf_tracy/*: the shipped build never has it.
set -euo pipefail
TRACY_TAG=v0.15.0;   TRACY_SHA=f2a4f2529e7e71844c9e434b877770a21ecf7587
GODOT_CPP_TAG=godot-4.5-stable; GODOT_CPP_SHA=e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
root=$(cd "$(dirname "$0")/../.." && pwd)
deps=$root/native/tracy/deps   # (short relative paths: godot-cpp's archive step puts every object on one command line)
venv=$deps/venv
mkdir -p "$deps" "$root/tools/perf/bin" "$root/perf_tracy"

fetch() {   # fetch <url> <tag> <sha> <dir>: a shallow clone, checked against the pinned commit
	[ -d "$4" ] || git clone -q --depth 1 --branch "$2" "$1" "$4"
	[ "$(git -C "$4" rev-parse HEAD)" = "$3" ] || { echo "$4 is not $2 ($3)" >&2; exit 1; }
}
fetch https://github.com/wolfpld/tracy.git "$TRACY_TAG" "$TRACY_SHA" "$deps/tracy"
fetch https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_TAG" "$GODOT_CPP_SHA" "$deps/godot-cpp"

[ -d "$venv" ] || { python3 -m venv "$venv"; "$venv/bin/pip" -q install scons cmake ninja; }
export PATH=$venv/bin:$PATH

for tool in capture csvexport; do   # same tag as the client (the protocols must match); no -march=native, so a binary built here runs on any x86_64 worker
	cmake -S "$deps/tracy/$tool" -B "$deps/build/$tool" -G Ninja -DCMAKE_BUILD_TYPE=Release -DNO_ISA_EXTENSIONS=ON > /dev/null
	cmake --build "$deps/build/$tool" > /dev/null
	cp "$deps/build/$tool/tracy-$tool" "$root/tools/perf/bin/"
done

(cd "$root/native/tracy" && scons platform=linux arch=x86_64 target=template_release \
	godot_cpp="$(realpath --relative-to=. "$deps/godot-cpp")" tracy="$(realpath --relative-to=. "$deps/tracy")" -j"$(nproc)" > /dev/null)
cp "$root"/native/tracy/build/libtracy_zones.*.so "$root/perf_tracy/"
cp "$root/native/tracy/tracy.gdextension.in" "$root/perf_tracy/tracy.gdextension"
echo "built: perf_tracy/ and tools/perf/bin/ (Tracy $TRACY_TAG, godot-cpp $GODOT_CPP_TAG)"
