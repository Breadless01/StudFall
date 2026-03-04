# weapon_state_ads.gd
# Weapon FSM state: ADS — aiming down sights, reduced FOV and sway.
class_name WeaponStateADS
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	var player = state_machine.owner_node
	var wd = player.weapon_holder.get_current_weapon_data()
	if wd:
		player.set_fov(wd.ads_fov, wd.ads_time)
		var weapon = player.weapon_holder.get_current_weapon()
		if weapon:
			weapon.is_ads = true

func exit() -> void:
	var player = state_machine.owner_node
	player.set_fov(player.normal_fov, 0.12)
	var weapon = player.weapon_holder.get_current_weapon()
	if weapon:
		weapon.is_ads = false

func physics_update(delta: float) -> void:
	var player  = state_machine.owner_node
	var holder  = player.weapon_holder
	var weapon  = holder.get_current_weapon()
	var wd      = holder.get_current_weapon_data()

	_update_sway(delta, player, weapon)
	_apply_camera_recoil(player, weapon)

	if not Input.is_action_pressed("ads"):
		state_machine.transition_to("WeaponIdle")
		return

	if wd == null: return
	var firing := Input.is_action_pressed("fire") if wd.is_auto else Input.is_action_just_pressed("fire")
	if firing:
		weapon.fire(player.camera, player)

func _update_sway(delta: float, player, weapon) -> void:
	if not weapon: return
	# Pass accumulated mouse delta for proper look-sway
	var mouse_delta : Vector2 = player._accumulated_mouse_delta if player else Vector2.ZERO
	weapon.process_sway(delta, player.velocity, mouse_delta)

func _apply_camera_recoil(player, weapon) -> void:
	if not weapon: return
	var recoil = weapon.get_and_consume_camera_recoil()
	if recoil.length() > 0.001:
		player._pitch -= deg_to_rad(recoil.x)
		player._pitch = clamp(player._pitch,
			-deg_to_rad(player.pitch_limit), deg_to_rad(player.pitch_limit))
		player.camera_pivot.rotation.x = player._pitch
