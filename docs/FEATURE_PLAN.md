# A) BESTANDSANALYSE — Touchpoints pro Feature

## Feature 1: Patrol Waypoints
- enemy_state_machine.gd / EnemyStateIdle.physics_update()
  → Touchpoint: nach stop_movement() — hier Patrol-Logik einhängen
- enemy.gd
  → patrol_enabled, patrol_speed_multiplier, patrol_wait_time exports
  → patrol_path: NodePath export → aufgelöster Node mit Marker3D children
- KEIN Eingriff in perception.gd nötig (Idle prüft already perc thresholds)

## Feature 2: Hitbox Zone System
- weapon.gd / _do_hitscan()
  → result["collider"] kann Area3D (Hitbox) sein NICHT CharacterBody3D
  → Touchpoint: nach intersect_ray() — prüfe ob collider ein HitboxZone ist
- enemy.gd / take_damage()
  → nimmt hit_info["multiplier"] bereits entgegen (zone-string), aber
    aktuell nur "head"/"body" string-check → ersetzen durch numeric multiplier
- NEU: hitbox_zone.gd — kleines Script auf jedem Area3D

## Feature 3: Ranged Enemy Attack
- enemy.gd
  → Touchpoint: do_melee_attack() / can_attack() Bereich
  → NEU: attack_mode enum + do_ranged_attack() stub
- enemy_state_machine.gd / EnemyStateAttack.enter() + update()
  → Touchpoint: do_melee_attack() → dispatch via enemy.attack_mode

## Feature 4: Inventory UI
- hud.gd + hud_scene_setup.md
  → Existiert bereits: AmmoLabel für aktives Slot
  → Touchpoint: _on_weapon_changed(), _sync_ammo_from_holder()
  → Erweitern um Slot-Anzeige (Primary/Secondary icons + active highlight)
- weapon_holder.gd
  → weapon_changed signal bereits vorhanden ✓
  → NEU: emit inventory_changed(slot_data_array) für Slot-UI update

## Feature 5: Sanity System
- NEU: systems/sanity_system.gd (separater Node, child of Player)
- player.gd
  → Touchpoint: _ready() → get_node_or_null("SanitySystem")
  → Optional: sanity abfragen in weapon sway / fear system
- fear_system.gd
  → Touchpoint: get_sway_multiplier() → kann sanity mit einrechnen (optional)

## Feature 6: LightDetection für Fear
- fear_system.gd / _update_fear()
  → Touchpoint: # gain += gain_darkness (bereits als Placeholder vorhanden!)
  → Aktivieren + environment_darkness Variable
- WAHL: Option B (DarkZone Area3D Trigger Volumes)
  → Begründung: Option A (Light Raycasts) erfordert Wissen über Light-Node Positionen
    und ist unzuverlässig bei mehreren Quellen. Option C (Viewport Luminance) ist
    GPU-readback = teuer + 1-Frame-Delay. Option B ist O(1) pro Overlap-Event,
    0 Overhead pro Frame, und erlaubt Level-Designer-Kontrolle.
  → NEU: dark_zone.gd — Area3D Script das FearSystem.set_darkness() aufruft
