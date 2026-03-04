# perception.gd
# Vision + Hearing perception for enemies.
# Produces: suspicion (0..1), target_visible, last_known_position
# Attach as child of Enemy.
class_name PerceptionSystem
extends Node

# ─── Tuning ────────────────────────────────────────────────
@export_group("Vision")
@export var vision_fov_deg      : float = 90.0     # full cone angle (45° each side)
@export var vision_range        : float = 18.0
@export var vision_interval     : float = 0.15     # seconds between checks
@export var los_collision_mask  : int   = 0b1      # layer 1 = world geometry

@export_group("Hearing")
@export var hearing_range       : float = 20.0

@export_group("Suspicion")
@export var suspicion_decay     : float = 0.08     # per second idle
@export var suspicion_decay_alerted: float = 0.03  # slower when recently alerted
@export var alerted_duration    : float = 8.0      # seconds after last alert

# ─── Output (read by EnemyStateMachine) ────────────────────
var suspicion           : float  = 0.0
var target_visible      : bool   = false
var last_known_position : Vector3 = Vector3.ZERO
var last_known_time     : float  = 0.0  # Time.get_ticks_msec() / 1000
var confidence          : float  = 0.0  # 0=stale, 1=fresh

# ─── Internal ──────────────────────────────────────────────
var _owner_enemy    : Enemy
var _vision_timer   : float = 0.0
var _alerted_timer  : float = 0.0
var _player         : Node3D = null

func _ready() -> void:
	# Find player in group
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func setup(enemy: Enemy) -> void:
	_owner_enemy = enemy

func _physics_process(delta: float) -> void:
	_update_suspicion_decay(delta)
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = vision_interval
		_check_vision()
	_update_confidence(delta)

# ─── Vision ────────────────────────────────────────────────
func _check_vision() -> void:
	if not _player or not _owner_enemy: return

	target_visible = false
	var to_player  := _player.global_position - _owner_enemy.global_position
	var dist       := to_player.length()

	if dist > vision_range: return

	# FOV check
	var forward  := -_owner_enemy.global_basis.z
	var angle    := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > vision_fov_deg * 0.5: return

	# Line of sight raycast
	var params := PhysicsRayQueryParameters3D.create(
		_owner_enemy.global_position + Vector3(0, 1.6, 0),
		_player.global_position + Vector3(0, 1.0, 0),
		los_collision_mask
	)
	params.exclude = [_owner_enemy.get_rid()]
	var result := _owner_enemy.get_world_3d().direct_space_state.intersect_ray(params)

	if result.is_empty() or result["collider"] == _player:
		target_visible = true
		# Suspicion gain: faster at close range
		var gain : float = lerp(0.8, 0.2, dist / vision_range)
		suspicion = min(1.0, suspicion + gain * vision_interval)
		_set_last_known(_player.global_position)
		_alerted_timer = alerted_duration

# ─── Hearing ───────────────────────────────────────────────
func on_noise(pos: Vector3, loudness: float, _tag: String, dist: float) -> void:
	if dist > hearing_range: return
	# Distance falloff
	var effective := loudness * (1.0 - dist / hearing_range)
	suspicion = min(1.0, suspicion + effective * 0.35)
	if not target_visible:
		_set_last_known(pos)
	_alerted_timer = alerted_duration

# ─── Suspicion ─────────────────────────────────────────────
func _update_suspicion_decay(delta: float) -> void:
	if target_visible: return
	var decay := suspicion_decay_alerted if _alerted_timer > 0.0 else suspicion_decay
	suspicion  = max(0.0, suspicion - decay * delta)
	_alerted_timer = max(0.0, _alerted_timer - delta)

func _set_last_known(pos: Vector3) -> void:
	last_known_position = pos
	last_known_time     = Time.get_ticks_msec() / 1000.0
	confidence          = 1.0

func _update_confidence(delta: float) -> void:
	# Confidence decays over ~10 seconds
	if not target_visible:
		confidence = max(0.0, confidence - delta * 0.1)

# ─── Thresholds ────────────────────────────────────────────
func is_idle_threshold()       -> bool: return suspicion < 0.3
func is_investigate_threshold()-> bool: return suspicion >= 0.3 and suspicion < 0.6
func is_chase_threshold()      -> bool: return suspicion >= 0.6
