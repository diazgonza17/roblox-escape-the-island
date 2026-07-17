# Escape the Island - Agent Guide

## Project purpose

This is the developer's first Roblox project and a mechanics-first learning project. Favor clear, incremental solutions that are easy to understand, test, tune, and reuse. Avoid introducing frameworks, abstractions, or large rewrites unless they solve a demonstrated need and the developer agrees to them.

The game is a parkour-first action progression game. Players traverse increasingly difficult stone towers and other obstacles above a lethal sea. Enemies add pressure during traversal and provide coins when defeated. Players spend rewards on upgrades that make later obstacles and encounters easier. Reaching the end of a run should eventually award a Rebirth Point for longer-term progression.

The intended core loop is:

1. Traverse the parkour route while avoiding the sea and nearby enemies.
2. Use a simple one-button melee attack without stopping movement.
3. Defeat enemies and collect the shared coins they drop.
4. Spend coins on movement or combat upgrades.
5. Use those upgrades to overcome harder parts of the route.
6. Reach the end, earn a Rebirth Point, and begin another run.

The map and its stone-tower course are an early prototype, not a settled final layout or art direction.

## Design priorities

- Prioritize fun, responsiveness, and playability before story, detailed art, animation polish, or elaborate map construction.
- Use the project to explore gameplay systems through code.
- Keep parkour as the primary objective. Combat should create pressure and feed progression, not turn the game into a combat-focused experience.
- Keep controls simple. The initial combat design uses one melee action that can hit all valid nearby enemies while the player continues running or jumping.
- Future weapons, armor, and temporary power-ups should equip or activate automatically. Do not require inventory management or interrupt the run with item-selection screens.
- Treat mobile controls and the lowest Roblox graphics quality as baseline requirements, not later compatibility work.
- Prefer placeholder geometry, native Roblox materials, and native UI while validating whether a mechanic is fun.
- Make multiplayer behavior part of the initial system design. Do not build a single-player gameplay path that will require a later multiplayer rewrite.

## Authority and multiplayer model

Gameplay state shared by players must be server-authoritative. The server owns:

- enemy spawning, targeting state, health, damage, death, and despawning
- melee cooldown validation, range validation, damage, and hit results
- coin-drop creation, collection eligibility, reward values, and cleanup
- player currencies, purchases, upgrades, hazards, run completion, and future persistence

Clients may own input, UI, immediate cosmetic feedback, animation, interpolation, and other presentation or performance optimizations. Client visuals must reflect server state and must not decide authoritative outcomes.

Enemies and dropped coins should be created as shared server-world objects so every current player can see and interact with the same encounter. Shared rewards may be collected by the first player to reach them; this competitive/helpful multiplayer behavior is intentional for initial testing.

## Coin direction

Placed, permanently located, respawning coins are deprecated and unsupported.

- Do not preserve compatibility with placed coins when modifying coin-related code.
- Do not add features, abstractions, origin fields, or branches that distinguish placed coins from enemy-dropped coins.
- New coin behavior should assume coins are runtime drops created after an enemy dies.
- If placed coins break after coin-system changes, resolve the Studio-side issue by deleting the placed coins rather than complicating the new code.
- The current `CoinService.server.lua` still represents the old placed-coin implementation. Treat it as legacy code to replace when the enemy-drop loop is implemented, not as a contract to preserve.

## Current and planned gameplay systems

Currently implemented:

- `UpgradeService.server.lua` owns upgrade purchases. Pads sell `JumpPower` or `WalkSpeed`, require a one-second hold, and increase their price after repeated purchases.
- `PadVisualController.client.lua` presents pad text, hold progress, purchase success, and insufficient-funds feedback locally.
- `HazardService.server.lua` kills players when they touch parts under `Workspace.World.Hazards`; the current hazard is a large sea box below the route.
- `PlayerData.lua` stores session-only player data. There is no DataStore persistence yet.
- `Leaderboard.lua` exposes coins, jump power, and walk speed through Roblox `leaderstats`.
- `CoinService.server.lua` implements the deprecated placed-coin behavior.

Planned direction:

- one code-configured spawn-zone system with optional debug visualization
- one floating enemy implementation; multiple enemy types are not currently in scope
- one-button radial melee, presented as a character spin with a sword
- shared, expiring coin pickups dropped by defeated enemies
- a native Roblox HUD that initially keeps all relevant elements visible
- run completion that awards one Rebirth Point
- an upgrade system supporting multiple spendable currencies, purchase limits, locks, and run/permanent scopes
- future automatically equipped weapons, armor, and temporary effects

## Repository and Studio boundaries

This is a Luau project synchronized with Roblox Studio through Rojo. `aftman.toml` pins Rojo 7.6.1.

The Rojo project currently maps:

- `src/server` to `ServerScriptService`
- `src/client` to `StarterPlayer.StarterPlayerScripts`
- `src/shared` to `ReplicatedStorage`

The repository does not currently contain the complete Roblox place. The island, sea, stone towers, old coin models, upgrade-pad models, attributes, tags, lighting, and other scene instances may exist only in the Studio place.

