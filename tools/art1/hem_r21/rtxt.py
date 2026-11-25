# rtxt.py OUT_DIR model.glb "text style" : Meshy retexture of an uploaded glb, original UV, text style, no PBR
import sys,os,json,time,base64
sys.path.insert(0,'tools/meshy'); import meshy_task as m
d,src,txt=sys.argv[1:4]; os.makedirs(d,exist_ok=True)
body={'model_url':'data:application/octet-stream;base64,'+base64.b64encode(open(src,'rb').read()).decode(),'enable_original_uv':True,'enable_pbr':False,'ai_model':'meshy-7','texture_resolution':'2k','text_style_prompt':txt,'target_formats':['glb']}
json.dump({k:(v if k!='model_url' else src) for k,v in body.items()},open(d+'/request.json','w'),indent=1)
tid=m.call('POST',m.BASE+'retexture',body)['result']; print('posted',tid,flush=True)
while True:
    t=m.call('GET',m.BASE+'retexture/'+tid)
    if t.get('status') in ('SUCCEEDED','FAILED','CANCELED','EXPIRED'): break
    time.sleep(15)
json.dump(t,open(d+'/task.json','w'),indent=1); print(t['status'],'credits',t.get('consumed_credits'),flush=True)
if t['status']=='SUCCEEDED':
    m.download(t['model_urls']['glb'],d+'/glb.glb')
    for k,u in (t.get('texture_urls') or [{}])[0].items():
        if u: m.download(u,d+'/tex_%s.png'%k)
