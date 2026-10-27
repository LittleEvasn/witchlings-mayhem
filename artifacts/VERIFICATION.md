# Prototype 0.1 verification

Date: 2026-10-20. Engine: Godot 4.6.2 GL Compatibility. Local Windows machine.

## Functional checks

`prototype-tests.txt`: 34 checks passed, zero failures, no script/runtime errors in that run.
Scope: spell syntax, two-stage trigger-once behavior, fan/homing/pierce/area damage, normalized movement,
dash cooldown/invulnerability, hit grace period, XP pickup, recipe changes, reward transitions, boss victory,
player death, restart, bounded populations, stale spatial-grid entries.

## Actual rendered game checks

- Title start button clicked through a Godot viewport mouse event: entered combat.
- Tab key event: opened editor. Recommendation and Apply buttons clicked: recipe changed to bolt/fan/impact/bloom.
- Reward choice and Continue buttons clicked: unlocked homing and advanced the wave.
- Esc key events: pause and resume both worked.
- A short controlled combat scenario used all three enemy types and real movement/aim input.
  Observed 29 enemies at peak, 47 damage hits, 16 child spell triggers, 9 kills, and 60 FPS at the sample point.
  This is a short local check, not a long-duration benchmark or proof of difficulty balance.
- Screenshots inspected: title, combat, recipe editor and rewards. Combat screenshot is a controlled wave-3 scenario,
  not a claim that a human completed three waves in six seconds.

## Issues found and corrected

- Title portrait inherited the texture's minimum size before sizing; fixed initialization order.
- Progress bars retained default theme height; deferred final size after minimum-size invalidation.
- A spatial query between physics frames could see a freed enemy; filtered invalid entries.
- Native test helper eval initially used spaces under a tab-indented wrapper; corrected test invocation indentation.

## Limits

No human playthrough, subjective fun verdict, long-session soak test, multiplayer test or release-export test.
The generated art uses a single pose per actor with transform animation. Character attack animation, richer VFX,
more spell variety, balance tuning and persistent progression remain future work.
