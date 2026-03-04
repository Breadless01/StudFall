# Lovecraft FPS — Setup & Quick Start Guide
# Godot 4.x / GDScript

## Dateistruktur

```
res://
├── autoload/
│   └── noise_bus.gd              ← Autoload als "NoiseBus"
├── player/
│   ├── player.gd
│   ├── state_machine.gd          ← Generic FSM base
│   ├── player_states.gd          ← Locomotion states
│   └── player.tscn               ← Scene
├── weapons/
│   ├── weapon_resource.gd        ← WeaponData Resource class
│   ├── weapon.gd                 ← Weapon logic node
│   ├── weapon_holder.gd          ← Inventory + WeaponSM states
│   └── data/
│       ├── revolver.tres         ← WeaponData instances
│       └── rifle.tres
├── interaction/
│   ├── interactable.gd
│   └── door.gd                   ← Door + PickupWeapon + PickupObject
├── enemy/
│   ├── enemy.gd
│   ├── enemy_state_machine.gd
│   ├── perception.gd
│   └── enemy_base.tscn
└── systems/
    ├── noise_bus.gd
    └── fear_system.gd
```

## Input Map (Project Settings → Input Map)

Folgende Actions anlegen:

| Action          | Default Key        |
|-----------------|--------------------|
| move_forward    | W                  |
| move_back       | S                  |
| move_left       | A                  |
| move_right      | D                  |
| jump            | Space              |
| sprint          | Left Shift         |
| crouch          | Left Ctrl          |
| lean_left       | Q                  |
| lean_right      | E                  |
| ads             | Right Mouse Button |
| fire            | Left Mouse Button  |
| reload          | R                  |
| interact        | F                  |
| weapon_next     | Mouse Wheel Up     |
| weapon_prev     | Mouse Wheel Down   |
| throw           | G                  |

## Autoload Setup

Project Settings → Autoload:
  Path: res://autoload/noise_bus.gd
  Name: NoiseBus
  Singleton: ✓

## Player Scene Aufbau

```
Player (CharacterBody3D) [player.gd]
├── CollisionShape3D          CapsuleShape3D h=1.8 r=0.4
├── CollisionShape3D_Crouch   CapsuleShape3D h=1.0 r=0.4  [disabled]
├── HeadClearanceRay (RayCast3D)
│     target_position: (0, 1.0, 0)
│     collision_mask: Layer 1
├── CameraRig (Node3D)
│   └── CameraPivot (Node3D)
│       └── Camera3D  fov=85
├── WeaponHolder (Node3D) [weapon_holder.gd]
│   ├── WeaponPivot (Node3D)
│   └── InteractRay (RayCast3D)
│         target_position: (0, 0, -2.5)
│         collision_mask: Layer 1|2|4
├── LocomotionSM (Node) [state_machine.gd]
│   ├── Idle     (Node) [PlayerStateIdle]
│   ├── Walk     (Node) [PlayerStateWalk]
│   ├── Sprint   (Node) [PlayerStateSprint]
│   ├── Crouch   (Node) [PlayerStateCrouch]
│   └── InAir    (Node) [PlayerStateInAir]
├── WeaponSM (Node) [state_machine.gd]
│   ├── WeaponIdle  (Node) [WeaponStateIdle]
│   ├── ADS         (Node) [WeaponStateADS]
│   ├── Reloading   (Node) [WeaponStateReloading]
│   └── Throwing    (Node) [WeaponStateThrowing]
└── FearSystem (Node) [fear_system.gd]
```

## Enemy Scene Aufbau

```
Enemy (CharacterBody3D) [enemy.gd]
├── CollisionShape3D   CapsuleShape3D h=2.0 r=0.5
├── NavigationAgent3D
│     path_desired_distance: 0.5
│     target_desired_distance: 0.8
├── EnemyStateMachine (Node) [state_machine.gd]
│   ├── Idle        [EnemyStateIdle]
│   ├── Investigate [EnemyStateInvestigate]
│   ├── Chase       [EnemyStateChase]
│   ├── Attack      [EnemyStateAttack]
│   ├── Search      [EnemyStateSearch]
│   └── Stunned     [EnemyStateStunned]
├── PerceptionSystem (Node) [perception.gd]
└── AttackHitbox (Area3D)
      CollisionShape3D  SphereShape3D r=2.0
```

## WeaponData Erstellen

1. Godot Editor → FileSystem → Rechtsklick → New Resource
2. WeaponData wählen
3. Felder füllen
4. Als .tres speichern (z.B. res://weapons/data/revolver.tres)
5. Im WeaponHolder inventory[0] = revolver.tres

## Layers Empfehlung

| Layer | Name          | Verwendung                            |
|-------|---------------|---------------------------------------|
| 1     | World         | Statische Welt-Geometrie              |
| 2     | Player        | Player CharacterBody3D                |
| 3     | Enemy         | Enemy CharacterBody3D                 |
| 4     | Interactable  | Türen, Pickups (für InteractRay)      |
| 5     | Projectile    | Throwables                            |

Vision-Ray: mask = Layer 1 (World only — Enemy-Körper blockieren nicht)
Hitscan:    mask = Layer 1|3 (World + Enemy)
InteractRay: mask = Layer 1|4 (World + Interactable)

## Erste Schritte / Minimaler Test

1. NoiseBus als Autoload registrieren
2. Player-Scene in Level platzieren, Layer 2 setzen
3. NavigationRegion3D backen
4. Enemy-Scene platzieren, Layer 3 setzen
5. Eine WeaponData .tres erstellen und inventory[0] setzen
6. Play — WASD + RMB (ADS) + LMB (Fire) + F (Interact)

## Erweiterungen (geplant)

- Patrol waypoints für Idle-State (Enemy)
- Hitbox Zone system (Head/Body/Limb) via separate Areas
- Ranged Enemy Attack (stub in enemy.gd → override do_ranged_attack)
- Inventory UI (AmmoChanged signal bereits vorhanden)
- Sanity/Lore system als weiterer System-Node
- LightDetection für Fear gain (WorldEnvironment sampling)
