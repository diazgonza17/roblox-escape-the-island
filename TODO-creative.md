# Escape the Island - Creative and Gameplay TODO

## Purpose of this document

This is the detailed gameplay and feature backlog for Escape the Island. It records the intended player experience, confirmed design direction, implementation milestones, playtest questions, acceptance criteria, and later experiments.

This document is deliberately extensive. Its job is to preserve why a feature exists and how it should fit the game, not merely list feature names.

Use `TODO-tech.md` for architecture cleanup, migration work, tooling, and technical debt that does not directly define a player-facing feature. Some gameplay features will require technical improvements; keep the player-facing objective here and cross-reference technical work rather than moving the entire feature into the technical TODO.

## How to interpret priorities

- **Immediate:** the next playable vertical slice. Keep implementation focused here unless the developer selects another task.
- **Next:** a coherent milestone to attempt after the immediate loop is playable and has been tested.
- **Later experiment:** a worthwhile mechanic that is intentionally not part of the current implementation scope.
- **Deferred:** specifically excluded until a prerequisite or playtest justifies revisiting it.
- **Provisional:** a value or behavior chosen to make testing possible; it is not final balance.

Checkboxes represent implementation work, not design approval. A later idea remaining unchecked does not authorize an agent to implement it as part of an earlier milestone.

---

## Confirmed game direction

### Development philosophy

- The project is mechanics-first and is intended to teach and explore different areas of Roblox game development through code.
- Fun, responsiveness, and playability take priority over story, detailed art, elaborate animation, or building a perfect map.
- Placeholder parts, rough layouts, and native UI are acceptable while validating mechanics.
- Features should be tested at the lowest available Roblox graphics quality.
- Mobile is a baseline platform. A mechanic should not depend on precise mouse input, many buttons, small text, or expensive visuals.
- New gameplay should be multiplayer-native from the beginning. Server-world enemies, rewards, and upgrades should naturally be visible and usable by all current players.
- Gameplay authority belongs on the server. Client work is appropriate for input, UI, animation, visual feedback, interpolation, and performance improvements.
- Systems should have clean boundaries that may later be reusable in another project, but current work should not be delayed by premature generalization.

### Player fantasy and priorities

The player is primarily trying to complete a parkour route over a lethal sea. Enemies create moving pressure, reward awareness, and provide resources, but defeating enemies is not the main objective.

Combat should therefore:

- require very little input complexity
- work without stopping movement
- remain usable during jumps and falls
- avoid precise aiming
- reward clearing immediate danger rather than hunting the whole map
- feed the upgrade and run-completion loops

### Intended core loop

1. Begin a run near the start of the parkour route.
2. Traverse increasingly difficult obstacles above the lethal sea.
3. Avoid or defeat floating enemies that approach during traversal.
4. Use one-button radial melee when enemies come close.
5. Collect coins dropped by defeated enemies.
6. Spend coins on movement or combat upgrades.
7. Use the upgrades to make later obstacles and encounters easier.
8. Reach the end of the route.
9. Gain one Rebirth Point.
10. Begin another run with access to longer-term progression.

### Coin policy

Placed, permanently located, respawning coins are no longer supported.

- Enemy drops are the intended source of coins.
- New code must not distinguish between placed and dropped coin origins.
- No new feature should depend on placed coins.
- If old placed coins become incompatible or broken, delete them from the Studio place.
- The existing placed-coin implementation is legacy code to replace when the enemy-drop milestone is developed.

### Current scope limit

Only one floating enemy implementation is planned. Do not create an enemy-type selection system, enemy inheritance model, or backlog of named enemy variants yet. First determine whether a single enemy improves the parkour loop.

---

# Immediate milestone - Playable enemy reward loop

## Milestone goal

Create the smallest complete loop in which shared enemies spawn from version-controlled regions, pursue players, can be defeated with one simple melee action, and drop shared coins that update a minimal HUD.

The intended first slice is:

```text
One code-defined spawn zone
    -> at most three placeholder floating enemies
    -> enemies pursue nearby players
    -> players use one-button radial melee
    -> killed enemies drop shared coins
    -> the first player to touch a coin collects it
    -> the HUD displays the updated amount
```

The milestone is successful if this rough loop is enjoyable enough to repeat. It does not require polished visuals, a sophisticated sword, multiple enemies, persistence, balanced progression, or the final upgrade system.

## Provisional tuning values

These exist to make the first playtest concrete. Keep them centralized and easy to change.

| Value | Provisional setting | Reason for first test |
|---|---:|---|
| Maximum enemies in first zone | 3 | Easy to observe and inexpensive to simulate |
| Enemy maximum health | 100 | Simple two-hit relationship with proposed melee damage |
| Enemy movement speed | 10 studs/second | Visible pressure without immediately overwhelming parkour |
| Enemy detection range | 80 studs | Activates within a meaningful local area |
| Enemy pursuit/leash range | 120 studs | Prevents permanent pursuit across the entire map |
| Enemy contact damage | 20 health | Threatening without causing an immediate death |
| Damage repeat cooldown | 1 second | Prevents rapid proximity damage from deleting a player |
| Melee damage | 50 | Defeats the first enemy in two valid attacks |
| Melee radius | 8 studs | Forgiving enough for mobile and movement |
| Melee cooldown | 0.8 seconds | Prevents spam while staying responsive |
| Coin reward per enemy | 25 coins | Easy number for early economy experiments |
| Dropped coin lifetime | 20 seconds | Gives players time to collect without accumulating objects |
| Spawn interval | 5 seconds | Produces a readable initial pace |

