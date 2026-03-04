# Lovecraft FPS — Architekturübersicht (Godot 4.x)

## A) NODE TREE

```
World (Node3D)
├── NoiseBus (Node)               ← Autoload/Singleton
├── NavigationRegion3D
│   └── Level (Node3D)
│       ├── Lights, Props, Doors...
│       └── EnemySpawner
│
└── Player (CharacterBody3D)      ← player.gd
    ├── CollisionShape3D          ← CapsuleShape3D (tall)
    ├── CollisionShape3D_Crouch   ← CapsuleShape3D (short, disabled)
    ├── HeadClearanceRay (RayCast3D) ← nach oben für Crouch-check
    │
    ├── CameraRig (Node3D)        ← yaw pivot
    │   └── CameraPivot (Node3D)  ← pitch pivot + lean
    │       └── Camera3D          ← FOV, main camera
    │
    ├── WeaponHolder (Node3D)     ← weapon_holder.gd
    │   ├── WeaponPivot (Node3D)  ← sway/recoil offset hier
    │   │   └── [CurrentWeapon]   ← weapon.gd instanz
    │   └── InteractRay (RayCast3D) ← für "Use" + weapon pickup
    │
    ├── StateMachine (Node)       ← state_machine.gd (Locomotion)
    ├── WeaponStateMachine (Node) ← state_machine.gd (Weapon Layer)
    ├── FearSystem (Node)         ← fear_system.gd
    ├── SanitySystem (Node)       ← sanity_system.gd
    └── AudioPlayers...

Enemy (CharacterBody3D)          ← enemy.gd
    ├── CollisionShape3D
    ├── NavigationAgent3D
    ├── EnemyStateMachine (Node)  ← enemy_state_*.gd (one file per state)
    ├── PerceptionSystem (Node)   ← perception.gd
    │   ├── VisionRay (RayCast3D)
    │   └── HearingRadius (Area3D) ← optional visualization
    └── AttackHitbox (Area3D)     ← melee range check
```

---

## SYSTEME & DATENFLUSS

```
INPUT LAYER
  Input.is_action_pressed(...)
         │
         ▼
  Player StateMachine (Locomotion Layer)
  ┌──────────────────────────────────┐
  │  Idle ↔ Walk ↔ Sprint            │
  │    ↕         ↕                   │
  │  Crouch    InAir                 │
  │    +                             │
  │  Lean (L/R overlay)              │
  └──────────────────────────────────┘
         │ velocity
         ▼
  CharacterBody3D.move_and_slide()

  Weapon StateMachine (parallel Layer)
  ┌──────────────────────────────────┐
  │  Idle → Firing → Reloading       │
  │       → ADS                      │
  │  Throw → (physics projectile)    │
  └──────────────────────────────────┘
         │ fire → RayCast → HitInfo
         ▼
  Enemy.damage(amount, hit_info)
         │
         ▼
  Enemy StateMachine (Suspicion-driven)
  ┌──────────────────────────────────┐
  │  Idle → Investigate → Chase      │
  │            ↑              │      │
  │      NoiseBus.on_noise    │      │
  │            ↑         Attack      │
  └────────────┼─────────────────────┘
               │
  NoiseBus ←── Player (sprint, shoot, interact)
  (Autoload)
         │ emit_noise(pos, loudness, tag)
         ▼
  PerceptionSystem.on_noise(...)
         │ updates suspicion
         ▼
  EnemyStateMachine transitions

  FearSystem
  ←── enemy proximity, low health, dark areas
  ──► Camera shake, sway multiplier, ADS speed
```

---

## DATEN-DRIVEN WAFFEN (WeaponData Resource)

```
WeaponData (Resource)
  display_name: String
  damage: float
  fire_rate: float          # shots/sec
  is_auto: bool
  magazine_size: int
  reload_time: float
  ads_fov: float            # z.B. 55.0
  ads_sensitivity_mult: float
  recoil_vertical: float
  recoil_horizontal: float
  recoil_recovery_speed: float
  sway_amount: float
  sway_speed: float
  ads_sway_mult: float
  range: float              # hitscan max distance
  damage_falloff_start: float
  impact_fx_scene: PackedScene
  shoot_sound: AudioStream
  reload_sound: AudioStream
  weapon_scene: PackedScene
```

---

## SIGNALS (Event Bus Pattern)

```
Player:
  signal damaged(amount: float, source: Node)
  signal died()
  signal health_changed(current: float, max_val: float)
  signal weapon_changed(weapon_data: WeaponData)
  signal interacted(target: Node)

Enemy:
  signal damaged(amount: float, hit_info: Dictionary)
  signal died()
  signal state_changed(new_state: String)

NoiseBus:
  signal noise_emitted(pos: Vector3, loudness: float, tag: String, source: Node)
```
