# Changelog

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
