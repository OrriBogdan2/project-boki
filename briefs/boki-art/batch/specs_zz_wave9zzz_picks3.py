# 07:05 ET 11-09: Gloamspire + Selenwhale finals (eye-checked: gnarlier/epic surprise finals) -> sheet+card+portrait (_py); retries of failed sheets/cards.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
for n,src,pose in [('Gloamspire','c_gloamspire_x1_4','planted in a pool of shadow, crystal spire glowing'),('Selenwhale','c_selenwhale_x1_4','breaching upward, cratered moon-dome head catching the light')]:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_py'
    SPECS.append({'id':f'{l}_cardy','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,'final',pose)})
    P(f'{l}_py',n,s,pose)
for n,src in [('Dragonkite','c_dragonkite_x1_3'),('Geodemole','c_geodemole_x1_2'),('Stormit','c_stormit_x1_4'),('Terrarimit','c_terrarimit_x1_3')]:
    TA(n,_C+n+'.jpg'); SPECS[-1]['id']=f'ta_{n.lower()}_ry'
SPECS.append({'id':'glaciatee_cardy','name':'Glaciatee (hero card, planted)','refs':[_C+'Glaciatee.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Glaciatee','final','hauled out and planted heavy on an ice floe, tusks lowered. Same design as image 1, only the pose changes.')})
SPECS.append({'id':'umbrathere_cardy','name':'Umbrathere (hero card, planted)','refs':[_C+'Umbrathere.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Umbrathere','final','hanging planted from a dead branch by its claws, bony umbrella wings wrapped around it. Same design as image 1, only the pose changes.')})
