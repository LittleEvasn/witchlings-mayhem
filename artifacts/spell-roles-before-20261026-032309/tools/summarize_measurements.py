"""Create per-scenario recipe leaderboards from a measurement CSV."""
import argparse
import csv
from collections import defaultdict
from pathlib import Path
from statistics import mean


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path, help="Summary CSV emitted by measure_spells.py")
    parser.add_argument("--output", type=Path, help="Output CSV; defaults to <input>-leaderboard.csv")
    args = parser.parse_args()
    output = args.output or args.csv.with_name(args.csv.stem + "-leaderboard.csv")
    grouped = defaultdict(list)
    with args.csv.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            duration = row.get("window_seconds", row.get("seconds", ""))
            key = (row["scenario"], row["recipe"], row["aim"], duration,
                   row.get("power", "1"), row.get("fire_rate", "1"))
            grouped[key].append(row)

    records = []
    for (scenario, recipe, aim, window_seconds, power, fire_rate), rows in grouped.items():
        number = len(rows)
        average = lambda field: mean(float(row[field]) for row in rows)
        cost = average("cost")
        dps = average("effective_dps")
        kills = average("kills")
        clear_times = [float(row["clear_seconds"]) for row in rows if float(row["clear_seconds"]) >= 0]
        records.append({
            "scenario": scenario, "recipe": recipe, "aim": aim, "window_seconds": window_seconds,
            "power": power, "fire_rate": fire_rate,
            "purchase_cost": round(average("purchase_cost"), 3) if "purchase_cost" in rows[0] else -1,
            "seeds": number, "clear_runs": len(clear_times), "clear_rate": round(len(clear_times) / number, 4), "cost": round(cost, 3),
            "mean_effective_dps": round(dps, 4), "mean_damage_per_gold": round(dps / cost, 5) if cost else 0,
            "mean_kills": round(kills, 4), "mean_kills_per_gold": round(kills / cost, 5) if cost else 0,
            "mean_clear_seconds": round(mean(clear_times), 4) if clear_times else -1,
            "mean_contact_rate": round(average("contact_rate"), 5),
            "mean_received_damage": round(average("player_damage"), 4),
            "mean_alive": round(average("mean_alive"), 4),
        })

    fields = list(records[0]) if records else []
    def conditions(record):
        return tuple(record[field] for field in ("scenario", "aim", "window_seconds", "power", "fire_rate"))
    for condition in sorted({conditions(record) for record in records}):
        subset = [record for record in records if conditions(record) == condition]
        for field, rank_name, reverse in (("mean_effective_dps", "rank_dps", True),
                                          ("mean_damage_per_gold", "rank_damage_per_gold", True),
                                          ("mean_kills", "rank_kills", True),
                                          ("mean_clear_seconds", "rank_clear_time", False)):
            sort_key = (lambda item: (item[field] < 0, item[field])) if rank_name == "rank_clear_time" else (lambda item: item[field])
            for rank, record in enumerate(sorted(subset, key=sort_key, reverse=reverse), 1):
                record[rank_name] = rank
    rank_fields = ["rank_dps", "rank_damage_per_gold", "rank_kills", "rank_clear_time"]
    fields.extend(rank_fields)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(records)
    print(f"{len(records)} recipe/environment rows saved to {output}")


if __name__ == "__main__":
    main()
