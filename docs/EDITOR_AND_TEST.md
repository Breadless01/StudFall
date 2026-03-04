# D) EDITOR / SCENE STEPS  +  E) TEST CHECKLIST
# ══════════════════════════════════════════════════════════════════

## Feature 1: Patrol Waypoints

### Scene Setup (Enemy)
1. In `enemy_base.tscn`, add a child: `PatrolPath` (Node3D)
2. Under PatrolPath, add 3–4 `Marker3D` nodes at world positions
   (e.g. four corners of a patrol route)
3. Select Enemy root → Inspector:
   - Patrol → patrol_enabled: ✓ ON
   - patrol_path: drag PatrolPath node into NodePath field
   - patrol_wait_time: 2.0
   - patrol_speed_mult: 0.7

### Notes
- PatrolPath can also be a shared path in the level (not a child of Enemy):
  set patrol_path to a level-global NodePath in that case.
- Patrol is interrupted IMMEDIATELY when perception threshold rises ≥ 0.3.

### Test Checklist
- [ ] Enemy walks between waypoints in order, pauses at each
- [ ] Throw a rock near enemy → Enemy switches to Investigate (interrupts patrol)
- [ ] Enemy kills player → Enemy eventually resumes patrol (after search → idle)

---

## Feature 2: Hitbox Zone System

### Scene Setup (Enemy)
Under Enemy root, add 3 Area3D children:

```
Enemy (CharacterBody3D)
├── CollisionShape3D           ← physics body (Layer 3, Mask 1|2)
├── HitboxHead (Area3D)        ← hitbox_zone.gd
│   CollisionShape3D           ← SphereShape3D r=0.18, pos y=1.7
│   Monitoring: OFF, Monitorable: ON
│   Layer: 8 (Hitbox), Mask: 0
├── HitboxBody (Area3D)        ← hitbox_zone.gd
│   CollisionShape3D           ← CapsuleShape3D h=0.9 r=0.28, pos y=1.0
│   Monitoring: OFF, Monitorable: ON
│   Layer: 8 (Hitbox), Mask: 0
└── HitboxLimb (Area3D)        ← hitbox_zone.gd (optional)
    CollisionShape3D           ← custom shape
    Monitoring: OFF, Monitorable: ON
    Layer: 8 (Hitbox), Mask: 0
```

Inspector per HitboxZone:
- HitboxHead: multiplier=2.0, zone_name="head"
- HitboxBody: multiplier=1.0, zone_name="body"
- HitboxLimb: multiplier=0.6, zone_name="limb"

Physics Layer setup:
- Layer 8: "Hitbox" (new layer)
- Hitscan mask in weapon.gd: 0xFFFFFFFF → hits both Layer 3 (body) and Layer 8 (hitboxes)
- Important: Area3D must be `Monitorable: ON` so RayCast can detect it

### Test Checklist
- [ ] Shoot enemy body → normal damage (1.0x)
- [ ] Aim high at head → enemy dies faster (2.0x multiplier)
- [ ] Print hit_info["zone"] in enemy.take_damage() to verify string

---

## Feature 3: Ranged Enemy

### Scene Setup
1. Select enemy instance → Inspector:
   - Attack → attack_mode: RANGED
   - ranged_range: 15.0
   - ranged_cooldown: 3.0
2. Enemy will now call do_ranged_attack() in Attack state instead of melee.
3. For custom projectile behavior: extend Enemy, override do_ranged_attack().

### Test Checklist
- [ ] Enemy enters Attack state when player in ranged_range + visible
- [ ] Enemy deals damage to player without entering melee range
- [ ] Blocked by wall (LOS check in do_ranged_attack) → no damage through wall

---

## Feature 4: Inventory UI

### Scene Setup (hud.tscn)
Add to HUDRoot:
```
SlotContainer (HBoxContainer)
  Anchor: Bottom Right
  Offset: (-300, -100, -20, -30)
  Separation: 8
```
(No children needed — _build_slot_ui() creates them at runtime)

### Notes
- Slot panels are built dynamically based on weapon_holder.slot_count
- Active slot: gold border. Filled inactive: grey border. Empty: dark.
- Ammo sub-label updates via existing ammo_changed signal (no new polling)

### Test Checklist
- [ ] Start with pistol in slot 0 → slot 0 highlighted gold, shows name + ammo
- [ ] Pick up second weapon → slot 1 panel fills with weapon name
- [ ] Switch weapon (scroll wheel) → gold highlight moves to new slot
- [ ] Fire → ammo sub-label in active slot counts down

---

## Feature 5: Sanity System

### Scene Setup (Player)
Add to Player scene:
```
SanitySystem (Node)   ← sanity_system.gd
```
No additional nodes needed. Connects to FearSystem automatically via get_node_or_null.

### Integration Hooks
- Lore pickup: call `player.get_node("SanitySystem").on_lore_pickup(pickup_node)`
- Eldritch event: `sanity_system.on_eldritch_event()`
- Sway modifier: in weapon.gd process_sway(), add sanity sway:
  ```gdscript
  var sanity_sys := owner.get_node_or_null("SanitySystem")
  var sanity_mult := sanity_sys.get_sway_multiplier() if sanity_sys else 0.0
  amount *= (1.0 + sanity_mult)
  ```

### Test Checklist
- [ ] sanity_changed signal fires (connect in debug print)
- [ ] Stand near enemy for 10s → sanity drops below 1.0
- [ ] Call on_lore_pickup() → immediate sanity drop (0.05)
- [ ] Enter safe zone (enter_safe_zone()) → sanity slowly recovers

---

## Feature 6: LightDetection (DarkZone)

### Scene Setup (Level)
For each dark area (corridor, basement, unlit room):
```
DarkZone (Area3D)         ← dark_zone.gd
  CollisionShape3D        ← BoxShape3D covering the area (e.g. 10x4x10)
  Monitoring: ON
  Monitorable: OFF
  Layer: 0 (no layer needed)
  Mask: Layer 2 (Player only)
Inspector:
  darkness_factor: 0.8    (0=no extra fear, 1=maximum darkness gain)
```

### Notes
- Multiple overlapping DarkZones: highest darkness_factor wins (no sum)
- darkness_factor=0.8 means fear gains 0.025 × 0.8 = 0.02/s from darkness
- FearSystem.environment_darkness is readable by SanitySystem too

### Test Checklist
- [ ] Walk into DarkZone area → fear_system.environment_darkness rises to 0.8
- [ ] fear_changed signal shows Fear slowly rising even without enemies
- [ ] Walk out of DarkZone → environment_darkness drops to 0.0
- [ ] Two overlapping zones (0.5 + 0.9) → environment_darkness = 0.9 (max wins)
