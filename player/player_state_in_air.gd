# player_state_in_air.gd
# Locomotion FSM state: InAir — player is airborne (jumping or falling).
class_name PlayerStateInAir
extends "res://player/state_machine.gd".State

func physics_update(delta: float) -> void:
	var player = state_machine.owner_node
	var dir : Vector3 = player.get_input_direction()
	# Air control (reduced)
	player.apply_air_control(dir, delta)

	if player.is_on_floor():
		var dir2 : Vector3 = player.get_input_direction()
		if dir2.length_squared() > 0.01:
			state_machine.transition_to("Walk")
		else:
			state_machine.transition_to("Idle")
