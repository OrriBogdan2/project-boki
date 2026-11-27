# oldnames.py IN OUT : measuring copy only. r31 renamed the skirt materials skirt-* -> cloth-* (slot fix); the r22-r26 measure
# scripts look up the old names. This writes a copy with the old names back (never ship it).
import sys; sys.path.insert(0,'tools/art1/hem_r17'); import glbio
M={'cloth-skirtmeshy':'skirt-meshy','cloth-skirtlining':'skirt-lining23','cloth-skirtliner':'skirt-liner','cloth-skirtgodet':'skirt-godet30'}
j,b=glbio.load(sys.argv[1])
for m in j['materials']: m['name']=M.get(m['name'],m['name'])
glbio.save(sys.argv[2],j,b)
