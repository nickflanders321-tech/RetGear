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

## Checking the harness itself

`selftest/` is a tiny fake add-on with planted bugs. Each one is marked `EXPECT` in `Bad.lua`.

```sh
lua5.1 tools/harness/run.lua --toc tools/harness/selftest/SelfTest.toc
```

It must fail with 3 Lua errors and 5 taint writes, each at the line marked in `Bad.lua`. Run it after changing
`wow.lua` or `drive.lua`.
