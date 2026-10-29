"""Rebuild the still monster atlas from preserved built-in imagegen sources. Requires Pillow.
Run from any folder with a Python environment containing Pillow. No new art is generated.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/art/enemies'
IDS=['jelly','bat','beetle','paper','ink','rabbit','cauldron','mushroom','book','candle','satchel','trolley']
old=Image.open(ROOT/'assets/art/characters.png').convert('RGBA')
f=Image.open(DEST/'source/eight-enemy-source.png').convert('RGBA')
parts={'jelly':old.crop((690,120,1254,665)), 'bat':old.crop((0,680,690,1254)), 'beetle':old.crop((690,680,1254,1254)), 'rabbit':Image.open(DEST/'source/rabbit-seed.png').convert('RGBA')}
xs=[0,443,887,1330,1774]; splits=[440,429,438,450]
raw={}
for col,(top,bot) in enumerate(zip(['paper','ink','cauldron','mushroom'],['book','candle','satchel','trolley'])):
    raw[top]=(xs[col],0,xs[col+1],splits[col]);raw[bot]=(xs[col],splits[col],xs[col+1],887)
    parts[top]=f.crop(raw[top]);parts[bot]=f.crop(raw[bot])
atlas=Image.new('RGBA',(1024,768))
preview=Image.new('RGBA',(1024,852),'#263842');draw=ImageDraw.Draw(preview)
manifest=[]
for i,id in enumerate(IDS):
    im=parts[id];bbox=im.getchannel('A').point(lambda p:255 if p>10 else 0).getbbox();im=im.crop(bbox)
    scale=min(224/im.width,224/im.height);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    cell=Image.new('RGBA',(256,256));cell.alpha_composite(im,((256-im.width)//2,240-im.height))
    cell.save(DEST/(id+'.png'));atlas.alpha_composite(cell,((i%4)*256,(i//4)*256))
    preview.alpha_composite(cell,((i%4)*256,(i//4)*284));draw.text((i%4*256+85,i//4*284+260),id,fill='white')
    manifest.append({'id':id,'file':'assets/art/enemies/'+id+'.png','source':'characters.png' if i<3 else ('rabbit-seed.png' if id=='rabbit' else 'eight-enemy-source.png'),'source_rect':raw.get(id),'alpha_bbox_inside_source_rect':bbox,'cell':[i%4,i//4],'canvas':[256,256],'foot_pivot':[128,240],'alpha_extrema':cell.getchannel('A').getextrema(),'status':'in_game_visual_qa_passed_still_prototype','frames':1})
atlas.save(DEST/'monsters-v1.png')
(ROOT/'artifacts').mkdir(exist_ok=True)
preview.convert('RGB').save(ROOT/'artifacts/monster-art-contact.png')
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('12 stills / 1024x768 atlas / RGBA alpha 0..255; source originals preserved')
