# fear_system.gd — PATCH v2  (Feature 6: LightDetection via DarkZone volumes)
# Changes vs v1:
#   + environment_darkness (0..1): set by DarkZone trigger volumes
#   + register_dark_zone() / unregister_dark_zone() called by dark_zone.gd
#   + get_darkness() getter for SanitySystem
#   + gain_darkness now ACTIVE (was placeholder comment)
#   + _active_dark_zones dictionary tracks overlapping zones (highest wins)
extends Node

signal fear_changed(value: float)

# ─── Tuning ────────────────────────────────────────────────
@export_group("Fear Gain")
@export var gain_enemy_proximity   : float = 0.06
@export var gain_low_health        : float = 0.04
@export var gain_darkness          : float = 0.025  # per second at darkness=1.0
@export var danger_range           : float = 8.0

@export_group("Fear Decay")
@export var decay_rate             : float = 0.05
@export var decay_in_safe_zone     : float = 0.15
@export var kill_bonus_decay       : float = 0.25

@export_group("Effect Caps")
@export var max_sway_mult          : float = 1.6
@export var max_recoil_recovery_penalty: float = 0.5
@export var camera_shake_max       : float = 0.4

# ─── State ─────────────────────────────────────────────────
var fear                 : float = 0.0
var in_safe_zone         : bool  = false
var environment_darkness : float = 0.0   # Feature 6: 0=bright, 1=pitch dark

# ─── Dark Zone tracking (Feature 6) ────────────────────────
# Key: DarkZone node, Value: darkness_factor float
var _active_dark_zones   : Dictionary = {}

var _player  : Node
var _camera  : Camera3D

func _ready() -> void:
	_player = get_parent()
	_camera = _player.get_node_or_null("CameraRig/CameraPivot/Camera3D")

func _physics_process(delta: float) -> void:
	_update_fear(delta)
	_apply_camera_shake(delta)
	fear_changed.emit(fear)

func _update_fear(delta: float) -> void:
	var gain := 0.0

	# Proximity to enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var dist : float = _player.global_position.distance_to(enemy.global_position)
			if dist < danger_range:
				gain += gain_enemy_proximity * (1.0 - dist / danger_range)

	# Low health
	if "health" in _player and "max_health" in _player:
		var hp_ratio : float = _player.health / _player.max_health
		if hp_ratio < 0.3:
			gain += gain_low_health * (1.0 - hp_ratio / 0.3)

	# Darkness (Feature 6 — now active)
	gain += gain_darkness * environment_darkness

	fear = clamp(fear + gain * delta, 0.0, 1.0)

	var effective_decay := decay_in_safe_zone if in_safe_zone else decay_rate
	if gain < 0.001:
		fear = max(0.0, fear - effective_decay * delta)

# ─── Dark Zone API (Feature 6) ─────────────────────────────
func register_dark_zone(zone: Node, factor: float) -> void:
	_active_dark_zones[zone] = factor
	_recalc_darkness()

func unregister_dark_zone(zone: Node) -> void:
	_active_dark_zones.erase(zone)
	_recalc_darkness()

func _recalc_darkness() -> void:
	# Use the highest darkness_factor among all active zones
	var max_darkness := 0.0
	for factor in _active_dark_zones.values():
		max_darkness = max(max_darkness, float(factor))
	environment_darkness = max_darkness

# Getter for SanitySystem
func get_darkness() -> float:
	return environment_darkness

# ─── Called externally ─────────────────────────────────────
func on_enemy_killed() -> void:
	fear = max(0.0, fear - kill_bonus_decay)

func enter_safe_zone() -> void:
	in_safe_zone = true

func exit_safe_zone() -> void:
	in_safe_zone = false

# ─── Getters ───────────────────────────────────────────────
func get_sway_multiplier() -> float:
	return lerp(1.0, max_sway_mult, fear)

func get_recoil_recovery_penalty() -> float:
	return lerp(0.0, max_recoil_recovery_penalty, fear)

func get_ads_speed_penalty() -> float:
	return lerp(0.0, 0.3, fear)

# ─── Camera Shake ──────────────────────────────────────────
func _apply_camera_shake(delta: float) -> void:
	if not _camera: return
	var shake_amt := camera_shake_max * fear * 0.3
	if shake_amt < 0.001:
		_camera.h_offset = lerp(_camera.h_offset, 0.0, 10.0 * delta)
		_camera.v_offset = lerp(_camera.v_offset, 0.0, 10.0 * delta)
		return
	var t := Time.get_ticks_msec() / 1000.0
	_camera.h_offset = lerp(_camera.h_offset, sin(t * 1.7 + 0.3) * shake_amt, 8.0 * delta)
	_camera.v_offset = lerp(_camera.v_offset, sin(t * 2.3 + 1.1) * shake_amt * 0.5, 8.0 * delta)
