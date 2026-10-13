# Changelog

## v0.36.0 (every Horde race and class: questing)
- **Starting zones for every Horde race:** Orc and Troll (Valley of Trials, Durotar, then The Barrens), Tauren (Camp Narache, Mulgore, then The Barrens), Undead (Deathknell, Brill, Silverpine) and Skyborne (Zephras Isle, then Mulgore and The Barrens). Each has its own travel tips from its home city and does Ragefire Chasm and Wailing Caverns before the far-off dungeons.
- **Steps built from WoW Forever's quest data:** each step is one stop ("At Razor Hill: ..."), visiting the busiest quest hub for your level first and catching up anything that falls behind. Steps tick themselves off once all their quests are turned in, and each has a waypoint for the arrow. Undead now use these too (the Tirisfal and Silverpine steps changed).
- **Class quests for every class** on the tracker, from the quest data: Orc mages, Troll warlocks, Skyborne druids and the Forsaken paladin chain included. Click one to show its quest giver.
- **Dungeon quests for your race and class:** each dungeon lists every quest you can take for it (with waypoints), not only the hand-picked ones. New on the route: Excavation Site, City of Dalaran, Gnomeregan, Razorfen Downs, the Sunken Temple, and Riverglades (no quest data for it yet).
- **New quests nearby** only shows quests your race and class can take, and hides either/or quests once you've done the other one.
- **Nothing speaks to the wrong class or profession:** paladin-only lines show only for paladins, and ore tips are marked "Miners:".
- Quest data now includes WoW Forever's own quests and changes (QuestieDB's merged Forever export), so map pins and tick-offs work for them too.
- New `tools/audit` checks all 28 Horde race/class combinations on every change.

## v0.35.0 (DPS coach removed)
- **The DPS coach is gone:** no more fight recording, DPS tab, after-fight chat reports or "last fight" reminders. Its saved fight history is cleared on login, which also makes your saved data smaller.
- Dungeon run reports on the Group tab keep time, kills, deaths, XP per hour and loot (they no longer show DPS).

## v0.34.0 (RetGear is now Waypath+)
- **New name: Waypath+.** It's growing past Ret Paladins, so it gets a name that fits every class. The command is now `/wp` (`/waypath`; `/rg` still works).
- **Moving over keeps everything:** install the `Waypath` folder next to the old `RetGear` one and log in once. Your progress, settings, ticked steps, prices and fishing history are copied across, RetGear is switched off, and a pop-up asks you to reload. Then delete the `RetGear` folder. Key bindings need setting again (Esc > Options > Keybindings > AddOns > Waypath+), and the quest-target macro is now `WaypathTarget`.
- **Groundwork for every class, race and profession:** paladin data (stat weights, gear guide, class quests, talents, rotation) now lives in `Classes/`, Undead starting zones in `Races/`, the shared Horde route in `Routes/` and Mining/Blacksmithing in `Professions/`. Nothing changes for a Ret Paladin: the route, gear guide and steps are exactly the same.
- **Other classes no longer get paladin advice:** the DPS coach, Healing tab, healing-set swap, Blessing and Aura reminders, paladin talents and class quests only show on paladins. Other classes get the route, tracker, arrow, travel, bags, gold and professions, with item scores from a general melee guide until their own data is in.
- Item scores are named per class ("Ret score" on paladins, "Upgrade score" elsewhere), and LFG posts name your own class.

## v0.33.0 (quality of life)
- **Upgrade arrows on your bag icons:** a green arrow on anything that's a Ret upgrade you can wear now, and a small Holy icon on pieces for your healing set (level 30+). Turn off in Settings.
- **Turn-in run:** with two or more quests ready, click the "Turn-in run" line at the top of the tracker's Quests (or the "quests ready" reminder, or `/rg turnin`). The arrow goes to the nearest turn-in, then the next as you hand each one in, until they're all done.
- **Abandon grey quests:** click the grey-quests reminder (or Settings > Tools, or `/rg greys`). It lists them and asks before dropping anything.
- **Tracker size and lock:** Ctrl + mouse wheel over the tracker resizes it, Shift + mouse wheel makes it wider or narrower, and "Lock the tracker in place" in Settings stops it being dragged. Hover the tracker's title for a reminder. "Move the tracker back" also resets the size.
- **Search in Settings:** type in the box at the top right of the Settings tab to find an option.
- **Dual-spec gear swap:** when you switch to Holy, RetGear offers to equip your healing set (best piece from your bags for each slot) and remembers your Ret gear; switching back offers to put it back on. Also the Swap row on the Healing tab, Settings > Tools, and `/rg gear heal` / `/rg gear ret`. Never during combat.
- **Error catcher:** if RetGear itself hits an error, it no longer pops up a Lua error box. It's saved quietly and you get one chat note; `/rg errors` shows them in a window you can copy for a bug report. Other addons' errors are untouched.

