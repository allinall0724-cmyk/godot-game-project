# Game Design Document

**Working Title:** TBD
**Engine:** Godot 4.x
**Graphics:** Code-only (no external image/sprite assets — ColorRect, Polygon2D, Line2D, particles, `_draw()`, etc.)
**Setting:** Medieval era — sailing, raiding, castles, pirates, vikings

---

## 1. Full Vision (Long-Term)

This is the complete game concept. Not all of this is being built right now — see **Section 2: Phase 1 Scope** for what we're actually building first. Sections below are written as the north star to design toward, not a sprint backlog.

### 1.1 Core Premise
An open-world exploration and looting game set in a medieval era. The player sails between a large central hub island and an effectively endless number of surrounding islands, raiding castles, dungeons, and enemy camps (pirates, vikings, etc.) to collect loot and grow their character's power.

### 1.2 World Structure
- One large **central island** acting as the main hub (home base, NPCs, vendors, social space).
- Endless surrounding locations reachable by **sailing** — islands, castles, dungeons, camps.
- World always loads back into the same persistent map (not regenerated/lost between sessions).
- **Shared world, not solo instances**: players exist in the same persistent world and can encounter each other while playing — not a Minecraft-style setup where each player is alone in their own world by default. Encountering another player should allow **trading** or **fighting** them out in the open world.
- Eventually: thousands of unique quests and dungeons scattered across the map.

### 1.3 Exploration & Sailing
- Player controls a ship as the primary means of traversal between locations.
- Sailing should feel core to the game's identity, not just a loading screen replacement.

### 1.4 Raiding & Combat
- Castles, dungeons, and camps can be "raided" — entered, fought through, looted.
- Enemy factions include pirates and vikings (and likely castle garrisons/guards).
- Eventually: raids are designed to be done **with friends** (co-op multiplayer).

### 1.5 Open-World Player Encounters
- The world is shared and persistent — other real players can be encountered while exploring, not just friends you've grouped with.
- On encountering another player, options include **trading** (exchanging loot) or **fighting** (open-world PvP, separate from the structured Ranked Battle Mode in 1.9).
- **PvP is open by default**: any player can attack any other player while out in the world.
- **Safe zones**: major cities/hub areas (including the central hub island) are designated **no-PvP zones** — fighting is disabled there, so trading, vendors, and general socializing stay safe regardless of open-world PvP rules elsewhere.
- This is distinct from the Ranked PvP mode — open-world encounters are unstructured/optional, ranked battles are a deliberate competitive mode.

### 1.6 Loot System — 5 Rarity Tiers
Every weapon belongs to a rarity tier. Increasing a weapon's rarity grants it a **new ability** on top of everything it already has — abilities are additive, not replaced.

| Tier | Rarity Name (placeholder) | New Ability Unlocked |
|------|---------------------------|------------------------|
| 1 | Common | None (baseline weapon) |
| 2 | Uncommon | Fireball (ranged elemental attack) |
| 3 | Rare | Lightning Zap (chain/area attack) |
| 4 | Epic | Dodge (evasive burst movement) |
| 5 | Legendary | Double Jump (mobility/traversal in combat) |

*(Rarity names and exact ability assignments are placeholders — easy to reshuffle once we playtest. The point of keeping all 5 tiers defined now is to test whether 5 stacked abilities feels balanced/fun or overloaded before committing to building out content for all of them.)*

### 1.7 Global Weapon Scarcity (Numbered Editions)
- Every individual weapon — across **all 5 rarity tiers, including Common** — has a **fixed total cap** on how many of it will ever exist in the world (e.g. "Iron Sword #247 of 1000"). The cap is set ahead of time per weapon and does not increase.
- **Higher rarity tiers have lower caps.** Common weapons exist in the largest numbers; Legendary weapons are the scarcest. Exact numbers per tier are still TBD (see Section 4).
- Once a weapon's cap is reached, no more copies of it can be found/looted/created — it's permanently capped.
- This number is shown to the player on the weapon itself (e.g. in its tooltip/inspection view).
- **This requires a shared persistent world to be meaningful** — a global cap only makes sense if all players are drawing from the same pool. This is part of why Section 1.2's shared-world requirement matters structurally, not just thematically.

### 1.8 Quests & Dungeons
- Long-term goal: thousands of quests and dungeons distributed across the map.
- Dungeons are raidable, ideally with friends.

### 1.9 Multiplayer
- **Open-world presence** — players share a persistent world and can encounter each other organically (see 1.5).
- **Co-op raiding** — friends join to raid dungeons/castles together.
- **Ranked PvP mode** — separate "battle mode" where players fight other players in a competitive/ranked ladder, likely using the same loot/ability system.

---

## 2. Phase 1 Scope (What We're Actually Building First)

Goal: a small, real, playable vertical slice that proves the *core loop* is fun — sail, raid, loot, get stronger — before expanding to multiplayer or huge content volume.

