# Cyberpunk Style Rank

DMC/Ultrakill inspired mod that adds a Style Rank system in Cyberpunk 2077

Click the thumbnail below to see the latest version of the mod in action
[![Showcase of current version](https://i.ytimg.com/vi/rsPF2f2BhGY/maxresdefault.jpg)](https://www.youtube.com/watch?v=rsPF2f2BhGY)

> **Status:** last tested against game patch 1.6. The game has since moved to
> 2.x, which rewrote combat, health and perks, and this has not been verified
> against it. See [`docs/compatibility-2x.md`](docs/compatibility-2x.md).

## Requirements

- A copy of Cyberpunk 2077
- [Cyber Engine Tweaks](https://github.com/yamashi/CyberEngineTweaks)
- [CPStyling](https://www.nexusmods.com/cyberpunk2077/mods/1718) — supplies the
  ImGui theming the meter is drawn with. Without it the mod logs a message and
  stays disabled rather than loading.

## Installation

Extract into Cyber Engine Tweaks mod folder:

```
<game folder>/bin/x64/plugins/cyber_engine_tweaks/mods
```

## Development

### Vendored dependencies

`cet-kit/` holds modules copied from
[psiberx/cp2077-cet-kit](https://github.com/psiberx/cp2077-cet-kit). They are
committed so that downloading the repo as a ZIP gives a working mod folder, but
they are not ours to edit. `deps.lock` pins the upstream commit and a SHA-256
per file, and CI fails if the two disagree.

```sh
./scripts/update-deps.sh            # install the pinned commit
./scripts/update-deps.sh --check    # verify the tree matches deps.lock
./scripts/update-deps.sh --upgrade  # move the pin to upstream HEAD
```

A weekly workflow runs `--upgrade` and opens a pull request when upstream
moves. It is not installed yet — see [`docs/ci/`](docs/ci/).

**Do not patch anything under `cet-kit/` in place.** An earlier local fix to
`GameUI.lua` sat there unreviewed for years and contained a nil dereference.
Fixes belong upstream; then re-pin.

### Linting

```sh
luacheck init.lua
shellcheck scripts/update-deps.sh
./scripts/update-deps.sh --check
```

`.luacheckrc` declares the globals Cyber Engine Tweaks injects, so anything else
undefined is flagged.

## To Do

- Hook style meter gain to different actions (e.g. headshots, wall bounced shots)
- Buffs and bonuses based on style rank + skill tree
- Implement `repetitionModifier` so repeating one attack stops paying full value
- Re-verify against game 2.x (see [`docs/compatibility-2x.md`](docs/compatibility-2x.md))
