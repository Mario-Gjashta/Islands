# Island Raiser

A cozy island builder on an endless painted sea, built with **Godot 4** (4.3+).
See [`docs/concept.md`](docs/concept.md) for the full concept.

![First prototype](docs/screenshots/prototype.png)
![Close-up](docs/screenshots/close-up.png)

## Status: a calm island builder

The full design is in the concept doc (Google Doc). The current build keeps it
simple and chill:

- **Raise land anywhere**: pick one of three land pieces (1–4 hexes, plus rock
  and spring pieces) and tap the sea. Every hex rises one level: deep sea,
  reef, sandbank, beach, lowland, upland, peak.
- **Land grows outward**: a land cell can only rise one level above its
  neighbours (rock two). Underwater you can pile up freely. Hovering explains
  any spot you can't build on.
- **Emergent terrain** settles after every piece (`scripts/terrain_rules.gd`):
  beach on open coasts and marsh on calm ones; forest in lowland near a spring
  or sheltered from the wind, scrub on windward coasts, meadow otherwise; bare
  rock on uplands facing open sea and forested hills where sheltered; peaks;
  lagoons in enclosed shallows.
- **Modes**: Voyage (24 pieces, then a summary) and Drift (endless pieces,
  free lowering, a sample island).

The boat, currents, tides, species and scoring from the design are parked for
later.

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
| Tap / click the sea | Raise the selected piece (on touch: tap to preview, tap again to place) |
| 1 / 2 / 3 or tap a card | Select a piece |
| R, right-click or Rotate | Rotate the piece |
| Lower (Drift) or Tab | Lower one cell, free |
| Drag, middle-drag, WASD / arrows | Pan |
| Q / E | Rotate the view |
| Wheel / pinch (trackpad or two fingers) | Zoom at the pointer |

## How it works

- **Logic on hexes** (`scripts/hex.gd`, `scripts/hex_grid.gd`): pointy-top axial
  coordinates and a hex-shaped map that stores one integer layer per cell
  (0 seabed, 1 reef, 2 shallows, 3 beach, 4 meadow, 5 hills, 6 highland,
  7 mountain, 8 summit).
- **Rendering without hexes** (`scripts/sea_renderer.gd`, `shaders/`): each
  cell's height and terrain (vegetation, wetness, rock) live in a tiny float
  texture. `terrain.gdshaderinc` blends nearby hexes into one smooth field with
  a two-scale coastline warp; high cells rise to off-centre summits and
  erosion carves ridges and gullies into mountains. The field is baked into a
  1024² height map whenever the land changes (`height_bake.gdshader`); the
  terrain mesh, per-pixel normals, crevice shading and trees all read it.
- **Painting and light** (`sea.gdshader`): sand with grain and ripples; grass in
  patches, tufts and blades with meadow flowers; marsh pools and spring ponds;
  faceted grey rock on steep ground. Soft wrap lighting with cool ambient
  shadows. Water runs from deep blue to turquoise shallows with seabed shapes,
  caustics and crisp foam, and reflects the sky with fresnel and sun glints.
  Anti-aliased (MSAA 4×) at full screen resolution, no fog.
- **Trees** (`trees.gdshader`): canopies of overlapping clumps shaded as one
  soft mass, with leaf-clump detail; they grow where the terrain's vegetation
  calls for them and recede when it doesn't.
- **Feel** (`scripts/ghost_hex.gd`, `scripts/splash.gd`): a ghost of the piece
  under the pointer (red where it can't go), rise tweens with foam ripples,
  and terrain that repaints softly as it settles.

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