### 2.1 In Scope for Phase 1
- **PC only.** No mobile or console work yet — see Section 1 for the long-term vision.
- **Minimal shared world, not full single-player isolation.** Phase 1 needs *some* form of basic networking so the world isn't purely local — even if it's bare-bones (e.g. players can see/encounter each other and a simple server tracks weapon counts). Full co-op raiding and ranked PvP are still out of scope (see 2.2) — this is just enough multiplayer plumbing to make the world feel shared and to make weapon caps meaningful.
- **One hub island** + a small handful of surrounding islands (not infinite yet).
- **Basic sailing**: a controllable boat that travels between islands.
- **One raidable dungeon or camp** with enemies and a loot drop at the end.
- **Combat**: simple melee/ranged attack with the player character.
- **Loot system, fully defined**: all 5 rarity tiers and their abilities exist as data (see table above), even if Phase 1 only actually drops Tier 1–2 weapons in practice. This lets us playtest ability feel without needing 5 tiers of content built out.
- **Global weapon numbering**: each weapon has a fixed cap and tracks/displays how many exist, even at small scale (e.g. cap of 50 instead of 1000 for early testing).
- **All graphics via code** — primitive shapes, no image assets.

### 2.2 Explicitly Out of Scope for Phase 1 (Future Phases)
- Full co-op raiding with friends (grouping, shared raid instances)
- Ranked PvP battle mode
- Thousands of quests/dungeons (start with one, expand later)
- Full open "endless" world (start with a handful of islands)
- Vikings/pirates as distinct enemy factions with unique behavior (start with one enemy type)
- Large-scale dedicated server infrastructure (Phase 1 networking can be minimal — e.g. a single simple host/server — not a scalable production backend)

### 2.3 Definition of Done for Phase 1
You can: spawn into the shared world → see/encounter another player if one is online → sail to one other island → enter and fight through one dungeon/camp → defeat enemies → receive a loot drop → see the weapon's rarity, ability, and edition number (e.g. "#12 of 50") → return to hub.

---

## 3. Resolved Decisions
- **Camera/perspective:** Third-person, behind the character. Implies **3D** (primitive meshes — capsules, boxes, simple shapes — since pure 2D doesn't support a true third-person camera). All visuals remain code-generated, just in 3D instead of 2D primitives.
- **Ability activation:** Active/button-triggered. Each unlocked ability (Fireball, Lightning Zap, Dodge, Double Jump) is bound to a player input and triggered intentionally, not automatic/passive.
- **Controls — on foot vs. on ship:** Same control scheme for both. Movement input (e.g. forward/back/strafe + look) maps the same way whether walking or sailing; the ship is functionally "the character" while sailing rather than a separate vehicle control scheme.
- **Networking model:** One dedicated server (not peer-to-peer). All players connect to the same server, which is the single source of truth for the world state and weapon caps. Simpler to reason about than host-migration/P2P, and the natural fit for a shared world with global scarcity.
- **Open-world PvP:** On by default everywhere, except designated safe zones (major cities, including the central hub) where PvP is disabled.

## 4. Open Questions / To Be Decided
- Working title for the game
- Exact rarity names (Common/Uncommon/Rare/Epic/Legendary vs. something more thematic)
- Ability input bindings (which key/button per ability)
- Ability cooldowns / resource costs (mana, stamina, cooldown timer?)
- How combat targeting works in 3D third-person (lock-on? free-aim?)
- Ship-specific feel: does "sailing" need any unique mechanic (wind, speed buildup) even with shared controls, or is it literally identical movement with a boat model instead of a legs model?
- **Networking model for Phase 1**: one server, run by you (or locally for testing) — confirmed. Still TBD: where/how is it hosted during development (your own machine vs. a cheap cloud VM)?
- **Weapon cap numbers**: rarer tiers have lower caps than common ones (confirmed) — exact numbers per tier still TBD (e.g. Common: 1000, Legendary: 25?).
- **What happens when a weapon is "lost"** (player dies and drops it, deletes it, etc.) — does its number become available again, or is it permanently retired, shrinking the effective pool?

---

## 5. Technical Notes
- **Engine:** Godot 4.x — **3D project** (third-person camera requirement rules out a pure-2D setup)
- **Language:** GDScript (default) unless C# is preferred later
- **Art pipeline:** None — all visuals built from Godot's built-in 3D primitive meshes (CapsuleMesh, BoxMesh, CylinderMesh, etc.) and procedural/code-driven materials, no imported models or textures
- **Phase 1 target platform:** PC only (Windows/Linux/Mac via Godot export). Mobile and console are long-term vision, not current scope — see Section 1.
- **Phase 1 input assumption:** Keyboard + mouse (and/or gamepad). No touch input needed yet.
- **Phase 1 networking:** One dedicated server model (confirmed) using Godot's built-in high-level multiplayer API (`MultiplayerSynchronizer`/`MultiplayerSpawner`, `ENetMultiplayerPeer`). One authoritative server instance; all players connect as clients. Hosting location (local machine vs. cloud VM) still TBD.
- **Note:** Networking is genuinely one of the harder parts of this project — worth treating "see another player and trade/fight them" as its own early milestone to validate, rather than assuming it'll fall out naturally from single-player code.
