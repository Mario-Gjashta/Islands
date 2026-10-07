# Island Raiser

A cozy island builder on an endless painted sea, built with **Godot 4** (4.3+).
See [`docs/concept.md`](docs/concept.md) for the full concept.

![First prototype](docs/screenshots/prototype.png)

## Status: first prototype (the make-or-break look test)

From the concept doc, the first prototype covers:

1. Tap a hex to raise or lower its height, from seabed to peak.
2. Heights blend into one smooth island, painted by a single water and land shader.
3. Foam along the coast, plus a ghost hex under the pointer.

Also in: a seeded sea generated from noise, rise and sink tweens with a splash
ripple, pan and zoom, and a HUD with mode toggle and new-sea button.

## Running

Open the folder in Godot 4.3+ and press **F5**, or:

```sh
godot --path .
```

| Input | Action |
| --- | --- |
| Tap / left-click | Raise the hex one layer (or lower it in Lower mode) |
| Right-click | Lower the hex one layer |
| Drag, middle-drag, WASD / arrows | Pan |
| Wheel / pinch | Zoom at the pointer |
| Tab | Toggle Raise / Lower mode |
| R | New sea (new seed) |

## How it works

- **Logic on hexes** (`scripts/hex.gd`, `scripts/hex_grid.gd`): pointy-top axial
  coordinates and a hex-shaped map that stores one integer layer per cell
  (0 seabed, 1 reef, 2 shallows, 3 beach, 4 land, 5 peak).
- **Rendering without hexes** (`scripts/sea_renderer.gd`, `shaders/sea.gdshader`):
  displayed heights live in a tiny float texture, one texel per hex. The shader
  blends the two rings of hexes around each pixel with gaussian weights and a
  noise warp, so hexes melt into soft contours. It then paints by height: water
  colour by depth, caustics, coastal foam and swells, glints, sand, meadow with
  flowers and stone, plus hill shading, wet edges and paper grain. Sea level sits
  at 2.5, so beach (3) is the first layer above water.
- **Feel** (`scripts/ghost_hex.gd`, `scripts/splash.gd`): the ghost hex drops out
  when a tile lands and drifts back in; tiles rise with an overshoot tween and a
  foam ripple.

The shader's look is tuned by uniforms (`blend_falloff`, `coast_warp`, `sea_level`,
and the palette colours), which you can tweak live on the `Sea` node's material.

## Tests and screenshots

```sh
# Logic tests (headless)
godot --headless --path . -s res://tests/run_tests.gd

# Render the sample island to a PNG (needs a display, or xvfb-run on Linux)
godot --path . -s res://tests/capture_screenshot.gd -- out.png
```

## Next steps (from the concept)

- Layer rule: land rises only on shallow water, so islands grow outward.
- Tile types beyond height (reef, sandbank, lagoon, forest, rock…).
- Current flow field over the hex grid, drawn as painted streaks.
- Wind, adjacency habitats, species arrivals and the field guide.
- The boat as cursor, with placement reach; Voyage and Drift modes.
