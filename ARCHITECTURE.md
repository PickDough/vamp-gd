# Architecture

How the game is organized and how its parts talk to each other. Code style lives in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Layers

```
main.tscn   root: switches between menu, run and game over
ui/         screens/, hud/            talks to run through signals only
run/        run.tscn                  one play session; builds and wires everything below
world/      map/, spawning/           may use core, data, actors
actors/     player/, enemies/         may use core, data
skills/     slice/, …                 may use core, data
data/       Resource classes + .tres  may use core
core/       autoloads, shared structs and traits, utilities
```

- Dependencies point down only. A layer never references a layer above it, by type, path or `load()`.
  `actors/` and `skills/` don't know about each other's internals; they meet through `core/` traits and structs.
- Group by feature, not by file type: a feature folder keeps its scene, script, resources and assets together
  (`skills/slice/slice_skill.tscn`, `slice_skill.gd`, `slice_stats.tres`).
- A folder's public surface is its scenes and `class_name` scripts. Anything other features shouldn't touch is
  private (`_` prefix) or lives in a subfolder only that feature uses.

## Scene flow

`Main` owns the current screen and is the only code that changes it. Screens ask for a change by emitting a signal:

```
MainMenu.play_pressed(letter) → Main starts a Run for that letter
```

A game-over screen will follow the same pattern (`Run.finished` → `Main` shows it).

No screen frees itself or changes the scene tree root.

## Run: the composition root

`Run` is the one place that knows how the pieces of a play session fit together.

- **Builds** the map for the chosen letter, and spawns the player once the map reports it is ready.
- **Wires** dependencies by handing them down: `spawner.setup(player, map.navigation_region)`. Spawned enemies get
  their target from the spawner. Nothing looks dependencies up through globals or `get_parent()`.
- **Owns run state** once it exists (elapsed time, XP, gold, level), exposed as signals for the HUD.
- **Relays** cross-feature events once there are any: it listens to its children (an enemy died, a pickup was
  collected) and updates state or calls down into other children.

Lower layers stay unaware of `Run`: they expose methods, exports and signals, and `Run` connects them.

Scenes are loaded with `load()` where they're instantiated, never `preload()`ed into constants. Preloading a scene
inside a script that other scripts depend on creates load cycles, and a scene built mid-cycle silently loses its
exported property values.

## Communication

- **Call down, signal up.** A node calls methods on nodes it owns and emits signals for whoever owns it.
- **Siblings never talk directly**; their common owner (often `Run`) connects them.
- **Dependencies come in through `setup(...)` or `@export`**, set by the owner before or right after `add_child`.
  Use `setup` for things that only exist at runtime (the player); use `@export` for things wired in the scene.
- **Autoloads are services**: random numbers (`AutoloadGame.rng`), settings, saves, audio. They never hold
  references to scene nodes, so nothing can read a freed player through them.

## Data, values and behaviour

| Use | For | Example |
| --- | --- | --- |
| `Resource` class + `.tres` | designer-tuned data, edited in the inspector | `SkillStats`, `SpawnScenario` |
| `struct` | values passed around at runtime, copied on assignment | `HitInfo`, `PlayerIntent` |
| `trait` | a capability other code checks with `is` | `Damageable`, `Targetable` |
| component node | behaviour that needs a lifecycle, signals or inspector settings | `Health` |
| `@export` on the scene | a value only one scene variant tunes | `Enemy.speed` in `enemy_a.tscn` |
| `class` | everything else: actors, skills, the map | `Enemy`, `SliceSkill` |

- Stats are typed `Resource` fields, not dictionaries. A misspelled stat is a parse error, and every stat has a
  visible default in the inspector.
- When player attributes start modifying skills, combine them with the skill's `SkillStats` in one function per
  skill, not scattered through the code.
- Stats live in their own `.tres` next to the feature (`skills/slice/slice_stats.tres`). A node that changes its
  resource at runtime duplicates it in `_ready`, so instances don't share one copy.
- Traits stay thin. Redot doesn't call engine callbacks such as `_ready` on traits, so anything with a lifecycle
  becomes a component node.

## Combat

```
SliceAction ──HitInfo──▶ Damageable.take_hit(hit) ──▶ Health.apply(hit)
                                                        ├─ damaged(hit)
                                                        └─ died(hit) ──▶ owner: drop XP, play effect, queue_free()
```

- An attack builds a `HitInfo` struct (amount, is_critical) and calls `take_hit` on anything `Damageable`.
  `take_hit` is abstract in the trait, so a class that `uses Damageable` without implementing it doesn't load.
- The target's `Health` component applies it and emits `damaged` and `died`. It never frees its owner.
- The owner decides what death means (`Enemy` emits `died` and frees itself); `Run` will hear about it through that
  signal once there is XP to award.
- **Physics layers decide what can touch what.** Name them in Project Settings → Layer Names → 3D Physics, and set
  layers and masks in scenes instead of filtering by type in code:

  | Layer | Name | Detected by |
  | --- | --- | --- |
  | 1 | world | everything that moves |
  | 2 | player | enemies, pickups |
  | 3 | enemies | player attacks, skill detectors |
  | 4 | player_attacks | — (they detect enemies) |
  | 5 | pickups | — (the player detects them) |

## Skills

- A skill is a node on the player. It owns its cooldown and targeting, and spawns short-lived action scenes
  (`SliceSkill` → `SliceAction`).
- A skill's stats come from its `SkillStats` resource.
- Action scenes get everything they need from the skill at spawn time (stats, target, timing) and never look back
  up to the skill or the player.
- A shared `Skill` base class comes when a second skill exists and the common part is clear, not before.

## Current layout

| Path | Contents |
| --- | --- |
| `main.tscn`, `main.gd` | `Main`: the main scene; switches between the menu and runs |
| `run/` | `Run`: composition root of a play session |
| `ui/screens/main_menu/`, `ui/theme.tres` | title screen and shared theme |
| `world/map/` | `Map`: letter mesh, collision, navigation; emits `ready_for_player` |
| `world/spawning/` | `EnemySpawner`, `SpawnScenario`; `setup(player, navigation_region)` |
| `world/activities/` | `Pickup`, `Shrine` stubs |
| `actors/player/` | `PlayerBody`, `PlayerIntent` |
| `actors/enemies/` | `Enemy`, `enemy_a.tscn` (with a `Health` node) |
| `skills/shared/` | `TargetDetector`: nearest damageable bodies in range |
| `skills/slice/` | `SliceSkill`, `SliceAction`, their scenes and stats |
| `data/` | `SkillStats`, `PlayerAttributes`, `words/` |
| `core/` | `AutoloadGame` (services), `TreeQuery`, `Damageable`, `Health`, `HitInfo` |
| `core/navigation/` | `NavPoints` (spawn spots), `SyncedNavigationRegion` (runtime rebake) |
| `spec/` | end-to-end specs; `spec/support/` holds `SceneSpec` and the VS Code runner |
| `tools/` | `lint/` (the GDScript linter), `vscode-gspec/` (the VS Code test explorer extension) |