Change these after playtesting. Do not distribute copies of the same value across unrelated scripts.

---

## 1. Version-controlled enemy spawn zones

### Design intent

Enemy placement should not depend on manually maintained, unversioned spawn parts in Studio. Spawn regions should be recoverable from the repository and adjustable through code.

### Proposed representation

Create a dedicated Luau configuration module containing a list of spawn zones. Each initial zone should define at least:

- stable string identifier
- center/orientation as a `CFrame`
- volume size as a `Vector3`
- maximum simultaneously alive enemies
- spawn interval
- player activation range
- enemy leash or allowed pursuit range

Conceptual example:

```lua
{
    id = "StartingRoute",
    cframe = CFrame.new(0, 20, 0),
    size = Vector3.new(60, 20, 80),
    maxAlive = 3,
    spawnInterval = 5,
    activationRange = 100,
    leashRange = 120,
}
```

The example coordinates are illustrative and are not the real zone configuration.

### Debug visualization

During Studio testing, code should optionally generate a visible box for each configured volume.

The visualization should:

- show the exact configured position, orientation, and size
- clearly identify the zone, ideally through a label or recognizable color
- be non-collidable and not affect gameplay
- be controlled by one debug setting
- remain hidden or absent during ordinary published play
- be generated from the same configuration used by spawning so it cannot drift from actual behavior

### Spawn behavior

- Choose random points inside the configured oriented volume.
- Do not spawn when no valid player is close enough to activate the zone.
- Respect both zone and global enemy limits.
- Avoid spawning directly inside a character when practical.
- Track which zone owns each spawned enemy.
- Stop replenishing enemies after the zone is inactive.
- Decide deliberately whether existing enemies return, wait, or despawn after all players leave.

For the first version, it is acceptable to despawn enemies after a grace period when no players are nearby. This is provisional and should be evaluated during multiplayer tests.

### Tasks

- [ ] Create the spawn-zone configuration module.
- [ ] Add one real zone around a suitable early section of the current route.
- [ ] Implement random point selection inside an oriented box.
- [ ] Add one global enemy cap in addition to the per-zone cap.
- [ ] Activate spawning only when at least one living player is nearby.
- [ ] Track enemies by owning zone.
- [ ] Add cleanup for inactive zones and destroyed enemies.
- [ ] Add optional Studio-only debug visualization.
- [ ] Document how to adjust and visually verify a zone.

### Acceptance criteria

- A fresh copy of the repository contains the spawn-zone definitions.
- Starting a Studio playtest generates the same zones without manually placed spawn markers.
- Enabling debug visualization shows boxes matching the actual spawn volumes.
- Enemies never exceed the configured zone or global cap.
- A zone does not continuously spawn enemies while no players are nearby.
- Changing configuration values and restarting the playtest predictably changes the region.

### Playtest questions

- Is editing raw coordinates tolerable for the current map size?
- Is the debug visualization sufficient to tune placement without dragging Studio objects?
- Does spawning feel predictable enough to learn without feeling static?
- Do enemies appear unfairly close to players or above unsafe jumps?

---

## 2. One placeholder floating enemy

### Design intent

The first enemy exists to apply moving pressure while the player performs parkour. It does not need pathfinding, complex animation, or a polished model.

### Representation

Use a simple placeholder model built from inexpensive Roblox parts. The enemy needs a stable root for movement and queries. Avoid creating a full character rig or Humanoid unless a concrete behavior requires it.

The enemy should have server-owned state for:

- current health
- current target player
- owning spawn zone
- spawn position or home region
- alive/dying state
- contact-damage cooldown per player or equivalent protection
- cleanup state and event connections

### Target selection

For the first implementation:

- Find valid living players within the enemy's detection range.
- Choose the nearest valid player when acquiring a target.
- Keep the current target until it becomes invalid, dies, or leaves the allowed pursuit area.
- Do not switch targets every update merely because another player becomes slightly closer.
- If the target becomes invalid, select another valid nearby player or return toward the home zone.

This prevents jittery multiplayer behavior and makes pursuit readable.

### Floating pursuit

- Move directly through three-dimensional space toward the target.
- Do not add ground navigation or PathfindingService during the first milestone.
- Update authoritative movement at a limited fixed rate rather than tying expensive decisions to every rendered frame.
- Keep pursuit smooth enough to understand, but prioritize simple and correct shared behavior.
- Do not allow the enemy to chase forever across the whole map.
- Consider a small vertical offset from the target so the enemy threatens without constantly clipping through the floor.

### Contact threat

The first enemy may damage a player when sufficiently close.

- Use server validation.
- Apply damage at most once per configured cooldown.
- Do not rely on uncontrolled repeated `Touched` events that can apply damage many times immediately.
- Preserve normal Roblox death and respawn behavior for the first test.
- Avoid extreme knockback initially because it can obscure whether basic pursuit is fun.

Knockback can be tested later if enemies are not threatening enough. It should not be included simply because the setting is above a lethal sea.

### Death behavior

- Once health reaches zero, transition exactly once into a dying state.
- Stop targeting, movement, and contact damage.
- Prevent repeated reward drops from duplicate damage events.
- Create the configured coin reward through the new dropped-coin system.
- Remove the enemy after minimal death feedback.
- Notify the owning zone so it may eventually spawn a replacement.

