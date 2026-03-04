# weapon_resource.gd
# Data-driven weapon configuration.
# Create as: File → New Resource → WeaponData
# Store as .tres files, e.g. res://weapons/data/revolver.tres
class_name WeaponData
extends Resource

@export_group("Identity")
@export var display_name      : String      = "Unknown Weapon"
@export var weapon_scene      : PackedScene              # 3D model scene

@export_group("Combat")
@export var damage            : float       = 35.0
@export var fire_rate         : float       = 2.5        # shots/sec
@export var is_auto           : bool        = false
@export var magazine_size     : int         = 6
@export var reload_time       : float       = 2.0        # seconds
@export var range             : float       = 80.0       # hitscan max dist
@export var damage_falloff_start: float     = 30.0       # full dmg within

@export_group("ADS")
@export var ads_fov           : float       = 60.0
@export var ads_sensitivity_mult: float     = 0.65
@export var ads_time          : float       = 0.18       # seconds to reach ADS

@export_group("Recoil")
@export var recoil_vertical   : float       = 1.8        # degrees per shot
@export var recoil_horizontal : float       = 0.4        # degrees per shot (random ±)
@export var recoil_recovery_speed: float    = 6.0        # deg/sec recovery
@export var camera_kick_mult  : float       = 0.7        # fraction goes to camera
@export var weapon_kick_mult  : float       = 0.3        # rest to weapon model

@export_group("Sway")
@export var sway_amount       : float       = 0.04       # world units
@export var sway_speed        : float       = 4.0        # lerp speed
@export var sway_look_mult    : float       = 0.015      # mouse delta → sway
@export var ads_sway_mult     : float       = 0.25       # sway scale in ADS

@export_group("Audio / FX")
@export var shoot_sound       : AudioStream
@export var reload_sound      : AudioStream
@export var empty_click_sound : AudioStream
@export var impact_fx_scene   : PackedScene  # spawned on hit surface
@export var muzzle_flash_scene: PackedScene

@export_group("Inventory")
@export var slot              : int         = 0          # 0=primary, 1=secondary
@export var pickup_scene      : PackedScene  # for floor pickup
