# enemy_state_stunned.gd
# Enemy FSM state: Stunned — immobile for a duration, then resumes Chase or Investigate.
class_name EnemyStateStunned
extends "res://player/state_machine.gd".State

var _timer: float = 0.0

func enter(msg: Dictionary) -> void:
	_timer = msg.get("duration", 0.8)
	(state_machine.owner_node as Enemy).stop_movement()

func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var perc = (state_machine.owner_node as Enemy).perception as PerceptionSystem
		state_machine.transition_to("Chase" if perc.is_chase_threshold() else "Investigate")