### Tasks

- [ ] Create one placeholder enemy model or code-built representation.
- [ ] Create server-owned enemy lifecycle state.
- [ ] Implement nearest-valid-player target acquisition.
- [ ] Prevent unnecessary target switching.
- [ ] Implement simple three-dimensional pursuit.
- [ ] Enforce detection and leash limits.
- [ ] Implement proximity/contact damage with repeat protection.
- [ ] Implement validated enemy damage and health reduction.
- [ ] Implement exactly-once death and cleanup.
- [ ] Release the enemy from its zone's alive count after cleanup.

### Acceptance criteria

- All simulated players see the same enemy positions and deaths.
- An enemy approaches a nearby living player without ground pathfinding.
- It does not pursue players indefinitely outside the configured area.
- Contact damage cannot fire continuously without respecting its cooldown.
- Enemy health cannot drop below zero through duplicate death processing that creates duplicate rewards.
- Destroyed enemies and inactive zones do not leave growing tables or active event connections.

### Playtest questions

- Does direct flight make the enemy too good at bypassing the obstacle course?
- Is it fun to manage an approaching enemy during a jump?
- Does the enemy block the camera or character too often?
- Is contact damage enough, or would modest knockback create better parkour pressure?
- Does the enemy need to pause, telegraph, or slow down before reaching the player?

---

## 3. One-button radial melee attack

### Design intent

The player needs one additional action beyond Roblox movement and jumping. The attack must be usable while moving through parkour and forgiving on touch devices.

The current presentation concept is a character spin with a sword. Mechanically, it is a radial melee attack that can damage every valid nearby enemy.

### Input behavior

- Provide one large mobile-friendly attack button.
- Map the same action to a convenient keyboard input and a gamepad input.
- Do not require aiming, locking on, selecting a target, or entering combat mode.
- Allow attacks while running, jumping, and falling.
- Pressing the input should still show attack feedback when no enemy is hit.
- Prevent holding the button from bypassing the intended cooldown unless deliberate auto-repeat is later approved.

### Server validation

The client reports that the player attempted an attack. The server decides the result.

Validate:

- the player and character are valid and alive
- the cooldown has elapsed according to server time
- enemies are still alive and within the allowed radius
- each enemy is damaged at most once by one attack activation
- damage uses server-owned values

Never accept a client-provided enemy list, damage amount, radius, or successful-hit result as authoritative.

### Hit query

Perform one spatial query when a valid attack activates. Do not run continuous melee hit detection every frame.

The query should:

- be centered consistently relative to the character root
- include all valid enemies inside the configured radius
- exclude players, scenery, destroyed enemies, and unrelated parts
- deduplicate models with multiple parts
- remain efficient with the configured enemy cap

### Presentation

The earliest version may use any of these levels of feedback, in order of importance:

1. Immediate button/cooldown response.
2. A clear character or weapon spin.
3. A brief simple arc or radius effect.
4. Hit feedback on affected enemies.
5. Sound, only after the mechanic works.

The visual spin must not rotate the camera unexpectedly, alter the player's trajectory, cancel a jump, or otherwise make parkour controls unreliable. If rotating the entire character causes control problems, rotate only the sword or a cosmetic effect.

### Sword representation

Do not build a weapon inventory for this milestone.

- A basic Part attached to the character is sufficient.
- A temporary visual sword can appear only during the attack if that is simpler.
- The damage query must not depend on the exact physical blade touching an enemy.
- Art quality is not an acceptance criterion.

### Tasks

- [ ] Define one cross-platform attack action.
- [ ] Add a touch-friendly attack button.
- [ ] Add keyboard and gamepad mappings.
- [ ] Create the client-to-server attack request.
- [ ] Validate character state and cooldown on the server.
- [ ] Query and deduplicate nearby enemies on valid activation.
- [ ] Apply damage to all valid enemies inside the radius.
- [ ] Add immediate local attack feedback.
- [ ] Add a simple sword/spin presentation that does not disturb movement.
- [ ] Display cooldown state through the HUD button.

### Acceptance criteria

- One button performs the complete attack on mobile.
- The same mechanic is usable with keyboard and gamepad.
- The player can attack without stopping a run or jump.
- Multiple nearby enemies can be hit by one activation.
- The server rejects attempts made before the cooldown ends.
- A modified client cannot choose arbitrary targets or damage values through the attack remote.
- Missing all enemies still produces understandable feedback.
- Attack presentation does not change the player's intended movement or camera direction.

### Playtest questions

- Is an 8-stud radius forgiving without making positioning irrelevant?
- Does the player understand when the attack is ready again?
- Does two-hit enemy health feel satisfying or merely repetitive?
- Is attacking while airborne helpful or distracting?
- Does hitting every nearby enemy create fun crowd control with three enemies?

---

## 4. Enemy-dropped coin pickups

### Design intent

Enemy death should produce a shared, visible reward that feeds the existing upgrade concept. Any current player may collect it, allowing both cooperation and light competition.

### Replacement policy

The new coin implementation replaces the gameplay assumptions of `CoinService.server.lua`.

Do not retain:

- permanent placed pickup registration
- same-location cooldown respawning
- origin-based branching
- compatibility logic for old tagged coin packages
- APIs whose only purpose is supporting both legacy and dropped coins

