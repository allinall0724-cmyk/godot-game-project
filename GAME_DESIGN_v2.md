# Game Design Document v2 — Wizard Pivot

**Working Title:** TBD
**Engine:** Godot 4.x
**Graphics:** Code-only (no external image/sprite assets — primitives, particles, code-driven materials)
**Setting:** Fantasy — open terrain with hills/mountains, goblins, orcs, and dragons. Player is a wizard.

> **This supersedes GAME_DESIGN.md.** The original doc (medieval sailing/looting/PvP concept) is kept for history but is no longer the active design. Key changes: no more sailing/ship/multiple-weapon-loot — replaced with a single staff + learnable spells, set on one large landmass instead of islands. Sections below describe the new direction; anything not explicitly changed here (3D third-person camera, code-only art, PC-first) carries over from the original doc's resolved decisions.

---

## 1. Core Premise

The player is a **wizard** exploring a large, continuous open world (hills, mountains, forests) — not islands, no sailing. Combat and progression center on **spells** cast from a single staff, rather than collecting multiple weapons. Enemies include goblins and orcs as common threats, with dragons as rare, powerful encounters.

## 2. World Structure
- **One large continuous landmass** (not islands) — hills, mountains, trees, rocks, varied terrain.
- A central village/hub area (carried over from earlier builds) sits on this terrain as the player's home base.
- No water/sailing in the default experience. **Ship/boat code is kept in the project but disabled/unused** — not deleted — in case sailing returns in some form later (e.g. a lake or coastal area in a future expansion of the map).
- World persistence and shared-multiplayer-world goals from the original doc (Section 1.2/1.5 in v1) are carried over as the long-term intent, not re-litigated here.

## 3. The Player Character — Wizard
- Single character class: wizard. No armor-driven "different weapon types" system (daggers/longswords/etc. from recent builds are deprecated under this pivot — see Section 8).
- Carries **one staff**, always. The staff itself is not looted/upgraded/replaced — it's a fixed tool.
- Progression comes from **leveling up and learning/equipping spells onto the staff**, not from finding better weapons.

## 4. Spell System
- The player can equip up to **5 spells** on their staff at once, unlocked as they level up.
- Spells are still tied to **elements/themes** (fire, lightning, wind, etc.) — this carries over directly from the existing ability system already built (Fireball, Lightning Zap, Meteor, etc.), just reframed as "spells" rather than "weapon abilities."
- **Spells still cost stamina** (carried over from the existing stamina system) and have cooldowns, consistent with the skill-based combat direction already in progress.
- **Global numbered scarcity applies to spells**, the same way it applied to weapons in the original design: each spell has a fixed total cap on how many players can ever learn/hold it (e.g. "Fireball #12 of 1000"), with rarer/more powerful spells having lower caps. This requires the shared persistent world from the original design to be meaningful (same reasoning as v1 Section 1.7).
- Existing combat mechanics already built — directional attacks, charge attacks, dodge/roll, crosshair aiming — carry over and apply to staff-based combat (e.g. a charged spell cast, a directional melee staff-bonk as a basic attack, etc.). Exact mapping of "melee vs. spell" basic attack is an open question (see Section 7).

## 5. Enemies
- **Goblins and orcs**: common enemies, encountered frequently across the open world. Standard difficulty, the "fodder" tier.
- **Dragons**: rare, powerful encounters — not a common enemy type. Closer to a mini-boss/special-encounter role than something you fight constantly. Exact dragon mechanics/abilities are TBD (see Section 7).

## 6. What Carries Over Unchanged From v1
These original decisions still apply and are not being revisited by this pivot:
- Third-person camera, 3D primitive-based art style, no imported assets.
- PC-first target platform.
- One dedicated server networking model (when multiplayer is implemented).
- Stamina system, sprint, charge attacks, directional attacks, dodge/roll — all carry over as mechanics, just applied to a wizard/staff context instead of a sword/multi-weapon context.

## 7. Resolved Decisions (Pivot-Specific)
- **Basic attack stays melee**: the existing directional/charge melee system (staff used as a melee weapon — "staff bonk") remains the basic attack. Spells are the special moves equipped on top, not a replacement for basic attack.
- **Existing weapon types are removed**: the sword/dagger/longsword system built in recent sessions is deprecated entirely. The wizard only ever uses the single staff. Any reusable underlying code (item data structure, stat modifiers, scarcity/edition numbering) can be repurposed for spells, but the weapon items/scenes themselves should be removed, not just hidden.

## 8. Open Questions / To Be Decided
- **Leveling system**: how does the player actually level up — kill count, quest completion, experience points from combat? Not yet defined.
- **Spell loot vs. spell unlock**: are spells found as loot (like weapons were), or unlocked via leveling/skill points, or both?
- **Dragon design**: dragon health, attack patterns, rewards for defeating one — not yet defined beyond "rare and powerful."
- **What happens to existing armor** (helmet/chest/legs slots, passive bonuses) — does the wizard still wear armor pieces alongside the staff, or is this also being simplified/removed? Not addressed by this pivot yet.
- Exact spell cap numbers per rarity tier (mirrors the same open question from v1).

## 9. Migration Notes (For Whoever Codes This Next)
The project currently has a working build with: multiple weapon types (sword variants, dagger, longsword), armor slots (helmet/chest/legs) with passive bonuses, an element-based ability/ability-bar system, stamina, directional/charge melee attacks, dodge roll, and (per the most recent prompt) a transition away from islands/sailing toward one large terrain.

This pivot does **not** require throwing that away — most systems map over directly:
- The ability/element system → becomes the spell system (mostly a rename/reframe, not a rebuild).
- Stamina, cooldowns, directional/charge attacks, dodge → unchanged mechanically.
- Multiple weapon types/armor pieces → likely deprecated in favor of "one staff," but the underlying item/stat/scarcity-numbering code is reusable for spells instead of weapons.
- The terrain/world rework already in progress is consistent with this pivot and doesn't need to change.

Recommend the next prompt instructs Claude Code to:
1. **Remove** the sword/dagger/longsword weapon-type system and their loot/scenes entirely (per Section 7 — confirmed decision, not just deprecated/hidden).
2. **Keep** the existing directional/charge melee system, now applied to the staff as the basic attack.
3. **Rename/reframe** the element/ability system as the spell system (5 equippable spell slots, learned via leveling — exact leveling mechanic still TBD per Section 8).
4. **Leave armor as-is for now** (Section 8 — not yet decided whether the wizard keeps armor slots), so this doesn't get accidentally removed alongside the weapons.
5. Report back exactly what was removed, what was kept, and flag anything ambiguous rather than guessing.
