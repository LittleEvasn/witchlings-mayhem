from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
engine = r"C:\Users\user\Desktop\Godot_v4.6.2-stable_win64.exe"
test = sys.argv[1] if len(sys.argv) > 1 else 'prototype_test'
if test not in ('compact_rewards_test', 'survival_feedback_test', 'monster_expansion_test', 'gem_damage_feedback_test', 'movement_tempo_test', 'connector_scope_test', 'acquisition_ui_test', 'orb_growth_test', 'fixed_slots_test', 'survival_run_test', 'level_growth_test', 'support_fusions_test', 'checkpoint_collection_test', 'front_flow_test', 'crafting_vfx_test', 'round_ember_test', 'magic_v2_test', 'pressure_reward_test', 'combat_personal_ui_test', 'lumi_run_test', 'scroll_arena_test', 'relics_test', 'two_orb_measurement_test', 'modifier_upgrades_test', 'spell_roles_test', 'spell_program_test', 'prep_board_test', 'forge_test', 'orb_workbench_test', 'magic_builds_test', 'prototype_test', 'shop_flow_test', 'spell_expansion_test', 'workbench_test', 'measurement_test', 'waves_test', 'random_spawns_test', 'wave_balance_probe', 'wave_play_probe'):
    raise SystemExit('Unknown test suite')
result = subprocess.run([engine, '--headless', '--path', str(root), '--quit-after', '1200', '--script', f'res://tests/{test}.gd'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
log = result.stdout + '\n' + result.stderr
(root / 'artifacts').mkdir(exist_ok=True)
(root / 'artifacts' / f'{test.replace("_", "-")}-results.txt').write_text(log, encoding='utf-8')
print(log)
raise SystemExit(1 if 'SCRIPT ERROR' in log or 'ERROR:' in log or 'RESULT:' not in log else result.returncode)
