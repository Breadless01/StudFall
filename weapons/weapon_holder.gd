# weapon_holder.gd
# Manages inventory (slots), weapon switching, floor pickups, throwables.
# Attach to: Player/WeaponHolder
extends Node3D

signal weapon_changed(weapon_data: WeaponData)
signal inventory_changed(slot_data: Array)   # Feature 4: HUD slot UI listens

@export var slot_count: int = 2

@onready var weapon_pivot   : Node3D  = $WeaponPivot
@onready var interact_ray   : RayCast3D = $InteractRay
@onready var camera         : Camera3D  # set from player

var inventory     : Array[WeaponData]  = []
var current_slot  : int = 0
var _current_weapon_node: Node3D = null

# Throwable
@export var throw_force       := 12.0
@export var throw_scene       : PackedScene  # generic physics object

func _ready() -> void:
	inventory.resize(slot_count)

func setup(p_camera: Camera3D) -> void:
	camera = p_camera

func get_current_weapon() -> Node3D:
	return _current_weapon_node

func get_current_weapon_data() -> WeaponData:
	return inventory[current_slot]

# ─── Equip ──────────────────────────────────────────────────
func equip_slot(slot: int) -> void:
	if slot == current_slot and _current_weapon_node: return
	if slot < 0 or slot >= slot_count: return
	if inventory[slot] == null: return

	# Remove old weapon model
	if _current_weapon_node:
		_current_weapon_node.queue_free()
		_current_weapon_node = null

	current_slot = slot
	var wd := inventory[slot]
	if wd.weapon_scene:
		_current_weapon_node = wd.weapon_scene.instantiate()
		weapon_pivot.add_child(_current_weapon_node)
		if _current_weapon_node.has_method("setup"):
			_current_weapon_node.setup(wd)

	weapon_changed.emit(wd)
	inventory_changed.emit(inventory)   # Feature 4: sync slot UI

func pickup_weapon(wd: WeaponData) -> void:
	var slot := wd.slot
	# Drop current if occupied
	if inventory[slot] != null:
		_drop_current(slot)
	inventory[slot] = wd
	equip_slot(slot)

func _drop_current(slot: int) -> void:
	var old := inventory[slot]
	if old and old.pickup_scene:
		var drop := old.pickup_scene.instantiate()
		get_tree().root.add_child(drop)
		drop.global_position = global_position + Vector3(0, 0.3, 0)
		if drop.has_method("set_weapon_data"):
			drop.set_weapon_data(old)
	inventory[slot] = null

func next_weapon() -> void:
	for i in slot_count:
		var next := wrapi(current_slot + 1 + i, 0, slot_count)
		if inventory[next] != null:
			equip_slot(next)
			return

func prev_weapon() -> void:
	for i in slot_count:
		var prev := wrapi(current_slot - 1 - i, 0, slot_count)
		if inventory[prev] != null:
			equip_slot(prev)
			return

# ─── Throwable ──────────────────────────────────────────────
func throw_object(source_player: Node) -> void:
	if not throw_scene or not camera: return
	var obj := throw_scene.instantiate()
	get_tree().root.add_child(obj)
	obj.global_position = camera.global_position + (-camera.global_basis.z * 0.8)
	if obj is RigidBody3D:
		obj.linear_velocity = -camera.global_basis.z * throw_force
	NoiseBus.emit_noise(obj.global_position, 0.4, "throw", source_player)


# ============================================================
# WEAPON STATE MACHINE STATES — split into individual files:
#   weapon_state_idle.gd      → WeaponStateIdle
#   weapon_state_ads.gd       → WeaponStateADS
#   weapon_state_reloading.gd → WeaponStateReloading
#   weapon_state_throwing.gd  → WeaponStateThrowing
#
# Godot 4 only allows one class_name per .gd file.
# ============================================================
