"""Normalize licensed local VFX for runtime; never downloads or redistributes the pack."""
from pathlib import Path
from PIL import Image
import json, shutil
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parent/'cartoon-coffee-free-minipack-40-vfx'/'Cartoon Coffee Free Minipack - 40 VFX'
DEST=ROOT/'assets/vfx/cartoon_coffee'
CHOICES={
 'bullet':('Projectile_Bullet_spritesheet.png',3,9),
 'explosion':('Explosion_Bomb_V1_spritesheet.png',8,64),
 'wind':('Charge_Wind_Loop_White_v4_A_spritesheet.png',8,64),
 'moon':('Blue Slash v2_spritesheet.png',4,16),
 'fire':('Bonfire_v8_A_spritesheet.png',8,64),
 'star':('Star_Flash_V2_spritesheet.png',4,16),
 'impact':('Impact_Hit_Lv2_spritesheet.png',4,16),
 'shockwave':('Impact_Shockwave v2_spritesheet.png',4,16),
}
def main():
 DEST.mkdir(parents=True,exist_ok=True)
 manifest={'source':str(SOURCE),'frame_pixels':192,'effects':{},'terms':'Project use including commercial allowed; standalone redistribution/sharing prohibited. See LICENSE-SOURCE.txt.'}
 for key,(name,grid,count) in CHOICES.items():
  path=SOURCE/'Spritesheets'/name
  image=Image.open(path).convert('RGBA')
  image=image.resize((grid*192,grid*192),Image.Resampling.LANCZOS)
  image.save(DEST/(key+'.png'),optimize=True)
  manifest['effects'][key]={'source':name,'grid':grid,'frames':count,'size':list(image.size)}
 shutil.copy2(SOURCE/'More Info.txt',DEST/'LICENSE-SOURCE.txt')
 (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'effects':len(CHOICES),'rgba_mib':sum((g*192)**2*4 for _,g,_ in CHOICES.values())/1048576,'destination':str(DEST)},indent=2))
if __name__=='__main__': main()
