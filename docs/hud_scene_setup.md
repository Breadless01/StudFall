# D) GODOT EDITOR STEPS — HUD Scene + Test Arena
# ══════════════════════════════════════════════════════════════════

## 1. HUD Scene (hud.tscn)

Create a new scene with root type CanvasLayer, save as res://hud/hud.tscn.
Attach script: res://hud/hud.gd

Node Tree to build:
```
HUD (CanvasLayer)   ← hud.gd
├── HUDRoot (Control)
│     Anchors: Full Rect (Layout → Full Rect)
│
│   ── AMMO (bottom-right) ──────────────────────────────────
│   ├── AmmoLabel (Label)
│         Anchor: Bottom Right
│         Offset: (-180, -60, -20, -30)
│         Text: "30 / 30"
│         Horizontal Alignment: Right
│         Font Size: 22
│         Add Theme FontColor: white
│
│   ── HEALTH (bottom-left) ──────────────────────────────────
│   ├── HealthBar (ProgressBar)
│         Anchor: Bottom Left
│         Offset: (20, -70, 220, -45)
│         Max Value: 100, Value: 100
│         Show Percentage: false
│         Add StyleBoxFlat fills: green (normal), red (under_threshold via script)
│   ├── HealthLabel (Label)
│         Anchor: Bottom Left
│         Offset: (20, -44, 220, -24)
│         Text: "100 / 100"
│         Font Size: 14
│
│   ── MINIMAP (top-right) ────────────────────────────────────
│   ├── MinimapPanel (Panel)
│         Anchor: Top Right
│         Offset: (-195, 15, -15, 195)
│         Size: 180x180
│         Add Theme StyleBoxFlat: bg Color(0,0,0,0.5), border 2px white
│         Clip Contents: ON  ← important! dots outside panel hidden
│   │   ├── PlayerDot (ColorRect)
│   │         Size: 10x10, Color: cyan — positioned by code
│   │   └── EnemyDots (Node2D)
│   │         (empty container — dots added at runtime)
│
│   ── GAME OVER (hidden by default) ──────────────────────────
│   └── GameOverOverlay (Control)
│         Anchor: Full Rect
│         Visible: OFF
│       ├── PanelBackground (Panel)
│             Anchor: Full Rect
│             StyleBox: Color(0,0,0,0.75)
│       ├── GameOverLabel (Label)
│             Anchor: Center Top
│             Offset: (-200, -80, 200, -10)
│             Text: "YOU DIED"
│             Horizontal Alignment: Center
│             Font Size: 64
│             FontColor: red
│       └── RestartButton (Button)
│             Anchor: Center Top
│             Offset: (-100, 10, 100, 60)
│             Text: "Restart"
│
└── MinimapTimer (Timer)
      Wait Time: 0.15
      Autostart: ON
      One Shot: OFF
```

---

## 2. Test Arena Scene (test_arena.tscn)

```
TestArena (Node3D)   ← main scene
│
├── WorldEnvironment
│     Environment: new Environment, sky + ambient light
│
├── DirectionalLight3D
│     Rotation: (-45, 30, 0)
│
├── NavigationRegion3D
│     NavigationMesh: bake after placing floor
│     └── Level (Node3D)
│         ├── Floor (CSGBox3D or MeshInstance3D)
│         │     Size: 40x0.5x40
│         │     Material: simple grey
│         │     Physics: StaticBody3D + CollisionShape3D
│         │     Navigation Layers: Layer 1 ✓
│         ├── Wall_N / Wall_S / Wall_E / Wall_W  (StaticBody3D boxes)
│         │     Size: 40x3x0.5 each, framing the arena
│         │     Navigation Layer: Layer 1 ✓
│         └── [optional] Crates (StaticBody3D boxes for cover)
│
├── Player (instance res://player/player.tscn)
│     Position: (0, 0.9, 0)
│     Layer: 2
│     Mask: 1 (world) | 3 (enemy) | 4 (interactable)
│
├── Enemy_01 (instance res://enemy/enemy_base.tscn)
│     Position: (8, 0.9, 8)
│     Layer: 3
│     Mask: 1 | 2
│
├── Enemy_02 (instance res://enemy/enemy_base.tscn)
│     Position: (-8, 0.9, 12)
│
├── Enemy_03 (instance res://enemy/enemy_base.tscn)
│     Position: (12, 0.9, -6)
│
└── HUD (instance res://hud/hud.tscn)
      (CanvasLayer — independent of 3D scene)
```

### After placing nodes:
1. Select NavigationRegion3D → NavigationMesh → Bake NavigationMesh
2. Verify green nav mesh covers the floor area
3. Set Player group: In Player node → Groups → Add "player"
4. Each Enemy auto-adds to "enemies" group in enemy.gd _ready()
5. Project Settings → Autoload: noise_bus.gd as "NoiseBus"

---

## 3. Input Map (Project Settings → Input Map)

Add these actions if not already present:

| Action         | Key/Button           |
|----------------|----------------------|
| move_forward   | W                    |
| move_back      | S                    |
| move_left      | A                    |
| move_right     | D                    |
| jump           | Space                |
| sprint         | Left Shift           |
| crouch         | Left Ctrl            |
| lean_left      | Q                    |
| lean_right     | E                    |
| ads            | Mouse Button Right   |
| fire           | Mouse Button Left    |
| reload         | R                    |
| interact       | F                    |
| weapon_next    | Mouse Wheel Up       |
| weapon_prev    | Mouse Wheel Down     |
| throw          | G                    |

---

## 4. Physics Layers Setup

Project Settings → Layer Names → 3D Physics:
  Layer 1: World
  Layer 2: Player
  Layer 3: Enemy
  Layer 4: Interactable
  Layer 5: Projectile

---

## E) TEST CHECKLIST (2 Minuten)

### Bewegung & Input
- [ ] WASD bewegt Player (CoD-feeling: snappy start/stop)
- [ ] Shift = Sprint (schneller, kein ADS)
- [ ] Ctrl = Crouch toggle (Capsule kleiner, Kamera tiefer)
- [ ] Q/E = Lean (Kamera rollt, kein Wand-Clipping)
- [ ] RMB = ADS (FOV enger, langsamere Sens)
- [ ] Space = Jump, fällt schnell

### Waffe & Combat
- [ ] LMB = Feuert (Hitscan, Recoil sichtbar)
- [ ] R = Reload (Ammo HUD springt auf Magazine)
- [ ] HUD Ammo zählt korrekt runter (event-driven, kein lag)
- [ ] Schuss trifft Enemy → Enemy nimmt Schaden

### Enemy
- [ ] Enemy steht still → Idle
- [ ] Schuss abfeuern → Enemy hört es → Investigate
- [ ] Enemy sieht Player → Chase
- [ ] Enemy greift Player an (Melee, HP sinkt)
- [ ] Enemy auf 0HP → is_dead=true → fällt leicht, verschwindet nach delay
- [ ] Toter Enemy verschwindet von Minimap (remove_from_group)

### HUD
- [ ] Health Bar zeigt korrekte HP
- [ ] Schaden → Health Bar fällt, wird rot unter 30%
- [ ] Ammo Label zeigt "current / max"
- [ ] Minimap zeigt rote Enemy-Dots (bewegen sich bei Chase)
- [ ] Enemy-Dot verschwindet wenn Enemy stirbt

### Player Death
- [ ] Player HP auf 0 → Kamera kippt
- [ ] Keine Eingaben mehr möglich (is_dead guard)
- [ ] Maus wird sichtbar
- [ ] Nach 1.2s: "YOU DIED" Overlay erscheint
- [ ] "Restart" Button → Scene neu geladen, alles reset
