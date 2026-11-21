#!/usr/bin/env python3
"""Local test server: serves before/after admin pages + a mock /api (usage/data only). No real data.
python3 mock_api.py PORT  -> http://127.0.0.1:PORT/after_admin_index.html?api=http://127.0.0.1:PORT/api&token=t#usage
Lanes carry placeholder emails on purpose: live lanes got 'email+role' on 11-12, which is what the
owner wants gone. The after page must show none of them."""
import json, sys, time, random, http.server, pathlib
ROOT = pathlib.Path(__file__).parent


def usage():
    t = time.time(); H = 3600; random.seed(7)
    # label, pct, pace, reset in h, burn %/h, running, done24h, lane, coord
    A = [('ProjectBoki', 71, 64, 30, 0.6, 2, {'done': 5, 'partial': 1}, 'coord: acct1@example.com · deep jobs', True),
         ('Outlook 1', 77, 97, 2, 0.4, 1, {'done': 3}, 'acct2@example.com · build', False),
         ('Outlook 2', 17, 20, 132, 0.2, 0, {'done': 1, 'blocked': 1}, 'acct3@example.com (w2 lane)', False),
         ('OrriB', 75, 58, 70, 1.1, 2, {'done': 6, 'failed': 1}, 'acct4@example.com · deep', False),
         ('GC', 95, 80, 40, 0.9, 0, {'done': 4, 'skipped': 1}, 'acct5@example.com · admin', False),
         ('corybogdan', 22, 51, 20, 0.3, 1, {'done': 2}, 'acct6@example.com · art', False)]
    acc, series = [], []
    for lab, p, pace, rh, burn, run, d, lane, coord in A:
        to90 = round(max(0, 90 - p) / burn, 1) if burn > 0 else None
        acc.append({'label': lab, 'coord': coord, 'lane': lane, 'pct': p, 'pace_pct': pace, 'pace_gap': p - pace,
                    'resets_at': t + rh * H, 'fable_pct': 12 if lab == 'OrriB' else None, 'running': run, 'done_24h': d,
                    'spent_24h': round(burn * 24), 'ballistic': {'rate_h': burn, 'to90_h': to90, 'flag': 'fast' if burn > 1 else ''}})
        pts = [[t - (167 - i) * H, max(0, min(100, p - burn * (167 - i) * 0.6 + random.uniform(-1, 1)))] for i in range(0, 168, 3)]
        series.append({'label': lab, 'pts': pts, 'resets': []})
    days = [{'day': time.strftime('%Y-%m-%d', time.gmtime(t - k * 86400)), 'done': random.randint(8, 25), 'partial': random.randint(0, 4),
             'failed': random.randint(0, 3), 'skipped': random.randint(0, 2), 'blocked': random.randint(0, 2)} for k in range(6, -1, -1)]
    hours = [{'done': random.randint(0, 5), 'failed': random.randint(0, 1)} for _ in range(24)]
    return {'snapshot_at': t - 240, 'pacer_last_t': t - 900, 'accounts': acc, 'series': series, 'x0': t - 7 * 86400, 'x1': t,
            'jobs_per_day': days, 'jobs_per_hour': hours}


class Hd(http.server.SimpleHTTPRequestHandler):
    def __init__(s, *a, **k): super().__init__(*a, directory=str(ROOT), **k)
    def log_message(s, *a): pass
    def j(s, code, obj):
        b = json.dumps(obj).encode(); s.send_response(code); s.send_header('Content-Type', 'application/json')
        s.send_header('Content-Length', str(len(b))); s.end_headers(); s.wfile.write(b)
    def do_GET(s):
        p = s.path.split('?')[0]
        if p == '/api/me': return s.j(200, {'user': {'role': 'owner', 'display': 'Owner'}})
        if p == '/api/admin/usage/data': return s.j(200, usage())
        if p.startswith('/api/'): return s.j(404, {'error': 'mock: not served'})
        return super().do_GET()


http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), Hd).serve_forever()
