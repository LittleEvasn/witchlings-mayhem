"""Reproducible selected two-orb cohort. Not an exhaustive or equal-price optimizer."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
BUILDS = {
 "baseline": [["bolt"],["bloom"]],
 "meta_seek": [["seek","fan","bloom","impact","vortex"],["bolt"]],
 "meta_echo": [["fan","echo","bloom","impact","vortex"],["bolt"]],
 "meta_both": [["seek","fan","echo","bloom","impact","vortex"],["bolt"]],
 "focus": [["pierce","charge","bolt"],["frost","impact","thunder"]],
 "control": [["giant","vortex"],["bloom","expire","frost"]],
 "scatter": [["seek","bounce","bolt"],["fan","thunder"]],
 "mobility": [["giant","ember_path"],["satellite"]],
 "traps": [["pierce","thorn","expire","bloom"],["boomerang"]],
 "timing": [["echo","bolt"],["bloom"]],
 "ranked": [["fan@2","bolt","impact","bloom"],["pierce","bolt"]],
}
SCENARIOS = ["single","cluster","line","scatter","pressure","moving_heavy","relocation"]
def jobs():
 result = [dict(id=name,bank=bank,scenario=scenario,seed=seed,aim="replay",seconds=15) for name,bank in BUILDS.items() for scenario in SCENARIOS for seed in [731,1151,2026]]
 # Matched-cost ablations: each removes one support; no fictitious filler purchase.
 for name, bank in {
  "bloom_chain": [["bloom","impact","vortex"],["bolt"]],
  "fan_chain": [["fan","bloom","impact","vortex"],["bolt"]],
  "seek_chain": [["seek","bloom","impact","vortex"],["bolt"]],
  "echo_chain": [["echo","bloom","impact","vortex"],["bolt"]],
  "double_meta": [["fan","echo","bloom","impact","vortex"],["fan","echo","bloom","impact","vortex"]],
  "deep_chain": [["fan","bolt","impact","bloom","expire","thunder"],["bolt"]],
  "charge_stack": [["charge","charge","charge","bolt"],["bolt"]],
  "fan_stack": [["fan","fan","fan","bolt"],["bolt"]],
  "echo_stack": [["echo","echo","echo","bolt"],["bolt"]],
  "frost_chain": [["frost","impact","thunder"],["bolt"]],
 }.items():
  for scenario in ["single","cluster","pressure"]:
   result.append(dict(id=name,bank=bank,scenario=scenario,seed=731,aim="replay",seconds=15))
 # Shared orbit motion brings close-range attacks into range, without build-specific autopilot.
 for name in ["baseline","meta_both","focus","control","mobility","traps","scatter"]:
  for scenario in ["single","cluster","line"]:
   result.append(dict(id=name,bank=BUILDS[name],scenario=scenario,seed=731,aim="replay",seconds=15,options={"motion":"orbit"}))
 return result
if __name__ == "__main__":
 output=ROOT/"artifacts/measurements/two-orb-cohort.json"
 output.parent.mkdir(parents=True,exist_ok=True)
 output.write_text(json.dumps(dict(jobs=jobs(),quiet=True),ensure_ascii=False,indent=2),encoding="utf-8")
 print(f"{len(jobs())} selected cases: {output}")
