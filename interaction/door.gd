# door.gd
# Attach to a door scene root. Requires an AnimationPlayer with "open"/"close" anims.
# PickupWeapon and PickupObject have been moved to their own files:
#   pickup_weapon.gd → PickupWeapon
#   pickup_object.gd → PickupObject
class_name Door
extends Interactable

@export var is_locked  : bool = false
@export var lock_hint  : String = "Locked..."

@onready var anim: AnimationPlayer = $AnimationPlayer

var _is_open: bool = false

func _ready() -> void:
	interaction_prompt = "Open" if not is_locked else lock_hint

func _on_interact(interactor: Node) -> void:
	if is_locked:
		# TODO: emit UI message
		print(lock_hint)
		return

	_is_open = !_is_open
	if _is_open:
		anim.play("open")
		interaction_prompt = "Close"
		NoiseBus.emit_noise(global_position, 0.5, "door_open", interactor)
	else:
		anim.play("close")
		interaction_prompt = "Open"
		NoiseBus.emit_noise(global_position, 0.4, "door_close", interactor)

func unlock() -> void:
	is_locked = false
	interaction_prompt = "Open"
