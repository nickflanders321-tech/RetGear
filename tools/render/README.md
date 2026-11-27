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
| `particles.py` | A model's particle emitters as one still frame (for `model.py`). |
| `camera.json` | The model frame's camera rules (field of view, framing, which calls set the camera again, lighting). Calibration changes these numbers. |
| `camfix.py` | Cards whose creature model has no body camera of its own, and the camera distance (`RG.ARCADE_CAMFIX`) at which each fits. Run after new cards are added: `run.lua --shoot tools/render/scenes/npcs.lua --out DIR`, then `camfix.py DIR/npc.json`. |
| `ui.sh`, `scenes/ui.lua`, `uidiff.py` | The screens check: the tracker in every view, its menu and every page of the main window, for a few characters, compared with the last accepted set (see "Checking the screens"). |
| `check_cards.py` | Reads a drawn card sweep and flags blank, over-zoomed, tiny and inconsistent models; writes `report.md` and contact sheets. |
| `casc.py` | Reads files from the local install by FileDataID or path. |
| `modeldata.py` | Display ID → model file and creature → display, from the `data/wago` branch (same build as the client); a humanoid NPC's hair, face, armor shapes, helmet and shoulders from the customization and item tables (wago.tools, same build, cached); creature displays the game told the add-on. Run it again after playing, to pick up newly learned creatures. |
| `fonts.py` | Character widths of every font the add-on uses, so text wraps and measures as in game. |

## Running it

```sh
python3 tools/render/modeldata.py && python3 tools/render/fonts.py     # once (and after a game update)
sh tools/render/cards.sh ~/shots/cards --models 1                       # every card with a model: draw and check
sh tools/render/cards.sh ~/shots/cards --cards "Hogger;Ragnaros"        # just these cards
lua5.1 tools/harness/run.lua --shoot tools/render/scenes/basic.lua --out ~/shots/ui && python3 tools/render/render.py ~/shots/ui
```

## Checking the screens

```sh
sh tools/render/ui.sh ~/shots/ui              # draw every screen and compare with the accepted set (~2 minutes)
sh tools/render/ui.sh ~/shots/ui --accept     # ... and accept this set, once the changes are the ones you meant
CHARS=fresh sh tools/render/ui.sh ~/shots/ui  # one character only (~10 s)
```

`scenes/ui.lua` finishes the first-time setup, then shoots the tracker in each view (`tracker-guide`, `-zone`,
`-log`, `-prof`, `-dungeon`), its view menu (`tracker-menu`) and every page of the main window (`main-route`,
`main-gear`, `main-settings`...). `ui.sh` runs it for three characters: `fresh` (level 1), `horde20` (an Orc
warrior the leveling bot plays to level 20: quests in the log, part way through the route) and `alliance12` (a
Human mage played to 12). The runs are the same every time, so any difference is a change.

`uidiff.py` then compares each shot with the accepted one (`tools/harness/.cache/ui-baseline`, git-ignored) and
writes `~/shots/ui/report/report.md`: each changed shot with the changed areas boxed in red beside the accepted
picture, and the texts that appeared or went away. A change that shows on many shots (the tracker is on every
page) is listed once, with the other shots it's in. It exits 1 when something changed.

`render.py` options: `--scale 2` (sharper), `--crop auto` (cut to what was drawn), `--crop l,b,r,t` (screen units:
UIParent is 1920 x 1080 of them, y up), `--bg FILE` (a real game screenshot behind the UI).

A scene script gets `T` with: `T.slash("/wp arcade")`, `T.step(seconds)`, `T.click(frame)`, `T.run(frame,
"OnMouseDown")`, `T.hover(frame)` (its highlight shows), `T.findText("Done")`, `T.windows()`, `T.hideAll()`,
`T.shoot(name, { marks = { { label =, frame = } } })`.

## How close it is

- Layout follows the game's rules: anchors, sizes, scale, strata, frame levels, draw layers and sublevels, and
  clipping. Text is laid out in whole pixels as the game does: the font at a whole pixel size, each letter's
  advance rounded up to a whole pixel. Checked against 2560 x 1440 screenshots (UI scale 0.64, 27 Nov 2026): the
  main window's frame, rows and buttons land on the same pixels, Marcellus text (most of the text) matches to the
  pixel, and small Cinzel labels (tabs, buttons) come out about 5-8% wider than in game. A line too long for its box that can't wrap is cut and ends in "...", as in game (and so
  does the last line kept by `SetMaxLines`).
