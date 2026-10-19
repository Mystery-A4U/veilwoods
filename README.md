# VEILWOODS — Three.js GitHub Pages Edition

## Upload
Upload the contents of this folder to a GitHub repository and enable **Settings → Pages → Deploy from branch → main → / (root)**.

No build command is required.

## Important: your `.blend` files
A browser cannot load Blender `.blend` files directly. Three.js uses web formats such as **GLB/GLTF**.

The game already contains an automatic loader for these optional files:

- `assets/trees.glb`
- `assets/bushes.glb`
- `assets/wood-logs.glb`
- `assets/body.glb`
- `assets/grass.glb`

Export your supplied Blender files to GLB, then put the resulting files in `assets/` with those exact names. The game will load them automatically.

The procedural low-poly world remains playable even before those GLBs are added.

## Your supplied source files
The original Blender sources are kept separately in `source-assets/` for reference. They are not loaded by the browser.

## Controls
PC:
- WASD = move
- Mouse = look
- Left click = axe / attack
- E = interact
- Shift = sprint

Mobile:
- Left joystick = move
- Drag right side = look
- AXE = chop / attack
- USE = interact
- RUN = sprint

## Game systems in this prototype
- First-person 3D
- Procedural island
- Deep forest
- Small + large trees
- Cuttable trees
- Berries + medicinal plants
- Town and village houses
- Meat shop / vegetable shop / market / hospital
- Loot chests
- Red Axe
- Campfire level 1–6
- Night cycle
- Skeletons + giant bull
- Day 50 shrine
- Emerald Guardian
- Emerald escape ending
- Mobile + PC browser controls

For a production version, replace procedural meshes with optimized GLB assets, add sound/animation, save data, crafting, proper collision, boss animations, and server-authoritative multiplayer.
