# weapon_state_throwing.gd
# Weapon FSM state: Throwing — brief animation delay, then back to WeaponIdle.
class_name WeaponStateThrowing
extends "res://player/state_machine.gd".State

const THROW_DURATION := 0.4

var _timer: float = 0.0

func enter(_msg: Dictionary) -> void:
	_timer = THROW_DURATION
	var player = state_machine.owner_node
	player.weapon_holder.throw_object(player)

func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to("WeaponIdle")
