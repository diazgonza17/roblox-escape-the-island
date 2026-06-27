# Escape the Island - Rojo Migration Improvement TODO

Context: this project was recently migrated to Rojo so scripts can be edited in an IDE and versioned with git. The items below are not cosmetic cleanup; they are architecture improvements intended to make the Roblox client/server boundary explicit, prevent player-data lifecycle bugs, and move visual-only work off the server.

## 1. Version stable remotes in `src/shared` instead of creating them dynamically

Current behavior:
- `src/server/NetworkInit.server.lua` creates `PadVisualEvent` and `GetPadInitialTextFunction` at runtime under `ReplicatedStorage`.
- `src/server/UpgradeService.server.lua` and `src/client/PadVisualController.client.lua` depend on those remotes by name.

Why this should change:
- These remotes are part of the stable client/server API contract, not temporary runtime objects.
- Since the project uses Rojo, stable Roblox instances can be represented in the repository and synced into Studio.
- Keeping remotes as source-controlled instances makes the API easier to inspect, review, rename safely, and reproduce from a clean clone.
- Rojo supports `.model.json` files for instances. A remote can be represented as a small JSON model, for example:

```json
{
  "ClassName": "RemoteEvent"
}
```

and:

```json
{
  "ClassName": "RemoteFunction"
}
```

Possible target structure:

```text
src/shared/Remotes/PadVisualEvent.model.json
src/shared/Remotes/GetPadInitialTextFunction.model.json
```

Expected code direction:
- Remove or replace `NetworkInit.server.lua` once remotes are Rojo-owned.
- Update server/client code to access remotes through a clear folder path, for example `ReplicatedStorage:WaitForChild("Remotes")`.
- Avoid scattering `Instance.new("RemoteEvent")` / `Instance.new("RemoteFunction")` across gameplay services.

Acceptance criteria:
- A fresh clone plus Rojo sync produces the required remotes in `ReplicatedStorage` without running a setup script first.
- `PadVisualController.client.lua` and `UpgradeService.server.lua` both reference the same source-controlled remotes.
- No duplicate remote instances are created at runtime.

## 2. Centralize player data ownership and cleanup

Current behavior:
- `PlayerData.lua` stores all player data in one shared in-memory table keyed by `UserId`.
- `CoinService.server.lua` calls `PlayerData.removeData(player)` on `Players.PlayerRemoving`.
- `UpgradeService.server.lua` also calls `PlayerData.removeData(player)` on `Players.PlayerRemoving`.

Why this is risky:
- Multiple services currently believe they own the lifecycle of the same player data.
- Roblox does not guarantee that independent `PlayerRemoving` handlers in different scripts will run in the order the developer expects.
- When persistent DataStore saving is added, one service could remove data before another service has finished saving or reading it.

Expected code direction:
- Create a single owner for player data lifecycle, likely a dedicated `PlayerDataService` or equivalent server module/script.
- That owner should handle player join initialization, future DataStore load/save, and final cleanup/removal from memory.
- Gameplay services such as `CoinService` and `UpgradeService` should update data through this owner, but should not delete shared player data themselves.

Acceptance criteria:
- Only one service handles `PlayerData.removeData(player)` or equivalent final cleanup.
- Coin and upgrade systems can update player data without owning its lifetime.
- The design is ready for future DataStore persistence without race-prone cleanup ordering.

## 3. Reapply latest upgraded stats on respawn

Current behavior:
- `UpgradeService.server.lua` reads saved jump/speed values when the player joins.
- It stores those values in local variables `currentJump` and `currentSpeed`.
- On each `CharacterAdded`, it reapplies those original join-time values to the new humanoid.

Why this is risky:
- If a player buys a jump or speed upgrade after joining, `PlayerData` is updated, but the local variables captured at join time are not necessarily updated.
- If the player dies and respawns, `CharacterAdded` can reapply stale values and effectively reset the player's upgraded stats for that session.

Expected code direction:
- On every character spawn, read the latest jump/speed values from `PlayerData`, then apply them to the humanoid.
- Keep the server authoritative for stat application.
- Avoid relying on values captured only once during `PlayerAdded`.

Acceptance criteria:
- A player can buy a jump or speed upgrade, die, respawn, and keep the upgraded value.
- The value applied to the humanoid on respawn matches the latest server-side player data.
- Initial default values still apply correctly for new players with no upgrades.

