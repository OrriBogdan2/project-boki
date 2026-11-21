#!/usr/bin/env python3
"""Apply USAGE-REDESIGN to the admin page: python3 apply.py <admin/index.html in> <out>.
Replaces the VIEWS.usage block, adds the CSS, and makes acct() drop any '@domain' so no email can show."""
import sys, re, pathlib
here = pathlib.Path(__file__).parent
src = pathlib.Path(sys.argv[1]).read_text()
a = src.index('// ---------- usage\nVIEWS.usage = (u, el) => {')
b = src.index('\n};\n', a) + 4
out = src[:a] + (here / 'usage_view.js').read_text() + src[b:]
out = out.replace('</style>', (here / 'usage_view.css').read_text() + '</style>', 1)
old = "esc(a==='corybogdan'?'Cory':a)"
assert out.count(old) == 1, 'acct() changed upstream'
out = out.replace(old, "esc(a==='corybogdan'?'Cory':String(a??'').replace(/@.*/,''))")
pathlib.Path(sys.argv[2]).write_text(out)
print('ok', len(src), '->', len(out))
