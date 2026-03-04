# player_state_walk.gd
# Locomotion FSM state: Walk — player moving at normal speed.
class_name PlayerStateWalk
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	pass

func physics_update(delta: float) -> void:
	var player = state_machine.owner_node
	var dir : Vector3 = player.get_input_direction()

	if not player.is_on_floor():
		state_machine.transition_to("InAir")
		return

	player.apply_movement(dir, player.walk_speed, delta)
	NoiseBus.emit_noise(player.global_position, 0.15, "footstep_walk", player)

	if dir.length_squared() < 0.01:
		state_machine.transition_to("Idle")
	elif Input.is_action_pressed("sprint") and player.can_sprint():
		state_machine.transition_to("Sprint")
	elif Input.is_action_just_pressed("crouch"):
		state_machine.transition_to("Crouch")
	elif Input.is_action_just_pressed("jump"):
		player.do_jump()
		state_machine.transition_to("InAir")
