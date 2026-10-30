#!/usr/bin/env python3
"""Build the existing Godot training scene for browsers; original project unchanged."""
from __future__ import annotations
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOURCES = ("assets", "scenes", "scripts")
SCENE = 'run/main_scene="res://scenes/training.tscn"'

def patched_project(original: str) -> str:
    result, count = re.subn(r'(?m)^run/main_scene="res://scenes/main\.tscn"\s*$',
                            SCENE, original, count=1)
    if count != 1:
        raise ValueError("Expected original main scene not found in project.godot")
    lines = []
    section = ""
    for line in result.splitlines():
        if line.startswith("[") and line.endswith("]"):
            section = line
        if section == "[autoload]" and "res://addons/" in line:
            continue
        if section == "[editor_plugins]" and line.startswith("enabled="):
            continue
        lines.append(line)
    return "\n".join(lines) + "\n"

def prepare(source: pathlib.Path, target: pathlib.Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for folder in RESOURCES:
        src = source / folder
        if not src.is_dir():
            raise FileNotFoundError(f"Missing Godot folder: {src}")
        shutil.copytree(src, target / folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".godot", "*.tmp"))
    for name in ("icon.svg", "export_presets.cfg"):
        if (source / name).is_file():
            shutil.copy2(source / name, target / name)
    (target / "project.godot").write_text(
        patched_project((source / "project.godot").read_text(encoding="utf-8")),
        encoding="utf-8")
    if not (target / "scenes/training.tscn").is_file():
        raise FileNotFoundError("Training scene missing")
    if 'name="Web Magic Lab"' not in (target / "export_presets.cfg").read_text(encoding="utf-8"):
        raise ValueError("Web Magic Lab export preset missing")

def run(command: list[str]) -> None:
    print("$ " + " ".join(command), flush=True)
    subprocess.run(command, check=True)

def build(godot: str, source: pathlib.Path, output: pathlib.Path, skip_smoke: bool, ai_autoplay: bool = False) -> None:
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="witchlings-web-lab-") as temp:
        stage = pathlib.Path(temp)
        prepare(source, stage)
        run([godot, "--headless", "--path", str(stage), "--import"])
        if not skip_smoke:
            run([godot, "--headless", "--path", str(stage), "--quit-after", "60"])
        if ai_autoplay:
            (stage / "tests").mkdir(exist_ok=True)
            shutil.copy2(source / "tests/ai_autoplay_test.gd",
                         stage / "tests/ai_autoplay_test.gd")
            report = source / "artifacts/ai-autoplay/report.json"
            report.parent.mkdir(parents=True, exist_ok=True)
            env = os.environ.copy()
            env["AI_AUTOPLAY_OUTPUT"] = str(report)
            command = [godot, "--headless", "--path", str(stage),
                       "--script", "res://tests/ai_autoplay_test.gd"]
            print("$ " + " ".join(command), flush=True)
            subprocess.run(command, check=True, env=env, timeout=900)
            if not report.is_file():
                raise RuntimeError("AI autoplay report missing: " + str(report))
            shutil.rmtree(stage / "tests")
        run([godot, "--headless", "--path", str(stage),
             "--export-release", "Web Magic Lab", str(output / "index.html")])
    missing = [f for f in ("index.html", "index.js", "index.wasm", "index.pck")
               if not (output / f).is_file()]
    if missing:
        raise RuntimeError("Missing Web export files: " + ", ".join(missing))
    (output / ".nojekyll").write_text("", encoding="utf-8")
    print("Web Magic Lab exported:", output, flush=True)

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot", default="godot")
    p.add_argument("--project", type=pathlib.Path, default=ROOT)
    p.add_argument("--output", type=pathlib.Path, default=ROOT / "artifacts/web-lab")
    p.add_argument("--skip-smoke", action="store_true")
    p.add_argument("--ai-autoplay", action="store_true", help="Execute 60-item Godot AI-play audit before exporting")
    p.add_argument("--prepare-only", type=pathlib.Path)
    a = p.parse_args()
    try:
        if a.prepare_only:
            prepare(a.project.resolve(), a.prepare_only.resolve())
            print("Staged project:", a.prepare_only.resolve())
        else:
            build(a.godot, a.project.resolve(), a.output.resolve(), a.skip_smoke, a.ai_autoplay)
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
