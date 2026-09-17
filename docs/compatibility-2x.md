# Compatibility checklist for game 2.x

This mod was last worked on in August 2022, against game patch 1.6 and Cyber
Engine Tweaks ~1.19. The game is now at 2.31 and CET at 1.37.x. Patch 2.0
rewrote combat, health, perks and enemy scaling, so several of the hooks in
`init.lua` are landing on APIs that have since moved.

None of the below has been verified in game. Each item is a thing to check with
the CET console open, not a known break.

## How to work through this

1. Launch with only Cyber Engine Tweaks, CP Styling and this mod installed.
2. Open the CET overlay and watch the console for Lua errors on load.
3. Take each hook in turn; add a `print()` inside it to confirm it fires at all
   before worrying about whether the value is right.

Tick items off in this file as you confirm them.

## Hooks to verify

### `PlayerPuppet::OnCombatStateChanged` (`init.lua`)

- [ ] Does the observer still fire?
- [ ] Are the state values still `1` for entering combat and `2` for leaving?
      The code compares raw integers. `gamedataNPCHighLevelState` and the
      combat state enums were touched in 2.0. If these shifted, the meter
      either never starts or never ends.
- [ ] Entering combat fires `start()` unconditionally, so re-entry mid-fight
      replays the intro warning. Worth confirming how often 2.x toggles this.

### `PlayerPuppet::OnHit` (`init.lua`)

This is the hook the whole mod turns on, and the most likely casualty.

- [ ] Does it fire for hits on NPCs, not just on the player? The mod relies on
      CET resolving `PlayerPuppet.OnHit` to the inherited `ScriptedPuppet::OnHit`,
      so that `self` can be an NPC. If CET's method resolution changed, the
      `elseif` branch never runs and style can only ever go down.
- [ ] `event.attackData:GetInstigator()` — still present, still returns the
      player object for player attacks?
- [ ] `gamedataAttackType.Effect` — does this enum member still exist? A
      missing member evaluates to `nil` and the guard silently stops filtering.
- [ ] `self:IsBoss()` — 2.0 replaced the old boss/elite tiering. Check this
      still returns true for anything.
- [ ] `self:IsIncapacitated()` — gates the execution bonus. Verify against a
      downed but not dead enemy.
- [ ] `self:IsCrowd()` / `self:IsVendor()` — used to punish hitting civilians.
- [ ] `self:IsHostile()` — used for the surprise bonus.

### `PlayerPuppet::OnHealthUpdateEvent` (`init.lua`)

- [ ] **Most likely to be wrong.** The guard is `event.healthDifference <= 1`,
      meant to ignore passive regen. Post-2.0 health is expressed as a
      percentage of max rather than a flat pool, so a meaningful heal may now
      be a small number and get filtered out — or regen ticks may exceed 1 and
      get punished. Print `healthDifference` during a fight before trusting it.
- [ ] `entEntity.GetEntityID(self).hash` comparison against the player — still
      the right way to identify the player in 2.x?

### `PlayerPuppet::OnDeath` (`init.lua`)

- [ ] Fires on player death, and the meter resets.

### CET kit (`cet-kit/GameUI.lua`)

Upstream declares `framework = '1.29.0'` while CET is at 1.37.x, and the file
has not changed materially since December 2023. It is not guaranteed current.

- [ ] Meter hides in menus, inventory, map and during loading.
- [ ] Meter hides in scanner mode.
- [ ] **Fast travel.** The previously vendored copy carried three local
      workarounds on the `FastTravelSystem` observers that upstream does not
      have. Those are now gone. If fast travel throws in the CET console, that
      guard was load-bearing and the fix belongs upstream, not in `cet-kit/`.

## Tuning, once it runs

Balance values in `init.lua` were set against 1.6 combat pacing, which was far
slower than 2.0's. Expect to revisit at least:

- `basePercentageIncrease` / `basePercentageDecrease`
- `baseTickReduction` and the rank-scaled drain in `baseTickReduction()`
- `styleExecutionFactor`, given how much 2.0 changed finishers

## Known gaps, unrelated to 2.x

- `repetitionModifier` is initialised to `1` and never updated. The
  "TODO Add modifier logic" in `init.lua` is the anti-spam mechanic that was
  never built, so repeatedly using one attack is not penalised.