## v0.32.0 (new arrow)
- **Redesigned waypoint arrow:** a dark disc with a gold ring, the destination's name above it, and an arrow that turns smoothly instead of snapping.
- **Color tells you where to go:** green when you're facing your target, gold when it's off to the side, red when it's behind you (with "It's behind you" underneath).
- **Distance and time:** yards to go plus how long it takes at your current speed.
- **Far targets:** when your target is in another zone, the arrow shows the fastest first step (for example the zeppelin to take); on another continent it shows the travel step instead of an arrow.
- **Arriving:** a green check mark, a glow and a chime, then the arrow fades out and clears the pin.
- A quick glow when the target changes, mouse wheel over the arrow to resize it (remembered), and a tooltip explaining the colors.

## v0.31.0 (quality-of-life sweep)
- **Key bindings** (Esc > Options > Keybindings > AddOns > RetGear): open or close the guide, pin your nearest quest objective, arrow on/off, show/hide the tracker, undo your last ticked task, sort your bags.
- **The guide window remembers** where you dragged it and which tab you had open, across reloads and logins.
- **Less chat spam:** map pins, "arrow on/off", "Arrived" and `/rg way` confirmations now flash briefly in the middle of the screen instead of filling your chat.
- **Tracker fades during combat** (35% opacity) so it doesn't cover the fight, and comes back when combat ends. Turn off in Settings.
- **Minimap button shortcuts:** Shift-click turns the arrow on or off, Ctrl-click opens Settings (click still opens the guide, right-click still hides the tracker).

## v0.30.0 (ore alerts)
- **Ore nearby alert:** when you come within about 90 yards of a spot where a vein you can mine can spawn, and it still gives Mining skill, RetGear tells you on screen ("Iron Deposit spot 60 yd to your left: check your minimap") with a ping, and the tracker shows it; click the line to pin it and follow the arrow.
- Uses WoW Forever's known vein spawn points (about 4,600 spots in 39 zones, from QuestieDB). The game doesn't let addons read the minimap's ore dots, so a spot can be empty if it was mined: Find Minerals on your minimap shows whether it's up.
- Each spot alerts once every 10 minutes, at most one alert every 20 seconds, never in combat or dungeons.
- Settings: turn it off, or include veins that no longer give skill (handy when you just want ore for smithing).
- New tool: `tools/nodes` rebuilds the spawn data; the twice-weekly update refreshes it.

## v0.29.0 (leveling efficiency + fishing alerts)
- **Route checked against WoW Forever quest data:** every zone's Horde quest levels were measured from the Forever database. Arathi Highlands moves from 30 to **33-40** (its quests are 34-42 in Forever; at 30 they were orange and red). Your ticked Arathi steps carry over.
- **New dungeon: Ruins of Lordaeron (16-22)**, right above Undercity, with its four Horde quests (The Wrath of Rath'mael, Light's Justice, The New Plague, A Frightened Request), the Unending Torment chain, entrance pin, boss tips, and its two-hander rewards (Forsaken Greataxe, Monstrous Cleaver) flagged in the gear guide.
- **Efficiency reminders** on the tracker: 3+ quests ready to turn in (hand them in before heading out), grey quests in your log (almost no XP: abandon or turn in on the way), several red quests (leave for later or group), and a low-priority nudge to log out in an inn or by your campfire for rested XP. The tracker header shows "rested" while you have rested XP. Turn off in Settings (Efficiency tips).
- **Fishing: loud bobber splash.** The game doesn't tell addons when a fish bites, so RetGear makes the bobber's own splash unmissable: while you fish, sound effects go to full and music and ambience are muted (and sound keeps playing if you tab out). Your settings come back 30 seconds after your last cast, when combat starts, or when you log out.
- **Fishing: "cast again" alert.** When a cast ends without a catch (the fish got away or the bobber timed out), you hear a ding and the screen flashes blue.
- Both fishing options are in Settings.

