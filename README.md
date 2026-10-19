# VEILWOODS — Professional Low-Poly Survival Prototype

A browser-ready Godot 4 project foundation for the Veilwoods survival game.

## Included
- First-person 3D controller
- PC WASD + mouse controls
- Mobile virtual joystick + touch look + action buttons
- Procedural low-poly island
- Deep forest with small/large trees, bushes, berries and medicinal plants
- Cuttable trees and wood harvesting
- Town with houses, meat shop, vegetable shop, market and hospital
- Campfire with 6 upgrade levels and a protected radius
- Day/night cycle
- Skeletons and giant bull night monsters
- Loot chests with a rare Red Axe
- 50-day survival progression
- Final Emerald shrine + boss encounter
- Basic inventory/hotbar and survival stats
- Lightweight procedural geometry; no external asset dependencies
- GL Compatibility renderer for mobile/browser targets

## Run
Open this folder in Godot 4.x and press Play.

## Web
Use Godot's Web export with the GL Compatibility renderer. For a production release, enable threaded web export only when your hosting/browser requirements support it.

## Design direction
The prototype intentionally uses generated primitive meshes so the project is portable and has no missing asset references. Replace individual procedural models with optimized GLB assets later without changing the gameplay architecture.