Do not assume that an instance is absent from the game merely because it is absent from the repository. Before changing paths, tags, attributes, model structure, or world-dependent behavior, identify the expected Studio structure and state any assumptions.

Known runtime expectations currently include:

- `Workspace.World.Hazards`
- `Workspace.World.Upgrades`
- upgrade-pad attributes `UpgradeType`, `Cost`, `BoostAmount`, `Multiplier`, and `PadId`
- upgrade pads may contain `Fill`, a `BillboardGui`, and a `TextLabel` used by client visuals

Prefer version-controlled configuration for new gameplay placement. Enemy spawn volumes should be described in a Luau configuration module using identifiers, `CFrame` centers, sizes, limits, and timing values. Generate optional visible debug parts from this configuration during Studio testing instead of requiring permanent hand-placed spawn markers.

## Progression terminology

Keep spendable resources separate from progress counters.

Spendable currencies currently planned:

- `Coins`
- `RebirthPoints`

Progress counters or unlock requirements may include:

- `EnemyKills`
- `RunsCompleted`

Do not automatically model enemy kills as a spendable currency. If a design later spends kills, that decision must be explicit. Upgrade definitions should eventually identify their cost currency, cost formula, maximum purchase count, requirements, and whether they apply only to the current run or persist across runs.

## UI direction

- Replace reliance on Roblox `leaderstats` as the primary player-facing display with a custom native Roblox HUD.
- Initially keep all relevant HUD elements visible at all times because that is simplest to implement and test.
- A later short-term improvement may hide upgrade-specific or otherwise unnecessary HUD elements during parkour and reveal them inside upgrade zones.
- Use native Frames, text, buttons, corners, strokes, gradients, constraints, and layout objects before introducing custom image assets.
- UI must be readable at low resolution, support touch input, and avoid overlapping Roblox movement and jump controls.
- Text must remain actual text rather than being baked into images.

## Working conventions

- Read `TODO-tech.md` before undertaking architecture or cleanup work.
- Read `TODO-creative.md` before proposing or implementing gameplay features.
- Keep technical debt and architecture cleanup in `TODO-tech.md`.
- Keep gameplay features, experiments, design goals, priorities, and playtest questions in `TODO-creative.md`.
- Treat brainstormed or later-stage TODO ideas as proposals, not approved implementation requirements. Implement the selected immediate milestone unless the user explicitly expands scope.
- Distinguish confirmed behavior, code-derived inference, provisional tuning, and creative suggestion.
- Preserve the parkour-first enemy-reward-upgrade loop unless a requested feature deliberately changes it.
- Prefer data-driven configuration for repeated systems when it makes iteration and reuse easier without hiding behavior behind unnecessary abstraction.
- Make focused changes and avoid unrelated refactors.
- Explain Roblox- or Luau-specific choices when they may be unfamiliar to a developer learning the platform.
- Design reusable system boundaries, but do not generalize for hypothetical enemy types, games, or item categories before the current mechanic works.

## Performance baseline

- Test gameplay at the lowest available Roblox graphics quality.
- Treat mobile touch controls and low-resolution layouts as required from the first playable version.
- Keep explicit global and per-zone caps for enemies and dropped items.
- Prefer event-driven work and limited-rate simulation over unnecessary per-frame server processing.
- Avoid ground pathfinding for the initial floating enemy unless simple direct pursuit proves insufficient.
- Ensure dropped objects expire and event connections are cleaned up.
- Use simple placeholder parts and built-in materials while mechanics are experimental.
- Client-side cosmetic work may improve performance, but authoritative state must remain on the server.
- Do not add complex optimization such as pooling until measurements or playtests demonstrate a need.

## Validation

There is currently no automated test suite or documented lint command. Validate changes proportionally:

- Review Luau code paths, remote boundaries, and server validation.
- Confirm Rojo mappings remain valid after file-structure changes.
- For gameplay changes, describe and perform the necessary Roblox Studio playtest when possible; the full world is not represented in source control.
- Test affected behavior with player death and respawn when movement, combat, currencies, or character state are involved.
- Test shared systems with at least two simulated players when enemies, dropped coins, upgrade pads, remotes, or per-player visuals are involved.
- Test touch layout through Studio device emulation and, when practical, test performance on actual low-end hardware.
- Test at the lowest graphics quality.
- Do not claim Studio-dependent behavior was fully verified if only the repository was inspected.

## Explicitly deferred or out of scope

- compatibility with placed coins
- multiple enemy types
- traditional inventory-management screens
- detailed story development
- polished 3D art or a final map layout
- complex aiming controls
- premature generic frameworks for future games

## Unknown or undecided design areas

Do not silently invent durable answers for these. Use provisional values for testing or ask the user when a decision materially affects scope:

- exactly what resets after reaching the end of a run
- which upgrades are run-only versus permanent
- whether Rebirth Points persist before DataStore support exists
- final enemy health, damage, speed, attack radius, cooldowns, and rewards
- player death penalties and checkpoint behavior
- automatic item replacement and stacking rules
- final progression length and economy balance

Update this file when a durable project fact, constraint, or working convention is confirmed. Put detailed feature planning and changing priorities in `TODO-creative.md` rather than expanding this guide into a backlog.
