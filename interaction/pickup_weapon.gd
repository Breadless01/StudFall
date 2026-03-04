# pickup_weapon.gd
# Floor pickup for weapons. When interacted, adds weapon to player's WeaponHolder.
class_name PickupWeapon
extends Interactable

@export var weapon_data: WeaponData

func _ready() -> void:
	interaction_prompt = "Pick up " + (weapon_data.display_name if weapon_data else "Weapon")

func set_weapon_data(wd: WeaponData) -> void:
	weapon_data = wd
	interaction_prompt = "Pick up " + wd.display_name

func _on_interact(interactor: Node) -> void:
	if not weapon_data: return
	var holder := interactor.get_node_or_null("WeaponHolder")
	if holder:
		holder.pickup_weapon(weapon_data)
	queue_free()
