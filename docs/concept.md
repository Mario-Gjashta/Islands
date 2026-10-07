# Island Raiser — Concept

Oct 7, 2026 · @Mario Gjashta

## Vision

A cozy island builder on an endless painted sea: you sail a small boat and raise land from the seabed one hex tile at a time, while currents and wind carry life to the islands you shape. Dorfromantik's placement puzzle meets Waterful's living ecosystem.

**Pillars**

- **Shape the sea, watch it respond.** Every tile changes how water flows and where life settles.
- **Organic, not gridded.** Hex rules underneath, soft painted coastlines on top.
- **Discovery as reward.** Species arrive when habitats form and fill a field guide.
- **Short sessions, no pressure.** 10–20 minutes, playable any time.

## Modes

Two modes share every system; only the end condition differs.

| Mode | Tiles | Ends when | Rewards |
| --- | --- | --- | --- |
| Voyage (scored) | Limited hand; earn more by matching edges and quests | Tiles run out | Score, archipelago snapshot, unlocks |
| Drift (relaxed) | Unlimited | Never; save and leave any time | Field guide entries, unlocked tile types |

## Core loop

A session is a cycle of drawing, sailing, placing and watching the sea respond; good placements earn the tiles that keep it going.

&#91;embedded content: core loop · one session\]

In Drift mode the hand never empties, so the loop runs as long as the player wants.

## Grid and tiles

Hexagons for the rules, invisible in the art: the game thinks in hexes, the player sees soft painted islands.

- **Logic:** placement, adjacency, edge matching, scoring and the current flow field all run on a hex grid (6 neighbors).
- **Rendering:** cell heights blend into smooth contours (signed distance field), so a cluster of hexes becomes one island with a curved shore and a foam line.
- **Placement:** a faint ghost hex under the finger, fading once the tile lands.

**Height layers** build from the seabed up; land needs shallow water beneath it first.

1. Seabed
2. Reef
3. Shallows / sandbank
4. Beach
5. Land (meadow, forest, hill)
6. Peak or cliff

**Starting tile types:** reef, sandbank, beach, meadow, forest, hill, lagoon, rock. Later unlocks: volcanic rock, coral garden, freshwater spring, mangrove.

## Systems

Four simple systems make every placement matter.

| System | Rule | Effect on play |
| --- | --- | --- |
| Height | Land rises only on shallow water; islands grow outward in layers | Plan reefs first, then build up |
| Currents | Water flows around land; channels speed it up, curved coasts calm it | Calm lagoons grow seagrass and mangroves; fast channels bring fish |
| Wind | Carries seeds and birds downwind | Windward sides stay bare; leeward sides turn lush |
| Adjacency | Each habitat needs certain neighbors | Forest needs freshwater nearby; turtles need a quiet beach; seabirds need cliffs facing open sea |

Currents are a hex flow field recalculated after each placement and drawn as soft painted streaks, so the player sees the sea change.

## Life, discovery and quests

Life arrives on its own when habitats form; the player's job is to make places worth arriving at.

- **Field guide:** every plant, fish, bird and animal becomes a sticker, like Waterful's scrapbook.
- **Rare species need combinations:** flamingos need a shallow salt lagoon; dolphins need a deep channel between two islands; puffins need sea cliffs on the windward side.
- **Quests come from the sea:** "A sea turtle is looking for a nesting beach," "Seagrass is drifting west; give it calm water to root." Completing them earns tiles in Voyage mode.
- **Visible arrivals:** seeds drift along current streaks, birds fly in, fish shadows gather, so cause and effect is always on screen.

## The boat and progression

The boat is the player's presence and cursor: tiles can only be placed within reach of it, so routes matter as much as placements.

**Boat upgrades**

- Bigger hold: more tiles in hand.
- Faster hull: reach farther spots per turn.
- Diving bell: place deeper reefs.
- Lantern: night sessions with bioluminescence and night species.

**Across sessions**

- Unlock tile types and biomes (Mediterranean, tropical, temperate, arctic seas).
- A gallery of archipelagos raised, saved as painted snapshots.
- Field guide completion as the long-term goal.

## Art direction and animation

Same painted top-down watercolor as the voyage concept, with the water as the star.

- **Water:** color by depth (pale turquoise shallows to ink-blue deep), seabed visible in shallows, white foam lines at every coast, sun sparkles.
- **Land:** muted painted fills (pale stone, sand, dry grass with flower dots), darker wet edges, soft hill shading.
- **Life:** animals as silhouettes in the water and small painted stamps on land.

**Animation without frame-by-frame drawing**

| Element | Technique |
| --- | --- |
| Sea, foam, sparkles, current streaks | Shaders |
| Island rising when a tile lands | Height tween with a splash and foam ripple |
| Boat | One painted sprite: rotate, bob, sail state swaps |
| Plants growing | Scale-up tween with a sway shader |
| Birds, fish, turtles | Silhouettes moved on paths with a wobble shader |
| Seeds drifting | Particles following the flow field |

Assets are a small stamp library, AI-generated in one consistent style and cleaned by hand.

## Tech and first prototype

Godot 4, fully offline: a hex grid, a flow field and shaders. No server, no real-world data.

- **Grid:** axial hex coordinates storing height and tile type per cell.
- **Rendering:** heights baked to a texture, blended into smooth contours, painted by water and land shaders.
- **Currents:** a flow field over the hex grid, recalculated on placement.
- **World:** procedurally generated empty sea from noise; each session gets a seed.
- **Workflow:** Claude Code with a Godot MCP; Mario directs look and feel.

**First prototype (the make-or-break test)**

1. Tap a hex to raise or lower its height (seabed to land).
2. Heights blend into one smooth island, painted with water and land shaders.
3. Foam along the coast and a ghost hex under the finger.

If a few taps melting into one soft painted island feels good, the look is proven; currents, life, quests and the boat build on top.

## Relation to the voyage game and open questions

Island Raiser is the smaller, faster-to-fun project and builds the water and art tech the voyage game needs later.

|  | Island Raiser | Ocean Voyage |
| --- | --- | --- |
| Pace | 10–20 min sessions | Real time, week-long voyages |
| World | Procedural, invented | Real Mediterranean |
| Server | None | Required (time, weather, events) |
| Genre | Busier (cozy builders) | Almost empty |
| Shared | Watercolor water and land shaders, art style, stamps | Same |

**Open questions**

- [ ] Should islands persist between Voyage sessions, or is each a fresh sea?
- [ ] How many tile types at launch?
- [ ] Does the boat move freely or a set distance per turn?
- [ ] Biome order: start Mediterranean to share assets with the voyage game?
- [ ] Game name.