Studio-placed coins should be deleted when this milestone is integrated.

### Drop creation

On confirmed enemy death, the server should create one or more coin pickups near the death position.

For the first version:

- One pickup representing the complete reward is simplest.
- The pickup can use a smaller version of the current visual coin concept.
- It should be anchored or otherwise prevented from falling into the lethal sea before players can reach it.
- If it scatters visually, the final collectible position must remain fair and stable.
- All players should see the same pickup.

Whether drops should remain suspended at the exact death height, move to a nearby safe point, or fall onto a surface is a playtest question. Start with the simplest behavior that prevents rewards from becoming immediately unreachable.

### Collection

- The server validates collection.
- Only one player receives a given pickup.
- Collection must be atomic enough that simultaneous touches cannot reward multiple players accidentally.
- Add the configured value to the player's coin currency.
- Remove the pickup immediately after successful collection.
- Update the collecting player's HUD through replicated authoritative state or a clear server-to-client update.

The first-player-to-collect rule is intentional. Do not add ownership reservation or killer-only rewards during the first milestone.

### Lifetime and cleanup

- Destroy uncollected pickups after the configured lifetime.
- Apply a global dropped-pickup cap as a safety limit.
- When the cap would be exceeded, prefer cleaning the oldest eligible pickup or declining additional visual objects without corrupting rewards.
- Disconnect collection handlers during cleanup.
- Do not let pickups accumulate after players leave a zone.

### Visual behavior

- Coin spinning is cosmetic and should occur on clients.
- Keep geometry and effects inexpensive.
- All clients should derive visuals from shared pickup objects.
- Visual animation must stop naturally when the shared pickup is removed.

### Tasks

- [ ] Replace legacy placed-coin assumptions with a dropped-pickup service or equivalent focused implementation.
- [ ] Delete or stop relying on old tagged placed-coin registration.
- [ ] Create shared pickups at confirmed enemy death positions.
- [ ] Ensure drops remain reachable during the first test.
- [ ] Implement server-authoritative first-collector reward handling.
- [ ] Prevent duplicate collection rewards.
- [ ] Add expiration and global-cap cleanup.
- [ ] Move spinning to a client cosmetic controller.
- [ ] Update authoritative coin state and the custom HUD after collection.
- [ ] Remove placed coins from the Studio place during integration.

### Acceptance criteria

- Defeating an enemy creates a pickup visible to every simulated player.
- The pickup does not depend on any placed-coin tag or map instance.
- Exactly one player receives the reward when players reach it simultaneously.
- The pickup disappears for everyone after collection.
- Uncollected drops expire and do not grow indefinitely.
- Coins visibly rotate without server-side per-frame rotation.
- No new code path exists solely to preserve placed-coin compatibility.

### Playtest questions

- Does open shared collection feel playful or frustrating?
- Does the reward appear somewhere the fighting player can reasonably reach?
- Is one 25-value pickup clearer than several smaller pickups?
- Does a 20-second lifetime create urgency without needless loss?
- Are enemy rewards frequent enough to support upgrades after placed coins are deleted?

---

## 5. Minimal always-visible native HUD

### Design intent

Replace reliance on the Roblox leaderboard as the main information display with an accessible, code-created HUD that works on mobile. Keep all initial elements visible at all times because conditional contexts add unnecessary complexity before the systems exist.

### Initial information

The first HUD should reserve clear places for:

- Coins
- Rebirth Points, even if their award system is implemented in the next milestone
- Jump Power
- Walk Speed
- Attack button
- Attack cooldown state

Enemy kills may also be displayed if the value is already tracked for progression testing. Do not add it solely as decorative clutter before a counter exists.

### Presentation rules

- Use native Roblox UI objects.
- Prefer Frames, `TextLabel`, `TextButton` or `ImageButton`, `UICorner`, `UIStroke`, `UIGradient`, padding, and layout constraints.
- Keep styling centralized in a small theme/configuration module when practical.
- Use actual text for labels and values.
- Avoid custom image dependencies in the first version.
- Use readable contrast at the lowest graphics quality and on a low-resolution screen.
- Use scale-aware layout and appropriate constraints rather than assuming one desktop resolution.
- Keep the attack control away from Roblox's jump and movement controls.

### Data flow

- The HUD runs on the client because on-screen UI is client-side.
- Displayed currencies and stats must reflect server-authoritative values.
- Avoid using the HUD text itself as gameplay state.
- Provide a clear update path rather than having unrelated scripts directly search for and mutate arbitrary labels.
- The attack button should invoke the same input action as keyboard and gamepad controls.

### Simplicity rule

Do not implement context-based hiding during this milestone. Everything remains visible even when a value is not immediately relevant.

### Tasks

- [ ] Create the HUD entirely from source-controlled code or Rojo-owned instances.
- [ ] Add readable coin and Rebirth Point displays.
- [ ] Add jump-power and walk-speed displays.
- [ ] Add the attack button and cooldown feedback.
- [ ] Connect displays to authoritative player state.
- [ ] Check common phone, tablet, and desktop aspect ratios.
- [ ] Confirm the HUD does not cover movement or jump controls.
- [ ] Reduce or remove player-facing reliance on `leaderstats` once the HUD is reliable.

### Acceptance criteria

