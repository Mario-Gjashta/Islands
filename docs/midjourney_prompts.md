# Midjourney prompts for the Island Raiser asset set

## How to use these

- **Lock the style once.** Upload the painted reference (the turquoise coast
  with the gull) to Midjourney and use its URL as `--sref <url>` on every
  prompt below. That keeps all assets in one style. If you have several
  references, you can pass more than one URL to `--sref`.
- **Tileable ground textures** use `--tile`, which makes the image repeat
  seamlessly. Keep them at `--ar 1:1`.
- **Sprites** (trees, foam, clouds, birds) need a transparent background.
  Midjourney can't output transparency, so they are generated on a flat
  pure-white background and the background is removed afterwards (remove.bg,
  Photoshop "Remove background", or Midjourney's own editor).
- Upscale everything to at least 1024×1024 before export.
- Palette (measured from the references), if you want to name colours in a
  prompt: water `#3A9EB7`, turquoise shallows `#36B9B4`, sand `#EEEADB`,
  wet sand `#DFD2BB`, meadow `#91A15F`, forest `#558150`, scrub `#9D9E82`,
  cliff cream `#CCBAA6`, rock shade `#ABA391`, sky `#2D88A3`.

The shared suffix used on every prompt:

```
--sref <reference url> --tile --ar 1:1 --style raw --v 7
```

(Drop `--tile` on the sprites and the style sheet.)

Export names are the filenames the game expects, under `assets/textures/`
and `assets/sprites/`.

---

## Ground textures (top-down, flat, tileable)

### grass_meadow.png
```
seamless top-down texture of a sunlit meadow, stylized painterly concept art, flat matte gouache brushwork, soft sage green #91A15F with slightly lighter and darker patches, a few tiny pale yellow and white wildflower dots, short grass with gentle brush texture, no shadows, no lighting, even flat illumination, no perspective, no horizon, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### grass_forest.png
```
seamless top-down texture of a shaded forest floor, stylized painterly concept art, flat matte gouache brushwork, deep muted green #558150 with mossy darker patches and soft lighter mottling, hints of leaf litter, no visible trees, no shadows, no lighting, even flat illumination, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### scrub.png
```
seamless top-down texture of dry coastal scrub, stylized painterly concept art, flat matte gouache brushwork, dusty yellow-green #9D9E82 with scattered olive tufts and patches of pale dry earth showing through, sparse low bushes seen from above as small dark-green blobs, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### alpine.png
```
seamless top-down texture of an alpine meadow on a mountain plateau, stylized painterly concept art, flat matte gouache brushwork, pale yellow-green grass with scattered small grey stones and patches of bare grey-brown earth, soft and muted, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### sand.png
```
seamless top-down texture of a dry tropical beach, stylized painterly concept art, flat matte gouache brushwork, pale cream sand #EEEADB with very subtle warm and cool variation and faint soft wind ripples, no footprints, no shells, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### sand_wet.png
```
seamless top-down texture of wet sand at the waterline, stylized painterly concept art, flat matte gouache brushwork, darker warm beige #DFD2BB with soft damp mottling and faint traces of dried foam, no water, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### rock_slope.png
```
seamless top-down texture of bare mountain rock seen from directly above, stylized painterly concept art, flat matte gouache brushwork, grey-brown stone #ABA391 broken into large soft angular facets with slightly darker cracks between them, a few paler worn patches, no snow, no vegetation, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### rock_cliff.png
```
seamless texture of a sea cliff face seen straight on from the side, stylized painterly concept art, flat matte gouache brushwork, pale cream limestone #CCBAA6 with tall vertical strata and columns, soft grey-blue shading in the recesses, a few thin dark cracks, no sky, no water, no vegetation, no snow, even flat illumination, game wall texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### scree.png
```
seamless top-down texture of loose mountain scree, stylized painterly concept art, flat matte gouache brushwork, a scatter of grey and warm-grey stones of mixed sizes on grey-brown ground, soft and muted, no snow, no vegetation, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### marsh.png
```
seamless top-down texture of a coastal salt marsh, stylized painterly concept art, flat matte gouache brushwork, muted olive-green reeds and grass with small irregular pools of still teal water between them, soft mud edges, no shadows, no lighting, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

### seabed.png
```
seamless top-down texture of a shallow tropical seabed seen through clear water, stylized painterly concept art, flat matte gouache brushwork, pale sandy bottom with soft dark teal patches of rock and seagrass, gentle rippled caustic light, no fish, no surface foam, no shadows, no perspective, game terrain texture --sref <url> --tile --ar 1:1 --style raw --v 7
```

---

## Sprites (plain white background, remove it afterwards)

Generate each at `--ar 1:1`; one object per image, centred.

### tree_01.png … tree_04.png
Run this prompt four times (or use the variation buttons) and keep the four
you like best.
```
a single small tree seen from a high three-quarter angle, stylized painterly concept art, flat matte gouache brushwork, a soft rounded canopy of overlapping leaf clumps in muted greens #558150 and #91A15F with a lighter sunlit top, a short brown trunk, no ground, no shadow, no background, isolated on a plain pure white background, game sprite --sref <url> --ar 1:1 --style raw --v 7 --no shadow, ground, background
```

### tree_tall.png (optional, for hill forests)
```
a single slender conifer-like tree seen from a high three-quarter angle, stylized painterly concept art, flat matte gouache brushwork, a tall narrow canopy of soft stacked leaf clumps in muted dark green with a lighter top, a short trunk, no ground, no shadow, isolated on a plain pure white background, game sprite --sref <url> --ar 1:1 --style raw --v 7 --no shadow, ground, background
```

### foam_01.png … foam_03.png
```
a single pale sea-foam brush stroke seen from above, stylized painterly concept art, a loose curling swirl of white and very pale cyan #BFE6E3 gouache with soft broken edges and a few small detached flecks, like foam streaming past a rock, isolated on a plain pure white background, game sprite --sref <url> --ar 1:1 --style raw --v 7 --no water, rock, background
```

### cloud_01.png … cloud_03.png
```
a single fluffy cumulus cloud seen from slightly above, stylized painterly concept art, flat matte gouache brushwork, soft white with pale blue-grey underside, simple rounded shapes, isolated on a plain pure white background, game sprite --sref <url> --ar 1:1 --style raw --v 7 --no sky, background
```

### bird.png
```
a single seagull in flight seen from above with wings spread, stylized painterly concept art, simple soft white silhouette with faint pale grey wing shading, isolated on a plain pure white background, game sprite --sref <url> --ar 1:1 --style raw --v 7 --no background
```

---

## Style sheet (not tileable, for reference only)

### style_sheet.png
```
a game art style sheet on a plain light grey background: a neat grid of square material swatches, each a flat painterly gouache sample, labelled row by row: turquoise sea water #3A9EB7 with pale foam, shallow lagoon #36B9B4, cream beach sand #EEEADB, wet sand #DFD2BB, sunlit meadow grass #91A15F, dark forest floor #558150, dry coastal scrub #9D9E82, alpine meadow with stones, loose grey scree, grey-brown mountain rock, pale cream cliff face with vertical strata, salt marsh with pools; plus a row of small sprites: three round leafy trees, a curling foam stroke, a cumulus cloud, a seagull; consistent muted tropical palette, stylized concept art, flat lighting --sref <url> --ar 3:2 --style raw --v 7
```

---

## Checklist before handing over

- Each ground texture repeats without a visible seam (open it twice side by
  side to check).
- No baked shadows or highlights on the ground textures; the game lights them.
- Sprites have a clean transparent background with no white fringe.
- Everything exported as PNG at 1024×1024 or larger.
- Files named exactly as above, in `assets/textures/` and `assets/sprites/`.
