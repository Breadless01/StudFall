# interactable.gd
# Base interface for all interactable objects.
# Extends Node3D so subclasses (Door, pickups) can use global_position.
# InteractSystem has been moved to interact_system.gd.
class_name Interactable
extends Node3D

signal interacted(interactor: Node)

@export var interaction_prompt: String = "Use"
@export var is_enabled: bool = true

# Override in subclasses
func interact(interactor: Node) -> void:
	if not is_enabled: return
	_on_interact(interactor)
	interacted.emit(interactor)

func _on_interact(_interactor: Node) -> void:
	pass  # override

func can_interact() -> bool:
	return is_enabled