- A fresh Rojo sync produces the initial HUD without manual GUI construction.
- All required elements remain visible during both parkour and upgrade-zone use.
- Coins update after collecting an enemy drop.
- Attack readiness is understandable without watching server logs.
- The interface remains legible and usable in phone emulation.
- The attack button does not interfere with Roblox movement or jumping.
- UI values cannot be used by the client to grant itself currency or stats.

### Playtest questions

- Which displayed values are actually useful while jumping?
- Does the always-visible information feel reassuring or cluttered?
- Is the attack button reachable while simultaneously holding movement and jump?
- Can the player understand currency changes without the Roblox player list?

---

## 6. Immediate milestone multiplayer test

### Required scenarios

- [ ] Run a two-player Studio server test.
- [ ] Confirm both players see the same spawned enemies.
- [ ] Confirm an enemy chooses and retains a sensible target.
- [ ] Confirm either player can damage the same enemy.
- [ ] Confirm an enemy dies once when both players attack nearly simultaneously.
- [ ] Confirm only one reward drop is created for that death.
- [ ] Confirm both players see the same drop.
- [ ] Confirm only one player receives a contested pickup.
- [ ] Confirm one player's HUD does not show the other player's coin balance.
- [ ] Confirm enemy and drop cleanup still works after a player disconnects.
- [ ] Confirm player death does not permanently break targeting or melee.

### Multiplayer design observations

Record whether:

- helping another player fight feels useful
- coin stealing produces humor, competition, or frustration
- enemies unfairly concentrate on one player
- a player can drag an enemy into another player's parkour path in a fun or harmful way
- three global enemies are enough when multiple players are present

Do not add personal loot or damage-credit systems before observing the shared version.

---

## 7. Immediate milestone low-end and mobile test

### Required settings

- [ ] Test at the lowest Roblox graphics quality.
- [ ] Test at a low-resolution phone aspect ratio in Studio device emulation.
- [ ] Test touch attack, movement, and jump control overlap.
- [ ] Inspect client frame rate and memory summary during repeated spawning and cleanup.
- [ ] Inspect server performance while all configured enemies are active.
- [ ] Leave the test running long enough to notice accumulating enemies, drops, connections, or memory.
- [ ] Test on a real lower-end mobile device when practical.

### Performance constraints

- Enemy and drop counts must remain capped.
- Enemy decisions should not require expensive per-frame work.
- Melee should perform a spatial query only on valid attack activation.
- Coin spinning and short feedback effects should be cosmetic client work.
- Placeholder models should use few parts and built-in materials.
- Effects should be brief and should not depend on high graphics quality to communicate danger or success.
- Do not introduce pooling, Parallel Luau, or sophisticated optimization unless profiling demonstrates the need.

### Milestone completion criteria

The immediate milestone is complete only when:

- one complete enemy-to-coin interaction works repeatedly
- the interaction works with two players
- the interaction is usable with mobile controls
- the interaction remains understandable at the lowest graphics quality
- instance counts remain bounded over time
- the player can continue performing parkour while attacking
- coin rewards reach the correct player's authoritative balance and HUD
- placed coins are not supported by the new implementation
- remaining problems are documented as bugs, tuning questions, or later ideas

---

# Next milestone - Run completion and Rebirth Points

## Milestone goal

Give the parkour route a repeatable endpoint. Reaching the end should award one Rebirth Point and begin another run in a deliberate, understandable way.

## 1. Version-controlled finish definition

Prefer defining the finish trigger or finish region through source-controlled configuration, following the same philosophy as enemy spawn zones.

Possible first representation:

- a configured oriented box at the end of the route
- optional debug visualization during Studio testing
- a server-side check or generated trigger that detects a living player entering the region

### Tasks

- [ ] Define the finish region in version-controlled configuration.
- [ ] Generate an optional debug visualization.
- [ ] Detect valid completion on the server.
- [ ] Prevent repeated completion awards from standing inside the region.
- [ ] Handle death, teleportation, and reconnect edge cases deliberately.

### Acceptance criteria

- The completion region can be recreated from source.
- Entering it awards exactly one completion for the current run.
- Remaining inside it cannot farm unlimited Rebirth Points.
- Each player has independent run-completion state.

## 2. Rebirth Point reward

### Confirmed direction

- Award one Rebirth Point for reaching the end.
- Rebirth Points are a spendable currency distinct from coins.
- They are intended for longer-term or more powerful progression.

### Still undecided

- whether coins reset immediately after completing a run
- whether run upgrades reset
- whether movement stats reset
- whether the player must confirm the rebirth
- whether the point persists before DataStore support is implemented
- whether completion teleports the player immediately or after short feedback

### Recommended first test

For the earliest implementation:

1. Detect completion.
2. Award one session-only Rebirth Point.
3. Show clear completion feedback.
4. Return the player to the start after a short delay.
5. Avoid implementing a full progression reset until run-scoped upgrades exist.

This tests whether completing and repeating the short course is satisfying without forcing premature reset rules.

### Tasks

- [ ] Add authoritative `RebirthPoints` player data.
- [ ] Award exactly one point per completed run.
- [ ] Update the HUD.
- [ ] Add simple completion feedback using native UI.
- [ ] Return or respawn the player at the start.
- [ ] Reset the per-run completion guard.
- [ ] Track `RunsCompleted` separately as a progress counter if needed.

### Playtest questions

