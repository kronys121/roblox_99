# 99 Nights in the Forest

A from-scratch Roblox co-op survival-horror game (1-8 players): gather
resources, craft a tree of tools/weapons/fortifications, build and defend
a base with the whole team, and survive as many of 99 escalating nights
as you can.

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
  GameConfig.lua               Survival, gathering, crafting, building,
                                enemy scaling, currency, cosmetics, and
                                Game Pass config -- the balance dial for
                                everything except time-of-day
  Configs/DayNightConfig.lua   Day/night pacing + Lighting presets
src/ServerScriptService/
  Main.server.lua               Boot script, wires every system together
  WorldGenerator.lua            Builds ground, spawn, Warehouse chest,
                                and every resource node type
  DayNightCycle.lua             Advances Lighting, tracks the current
                                night, fires NightStarted/DayStarted
  WorldStateStore.lua           DataStore persistence for the current
                                night + the shared Warehouse stockpile
  Warehouse.lua                 The shared base stockpile (resources +
                                crafted Buildables) every player draws
                                from and deposits into
  DepositStation.lua             Wires the Warehouse chest's "Deposit"
                                prompt
  PlayerDataManager.lua         Per-player DataStore: personal carry,
                                best night, Embers currency, cosmetics
  SurvivalStats.lua              Health/Hunger/Thirst/Stamina simulation
  ResourceNodes.lua              Gathering (trees/rocks/bushes/water/ore)
  CraftingSystem.lua             Recipe tree validation against the
                                Warehouse, tool prerequisites, craft time
  BuildingSystem.lua             Grid-snapped placement, structure HP,
                                repair, trap damage-over-time
  EnemySpawner.lua                PathfindingService-driven AI, per-night
                                difficulty scaling, boss nights,
                                coordinated pack attacks
  GamePassService.lua             Game Pass ownership checks (extra carry,
                                instant crafting)
  ShopService.lua                 Embers-funded cosmetic purchases
  LeaderboardService.lua          Global "best night" OrderedDataStore
src/StarterPlayer/StarterPlayerScripts/
  Main.client.lua                 Client bootstrap, sprint input
  HUDController.lua               HUD: night/phase countdown, health/
                                hunger/thirst/stamina, personal +
                                Warehouse resource counts, currency
  CraftingController.lua          Crafting menu (press C)
  BuildingController.lua          Grid-snapped placement preview
                                (press B, Tab)
  ShopController.lua              Cosmetic + Game Pass shop (press V)
  LeaderboardController.lua       Global best-nights leaderboard (press L)
```

## Running it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (CLI + the Roblox Studio plugin).
2. From the repo root, start the Rojo server:
   ```
   rojo serve
   ```
3. In Roblox Studio, open the Rojo plugin panel and click **Connect**.
4. Press **Play** (use the **Start** / multi-client test tool with 2+
   players to see the co-op systems: shared Warehouse, coordinated
   building, etc). Everything builds itself on start -- no manual setup.

Alternatively, build a standalone place file without Studio open:
```
rojo build -o "99NightsInTheForest.rbxlx"
```

## Gameplay

- **Gather**: use the ProximityPrompt on trees/rocks/bushes/water pools/
  ore veins for Wood, Stone, Berries, Water, and Rare Material. Personal
  carry is capped (see Tuning) -- return to the **Warehouse** chest near
  spawn and use its "Deposit" prompt to add your haul to the shared base
  stockpile.
- **Survive**: Health, Hunger, and Thirst all matter. Eat Berries / Drink
  Water (HUD buttons) before they hit zero or you start taking damage.
  Sprint with Left Shift (drains Stamina).
- **Craft** (`C`): a four-tier tree -- Tools (Axe, Pickaxe) -> Weapons
  (Spear, Sword, gated behind a tool) -> Fortifications (walls, doors,
  spike traps, watchtowers) -> Advanced gear (Steel Pickaxe, Crossbow,
  Reinforced Wall, gated behind Rare Material + a tier-2 item). Everything
  is paid for out of the shared Warehouse, so the whole team contributes.
- **Build** (`B`, `Tab` to cycle, click to place): placement snaps to a
  grid. Every structure has durability shown via its own "Repair" prompt;
  enemies (and spike traps, against enemies) damage structures over time.
- **Fight**: forest creatures spawn at night and path toward players
  using Roblox's PathfindingService, smashing through fortifications in
  their way. Difficulty (health, damage, speed, chase range, and horde
  size) scales with both the night number and how many players are
  online. From Night 15 on, spotting a player alerts nearby creatures to
  converge together. Every 10th night, a large boss creature also spawns.
- **Progress**: your best night reached is saved (leaderstat "Best
  Night") and feeds a global leaderboard (`L`) across all servers. Every
  night survived earns Embers (bonus on boss nights), spendable in the
  shop (`V`) on purely cosmetic auras. The shop's Game Passes tab is
  wired up for real Robux monetization -- see below.
- Goal: survive all 99 nights. Day lasts 5 minutes, night lasts 3; the
  run's current night and the Warehouse stockpile are saved server-side,
  so a restarted server resumes instead of starting over.

## Setting up real Game Passes (optional)

`GameConfig.GamePasses` ships with `Id = 0` placeholders for "Extra
Backpack" and "Swift Crafting" -- Game Pass IDs are created per-experience
in the Roblox Creator Dashboard, so nobody can pre-fill them for you. To
enable real Robux purchases:

1. Publish this place, then create the two Game Passes for it in the
   Creator Dashboard (Monetization -> Game Passes).
2. Paste each pass's numeric ID into the matching entry's `Id` field in
   `src/ReplicatedStorage/GameConfig.lua`.
3. That's it -- the shop UI automatically enables the "Buy" button and
   `GamePassService` starts checking real ownership once `Id > 0`.

## Tuning

- Day/night pacing, transition timing, and Lighting presets:
  `src/ReplicatedStorage/Configs/DayNightConfig.lua`.
- Everything else (carry caps, survival rates, resources, the crafting
  tree, enemy/boss scaling, building durability, currency, cosmetics,
  Game Passes, map size): `src/ReplicatedStorage/GameConfig.lua`.
