# 07:05 ET 11-09: retries (Selenwhale card+portrait 7.8; Dragonkite sheet failed twice -> from the concept with 2 extra runs).
_O='briefs/boki-art/batch/out/'
SPECS.append({'id':'selenwhale_cardx','name':'Selenwhale (hero card)','refs':[_O+'c_selenwhale_x1_4.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Selenwhale','final','floating majestically, cratered moon-dome head raised, fins spread wide')})
P('selenwhale_px','Selenwhale',_O+'c_selenwhale_x1_4.jpg','floating majestically, cratered moon-dome head raised, fins spread wide')
TA('Dragonkite',_O+'c_dragonkite_x1_3.jpg'); SPECS[-1]['id']='ta_dragonkite_rx'; SPECS[-1]['runs']=3
