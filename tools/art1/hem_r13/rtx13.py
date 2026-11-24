"""rtx13.py OUT_DIR TASK_ID "text style prompt" : Meshy retexture (original UV, 2k, no PBR) of a skirt task; writes OUT_DIR/{glb.glb,base_color.png,task.json}."""
import sys, os, json, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../meshy'))
import meshy_task as m
d, tid_in, txt = sys.argv[1:4]; os.makedirs(d, exist_ok=True)
body = {'input_task_id': tid_in, 'enable_original_uv': True, 'enable_pbr': False, 'ai_model': 'latest', 'texture_resolution': '2k', 'text_style_prompt': txt}
json.dump(body, open(d + '/request.json', 'w'), indent=1)
tid = m.call('POST', m.BASE + 'retexture', body)['result']; print('posted', tid, flush=True)
while True:
    t = m.call('GET', m.BASE + 'retexture/' + tid)
    if t.get('status') in ('SUCCEEDED', 'FAILED', 'CANCELED', 'EXPIRED'): break
    time.sleep(15)
json.dump(t, open(d + '/task.json', 'w'), indent=1); print(t['status'], 'credits', t.get('consumed_credits'), flush=True)
if t['status'] == 'SUCCEEDED':
    m.download(t['model_urls']['glb'], d + '/glb.glb')
    for k, u in (t.get('texture_urls') or [{}])[0].items():
        if k == 'base_color': m.download(u, d + '/base_color.png')
