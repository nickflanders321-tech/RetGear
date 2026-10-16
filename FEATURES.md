# Waypath+ feature ideas

Ranked by how much they would help a player leveling in WoW Forever. Nothing here is built yet.
Standing rules: no talent advice, never hide or move protected Blizzard frames.

## 1. Make leveling faster
- **Smarter next-step engine:** one "do this now" line that weighs your quest log, nearby pick-ups, route position, travel time and rested XP, and re-plans when you wander off.
- **Quest turn-in batching:** group hand-ins and pick-ups by area so you never run past a giver twice.
- **Dungeon planner:** which dungeons are worth running at your level for quests plus drops, with the quest list, a group finder note and run timer.
- **Death and corpse run helper:** arrow to your corpse and to the nearest spirit healer, with a note about res sickness.
- **XP per hour comparison:** show your pace against the best route for your level and flag zones that are slower than your current one.

## 2. Make gear and gold decisions easy
- **Upgrade compare tooltip:** hover any item for "+N over what you wear" and a bind-on-equip warning.
- **Vendor and bag cleaner:** one click to sell grey and known-worthless items, and a "keep for Alts/Professions" list.
- **Gold tracker:** gold per hour by activity (questing, fishing, gathering) and an all-character wealth total.
- **Auction undercut helper:** suggested listing price from your scans, with a one-click post.
- **Profession leveling planner:** cheapest materials path per skill range, with a shopping list that checks your bags and bank alt.

## 3. Make it feel finished
- ~~**Step pager and search box:** flip through route steps one at a time; search quests, items and NPCs.~~ (done v0.76.0)
- ~~**Header buttons:**~~ (done v0.73.0) quick toggles for arrow, tracker and sounds in the window header.
- ~~**Report this step:**~~ (done v0.73.0) a button on every generated step that files a correction to the data pipeline.
- ~~**First-run tour:** a three-screen intro that shows the arrow, the tracker and Shift-click.~~ (done v0.74.0)
- ~~**Themes:** charcoal and mint (default), plus light and high-contrast options for readability.~~ (done v0.76.0)
- ~~**Localisation scaffolding:** move strings into a table so other languages can be added.~~ (done v0.74.0)

## 4. Make it social and shareable
- **Group quest sharing:** show which of your party's quests overlap and where to meet.
- **Route sharing:** export and import a custom route string.
- **Leveling timeline:** a shareable summary of level times and gold earned.

## 5. Quality and trust
- **In-game data check:** a /wp verify command that tests arrows and hand-ins for your zone and reports problems.
- **Alliance and Riverglades data:** play-test and fill the gaps (Alliance is beta; Riverglades has no quest data).
- **Error reporter polish:** one-click copy of errors with version and zone.
- **Performance budget:** a /wp perf readout of memory and update cost per module, with a lazy-load for unused tabs.
- **Module merge:** a shared UI kit and feature registry so each screen is a small plugin.

## 6. More depth in what you already have
- **Fishing:** fish-pool locations on the map, a sell-or-cook recommendation per catch and a Fishing Extravaganza timer.
- **Cooking and first aid:** cheapest path per skill range with arrow to trainers and vendors.
- ~~**Gathering:** a route over nodes in your zone, with herb and ore value per node.~~ (done v0.74.0)
- ~~**Travel:** best flight path, boat and portal route with the cost and the time.~~ (done v0.74.0)
