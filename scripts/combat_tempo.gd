extends RefCounted
## Initial walking/evading balance. World units are ours, not imported VS pixels.
const PLAYER_SPEED:=200.0
const DASH_SPEED:=520.0
const DASH_SECONDS:=0.20
const DASH_COOLDOWN:=1.7
const ENEMY_SPEED:=[0.0,90.0,65.0,82.0]
const SWARM_SPEED:=72.0
const CARRIER_SPEED:=168.0
const ESCORT_SPEED:=112.0
const SENTINEL_SPEED:=130.0
const CHARGE_SPEED:=280.0
const CHARGE_SECONDS:=1.1
const CHARGE_WINDUP:=1.05
const CHARGE_RECOVERY:=0.9
const CHARGE_COOLDOWN:=4.4
const SEPARATION_SPEED:=30.0
const SHOT_SPEED:=140.0
const BOSS_DASH_SPEED:=300.0
const BOSS_SHOT_SPEED:=160.0

static func enemy_speed(kind: int, role: String, wave: int, boss := false) -> float:
	if boss: return 48.0 # Boss walking/dashes use their own attack controller.
	var tier:=clampi(wave,1,5)
	match role:
		"carrier": return CARRIER_SPEED
		"escort": return ESCORT_SPEED
		"sentinel": return SENTINEL_SPEED+tier*2
		"swarm": return SWARM_SPEED+tier
	return ENEMY_SPEED[kind]+tier*(2 if kind==1 else 1)+(6 if role=="line" else 0)

static func steered_velocity(velocity: Vector2, separation: Vector2, walk_speed: float) -> Vector2:
	# Steering changes direction/spacing, never adds free forward pursuit speed.
	# Explicit attack velocities (charge/boss) keep their own higher limit.
	return (velocity+separation).limit_length(maxf(walk_speed,velocity.length()))
