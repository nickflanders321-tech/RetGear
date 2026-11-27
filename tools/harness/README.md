# tools/harness: run the add-on without the game

`run.lua` loads every file in `Waypath.toc`, in order, against a fake WoW client (`wow.lua`) and logs a
character in. It then drives everything it can reach (`drive.lua`):

1. Every event the add-on listens for, with plausible arguments. That includes addon-channel messages on every
   prefix the add-on registers (empty, nonsense and very long ones), the game's load-on-demand windows loading,
   and a combat start and end.
2. Every `/wp` command. They are found in the source and the docs on each run, so a new command is covered without
   a list to update. It reads the `/wp ...` phrases in help text, `README.md` and `FEATURES.md`, plus every word
   the slash handlers compare against. A word that isn't a command just prints the help.
3. After each command, every handler on whatever is on screen, once each. That covers left, right and
   shift-clicks, mouse-over, the mouse wheel, dragging, typing in edit boxes, sliders and hyperlinks. It then
   does the same for the windows those open, and so on.
4. The add-on's hooks on the game: its windows shown and hidden, tooltips, tooltip post-calls, and hooked
   functions.
5. Per-frame updates (`OnUpdate`) and timers, run continuously between all of these at 10 fps of game time.
6. The events again (now with windows open), then logout.

It reports:

- **Lua errors:** the file and line, and what was running (which event and frame, which timer and where it was
  started, which button), plus the `/wp` command or phase it happened in.
- **Errors the add-on caught itself:** anything new in `WaypathDB.errors`, the list behind `/wp errors`.
- **Taint risks:** a write to something the game owns. That means a game global (`CreateFrame = ...`), an API table
  (`C_Timer.After = ...`) or a field on a game frame (`GameTooltip.x = ...`). It also covers `SetScript` replacing a
  handler on a game frame, where `HookScript` should be used.
- **Errors swallowed by `pcall`:** listed, but not a failure. Some are deliberate, such as trying an API that
  may not exist. Others are a feature failing silently.

It exits 1 when it finds a Lua error, a caught error or a taint write, and 0 otherwise. A full run takes about
25 seconds.

## Running it

It needs Lua 5.1. On Windows, use WSL (`sudo apt install lua5.1` in Ubuntu). Run it from the repo root:

```sh
lua5.1 tools/harness/run.lua                                 # Undead Paladin, level 1, fresh install, everything
lua5.1 tools/harness/run.lua --race Human --class MAGE --level 12
lua5.1 tools/harness/run.lua --cmd "next,plan,arcade"        # just these commands (and what they open)
lua5.1 tools/harness/run.lua --login-only                    # just load and log in (a few seconds)
lua5.1 tools/harness/run.lua --coverage /tmp/cov.txt         # also: which lines never ran (slow, ~10 minutes)
```

| Option | Default | |
|---|---|---|
| `--class` | `PALADIN` | `WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID` |
| `--race` | `Scourge` | `Orc Scourge Tauren Troll Human Dwarf NightElf Gnome Skyborne` (`Undead` also works) |
| `--faction` | the race's | Needed only for Skyborne, which exist on both sides |
| `--level` | `1` | |
| `--login-only` | | Skip the drive (steps 1 to 6) |
| `--cmd LIST` | | Run only these `/wp` commands (comma-separated), with no event sweep |
| `--coverage FILE` | | Write, for each file, the share of its lines of code that ran and the line numbers that never did |
| `--seconds` | `15` | How long after login to run timers before the drive starts |
| `--sv FILE` | none (fresh install) | Saved variables to log in with |
| `--save-sv FILE` | | Write `WaypathDB` out after the run |
| `--chat` | | Print what the add-on wrote to chat |
| `--verbose` | | Tracebacks, plus the globals and widget methods the harness doesn't model |

**A second login.** `--save-sv a.lua`, then `--sv a.lua`, is the next session with the first one's data.
`--sv` also reads a real `WTF/Account/<ACCOUNT>/SavedVariables/Waypath.lua`, so you can log in with a player's
actual saved data.

**Checking a change.** Run the commands that reach the code you changed (`--cmd`), or the whole thing. A
`--coverage` run shows whether the changed lines ran at all.

## What a clean run means, and what it doesn't

A clean run means nothing the harness can reach throws a Lua error or writes to the game's things. It does
**not** mean the add-on works:

- The character is empty. Bags, quest log, gear, professions, auctions and mail are all empty, and `GetItemInfo`
  returns nothing. Code that only runs with real data isn't reached: the quest tracker, the Auction House, bags
  and mail are around 30 to 50% covered. The harness also checks that nothing crashes, not that the output is
  right.