## v0.28.0 (travel tips)
- **Getting there:** whenever the guide sends you to another zone, RetGear works out the quickest way from where you are: your hearthstone (when it's ready), the flight paths you know, the Horde zeppelins (Undercity, Orgrimmar, Grom'gol), the Ratchet-Booty Bay boat and running across zone borders. It also reminds you to grab the flight path when you arrive.
- Shown on the tracker under your current zone's tasks and under the next dungeon once it's time to go, and on the Route tab under each zone or dungeon you're heading to.
- Turn it off in Settings (Travel tips).

## v0.27.0 (gear check)
- **My gear → Gear check:** RetGear compares every item in the gear guide (your level -15 to +8) with what you're wearing right now and lists your 8 best upgrades, biggest first: the upgrade, which of your items it replaces, where it comes from, how much better it is (Ret score and %), and whether you can use it now or at what level.
- **Dungeons with upgrades for you:** the top 5 dungeons ranked by how much they'd improve your gear, with each dungeon's upgrades and their bosses. Click one to pin the entrance on the map.
- Rings and trinkets are compared against your weaker one; two-handers count your current main and off hand together.

## v0.26.0 (paladin class quests)
- The Forsaken paladin class quest line is now part of the route, from WoW Forever beta guides:
  - **Deathknell (1-5):** A Difficult Path, Rediscovering the Light, Coming to Terms and Continue Your Training, with map pins.
  - **Bandarion Keep (10+):** your paladin hub in the Whispering Wood; come back each time you train.
  - **Wolf's Bane (20):** the class weapon chain, step by step: rescue Lumina Windsinger on Fenris Isle, collect the Enchanted Silver Ingot (Shadowfang Keep), Purified Kor Gem (Blackfathom Deeps, after Olric Frostvale's quest) and Whitestone Oak Lumber (Deadmines), have Orrt in Tarren Mill forge the Moonsilver Blade, then defeat Old Fire Eye. Shadowfang Keep and Blackfathom Deeps remind you to grab the materials.
  - **A Trusty Steed (40)** and **Justice and Retribution (60)** for your warhorse and charger.
- The tracker shows the next class-quest step for your level, and the steps tick themselves when the quests are done.
- Gear guide: Wolf's Bane (slow 3.4, +10 Strength, +9 Stamina, holy proc) is flagged at level 20, plus a Bandarion Keep tip at 10. It has no item ID in the Forever data yet, so it shows as a tip.
- Note: QuestieDB's WoW Forever data doesn't include the Horde paladin quests yet; the twice-weekly update will add map pins and IDs when it does.

## v0.25.1 (target type fix)
- Fixed: "attempt to compare local 'ctype' (a secret string value)" when targeting in combat. WoW Forever can hide your target's creature type from addons; the Exorcism alert now just stays quiet when it can't tell, instead of erroring.
- Every other target and party check (attackable, dead, exists, creature type in the DPS coach, the Seal reminder, party lists) goes through the same protection.

