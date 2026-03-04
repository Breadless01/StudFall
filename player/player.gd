# player.gd — PATCH v2 (Vertical Slice)
# Changes vs v1:
#   + health_changed(current, max) signal         → HUD connection
#   + is_dead: bool                               → guard in input + physics
#   + take_damage() clamped, health_changed emit  → was missing
#   + _die() fully implemented (input lock, mouse free, FSMs stopped)
#   + heal() method
#   + _accumulated_mouse_delta for sway (Pitfall #10 fix)
#   + set_fov() kills previous tween (Pitfall #6 fix)
extends CharacterBody3D

# ─── Signals ───────────────────────────────────────────────
signal damaged(amount: float, source: Node)
signal died()
signal weapon_changed(weapon_data: Resource)
signal health_changed(current: float, max_val: float)   # NEW — HUD listens

# ─── Movement Tuning ───────────────────────────────────────
@export_group("Movement")
@export var walk_speed        := 5.5
@export var sprint_speed      := 9.0
@export var crouch_speed      := 2.8
@export var acceleration      := 25.0
@export var friction          := 22.0
@export var air_control       := 0.3
@export var air_friction      := 4.0
@export var jump_velocity     := 5.0
@export var gravity_mult      := 2.2

# ─── Crouch ────────────────────────────────────────────────
@export_group("Crouch")
@export var stand_height      := 1.8
@export var crouch_height     := 1.0
@export var crouch_lerp_speed := 12.0
var _is_crouched              := false
var _current_height           := 1.8

# ─── Camera / Look ─────────────────────────────────────────
@export_group("Camera")
@export var mouse_sensitivity    := 0.002
@export var pitch_limit          := 88.0
@export var camera_height_stand  := 1.65
@export var camera_height_crouch := 0.85
@export var normal_fov           := 85.0

# ─── Lean ──────────────────────────────────────────────────
@export_group("Lean")
@export var lean_angle_max       := 15.0
@export var lean_offset_max      := 0.35
@export var lean_speed           := 8.0
@export var lean_wall_check_dist := 0.5
var _lean_input   := 0.0
var _lean_current := 0.0

# ─── Health ────────────────────────────────────────────────
@export_group("Health")
@export var max_health := 100.0
var health    := 100.0
var is_dead   := false          # NEW — all systems check this

# ─── Node References ───────────────────────────────────────
@onready var camera_rig    : Node3D             = $CameraRig
@onready var camera_pivot  : Node3D             = $CameraRig/CameraPivot
@onready var camera        : Camera3D           = $CameraRig/CameraPivot/Camera3D
@onready var col_stand     : CollisionShape3D   = $CollisionShape3D
@onready var col_crouch    : CollisionShape3D   = $CollisionShape3D_Crouch
@onready var head_ray      : RayCast3D          = $HeadClearanceRay
@onready var weapon_holder : Node3D             = $WeaponHolder
@onready var loco_sm       : Node               = $LocomotionSM
@onready var weapon_sm     : Node               = $WeaponSM
@onready var fear_system   : Node               = $FearSystem

# ─── Internal ──────────────────────────────────────────────
var _yaw   := 0.0
var _pitch := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _accumulated_mouse_delta := Vector2.ZERO   # sway fix (Pitfall #10)
var _fov_tween: Tween = null                   # single tween guard (Pitfall #6)

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	loco_sm.init("Idle", self)
	weapon_sm.init("WeaponIdle", self)
	col_crouch.disabled = true
	head_ray.target_position = Vector3(0, stand_height * 0.6, 0)
	health = max_health
	health_changed.emit(health, max_health)

# ─── Input ─────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	if event is InputEventMouseMotion:
		_accumulated_mouse_delta += event.relative
		_handle_mouse_look(event.relative)

# ─── Physics ───────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead: return
	_apply_gravity(delta)
	_update_lean(delta)
	_update_camera_height(delta)
	move_and_slide()
	_accumulated_mouse_delta = Vector2.ZERO