- Is the current course long enough for one point to feel earned?
- Does immediate return to the start encourage another run?
- Should enemies or upgrades reset before another run begins?
- Is one Rebirth Point per run a useful scale for permanent upgrades?

---

# Next milestone - Data-driven upgrade zones and multiple currencies

## Milestone goal

Replace manually configured individual upgrade-pad behavior with a reusable data-driven system. A developer should be able to describe an upgrade and an upgrade zone in code, then have the server generate and arrange the necessary pads.

The system must support:

- costs in Coins or Rebirth Points
- indefinitely repeatable upgrades with increasing prices
- upgrades purchasable a fixed number of times
- one-time purchases
- locked upgrades with explicit requirements
- upgrades that apply only to the current run
- upgrades intended to persist across runs
- code-generated placement inside configured upgrade zones

## 1. Wallet currencies versus progress counters

### Spendable wallet currencies

- `Coins`
- `RebirthPoints`

### Progress counters and requirements

- `EnemyKills`
- `RunsCompleted`
- potentially lifetime coins collected later

Do not reduce `EnemyKills` when an upgrade merely requires a number of kills. A requirement is not a price.

Conceptual cost representation:

```lua
cost = {
    currency = "Coins",
    baseAmount = 100,
    multiplier = 1.5,
}
```

Conceptual requirement representation:

```lua
requirements = {
    enemyKills = 10,
    upgradePurchases = {
        attackDamage = 2,
    },
}
```

The exact schema should remain small and readable. Do not build a general expression language for requirements.

### Tasks

- [ ] Define a small authoritative wallet API for registered currencies.
- [ ] Define progress counters separately from spendable balances.
- [ ] Ensure purchases cannot produce negative currency.
- [ ] Make the cost currency visible on each generated pad.
- [ ] Update the HUD after authoritative balance changes.
- [ ] Document how to add another currency without duplicating purchase logic.

## 2. Upgrade definitions

Each upgrade should be represented by source-controlled data rather than unique pad code.

Potential fields:

- stable upgrade ID
- display name
- description
- target stat or effect identifier
- amount per purchase
- cost currency
- base cost
- price multiplier
- maximum purchases, or unlimited
- run/permanent scope
- requirements
- display order
- optional pad color or simple visual category

Conceptual example:

```lua
{
    id = "attackRadius",
    displayName = "Attack Radius",
    effect = "AttackRadius",
    amountPerPurchase = 1,
    cost = {
        currency = "Coins",
        baseAmount = 100,
        multiplier = 1.5,
    },
    maxPurchases = 5,
    scope = "Run",
    requirements = {},
}
```

This is a design example, not a requirement to use these exact names.

### Purchase modes

- **Unlimited:** `maxPurchases` is absent or explicitly unlimited; price may continue increasing.
- **Limited:** a positive maximum greater than one.
- **One-time:** maximum of one.
- **Locked:** requirements are not yet satisfied; locking is a state, not a separate pad implementation.
- **Completed:** maximum purchases reached; do not continue charging or offering the pad as available.

### Tasks

- [ ] Create a source-controlled upgrade registry.
- [ ] Represent current Jump Power and Walk Speed upgrades through definitions.
- [ ] Support configurable cost currency.
- [ ] Support unlimited, limited, and one-time purchase counts.
- [ ] Support locked and completed states.
- [ ] Support clear run/permanent scope metadata.
- [ ] Keep effect application server-authoritative.
- [ ] Validate definitions and fail clearly on missing or invalid required fields.

## 3. Code-defined upgrade zones

An upgrade zone should be a source-controlled placement definition, not a manually maintained collection of pads.

Potential zone fields:

- stable zone ID
- origin `CFrame`
- platform size or expected available area
- list of upgrade IDs to include
- pad spacing
- number of columns or layout direction
- orientation
- optional debug visualization

The server should generate a simple platform and arrange pads relative to the configured origin, or use a minimal known platform representation generated from source.

### Placement requirements

- Adding an upgrade definition to a zone should not require manually positioning a new pad.
- Pad positions must be deterministic.
- Layout should remain readable when the number of pads changes.
- Pads should not overlap.
- The platform may remain visually primitive.
- Generated pads should retain the existing hold-to-buy concept unless playtesting changes it.

### Tasks

- [ ] Define one upgrade-zone configuration in code.
- [ ] Generate a placeholder platform or use a source-controlled platform representation.
- [ ] Generate pads from the zone's upgrade list.
- [ ] Arrange pads deterministically with configurable spacing.
- [ ] Populate text and state from upgrade definitions.
- [ ] Generate locked, available, insufficient-funds, holding, successful, and completed visual states.
- [ ] Support adding/removing definitions without manual pad cleanup.
- [ ] Add optional debug information for zone bounds and generated pad IDs.

## 4. Purchase flow

For each player and pad:

1. Determine whether requirements are satisfied.
2. Determine whether the maximum purchase count has been reached.
3. Calculate the current price from authoritative purchase history.
4. Check the appropriate authoritative currency balance.
5. Run the hold interaction.
6. Revalidate all conditions at purchase time.
7. Deduct the correct currency exactly once.
8. Apply the effect.
9. Record the purchase count in the correct run/permanent scope.
10. Update pad text and HUD state for that player.

### Acceptance criteria

