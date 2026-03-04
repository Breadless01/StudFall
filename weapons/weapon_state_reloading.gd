# weapon_state_reloading.gd
# Weapon FSM state: Reloading — blocks input for reload_time, then returns to WeaponIdle.
# Ammo restoration is handled here (not in weapon.gd) to avoid race conditions.
class_name WeaponStateReloading
extends "res://player/state_machine.gd".State

var _timer: float = 0.0
var _reload_time: float = 2.0

func enter(_msg: Dictionary) -> void:
	var player = state_machine.owner_node
	var wd = player.weapon_holder.get_current_weapon_data()
	if wd:
		_reload_time = wd.reload_time
	_timer = _reload_time
	var weapon = player.weapon_holder.get_current_weapon()
	if weapon:
		weapon.start_reload()

func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		# Restore ammo when the state timer expires
		var player = state_machine.owner_node
		var weapon = player.weapon_holder.get_current_weapon()
		if weapon:
			weapon.finish_reload()
		state_machine.transition_to("WeaponIdle")
