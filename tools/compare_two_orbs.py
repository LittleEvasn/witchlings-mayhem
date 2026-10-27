"""Compare paired production-runtime reports; finite clear time is not treated as sustained DPS."""
import argparse, collections, csv, json, statistics
from pathlib import Path

def load(path):
 return json.loads(path.read_text(encoding="utf-8"))["runs"]
def key(r):
 return r["build_id"],r["scenario"],r["seed"],r["motion"],r["aim"]
def sustained(r):
 timeline=r["timeline"]
 if r["scenario"]!="single" or len(timeline)<10:return None
 start=next(t for t in timeline if t["seconds"]>=3)
 end=timeline[-1]
 return (end["damage"]-start["damage"])/(end["seconds"]-start["seconds"])
def caps(r):
 return {k:v for k,v in r["totals"].items() if ("blocked" in k or "evicted" in k) and v}
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument("before",type=Path);parser.add_argument("after",type=Path);parser.add_argument("--output",type=Path,required=True)
 args=parser.parse_args()
 before={key(r):r for r in load(args.before)};after={key(r):r for r in load(args.after)}
 if before.keys()!=after.keys():raise ValueError("Pair keys differ")
 rows=[]
 for k,a in after.items():
  b=before[k]
  common=min(len(a["input_trace"]),len(b["input_trace"]))
  assert a["input_trace"][:common]==b["input_trace"][:common] and a["arrival_plan"]==b["arrival_plan"],("Mismatched shared inputs",k)
  rows.append(dict(build=k[0],scenario=k[1],seed=k[2],motion=k[3],aim=k[4],cost=a["purchase_cost"],before_window_dps=b["window_dps"],after_window_dps=a["window_dps"],before_sustained_dps=sustained(b),after_sustained_dps=sustained(a),before_kills=b["totals"].get("kills",0),after_kills=a["totals"].get("kills",0),before_clear=b["clear_seconds"],after_clear=a["clear_seconds"],before_received=b["totals"].get("player_damage",0),after_received=a["totals"].get("player_damage",0),before_evicted=b["totals"].get("zones_evicted",0),after_evicted=a["totals"].get("zones_evicted",0),before_cpu_p95=b["step_cpu_ms"]["p95"],after_cpu_p95=a["step_cpu_ms"]["p95"]))
 args.output.parent.mkdir(parents=True,exist_ok=True)
 with args.output.with_suffix(".csv").open("w",encoding="utf-8-sig",newline="") as f:
  writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
 summary={"paired_runs":len(rows),"before_affected_runs":sum(bool(caps(r)) for r in before.values()),"after_affected_runs":sum(bool(caps(r)) for r in after.values()),"after_max_step_p95_ms":max(r["step_cpu_ms"]["p95"] for r in after.values()),"after_max_step_p99_ms":max(r["step_cpu_ms"]["p99"] for r in after.values()),"after_limit_details":[dict(build=r["build_id"],scenario=r["scenario"],seed=r["seed"],motion=r["motion"],events=caps(r)) for r in after.values() if caps(r)]}
 args.output.with_suffix(".json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
 print(json.dumps(summary,indent=2))
if __name__=="__main__":main()