## v0.25.0 (secret bank-alt guide)
- **Secret guide: a bank alt in ten minutes.** Make a new Undead on your realm and log in: RetGear's tracker walks it from Deathknell to Brill, into Undercity, to the Auction House, bank and mailbox, makes the Undercity inn its home, and fills its bag slots, with the arrow pointing at each stop (auctioneer, bankers, Innkeeper Norman and the bag vendor, positioned from WoW Forever data).
- Each step ticks itself: arriving in Brill and Undercity, opening the Auction House, bank and mailbox, setting your hearthstone, and filling four bags. When it's done, the tracker switches to the shopping list for your main.
- Includes the fastest way to level it if you want to (you don't need to: level 1 can use the Auction House, bank and mail), and why to log out in the inn.
- On your main: `/rg bankalt` (or the "Secret" row at the top of Gold & AH → Bank alt) shows the steps. On the alt, "Hide this guide" puts it away and `/rg bankalt` brings it back.

## v0.24.1 (arrow switch)
- Arrow on/off switch in the tracker's header (the small arrow next to the book): gold when the waypoint arrow is on, grey when it's off. Your map pin stays; only the arrow hides. Double-clicking a quest still turns it back on.

## v0.24.0 (gear guide for every slot)
- The Gear guide grew from 32 items to about 160, covering every slot: two-hander, head, neck, shoulders, back, chest, wrists, hands, **waist** and **feet** (new), legs, rings and trinkets, levels 8-60.
- New items are picked from data, not guesswork: every item in WoW Forever that a Ret paladin can use, scored with RetGear's Ret weights (Strength, Attack Power, crit, hit, weapon DPS), keeping the upgrade path for each slot plus the best quest reward and the best dungeon drop every 5 levels.
- Only things an Undead paladin can actually get: Horde quest rewards, 5-player dungeon bosses, Horde vendors. No raid items, raid quests or PvP gear; caster pieces without melee stats are skipped.
- With "Near my level" ticked, the guide is grouped by slot and shows what's coming in your next 8 levels (up to 4 per slot), so you see the next upgrade for every slot at a glance. Untick it for the whole guide by level bracket, sorted by slot.
- My gear: each slot's "next" now prefers the biggest upgrade you can use within 3 levels, and Waist and Feet get suggestions too. The pre-raid checklist shows the best piece per slot (two rings, two trinkets).
- New tool: `tools/gear` rebuilds the list (see its README).

## v0.23.1 (open guide quests in your log)
- Route tab: when a step names a quest that's in your quest log, a line for that quest appears right under the step (with its level and "In your log" or "Ready to turn in"). Click it to open the quest in your quest log.
- Bank-alt quests on the Route tab open in your quest log when you have them (otherwise the Bank alt tab, as before).
- Gear guide: when a quest reward's quest is in your log, it says "Quest in your log" and clicking it opens the quest. Shift-click and Ctrl-click still link or preview the item.

## v0.23.0 (cleaner Route tab)
- The Route tab is reorganized into four sections:
  - **Now**: the zones and dungeons for your level, opened, showing only the steps you still have to do.
  - **Coming up**: the next 5 levels, closed until you click one.
  - **Later**: the rest of the route by level bracket (folded).
  - **Done**: everything you've finished (folded).
- Finished steps are hidden; a "+ N finished steps hidden" line shows them again. Finished zones, flight paths and dungeons move to Done.
- Dungeon quests you've turned in no longer clutter the list; quests still to get show their level and "Pick up", "In your log" or "Ready to turn in".
- Zones say "N to do" instead of a done/total count. Click any gold heading to fold or unfold it.
- The leveling pace row is shorter, and the "Near my level" box is gone from the Route tab (the sections replace it).

## v0.22.1 (sort bags)
- **Sort button** on your bags (top right of the backpack) and on your bank. `/rg sort` and `/rg sort bank` do the same.
- Uses the game's own bag sort when WoW Forever has it. Otherwise RetGear sorts for you: merges stacks, then Hearthstone, quest items, food and potions, gear, materials (ore, bars, cloth, fish), recipes, and grey junk last. Quivers and profession bags are left alone, and sorting stops if you enter combat.
- Turn the button off in Settings.

## v0.22.0 (fishing, in depth)
- New **Professions → Fishing & cooking** page (`/rg fish` or `/rg cook`):
  - Fishing and Cooking skill bars, your next Fishing rank and exactly how to get it (Journeyman at 50 and level 10; Expert book from Old Man Heming at 125 and level 20, 1g; Artisan from Nat Pagle at level 35).
  - Your zone: where fishing starts, where every fish bites, and your skill + pole + lure against it.
  - Where to fish for each skill bracket as Undead Horde: Undercity canals, your questing zones, the islands by Grom'gol, then Tanaris or Feralas.
  - Raw fish in your bags that still level Cooking (read from your Cooking window), colored like the game.
  - Fish to catch and cook: what each becomes, where it's caught, Cooking skill, Horde recipe vendors, day/night and seasonal fish (Grilled Squid's +10 Agility is flagged for Ret, Nightfin Soup for your healing set).
  - Every pole, lure and piece of fishing gear with its bonus and where to get it, and which you own.
  - Stranglethorn Fishing Extravaganza rules and prizes, fish other professions buy, and your catch history.
