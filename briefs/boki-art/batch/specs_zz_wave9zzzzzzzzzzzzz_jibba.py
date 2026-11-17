# 12:40 ET 11-09 owner paste (12:37): Jibbatross = b2_2 (bigger head, open beak), not my b1_1. Redo sheet + card + portrait from b2_2.
# The b1_1-based ta_jibbatross_pb / jibbatross_cardb / portrait_jibbatross_pb outputs are not promoted.
_s='briefs/boki-art/batch/out/c_jibbatross_b2_2.jpg'
TA('Jibbatross',_s); SPECS[-1]['id']='ta_jibbatross_pc'
SPECS.append({'id':'jibbatross_cardc','name':'Jibbatross (hero card)','refs':[_s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Jibbatross','mid','gliding low with its wings spread wide and its sail filled with wind, beak open in an eager cry')})
P('jibbatross_pc','Jibbatross',_s,'gliding low with its wings spread wide and its sail filled with wind, beak open in an eager cry')
