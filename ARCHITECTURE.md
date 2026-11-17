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

```
Run.finished → Main shows the main menu again (a game-over screen will take its place)
```

No screen frees itself or changes the scene tree root.

## Run: the composition root

`Run` is the one place that knows how the pieces of a play session fit together.

- **Builds** the map for the chosen letter, and spawns the player once the map reports it is ready.
- **Wires** dependencies by handing them down: `spawner.setup(player, map.navigation_region)` and
  `player.setup(spawner.hive)`. The spawner hands the hive its target; the player hands the hive, as a
  `TargetFinder`, to its skills. Nothing looks dependencies up through globals.
- **Owns run state** (`Score`: elapsed time so far; XP, gold and level later), exposed as signals for the HUD.
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
| `trait` | a capability other code checks with `is` | `Damageable`, `TargetFinder` |
| `RefCounted` class | logic or state with no node lifecycle, composed into a node | `BodyPhysics`, `EnemyState`, `SpatialGrid` |
| component node | behaviour that needs a lifecycle, signals or inspector settings | `Health` |
| `@export` on the scene | a value only one scene variant tunes | `Enemy.speed` in `enemy_a.tscn` |
| `class` | everything else: actors, skills, the map | `Enemy`, `SliceSkill` |

- Stats are typed `Resource` fields, not dictionaries. A misspelled stat is a parse error, and every stat has a
  visible default in the inspector.
- When player attributes start modifying skills, combine them with the skill's `SkillStats` in one function per
  skill, not scattered through the code.
- Stats live in their own `.tres` next to the feature (`skills/slice/slice_stats.tres`). A node that changes its
  resource at runtime duplicates it in `_ready`, so instances don't share one copy.
- Traits can hold state, `@onready` references and default method bodies, and Redot calls their engine callbacks
  (`_ready`, `_process`, …). A callback the adopting class defines replaces the trait's one, so keep each callback
  in either the trait or the class, not both.

## Combat

```
SliceAction ──HitInfo──▶ Damageable.take_hit(hit) ──▶ Health.apply(hit)
                                                        ├─ damaged(hit)
                                                        └─ died(hit) ──▶ owner: drop XP, play effect, queue_free()
```

- An attack builds a `HitInfo` struct (amount, is_critical) and calls `take_hit` on anything `Damageable`.
  By default `Damageable.take_hit` applies the hit to the adopter's `Health` child; an adopter can override it.
- The target's `Health` component applies it and emits `damaged` and `died`. It never frees its owner.
- The owner decides what death means (`Enemy` emits `died` and frees itself); `Run` will hear about it through that
  signal once there is XP to award.
- Enemies hurt the player by contact: each physics frame `PlayerBody` asks its `TargetFinder` for the nearest enemy
  within `contact_range` and takes a hit worth the current minute of the run, read from the `Score` that `Run`
  owns and hands to the player (`player.setup(hive, score)`). A hit starts the player's
  `InvulnerabilityTimer` (the player blinks and ignores hits until it stops).
- `OnHitEffect` (`actors/shared/on_hit_effect.gd`) is the shared reaction to damage for anything that uses the
  `HitReactive` trait: it knocks its owner along the hit through `apply_impulse` and flashes it through
  `show_tint`. Enemies and the player both carry one, tuned per scene. Death stays with the owner (`Enemy` leaves a
  `DeathBody` ragdoll). When its `Health` runs out the player stops and emits `died`; `Run` emits `finished`.
- **Physics layers decide what can touch what.** Name them in Project Settings → Layer Names → 3D Physics, and set
  layers and masks in scenes instead of filtering by type in code:

  | Layer | Name | Detected by |
  | --- | --- | --- |
  | 1 | world | everything that moves |
  | 2 | player | enemies, pickups |
  | 3 | enemies | unused: enemies have no body, see Enemies below |
  | 4 | player_attacks | unused: attacks query the hive, not physics |
  | 5 | pickups | — (the player detects them) |

## Enemies