- One purchase path handles Coins and Rebirth Points without duplicated services.
- A one-time upgrade cannot be purchased twice.
- A limited upgrade stops at its configured maximum.
- An unlimited upgrade continues increasing its price correctly.
- A locked upgrade cannot be purchased by bypassing client visuals.
- Two players can see different pad prices, locks, and completion states when their progression differs.
- Generated pads remain shared world objects while their informational presentation may be player-specific.
- Changing a definition or zone configuration is sufficient to alter generated content after restart.

## 5. Candidate first upgrades

These are candidates for testing the flexible system, not a commitment to implement all of them.

### Coin-funded run upgrades

- Jump Power
- Walk Speed
- Melee Damage
- Melee Radius
- Melee Cooldown reduction
- Maximum Health
- Contact-damage resistance

### Rebirth-funded longer-term upgrades

- Starting Jump Power
- Starting Walk Speed
- Starting Melee Damage
- Starting Coins
- Increased enemy coin reward
- One free damage shield per run
- Small permanent coin collection radius

Avoid adding enough upgrades to hide whether the first few are meaningful. The flexible system can be validated with a small representative set:

- one unlimited Coin upgrade
- one limited Coin upgrade
- one one-time Rebirth Point upgrade
- one locked upgrade

---

# Short-term improvement - Contextual HUD visibility

## Goal

After the always-visible HUD is stable, reduce screen clutter during parkour by hiding information that is only relevant near upgrade zones.

## Proposed behavior

Always visible during parkour:

- Coins
- Rebirth Points
- Attack button and cooldown
- possibly health if custom health display is necessary

Visible while inside an upgrade zone:

- Jump Power
- Walk Speed
- detailed combat stats
- upgrade affordances or summaries
- currency details relevant to available pads

### Requirements

- Zone entry and exit must be reliable and multiplayer-safe.
- Hiding must not destroy UI state or recreate the whole HUD repeatedly.
- Use a short, inexpensive transition if it improves readability.
- Do not hide information needed to understand an active parkour mechanic.
- Ensure rapid boundary movement does not flicker the HUD excessively.

### Tasks

- [ ] Identify which elements players actually use during initial HUD playtests.
- [ ] Define upgrade-zone presence for each player.
- [ ] Show upgrade-specific information on zone entry.
- [ ] Hide it on exit after any small debounce or transition.
- [ ] Test death, respawn, and teleportation while the contextual HUD is open.
- [ ] Test multiple players entering different zones independently.

### Acceptance criteria

- Parkour has less visual clutter than the initial HUD.
- Currency and attack information remain available when needed.
- Each player's HUD responds only to that player's zone presence.
- Context changes do not affect server-authoritative progression.

---

# Later experiment - Automatically equipped run items

## Status

Later experiment. Preserve the design intent, but do not build inventory, item rarity, drop tables, or equipment slots during the first enemy milestone.

## Design goal

Add roguelite variation without changing the player's primary objective or forcing them to stop parkour to compare items.

All items found during a run should automatically equip, improve an existing effect, or activate immediately.

## Guiding rules

- No traditional inventory-management screen.
- No dragging, comparing, selling, or manually equipping items during a run.
- Pickups should take effect quickly enough that the player can keep moving.
- The result of a pickup must be understandable through brief feedback.
- Avoid automatic replacements that make the player weaker without warning.
- Run-item effects should reset according to the eventual run-reset rules.

## Possible categories

### Weapons

Weapons change the existing one-button melee rather than adding more combat buttons.

Potential effects:

- larger attack radius
- greater damage
- shorter cooldown
- stronger knockback
- a second delayed hit
- an elemental visual with one simple mechanical effect

### Armor

Armor provides passive protection without another input.

Potential effects:

- block one enemy hit
- reduce contact damage
- reduce knockback
- grant brief protection after taking damage
- increase maximum health for the run

### Immediate temporary power-ups

These activate automatically on pickup and expire after a duration or one use.

Confirmed example directions:

- burst explosion damaging surrounding enemies
- freeze all surrounding enemies for two seconds

Other possible experiments:

- temporary coin magnet
- short movement boost
- temporary invulnerability to enemy contact
- reduced melee cooldown for several seconds

## Automatic replacement problem

If future weapons or armor occupy slots, automatic pickup must not unexpectedly replace a better item with a worse one.

Potential policies to evaluate later:

1. Every item is a strict tier upgrade.
2. Picking up the same category increases its level.
3. Effects accumulate for the current run.
4. Replacement occurs only when the new item's tier is higher.
5. There are no equipment slots; every pickup is an immediate modifier or temporary effect.

The fifth option is simplest and most aligned with uninterrupted parkour, but no policy is confirmed yet.

## Future acceptance principles

- A player never needs to stop and open a menu.
- Items do not add extra required combat buttons.
- The player receives clear feedback about what changed.
- Item effects do not make mobile controls more complicated.
- Run items do not compromise server authority.
- The system remains performant with multiple players receiving different effects.

---

# Economy and balance experiments

## Purpose

Balance should emerge through short playtests rather than theoretical precision. Centralize values and make them easy to change.

## Measurements worth recording manually

- time until the first enemy kill
- time until the first affordable upgrade
- enemies defeated per course attempt
- coins earned per minute
- average coins lost or left uncollected
- number of upgrades purchased before reaching the end
- time required to complete the course
- number and location of player deaths
- whether players wait for enemies to farm instead of doing parkour
- whether players avoid enemies because rewards are not worth the risk

## Warning signs

