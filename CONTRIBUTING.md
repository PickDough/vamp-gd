# Contributing

This project is written in Redot 26.3 GDScript. The rules below keep the code base consistent; they follow the
[official GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and [static typing guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html),
with project decisions where those leave room. How the code is organized (folders, scene flow, wiring, data and
combat) is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Naming

| Kind | Style | Example |
| --- | --- | --- |
| Files, folders | snake_case, matching the class name | `enemy_spawner.gd` |
| Classes, structs, traits | PascalCase | `class_name EnemySpawner`, `struct_name PlayerIntent`, `trait_name Damageable` |
| Nodes in scenes | PascalCase | `NavigationAgent3D`, `Cooldown` |
| Functions, variables, parameters | snake_case | `func pick_spawn_point()`, `var spawn_carry` |
| Private functions and member variables | `_` + snake_case | `func _cast()`, `var _hit_bodies` |
| Constants | CONSTANT_CASE | `const MIN_SPAWN_DISTANCE := 10.0` |
| Enums | PascalCase, singular; members CONSTANT_CASE | `enum SkillModifier { DAMAGE, SPEED }` |
| Type aliases (constants holding a type) | PascalCase | `const SkillModifier := SkillModifiers.SkillModifier` |
| Signals | snake_case, past tense | `signal died`, `signal bake_finished` |
| Signal handlers | `_on_<node>_<signal>`, or `_on_<signal>` for the node's own signals | `_on_cooldown_timeout()` |
| Booleans | `is_`, `has_`, `can_` prefix | `is_close_to_floor` |

- A member is private unless other scripts or scenes use it. Exported variables are public.
- Use full words. No abbreviations or single letters (`spd`, `l`) except loop indices.
- If a name would shadow a member, choose a more specific name rather than a shorter one.

## File layout

Declare things in this order, public before private within each group:

1. `@tool`, `@icon`
2. `class_name` / `struct_name` / `trait_name`
3. `extends`, then `uses`
4. `##` doc comment
5. signals
6. enums
7. constants
8. static variables
9. `@export` variables
10. public variables
11. private variables
12. `@onready` variables
13. `_static_init()`, then public static functions (private static functions go with the private methods)
14. engine callbacks: `_init()`, `_enter_tree()`, `_ready()`, `_process()`, `_physics_process()`, then the rest
15. public methods
16. private methods
17. inner classes

```gdscript
class_name Enemy
extends CharacterBody3D
uses Damageable

## Walks toward the player along the navigation mesh.

const PATH_REFRESH_INTERVAL := 0.3

@export var speed: float = 2.0

var _time_since_path_refresh: float = 0.0

@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_refresh_path()


func _physics_process(delta: float) -> void:
	...


func _refresh_path() -> void:
	...
```

## Types

- Type every declaration, parameter and return value.
- Use `:=` when the type is visible on the same line; otherwise write the type.

  ```gdscript
  var timer := Timer.new()
  var distance: float = global_position.distance_to(target.global_position)
  ```

- Type collections: `Array[Enemy]`, `Dictionary[SkillModifier, float]`. Type `for` variables when they aren't
  inferred: `for enemy: Enemy in enemies:`.
- Use `T?` only where `null` is a real state (an optional result, something not spawned yet), and check for `null`
  before use. Everything else is non-nullable.
- `as` returns `null` when the cast fails. Use it only where `null` is acceptable; otherwise check with `is` first.
- Prefer typed helpers: `absf`, `minf`, `clampf`, `lerpf`, `roundi`.

### Structs, traits and classes

- **struct**: plain data with no behaviour, copied by value (`PlayerIntent`).
- **trait**: shared behaviour with a contract that unrelated classes adopt with `uses` (`Damageable`). Traits can
  hold state, `@onready` references and default implementations, and receive engine callbacks such as `_ready`. A
  callback the adopting class defines replaces the trait's one, so keep each callback in one of the two.
- **class**: nodes and resources.

## Formatting

- Tabs for indentation, LF line endings, UTF-8, one newline at the end of the file.
- Lines at most 120 characters. Wrap inside parentheses; continuation lines get two extra indents (one for
  arrays, dictionaries and enums).
- Two blank lines between functions; one blank line inside a function to separate steps.
- Trailing comma on the last item of multiline arrays, dictionaries, enums and argument lists.
- `and`, `or`, `not`, never `&&`, `||`, `!`.
- Double quotes, unless single quotes avoid escaping.
- Write numbers in full: `0.6`, `13.0`, `1_000_000`.
- One statement per line; the ternary `a if condition else b` is the only exception.
- Run the formatter on save and don't hand-format against it.

## Scenes and nodes

- Reference a script's own child nodes with a typed `@onready` variable:

  ```gdscript
  @onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
  @onready var _animation_player: AnimationPlayer = %AnimationPlayer
  ```

  Use `%UniqueName` for nodes that may move in the scene tree. Use `TreeQuery` only for dynamic lookups, such as
  searching spawned nodes by type.
- Call down, signal up: a parent calls methods on its children; a child emits signals for its parent. Reaching up
  with `get_parent()` or `../` paths is allowed, for example for a component node that works on its owner
  (`OnHitEffect`).
- Connect a node's signals in one place, either in the scene or in `_ready()`, not both.
- Load scenes with `load()` where you instantiate them; don't `preload()` them into constants. Scene preloads
  create load cycles that leave exported properties unset (see ARCHITECTURE.md).
- No magic numbers: give values a named constant, or an `@export` when designers should tune them.

## Autoloads

- Autoloads hold services shared across scenes (random numbers, settings, saves), not the state of a single scene.
- If an autoload does hold scene state, the node that owns it sets it and clears it:

  ```gdscript
  func _enter_tree() -> void:
  	AutoloadGame.player = self


  func _exit_tree() -> void:
  	if AutoloadGame.player == self:
  		AutoloadGame.player = null
  ```

- Use an autoload by its global name (`AutoloadGame.rng`); don't copy it into a member variable.

## Comments

- Every script except specs has a doc comment: a `##` block right after the header (`class_name`, `struct_name`,
  `extends`, `uses`) stating what the script is for. Mention workarounds and engine quirks there.
- The doc comment is the only comment allowed.
- Nothing else gets a comment: not functions, variables, constants or lines. Say it through names instead: a
  well-named function, variable or constant replaces the comment that would explain it.
- `#region`/`#endregion` and `# lint-ignore: rule` directives are not comments and are allowed.

## Hygiene

- No `print` debugging in committed code. Use `push_warning()` / `push_error()` for real problems and DeDraw for
  visual debugging.
- No commented-out code; version control remembers it.
- No `self.` unless it disambiguates.
- A function body has at most 16 lines, not counting blank lines. Return early from guard clauses instead of
  nesting. Specs are exempt: each one is a single long scenario on purpose.
- Split a long function by naming its steps (`_read_intent()`, `_next_velocity()`), but don't let a script turn
  into a pile of small functions. Logic that is self-contained or reusable gets its own script or node:
  `NavPoints` and `SyncedNavigationRegion` for navigation, `TargetDetector` for skill targeting,
  `SkillStats.roll_hit()` for hit rolls. Prefer a node from the scene (a `Timer`, a `RayCast3D`) over code that
  rebuilds it.
- More than four or five parameters usually means the function is doing too much; consider a struct.

## Tests

Specs live in `spec/` and use [gspec](https://github.com/NgocHai220998/gspec). They are end-to-end: each one
drives real scenes through a single scenario (see `spec/support/scene_spec.gd`).

Run them from the CLI:

```bash
/Applications/Redot_mono.app/Contents/MacOS/Redot --headless --path . res://addons/gspec/runner.tscn
```

or open `res://addons/gspec/runner.tscn` and press Run Current Scene (F6), or use the VS Code Test Explorer
(`tools/vscode-gspec`). The editor's GSpec panel can't run scene specs, because game scripts don't run inside the
editor.

## Linting

`tools/lint/lint.py` checks the rules in this document. It runs in two passes:

- **engine**: Redot compiles every script with the project's GDScript warnings raised to errors (untyped
  declarations, unsafe access and casts, unused or shadowed names, …). The project itself keeps them as warnings,
  so the editor shows them and the game still runs.
- **style**: naming, file names, declaration order, two blank lines between functions, line length, function
  length, comments and doc comments, boolean operators, number format, quotes, and hygiene (`print`, `self.`, node
  references outside `@onready`, public members, including `@onready` ones, that nothing else uses).

```bash
python3 tools/lint/lint.py
```

Pass file paths to report only those files, or `--no-engine` to skip the slower engine pass. Findings print as
`path:line:column: rule: message`. Silence a single line with a trailing `# lint-ignore: rule`.

In VS Code, run the **lint GDScript** task; findings show in the Problems panel.

A pre-commit hook lints the staged `.gd` files and blocks the commit on findings. Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

## Neovim

`.lazy.lua` in the project root sets Neovim up for this project only. It's for LazyVim (lazy.nvim loads a
project's `.lazy.lua` automatically). It adds:

- the Godot editor colorscheme ([bentok/godot.nvim](https://github.com/bentok/godot.nvim), pinned to a commit)
- the GDScript language server and the Redot debug adapter, both served by the Redot editor
- tree-sitter highlighting for `.gd`, `.tscn`/`.tres` and `.gdshader`
- `lint.py`'s style rules as diagnostics on save
- GDQuest's [GDScript formatter](https://github.com/GDQuest/GDScript-formatter) through conform.nvim, the same
  binary and defaults the VS Code/Cursor `godot-format` extension uses (format on save, or `<leader>cf`). It skips
  files with Redot-only syntax (`struct_name`, `trait_name`, `uses`, `T?`), which its parser can't read
- a `server.pipe` in the project root that Redot uses to open files in the running Neovim

To use it:

1. Open the project in Redot. It serves the language server (port 6005) and the debug adapter (port 6006).
2. Start Neovim in the project root. The first start installs the theme, nvim-dap and the tree-sitter parsers.
3. In Redot, set Editor Settings > Text Editor > External: **Use External Editor** on, **Exec Path** to your `nvim`,
   and **Exec Flags** to:

   ```
   --server {project}/server.pipe --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line}+1,{col})<CR>"
   ```

   Also turn on Editor Settings > Network > Language Server > **Use Thread**.

Debug with `<leader>dc` (start/continue), `<leader>db` (breakpoint), `<leader>di`/`do`/`dO` (step into/over/out),
`<leader>dr` (REPL) and `<leader>dt` (stop); the "Launch main scene" configuration runs the game from Redot.
`.lazy.lua` adds nvim-dap directly instead of importing LazyVim's `dap.core` extra, because lazy.nvim loads
`.lazy.lua` after your own plugins and LazyVim requires extras to come before them. For the full debugger UI,
enable `dap.core` in `:LazyExtras`. The GDScript tree-sitter grammar predates Redot's `struct_name`,
`trait_name`, `uses` and `T?`, so those lines may highlight imperfectly; the language server understands them.
