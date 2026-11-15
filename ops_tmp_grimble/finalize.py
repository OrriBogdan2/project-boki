import os,shutil,subprocess
H=os.path.dirname(os.path.abspath(__file__)); F=H+'/final'
D='/home/boki/meshy/grimble-chain-1115'; V='/home/boki/meshy/v95'
SRC='/home/boki/jobq/done/20261115-204531-32755/out/A2.glb'
def sh(c):
    r=subprocess.run(c,shell=True,capture_output=True,text=True); print("$",c[:100],"rc",r.returncode,(r.stdout+r.stderr)[-500:]); return r
os.makedirs(D+'/tools',exist_ok=True)
assert os.path.getsize(SRC)>60e6
shutil.copy(SRC,D+'/A2.glb'); shutil.copy(SRC,V+'/Grimble/r5/cg3d1115/A2.glb')
for f in ('sheet.jpg','turntable.mp4','answer.md'): shutil.copy(F+'/'+f,D+'/'+f)
for f in ('common.py','del.py','inpaint_lib.py','views.py','zoom2.py','ana2.py','prof.py'): shutil.copy(H+'/'+f,D+'/tools/'+f)
ov=V+'/CURRENT_OVERRIDES.txt'; shutil.copy(ov,D+'/CURRENT_OVERRIDES.before')
L=open(ov).read().split('\n'); out=[]; done=False
NEW=("Grimble r5/cg3d1115/A2.glb face # 11-15 (job 20261115-193602-a3, grimble-chain-1115): A minus the shorter gold chain on the viewer's right of the face (detached rope tube deleted + capped, tooth texels repainted); everything else identical; sheet /home/boki/meshy/grimble-chain-1115/sheet.jpg")
for l in L:
    if l.startswith('Grimble r5/cg3d1115/A.glb') and not done:
        out.append('# superseded 11-15 (grimble-chain-1115, job 20261115-193602-a3): '+l); out.append(NEW); done=True
    else: out.append(l)
print("FOUND_A_LINE",done)
if done:
    open(ov,'w').write('\n'.join(out)); open(D+'/OVERRIDE_LINES.txt','w').write(NEW+'\n')
sh(f'grep -n Grimble {ov} | cut -c1-140; ls -la {D}')
sh('grep -v "^#" ~/.ssh/config 2>/dev/null | grep -i -E "^host|hostname" | head -20; ls ~/.ssh 2>&1 | head')
