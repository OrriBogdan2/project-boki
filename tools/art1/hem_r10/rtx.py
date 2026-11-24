"""rtx.py NAME [--img PATH] [--text STR] : Meshy retexture of the r8b H2 gen (geometry + UVs kept) for a clean skirt texture."""
import sys, os, json, time, argparse
from importlib.machinery import SourceFileLoader
m = SourceFileLoader('b', '/home/boki/bin/boki3d-batch').load_module()
ap = argparse.ArgumentParser(); ap.add_argument('name'); ap.add_argument('--img'); ap.add_argument('--text')
ap.add_argument('--task', default='01a20a5f-3124-7002-92af-40ac154a0c08'); a = ap.parse_args()
d = '/home/boki/gens/lace-r10/rt/' + a.name; os.makedirs(d, exist_ok=True)
body = {'input_task_id': a.task, 'enable_original_uv': True, 'enable_pbr': False, 'ai_model': 'latest', 'texture_resolution': '2k'}
if a.img: body['image_style_url'] = m.data_uri(a.img)
if a.text: body['text_style_prompt'] = a.text
json.dump({k: v for k, v in body.items() if k != 'image_style_url'} | {'img': a.img}, open(d + '/request.json', 'w'), indent=1)
tid = m.call('POST', 'retexture', body)['result']; print(a.name, 'posted', tid, flush=True)
while True:
    t = m.call('GET', 'retexture/' + tid)
    if t.get('status') in ('SUCCEEDED', 'FAILED', 'CANCELED', 'EXPIRED'): break
    time.sleep(15)
json.dump(t, open(d + '/task.json', 'w'), indent=1); print(a.name, t['status'], 'credits', t.get('consumed_credits'), flush=True)
if t['status'] == 'SUCCEEDED':
    m.download(t['model_urls']['glb'], d + '/glb.glb')
    for k, u in (t.get('texture_urls') or [{}])[0].items():
        if k == 'base_color': m.download(u, d + '/base_color.png')
    print(a.name, 'done', flush=True)
