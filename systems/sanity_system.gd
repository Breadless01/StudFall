# sanity_system.gd  (Feature 5)
# Attach as child of Player: Player/SanitySystem
#
# Sanity (0..1): long-term psychological degradation.
# Fear   (0..1): short-term situational stress (fear_system.gd).
# These are SEPARATE axes:
#   Fear resets quickly in safety.
#   Sanity degrades slowly and recovers slowly — represents lasting damage.
#
# Gameplay modulation is intentionally subtle (hooks, not hard locks).
extends Node

# ─── Signals ───────────────────────────────────────────────
signal sanity_changed(value: float)
signal sanity_event(tag: String, amount: float, source: Variant)

# ─── Tuning ────────────────────────────────────────────────
@export_group("Sanity Gain/Loss")
@export var loss_monster_proximity  : float = 0.003  # per second, within sanity_danger_range
@export var loss_lore_pickup        : float = 0.05   # per lore event
@export var loss_eldritch_event     : float = 0.15   # per eldritch event
@export var loss_darkness           : float = 0.001  # per second in darkness (optional)

@export_group("Sanity Recovery")
@export var recovery_rate           : float = 0.004  # per second in safe zone
@export var recovery_requires_safe  : bool  = true   # only recover in safe zones

@export_group("Thresholds")
@export var sanity_danger_range     : float = 6.0
@export var threshold_disturbed     : float = 0.6    # below → minor effects
@export var threshold_broken        : float = 0.3    # below → stronger effects

# ─── State ─────────────────────────────────────────────────
var sanity        : float = 1.0    # starts full
var in_safe_zone  : bool  = false

var _player       : Node = null
var _update_timer : float = 0.0
const UPDATE_INTERVAL := 0.5    # check proximity every 0.5s, not per frame

func _ready() -> void:
	_player = get_parent()

func _physics_process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = UPDATE_INTERVAL
		_tick_sanity(UPDATE_INTERVAL)

func _tick_sanity(dt: float) -> void:
	var loss := 0.0

	# Monster proximity
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var dist : float = _player.global_position.distance_to(enemy.global_position)
			if dist < sanity_danger_range:
				var prox : float = 1.0 - dist / sanity_danger_range
				loss += loss_monster_proximity * prox

	# Darkness (optional integration with FearSystem.environment_darkness)
	var fear_sys := _player.get_node_or_null("FearSystem")
	if fear_sys and fear_sys.has_method("get_darkness"):
		loss += loss_darkness * fear_sys.get_darkness()

	var prev := sanity
	if loss > 0.0:
		sanity = clamp(sanity - loss * dt, 0.0, 1.0)
	elif in_safe_zone or not recovery_requires_safe:
		sanity = clamp(sanity + recovery_rate * dt, 0.0, 1.0)

	if abs(sanity - prev) > 0.001:
		sanity_changed.emit(sanity)

# ─── External Triggers ─────────────────────────────────────
# Call these from game events: lore pickups, eldritch scenes, etc.
func apply_sanity_delta(amount: float, reason: String = "", source: Variant = null) -> void:
	var prev := sanity
	sanity = clamp(sanity + amount, 0.0, 1.0)
	if abs(sanity - prev) > 0.001:
		sanity_changed.emit(sanity)
	if reason != "":
		sanity_event.emit(reason, amount, source)

func on_lore_pickup(source: Variant = null) -> void:
	apply_sanity_delta(-loss_lore_pickup, "lore_pickup", source)

func on_eldritch_event(source: Variant = null) -> void:
	apply_sanity_delta(-loss_eldritch_event, "eldritch", source)

func enter_safe_zone() -> void:
	in_safe_zone = true

func exit_safe_zone() -> void:
	in_safe_zone = false

# ─── Modulator Getters (read by other systems) ─────────────
# All return 0.0 at full sanity, scaling to max at sanity=0.

func get_sway_multiplier() -> float:
	# At sanity=0: +40% extra sway on top of Fear sway
	return lerp(0.0, 0.4, _insanity())

func get_ui_distortion() -> float:
	# For shader or UI aberration: 0..1
	return lerp(0.0, 1.0, _insanity()) if sanity < threshold_disturbed else 0.0

func get_audio_distortion() -> float:
	# Feed to AudioEffectDistortion or reverb mix: 0..1
	return lerp(0.0, 0.8, _insanity()) if sanity < threshold_broken else 0.0

func is_disturbed() -> bool:
	return sanity < threshold_disturbed

func is_broken() -> bool:
	return sanity < threshold_broken

func _insanity() -> float:
	return 1.0 - sanity   # convenience: 0=full sanity, 1=insane