- Players stand safely near a spawn zone and farm instead of advancing.
- Enemy rewards are required but enemies spawn too slowly to progress.
- Movement upgrades trivialize every obstacle after one purchase.
- Combat upgrades make enemies irrelevant immediately.
- Rebirth upgrades make later runs strictly automatic rather than more expressive.
- Shared rewards cause one player to progress while another receives nothing.
- Death creates a long wait or unrecoverable currency disadvantage.

## Possible countermeasures to test only when needed

- Activate enemies based on course progression rather than only proximity.
- Limit rewards from repeatedly farming the same zone.
- Increase rewards later in the course.
- Require moving forward to reach active upgrade opportunities.
- Split one enemy reward into several contested pickups.
- Add a small guaranteed completion reward in addition to combat earnings.

Do not implement anti-farming systems until the simple loop demonstrates actual farming behavior.

---

# Reuse strategy

## Current approach

Build readable Rojo-managed ModuleScripts with explicit configuration and small public interfaces. Reuse within this repository first.

Good candidates for eventual reuse include:

- spatial spawn-zone configuration and debug visualization
- shared enemy lifecycle service
- server-validated radial melee
- dropped-pickup lifecycle and collection
- wallet currencies and progress counters
- data-driven upgrade definitions
- code-generated upgrade zones and pads
- native HUD theme/components

## Avoid premature extraction

Do not create a generic multi-game framework while the mechanics are still changing. A system becomes a candidate for copying or packaging after:

- it has survived real playtests
- its responsibilities are understandable
- its configuration is clearly separate from behavior
- it no longer depends heavily on Escape the Island-specific world paths
- reuse would remove real duplicated work

Roblox Packages may later distribute stable systems across projects. Copying a clean group of Rojo modules is acceptable before a package workflow is justified.

---

# Explicitly deferred or excluded

The following should not be included in the immediate enemy loop unless the developer explicitly changes priority:

- support or compatibility for placed respawning coins
- multiple enemy types
- enemy type registries or inheritance frameworks
- complex enemy pathfinding
- ranged aiming controls
- multiple combat buttons
- traditional inventory screens
- manual weapon or armor selection during a run
- item rarity systems
- procedural item drop tables
- polished sword models or elaborate attack animations
- detailed narrative or lore
- final island art direction
- a polished or large map
- complex UI image production
- DataStore persistence
- monetization
- sophisticated anti-farming systems
- object pooling without measured need

---

# Open design questions

These are intentionally unresolved. Use provisional behavior for the immediate milestone when possible.

## Combat

- Should enemy contact cause only damage, or eventually modest knockback?
- Should melee always hit in a full circle or favor the character's facing direction?
- Should enemies briefly telegraph contact damage?
- Should the sword remain visible or appear only during attacks?
- How should attack upgrades affect the spin presentation?

## Enemy behavior

- Should an enemy return to its spawn region or despawn when abandoned?
- Should it maintain a fixed height relative to the player, the world, or the local obstacle?
- Can enemies move through stone towers, or should simple collision avoidance eventually be added?
- Should enemy count scale with the number of active players?

## Shared rewards

- Is first-player collection fun enough to retain?
- Should the killing player eventually receive any guaranteed portion?
- Should several coins scatter so multiple players can collect part of a reward?
- How should drops remain reachable when an enemy dies over the sea?

## Run completion

- What resets when the player earns a Rebirth Point?
- Does run completion require a short confirmation or happen immediately?
- Should reaching the end heal the player before the next run?
- Do all enemies and drops reset globally, or only progression associated with that player?

## Upgrades

- Which stats are run-only?
- Which Rebirth upgrades are permanent?
- Do run upgrades reset on death, on completion, or only when leaving the server?
- Should locked pads remain visible with their requirements or stay hidden?
- How many pads can appear before a physical upgrade zone becomes hard to read?

## Failure and checkpoints

- Does falling into the sea return the player to the beginning or a checkpoint?
- Are coins lost on death?
- Are temporary items lost on death?
- Should checkpoints be tied to course sections or purchased progression?

---

# Recommended implementation sequence

Follow this order unless testing reveals a smaller prerequisite:

1. Replace stale project context in agent documentation. **Documented.**
2. Add one code-defined spawn zone and its debug visualization.
3. Spawn and clean up one placeholder floating enemy.
4. Add target selection, pursuit, and contact damage.
5. Add one-button server-validated radial melee.
6. Add exactly-once enemy death.
7. Replace legacy placed coins with shared expiring enemy drops.
8. Add the minimal always-visible native HUD.
9. Run two-player, lowest-quality, and mobile tests.
10. Tune the loop before expanding it.
11. Add code-defined finish detection and Rebirth Points.
12. Build the generic wallet and data-driven upgrade system.
13. Generate upgrade zones and pads from code.
14. Test contextual HUD visibility.
15. Only then select an automatically equipped run-item experiment.

---

# Definition of a useful playtest result

A playtest does not need to prove that the game is finished. It should answer a specific question and leave a short record.

For the immediate milestone, record:

- what was tested
- number of simulated or real players
- device/input used
- graphics quality used
- what felt fun
- what interrupted parkour
- whether enemies created pressure or annoyance
- whether melee felt responsive
- whether shared coin collection felt playful or unfair
- any performance, cleanup, or replication problems
- which provisional values should change next

Prefer one small tuning change followed by another test over implementing several later systems to compensate for an unproven loop.