- New **Fishing panel** on the tracker while you hold a pole: skill and catches per point, a warning when fish get away in your zone, lure timer or "no lure", fish per hour and skill gained this session, and raw fish to cook. Turn it off in Settings.
- Reminders when your Fishing is capped and the next rank is ready, and when you're carrying 5+ raw fish that still level Cooking.
- Plan fixes from WoW Forever data: Expert Fishing needs level 20 (1g); Undead should fish the Undercity canals rather than Tirisfal's lakes.

## v0.21.3 (double-click arrow)
- Double-click a quest, new quest, route task or dungeon quest giver on the tracker to point the arrow at it; double-click it again to turn the arrow off. The line the arrow is pointing at is marked with a small arrow.
- Double-click (or right-click) the arrow itself to turn it off. Hovering the arrow explains this.
- Single clicks wait a moment so a double-click doesn't also open the quest log or tick a task.

## v0.21.2 (quests grouped by zone)
- The tracker's Quests list is grouped by zone, as in your quest log: the zone you're in first ("you're here"), then the nearest zones. Each zone shows how many quests it has and how many are ready to turn in.
- Click a zone name to fold its quests away (+ means folded); it stays folded.
- Up to 10 quests show; the rest are counted with a link to your quest log.

## v0.21.1 (talents fix)
- Fixed: the Talents tab said "open your talents once" forever. WoW Forever doesn't answer the usual "unspent talent points" call, so RetGear now tries every way it knows, and if none work it counts your points itself (one per level from 10, minus what's spent in your tree).
- The tab refreshes as soon as you spend a point or level up, and clicking the unspent-points bar opens your talent window.
- New `/rg talents check` shows how talents are being read on this client, for bug reports.

## v0.21.0 (cleaner tracker, quest levels)
- The tracker is reorganized around a **Quests** list: every quest in your log on one line with its **level** in the game's colors (grey, green, yellow, orange, red), progress and distance on the right. Ready-to-turn-in quests come first, then the nearest.
- Click a quest to open it in your quest log, right-click to show it on the map, hover for all its objectives, its zone and the turn-in.
- **New quests nearby**, the **Route** (2 tasks at a time), the next **dungeon** (only quests you still need to pick up), **Next upgrade** and **Reminders** (top 4) follow, each tidied to fewer, shorter lines.
- Click any gold section header to fold that section away; it stays folded.
- Quest levels also show on the Route tab's dungeon quests and the Group tab.

## v0.20.7 (hidden unit names fix)
- Fixed: "attempted to index a table that cannot be indexed with secret keys" (Speed.lua) when a nameplate appeared. WoW Forever can hide other units' names from addons; the quest-mob nameplate alert now skips those instead of erroring.
- The same protection now covers every other place RetGear reads another unit: your target's name in the DPS coach, party names, classes, levels and health on the Group tab and in alerts, and the combat log for the DPS coach and dungeon run reports. Anything hidden is skipped quietly.

## v0.20.6 (open quests in your quest log)
- Clicking a quest in RetGear now opens it in the game's quest log, already selected and scrolled into view: "Quests near you" on the tracker, dungeon quests on the tracker and Route tab, and quests on the Group tab. Click it again to close the log.
- Right-click still shows the quest (or its giver/turn-in) on the map. Quests not in your log yet show their quest giver on the map instead.
- On the Group tab, click still shares a quest your party is missing; right-click opens it in your log.

## v0.20.5 (undo)
- Ticked a task off on the tracker by mistake? An "Undo" line appears under the list for 10 minutes; click it to put the task back. `/rg undo` does the same any time (it remembers your last 10 ticks).
- Ticks made on the Route tab count too, and clicking a ticked task there still unticks it.

## v0.20.4 (from your first screenshot)
- Dungeons whose quests are all turned in now show "Quests done" on the Route tab, tick their steps off, and leave the tracker instead of saying "go now".
- The selected bottom tab is easy to see: it's lit up and raised, instead of fading into the window.
- Leveling pace says "times for earlier levels appear after your next level-up" instead of "?" (and `/rg pace` says "not recorded yet").
- `/rg help` no longer lists the old `/rg welcome` (it still works and opens setup).

## v0.20.3 (combat hardening)
- The DPS coach's in-combat checks (cooldowns, range, usable, mana, threat) now treat any hidden ("secret") value as "can't tell" instead of risking an error, the same protection buffs got in v0.20.2.
- Camp Benefits timer ignores a hidden expiry time instead of erroring.

