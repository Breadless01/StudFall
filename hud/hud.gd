# hud.gd — PATCH v2  (Feature 4: Inventory Slot UI)
# Changes vs v1:
#   + SlotContainer with per-slot panels (Primary/Secondary)
#   + Active slot highlighted
#   + weapon_holder emits inventory_changed → slots update
#   + All updates event-driven (no polling)
extends CanvasLayer

# ─── Node References ───────────────────────────────────────
@onready var ammo_label     : Label       = $HUDRoot/AmmoLabel
@onready var health_bar     : ProgressBar = $HUDRoot/HealthBar
@onready var health_label   : Label       = $HUDRoot/HealthLabel
@onready var minimap_panel  : Panel       = $HUDRoot/MinimapPanel
@onready var player_dot     : ColorRect   = $HUDRoot/MinimapPanel/PlayerDot
@onready var enemy_dot_root : Node2D      = $HUDRoot/MinimapPanel/EnemyDots
@onready var game_over      : Control     = $HUDRoot/GameOverOverlay
@onready var restart_btn    : Button      = $HUDRoot/GameOverOverlay/RestartButton
@onready var minimap_timer  : Timer       = $MinimapTimer
# Feature 4: Slot UI container (holds SlotPanel_0, SlotPanel_1, ...)
@onready var slot_container : HBoxContainer = $HUDRoot/SlotContainer

# ─── Config ────────────────────────────────────────────────
@export var minimap_radius  : float = 80.0
@export var minimap_scale   : float = 0.04
@export var enemy_dot_color : Color = Color(1, 0.15, 0.15, 0.9)
@export var player_dot_color: Color = Color(0.2, 0.8, 1.0, 1.0)

# Feature 4 colors
const SLOT_ACTIVE_COLOR   := Color(1.0, 0.85, 0.2, 1.0)   # gold border
const SLOT_INACTIVE_COLOR := Color(0.4, 0.4, 0.4, 0.6)
const SLOT_EMPTY_COLOR    := Color(0.2, 0.2, 0.2, 0.5)

# ─── Internal ──────────────────────────────────────────────
var _player              : Node3D = null
var _current_weapon_node : Node   = null
var _enemy_dot_pool      : Array[ColorRect] = []
var _slot_panels         : Array[Panel] = []   # Feature 4

func _ready() -> void:
	game_over.visible = false
	restart_btn.pressed.connect(_on_restart_pressed)
	call_deferred("_init_minimap")
	minimap_timer.wait_time = 0.15
	minimap_timer.autostart = true
	minimap_timer.timeout.connect(_update_minimap)
	minimap_timer.start()
	call_deferred("_wire_to_player")

func _init_minimap() -> void:
	var c := minimap_panel.size * 0.5
	player_dot.color    = player_dot_color
	player_dot.size     = Vector2(10, 10)
	player_dot.position = c - player_dot.size * 0.5

# ─── Player Wiring ─────────────────────────────────────────
func _wire_to_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("HUD: no node in group 'player'"); return
	_player = players[0]
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)

	var holder := _player.get_node_or_null("WeaponHolder")
	if holder:
		if holder.has_signal("weapon_changed"):
			holder.weapon_changed.connect(_on_weapon_changed)
		# Feature 4: connect inventory_changed if it exists
		if holder.has_signal("inventory_changed"):
			holder.inventory_changed.connect(_on_inventory_changed)

	_on_health_changed(_player.health, _player.max_health)
	_sync_ammo_from_holder()
	_build_slot_ui()      # Feature 4: build slot panels

