# enemy_state_investigate.gd
# Enemy FSM state: Investigate — moves toward last known position, then transitions to Search.
class_name EnemyStateInvestigate
extends "res://player/state_machine.gd".State

var _arrive_timer: float = 0.0
const WAIT_AT_SPOT := 3.0

func enter(_msg: Dictionary) -> void:
	_arrive_timer = 0.0
	_set_destination()

func physics_update(delta: float) -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	if perc.is_chase_threshold() or perc.target_visible:
		state_machine.transition_to("Chase"); return
	if perc.is_idle_threshold():
		state_machine.transition_to("Idle"); return
	enemy.move_toward_target(perc.last_known_position, enemy.move_speed, delta)
	if enemy.nav_agent.is_navigation_finished():
		_arrive_timer += delta
		if _arrive_timer >= WAIT_AT_SPOT:
			state_machine.transition_to("Search")

func _set_destination() -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	enemy.nav_agent.target_position = perc.last_known_position
