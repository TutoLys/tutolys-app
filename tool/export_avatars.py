"""Exports the avatar art (docs/design/AVATARS.md) to 512px webp under 120 KB.

The source art stays untouched in Lab/Tutolys/Assets/imgs/avatars. Each entry
names its source file and a square crop around the head and shoulders, in
pixels of a 300px-long-side thumbnail, or None for art already framed that
way. Full-body art has to be cropped, because the app shows avatars in a
circle as small as 30px.

    python3 -I tool/export_avatars.py
"""
import os, sys, io
from PIL import Image, ImageDraw
SRC=os.environ.get('AVATAR_SRC', os.path.join(os.path.dirname(__file__), '../../../Assets/imgs/avatars'))
OUT = os.environ.get('AVATAR_OUT', os.path.join(os.path.dirname(__file__), '../assets/images'))
# file key: (source, (centre x, centre y, side) or None)
P = {
 'kid-braids':('Glossy Braided Girl Avatar.png',None), 'kid-freckles':('Freckled Auburn-Haired Boy Avatar-1.png',None),
 'camper-girl':('Cheerful Camper Girl Avatar.png',None), 'camper-boy':('Cheerful Camper Adventurer Portrait.png',None),
 'explorer-girl':('Cheerful Young Explorer Adventure Portrait.png',None), 'explorer-boy':('Cheerful Cartoon Explorer with Map-1.png',None),
 'tuque-girl':('ChatGPT Image Oct 25, 2026, 12_42_49 PM-2.png',None),
 'captain-girl':('Cheerful Girl Captain with Spyglass-2.png',None), 'captain-boy':('Cheerful Young Captain with Spyglass-3.png',None),
 'hero-girl':('Flying Blue Superhero Girl-2.png',(165,120,190)), 'hero-boy':('Joyful Blue Superhero in Flight-2.png',(160,105,180)),
 'artist-girl':('Cheerful Jumping Artist Girl.png',(160,90,160)), 'artist-boy':('Cheerful 3D Paintbrush Artist Boy.png',(160,100,160)),
 'scientist-girl':('ChatGPT Image Oct 25, 2026, 02_27_53 PM-2.png',(150,120,170)), 'scientist-boy':('ChatGPT Image Oct 25, 2026, 02_27_52 PM-1.png',(160,120,170)),
 'chemist-girl':('Leaping Science Girl with Glowing Flasks-2.png',(150,100,170)), 'chemist-boy':('Jumping Kid Scientist with Glowing Flask-1.png',(150,95,170)),
 'mathematician-girl':('Eureka Math Adventure.png',(120,80,150)), 'mathematician-boy':('Math Adventure with a Cheerful Fox.png',(150,80,150)),
 'french-teacher-girl':('Cheerful French Teacher Adventure.png',(135,80,140)), 'french-teacher-boy':('Cheerful French Teacher Mascot.png',(95,70,140)),
 'english-girl':('Cheerful English Learning Adventure.png',(135,95,150)), 'english-boy':('Cheerful English Learning Classroom Mascot.png',(115,90,150)),
 'historian-girl':('Adventurous Young Historian Explorer.png',(130,110,150)), 'historian-boy':('Cheerful Explorer of History.png',(110,105,150)),
 'knight-girl':('Cheerful Blue Crest Girl Knight-2.png',(140,150,200)), 'knight-boy':('Cheerful Blue-Crested Knight.png',(140,150,200)),
 'fleur-knight-girl':('Cheerful Fleur-de-Lis Knight-1.png',(150,160,200)), 'fleur-knight-boy':('Cheerful Knight with Sword and Shield-1.png',(150,155,200)),
 'wizard-girl':('Joyful Girl Wizard Casting Magic-1.png',(170,120,170)), 'wizard-boy':('Joyful Wizard Boy Casting Magic-2.png',(145,105,170)),
 'astronaut-girl':('Cheerful Girl Astronaut Portrait-1.png',None), 'astronaut-boy':('ChatGPT Image Oct 25, 2026, 12_58_25 PM-2.png',None),
 'coder-girl':('Cheerful Cyber Coder Adventure.png',(100,115,150)), 'coder-boy':('Young Cyber Coder Adventure.png',(100,85,150)),
 'hist-therese-casgrain':('Thérèse Casgrain_ Vote for Equality.png',(125,65,110)),
 'hist-rene-levesque':('Québec Statesman with Flag and Fleur-de-Lis.png',(165,68,120)),
 'pirate':('Cheerful Pirate Captain Adventure.png',(115,110,160)), 'mermaid':('ChatGPT Image Oct 25, 2026, 02_44_27 PM-2.png',(160,90,160)),
}
def knock_out_black(im):
    # flood the near-black backdrop from the corners (no alpha in the source)
    im = im.convert('RGBA'); w,h = im.size
    mask = Image.new('L', im.size, 0)
    rgb = im.convert('RGB')
    for corner in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]:
        ImageDraw.floodfill(rgb, corner, (255,0,255), thresh=40)
    px = rgb.load(); alpha = im.getchannel('A'); a = alpha.load()
    for y in range(h):
        for x in range(w):
            if px[x,y]==(255,0,255): a[x,y]=0
    im.putalpha(alpha)
    return im

def build(key):
    f, crop = P[key]
    im = Image.open(os.path.join(SRC,f))
    im = knock_out_black(im) if im.mode!='RGBA' and key.startswith('astronaut') else im.convert('RGBA')
    W,H = im.size; s = max(W,H)/300
    if crop is None:
        side = max(W,H); cx, cy = W/2, H/2
    else:
        cx, cy, side = crop[0]*s, crop[1]*s, crop[2]*s
    box = (round(cx-side/2), round(cy-side/2), round(cx+side/2), round(cy+side/2))
    canvas = Image.new('RGBA', (box[2]-box[0], box[3]-box[1]), (0,0,0,0))
    canvas.paste(im.crop((max(box[0],0),max(box[1],0),min(box[2],W),min(box[3],H))), (max(-box[0],0), max(-box[1],0)))
    out = canvas.resize((512,512), Image.LANCZOS)
    for q in (86,80,72,64):
        b = io.BytesIO(); out.save(b,'WEBP',quality=q,method=6)
        if b.tell() < 120*1024: break
    open(f'{OUT}/avatar-{key}.webp','wb').write(b.getvalue())
    return f, b.tell(), q

for k in P:
    f,n,q = build(k); print(f'{k:22} {n//1024:4} KB q{q}  <- {f}')
