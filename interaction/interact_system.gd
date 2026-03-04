# interact_system.gd
# Player-side raycast logic for detecting and triggering Interactable objects.
# Attach to Player or as a child node.
class_name InteractSystem
extends Node

@export var reach: float = 2.5
@onready var _ray: RayCast3D = $InteractRay  # already set up in scene

var _current_target: Interactable = null

func _process(_delta: float) -> void:
	_update_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _current_target and _current_target.can_interact():
			var player := get_parent()
			_current_target.interact(player)
			NoiseBus.emit_noise(player.global_position, 0.2, "interact", player)

func _update_target() -> void:
	if _ray.is_colliding():
		var col := _ray.get_collider()
		var interact := _find_interactable(col)
		_current_target = interact
		# TODO: emit UI hint event
	else:
		_current_target = null

func _find_interactable(node: Node) -> Interactable:
	if node is Interactable:
		return node
	var parent := node.get_parent()
	while parent:
		if parent is Interactable:
			return parent
		parent = parent.get_parent()
	return null
