# tools/render: see the add-on without the game

The harness (`tools/harness`) runs the add-on against a fake WoW client. This folder draws what it puts on screen,
the windows, the cards and the 3D creature models, into PNG files. Claude (or anyone) can look at them and check
the look, with no video from the game.

It needs a local WoW Forever install. The game's textures, fonts and models are read from it (`casc.py`) and
cached in `tools/harness/.cache` (git-ignored). Nothing from the game is ever committed. It runs on this PC, not in
CI. Requirements (WSL Ubuntu): `lua5.1`, and `sudo apt install python3-pil python3-numpy`.

## Pieces

| File | What it does |
|---|---|
| `tools/harness/look.lua` | Inside the harness: real layout (anchors, scale, text measured with the real fonts), every visual setting, and a log of every model-frame call. Writes a scene: what is on screen, in the order the game draws it. |
| `tools/harness/shoot.lua` | `run.lua --shoot SCRIPT --out DIR`: runs a scene script, which calls `T.shoot("name")` to write `DIR/name.json`. |
| `scenes/*.lua` | Scene scripts. `basic.lua`: the tracker, main window and card window. `cards.lua`: every card through the pack reveal, the collection and the big card view. |
| `render.py` | Draws a scene (or a folder of them) to PNG: textures, texture coordinates, rotation, colors, gradients, blend modes, masks, backdrops, text with the game's fonts, shadows and outlines, and models. |
| `model.py` | Draws a creature (M2 model, its skin, textures and geosets) as a model frame shows it. `python3 tools/render/model.py DISPLAYID` draws one on its own. |
| `camera.json` | The model frame's camera rules (field of view, framing, which calls set the camera again, lighting). Calibration changes these numbers. |
| `camfix.py` | Cards whose creature model has no body camera of its own, and the camera distance (`RG.ARCADE_CAMFIX`) at which each fits. Run after new cards are added: `run.lua --shoot tools/render/scenes/npcs.lua --out DIR`, then `camfix.py DIR/npc.json`. |
| `check_cards.py` | Reads a drawn card sweep and flags blank, over-zoomed, tiny and inconsistent models; writes `report.md` and contact sheets. |
| `casc.py` | Reads files from the local install by FileDataID or path. |
| `modeldata.py` | Display ID → model file and creature → display, from the `data/wago` branch (same build as the client); a humanoid NPC's hair, face and geosets from the customization tables (wago.tools, same build, cached). |
| `fonts.py` | Character widths of every font the add-on uses, so text wraps and measures as in game. |

## Running it

```sh
python3 tools/render/modeldata.py && python3 tools/render/fonts.py     # once (and after a game update)
sh tools/render/cards.sh ~/shots/cards --models 1                       # every card with a model: draw and check
sh tools/render/cards.sh ~/shots/cards --cards "Hogger;Ragnaros"        # just these cards
lua5.1 tools/harness/run.lua --shoot tools/render/scenes/basic.lua --out ~/shots/ui && python3 tools/render/render.py ~/shots/ui
```

`render.py` options: `--scale 2` (sharper), `--crop auto` (cut to what was drawn), `--crop l,b,r,t` (screen units:
UIParent is 1920 x 1080 of them, y up), `--bg FILE` (a real game screenshot behind the UI).

A scene script gets `T` with: `T.slash("/wp arcade")`, `T.step(seconds)`, `T.click(frame)`, `T.run(frame,
"OnMouseDown")`, `T.hover(frame)` (its highlight shows), `T.findText("Done")`, `T.windows()`, `T.hideAll()`,
`T.shoot(name, { marks = { { label =, frame = } } })`.

## How close it is

- Layout follows the game's rules: anchors, sizes, scale, strata, frame levels, draw layers and sublevels, and
  clipping. Text uses the real fonts' widths, so wrapping and `GetStringWidth` match closely, though not to the
  pixel (no kerning).
- The game's own templates (UIPanelButtonTemplate and the like) only get the pieces the harness models. The
  add-on draws almost everything itself, so this rarely matters.
- Models are drawn in their bind pose, not the standing animation, with simple lighting and no particles. That's
  enough to see framing (what part of the creature is in the card), which is what goes wrong.
- Humanoid NPCs (player-race models) get their baked skin, plus hair, beard, ears, face and eye color from the
  game's customization tables (`modeldata.customizations`). Groups no choice names show xx01, except the face
  (3202) and eye glows (none). Not drawn yet: armor pieces that change the shape (robes, gloves, boots), helmets
  and weapons, and the hair a helmet hides.
- **The model camera** follows what calibration against game video showed (2026-11-27, 18 collection cards, all
  matching): a model frame looks through the model's own "character info" camera (type 1 in the model file) and
  moves toward its portrait camera (type 0) as `SetPortraitZoom` goes from 0 to 1. Those cameras store a diagonal
  field of view. `SetCamDistanceScale` moves the camera back along its line. A model with no character info
  camera gets a fallback that frames it too close (Tepolar, the centaurs): `camfix.py` finds those cards and a
  camera distance (`RG.ARCADE_CAMFIX`) at which they fit. The fallback itself is tuned on one card (Tepolar).
- The add-on found that the game fixes a model's camera at the frame size it had when the camera was last set
  (Arcade.lua, `ensureModel`). `camera.json` carries that rule (`camera_fixed_at_fit_size`, `camera_resets_on`).

## Calibration

Done once against a video of the collection (see above). To check again, take these screenshots in game, with the UI at its default scale:
1. The collection window on a page with a few creature cards.
2. The big card view of three of them (one humanoid, one large creature like a dragon, one small one).
3. A pack reveal after "Turn all", once it has settled.

Run the same views through the harness (`--cards "<those names>"`), draw them, and compare. Adjust `fov`,
`body_margin`, `use_display_scale` and the portrait settings in `camera.json` until the framing matches. Keep the
screenshots in `tools/harness/.cache/calibration` (they show the game: not committed).