- Quest mobs and quest givers on the tracker get their model from cMaNGOS classic-db's creature table
  (`modeldata.cmangos_creatures`, fetched into the cache once) when the client's own table and the game's answers
  don't have it. A creature only WoW Forever has (Tabitha Heartweaver) shows an empty frame offline.
- The game's own templates (UIPanelButtonTemplate and the like) only get the pieces the harness models. The
  add-on draws almost everything itself, so this rarely matters.
- Models are drawn in the first frame of their standing animation, with simple lighting. That's enough to see
  framing (what part of the creature is in the card), which is what goes wrong.
- Particles (`particles.py`: fire, smoke, water, glows) are one still frame: each emitter's steady number of
  particles, at random ages, moved by its speed, spread and gravity, colored, faded and sized by age, drawn as
  sprites facing the camera with the emitter's blending. Close to the game's look, not exact (no drag, wind,
  twinkle, spin, tails or ribbons). An empty model (an invisible creature such as Dream Fog, whose look is a
  spell) draws nothing, as in game.
- Humanoid NPCs (player-race models) get their baked skin, plus hair, beard, ears, face and eye color from the
  game's customization tables (`modeldata.customizations`). Groups no choice names show xx01, except the face
  (3202) and eye glows (none).
- Their armor (`modeldata.equipment`, from NPCModelItemSlotDisplayInfo) switches the parts it changes (sleeves,
  robe, boots, gloves, belt, tabard, cape: WoW Model Viewer's rules, a robe hiding trousers and boots, gloves the
  cuffs), and the helmet and shoulder models are drawn at their attachment points. A helmet hides what the game's
  HelmetGeosetData says (hair, beard, ears). Weapons aren't drawn: a display id has none (SetDisplayInfo shows none
  in game either).
- Creature cards the client's Creature table leaves out (most of them) use the display id the game gave the
  add-on (`WaypathDB.arcade.npcDisp` in the install's SavedVariables, read by `modeldata.learned_creatures`). The
  card scene starts with those already learned, like a player's game. A creature this PC's game hasn't been asked
  about yet has no model offline.
- **The model camera** follows what calibration against game video showed (2026-11-27, 18 collection cards, all
  matching): a model frame looks through the model's own "character info" camera (type 1 in the model file) and
  moves toward its portrait camera (type 0) as `SetPortraitZoom` goes from 0 to 1. Those cameras store a diagonal
  field of view. `SetCamDistanceScale` moves the camera back along its line. A model with no character info
  camera gets a fallback that frames it too close (Tepolar, the centaurs): `camfix.py` finds those cards and a
  camera distance (`RG.ARCADE_CAMFIX`) at which they fit. The fallback itself is tuned on one card (Tepolar).
- The add-on found that the game fixes a model's camera at the frame size it had when the camera was last set
  (Arcade.lua, `ensureModel`). `camera.json` carries that rule (`camera_fixed_at_fit_size`, `camera_resets_on`).

## Your own screen

The harness draws a 1920 x 1080 screen at UI scale 1 unless told otherwise. To match a real player's screen (for
comparing with their screenshots), give it their resolution and UI scale, and draw at that scale:

```sh
lua5.1 tools/harness/run.lua --shoot tools/render/scenes/ui.lua --out DIR --screen 2560x1440 --ui-scale 0.64
python3 tools/render/render.py DIR --scale 1.2         # 2560 x 1440 pictures, the windows at their real size
```

The game's UI is 768 units high at scale 1, so at UI scale 0.64 the screen is 1200 units high and each unit is
1440 / 1200 = 1.2 pixels: render at screen height x UI scale / 768. In game,
`/run print(GetCVar("useUiScale"), GetCVar("uiScale"), UIParent:GetEffectiveScale(), GetPhysicalScreenSize())`
prints both (the third number is the UI scale actually used: 0.64 on a 2560 x 1440 screen with the default setting).

## Calibration

Done once against a video of the collection (see above). To check again, take these screenshots in game, with the UI at its default scale:
1. The collection window on a page with a few creature cards.
2. The big card view of three of them (one humanoid, one large creature like a dragon, one small one).
3. A pack reveal after "Turn all", once it has settled.

Run the same views through the harness (`--cards "<those names>"`), draw them, and compare. Adjust `fov`,
`body_margin`, `use_display_scale` and the portrait settings in `camera.json` until the framing matches. Keep the
screenshots in `tools/harness/.cache/calibration` (they show the game: not committed).
