# weapon_state_idle.gd
# Weapon FSM state: WeaponIdle — hip-fire ready, handles fire/ads/reload/throw transitions.
class_name WeaponStateIdle
extends "res://player/state_machine.gd".State

var _fire_timer: float = 0.0

func enter(_msg: Dictionary) -> void:
	var player = state_machine.owner_node
	player.set_fov(player.normal_fov, 0.1)

func physics_update(delta: float) -> void:
	var player  = state_machine.owner_node
	var holder  = player.weapon_holder
	var weapon  = holder.get_current_weapon()
	_fire_timer = max(0.0, _fire_timer - delta)

	_update_sway(delta, player, weapon)
	_apply_camera_recoil(player, weapon)

	# Transitions
	if Input.is_action_pressed("ads"):
		state_machine.transition_to("ADS")
		return

	if Input.is_action_just_pressed("reload"):
		state_machine.transition_to("Reloading")
		return

	if Input.is_action_just_pressed("throw"):
		state_machine.transition_to("Throwing")
		return

	if Input.is_action_just_pressed("weapon_next"):
		holder.next_weapon()
		return
	if Input.is_action_just_pressed("weapon_prev"):
		holder.prev_weapon()
		return

	var wd = holder.get_current_weapon_data()
	if wd == null: return

	var firing := Input.is_action_pressed("fire") if wd.is_auto else Input.is_action_just_pressed("fire")
	if firing and _fire_timer <= 0.0:
		weapon.fire(player.camera, player)
		_fire_timer = 1.0 / wd.fire_rate

func _update_sway(delta: float, player, weapon) -> void:
	if not weapon: return
	var mov_vel : Vector3 = player.velocity
	# Pass accumulated mouse delta for proper look-sway
	var mouse_delta : Vector2 = player._accumulated_mouse_delta if player else Vector2.ZERO
	weapon.process_sway(delta, mov_vel, mouse_delta)

func _apply_camera_recoil(player, weapon) -> void:
	if not weapon: return
	var recoil = weapon.get_and_consume_camera_recoil()
	if recoil.length() > 0.001:
		# Directly modify player pitch
		player._pitch -= deg_to_rad(recoil.x)
		player._pitch = clamp(player._pitch,
			-deg_to_rad(player.pitch_limit), deg_to_rad(player.pitch_limit))
		player.camera_pivot.rotation.x = player._pitch