- Positions are fake. Every map position is the middle of the map, so distances come out as 0 yd.
- Nothing is drawn, so layout bugs are invisible.
- An API the harness doesn't model answers generically: 0 for counts (`GetNum...`, `...Num...`, `...Count`,
  money and cost), false for `Is.../Can.../Has...`, nil otherwise. `--verbose` lists these. If the add-on starts
  using a new game function, add it to `wow.lua`. Either give it a real stub, or put its name in the `GENERIC` list
  if the generic answer is right. Names that are nil in the game at login (other add-ons, load-on-demand windows)
  go in the `ABSENT` list. Event arguments live in `PAYLOAD` in `drive.lua`.
- When a reported error comes from the harness answering wrongly (a `nil` where the game gives a number, an event
  missing an argument), fix `wow.lua` or `drive.lua`, not the add-on.
- The taint check sees writes made with `=` and `SetScript`. It can't see the game's own secure-code rules, so
  something it doesn't flag can still be blocked in combat.

## The bot: playing the route (`--play`)

```sh
lua5.1 tools/harness/run.lua --play                          # Undead Paladin, level 1 to 20 (a few seconds)
lua5.1 tools/harness/run.lua --play --until-level 60 --race Human --class MAGE    # the whole route (~3 minutes)
lua5.1 tools/harness/run.lua --play --verbose                # also: every quest it took, did and handed in
```

`--play` replaces the drive with a bot that levels a fresh character by doing only what Waypath+ says. It runs in a
simulated world (`world.lua`) that knows where the player is, the quest log, the quests done, XP and levels.

Each turn, the bot asks the guide for the zone (`RG.CurrentRouteEntry`), the step (`RG.NextStep`), and what to do
with each of the step's quests (`RG.StepQuestLines`). It then walks to the guide's waypoint and does what the guide
says: hand in, pick up, or work on the objectives. A step with no quests (a flight path, the hearthstone...) it
walks to and ticks, as a player would. At NPCs it goes through the real quest-dialog events, so the add-on's own
auto-accept and auto hand-in do the clicking.

The world keeps the game's rules, using the add-on's quest data (`Objectives.lua`). You have to be at the giver to
accept, near an objective to make progress, and at the finisher to hand in. Required level, earlier quests in a
chain, race and class, and a full quest log stop an accept.

It reports:

- **Guide problems** (a failure), grouped by cause:
  - a quest the guide says to pick up that the game won't give;
  - a waypoint that isn't where the objective is;
  - the guide pointing at the same thing with nothing changing;
  - a step that isn't done but has nothing left to do;
  - a step whose quests are all blocked by an earlier quest. Each of these says why that earlier quest never got
    done: it isn't in the route, it comes later in the route, the guide skipped it as grey, the guide hides it, or
    its step counted as done without it.
- **Knock-on effects:** quests blocked only because the bot had to skip something earlier. These are listed with
  `--verbose` and not counted.
- **Levels ground:** where the route ran out of quests for the character's level.

`--until-level` (default 20) and `--max-actions` (default 4000) set when it stops.

**Maps.** `sh tools/harness/maps.sh` builds `.cache/maps.lua` from the client's UiMap and UiMapAssignment tables
(wago.tools, for the build the `data/wago` branch has). It gives each map its real name and parent, so `RG.ZoneName`
and the guide's zone checks behave as in game. Map points become world positions, so distances are real yards, also
between zones, and travel between zones takes the walking time (capped at 10 minutes, standing in for flights).
Without the cache, every zone is 3,500 yards wide and unconnected.

**Class quests.** The tracker lists class quests beside the route ("Class quests: pick up now", `RG.ClassQuests`).
The bot does each one when the tracker says so and the quest is within 3 levels of its own. The world can't make a
quest harder for being above you, so this is the bot standing in for a player's judgement. It notes:

- when each class quest was listed and when it was done;
- which ones the tracker called "pick up now" 4 or more levels before the quest's level.

**The zone path.** The bot records the zones it goes through, with levels (`--play-dump FILE` writes the path and
the class quests as JSON). The report counts how often it goes back to a zone it had left, which shows how much the
guide mixes zones.

**Trips back.** At every quest giver the bot visits, it notes which of the route's quests that giver could hand it
right then. Coming back later, after walking away, to take one of those is listed under "Trips back": a visit the
guide could have saved (Gryan Stoutmantle's next People's Militia, offered the moment you hand in the one before).
They're listed but not counted as guide problems yet.

**Quests that start from an object or item.** The route only lists quests handed out by an NPC. Some quests start
from an object instead (a crate, a corpse, a letter) or from an item that drops. When a step's quests all wait on
one of those, the bot goes where it starts, takes it, does it and hands it in, as a player who came across it would.
`sh tools/harness/starters.sh` builds where they start (`.cache/starters.lua`, from QuestieDB: a few minutes the first
time). Without it, the bot finds them wherever it stands.

