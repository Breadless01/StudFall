# enemy.gd — PATCH v3 (Feature Extensions)
# Changes vs v2:
#   + Patrol exports (patrol_enabled, patrol_path, etc.)
#   + attack_mode enum (MELEE / RANGED) + do_ranged_attack() stub
#   + take_damage() now reads hit_info["multiplier"] (float) directly
#     from HitboxZone, falling back to zone-name strings for compatibility
class_name Enemy
extends CharacterBody3D

# ─── Signals ───────────────────────────────────────────────
signal damaged(amount: float, hit_info: Dictionary)
signal died()
signal state_changed(state_name: String)

# ─── Stats ─────────────────────────────────────────────────
@export_group("Stats")
@export var max_health      : float = 100.0
@export var move_speed      : float = 3.5
@export var chase_speed     : float = 5.5
@export var attack_damage   : float = 20.0
@export var attack_range    : float = 1.8
@export var attack_cooldown : float = 1.5

@export_group("Death")
@export var corpse_linger   : float = 4.0

# ─── Patrol (Feature 1) ────────────────────────────────────
@export_group("Patrol")
@export var patrol_enabled        : bool   = false
@export var patrol_path           : NodePath       # Node with Marker3D children
@export var patrol_wait_time      : float  = 2.0   # seconds at each waypoint
@export var patrol_speed_mult     : float  = 0.7   # relative to move_speed

# Resolved at runtime
var patrol_points : Array[Vector3] = []
var patrol_index  : int = 0

# ─── Attack Mode (Feature 3) ───────────────────────────────
enum AttackMode { MELEE, RANGED }
@export_group("Attack")
@export var attack_mode : AttackMode = AttackMode.MELEE

# Ranged stub config
@export var ranged_range    : float = 15.0
@export var ranged_cooldown : float = 3.0

# ─── Hitbox Multipliers — legacy fallback ──────────────────
const HIT_MULT_HEAD : float = 2.0
const HIT_MULT_BODY : float = 1.0

# ─── Node References ───────────────────────────────────────
@onready var nav_agent   : NavigationAgent3D = $NavigationAgent3D
@onready var enemy_sm    : Node              = $EnemyStateMachine
@onready var perception  : Node              = $PerceptionSystem
@onready var attack_area : Area3D            = $AttackHitbox
@onready var col_shape   : CollisionShape3D  = $CollisionShape3D

# ─── Runtime ───────────────────────────────────────────────
var health       : float
var is_dead      : bool  = false
var _attack_timer: float = 0.0
var _gravity     : float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	enemy_sm.init("Idle", self)
	NoiseBus.noise_emitted.connect(_on_noise)
	if perception:
		perception.setup(self)
	_resolve_patrol_path()

# ─── Patrol Path Resolution ────────────────────────────────
func _resolve_patrol_path() -> void:
	if not patrol_enabled or patrol_path.is_empty(): return
	var path_node := get_node_or_null(patrol_path)
	if not path_node: return
	for child in path_node.get_children():
		if child is Node3D:
			patrol_points.append(child.global_position)

func get_patrol_point() -> Vector3:
	if patrol_points.is_empty(): return global_position
	return patrol_points[patrol_index]

func advance_patrol() -> void:
	if patrol_points.is_empty(): return
	patrol_index = (patrol_index + 1) % patrol_points.size()

# ─── Physics ───────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_attack_timer = max(0.0, _attack_timer - delta)

# ─── Damage Interface (Feature 2 integrated) ───────────────
func take_damage(amount: float, hit_info: Dictionary = {}) -> void:
	if is_dead: return

	# Feature 2: prefer numeric multiplier from HitboxZone,
	# fall back to legacy zone-name string
	var mult := 1.0
	if hit_info.has("multiplier"):
		mult = float(hit_info["multiplier"])
	elif hit_info.get("zone", "") == "head":
		mult = HIT_MULT_HEAD

	var final_dmg := amount * mult
	health        -= final_dmg
	damaged.emit(final_dmg, hit_info)

	if perception:
		perception.suspicion = min(1.0, perception.suspicion + 0.5)
	_on_flinch(hit_info)

	if health <= 0.0:
		_die()

func _on_flinch(_hit_info: Dictionary) -> void:
	pass  # override in subclass

# ─── Death ─────────────────────────────────────────────────
func _die() -> void:
	if is_dead: return
	is_dead = true
	died.emit()
	enemy_sm.set_process(false)
	enemy_sm.set_physics_process(false)
	nav_agent.set_target_position(global_position)
	velocity = Vector3.ZERO
	col_shape.set_deferred("disabled", true)
	remove_from_group("enemies")
	if NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.disconnect(_on_noise)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 0.4, 0.3).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(corpse_linger).timeout
	queue_free()

# ─── Noise ─────────────────────────────────────────────────
func _on_noise(pos: Vector3, loudness: float, tag: String, source: Node) -> void:
	if is_dead: return
	if not perception: return
	perception.on_noise(pos, loudness, tag, global_position.distance_to(pos))

# ─── Navigation Helpers ────────────────────────────────────
func move_toward_target(target_pos: Vector3, speed: float, _delta: float) -> void:
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished(): return
	var next := nav_agent.get_next_path_position()
	var dir  := (next - global_position).normalized()
	dir.y     = 0.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length_squared() > 0.01:
		look_at(global_position + dir, Vector3.UP)

func stop_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

# ─── Attack Dispatch (Feature 3) ───────────────────────────
func can_attack() -> bool:
	return _attack_timer <= 0.0 and not is_dead

func do_attack() -> void:
	match attack_mode:
		AttackMode.MELEE:   do_melee_attack()
		AttackMode.RANGED:  do_ranged_attack(perception._player if perception else null)

func do_melee_attack() -> void:
	_attack_timer = attack_cooldown
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_damage, {"source": self})

# Feature 3: Ranged Attack Stub
# Override this in a subclass to implement projectile / hitscan ranged behavior.
# Current implementation: simple hitscan to player position (functional stub).
func do_ranged_attack(target: Node3D) -> void:
	if not target: return
	_attack_timer = ranged_cooldown

	# TODO: replace with projectile spawn for non-hitscan enemies
	var dist := global_position.distance_to(target.global_position)
	if dist > ranged_range: return

	# Simple line-of-sight check before damaging
	var params := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.4, 0),
		target.global_position + Vector3(0, 1.0, 0),
		0b1  # world geometry only
	)
	params.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	# Only hits if LOS clear (result empty = nothing blocking)
	if result.is_empty() or result["collider"] == target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, {"source": self, "type": "ranged"})

func is_in_attack_range(target: Node3D) -> bool:
	var range_val := ranged_range if attack_mode == AttackMode.RANGED else attack_range
	return global_position.distance_to(target.global_position) <= range_val