# ─── Health ────────────────────────────────────────────────
func _on_health_changed(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value     = current
	health_label.text    = "%d / %d" % [int(current), int(max_val)]
	health_bar.modulate  = Color(1.0, 0.3, 0.3) if current / max_val < 0.3 else Color.WHITE

# ─── Ammo ──────────────────────────────────────────────────
func _on_weapon_changed(wd) -> void:
	if _current_weapon_node and is_instance_valid(_current_weapon_node):
		if _current_weapon_node.ammo_changed.is_connected(_on_ammo_changed):
			_current_weapon_node.ammo_changed.disconnect(_on_ammo_changed)
	_sync_ammo_from_holder()
	_refresh_slot_highlight()   # Feature 4

func _sync_ammo_from_holder() -> void:
	if not _player: return
	var holder := _player.get_node_or_null("WeaponHolder")
	if not holder: return
	var weapon = holder.get_current_weapon()
	if not weapon or not weapon.has_signal("ammo_changed"):
		ammo_label.text = "-- / --"; return
	_current_weapon_node = weapon
	if not weapon.ammo_changed.is_connected(_on_ammo_changed):
		weapon.ammo_changed.connect(_on_ammo_changed)
	var mag : int = weapon.data.magazine_size if weapon.data else 0
	_on_ammo_changed(weapon.current_ammo, mag)

func _on_ammo_changed(current: int, max_val: int) -> void:
	ammo_label.text = "%d / %d" % [current, max_val]
	# Also update the active slot ammo sub-label (Feature 4)
	if not _player: return
	var holder := _player.get_node_or_null("WeaponHolder")
	if holder:
		_update_slot_ammo(holder.current_slot, current, max_val)
	if current == 0:
		var t := create_tween()
		t.tween_property(ammo_label, "modulate", Color(1, 0.2, 0.2), 0.1)
		t.tween_property(ammo_label, "modulate", Color.WHITE, 0.4)

# ─── Feature 4: Inventory Slot UI ──────────────────────────
# Dynamically build one panel per weapon slot.
# Structure per panel:
#   Panel (border = active/inactive color)
#   ├── VBoxContainer
#   │   ├── SlotLabel  "P" / "S"  (Primary / Secondary)
#   │   ├── WeaponName (Label)
#   │   └── AmmoSub    (Label, small)  "6/6"

func _build_slot_ui() -> void:
	if not slot_container: return
	# Clear existing
	for child in slot_container.get_children():
		child.queue_free()
	_slot_panels.clear()

	var holder = _player.get_node_or_null("WeaponHolder") if _player else null
	var slot_count : int = holder.slot_count if holder else 2

	var slot_labels := ["P", "S", "3", "4"]

	for i in slot_count:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(64, 72)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var slot_lbl := Label.new()
		slot_lbl.name = "SlotLabel"
		slot_lbl.text = slot_labels[i] if i < slot_labels.size() else str(i)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.modulate = Color(0.7, 0.7, 0.7)

		var name_lbl := Label.new()
		name_lbl.name = "WeaponName"
		name_lbl.text = "Empty"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.custom_minimum_size = Vector2(60, 0)

		var ammo_lbl := Label.new()
		ammo_lbl.name = "AmmoSub"
		ammo_lbl.text = ""
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.add_theme_font_size_override("font_size", 10)
		ammo_lbl.modulate = Color(0.8, 0.8, 0.8)

		vbox.add_child(slot_lbl)
		vbox.add_child(name_lbl)
		vbox.add_child(ammo_lbl)
		panel.add_child(vbox)
		slot_container.add_child(panel)
		_slot_panels.append(panel)

	_refresh_slot_contents()
	_refresh_slot_highlight()

func _refresh_slot_contents() -> void:
	if not _player: return
	var holder := _player.get_node_or_null("WeaponHolder")
	if not holder: return
	for i in _slot_panels.size():
		var wd : WeaponData = holder.inventory[i] if i < holder.inventory.size() else null
		_update_slot_data(i, wd)

func _update_slot_data(slot_idx: int, wd) -> void:
	if slot_idx >= _slot_panels.size(): return
	var panel := _slot_panels[slot_idx]
	var name_lbl := panel.get_node_or_null("VBoxContainer/WeaponName") as Label
	var ammo_lbl := panel.get_node_or_null("VBoxContainer/AmmoSub") as Label
	if name_lbl:
		name_lbl.text = wd.display_name if wd else "Empty"
	if ammo_lbl:
		ammo_lbl.text = ""   # filled when ammo_changed fires

func _update_slot_ammo(slot_idx: int, current: int, max_val: int) -> void:
	if slot_idx >= _slot_panels.size(): return
	var ammo_lbl := _slot_panels[slot_idx].get_node_or_null("VBoxContainer/AmmoSub") as Label
	if ammo_lbl:
		ammo_lbl.text = "%d/%d" % [current, max_val]

func _refresh_slot_highlight() -> void:
	if not _player: return
	var holder := _player.get_node_or_null("WeaponHolder")
	var active : int = holder.current_slot if holder else 0
	for i in _slot_panels.size():
		var panel := _slot_panels[i]
		var style := StyleBoxFlat.new()
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
		var has_weapon : bool = holder and i < holder.inventory.size() and holder.inventory[i] != null
		if i == active and has_weapon:
			style.border_color  = SLOT_ACTIVE_COLOR
			style.bg_color      = Color(0.15, 0.15, 0.05, 0.8)
		elif has_weapon:
			style.border_color  = SLOT_INACTIVE_COLOR
			style.bg_color      = Color(0.1, 0.1, 0.1, 0.7)
		else:
			style.border_color  = SLOT_EMPTY_COLOR
			style.bg_color      = Color(0.05, 0.05, 0.05, 0.5)
		panel.add_theme_stylebox_override("panel", style)

# Called when weapon_holder fires inventory_changed (optional signal)
func _on_inventory_changed(slot_data: Array) -> void:
	for i in slot_data.size():
		_update_slot_data(i, slot_data[i])
	_refresh_slot_highlight()

# ─── Minimap ───────────────────────────────────────────────
func _update_minimap() -> void:
	if not _player or not is_instance_valid(_player): return
	var enemies      := get_tree().get_nodes_in_group("enemies")
	var panel_center := minimap_panel.size * 0.5
	while _enemy_dot_pool.size() < enemies.size():
		var dot        := ColorRect.new()
		dot.color       = enemy_dot_color
		dot.size        = Vector2(8, 8)
		enemy_dot_root.add_child(dot)
		_enemy_dot_pool.append(dot)
	for i in _enemy_dot_pool.size():
		_enemy_dot_pool[i].visible = i < enemies.size()
	var yaw := 0.0
	var cam_rig := _player.get_node_or_null("CameraRig")
	if cam_rig: yaw = cam_rig.rotation.y
	for i in enemies.size():
		var e := enemies[i] as Node3D
		if not is_instance_valid(e): continue
		var diff   := e.global_position - _player.global_position
		var offset := Vector2(diff.x, diff.z) * minimap_scale
		offset      = offset.rotated(-yaw)
		if offset.length() > minimap_radius - 6.0:
			offset = offset.normalized() * (minimap_radius - 6.0)
		_enemy_dot_pool[i].position = panel_center + offset - _enemy_dot_pool[i].size * 0.5

# ─── Game Over ─────────────────────────────────────────────
func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	game_over.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
