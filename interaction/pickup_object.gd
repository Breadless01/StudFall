# pickup_object.gd
# Generic item pickup (key, note, sanity item, etc.)
class_name PickupObject
extends Interactable

@export var item_id    : String = ""
@export var item_name  : String = "Item"
@export var auto_pick  : bool   = false  # pick up on overlap instead of Use

signal item_picked_up(item_id: String, interactor: Node)

func _ready() -> void:
	interaction_prompt = "Pick up " + item_name
	if auto_pick:
		var area := $Area3D
		if area:
			area.body_entered.connect(_on_body_entered)

func _on_interact(interactor: Node) -> void:
	_collect(interactor)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect(body)

func _collect(who: Node) -> void:
	item_picked_up.emit(item_id, who)
	# TODO: add to inventory system
	print("Picked up: ", item_name)
	queue_free()
