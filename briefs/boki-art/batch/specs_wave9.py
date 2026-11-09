# Round 9 (21:10 ET 11-08): owner note "hero shots look straight at the camera, needs to be more interesting".
# P() now asks for a dynamic action hero shot, head turned, never looking at camera. Re-make every portrait already
# generated with the old prompt as portrait_<species>_r (same ref and pose, new prompt); unmade ones just use the new prompt.
import subprocess as _sp
_made={l.split('/')[-1].rsplit('_',1)[0] for l in _sp.run(['git','ls-tree','--name-only','HEAD','briefs/boki-art/batch/out/'],capture_output=True,text=True).stdout.split()
       if l.split('/')[-1].startswith('portrait_')}
for _x in list(SPECS):
    if _x['id'] in _made and not _x['id'].endswith('_r'):
        _y=dict(_x); _y['id']=_x['id']+'_r'; SPECS.append(_y)
