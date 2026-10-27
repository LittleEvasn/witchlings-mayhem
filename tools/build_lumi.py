"""Build a local portable Windows test executable. Never publishes or changes user saves."""
from pathlib import Path
import subprocess, hashlib, json
ROOT=Path(__file__).resolve().parents[1]
ENGINE=Path('C:/Users/user/Desktop/Godot_v4.6.2-stable_win64.exe')
DEST=ROOT/'artifacts/builds/lumi-run'
DEST.mkdir(parents=True,exist_ok=True)
before=hashlib.sha256((ROOT/'project.godot').read_bytes()).hexdigest()
result=subprocess.run([str(ENGINE),'--headless','--path',str(ROOT),'--export-release','Windows Lumi',str(DEST/'WitchlingsMayhem.exe')],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
log=result.stdout+'\n'+result.stderr
(DEST/'build.log').write_text(log,encoding='utf-8')
errors=[line for line in log.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
output=DEST/'WitchlingsMayhem.exe'
ok=result.returncode==0 and not errors and output.exists()
unchanged=before==hashlib.sha256((ROOT/'project.godot').read_bytes()).hexdigest()
report={'ok':ok,'project_config_unchanged':unchanged,'exit_code':result.returncode,'bytes':output.stat().st_size if output.exists() else 0,'sha256':hashlib.sha256(output.read_bytes()).hexdigest() if output.exists() else None,'errors':errors}
(DEST/'build-result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(0 if ok and unchanged else 1)
