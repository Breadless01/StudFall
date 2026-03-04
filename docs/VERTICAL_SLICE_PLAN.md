# ══════════════════════════════════════════════════════════════════
# A) BESTANDSANALYSE
# ══════════════════════════════════════════════════════════════════
#
# VORHANDENE SIGNALE:
#   weapon.gd          → ammo_changed(current: int, max_val: int)  ✓
#                      → fired(hit_info), reloaded()
#   weapon_holder.gd   → weapon_changed(weapon_data: WeaponData)    ✓
#   enemy.gd           → damaged(amount, hit_info), died()          ✓
#                        max_health/health vorhanden, take_damage() vorhanden
#                        _die() → queue_free() (kein graceful shutdown)
#   player.gd          → damaged(amount, source), died()            ✓
#                        health/max_health vorhanden
#                        take_damage() vorhanden, aber:
#                        • kein health_changed Signal
#                        • kein is_dead Guard
#                        • _die() macht nichts (nur TODO)
#                        • keine Input/Movement-Sperre beim Tod
#
# FEHLENDE SIGNALE / LÜCKEN:
#   player.gd  → health_changed(current, max) fehlt       → PATCH
#   player.gd  → is_dead guard in input + physics         → PATCH
#   player.gd  → _die() implementierung                   → PATCH
#   enemy.gd   → is_dead guard + graceful shutdown        → PATCH
#   enemy.gd   → _die() → Collision off + FSM stop        → PATCH
#   HUD                                                   → NEU
#
# ══════════════════════════════════════════════════════════════════
# B) PATCH-PLAN
# ══════════════════════════════════════════════════════════════════
#
# ÄNDERN (minimal):
#   player/player.gd          → health_changed Signal, is_dead guard, _die()
#   enemy/enemy.gd            → is_dead guard, graceful _die()
#
# NEU ANLEGEN:
#   hud/hud.gd                → HUD Controller
#   hud/hud.tscn              → (beschrieben in Editor Steps)
#   scenes/test_arena.tscn    → (beschrieben in Editor Steps)
#
# NICHT ÄNDERN:
#   weapon.gd, weapon_holder.gd, state_machine.gd,
#   player_states.gd, enemy_state_machine.gd, perception.gd,
#   noise_bus.gd, fear_system.gd, interactable.gd, door.gd
