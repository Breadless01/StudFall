# B) State Machine Design

## ARCHITEKTUR-ENTSCHEIDUNG: Layered State Machine

Statt einer monolithischen FSM (die bei "ADS + Sprint + Crouch" explodieren würde)
verwenden wir **2 parallele Layer-FSMs**:

```
Layer 1 (Locomotion):  Idle | Walk | Sprint | Crouch | InAir | Lean*
                       (player/player_state_*.gd — one file per state)
Layer 2 (Weapon):      WeaponIdle | ADS | Reloading | Throwing
                       (weapons/weapon_state_*.gd — one file per state)
```

Lean ist ein **Overlay** (kein echter State), da es mit allen Locomotion-States kombinierbar ist.
Interaction ist ein **kurzer Interrupt** der Locomotion-Layer (kurze blockierung, dann zurück).

**Warum nicht ein State?**
→ ADS+Walk, Sprint→ADS cancel, Crouch+ADS müssen alle gleichzeitig funktionieren.
→ Layered States erlauben unabhängige Transitions ohne O(n²) Zustandskombinationen.

---

## PLAYER STATE MACHINE — Locomotion Layer

```
                    ┌──────────────────────────────────────────────┐
                    │              LOCOMOTION LAYER                 │
                    │                                               │
          ┌─────────┴─────────┐                                    │
          │       IDLE        │◄──── no input + grounded           │
          └────────┬──────────┘                                    │
                   │ move input                                     │
                   ▼                                                │
          ┌────────────────────┐                                   │
          │       WALK         │◄──── move input, no sprint        │
          └─┬──────────────────┘                                   │
            │  sprint key        │ no input                        │
            ▼                    ▼                                 │
   ┌──────────────────┐     [→ IDLE]                               │
   │     SPRINT       │                                            │
   └──────────────────┘                                            │
            │ crouch                                               │
            ▼                                                      │
   ┌──────────────────┐                                            │
   │     CROUCH       │ ◄── crouch toggle / hold                  │
   └──────────────────┘                                            │
                                                                   │
   ┌──────────────────┐                                            │
   │     IN_AIR       │ ◄── not on floor (jump / fall)            │
   └──────────────────┘                                            │
                    │                                               │
                    └──────────────────────────────────────────────┘

LEAN OVERLAY (any locomotion state):
  Q held → lean_left  (camera + body offset, wall check)
  E held → lean_right (camera + body offset, wall check)
  No key → lerp back to center
```

---

## PLAYER STATE MACHINE — Weapon Layer

```
                    ┌──────────────────────────────────────────────┐
                    │               WEAPON LAYER                    │
                    │                                               │
          ┌─────────┴──────────┐                                   │
          │    WEAPON_IDLE     │ ◄── default                       │
          └─┬──────────────────┘                                   │
            │                                                       │
            ├─── ads_pressed ──► ADS ──── ads_released ──► IDLE   │
            │                                                       │
            ├─── fire ─────────► FIRING                            │
            │                      │ (auto: held; semi: once)      │
            │                      ▼                               │
            │                   [back to IDLE / continue]          │
            │                                                       │
            ├─── reload ───────► RELOADING ──timer──► IDLE        │
            │                                                       │
            ├─── throw ────────► THROWING ──anim──► IDLE          │
            │                                                       │
            └─── weapon_next ──► SWITCHING ──timer──► IDLE        │
                    │                                               │
                    └──────────────────────────────────────────────┘

KOMBINATIONEN:
  ADS + Firing:   erlaubt (firing state innerhalb ADS)
  Sprint + ADS:   ADS cancelled beim Sprint-Eintritt
  Reload + Fire:  Fire ignoriert während RELOADING
```

---

## ENEMY STATE MACHINE

```
                         ┌────────────────────────────────────────────┐
                         │            ENEMY STATE MACHINE              │
                         │                                              │
  ┌──────────────────────┴──┐                                          │
  │         IDLE            │ suspicion < 0.3                          │
  │   (optional patrol stub)│                                          │
  └────────────┬────────────┘                                          │
               │ suspicion > 0.3                                       │
               ▼                                                       │
  ┌────────────────────────┐                                           │
  │      INVESTIGATE        │ ← noise/glimpse, go to last_known_pos   │
  └────────────┬────────────┘                                          │
               │ suspicion > 0.6 OR player_visible                    │
               ▼                                                       │
  ┌────────────────────────┐     ┌─────────────────────────┐          │
  │        CHASE            │────►│         ATTACK          │          │
  │  NavigationAgent chase  │◄────│  in attack_range + cd   │          │
  └────────────┬────────────┘     └─────────────────────────┘          │
               │ target_lost + timer                                   │
               ▼                                                       │
  ┌────────────────────────┐                                           │
  │        SEARCH           │ patrol last_known_pos area               │
  └────────────┬────────────┘                                          │
               │ suspicion decayed < 0.3                               │
               ▼                                                       │
           [→ IDLE]                                                    │
                                                                       │
  ┌────────────────────────┐                                           │
  │        STUNNED          │ ← damage flinch placeholder              │
  │  (any state → stunned) │                                           │
  └────────────────────────┘                                           │
                         └────────────────────────────────────────────┘

SUSPICION THRESHOLDS:
  0.00 – 0.30 → IDLE
  0.30 – 0.60 → INVESTIGATE
  0.60 – 1.00 → CHASE / ATTACK
```