# ─── Mouse Look ────────────────────────────────────────────
func _handle_mouse_look(rel: Vector2) -> void:
	var sens := mouse_sensitivity
	if weapon_sm and weapon_sm.get_current_state_name() == "ADS":
		var wd = weapon_holder.get_current_weapon_data()
		if wd:
			sens *= wd.ads_sensitivity_mult
	_yaw   -= rel.x * sens
	_pitch -= rel.y * sens
	_pitch  = clamp(_pitch, -deg_to_rad(pitch_limit), deg_to_rad(pitch_limit))
	camera_rig.rotation.y   = _yaw
	camera_pivot.rotation.x = _pitch

# ─── Movement Helpers (called by States) ───────────────────
func get_input_direction() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):  dir -= camera_rig.basis.z
	if Input.is_action_pressed("move_back"):     dir += camera_rig.basis.z
	if Input.is_action_pressed("move_left"):     dir -= camera_rig.basis.x
	if Input.is_action_pressed("move_right"):    dir += camera_rig.basis.x
	dir.y = 0.0
	return dir.normalized()

func apply_movement(dir: Vector3, speed: float, delta: float) -> void:
	var target_vel := dir * speed
	var fear_mult  := 1.0
	if fear_system:
		fear_mult = 1.0 - fear_system.fear * 0.12
	target_vel *= fear_mult
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

func apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)

func apply_air_control(dir: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * sprint_speed, air_control * acceleration * delta)
	velocity.z = move_toward(velocity.z, dir.z * sprint_speed, air_control * acceleration * delta)
	velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, air_friction * delta)

func can_sprint() -> bool:
	return not _is_crouched

func do_jump() -> void:
	velocity.y = jump_velocity

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_mult * delta
	else:
		velocity.y = -0.5

# ─── Crouch ────────────────────────────────────────────────
func set_crouch(crouching: bool) -> void:
	_is_crouched = crouching
	col_stand.disabled  = crouching
	col_crouch.disabled = not crouching

func has_head_clearance() -> bool:
	return not head_ray.is_colliding()

func _update_camera_height(delta: float) -> void:
	var target_h := camera_height_crouch if _is_crouched else camera_height_stand
	_current_height = lerp(_current_height, target_h, crouch_lerp_speed * delta)
	camera_rig.position.y = _current_height

# ─── Lean ──────────────────────────────────────────────────
func _update_lean(delta: float) -> void:
	_lean_input = 0.0
	if Input.is_action_pressed("lean_left"):  _lean_input = -1.0
	if Input.is_action_pressed("lean_right"): _lean_input =  1.0
	if _lean_input != 0.0:
		var check_dir := camera_rig.basis.x * _lean_input
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, camera_height_stand * 0.7, 0),
			global_position + Vector3(0, camera_height_stand * 0.7, 0) + check_dir * lean_wall_check_dist,
			collision_mask
		)
		query.exclude = [get_rid()]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			_lean_input = 0.0
	_lean_current = lerp(_lean_current, _lean_input, lean_speed * delta)
	camera_pivot.rotation.z = deg_to_rad(-lean_angle_max * _lean_current)
	camera_pivot.position.x = lean_offset_max * _lean_current

# ─── Health / Damage ───────────────────────────────────────
func take_damage(amount: float, source: Node = null) -> void:
	if is_dead: return
	health = clamp(health - amount, 0.0, max_health)
	damaged.emit(amount, source)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	if is_dead: return
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	if is_dead: return
	is_dead = true
	died.emit()
	# Stop FSMs so states don't keep running
	loco_sm.set_process(false)
	loco_sm.set_physics_process(false)
	weapon_sm.set_process(false)
	weapon_sm.set_physics_process(false)
	velocity = Vector3.ZERO
	# Release mouse so Game Over UI is clickable
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Tilt camera to convey "falling"
	var tween := create_tween()
	tween.tween_property(camera_pivot, "rotation:z", deg_to_rad(70.0), 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ─── FOV ───────────────────────────────────────────────────
func set_fov(target_fov: float, t: float = 0.1) -> void:
	if _fov_tween and _fov_tween.is_valid():
		_fov_tween.kill()
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", target_fov, t).set_ease(Tween.EASE_OUT)
