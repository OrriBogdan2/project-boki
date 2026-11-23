import io, subprocess
from PIL import Image
import os; R=os.environ.get('BOKI_REPO', os.path.abspath(os.path.join(os.path.dirname(__file__),'../../..')))
def load(stem):
    """Load batch output <stem> (e.g. 'zipling_r_1') from git, jpg or png."""
    for e in ('jpg','png'):
        try:
            b=subprocess.check_output(['git','show',f'origin/ext/agent-briefs:briefs/boki-art/batch/out/{stem}.{e}'],cwd=R,stderr=subprocess.DEVNULL)
            return Image.open(io.BytesIO(b)).convert('RGB')
        except subprocess.CalledProcessError: pass
    raise FileNotFoundError(stem)
def stems():
    out=subprocess.check_output(['git','ls-tree','--name-only','origin/ext/agent-briefs','briefs/boki-art/batch/out/'],cwd=R,text=True).split()
    return sorted({p.rsplit('/',1)[1].rsplit('.',1)[0] for p in out})
