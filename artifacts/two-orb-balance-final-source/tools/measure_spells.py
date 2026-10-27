"""Local Godot simulation. No model or API requests are made by this tool."""
from pathlib import Path
import argparse
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = ("single", "cluster", "line", "scatter", "pressure", "moving_heavy", "relocation")

def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recipe", action="append", help="Comma-separated orb IDs. Repeat to compare recipes.")
    parser.add_argument("--bank", action="append", help='JSON two-row loadout, e.g. [["bolt"],["bloom"]]; repeat to compare banks')
    parser.add_argument("--motion", choices=("scenario","stationary","orbit"), default="scenario")
    parser.add_argument("--economy-route", choices=("merge","paid"), default="merge")
    parser.add_argument("--scenario", choices=(*SCENARIOS, "all"), default="all")
    parser.add_argument("--seeds", default="731", help="Comma-separated integer seeds")
    parser.add_argument("--aim", choices=("replay", "nearest", "fixed", "build"), default="replay")
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--power", type=float, default=1)
    parser.add_argument("--fire-rate", type=float, default=1)
    parser.add_argument("--input", type=Path, help="JSON job list, or object with a jobs list; overrides recipe options")
    parser.add_argument("--allow-large-run", action="store_true", help="Explicitly allow more than 2000 local simulations")
    parser.add_argument("--kit", choices=("garden","charge","sigil","frost"), default="sigil")
    parser.add_argument("--all-valid", action="store_true", help="Legacy single-orb subset only; NOT exhaustive for sequential/duplicate/ranked/two-orb programs")
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/measurements/latest")
    parser.add_argument("--engine", default=r"C:\Users\user\Desktop\Godot_v4.6.2-stable_win64.exe")
    args = parser.parse_args()
    if args.input:
        data = json.loads(args.input.read_text(encoding="utf-8-sig"))
        jobs = data["jobs"] if isinstance(data, dict) else data
        compact = bool(data.get("compact", False)) if isinstance(data, dict) else False
        quiet = bool(data.get("quiet", False)) if isinstance(data, dict) else False
    else:
        recipes = [json.loads(s) for s in args.bank] if args.bank else generate_valid_recipes(args.engine) if args.all_valid else [s.split(",") for s in args.recipe] if args.recipe else [["seek","fan","bloom","impact","vortex"]]
        layouts = SCENARIOS if args.scenario == "all" else (args.scenario,)
        try:
            seeds = [int(s) for s in args.seeds.split(",")]
        except ValueError:
            parser.error("Seeds must be integers")
        jobs = [dict(recipe=recipe, scenario=scenario, seed=seed,
                     aim=args.aim, seconds=args.seconds, power=args.power, fire_rate=args.fire_rate, kit=args.kit, options=dict(motion=args.motion,economy_route=args.economy_route))
                for recipe in recipes for scenario in layouts for seed in seeds]
        compact = args.all_valid
        quiet = args.all_valid
    if not jobs or any(not 0 < float(j.get("seconds",15)) <= 120 or
                       not 0 < float(j.get("power",1)) <= 100 or
                       not 0 < float(j.get("fire_rate",1)) <= 10 for j in jobs):
        parser.error("Supply jobs with duration (0,120], power (0,100], fire rate (0,10]")
    if len(jobs)>2000 and not args.allow_large_run:
        parser.error(f"{len(jobs):,} simulations requested. Narrow recipes/scenarios or explicitly use --allow-large-run.")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    request = output.with_name(output.name + "-request.json")
    request.write_text(json.dumps(dict(jobs=jobs, output=output.as_posix(), compact=compact, quiet=quiet), ensure_ascii=False), encoding="utf-8")
    with output.with_name(output.name+"-log.txt").open("w",encoding="utf-8") as logfile:
        result = subprocess.Popen([args.engine, "--headless", "--path", str(ROOT), "--script",
                                   "res://tests/measurement_batch.gd", "--", str(request)],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                  encoding="utf-8", errors="replace")
        lines = []
        for line in result.stdout:
            print(line,end="",flush=True)
            logfile.write(line)
            lines.append(line)
        code = result.wait(timeout=max(60, len(jobs)*10))
    log = "".join(lines)
    if code or "SCRIPT ERROR" in log or "ERROR:" in log or "RESULT:" not in log:
        raise SystemExit(code or 1)
    print("JSON:", output.with_suffix(".json"))
    print("CSV: ", output.with_suffix(".csv"))

def generate_valid_recipes(engine=r"C:\Users\user\Desktop\Godot_v4.6.2-stable_win64.exe"):
    """Read production definitions from Godot; do not duplicate the catalog in Python."""
    from itertools import combinations
    catalog = ROOT / "artifacts/measurements/spell-catalog.json"
    catalog.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run([engine, "--headless", "--path", str(ROOT), "--script",
                             "res://tools/spell_catalog.gd", "--", str(catalog)],
                             capture_output=True, text=True, encoding="utf-8", timeout=30)
    if result.returncode or "SCRIPT ERROR" in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    data = json.loads(catalog.read_text(encoding="utf-8"))
    recipes = []
    for attack in data["attacks"]:
        for count in range(6):
            for prefix in combinations(data["allowed"][attack], count):
                recipes.append([*prefix, attack])
        for second in data["attacks"]:
            for connector in data["connectors"]:
                if connector == "on_return" and attack != "boomerang":
                    continue
                for first_count in range(4):
                    for first_prefix in combinations(data["allowed"][attack], first_count):
                        for second_count in range(4-first_count):
                            for second_prefix in combinations(data["allowed"][second], second_count):
                                recipes.append([*first_prefix, attack, connector, *second_prefix, second])
    return recipes

if __name__ == "__main__":
    main()
