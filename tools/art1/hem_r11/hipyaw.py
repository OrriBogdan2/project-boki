import sys, numpy as np
sys.path.insert(0, sys.argv[2]); from zerow import load, acc
j, b = load(sys.argv[1]); names = [n.get('name') for n in j['nodes']]
for a in j['animations']:
    for ch in a['channels']:
        n = names[ch['target']['node']]
        if n in ('Hips', 'Armature', 'root', 'Root') and ch['target']['path'] in ('rotation', 'translation'):
            s = a['samplers'][ch['sampler']]; t = acc(j, b, s['input'])[:, 0]; v = acc(j, b, s['output'])
            if ch['target']['path'] == 'rotation':
                x, y, z, w = v.T; yaw = np.degrees(np.arctan2(2 * (w * y + x * z), 1 - 2 * (y * y + x * x)))
                flips = int((np.sum(v[1:] * v[:-1], axis=1) < 0).sum())
                print('%-24s %-6s rot keys %3d len %.2fs yaw min %.0f max %.0f max step %.0f deg, sign flips %d ; yaw@0.4/1.0/1.6 = %s' % (a['name'], n, len(t), t[-1], yaw.min(), yaw.max(), np.abs(np.diff(yaw)).max() if len(t) > 1 else 0, flips, [round(float(np.interp(q, t, yaw))) for q in (0.4, 1.0, 1.6)]))
            else:
                print('%-24s %-6s pos keys %3d  x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f' % (a['name'], n, len(t), v[:, 0].min(), v[:, 0].max(), v[:, 1].min(), v[:, 1].max(), v[:, 2].min(), v[:, 2].max()))
