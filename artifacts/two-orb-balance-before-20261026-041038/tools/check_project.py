"""Local Godot import/parse smoke check, bounded to this new prototype."""
from pathlib import Path
import subprocess
from PIL import Image
root = Path(__file__).resolve().parents[1]
engine = r"C:\Users\user\Desktop\Godot_v4.6.2-stable_win64.exe"
for path in (root / 'assets/art').glob('*.png'):
    im = Image.open(path)
    print(path.name, im.size, im.mode)
result = subprocess.run([engine, '--headless', '--path', str(root), '--editor', '--import', '--quit'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
print(result.stdout[-5000:])
print(result.stderr[-10000:])
raise SystemExit(1 if 'SCRIPT ERROR' in result.stderr or 'ERROR:' in result.stderr else result.returncode)
