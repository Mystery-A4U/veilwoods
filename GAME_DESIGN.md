# VEILWOODS — Game Design Snapshot

## Core loop
Explore → gather → craft/upgrade → return to camp before night → survive → unlock deeper areas → reach Day 50 → face the Emerald Guardian → escape.

## Progression
- Starter: ordinary axe
- Exploration: loot chests and resources
- Rare loot: Red Axe
- Base progression: Campfire Lv.1–6
- Survival progression: Day 1–50
- Endgame: Emerald shrine + boss + extraction

## Production replacement points
Procedural primitives are deliberately isolated. Replace:
- `_tree()` with optimized tree GLBs
- `_building()` with modular building scenes
- `_plant()` with vegetation scenes
- `Monster.gd` visual mesh with skeleton/bull GLBs
- Campfire primitive with a hero campfire scene

Gameplay code can remain unchanged if replacement scenes preserve collision/interact interfaces.
