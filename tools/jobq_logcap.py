#!/usr/bin/env python3
"""Job-log filter for jobq-worker: `cmd 2>&1 | jobq_logcap.py OUT`. Master copy belongs in boki-tools.

Dedupe: a block of 1-4 lines that repeats 3 times in a row is shown 3 times, then counted
("[... 2 lines x 23806 more]"). Cap: OUT stays under CAP bytes (default 50 MB): the first HEAD (5 MB) is kept,
then the newest lines roll through a tail buffer and are written, after an elision note, when the input ends.
Past the cap OUT is rewritten at exit or on SIGTERM, so a hung job killed by the timeout still leaves a log.
Check: `python3 tools/jobq_logcap.py --self-test`."""
import collections, signal, sys

CAP, HEAD, MAX_BLOCK, SHOWN = 50 << 20, 5 << 20, 4, 3


class LogCap:
	def __init__(self, path, cap=CAP, head=HEAD):
		self.f, self.cap, self.head_max = open(path, "w+", errors="replace"), cap, head
		self.written, self.tail, self.tail_bytes, self.dropped = 0, collections.deque(), 0, 0
		self.hist, self.block, self.pos, self.reps = [], None, 0, 0

	def feed(self, line):
		if self.block is not None:
			if line == self.block[self.pos]:
				self.pos = (self.pos + 1) % len(self.block)
				self.reps += self.pos == 0
				return
			self._flush_repeats()
		self.hist = (self.hist + [line])[-SHOWN * MAX_BLOCK:]
		self._emit(line)
		for p in range(1, MAX_BLOCK + 1):
			blk = self.hist[-p:]
			if len(self.hist) >= SHOWN * p and any(s.strip() for s in blk) and all(
					self.hist[-(i + 1) * p:len(self.hist) - i * p] == blk for i in range(SHOWN)):
				self.block, self.pos, self.reps, self.hist = blk, 0, 0, []
				return

	def _flush_repeats(self):
		if self.reps:
			self._emit("[... %d line%s x %d more]\n" % (len(self.block), "s" * (len(self.block) > 1), self.reps))
		for line in self.block[:self.pos]:
			self._emit(line)
		self.block, self.hist = None, []

	def _emit(self, line):
		n = len(line.encode("utf-8", "replace"))
		if self.written + n <= self.cap and not self.tail:
			self.written += n
			self.f.write(line)
			self.f.flush()
			return
		if not self.tail:
			self._cut_to_head()
		self.tail.append(line)
		self.tail_bytes += n
		while self.tail_bytes > self.cap - self.head_max - 200:
			self.tail_bytes -= len(self.tail.popleft().encode("utf-8", "replace"))
			self.dropped += 1

	def _cut_to_head(self):
		self.f.flush()
		self.f.seek(0)
		kept = self.f.read(self.head_max)
		kept = kept[:kept.rfind("\n") + 1]
		self.f.seek(0)
		self.f.truncate(len(kept.encode("utf-8", "replace")))
		self.f.seek(0, 2)

	def close(self):
		if self.block is not None:
			self._flush_repeats()
		if self.tail:
			self.f.write("[... %d lines dropped to keep the log under %d MB ...]\n" % (self.dropped, self.cap >> 20))
			self.f.writelines(self.tail)
		self.f.close()


def _self_test():
	import os, tempfile
	def run(lines, **kw):
		p = tempfile.mktemp()
		c = LogCap(p, **kw)
		for l in lines: c.feed(l)
		c.close()
		out = open(p).read()
		os.remove(p)
		return out
	spam = ['ERROR: Parameter "material" is null.\n', "   at: material_set_shader (x.cpp:2284)\n"] * 5000
	out = run(["start\n"] + spam + ["end\n"])
	assert out.count("material_set_shader") == 3 and "[... 2 lines x 4997 more]" in out and out.endswith("end\n"), out
	assert run(["a\n"] * 10) == "a\na\na\n[... 1 line x 7 more]\n"
	assert run(["a\n", "b\n"] * 3 + ["a\n"]) == "a\nb\na\nb\na\nb\na\n"
	assert run(["\n"] * 6) == "\n" * 6
	uniq = ["line %05d\n" % i for i in range(5000)]
	out = run(uniq, cap=20000, head=2000)
	assert len(out) < 20000 and out.startswith("line 00000") and out.endswith("line 04999\n") and "dropped" in out
	assert run(uniq[:100], cap=20000, head=2000) == "".join(uniq[:100])
	print("jobq_logcap self-test ok")


if __name__ == "__main__":
	if sys.argv[1:] == ["--self-test"]:
		_self_test()
		sys.exit(0)
	cap = LogCap(sys.argv[1])
	signal.signal(signal.SIGTERM, lambda *_: (cap.close(), sys.exit(143)))
	for raw in sys.stdin:
		cap.feed(raw)
	cap.close()
