# weapon.gd
# Attach to weapon model node (child of WeaponPivot).
# Handles: sway, recoil visual, fire (hitscan), ammo.
# Weapon StateMachine drives: fire, ads, reload calls.
extends Node3D

signal fired(hit_info: Dictionary)
signal reloaded()
signal ammo_changed(current: int, max_val: int)

@export var data: WeaponData

@onready var _audio: AudioStreamPlayer3D = $AudioPlayer
@onready var _muzzle_point: Node3D = $MuzzlePoint  # position for flash + raycast origin

# Runtime state
var current_ammo    : int   = 0
var is_ads          : bool  = false

# Sway internal
var _sway_offset    : Vector3 = Vector3.ZERO
var _prev_mouse_vel : Vector2 = Vector2.ZERO
var _mouse_vel      : Vector2 = Vector2.ZERO   # fed from weapon_sm each frame

# Recoil internal
var _recoil_offset  : Vector3 = Vector3.ZERO   # pitch/yaw for camera (in player)
var _weapon_recoil  : Vector3 = Vector3.ZERO   # local position kick

func _ready() -> void:
	if data:
		current_ammo = data.magazine_size

func setup(p_data: WeaponData) -> void:
	data = p_data
	current_ammo = data.magazine_size
	ammo_changed.emit(current_ammo, data.magazine_size)

# ─── Called every physics frame by WeaponSM ─────────────────
func process_sway(delta: float, movement_vel: Vector3, p_mouse_vel: Vector2) -> void:
	if not data: return
	var mult := data.ads_sway_mult if is_ads else 1.0
	var amount := data.sway_amount * mult

	# Combine movement sway + look sway
	var look_sway := Vector3(
		-p_mouse_vel.y * data.sway_look_mult,
		-p_mouse_vel.x * data.sway_look_mult,
		0.0
	) * mult

	var move_sway := Vector3(
		-movement_vel.x * 0.004,
		-movement_vel.y * 0.002,
		0.0
	) * mult

	var target := (look_sway + move_sway).limit_length(amount)
	_sway_offset = _sway_offset.lerp(target, data.sway_speed * delta)

	# Recover weapon recoil kick
	_weapon_recoil = _weapon_recoil.lerp(Vector3.ZERO, data.recoil_recovery_speed * delta)

	position = _sway_offset + _weapon_recoil

# Returns camera recoil delta to be applied to player camera pitch
func get_and_consume_camera_recoil() -> Vector2:
	var r := Vector2(_recoil_offset.x, _recoil_offset.y)
	_recoil_offset = _recoil_offset.lerp(Vector3.ZERO, data.recoil_recovery_speed * 0.016)
	return r

# ─── Fire ───────────────────────────────────────────────────
func can_fire() -> bool:
	return current_ammo > 0

func fire(camera: Camera3D, player: Node) -> Dictionary:
	if not data or not can_fire():
		_play_audio(data.empty_click_sound if data else null)
		return {}

	current_ammo -= 1
	ammo_changed.emit(current_ammo, data.magazine_size)

	# Audio / FX
	_play_audio(data.shoot_sound)
	_spawn_muzzle_flash()

	# Noise event
	NoiseBus.emit_noise(player.global_position, 0.95, "shoot", player)

	# Hitscan raycast
	var hit_info := _do_hitscan(camera, player)

	# Apply recoil
	_apply_recoil()

	fired.emit(hit_info)
	return hit_info

func _do_hitscan(camera: Camera3D, player: Node) -> Dictionary:
	var origin    : Vector3 = camera.global_position
	var direction : Vector3 = -camera.global_basis.z

	var params := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * data.range,
		0xFFFFFFFF
	)
	params.exclude = [player.get_rid()]

	var space = player.get_world_3d().direct_space_state
	var result : Dictionary = space.intersect_ray(params)

	if not result.is_empty():
		var dist := origin.distance_to(result["position"])
		var dmg  := _calc_damage(dist)

		# ── Feature 2: HitboxZone resolution ─────────────────
		# If ray hit a HitboxZone Area3D → extract multiplier,
		# resolve owning CharacterBody3D for damage call.
		var hit_target : Node   = result["collider"]
		var multiplier : float  = 1.0
		var zone_name  : String = ""

		if hit_target is HitboxZone:
			multiplier = hit_target.multiplier
			zone_name  = hit_target.zone_name
			var owner_body = hit_target.get_owner_enemy()
			if owner_body:
				hit_target = owner_body

		var hit_info := {
			"position"   : result["position"],
			"normal"     : result["normal"],
			"collider"   : result["collider"],
			"target"     : hit_target,
			"distance"   : dist,
			"damage"     : dmg,
			"multiplier" : multiplier,
			"zone"       : zone_name,
		}

		if hit_target.has_method("take_damage"):
			hit_target.take_damage(dmg, hit_info)
		elif hit_target.get_parent().has_method("take_damage"):
			hit_target.get_parent().take_damage(dmg, hit_info)

		_spawn_impact(result["position"], result["normal"])
		return hit_info

	return {}

func _calc_damage(dist: float) -> float:
	if dist <= data.damage_falloff_start:
		return data.damage
	var falloff_range : float = data.range - data.damage_falloff_start
	var t := clamp((dist - data.damage_falloff_start) / falloff_range, 0.0, 1.0)
	var dmg_result : float = lerp(data.damage, data.damage * 0.3, t)
	return dmg_result

func _apply_recoil() -> void:
	var v : float = data.recoil_vertical
	var h := randf_range(-data.recoil_horizontal, data.recoil_horizontal)
	# Camera gets majority
	_recoil_offset += Vector3(v * data.camera_kick_mult, h * data.camera_kick_mult, 0.0)
	# Weapon model gets the rest (z = backward kick)
	_weapon_recoil  += Vector3(0.0, 0.0, v * data.weapon_kick_mult * 0.02)

# ─── Reload ─────────────────────────────────────────────────
# Reload is now split into start/finish to avoid race conditions.
# The WeaponStateReloading state calls start_reload() on enter and
# finish_reload() when its timer expires. No internal await needed.
func start_reload() -> void:
	if not data: return
	_play_audio(data.reload_sound)

func finish_reload() -> void:
	if not data: return
	current_ammo = data.magazine_size
	ammo_changed.emit(current_ammo, data.magazine_size)
	reloaded.emit()

# ─── Helpers ────────────────────────────────────────────────
func _play_audio(stream: AudioStream) -> void:
	if stream and _audio:
		_audio.stream = stream
		_audio.play()

func _spawn_muzzle_flash() -> void:
	if data.muzzle_flash_scene and _muzzle_point:
		var flash := data.muzzle_flash_scene.instantiate()
		_muzzle_point.add_child(flash)

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if data.impact_fx_scene:
		var fx := data.impact_fx_scene.instantiate()
		get_tree().root.add_child(fx)
		fx.global_position = pos
		fx.look_at(pos + normal, Vector3.UP)
