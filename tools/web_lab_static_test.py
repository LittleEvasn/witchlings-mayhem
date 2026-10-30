#!/usr/bin/env python3
"""Web export staging tests, runnable without Godot."""
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_web_lab

class WebLabTests(unittest.TestCase):
    def test_training_scene_is_web_startup(self):
        with tempfile.TemporaryDirectory() as folder:
            target = pathlib.Path(folder) / "stage"
            build_web_lab.prepare(ROOT, target)
            p = (target / "project.godot").read_text(encoding="utf-8")
            self.assertIn('run/main_scene="res://scenes/training.tscn"', p)
            self.assertNotIn('run/main_scene="res://scenes/main.tscn"', p)
            self.assertNotIn("res://addons/godot_ai/runtime/game_helper.gd", p)
            self.assertTrue((target / "scripts/spell_runtime.gd").is_file())
            self.assertTrue((target / "scripts/magic_catalog.gd").is_file())
            self.assertFalse((target / "addons").exists())

    def test_original_main_scene_preserved(self):
        p = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://scenes/main.tscn"', p)

    def test_web_export_is_single_thread(self):
        p = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('name="Web Magic Lab"', p)
        self.assertIn('platform="Web"', p)
        self.assertIn("variant/thread_support=false", p)

if __name__ == "__main__":
    unittest.main()
