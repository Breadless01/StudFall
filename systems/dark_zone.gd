# dark_zone.gd  (Feature 6)
# Attach to an Area3D node in the level to define a "dark zone".
# When the player enters, FearSystem receives increased darkness_factor.
# Multiple overlapping zones stack (highest value wins).
#
# Why Option B (Trigger Volumes) over A/C:
#   A (light raycasts): requires knowing all light positions, unreliable with
#     dynamic lights, O(n_lights) raycasts per frame.
#   C (viewport luminance): GPU readback is expensive and adds 1-frame latency.
#   B: O(1) per overlap event, zero per-frame cost, full level-designer control.
#
# Scene setup:
#   DarkZone (Area3D)  ← dark_zone.gd
#   ├── CollisionShape3D  ← box/capsule covering the dark area
#   └── (monitoring=true, monitorable=false, layer=none, mask=Layer2/Player)
class_name DarkZone
extends Area3D

@export var darkness_factor : float = 0.8   # 0=no effect, 1=pitch black

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	var fear := body.get_node_or_null("FearSystem")
	if fear and fear.has_method("register_dark_zone"):
		fear.register_dark_zone(self, darkness_factor)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	var fear := body.get_node_or_null("FearSystem")
	if fear and fear.has_method("unregister_dark_zone"):
		fear.unregister_dark_zone(self)
