# player_state_sprint.gd
# Locomotion FSM state: Sprint — player running at sprint_speed.
class_name PlayerStateSprint
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	# Cancel ADS when sprinting
	var player = state_machine.owner_node
	if player.weapon_sm:
		player.weapon_sm.transition_to("WeaponIdle")

func physics_update(delta: float) -> void:
	var player = state_machine.owner_node
	var dir : Vector3 = player.get_input_direction()

	if not player.is_on_floor():
		state_machine.transition_to("InAir")
		return

	player.apply_movement(dir, player.sprint_speed, delta)
	NoiseBus.emit_noise(player.global_position, 0.4, "footstep_sprint", player)

	if dir.length_squared() < 0.01 or not Input.is_action_pressed("sprint"):
		state_machine.transition_to("Walk")
	elif Input.is_action_just_pressed("crouch"):
		state_machine.transition_to("Crouch")
	elif Input.is_action_just_pressed("jump"):
		player.do_jump()
		state_machine.transition_to("InAir")
