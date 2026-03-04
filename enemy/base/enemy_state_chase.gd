# enemy_state_chase.gd
# Enemy FSM state: Chase — pursues player at chase_speed, transitions to Attack when in range.
class_name EnemyStateChase
extends "res://player/state_machine.gd".State

var _lost_timer: float = 0.0
const LOST_TIMEOUT := 4.0

func enter(_msg: Dictionary) -> void:
	_lost_timer = 0.0

func physics_update(delta: float) -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	if perc.target_visible:
		_lost_timer = 0.0
		enemy.move_toward_target(perc.last_known_position, enemy.chase_speed, delta)
		if enemy.is_in_attack_range(perc._player) and enemy.can_attack():
			state_machine.transition_to("Attack")
	else:
		_lost_timer += delta
		enemy.move_toward_target(perc.last_known_position, enemy.chase_speed, delta)
		if _lost_timer >= LOST_TIMEOUT:
			state_machine.transition_to("Search")
	if perc.is_idle_threshold():
		state_machine.transition_to("Idle")
