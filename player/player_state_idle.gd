# player_state_idle.gd
# Locomotion FSM state: Idle — player is stationary on ground.
class_name PlayerStateIdle
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	pass

func physics_update(delta: float) -> void:
	var player = state_machine.owner_node as CharacterBody3D
	# Decelerate to zero
	player.apply_friction(delta)
	# Transition checks
	var dir : Vector3 = player.get_input_direction()
	if not player.is_on_floor():
		state_machine.transition_to("InAir")
	elif dir.length_squared() > 0.01:
		state_machine.transition_to("Walk")
	elif Input.is_action_just_pressed("crouch"):
		state_machine.transition_to("Crouch")