**Items and gear.** The world has bags (a backpack and four 10-slot bags), equipped gear, and the client's item
cache: as in the game, `GetItemInfo` answers a moment after an item is first asked about. Item facts come from
LibItemDB's WoW Forever tables (`items.lua`), copied out of the `data/itemdb` branch into
`tools/harness/.cache/itemdb` on the first `--play` run. Run `git fetch origin data/itemdb` if that fails; without
them the bot plays with no items.

- **Quest rewards:** there is no reward table in the repo, so a quest offers the items the class gear lists
  (`RG.CLASS_GEAR`, `RG.CLASS_GEAR_A`, every class) name as its reward. The add-on's own auto-reward picks; if it
  doesn't, the bot takes the choice `RG.Compare` scores best.
- **Quest items:** an item objective puts the items in the bags, and they go at hand-in.
- **Equipping:** after each hand-in and level-up, the bot equips whatever `RG.Compare` calls an upgrade.
- **Selling:** every 10 hand-ins (or with full bags) it visits a vendor. The add-on gets its turn first, then the
  bot sells grey items and gear that isn't an upgrade.
- **Tooltips:** item tooltips (`SetHyperlink`, `SetBagItem`, `C_TooltipInfo`) carry the item's lines, so the
  add-on's tooltip hooks and stat parsing run on real items.

Gear adds two guide problems:

- **downgrade:** an item the add-on called an upgrade made the whole outfit worse by the add-on's own scoring,
  for example a shield that takes off a two-hander;
- **flip-flop:** an item and the one it replaced are both called upgrades.

The report also gives the add-on's score for everything worn at levels 10, 20, ... (`--verbose` lists the
gear worn at the end).

What it can't judge: the world's objective counts (6 kills, 4 items) and its XP are made up, because the quest
data has neither. So the levels the bot reaches are approximate. A problem that depends on the character's level
(for example a quest gone grey) may not happen to a real player. Zone sizes are a guess, and zones aren't connected
(travel between them takes a flat 5 minutes). There are no mob drops, dungeons or Auction House, and quest rewards
are only the ones the gear lists know.

Note: the bot follows the leveling route (`RG.CurrentRouteEntry`, `RG.NextStep`...), which in game is the
"Leveling route (WIP)" setting, `routeGuide`. That setting is off by default, so its problems reach the players
who switch it on.

## Hand-written checks (`--checks`)

```sh
lua5.1 tools/harness/run.lua --checks                        # all of them (~15 seconds)
lua5.1 tools/harness/run.lua --checks --only reload          # those whose name contains "reload"
lua5.1 tools/harness/run.lua --checks --verbose              # also why each known bug fails
```

Small, exact tests in the simulated world, for what the bot can't judge. They live in `checks/*.lua`, and
`checks.lua` describes the format. Each check runs in a fresh game of its own. A check with a `reload` part runs a
second time, as a `/reload`: it uses the first run's saved data (`WaypathDB`) and the same world (quests done,
level, bags).

- `checks/tracker.lua`:
  - an accepted quest is on the tracker with its progress;
  - progress and "hand in" show on the tracker;
  - the arrow goes to the objective, then to the hand-in;
  - walking closer lowers the distance shown.
- `checks/reload.lua`:
  - hand-ticked steps, settings and quest progress survive a `/reload`;
  - an old RetGear install's data moves into `WaypathDB`, once.
- `checks/bugs.lua`: one check per bug the bot found, each marked `known` with the reason. A known bug that fails
  shows as `KNOWN`, not a failure. Once it passes, it shows as `FIXED?`: remove its `known` line, and from then on
  it guards against the bug coming back.

A check gets a `T` with:

- **Quests:** `T.accept(id)`, `T.work(id)`, `T.handIn(id)`, `T.complete(id)`.
- **The character:** `T.setLevel(n)`, `T.go({map, x, y})`.
- **Items:** `T.give(itemID)`, `T.equip(itemID)`.
- **Reading the screen:** `T.tracker()` and `T.trackerFind(pattern)` (the tracker's text), `T.arrow()` (where the
  map pin is).
- **Commands:** `T.slash("/wp ...")`.
- **Time:** `T.step(seconds)`.
- **Assertions:** `T.ok(cond, msg)`, `T.eq(got, want, msg)`.
- **The internals:** `T.RG`, `T.Wd` (the world) and `T.Inv` (bags and gear), for anything else.

The runner exits 1 when a check fails (not for known bugs).

## Checking the harness itself

`selftest/` is a tiny fake add-on with planted bugs. Each one is marked `EXPECT` in `Bad.lua`.

```sh
lua5.1 tools/harness/run.lua --toc tools/harness/selftest/SelfTest.toc
```

It must fail with 3 Lua errors and 5 taint writes, each at the line marked in `Bad.lua`. Run it after changing
`wow.lua` or `drive.lua`.
