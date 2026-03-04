# player_state_crouch.gd
# Locomotion FSM state: Crouch — player crouching with reduced speed.
class_name PlayerStateCrouch
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	var player = state_machine.owner_node
	player.set_crouch(true)

func exit() -> void:
	var player = state_machine.owner_node
	# Only stand if head clearance allows
	if player.has_head_clearance():
		player.set_crouch(false)

func physics_update(delta: float) -> void:
	var player = state_machine.owner_node
	var dir : Vector3 = player.get_input_direction()
	player.apply_movement(dir, player.crouch_speed, delta)

	if Input.is_action_just_pressed("crouch"):
		if player.has_head_clearance():
			state_machine.transition_to("Idle")
		# else: stay crouched (ceiling above)
	elif not player.is_on_floor():
		state_machine.transition_to("InAir")