## 4. Move coin spinning to a client-side visual controller

Current behavior:
- `CoinService.server.lua` rotates every active coin on `RunService.Heartbeat` by modifying each coin part's `CFrame` on the server.
- The server also handles coin collection, cooldown, visibility, and coin rewards.

Why this should change:
- Coin rotation is visual-only; it does not affect authoritative gameplay state.
- Server-side per-frame `CFrame` changes replicate to clients, which creates unnecessary server CPU and network replication work.
- The server should own collection validity, cooldowns, rewards, and anti-cheat-sensitive state, but not cosmetic animation.

Expected code direction:
- Keep coin collection logic server-side.
- Keep coin cooldown/enable state server-side.
- Create a client visual script that rotates visible/tagged coin parts locally.
- Consider using `CollectionService` on the client as well, matching the existing server-side `Coin` tag approach.

Acceptance criteria:
- Coins still visually spin for players.
- Collecting coins still works and remains server-authoritative.
- The server no longer updates coin rotation every heartbeat for cosmetic purposes.
- Coin visibility/cooldown behavior remains consistent after collection.

## 5. Replace one polling loop per upgrade pad with a scalable pad-processing model

Current behavior:
- `UpgradeService.server.lua` calls `setupUpgradePad(upgradePad)` for each pad.
- Each pad starts its own `task.spawn` loop.
- Every loop wakes every `PAD_CHECK_INTERVAL` seconds and checks every player to see whether they are standing on that specific pad.

Why this can become an issue:
- With a small number of pads and players, this is acceptable.
- As pad/player count grows, checks scale as `number_of_pads * number_of_players` every interval.
- Many independent loops are harder to debug, profile, stop, and coordinate.
- Per-pad local state makes future global rules harder, such as limiting a player to one active upgrade interaction at a time.

Expected code direction:
- Prefer one centralized upgrade-processing loop that owns all pad/player interaction state.
- Track all upgrade pads in a single collection, ideally using `CollectionService` tags or a controlled folder watcher.
- On each interval, process players and pads from one place.
- Alternatively, use touch/zone tracking to maintain enter/exit state, then only process players currently inside upgrade zones.

Acceptance criteria:
- Upgrade hold-to-buy behavior remains the same from the player's perspective.
- The server has one clear control path for pad processing instead of one background loop per pad.
- Adding/removing upgrade pads at runtime is handled deliberately.
- The implementation remains understandable for future DataStore and upgrade-system expansion.

## 6. Remove unused local variables and small dead code

Current behavior:
- `UpgradeService.server.lua` calculates `nextCost` after a successful purchase, but the variable is not used.

Why this should change:
- Unused variables create noise and can hide real logic mistakes.
- Keeping the codebase clean matters more after migrating to Rojo because IDE/editor tooling can surface these issues consistently.

Expected code direction:
- Remove the unused `nextCost` variable unless it becomes part of an actual behavior change.
- While touching nearby code, avoid unrelated refactors.

Acceptance criteria:
- No unused `nextCost` local remains in `UpgradeService.server.lua`.
- Purchase behavior remains unchanged.

## 7. Research Roblox/Luau IDE tooling for linting, formatting, typechecking, and IntelliSense

Current behavior:
- The project has Rojo and Aftman configured, but no documented linting, formatting, typechecking, or editor intelligence workflow yet.

Why this matters:
- The project was migrated to Rojo specifically to make development easier in an IDE and safer in git.
- Similar to ESLint and Prettier in JavaScript projects, Roblox/Luau projects can benefit from automated style checks, formatting, diagnostics, type analysis, and better autocomplete/navigation.

Research direction:
- Investigate common Roblox/Luau tools for formatting, linting, static analysis, typechecking, and editor IntelliSense.
- Look into tools such as StyLua, Selene, Luau language server support, Luau type annotations, and any Rojo/Aftman-compatible workflows.
- Determine which tools are appropriate for this project size and current learning stage.
- Consider whether these should run manually, through editor integration, through git hooks, or later through CI.

Acceptance criteria for future research:
- Produce a recommended tooling setup for this repository.
- Explain what each tool does and why it is useful.
- Document required editor extensions and project config files.
- Avoid adding tools blindly; choose only tools that provide clear value for this Roblox/Rojo workflow.
