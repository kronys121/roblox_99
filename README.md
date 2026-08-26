# 99 Nights in the Forest

A from-scratch Roblox survival game: gather resources, craft tools and
buildings, and survive as many of the 99 nights as you can while forest
creatures hunt you after dark.

## Project layout

This is a [Rojo](https://rojo.space/) project. All game logic is plain
Luau source under `src/`; the map itself is generated procedurally at
server start (see `WorldGenerator.lua`), so there are no binary asset
files to manage.

```
default.project.json          Rojo project definition (also declares the
                               RemoteEvents/RemoteFunctions used for
                               client-server communication)
src/ReplicatedStorage/
  GameConfig.lua               Shared balance constants: hunger/stamina
                                rates, recipes, enemy stats, map size
  Configs/DayNightConfig.lua   Day/night pacing + Lighting presets
                                (the authoritative source for time-of-day)
src/ServerScriptService/
  Main.server.lua               Boot script, wires every system together
  WorldGenerator.lua            Builds ground, spawn, and resource nodes
  DayNightCycle.lua             Base framework: advances Lighting, tracks
                                the current night, fires NightStarted/
                                DayStarted for every other system to hook
  WorldStateStore.lua           DataStore persistence for the run's
                                current night (survives server restarts)
  PlayerDataManager.lua         Per-player DataStore persistence + leaderstats
  SurvivalStats.lua              Hunger/stamina simulation
  ResourceNodes.lua              Gathering (trees/rocks/bushes)
  CraftingSystem.lua             Recipe validation, tool/buildable granting
  BuildingSystem.lua             Server-authoritative placement
  EnemySpawner.lua                Night-time creature spawning + AI
src/StarterPlayer/StarterPlayerScripts/
  Main.client.lua                 Client bootstrap, sprint input
  HUDController.lua               Builds the whole HUD in code
  CraftingController.lua          Crafting menu (press C)
  BuildingController.lua          Placement/ghost preview (press B, Tab)
```

> **Status**: this is being rebuilt incrementally into a co-op (1-8
> player) survival-horror game per an expanded design (PathfindingService
> enemy AI with escalating difficulty and boss nights, grid-based base
> building with structure HP, hunger/thirst/health, a shared base
> stockpile, meta-progression, leaderboards, Game Passes). The day/night
> cycle above (`DayNightCycle.lua` + `DayNightConfig.lua` +
> `WorldStateStore.lua`) is the first piece: the persisted night counter
> and the `NightStarted`/`DayStarted` events every later system attaches
> to. Everything else in the tree above is the previous, simpler
> iteration and will be reworked to match as each system is built.

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (CLI + the Roblox Studio plugin).
2. From the repo root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play**. The world, HUD, and every system build themselves on
   start — no manual setup needed.

Alternatively, build a standalone place file without Studio open:
```
rojo build -o "99NightsInTheForest.rbxlx"
```

## Gameplay

- **Gather**: walk up to a tree/rock/bush and use the ProximityPrompt to
  collect Wood, Stone, or Berries. Equip an Axe/Pickaxe (once crafted) to
  gather faster.
- **Survive**: Hunger drains constantly; eat Berries (the "Eat Berries"
  button) before it hits zero, or you'll start taking damage. Sprint with
  Left Shift, which drains Stamina.
- **Craft**: press `C` to open the crafting menu (Axe, Pickaxe, Campfire,
  Wood Wall).
- **Build**: press `B` to enter placement mode for a crafted buildable,
  `Tab` to cycle between buildables you own, left-click to place.
- **Survive the night**: forest creatures spawn at dusk and hunt nearby
  players; they despawn at dawn. Your best night reached is saved
  (leaderstat "Best Night") and persists between sessions.
- Goal: survive all 99 nights. Day lasts 5 minutes, night lasts 3; the
  run's current night is saved server-side, so a restarted server picks
  up where it left off instead of resetting to Night 0.

## Tuning

- Day/night pacing, transition timing, and Lighting presets:
  `src/ReplicatedStorage/Configs/DayNightConfig.lua`.
- Everything else (hunger drain, recipe costs, enemy stats, map size/
  resource density): `src/ReplicatedStorage/GameConfig.lua`.