## v0.20.2 (combat fix)
- Fixed: "Auras cannot be accessed when secret while tainted by 'RetGear'" in combat. WoW Forever hides buffs and debuffs from addons during combat, so RetGear no longer reads them then: Seal and Blessing of Might are read before the pull and followed through the combat log during the fight (Seal uptime still works), and the camp buff, Aura and Blessing reminders reuse the last reading from out of combat.
- Party dispel alerts can only fire out of combat on this client (debuffs are hidden in combat).
- Any refused read is now caught quietly instead of showing an error.

## v0.20.1 (quality pass)
- Fixed: after running setup with the Full guidance or Balanced preset, Ret scores could disappear from item tooltips (and the AH auto-scan setting could be misread) until the next login.
- Safer visuals: dialogs keep a solid dark background even if a client lacks the dialog texture, and map-pin markers use the raid-target star that every client has.
- /rg help lists every command, grouped by topic.
- Consistent wording in Settings ("my" / "I" throughout).
- Checked: every game function and event against Blizzard's API documentation, every internal function and setting reference, and all player-facing text for spelling (WoW names verified against Forever's own NPC, item, quest and zone names).

## v0.20.0 (group play)
- New Group tab: solo vs grouped XP/hr over your last 5 levels with a verdict, paladin duties (Aura, each party member's Blessing with a class-based suggestion and health), your quests with who in the party has them and a click to share, Find a group suggestions (dungeons at your level and Group/Elite quests) with one-click LookingForGroup posts, and dungeon run reports.
- Dungeon run reports when you leave: time, kills, deaths, XP/hr, your average DPS and share of the group's damage, and loot.
- DPS coach in groups: your share of the party's damage and DPS rank, plus a tip when you pull aggro off the tank.
- Tracker: "Bless your group" and "Turn on an Aura" in a party; "group quests in your log" while solo.
- Alerts: Purify/Cleanse when a party member has a Poison, Disease or Magic debuff you can remove; "X is dying" with Lay on Hands / Blessing of Protection.
- /rg group, /rg lfg <what>. Setup wizard has a Group helper switch. Two new Settings toggles.

## v0.19.0
- Setup wizard on first launch (and once after this update): welcome, your main and the professions you'll level, a help-level preset (Full guidance / Balanced / Minimal), automation switches, extras (healing set, DPS coach, AH protection, nearby quests) and a summary with the commands worth remembering. /rg setup or Settings runs it again.
- Professions you won't level drop out of reminders, the Camp plan and Gold tips.

## v0.18.0
- Quest objectives from QuestieDB's WoW Forever data (2,121 quests an Undead paladin can take): where every objective is, which mobs drop your quest items, and where to turn quests in.
- Tracker "Quests near you": nearest unfinished objective, nearest quest ready to turn in, and up to two new quests you can pick up nearby (level, prerequisites and class checked), each with distance. Click to pin; /rg next pins the nearest objective.
- The RetGearTarget macro, quest bar and nameplate alerts now include the mobs that drop items for "collect" quests.
- New Settings toggle: "Show new quests you can pick up nearby".

## v0.17.1
- Fixed a stray "." in front of unnumbered checklist rows (Settings and the Camp plan).

## v0.17.0
- Classic WoW look: the stone-and-gold dialog frame with a gold title banner, Character-window tabs along the bottom, tooltip-bordered rows with the quest-log highlight, classic checkboxes, red Blizzard buttons and close buttons, status-bar textures, a purple XP bar (blue while rested), classic quest-log colors, and tab/open/close sounds. The tracker, pop-ups, quest bar and welcome screen match.
- Fewer tabs (12 to 9): Professions now holds Mining & smithing plus Camp, fish & cook; Gold & AH holds Sell & prices, Gold tips and Bank alt, with sub-tabs at the top right. /rg camp, /rg gold and /rg mail still jump straight there.
- Route waypoints with WoW Forever coordinates (QuestieDB, game build 1.60.1): 74 route steps, 45 quest givers, 56 dungeon entrances and the Fishing/Cooking trainers. The arrow follows your next step automatically (never over a pin you placed); right-click a step, or click a quest giver, dungeon or trainer, to pin it. New Settings toggle: "Arrow follows your next route step".
- tools/waypoints rebuilds the waypoints from the latest QuestieDB data.

## v0.16.0 (quality pass)
- Faster: window redraws are merged (looting used to rebuild it up to a dozen times), and bag-driven work (healing set, bank-alt list, coin marks) waits for the bag burst to finish.
- Clearer tracker: reminders are ranked (urgent first: full bags, keep sitting, Blessing/Seal) and capped at 5, with a "+N more" line.
- Quieter chat: the DPS coach only reports dungeon, elite and long fights, or fights with a big fix; quest mob alerts at most every 3 minutes per mob.
- Settings grouped into Leveling and quests / Gear and combat / Professions, bags and gold / Interface. Tabs reordered so related ones sit together.
- Welcome screen updated for everything RetGear does now; README rewritten as a guide with a tab-by-tab table.
- Safer profession bars when the game hasn't reported a skill cap yet.

## v0.15.0
Speed-leveling tools inspired by RestedXP:
- Auto accept and turn in quests through gossip and quest greetings. Hold Shift to pause. Skips grey quests, quests that cost gold, and pauses itself when your quest log or bags are full.
- Smart reward picks: the best Ret upgrade, or the best vendor value when nothing is an upgrade. When a Ret upgrade and a healing-set upgrade compete, it asks you. Reward frames now also mark the healing-set pick.
- RetGearTarget macro and a quest bar, rebuilt from your quest log out of combat: click to target quest mobs, plus one-click buttons for quest items to use and items that start quests. Drag the bar anywhere.
- Quest mob alert when one's nameplate appears.
- Waypoint arrow to your map pin; /rg way x y sets a pin in your zone; right-click the arrow to clear.
- Leveling pace: time played at each level (AFK excluded), splits on the Route tab and /rg pace.
- Bag-space warning on the tracker.
- 7 new Settings toggles.

## v0.14.0
- New Camp tab for WoW Forever's camping: Camp Benefits timer, the best object to place solo (Sharpening Wheel vs Fish Bowl, computed from your stats), campfire tiers (Basic / Journeyman / Expert) and every Blacksmithing, Mining, Fishing and Cooking camp object with skill, buff, cost and blueprint source.
- Fishing and Cooking leveling plan along the Undead route (Tirisfal to Feralas), shown in the Camp tab and in each zone of the route, ticked off from your real skill levels. Skill milestones (Journeyman, Expert books, campfire blueprints, Nat Pagle) print in chat.
- Tracker reminders: make camp, keep sitting, camp buff ending, eat for Well Fed (+5% XP). Settings toggles for both.
- DPS coach: "No camp buff for this fight" tip. Leveling priority starts with making camp.
- Gold tab: new Fishing tips (Deviate Fish, Oily Blackmouth, Firefin Snapper, Stonescale Eel) with live prices. Healing tab: use the Fish Bowl when healing.
- Sources: Icy Veins, Mobalytics, wowforever.be and classicwowforever.com camping guides; wow-professions.com Forever fishing and cooking guides; Warcraft Wiki item pages.

## v0.13.0
- Bank alt support. Your paladin is saved as your main; other characters run in bank alt mode and no longer write quest progress, flight paths, fights, session stats or bank contents over your main's.
- New Bank alt tab: 9 route quests whose items can be bought and mailed (The Lost Pages, Warsong Saw Blades, Elixir of Agony, Coolant Heads Prevail, Gyro... What?, Stone Is Better than Cloth, The Green Hills of Stranglethorn, Caught!, Chasing A-Me 01), what your main already has, a shopping list for the next few levels with AH prices and total cost, and click-to-search at the AH.
- Mailbox button on the bank alt: attaches everything on the list and addresses it to your main.
- Route shows mail-able quests in their zone; the tracker reminds your main before they come up; the bank alt's tracker shows the shopping list.
- Opening the AH prices the shopping list too. Tabs now squeeze to fit on one line.
- Sources: Nightfall's Horde leveling guide purchase list (Warcraft Tavern), Warcraft Wiki and Wowhead quest/item pages. Classic-era quests; Forever changes are checked by the weekly update.

## v0.12.0
- New DPS tab: a fight-by-fight coach built from the combat log. Shows DPS, efficiency (your DPS vs. what every fix would add), a damage breakdown by ability, Seal and swing uptime, and miss/dodge/parry rates.
- Ranked tips with estimated DPS gain: Seal not up, not swinging, Judgement / Holy Strike / Exorcism / Hammer of Wrath left sitting ready (measured live, so it works with Forever's cooldowns), too many misses (get hit gear) or parries (stand behind), Blessing of Might or weapon stone missing, out of mana, deaths.
- Recurring problems across your last 10 fights, the last 30 fights saved, a chat report after each fight and a tracker line with the top fix.
- Window is a little wider to fit the new tab. Settings toggles for the coach and the chat report.

## v0.11.0
- New Healing tab for a Holy dual spec (WoW Forever unlocks dual spec at level 40): your healing set slot by slot, the next piece to hunt for each slot, and a level 40-60 list of 38 Horde-friendly healing items with boss and dungeon, including Whitesoul Helm you can make with Blacksmithing.
- Holy score on item tooltips (+Healing, Intellect, MP5, spell crit), with "in your healing set, keep it" or "+X healing set upgrade".
- Your healing set is protected: never flagged to sell on the AH, and selling a piece at a vendor offers a Buy back.
- RetGear remembers healing gear in your bank, pops up when a new piece joins your set, and reminds you to learn dual spec at 40.
- Stat reading now understands +Healing, mana per 5 and spell crit.
- Healing items are Classic-era drops (Forever loot tables are still being mapped). Sources: Icy Veins pre-raid list, Wowhead, Warcraft Wiki, Ten Ton Hammer.

## v0.10.0
- Don't-vendor guard: items in your bags worth more on the AH than at a vendor get a gold coin on their bag slot and a tooltip line, are never sold by the junk seller, and trigger a heads-up when you open a vendor. Sell one by mistake and you get a Buy back button.
- Opening the AH now also prices the tradeable items in your bags and the items from your gold tips.
- Auction House tab: an "In your bags" list with the extra gold each stack would make, plus tradeable greens that haven't been priced yet.
- New Gold tab: gold-making tips for Mining, Blacksmithing, cloth, AH tactics and Forever-only systems (Waylaid Crates, new recipes, rare drops), filtered to your level with live prices. Sources: gamsgo.com, boostroom.com, expcarry.com, Icy Veins. The weekly update keeps them current.
- New commands: /rg gold, /rg profit, /rg profit min, /rg profit ignore. New Settings toggle.

## v0.9.0
- Quest reward picker: the best reward for Ret gets a gold frame (or "Sells best" when nothing's an upgrade).
- Exorcism alert when you target Undead or Demons.
- Weapon stone reminder: tells you which sharpening stone or weightstone to use, and whether you can make it.
- XP per hour and time to level on the tracker; /rg session prints a session summary.
- Ret scores on your character screen, with your weakest slot in red.
- Talents tab: reads your talent tree and suggests the next point, using WoW Forever's Ret talents (Icy Veins, Mobalytics, Warcraft Tavern), plus a leveling priority updated for Forever (Holy Strike, Judgement no longer uses your Seal).
- Professions: a 1-300 Blacksmithing skill-up plan with Horde trainers (wow-professions.com), and smelt-or-sell advice from AH prices.
- My gear: a pre-raid checklist for levels 52-60.

## v0.8.0
- On-screen tracker: your current route step, next tasks (click to tick), dungeon quests to collect, your next gear upgrade and reminders. Drag it anywhere; collapse it with the minus button.
- Upgrade pop-up with an Equip button when better gear lands in your bags.
- Level-up banner: new spells to train, upgrades in reach and where to go next.
- Vendor helper: sells grey junk and repairs your gear automatically.
- Paladin reminders for a missing Blessing or Seal, and when to visit your trainer.
- Mining reminder that turns on Find Minerals with one click.
- Welcome screen for first-time setup, a minimap button, and a Settings tab to turn each helper on or off.

## v0.7.0
- The route syncs with your game: dungeon quests show In your log, Ready to turn in or Done.
- Reads your completed-quest history on login, so quests done before installing count too.
- Steps tick themselves when the game confirms them: flight paths, hearthstone, professions, Seal of Command and named quests.
- Each route step shows its progress (for example 4/7), and zones you've outleveled are marked done.

## v0.6.0
- Bigger text, with A- / A+ buttons to adjust it.
- Every route step has a numbered to-do list you can tick off.

## v0.5.1
- Works with the WoW Forever beta (interface 16001).

## v0.5.0
- Flight paths and travel tips on the route; remembers which flight paths you know.
