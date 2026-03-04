# enemy_state_search.gd
# Enemy FSM state: Search — wanders near last known position for SEARCH_DURATION seconds.
class_name EnemyStateSearch
extends "res://player/state_machine.gd".State

var _search_timer: float = 0.0
const SEARCH_DURATION := 8.0
var _waypoints: Array[Vector3] = []
var _wp_index : int = 0

func enter(_msg: Dictionary) -> void:
	_search_timer = SEARCH_DURATION
	_generate_waypoints()

func _generate_waypoints() -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	_waypoints.clear(); _wp_index = 0
	_waypoints.append(perc.last_known_position)
	for i in 2:
		var offset := Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		_waypoints.append(perc.last_known_position + offset)

func physics_update(delta: float) -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	_search_timer -= delta
	if perc.is_chase_threshold() or perc.target_visible:
		state_machine.transition_to("Chase"); return
	if _search_timer <= 0.0 or perc.is_idle_threshold():
		state_machine.transition_to("Idle"); return
	if _wp_index < _waypoints.size():
		enemy.move_toward_target(_waypoints[_wp_index], enemy.move_speed, delta)
		if enemy.nav_agent.is_navigation_finished():
			_wp_index += 1
	else:
		enemy.stop_movement()
