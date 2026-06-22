# Game Design v2 — Wizard Pivot

> This document supersedes `GAME_DESIGN.md`. It records the design change made in
> the wizard pivot and what carried over. Where the two disagree, **v2 wins**.

## The change

The game is now **wizard-focused**. The player is a mage who wields **one staff**
and channels **spells** through it. The old multi-weapon fantasy (swords, daggers,
longswords with per-type feel) is gone.

## What carried over (same underlying systems, reframed)

- **Melee combat** — directional attacks (W = up swipe, S = down chop, else stab),
  charge attacks (hold to swell damage), and the dodge/roll are all **unchanged**.
  They now belong to the **staff** as its basic attack. Implementation untouched
  except the per-weapon-type tuning was dropped (one staff = one fixed feel).
- **The element/ability system became the SPELL system.** The fire / lightning /
  wind / sky abilities (Fireball, Lightning Zap, Meteor, Gust, etc.) are now
  **spells**. Same effect code (`_eff_*`), same VFX, same telegraphs. They were
  reorganised from "element + tier unlocks N moves" into a **flat spell catalog**
  (`SPELLS` in `player.gd`).
- **Armor** (helmet / chest / legs slots + passive bonuses) is **unchanged**.
- Procedural terrain, minimap, inventory UI, HUD, crosshair — unchanged.

## Spells on the staff

- The player slots up to **5 spells** onto the staff, bound to **Q / R / F / C / V**
  (`ability_1..ability_5`). Each slot has its **own** cooldown.
- `equipped_spells` (in `player.gd`) chooses which 5 from the `SPELLS` catalog are
  bound. Default loadout: Fireball, Lightning Zap, Ring of Fire, Gust, Meteor.
- **No leveling / unlock progression yet** — that is a future prompt. For now the
  loadout is simply filled in. The catalog (`SPELLS`) holds all spells so future
  progression can gate which are available.

## Enemies

- Common enemies are **goblins** (small, fast, green, weak) and **orcs** (slower,
  tankier, harder-hitting). Same `enemy.gd` / `enemy.tscn`; goblin is the base, the
  orc overrides exported stats + colors per-instance.
- They **wander until they spot the player, then chase and melee** on a cooldown.
  The player respawns at the village on death.
- **Dragons** (rare, powerful) are intended but **not built yet** — future work.

## Still TODO (future prompts)

- Spell **leveling / unlock progression** + a **loadout UI** to swap the 5 spells.
- A real **dragon** enemy (rare encounter).
- Spell sources (learn spells from loot / leveling rather than a fixed default set).

## Preserved-but-disabled (re-enable later)

- **Sailing**: the ship (`scenes/ship/ship.tscn`) and water (`scenes/world/water.tscn`)
  are preserved but not in the active scene. See those files + `main.gd` for how to
  bring sailing back.
