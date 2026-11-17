"""Turnaround tracker. Every Boki needs a turnaround (sheet) drawn from its CURRENT card.
LIVE_MANIFEST[name]['sheet_for_card'] = hash of the card the sheet was approved against.
  python3 briefs/boki-art/tools/sheet_audit.py                -> list MISSING / STALE (card changed since the sheet was approved); exit 1 if any
  python3 briefs/boki-art/tools/sheet_audit.py mark Name ...  -> sheet checked by eye against the current card: record it as in sync
Run refresh_names.py first so hashes are current. A flat_card.py backdrop change alters the card hash: re-mark after checking."""
import json,os,sys
P='briefs/boki-art/LIVE_MANIFEST.json'; m=json.load(open(P))
if len(sys.argv)>1 and sys.argv[1]=='mark':
    for n in sys.argv[2:]: m[n]['sheet_for_card']=m[n]['hash']['card']
    json.dump(m,open(P,'w'),indent=1); print('marked',len(sys.argv)-2); sys.exit(0)
missing=[n for n,e in m.items() if not e.get('sheet') or not os.path.exists(e['sheet'])]
stale=[n for n,e in m.items() if n not in missing and e.get('sheet_for_card')!=e['hash']['card']]
print('Boki',len(m),'| MISSING',len(missing),missing,'| STALE',len(stale),sorted(stale)); sys.exit(1 if missing or stale else 0)
