# enemy_state_idle.gd
# Enemy FSM state: Idle / Patrol — waits or patrols waypoints until perception triggers.
class_name EnemyStateIdle
extends "res://player/state_machine.gd".State

var _poll_timer  : float = 0.0
var _wait_timer  : float = 0.0
var _is_waiting  : bool  = false
const POLL_INTERVAL := 0.2

func enter(_msg: Dictionary) -> void:
	var enemy = state_machine.owner_node as Enemy
	_is_waiting = false
	_wait_timer = 0.0
	if not enemy.patrol_enabled:
		enemy.stop_movement()

func physics_update(delta: float) -> void:
	# ── Perception poll ─────────────────────────────────────
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		var enemy = state_machine.owner_node as Enemy
		var perc  = enemy.perception as PerceptionSystem
		if perc.is_investigate_threshold():
			state_machine.transition_to("Investigate")
			return
		elif perc.is_chase_threshold() or perc.target_visible:
			state_machine.transition_to("Chase")
			return

	# ── Patrol ──────────────────────────────────────────────
	var enemy = state_machine.owner_node as Enemy
	if not enemy.patrol_enabled or enemy.patrol_points.is_empty(): return

	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_is_waiting = false
			enemy.advance_patrol()
		return

	# Move toward current waypoint
	var target := enemy.get_patrol_point()
	enemy.move_toward_target(target, enemy.move_speed * enemy.patrol_speed_mult, delta)

	# Arrived at waypoint?
	if enemy.nav_agent.is_navigation_finished():
		_is_waiting = true
		_wait_timer = enemy.patrol_wait_time
		enemy.stop_movement()
