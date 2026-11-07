# TODO

Next steps for the project, roughly in priority order. See [ARCHITECTURE.md](ARCHITECTURE.md) for where new code
goes and [CONTRIBUTING.md](CONTRIBUTING.md) for how to write it.

## 1. Ship the Redot port

- [ ] Merge `vamp-rd` into `main`
  - [ ] Open a pull request `vamp-rd` → `main` on PickDough/vamp-gd
  - [ ] Review the diff and check the specs and lint pass
  - [ ] Merge it
- [ ] Retire the C# setup
  - [ ] Switch the `vamp-gd` checkout to the merged `main`
  - [ ] Remove the `vamp-rd` worktree

## 2. Core gameplay loop

- [ ] Player health
  - [ ] Give the player a `Health` node and make `PlayerBody` use `Damageable`
  - [ ] Enemies deal contact damage to the player through `HitInfo`
  - [ ] Player death ends the run
- [ ] Game over
  - [ ] `Run` emits `finished` when the player dies
  - [ ] `Main` shows a game-over screen with retry and back to menu
- [ ] XP and levelling
  - [ ] Enemies drop XP pickups when they die (fill in `Pickup`)
  - [ ] The player collects pickups on the pickups physics layer
  - [ ] `Run` tracks XP and level and emits `xp_changed` and `level_reached`
  - [ ] Level-up choice screen that pauses the run
- [ ] Player attributes
  - [ ] Wire `PlayerAttributes` into `PlayerBody` (speed and jump modifiers)
  - [ ] Extra jumps from `extra_jumps_count`
  - [ ] Gold from enemies or pickups
- [ ] Skill upgrades
  - [ ] Combine `SkillStats` with `PlayerAttributes` in one place per skill
  - [ ] Level-up choices that change skill stats (damage, count, area, cooldown)
- [ ] More skills
  - [ ] Add a second skill
  - [ ] Extract a shared `Skill` base (cooldown, targeting) once both exist
- [ ] Shrines
  - [ ] Decide what a shrine does
  - [ ] Implement it (fill in `Shrine`)
- [ ] Words and letters
  - [ ] Decide how `words.tres` shapes a run (e.g. one map per letter of a word)
  - [ ] Move between letter maps within a run

## 3. HUD and menus

- [ ] HUD
  - [ ] Health bar
  - [ ] XP bar and level
  - [ ] Run timer
  - [ ] Bind everything to `Run` signals
- [ ] Pause menu
  - [ ] Pause and resume the run
  - [ ] Release the mouse in menus and recapture it in play (`main.gd` currently captures it for the whole game)
- [ ] Main menu
  - [ ] Choose a letter or word to play
  - [ ] Settings (volume, fullscreen)

## 4. Enemies and spawning

- [ ] Enemy variants
  - [ ] Add more enemy scenes
  - [ ] Introduce an `EnemyStats` resource once variants differ in more than speed
- [ ] Enemy movement
  - [ ] Turn on NavigationAgent avoidance so chasing enemies don't stack into one blob
  - [ ] Turn off `debug_enabled` on the NavigationAgent in `enemy_a.tscn` (the red path lines)
- [ ] Spawning
  - [ ] Tune a spawn-scenario timeline for a full run
  - [ ] Add scenarios that introduce new enemy variants over time
