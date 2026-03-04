# hitbox_zone.gd  (Feature 2)
# Attach to each hitbox Area3D on the Enemy scene.
# weapon.gd hitscan checks: if collider is HitboxZone → use its multiplier.
#
# Enemy Scene structure:
#   Enemy (CharacterBody3D)
#   ├── CollisionShape3D          ← main physics body
#   ├── HitboxHead (Area3D)       ← hitbox_zone.gd, multiplier=2.0, zone_name="head"
#   │   └── CollisionShape3D     ← small capsule/sphere at head height
#   ├── HitboxBody (Area3D)       ← hitbox_zone.gd, multiplier=1.0, zone_name="body"
#   │   └── CollisionShape3D     ← main torso capsule
#   └── HitboxLimb (Area3D)      ← hitbox_zone.gd, multiplier=0.6, zone_name="limb"
#       └── CollisionShape3D     ← (optional) arms/legs
class_name HitboxZone
extends Area3D

@export var multiplier : float  = 1.0
@export var zone_name  : String = "body"

# Convenience: returns the Enemy (or any CharacterBody3D) that owns this hitbox.
func get_owner_enemy() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterBody3D:
			return p
		p = p.get_parent()
	return null
