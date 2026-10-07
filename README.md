# Island Raiser

A cozy island builder on an endless painted sea, built with **Godot 4** (4.3+).
See [`docs/concept.md`](docs/concept.md) for the full concept.

![First prototype](docs/screenshots/prototype.png)
![Close-up](docs/screenshots/close-up.png)

## Status: first prototype (the make-or-break look test)

From the concept doc, the first prototype covers:

1. Tap a hex to raise or lower its height, from seabed to summit.
2. Heights blend into one smooth island, painted by a single water and land shader.
3. Foam along the coast, plus a ghost hex under the pointer.

Also in: a seeded sea generated from noise, rise and sink tweens with a splash
ripple, pan and zoom, and a HUD with mode toggle and new-sea button.

## Play in the browser

Every push to `main` (or the prototype branch) is exported to the web and deployed
to GitHub Pages by `.github/workflows/pages.yml`. It's at
**https://mario-gjashta.github.io/Islands/** once Pages is enabled
(Settings → Pages → Source: **GitHub Actions**). It works on phones too: tap to
raise, drag to pan, pinch to zoom. The panel's corner shows the build (commit)
you're running. Each release gets unique file names (`tools/stamp_web_build.sh`),
so a refresh never mixes a new page with old cached game files.

## Running locally

Open the folder in Godot 4.3+ and press **F5**, or:

```sh
godot --path .
```

| Input | Action |
| --- | --- |
| Tap / left-click | Raise the hex one layer (or lower it in Lower mode) |
| Right-click | Lower the hex one layer |
| Drag, middle-drag, WASD / arrows | Pan |
| Q / E | Rotate the view |
| Wheel / pinch (trackpad or two fingers) | Zoom at the pointer |
| Tab | Toggle Raise / Lower mode |
| R | New sea (new seed) |
| Sample island button | Raise a ready-made mountain island to see every layer |

## How it works

- **Logic on hexes** (`scripts/hex.gd`, `scripts/hex_grid.gd`): pointy-top axial
  coordinates and a hex-shaped map that stores one integer layer per cell
  (0 seabed, 1 reef, 2 shallows, 3 beach, 4 meadow, 5 hills, 6 highland,
  7 mountain, 8 summit).
- **Rendering without hexes** (`scripts/sea_renderer.gd`, `shaders/`): a 3D
  scene. The camera (`scripts/camera_rig.gd`) looks steeply down when zoomed
  out and drops towards the horizon as you zoom in, so towers stand against a
  painted sky (`sky.gdshader`). It tilts up rather than clip into rock.
  Displayed heights live in a tiny float texture, one texel per hex.
  `terrain.gdshaderinc` turns it into one height field: a gaussian blend of
  nearby hexes with a noise warp (soft coastlines). High ground breaks into
  terraced cliffs, and every hex above the meadows raises a steep-walled rock
  tower, taller the higher the hex, so you get karst towers and sea stacks.
  The field is baked into a height map whenever the land changes
  (`height_bake.gdshader`), and the terrain mesh and trees read it.
- **Painting** (`sea.gdshader`): per pixel, by height and slope. Water goes from
  deep blue with dark brush-stroke waves to turquoise shallows, with seabed
  shadows, caustics, coastal foam, swells and glints. On land: white sand,
  lush greens on anything flat enough to hold soil (tower tops and ledges
  too), and grey granite on steep faces, streaked and cracked top to bottom
  with moss on the ledges.
- **Trees** (`trees.gdshader`): rounded jungle canopies, scattered as
  candidates over every hex. Each one reads the ground under it to decide
  whether it grows: scattered on meadows (layer 4), thick on hills (5) and up,
  and never on slopes too steep for soil. They grow and recede on their own as
  the land rises and sinks.
- **Feel** (`scripts/ghost_hex.gd`, `scripts/splash.gd`): the ghost hex drops out
  when a tile lands and drifts back in; tiles rise with an overshoot tween and a
  foam ripple.

The shader's look is tuned by uniforms (`blend_falloff`, `coast_warp`, `sea_level`,
and the palette colours), which you can tweak live on the `Sea` node's material.

## Tests and screenshots

```sh
# Logic tests (headless)
godot --headless --path . -s res://tests/run_tests.gd

# Web export (needs the 4.3 web export templates installed)
godot --headless --path . --export-release "Web" build/web/index.html

# Render the sample island to a PNG (needs a display, or xvfb-run on Linux)
godot --path . -s res://tests/capture_screenshot.gd -- out.png
```

## Next steps (from the concept)

- Layer rule: land rises only on shallow water, so islands grow outward.
- Tile types beyond height (reef, sandbank, lagoon, forest, rock…).
- Current flow field over the hex grid, drawn as painted streaks.
- Wind, adjacency habitats, species arrivals and the field guide.
- The boat as cursor, with placement reach; Voyage and Drift modes.
