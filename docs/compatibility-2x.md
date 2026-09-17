# Compatibility checklist for game 2.x

This mod was last worked on in August 2022, against game patch 1.6 and Cyber
Engine Tweaks ~1.19. The game is now at 2.31 and CET at 1.37.x. Patch 2.0
rewrote combat, health, perks and enemy scaling, so several of the hooks in
`init.lua` are landing on APIs that have since moved.

Part of this has since been settled without the game, by reading the engine's
own reflection data. The rest needs ten minutes of play and the probe in
`tools/style-rank-probe/`.

## Where the evidence comes from, and what it is worth

[RED4ext.SDK](https://github.com/WopsS/RED4ext.SDK) generates C++ headers
directly from the game's RTTI, so it is authoritative about which types, enum
members and struct fields exist. Two caveats, and they matter:

- The checkout used here carries no game-version string. It is demonstrably
  post-2.0 (`gamedataStatType` contains `RelicPerk`, added with Phantom
  Liberty's Relic tree) but the exact patch was not pinned.
- A field existing in RTTI does **not** prove Cyber Engine Tweaks exposes it to
  Lua under that name. RTTI tells us what to reach for; only the probe tells us
  whether the reach succeeds.

So treat everything below as "worth trying", not "known working".

## Settled by reflection data

- [x] **`gamedataAttackType.Effect` still exists** (value 2). The guard in
      `OnHit` that filters out effect damage is still meaningful.
- [x] **`gamedamageAttackData` still carries `attackType` and `instigator`.**
      The two fields the scoring depends on most are intact.
- [x] **`gameHitEvent` still carries `attackData`.** The hook's core payload
      survives.

## Still needs the game

Run the probe; it prints each of these and collects the distinct values.

### `PlayerPuppet::OnHit`

- [ ] **Does it fire for hits on NPCs, not just on the player?** The mod relies
      on CET resolving `PlayerPuppet.OnHit` to the inherited
      `ScriptedPuppet::OnHit`, so that `self` can be an NPC. If the probe only
      ever reports `selfIsPlayer true`, style can only ever decrease, and the
      design needs rethinking rather than patching. **Check this first — most
      of the rest is moot if it fails.**
- [ ] `self:IsBoss()` — 2.0 replaced the old boss/elite tiering. May be gone.
- [ ] `self:IsIncapacitated()` — gates the execution bonus.
- [ ] `self:IsCrowd()` / `self:IsVendor()` — civilian punishment.
- [ ] `self:IsHostile()` — surprise bonus.

### `PlayerPuppet::OnHealthUpdateEvent`

- [ ] **Most likely to be wrong.** The guard is `event.healthDifference <= 1`,
      meant to ignore passive regen. Post-2.0 health is a percentage of max
      rather than a flat pool, so a real heal may now be a small number and get
      filtered out, or regen ticks may exceed 1 and get punished. The probe
      prints raw values; pick the threshold from those.
- [ ] `entEntity.GetEntityID(self).hash` comparison against the player.

### `PlayerPuppet::OnCombatStateChanged`

- [ ] Are the state values still `1` entering combat and `2` leaving? The code
      compares raw integers. The probe logs every transition.
- [ ] Entering combat calls `start()` unconditionally, so re-entry mid-fight
      replays the intro warning. Worth seeing how often 2.x toggles this.

### CET kit (`cet-kit/GameUI.lua`)

Upstream declares `framework = '1.29.0'` while CET is at 1.37.x, and the file
has not changed materially since December 2023.

- [ ] Meter hides in menus, inventory, map, loading and scanner.
- [ ] **Fast travel.** The previously vendored copy carried three local
      workarounds on the `FastTravelSystem` observers that upstream does not
      have. Those are now gone. If fast travel throws in the CET console, that
      guard was load-bearing and the fix belongs upstream, not in `cet-kit/`.

## What the reflection data opened up for the roadmap

This is the useful surprise: most of the To Do list maps onto fields that
already exist, rather than needing to be derived.

### Wall bounced shots — `attackData.numRicochetBounces`

`gamedamageAttackData` carries this as an `int32_t`, not a boolean. So the
bonus can scale with bounce depth instead of being a flat flag, which is much
closer to the DMC/Ultrakill feel the mod is going for.

### Rate of fire — `attackData.triggerMode`

The `-- TODO check weapon type and add rate of fire modifier` in `init.lua` has
a direct answer. `gamedataTriggerMode` is:

```
Burst = 0, Charge = 1, FullAuto = 2, Lock = 3, SemiAuto = 4, Windup = 5
```

Full-auto spraying should plainly be worth less per hit than placed semi-auto
shots. `attackData.weapon` and `attackData.weaponCharge` are there too, so
charged-shot bonuses are available.

### Headshots — `hitEvent.hitColliderTag` and `hitEvent.hitComponent`

Headshots are **not** a hit flag. Searching the whole RTTI for "headshot" turns
up only stats: `HeadshotDamageMultiplier`, `CanWeaponTriggerHeadshot`,
`HeadshotImmunity`, `HeadshotCritChance`. There is no
`hitFlag.Headshot` to test.

What `gameHitEvent` does carry is `hitColliderTag` (a `CName`) and
`hitComponent`. Identifying a headshot almost certainly means matching against
the collider tag for the head — but the *values* of those tags are not in the
reflection data, which is precisely why the probe collects the distinct set of
them. Get that set, and the feature becomes straightforward.

### Boss factor — `gamedataNPCRarity`

Rather than a binary `IsBoss()`, the game has a ladder:

```
Boss, Elite, MaxTac, Officer, Rare, Normal, Trash, Weak
```

A rarity-scaled multiplier would be both more robust than `IsBoss()` and better
design — killing Trash should not pay like killing MaxTac.

### Repetition — `gamedataHitPrereqConditionType.ConsecutiveHits`

`repetitionModifier` is initialised to `1` and never updated, so attack spam is
not penalised. The game's own hit-prerequisite system has a `ConsecutiveHits`
condition, which suggests tracking consecutive same-weapon or same-attack-type
hits is an idiom the engine already supports.

That same enum also lists `SelfHit`, `TargetIsCrowd`, `TargetKilled`,
`DismembermentTriggered`, `WoundedTriggered`, `BodyPart` and `WeaponType` —
effectively a menu of scoring hooks worth reading before designing more.

## Running the probe

1. Copy `tools/style-rank-probe/` into
   `<game>/bin/x64/plugins/cyber_engine_tweaks/mods/style-rank-probe`.
2. Bind **Style Rank probe: dump summary** under CET → Bindings.
3. Load a save and fight for a few minutes. Get headshots, body shots,
   ricochets, a full-auto weapon and a semi-auto one, and at least one civilian
   and one tough enemy.
4. Press the dump hotkey.
5. Read `probe-log.txt` next to the probe's `init.lua`, and fill in the boxes
   above.

The probe changes nothing in game and reads every value through `pcall`, so a
field the patch removed reports as an error line instead of breaking the run.

## Tuning, once it runs

Balance values in `init.lua` were set against 1.6 combat pacing, which was far
slower than 2.0's. Expect to revisit at least:

- `basePercentageIncrease` / `basePercentageDecrease`
- `baseTickReduction` and the rank-scaled drain in `baseTickReduction()`
- `styleExecutionFactor`, given how much 2.0 changed finishers