- Enemies are not physics bodies and have no model nodes. An `Enemy` is a bare `Node3D` (`Health`, `OnHitEffect`)
  that the `Hive` moves and draws. Each enemy scene names a `model_scene`, its `model_transform` and a
  `walk_animation`; the hive bakes that animation once into a `VertexAnimation` (vertex positions per frame in a
  texture) and draws every enemy sharing it as one instance of a `CrowdRenderer` MultiMesh, whose shader plays
  the baked frames. A skinned model with a Skeleton3D and AnimationPlayer per enemy cost more than the whole AI
  step; `DeathBody` still instantiates the real model for the ragdoll. Each enemy gets a pastel `body_color`
  from its scene's `colors` when it registers; the crowd shader draws it matte with a dark outline pass, and hit
  flashes (`Enemy.tint`) fade it to white.
  The hive keeps two parallel arrays indexed by slot: the `Enemy` nodes and their `EnemyState` (plain data with no
  node reference; the enemy's settings are copied in when it registers). An enemy knows its slot, so its impulses
  go straight to its state, and it unregisters itself in `_exit_tree`.
- Crowds stay cheap through staggering: separation is recomputed every other tick, far enemies refresh their
  paths less often, and enemies beyond 100m run a full step only every other tick and coast in between (see
  `EnemyState`).
- With enough enemies the step is split into buckets that run on `WorkerThreadPool` threads. Only the main thread
  may touch nodes, `move_and_slide` or the physics server, so a step reads the navigation server (thread-safe) and
  the `SpatialGrid`, writes only its own `EnemyState`, and the hive then moves the nodes on the main thread. The
  nav mesh is the floor: enemies walk along paths from `NavigationServer3D.map_get_path` and snap to
  `map_get_closest_point_to_segment` along a short vertical probe.
- Enemies don't block the player or each other physically. Separation between them is computed from the grid.
- Attacks find enemies through the `TargetFinder` trait (`find_nearest`, `find_in_box`), which the hive adopts on
  top of the same grid. `Run` hands it to the player, which hands it to its skills; skills never reference
  `actors/`.
- Anything that changes hive state (`register`, impulses, queries) runs on the main thread, outside the step.
- `tools/bench/enemy_bench.tscn` measures a run under a crowd of N enemies; see its doc comment.

## Skills

- A skill is a node on the player. It owns its cooldown and targeting, and spawns short-lived action scenes
  (`SliceSkill` → `SliceAction`).
- A skill's stats come from its `SkillStats` resource.
- Action scenes get everything they need from the skill at spawn time (stats, target, timing) and never look back
  up to the skill or the player.
- A shared `Skill` base class comes when a second skill exists and the common part is clear, not before.

## Current layout

Each feature folder keeps its scene and main script at the top and splits the rest into subfolders by concern.

| Path | Contents |
| --- | --- |
| `main.tscn`, `main.gd` | `Main`: the main scene; switches between the menu and runs |
| `run/` | `Run`: composition root of a play session |
| `ui/screens/main_menu/`, `ui/theme.tres` | title screen and shared theme |
| `world/map/` | `Map`: letter mesh, collision, navigation; emits `ready_for_player` |
| `world/map/floor/` | `checker.gdshader` and `checker_floor.tres`: the checkered letter |
| `world/map/void/` | `fog_sea.gdshader` (fog layers under the map), `FloatingToys` + `toy.gdshader` (shapes in the void) |
| `world/spawning/` | `EnemySpawner`, `SpawnScenario`; `setup(player, navigation_region)` |
| `actors/player/` | `PlayerBody` (with `Health`, `InvulnerabilityTimer` and its `Skills`), `PlayerIntent` |
| `actors/player/materials/` | the player's toon materials (`body`, `head`, `limbs`, `hands`) and their shared light-blue `outline` pass |
| `actors/enemies/` | `Enemy`, `EnemyModel`, `enemy_a.tscn` |
| `actors/enemies/hive/` | `Hive`, `EnemyState`, `StepContext`: the threaded crowd simulation |
| `actors/enemies/crowd/` | `CrowdRenderer`, `VertexAnimation` (+ `.gdshaderinc`), `crowd.gdshader`, `crowd_outline.gdshader`: drawing the crowd |
| `actors/enemies/death/` | `DeathBody` and `ragdoll_dissolve.gdshader`: ragdolls that burn away |
| `actors/shared/` | `OnHitEffect`, shared by enemies and the player |
| `skills/slice/` | `SliceSkill`, `SliceAction`, their scenes and stats |
| `data/` | `SkillStats`, `PlayerAttributes`, `words/` |
| `core/` | `AutoloadGame` (services), `TreeQuery`, `Score` |
| `core/combat/` | `Health`, `HitInfo`, `Damageable`, `HitReactive`, `TargetFinder` |
| `core/spatial/` | `SpatialGrid` |
| `core/physics/` | `BodyPhysics` (gravity and knockback, thread-safe), `Impulse` |
| `core/navigation/` | `NavPoints` (spawn spots), `SyncedNavigationRegion` (runtime rebake) |
| `assets/shaders/` | `toon.gdshader`, `toon_light.gdshaderinc`, `outline.gdshader`: the matte cartoon look the player, enemies, ragdolls and toys share |
| `spec/` | end-to-end specs; `spec/support/` holds `SceneSpec` and the VS Code runner |
| `tools/` | `lint/` (the GDScript linter), `bench/` (crowd benchmark), `vscode-gspec/` (the VS Code test explorer extension) |
