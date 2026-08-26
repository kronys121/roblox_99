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
  GameConfig.lua               Shared balance constants: day/night length,
                                hunger/stamina rates, recipes, enemy stats
src/ServerScriptService/
  Main.server.lua               Boot script, wires every system together
  WorldGenerator.lua            Builds ground, spawn, and resource nodes
  DayNightCycle.lua             Advances time, tracks night 1-99
  PlayerDataManager.lua         DataStore persistence + leaderstats
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
- Goal: survive all 99 nights.

## Tuning

Every balance number (day/night length, hunger drain, recipe costs, enemy
stats, map size/resource density) lives in
`src/ReplicatedStorage/GameConfig.lua`.
