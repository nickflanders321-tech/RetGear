# Changelog

## Unreleased
- Spirit of Mograine, Blaumeux, Korth'azz and Zeliek, and Taerar, now show a visible model (the ghost/blank ones use their living look).
- Raider cards use the game's own textured people of their class (picked from the name) instead of untextured player models, which showed all white.
- Raider cards always show a character model in their class gear (race and sex picked from the name when never seen); names in Chinese, Korean and Cyrillic use fonts that have those letters.
- Blood elf and draenei Raiders now show their character model on their card (they fell back to scenery before).
- No two cards share a picture any more: Raiders, creatures and places the game can't show a model or painting for get their own drawn scenery, seeded from their name (cards, pack reveal and board).
- Raider cards and other text with non-Latin letters (Cyrillic, Chinese, Korean...) no longer show empty boxes: those strings switch to the game's own font automatically.
- Creature models are framed by creature type (head and chest for upright humanoids, the whole body for long low beasts and dragonkin) so they sit centred in the card and on the board; basic cards like Orgrimmar Grunt show the same picture on the board as on the card.
- Arena: a minion on the board now shows the same picture as its card (the creature's 3D model, the place's painting, the item's icon) instead of a guessed keyword icon. Name-based icons only match at the start of a word, so "Howler" no longer gets an owl.
- Card bonuses for playing the game (new file ArcadeRewards.lua). Coins and packs for: level milestones 10, 20, 30, 40, 45, 50, 55, 56, 57, 58 and 59 (each once per account, caught up on login); clearing a dungeon (three different bosses in one visit: a Jumbo and coins the first time, a Pack and coins on repeats, two repeats a day); finishing the last quest of a quest line (coins every time, plus a Pack for lines three quests or longer, two a day); and every gear upgrade, meaning an item level above anything that slot has worn before on that character (coins every time, plus a Pack for the first two each day). Reaching level 60 gives a present: three cards rated 105 or higher (new ones first) and 5 Packs, 5 Jumbos and 5 Super Jumbos.
- Earned packs wait in the Pack, Jumbo and Super Jumbo buttons ("free x2"). With the extra income, kills now pay 1 coin per 4 (was 1 per 20, still inside the daily cap), and release prices are 52 / 84 / 120 coins for 5 / 8 / 12 cards; the median player still lands at about 75% of the Master Set at level 60 (tools/arcade/economy.py).
- Polish: the collection window's bottom row is re-laid out so nothing overlaps or is cut off (Arena, Duel, three pack buttons with their own cost line, Sell extras, Open all). Card names in the binder are measured at full width, so long names wrap to two lines instead of ending in "...".
- Release balance for the card game (packs stay free in the beta, all three kinds). Packs will cost 25 / 38 / 54 coins for 5 / 8 / 12 cards. A 1-60 climb earns about 6,500 coins plus about 45 daily free packs and a reward Jumbo every 7th day, which lands a typical player at about 75% of the Master Set (every card, any finish) at level 60: about 70% for a light player and about 83% for a heavy one. A small "collector's luck" gives each card a 10% chance to be one you don't own yet. The Ledger has a Master Set bar, and tools/arcade/economy.py re-runs the maths.
- Packs are no longer themed by set: every card can come out of every pack. There are now three kinds: a Pack (5 cards, 1 rare or better), a Jumbo Pack (8 cards, 2 rares or better) and a Super Jumbo Pack (12 cards, 3 rares or better). Reward packs are Jumbos with a guaranteed holo or better at the end. Bigger packs count for more toward the holo/full-art guarantee. The pack screen lays out 5, 8 or 12 cards in one or two rows, and each pack type has its own colour and size.
- Map markers for quest objectives are now the gold "..." bubble the quest log uses, instead of blue discs.
- The booster pack is redrawn with proper proportions and now stands under a tinted spotlight on a floor glow with a shadow. A soft holographic band sweeps across the foil (and stays inside the pack), and a dashed tear line shows where to rip.
- The pack screen has a proper header, a double border, an info plaque with labelled rows (featured set, daily streak, guarantee) and, after the deal, a results plaque (best pull, new cards, sets, bonuses). The footer buttons are uniform, with a quiet sound link.
- Today, Trade, Ledger and Sets pages are rebuilt with stat tiles, section titles, progress bars and aligned rows instead of plain text.
- Place cards have their own painted landscape: all 376 places are painted by us (a sky for the time of day, hazy mountain layers, a lit landmark picked from the place's name such as a tower, keep, ruin arch, camp, ship, cave or volcano, and biome mood like snow, embers or spores), shown in a gold frame like the item cards. It replaces the map crops. (tools/arcade/art_places.py, Media/Arcade/Places1-4.tga, ArcadePlaces.lua)
- Pack opening: a richer booster pack (brushed foil tinted per set with gold trim, ornate title and set banners, a medallion with the set emblem, a holographic sheen that sweeps across it and a soft aura), bigger on screen. The pack screen now covers the whole collection window instead of a smaller box, and no creature model shows through before the cards are dealt.
- Arena layout: hand cards sit entirely below your hero (they no longer cover its portrait or health), your hero moved up a little, your own hero name no longer sits on top of your minions' names, the mulligan instruction is inside its panel above the cards instead of on top of them, and the End Turn / Reminder / Sound buttons are wide enough for their labels.
- Booster packs instead of wax seals: a foil wrapper (our own drawing) tinted per set with the set's emblem in the medallion, gold for reward packs, a fan of packs when you open several. Drag across the top to rip the crimped strip off, or click it three times; the strip flies away and the cards are dealt. All "seal" wording is now "pack". (tools/arcade/art_packs.py, Media/Arcade/PackBody.tga and PackTop.tga)
- Card art is now the game's own and different on every card: an NPC card shows that creature's 3D model, a place card shows a piece of its zone's world-map art (a different crop per place), items keep their own icon. Cards the game has no art for keep a drawn scene. (New ArcadeArt.lua, generated by tools/arcade/gen_art.py.)
- The opening mulligan no longer covers the bottom of your cards, and the pack screen's dark veil is solid so the collection no longer shows through.
- Mana crystals no longer overlap the deck and hand counts.
- Cards are readable: on hand, board and collection cards the full name now sits on the parchment in a size you can read (two lines if it needs them) with the effect line under it, and hand cards are larger and no longer overlap their text.
- Every card has a real game icon in the centre frame like the raider cards do: items keep their own icon, NPCs and places pick one from their name (dragon, troll, spider, city portal, mine and so on). The drawn scenery is gone.
- Pack opening screen is flat and quiet: no glow, ribbon, stars or corner ornaments, a smaller seal, and the Arena button label no longer clips.

- Side bar: less crowded. The sections under Quests (new quests, route, class quests, dungeon, upgrade, professions, reminders) now share one "+ MORE" row that lists what is in them (green when something is ready); click it to open them, "- SHOW LESS" to fold them again. Long lines no longer print over the line below (they wrap to two rows at most, or are cut with ...), and the text is a little larger and clearer.
- Removed the clickable pick-up (!) markers on the world map: they showed quests you are not yet high enough level to take.
- Pack opening, rebuilt: hold and drag (or hold a moment, or click three times) to tear the seal open, with cracks, shards and a jolt; the seal's colour comes from the seal's featured set (that set's cards turn up more often, and the seal says which); the seal shows how close your holo-or-full-art guarantee is. Cards are dealt with the best one last. Hover over a rare card and it hums; hold the mouse on any card to peek at how rare its print is; rare and better cards take longer to turn, tremble, and shake the table when they land. Each card shows NEW, NEW PRINT or what the extra copy is worth; the summary says how rare your best pull is ("about 1 in 4,782 cards"), your set progress and your seal streak. A "Show off" button puts your best pull in the chat box for you to send.
- Pack seals have their own art: wax seals with an embossed emblem for the featured set (a landmark for a place set, a creature for an NPC set, a gear slot for an item set), a laurel-and-star reward seal, a stack for "Break all" with the count on it, and a gold ribbon with your streak day on the Daily seal. All drawn for the add-on (tools/arcade/art_seals.py).
- Peel a card: hold the mouse on a face-down card and its bottom edge lifts to show the bottom of the card and a bar in its print's colour; let go to turn it.
- Our own card sounds (Media/Sounds, synthesised for the add-on): a flip sound for each rarity (common, rare, holo, full art, legendary), a hum when a rare card is under your mouse, seal chips, the tear, the deal, a personal-best fanfare, reward and pop-up chimes. A Sound button on the pack screen (shared with the Arena's) mutes them; without the sound files the game's own sounds are used.
- Show off now shows the card itself: players in your group or guild who have Waypath+ get a small pop-up with your card, its print and how rare it is (turn it off under Settings, Group play, "Show cards my friends pull and show off"); everyone else gets the text in your chat box.
- Seals: the first seal each day is the Daily seal and keeps a streak (a reward seal on every 7th day in a row); reaching a new highest rank earns a reward seal (a rare and a holo or better inside); "Break all" opens up to 10 waiting seals at once and shows the five best cards plus a count.
- Audit pass: removed the last talent advice (a Paladin level-20 route step and unused talent build data in the class and spec files; the audit tool now fails if talent data comes back), guarded the map-marker and quest-log click options before your settings load, and rounded the distances shown on the arrow.
- Click a place, follow the arrow: a single click on any location line in the Waypath+ sidebar and window (quests, hand-ins, pick-ups, steps, trainers, vendors) now sends the arrow there; click again for off. No more double-click.
- World map markers: your quest objectives and hand-ins (?) on the map you are looking at are clickable and point the arrow at them. Ctrl+click anywhere on the map to send the arrow to that spot. `/wpmap on|off|quests` controls it.
- The game's own quest log and tracker: clicking a quest also points the arrow at its next objective or hand-in (Shift, Ctrl and Alt clicks keep the game's own behaviour).

- Duel your party: a new "Duel your party" button in the Arena lobby (or /wp duel) lists everyone in your group, shows who has Waypath+ and its rank, and sends a duel invite with one click. Players answer a quick hello automatically, so you can see who can accept before you ask.

- Arena board: ending your turn with an attacker that could still swing now asks you to click End Turn again (the ready attackers blaze while it waits). The small Reminder button cycles Attackers, Everything (also playable cards and an unused hero power) and Off.
- Arena board: a painted backdrop in your class colours behind the table, class-coloured hero frames, ready attackers that breathe, a targeting ring that lights up over valid targets, hit shake, embers when a minion dies, mana crystals that pop as they fill, a low-deck warning, your opponent's clock in player duels, and optional sounds (Sound button).

- Card art: places and NPCs get richer scenery (16 detailed landmarks instead of 8 plain shapes, stars in dark skies, haze between the ridges, lit ridge crests and a grassy foreground); item cards get a rarity-coloured spotlight behind a larger icon.
- NPC cards now show a silhouette of their own creature type (beast, spider, dragon, wyrm, demon, flame, rock, giant, undead, humanoid, golem and more), bigger for bosses; item cards show an emblem of their gear slot (helm, shoulders, chest, gloves, boots, belt, legs, bracers, ring, amulet, cloak, weapons, shield, trinket) behind the icon.

- Arena balance pass (about 400k self-play games with the built-in AI): the player who goes second starts with 5 Armor besides the Lucky Coin (first-player win rate 55% to 51%); hero powers retuned (Warrior 3 armor, Hunter 2 damage plus 1 armor, Paladin and Shaman cost 3, Priest heals 3 and gains 1 armor, Rogue dagger is 1/3, Warlock takes 1); vanilla minions and keyword prices lowered, shield and destroy spells costlier, buff, heal and armor spells cheaper; about 500 individual cards nudged by up to 2 mana or a stat point. Heroes now win 48-52%.
- Arena: the opening-hand screen is tidied (cards sit on their own panel, the Keep button and message no longer overlap, the opponent's hand no longer touches their name).

## 1.2.0
- **Ranked ladder.** Every Arena duel now moves your rank. It is a chess-style Elo rating shown Valorant-style: seven tiers (Wanderer, Scout, Pathfinder, Trailblazer, Navigator, Cartographer, Waymaster), three divisions each, 100 RR per division. Beat a stronger opponent for a big gain, a weaker one for a small gain; a loss to a weaker opponent costs more. The computer opponents are rated Apprentice 800, Adept 1200 and Archmage 1600, so they can take you into the middle of the ladder and the top needs real players. Your first 5 games are placement games with bigger swings. Player duels are ranked too (each side sends its rating), but the same opponent only counts 3 times a day. The lobby shows your rank bar; the VS splash and end screen show your rank and the RR gained or lost, with promotion and demotion banners.
- **A premium Waypath Arena lobby.** Hero portraits in class colours with a showcase of your hero and its power, deck cards with your card back and a mana-curve chart, opponent cards with difficulty pips and coin rewards, one big Enter button, a records box with your win streak, and the rules tucked behind a "How to play" button.
- **VS splash** when a duel starts (both heroes slide in with names and classes) and a **new victory / defeat screen** with the Waypath logo, a pulsing glow, your win streak and a sound.
- Removed the Waypath+ quest bar (target buttons, quest-item buttons) and the WaypathTarget macro; the leftover macro is deleted from your macro list once. Quest-mob nameplate alerts stay.

## 1.1.1
- **Fix: accepting a duel did nothing** if you had never opened the Waypath Arena that session. It now works straight away, and if you have no finished Arena deck one is built for the duel. Challenges stay open for 90 seconds and both players see progress messages in chat.
- Player duels no longer refuse a deck with Raider cards: they are swapped for other cards from your collection for that duel only.
- **Player duels in the Waypath Arena.** Challenge anyone who also has Waypath+ (same realm and faction): target them and press "Challenge a player" in the Arena menu, or type `/wp duel Name`. They get an Accept/Decline box; you each play your selected Arena deck, the host's seed and first player are shared, then only moves are exchanged (every move carries a check value, so the two games can never silently differ). Mulligans, concede, a 2-minute turn clock and desync detection are in. Friendly duels: no coins, separate win/loss record. Raider cards can't be used in player duels yet.
- **Waypath branding.** Card backs now show the Waypath+ logo; the game is "Waypath Arena" and "Waypath Cards", with the logo in the headers.
- A better-looking Arena. The mulligan hand sits above your hero instead of covering it and is spaced so each card reads; the empty bar in the middle is now a plaque that shows whose turn it is; the table has inlaid lanes, a halo under each hero and plates for each side's mana and deck. Mana crystals always show (spent and future ones dimmed) and the counts are easier to read. Hand text is bigger and darker with keywords (Taunt, Charge, Battlecry and the rest) highlighted, names get more room, and cards you can't afford are dimmed with a red cost. Cards slide in from your deck, new minions drop onto the board with a flash, and attackers lunge at their target. Five card backs (Midnight, Crimson, Emerald, Azure, Gilt) to choose from in the Arena menu; the choice is used for your opponent's hand and for pack reveals.
- Faction-neutral at last: the travel planner uses the Alliance flight masters, the boats (Rut'theran, Auberdine, Menethil, Theramore) and the Deeprun Tram for Alliance characters, with Horde zeppelins kept for the Horde. The secret bank-alt guide now has an Alliance version (a new Human, Goldshire, then the Stormwind Auction House, bank, inn and bag vendor, coordinates from the Forever data). Fishing has Alliance trainers, a leveling route and vendors, mining lists the Alliance ore zones, and cooking, blacksmithing, engineering and enchanting notes no longer assume Horde vendors. Flight-path steps now tick off for every flight master of both factions.
- Fishing learns from you: anything you catch (a Sturdy Locked Chest, a crate, a clam) is added to that zone's list, so the Fishing page, the "Here:" line and the Fishing & cooking page show it from then on. `/wp fishseen` lists what you have added.
- GPS data: when the game and our data cannot say where a quest is handed in, Waypath+ now asks Questie's own database (if Questie is installed). When a target is inside a dungeon, the arrow leads to the dungeon's door on the outside map. `/wp gpscheck` lists which map and quest data your game client offers.
- Better GPS. When the arrow is blocked and has no learned path, it now leads to the game's own next leg of that quest (a door, cave mouth or stair) before the quest point. Without Shortest Path Forever installed, the arrow's tooltip and blocked hint mention it.
- Shareable walking routes: `/wp trail export` shows your learned paths as text to copy, `/wp trail import` merges pasted paths, and `Paths.lua` can ship routes inside the add-on. The trail holds up to 20,000 points.

## v1.0.12
- The 3D arrow is re-lit per pixel: crisp silhouette, rounded glassy edges, a real specular highlight and a rim light, instead of soft blurred shading. It reads as detailed instead of blurry.

## v1.0.11
- A sharper arrow: the 3D arrow is drawn at four times the detail (256 px frames, 2048 px sheet) with much lighter smoothing, so it stays crisp even at 300 percent size.
- A smoother arrow: it now turns every frame instead of about thirty times a second, easing towards its heading independent of frame rate, and blends between neighbouring frames so there are no visible steps. It keeps up with 144 Hz displays.

## v1.0.10
- Arrow size: choose it from the Settings tab (click the Arrow size row to step bigger), with `/wp arrowsize 150` (50 to 300 percent), or the mouse wheel over the arrow, which now goes up to 300 percent.
- A smoother arrow: the faceted lines are gone, so the 3D arrow is shaded smoothly and the glowing facet edges are removed. It reads cleaner at every size.

## v1.0.9
- More clickable options. Shift + right-click a quest on the tracker for a small menu: arrow to it (or to its hand-in), open it in your quest log, or skip it for ten minutes so the plan moves on. The Now line has its own menu (arrow to it, skip this stop, open the quest plan), and a quest under "New quests nearby" can be sent to the arrow or hidden with "Don't suggest this quest" (`/wp unhide` brings them back). Shift-click the arrow itself to jump to the next stop. Plain right-click and double-click work as before.

## v1.0.8
- A shorter tracker. At higher levels the tracker could fill the screen, so by default it now keeps itself short: the Fishing block shows two lines (the rest is on the Fishing page), quests show up to six lines (four while fishing) with the ones in your zone and nearest first, far-away zones fold into "+N more in your quest log", and the Now block only adds the "Great / Okay" rating line when it is a warning. Turn it off in Settings ("Keep the tracker short") for the full list.

## v1.0.7
- The arrow now follows the rest of the game's maps. Pick a quest on the world map or in your quest log and the arrow guides you to it (the turn-in if it is ready, otherwise the nearest objective). Ctrl-click the minimap and the arrow goes to that spot. Questie icons (world map and minimap) send the arrow where you Ctrl-click them, the same way they would with TomTom (Waypath+ answers for TomTom when TomTom is not installed). One switch in Settings, "Let map clicks drive the arrow".

## v1.0.6
- Quest givers the quest data does not know (new WoW Forever content, like the pilots at Steelgrill's Depot) are now picked up from the game. Waypath+ remembers where it was offered a quest when you talk to a giver (shared by all your characters) and also reads the game's own available-quest pins on your map, so those givers can show up under "New quests nearby" and in the next-stop plan.

## v1.0.5
- Waypath+ now says everywhere that it is for every class and both factions (Horde and Alliance): the add-on description, the setup wizard welcome and the README.
- The bank-alt walk-through (which goes to the Undercity Auction House) is now labelled as a Horde guide and no longer shows on Alliance characters. The fishing spots list says when its suggestions are written from the Horde side.

## v1.0.4
- Smarter quest planner. A quest that is ready to hand in is now always counted, even when only the game knows where it goes (before, the plan could send you 968 yd away while a turn-in sat 141 yd from you).
- The planner now weighs how much each task is worth: yellow and orange quests first, green next, grey last, and hand-ins ahead of pick-ups. It also adds worthwhile new quests within about 900 yd to the plan, so the next stop reflects what is actually around you.
- "New quests nearby" is now ranked by value for the distance (quest colour, chains it opens, and busy hubs with several givers), instead of just the nearest two. Grey quests no longer crowd out better ones.

## v1.0.3
- Gear guide: items with no zone listed no longer show a stray "·" separator.
- Cards: opening a pack now dims the whole collection window behind it, so the cards underneath no longer peek out around the reveal.
- The Arena: cards in your hand now show a short line of rules text you can read (hover for the full card), and your hero sits clear of the hand instead of under it.

## v1.0.2
- Fixed the Fishing & cooking page failing with an error about the Stranglethorn Fishing Extravaganza timer (and a related fishing-advice line).

## v1.0.1
- The Arena and the cards window now close the main Waypath+ window when they open, so the two no longer draw on top of each other.

## v1.0.0
- New Cards tab in the main window: play The Arena, open a pack (free in the beta) and browse your collection without remembering a command. /wp cards and /wp arena still work.

## v0.99.0
- Cards: opening a pack now closes any card window left open, so the two no longer stack on top of each other.

## v0.98.0
- Cards: a card's detail window no longer opens on top of a pack that is being opened; the free-pack button text fits.

## v0.97.0
- Cards window: the sort button label fits its button and the totals no longer crowd the tabs.

## v0.96.0
- Beta: card packs are free for now. (One switch in Arcade.lua puts the price back.)

## v0.95.0
- The cards window is easier to read: larger, brighter text for the subtitle, totals, tabs, buttons, search and page counter.

## v0.94.0
- The card collection now opens with the cards you own first (new "Owned first" sort, the default), so you do not have to page past empty slots. The Showcase button no longer overlaps the search box, and an empty showcase explains how to fill it.

## v0.93.0
- Fixed the Gear guide page failing with "attempt to call a nil value": it used a game function this client does not provide. The same fix is applied in the bag sorter.

## v0.92.0
- Clean-up of wonky spots: the search box no longer sits on top of the Route sub-tabs; the Arena's opening-hand screen no longer stacks the cards, the Keep button and the heroes on each other, and the opponent's card backs no longer cover their name; the Arena rules text has more line spacing.
- If a page of the window hits an error it now says so on the page (and in chat, with the error text) instead of leaving half-drawn rows from the previous tab. The error line in chat no longer says "Waypath+" twice.

## v0.91.0
- Right-clicking a green "turn in" quest in the sidebar now points the arrow at the hand-in, even for quests our data does not cover yet: the hand-in spot is read from the game's own quest map. If no spot is known, it says so in chat instead of doing nothing.

## v0.90.0
- Every place and NPC card now has its own picture: a little landscape (sky, sun or moon, two ridge lines and a landmark) worked out from the card itself, so no two cards look alike. NPCs keep a small portrait badge on top. The same art shows on the Arena board.
- /wp arena now reports a problem in chat instead of doing nothing if the window cannot open.

## v0.89.0
- Gear guide: a "View" row switches between the by-level list and a slot-by-slot view that shows what you wear in each slot and the best piece you could swap in.
- Gear guide: a "Source" row cycles through Dungeon, Quest, Vendor, Crafted, Rare mob and Drop so you can see only gear from one place; it also filters the "Best upgrades you can get now" block.

## v0.88.0
- Gear guide: a "Best upgrades you can get now" block at the top lists the pieces that would improve you most (a quest already in your log counts extra), then the rest of the guide follows.
- Gear guide: near your level, each slot is now sorted by how much the piece would actually improve you instead of by level, pieces you carry come first, and upgrade rows say what they replace ("replaces ..." or "fills an empty slot").
- Gear guide: new "Upgrades only" tick hides pieces you already beat or wear, keeping the ones still out of reach and the tips.

## v0.87.0
- Setup: new characters now pick their main spec ("What do you level as?") instead of Waypath+ assuming it. The choice drives stat weights, the weapon model, the Gear guide, the score name on tooltips and the paladin seal and blessing reminders (those only show for melee and tank specs).
- Spec tab: a "Your main spec" section lets you change it any time (it says "not confirmed yet" until you pick). Your 2nd spec can no longer be the same as your main. Existing characters get a one-time chat reminder to pick one.

## v0.86.1
- Quest, gear, map and profession data updated from WoW Forever's latest game data.

## v0.86.0
- Cards: "The Arena", a Hearthstone-style duel played with the cards you have found. Reach it from the cards window or with /wp arena. 30 health, a growing pool of mana crystals (up to 10), 30-card decks, a hand of 10, seven minions a side, an opening-hand swap, hero powers for all nine classes, weapons, armour, fatigue and the Lucky Coin for whoever goes second.
- Cards: every card plays by its own fixed rules, worked out from the card itself. NPCs and Raiders are minions (their creature type decides what they can do: beasts rush, undead leave deathrattles, dragonkin breathe fire, giants taunt), Items become weapons and spells, Places become area spells. Keywords: Taunt, Charge, Rush, Divine Shield, Stealth, Windfury, Lifesteal, Poisonous, Battlecry, Deathrattle, end-of-turn effects, Freeze and Silence. The print (rare, holo, full art) is cosmetic.
- Cards: a computer opponent at three levels (Apprentice, Adept, Archmage) that tries every move and looks at how the board would end up. A win pays coins (4, 8 or 14, plus 8 for your first win each day); a loss pays one.
- Cards: a deck builder with three deck slots, cost, type and name filters, a big card preview and an auto-fill. You can only use cards you own (two copies, one for Legendary and Artifact cards); a few basic cards are always available so a new collection can still make a deck.
- Art: new board, mana crystals, stat badges and minion frames (tools/arcade/art_battle.py). Rules engine in Battle.lua, screens in ArcadeBattle.lua.

## v0.85.0
- Cards: a full visual overhaul in a dark-fantasy, tabletop-RPG style. The card window is now "The Hoard", a night-sky grimoire with a slowly turning magic circle, drifting motes, gold corner trim, a title plate and text tabs (Collection, Sets, Today, Trade, Ledger).
- Cards: real trading-card frames. Name banner, art window, type line with a rarity gem, a parchment text box with the card's description, a power plate and a collector number. The frame takes the colour of the card's rarity; the four prints look different: plain, rare (soft glow), holo (a rainbow foil sweeps across, a turning rune circle, glints) and full art (radiant rays and a larger picture).
- Cards: rarity names follow the tabletop tradition: Mundane, Uncommon, Renowned, Epic, Legendary and Artifact (Raiders). Empty binder slots show a dark silhouette and the collector number.
- Cards: the pack opening starts with a wax seal you click to break; the five face-down cards are then dealt out and turned over one at a time, with a burst of light behind rare pulls. Card backs show a magic circle around a twenty-sided die.
- Cards: a larger card view with the card's name, description, set, power and the four prints; new fonts (Cinzel and Marcellus, both open source) and gold-trimmed buttons. All the artwork is drawn by tools/arcade/art.py and ships in Media/Arcade.

## v0.84.1
- Tracker: the Now line and the line after it wrap instead of being cut off at 300 pixels wide; the rating (Great, Okay, ...) sits on its own line.

## v0.84.0
- One objective for everything. The arrow, the tracker's new **Now** line, the collapsed tracker and the new **Quest plan** tab all follow the same current objective, so they never disagree. After a reload or relog the arrow goes back to it.
- Quest planner: the quests in your log (and the route's next pick-ups) are ordered into a trip. Objectives and hand-ins that are close together share one stop, hand-ins wait for their objectives, and the arrow keeps heading for a stop until another is clearly closer. The Quest plan tab shows every stop and the walking time; right-click a stop to skip it for 10 minutes.
- `/wp next` (and the "Next objective" key binding) points the arrow at the objective, and if it is already there it moves on to the next stop.
- Each objective says why it was chosen and what it needs: level, earlier quests and objectives, ticked live (`/wp why`, the Now tooltip, the plan tab).
- Quest ratings (Great, Okay, Tough, Skip, Too hard) from the quest colour, group recommendation and how many quests follow; low-value quests are listed on the plan tab.
- `/wp near` lists what is worth doing close by. `/wp goto 45 60 Name` adds goals of your own for zones with no quest data (Riverglades), `goto pin` turns your map pin into one.
- `/wp minimal` shows only the Now line. `/wp share` shares your current objective with your party and shows theirs.
- Inside a dungeon the Now line shows the dungeon quest from your log and the arrow rests.
- Play-test log (`/wp log`): arrivals and how long they took, stops you skipped, pins you set yourself, steps you skipped by hand. It is added to `/wp report`.
- Settings: "Plan the quest trip" (on) and "Share my current objective with my party" (off).

## v0.83.2
- Fix: the game could block the world map's quest pins ("SetPassThroughButtons during combat") because Waypath+ placed or cleared the map pin in combat. Pins and clears now wait until combat ends.

## v0.83.1
- Quest, gear, map and profession data updated from WoW Forever's latest game data.

## v0.83.0
- Cards, UI: a pack summary after the flips (best pull, new cards, set and goal rewards) with an "Open another" button; sparkle on holo and full-art cards; click a card for a large detail view (all four prints, set, power, showcase, duel card, link in chat, offer to group); search, sort (collection, rarity, name, power) and show (all, owned, missing, extras) controls; a showcase of up to nine favourites (right-click a card); progress for items, NPCs, places and raiders.
- Cards, features: Sets with coin rewards for finishing them; a free pack every day (up to 3 saved); a pity timer (a holo or full art at least every 7 packs); three daily goals; choose which card duels for you, with a win streak bonus; trading extras with your party; the Today and Stats screens; characters you mouse over become Raider cards; a once-a-day chat hint when you can afford a pack.

## v0.82.1
- Cards: a pack now costs 25 coins.

## v0.82.0
- Card coins rebalanced. XP now pays 1 coin per 4% of a level (was 2%), and there are new bonuses: level-ups (5 + level/5, plus 25 at every tenth level), quest turn-ins (3 + level/20), mob kills that give XP (1 coin per 20) and profession skill-ups (1 coin per 2). Quests, kills and skill-ups together pay at most 80 coins a day. A pack costs 40 coins (was 30) and a duel win pays 4. Climbing from 1 to 60 earns roughly 100 packs.

## v0.81.0
- Cards: the five creator cards are gone. The super rare set is now **Raiders**: characters you have met (your own, your group, and anyone who chats near you) as cards, shown as a 3D model of their race wearing the best raid armour of their class (Tier 3 sets). They come as holo or full art only, are saved with your collection, and the set grows as you play. Races without a known model fall back to the class icon. The old Legends cards are removed.

## v0.80.0
- Pack opening: the five cards are dealt face down. Click each one to flip it (or "Flip all"). Rare, holo, full-art and Legend cards flash and play a sound when they turn over, and the backs of holos, full arts and Legends glitter before you flip them.

## v0.79.0
- Cards: a new super rare "Legends" set (Asmongold, Madseasonshow, Leeroy Jenkins, Xaryu, Savvier). They only come as holo or full-art prints, are rarer than any other card, and have their own filter. Collections are now saved by card name so the card list can grow without mixing saves up.

## v0.78.0
- The hidden card game (`/wp arcade`) is now a collection of 1,206 world cards: 430 iconic epic and legendary items, 400 bosses and rare NPCs, and 376 zones and places. Packs hold 5 cards and every card can come as a common, a rare, a holo (shimmering) or a full-art print; the last card of a pack is always a rare or better. Pages, filters (items, NPCs, places, owned only), a pack-opening reveal, "Sell extras" for coins and duels. The first creature set was swapped for coins.

## v0.77.0
- A hidden extra for the curious: leveling XP quietly earns coins, and coins buy packs of collectible creature cards (36 original creatures in six types, from common to legendary) and fund small card duels. It is not mentioned anywhere in the add-on; `/wp arcade` opens it.

## v0.76.0
- **Step pager:** in an open Route zone, "One step at a time" shows a single unfinished step; click for the next, right-click for the previous, double-click to show all again.
- **Accent colours:** Settings > Look (or `/wp theme [mint|gold|sky|rose|violet|light]`) changes the accent. Text that uses a fixed colour code updates after /reload.
- **Fish pools:** the Fishing tab has a "Nearest pool" row and `/wp pool` guides you to the closest known pool cluster on your map.
- Flight path names now match the ones the travel planner uses (Grom'gol, Crossroads, Light's Hope, Theramore), so learned paths are recognised.
- Data check: regenerated everything from the latest QuestieDB (Oct 15). Quests, gear and professions unchanged; the 54 race/class checks pass. Riverglades still has no quest data in Forever's database.

## v0.75.1
- Polish: `/wp fp` is in the tour, the `/wp` help and the README.

## v0.75.0
- **Flight paths:** a new "Flight paths" tab beside the leveling route lists every Classic flight master for your faction (61 in the game data, with neutral ones), split into ones to learn and ones you have. Click a row and Waypath+ pins it and turns the arrow on; right-click pins without the arrow, double-click toggles the arrow. Rows are sorted by distance when you are on the same continent, and the search box filters them.
- `/wp fp` points the arrow at the nearest flight path you have not learned yet; `/wp fp list` opens the tab. A path counts as learned once you have opened any flight master's map with that character.

## v0.74.0
- **Gathering route:** `/wp node` (also /wp ore, /wp herb) points the arrow at the nearest known ore or herb spot you can still gather for skill, then the next one as you reach it (spots you just visited are skipped for ten minutes).
- **Travel time:** "Getting there" on the tracker and Route tab now ends with an estimate, for example "(about 19 min)".
- **Fishing:** every catch shows what to do with it (cook it, keep it, or sell it with its price) in the fishing feed and the catch log. The Stranglethorn Fishing Extravaganza has a countdown on the Fishing tab and the tracker (Sundays from 2 pm server time, about two hours).
- **First-run tour:** `/wp tour`, also offered by "Take the tour" on the welcome screen, is four short pages on the tracker, the arrow, the window and the extras.
- **Translations:** added `RG.L` and `RG.AddLocale` so a language can be added as a file (see LOCALES.md). Not translated yet.

## v0.73.0
- **Finishing touches.**
  - **Header switches:** four small buttons beside A-/A+ turn the arrow, tracker and sounds on and off (lit when on) and open a step report.
  - **Search the route:** a search box on the Route tab finds any zone, hub, note or step ("hearthstone", "Kharanos") and shows the matching entries, even finished or later ones.
  - **Report this step:** the header button (or `/wp report`) opens a copy box with your version, zone, position, the step you are on, its waypoint and quest IDs, ready to paste into a bug report.

## v0.72.0
- **Deeper fishing.**
  - **Catch value:** every catch is priced (your AH scan, Auctionator/TSM, or the vendor price). The fishing screen, tracker and Fishing tab show what the session is worth and gold per hour.
  - **Catch log:** the Fishing tab lists your last catches with zone, time and value, plus your all-time haul.
  - **What this water gives:** the fishing screen shows the top catches here with their chances and the one worth the most per cast; the Fishing tab lists up to 8 with price and value per catch.
  - **Worth catching:** the tracker's fishing section names the best-value fish in your zone.
  - **One-click boosts:** when your lure is missing or under a minute left, or you have no food buff, a Lure / Eat button appears beside Cast if you carry one (best lure for your skill, best cooked fish). Click to apply or eat.

## v0.71.0
- **Fishing shows your boosts.** The fishing screen has a new row of icon chips with countdowns for the lure on your pole (with its skill bonus), your food buff (Well Fed or any fishing buff) and your campfire (Camp Benefits, or "sit by the fire"/"campfire near"). A chip turns orange when it is about to run out, and "No lure" shows when your pole is bare. The tracker's fishing section lists the same food and campfire timers under the lure.

## v0.70.5
- **Right-click a quest in the tracker and the arrow follows it** (turning the arrow on if it was off). Right-click works the same on route steps, pick-ups and hand-ins. To open a ready quest in your quest log, Shift-click it.

## v0.70.4
- **A lighter, smaller tracker.** The panel is now see-through by default (50%) so you can see the world behind it; hold **Alt and scroll over it** to make it more or less see-through. Text and spacing are tighter, so it takes up less of the screen, and text has a soft shadow to stay readable.

## v0.70.3
- **One font everywhere.** Pop-ups (toasts), the setup wizard, the item source window, the error window, the tracker header and footer, the window's footer, search box and "Near my level" label, the fishing and paper-doll overlays all used the game's own gold ornate fonts. They now use Inter like the rest, with the mint accent instead of Blizzard gold.

## v0.70.2
- **Back to charcoal and mint.** The window, tracker and pop-ups use neutral charcoal greys with the mint accent again (the blue-black tint is gone). Layout and rounded corners stay.
- **Tracker text** now uses the same Inter font as the window, a touch larger, with neutral grey section labels. If the font ever shows blank lines, turn off "Modern font in the tracker" in Settings (it also switches itself off if it lays out at zero width).

## v0.70.1
- **Redesign, second pass.** Your current zone is now a large "hero" card (bigger icon and title), all cards and rows are taller with more space between them and bigger text, the header shows your character in a larger font with a thicker XP bar, section labels are quiet capitals without +/- markers, and the pace line is a plain row. The tracker has larger text, more room between lines and between sections.

## v0.70.0
- **A new look for everything.** Rounded cards and pills replace the boxed outlines; the window, tracker, pop-ups, setup wizard and source windows share one deep blue-black palette with a teal accent.
- **Route window:** the tab strip is now a rounded segmented control, section labels are small and quiet, steps use round checkboxes, and sub-tabs, buttons and status pills are rounded.
- **Tracker:** a rounded panel with a cleaner font, round tick circles, quieter uppercase section labels, more breathing room between lines and an inset XP bar with the pace underneath.
- Adds four small textures (Media/Round, Ring, Disc, Check) and `RG.Round` for rounded panels.

## v0.69.3
- Clicking a quest that is ready to turn in now points the arrow at the hand-in instead of opening the quest log. Right-click opens the quest log; double-click still switches the arrow on or off.

## v0.69.2
- **Double-click works on every tracker line that has a place.** Added to: the "Then:" next step, "Getting there:" (arrow to the first stop of the zone or dungeon), the next upgrade (when its source NPC is known), the bank-alt setup steps and ore/herb reminders. Lines that already had it (quests, pick-ups, hand-ins, route stops, professions) keep it. Their tooltips say so.

## v0.69.1
- **Double-click a quest that is ready to turn in and the arrow guides you to the hand-in.** Ready quests now always know their hand-in NPC from the quest data (even when it is on another continent), so every green "turn in" row on the tracker can be double-clicked. Right-click shows the spot on the map.

## v0.69.0
- **Tracker redesign:** the header now names the zone you're working through. Quest rows use the quest-log icons (? hand in, ! pick up, a sword for objectives, a clock for later) with coloured names. Professions and Reminders start folded, with a count, so the tracker shows only what to do now (click a heading to open it; it remembers).

## v0.68.0
- **A new character no longer sees "Everything for your level is done."** When nothing matches your exact level (for example after ticking the starting zone), the next zone is shown as "Up next" instead.
- Levels 1-10 hide the long "Later" list so the first screen is just what to do now and what comes next.
- The leveling pace card moved from the top to below "Now".
- The scroll bar has a real thumb (as long as the visible part of the list) on a faint track, instead of a small stub.
- Fewer colours: the teal accent marks what matters; dungeon and travel rows use a quiet grey bar.
- The tracker panel is darker (about 85% opaque) with a thin grey border, so text reads over snow and sand.

## v0.67.1
- **No more accidental skips:** steps tick themselves when you finish them in game. Ticking one by hand now needs Shift-click (on the Route tab and on the tracker), so a stray click can't mark a step done. Clicking a step you ticked still un-ticks it, and Undo is still offered.
- Fixed dungeons showing "Quests done" on a new character: quests you can't take yet no longer count as finished.

## v0.67.0
- **Zone level windows now follow the guides.** Six current WoW Forever guides were compared (The Forever Era, WoW Handbook, Endgame Tools, wowforeverbuilds, Decarebia). Horde zones now start earlier where the guides do (Stonetalon 18, Hillsbrad 21, Ashenvale 22, Thousand Needles 26, Tanaris 41, Feralas 42, Hinterlands 44, Burning Steppes 50, Azshara 50, Silithus 55) and run later where they do (Stranglethorn to 45, Dustwallow to 45). Alliance Hillsbrad, Dustwallow, Desolace, Tanaris, Burning Steppes, Azshara and Silithus were corrected the same way. The Smart route and the tracker use these windows.
- **New dungeons in the route:** The Hall of Thanes (Alliance, 13-18, under Ironforge), The Drowned City (35-40), Krol'dok Stronghold (40-55), Alcaz Prison (48-53), Blackmaw Hold (55-60) and The Shaper's Terrace (58-60). Entrances that no guide has confirmed yet say so.
- For the developers: `tools/sources/evidence.json` and `tools/sources/compare.py` keep the guide ranges and compare them to our routes on every update.

## v0.66.0
- **Horde zones are now built from the quest data, quest by quest.** Stonetalon, Hillsbrad, Ashenvale, Thousand Needles, Arathi, Desolace, Stranglethorn, Dustwallow, Badlands, Swamp of Sorrows, Tanaris, Feralas, Hinterlands, Searing Gorge, Un'Goro, Felwood, Burning Steppes, Winterspring, the Plaguelands and the Barrens (18-26) went from about three hand-written lines each to a full list: every quest your Horde character can take, grouped by town in a sensible order, with a map pin per stop. Each step ticks itself off when its quests are turned in. The Alliance zones already worked this way.
- New Horde zone entries: Azshara (52-58) and Silithus (56-60).

## v0.65.1
- **Professions tab:** your main professions and your side professions are now listed separately. Cooking, Fishing and First Aid always have their own section under "Side professions", even before you learn them, so the First Aid plan (and its camp object) is always one click away.
- First Aid is now part of the default plan for every character, like Cooking and Fishing.

## v0.65.0
- **Tracker restyle:** the header is just your level; the XP bar is now a thin line along the bottom with your XP per hour, time to level and percent above it.
- **Compact tracker:** collapse the tracker (the - button) and it keeps one line, "Next: ...", with your next step.
- **Resizable window:** drag the bottom-right corner of the Waypath+ window to make it bigger or smaller; double-click the corner to reset.
- **Bug reports:** `/wp debug` opens the error window with your version, race, class, level, zone and memory on the first lines, ready to copy.
- A small public API for other add-ons: `WaypathAPI.Pin(map, x, y, label)`, `Clear()`, `CurrentZone()`.

## v0.64.0
- Lighter on memory: quests your race or class can never take, the other faction's route and other races' definitions are dropped after login (about 18% less memory).
- The ore and herb alert check does nothing when you have no gathering profession or the alerts are off.

## v0.63.3
- Fixed the quest tracker losing the text of some lines (section headings and several rows were blank): it is back on the game's own font.
- The header line no longer runs into the XP numbers: it now shows just your level, race and spec.

## v0.63.2
- The arrow is green when you are facing the target (amber to the side, soft red when it is behind you).

## v0.63.1
- **Crystal arrow:** the 3D arrow is redrawn as a faceted, cut-glass arrow with a ridge down its length, glowing edges and a soft shadow beneath. It glows cyan when you face the target, amber when it is off to the side and soft red when it is behind you.

## v0.63.0
- **New Graphite look:** the classic ornate frames are gone. Waypath+ is now flat near-black with thin lines, a single teal accent and the Inter typeface (SIL Open Font License, included). Tabs run along the top, list items are separated by hairlines instead of boxes, buttons and the scroll bar are slim, and the quest tracker, setup and toasts match.
- **Cleaner arrow:** no more dark disc or gold ring. The solid 3D arrow floats on its own, larger, with a crisp name above and distance below in Inter, and gives a small pop when its target changes.

## v0.62.0
- **Proper pathing with Shortest Path Forever:** if you install the free add-on Shortest Path Forever (by cjber), Waypath+ now hands every pin to it. It plans a real walking route around mountains, cliffs and cave mouths (and boats, zeppelins and flights) from a baked map of the world, and its arrow and tracker guide you. Our own arrow steps aside while it's guiding. Turn it off in Settings if you prefer ours. Without it, the arrow still learns your walked paths as before.

## v0.61.2
- The dark look is removed again (the Look button and /wp theme are gone); Waypath+ keeps its classic look.

## v0.61.1
- **Real 3D arrow:** replaced the layered look with a properly rendered solid arrow with lighting and a highlight, drawn from 100 pre-rendered angles. /wp arrow3d off brings back the flat one.

## v0.61.0
- **3D arrow:** the waypoint arrow is now a solid, lit 3D arrow (pre-rendered, one picture per direction) that turns smoothly and still changes colour as you face the target. Prefer the flat arrow? Type /wp arrow3d off.

## v0.60.0
- **Dark look:** a flat, cooler, less cluttered theme sits beside the classic one. Click "Look" in the window's top bar, or type /wp theme dark or /wp theme classic. Your choice is remembered.

## v0.59.0
- **The arrow learns the way:** Waypath+ now remembers where you walk (a thin trail, shared by all your characters). If the arrow sees you aren't getting closer, because a mountain, cliff or cave entrance is in the way, it leads you point by point along the way you went before. If it doesn't know the way yet it says so, and learns it as you find it. /wp trail shows what it knows; /wp trail off or reset to stop or clear it.

## v0.58.0
- **Smart route:** the tracker now picks the best questing zone for your level, where you are and the quests already in your log, and lists the next best choices ("Also good: ..."). It follows the style you pick in /wp setup (Fastest XP, Balanced, Low travel). It stays in a zone until something is clearly better, and dungeons are only suggested if you said you're open to groups. Prefer the fixed order? Choose Guided in setup or type /wp smart to switch.
- Every spec (Horde and Alliance) is now scored against the same gear and guide standard in the data checks.

## v0.57.0
- **Alliance support (beta):** Humans, Dwarves, Gnomes, Night Elves and Alliance Skyborne now get a full leveling route from their own starting zone through all the shared Alliance zones to 60, with quest steps, map pins, dungeon quest lists, Alliance profession trainers and Alliance gear sources for every class and spec.
- Undead-only paladin text is hidden for Alliance paladins. The first time an Alliance character logs in you get a short beta notice; please report anything that looks off.
- The data checks now cover all ten races and every class they can play.

## v0.56.0
- **Smarter first-run setup:** Waypath+ now detects your faction, race, class, level, zone and professions on its own and shows them on the setup page. A new "How do you play?" page asks what matters most (leveling fast or enjoying the zones), solo or groups, travel and your role. Run it again any time with /wp setup.
- **Professions follow you:** learn a profession and it is added to your guided professions automatically, with a message; drop one and it is removed. Professions you know but don't want guided can be unticked in setup.
- **Professions tab redesigned:** every profession you have gets its own section with a skill bar. Click a bar to fold or open it. Each section shows the current step, materials, trainers, places, the full route, and its camp object. The separate Camping tab is gone; campfires live under Cooking and each camp object under its profession.

## v0.55.1
- Quest, gear, map and profession data updated from WoW Forever's latest game data.

## v0.55.0
- **Route steps for five more dungeons:** Excavation Site (Wetlands), City of Dalaran, Gnomeregan, Razorfen Downs and the Temple of Atal'Hakkar now have step-by-step guidance on the route: the quests to collect first, where the entrance is (with a map pin), the boss order, and the quests to hand in. Gnomeregan explains the Goblin Transponder Horde use to get in, and Dalaran lists the Tarren Mill key chain.
- **Honest fishing numbers:** the Fishing tab now says plainly that zone skill levels are Classic's until WoW Forever publishes its own, instead of presenting them as confirmed.
- **New WoW Forever fishing gear:** "Secret" Bait, the Shiny Silver Coin and the Wide-Brimmed Fishing Hat are listed with their bonuses (where to get them isn't published yet).

## v0.54.0
- **Everything fishing can bring up, on the Fishing tab:** a new "Everything fishing can bring up" section lists the catches for the zone you're standing in, with the chance per catch. Open the groups below it (fish, chests and crates, materials, potions, gear, junk) to see every catch in the game: which zones and pools give it, the Fishing skill it starts at, and what each chest, crate, trunk, clam and bottle holds. Hover a row for every zone; click a pool to put it on your map.
- A "Pools, schools, wreckage and fishing spots" group shows what each pool gives and where they are, including WoW Forever's new fishing locations.
- Chances come from the classic fishing tables (WoW Forever hasn't published its own), and the tab says so.

## v0.53.1
- **The Waypath+ logo replaces the paladin icon everywhere:** the window, the tracker, the minimap button, the welcome and setup screens, pop-ups, chat messages and the add-on list now show the Waypath+ waypoint logo for every class.

## v0.53.0
- **Fresh WoW Forever quest data:** quest givers, objective spots and route steps updated from the latest WoW Forever database. Zephras Isle steps now point to Yorana Windyreed for her quests instead of Valanaar, Thunder Bluff's "Stalk With The Earthmother" is on the Mulgore route, and many map pins (Shen'dar Village, Valanaar, Elegael Thornpaw and others) are more precise.
- The Barrens fishing pin now names the Oily Blackmouth School pools.

## v0.52.1
- **Upgrades while fishing, take two:** with a fishing pole in your hands and no weapon remembered yet, upgrades are compared with the best weapon in your bags, and the list says "Replaces your fishing pole" instead of "an empty slot".
- The item window's "Show ... on my map" button fits inside the window again (long place names shorten to "Show on my map").
- The error list shows versions as v0.48.0 (it said vv0.48.0).

## v0.52.0
- **Ready for game updates:** the first time you log in after Blizzard patches the game, Waypath+ checks that everything it uses is still there. If a patch changed something, it tells you which features are affected instead of failing quietly, and notes it in `/wp errors`. `/wp check` runs the check any time.
- Waypath+ now also loads on upcoming WoW Forever versions (1.60.x through 1.62) without being marked "out of date".
- Fixes are now watched for around the clock: a new game build, new WoW Forever quest data or a bug report starts an update within about an hour.

## v0.51.1
- **Fixed the "Waypath has been blocked from an action" pop-up.** Immersive fishing no longer hides the minimap: the game doesn't allow add-ons to do that. (If you saw the pop-up, "Ignore" was safe.)
- If the game ever blocks something again, `/wp errors` now names exactly what was blocked and the game build, for bug reports.

## v0.51.0 (data accuracy pass)
- **250 more quests recognized:** quests that start from an item or object, repeatable quests and quests whose giver has no map position now keep their name, level and earlier steps. Route steps, dungeon lists, quest chains and "where does this item come from" now know about them (for example Willix the Importer, Blackfathom Villainy and The Platinum Discs).
- **The tracker follows your real next zone:** once a zone's route is finished, the tracker moves on to the next unfinished zone for your level instead of saying "All done here".
- **Correct map pins after class-only steps:** where a route step is only for one class (like "Paladins: ..."), the pins for the steps after it were one off for every other class. Fixed.
- **Immersive fishing hides the minimap too,** so quest and tracking dots don't float over the water.
- Route steps that include a repeatable quest no longer wait for it to be "completed" (the game never marks repeatables done).
- Dungeon lists: "Lost Thunderbrew Recipe" now matches the quest's real name and giver (Shadowmage Vivian Lagrave), so it is recognized and pinned.

## v0.50.0 (fixes from in-game testing)
- **Immersive fishing shows its text again:** the display was only showing the cast bar. Your skill, "Watch your bobber", catches and whispers now appear as intended.
- **No more fishing poles or wrong weapons in gear lists:** a bug let classes see weapons they can't use (Paladins were offered staves and fishing poles). Every class's gear guide and every 2nd-spec list has been rebuilt.
- **Upgrades while fishing:** with a fishing pole in your hands, upgrades are compared with the weapon you normally wear, not an empty slot.
- **No Alliance quests in dungeon lists:** quests given out in Alliance cities (such as "In Search of Thaelrid") are gone from Horde dungeon lists.
- **Long lines no longer end in "...":** route steps, travel tips and descriptions now get room for every line.
- Time-to-level on the tracker and the "why this ticked itself off" reason on route steps work again.
- Shorter tab footers that fit, and "about 3 catches per point" instead of a symbol that didn't display.

## v0.49.1
- Waypath+ is now on CurseForge (WoW Forever, project 1743915). Updates there arrive as Beta releases.

## v0.49.0
- **Talents tab removed.** The game's own talent screen does that job better, and builds go out of date as WoW Forever's trees change. The tracker still reminds you when you have points to spend; click the reminder (or type `/wp talents`) to open the game's talent screen.
- The 2nd Spec page keeps each spec's stats, how to play it and what's new in Forever, without the talent build.
- New Waypath+ logo.

## v0.48.0 (ready for CurseForge)
- **Cast button while fishing:** immersive fishing now shows a big Fishing button under the display, since your action bars are hidden. Click it to cast; your usual Fishing key still works too.
- **Uses less memory:** only your own class's gear lists and your own race's starting route stay loaded (about a quarter less memory).
- **Non-English game clients** get a one-time note at login that Waypath+ is made for English clients.
- Waypath+ is now open source under the GNU GPL v3, with credits for QuestieDB and cMaNGOS in the README.
- Packaging fixes for CurseForge: the add-on folder is always named Waypath, and only WoW Forever's game versions are listed.

## v0.47.0 (immersive fishing)
- **Immersive fishing:** cast Fishing and your whole interface fades away, leaving just the water and a small display near the bottom of the screen:
  - your Fishing skill (and points gained this session),
  - a cast timer ("Watch your bobber · 14s"),
  - fish caught, fish per hour, lure time left and whether every fish bites here,
  - your last three catches, with icons and quality colors,
  - "Got away: cast again" when a fish escapes, and whispers ("Whisper from Darmine: press Enter to read").
- **Getting your interface back:** move, get into a fight, press Esc or Enter, or stop casting for about 25 seconds. If you don't use auto loot, the loot window still appears so you can click it, then everything fades again.
- The "cast again" flash now shows even while the interface is hidden.
- Turn it off in Settings (Professions, bags and gold) or with `/wp fishmode`.

## v0.46.0 (clearer route on the tracker)
- **One quest per line:** the tracker's Route section no longer packs a whole step into one long sentence. It shows where you are (for example "The Den, Valley of Trials · levels 1-3" and "1/4 quests done"), then each quest with the one thing to do next:
  - **Hand in** Cutting Teeth, *to Gornek*
  - **Pick up** Your Place In The World, *from Kaltunk*
  - **Do** Cutting Teeth, *3/10*
  - **Later:** Sting of the Scorpid, *after Cutting Teeth*
- Hand-ins come first, then pick-ups, then quests you're on, then ones that aren't open yet. Double-click any line for the arrow; the arrow starts on the first thing to do.
- The header shows "step 1 of 2" instead of an unexplained "0/2", and a "Then:" line says what the next step is.
- "New quests nearby" no longer repeats quests the route already lists.
- The Route tab shows the same breakdown under each step.
- Class quests say "pick up now" and "from Gornek" instead of "ready" and a bare name.

## v0.45.0 (fixes from your screenshots)
- **Talents for every class:** the Talents tab now shows a leveling build for every class and spec (it used to be empty outside Paladin). It shows what to work toward, ranks as "x/target", and the next point to spend, all taken from the current Forever guides.
- **Gear guide fits your character:** early-level items no longer come from another race's starting zone (no Tirisfal or Darkshore picks for an Orc), and quest, rare and vendor items from Alliance-only zones are gone for Horde.
- **Profession spots near you:** suggested places prefer your current zone first, then your continent, then your home zones. An Orc in Durotar gets Durotar spots instead of Mulgore.
- **More skinning and farming spots:** neutral beasts such as Mottled Boar now count, and each level range lists more places.

## v0.44.2
- "What's new" covers every update since the one you last saw, not just the latest. `/wp news` shows the last two updates, and `/wp news all` shows older ones.

## v0.44.1
- The "what's new" notes are now included in the download, so the first login after an update shows what changed (v0.44.0's zip was built before its notes were added).

## v0.44.0 (quality-of-life pass)
- **What's new after an update:** the first login after updating prints the three biggest changes in chat, once. `/wp news` lists everything in the update.
- **Professions on the tracker:** for each profession you have, one line shows the step you're on and the first material you're short of (for example "Tailoring 62 · Bolt of Woolen Cloth x33 · 99 more Wool Cloth"). Click it to open that profession's guide; double-click it and the arrow takes you to the best place to go. Turn it off in Settings.
- **Next upgrade on the tracker:** click it to see where it drops or which quest gives it (right-click still opens the Gear guide).
- **Quieter Auction House:** automatic scans no longer print to chat. Chat messages only appear when you start a scan yourself with the Scan button or `/wp scan`.
- **Settings:** options that were stuck under "Other" now sit in their groups: new quests nearby and the auto-arrow under Leveling, herb alerts under Professions, and a new Group play group. The group helper's labels no longer mention paladins only.
- No more paladin-only wording for other classes: the Group tab's title, the welcome screen and the bank-alt message.
- Error reports (`/wp errors`) now include the add-on version; it was missing before.
- Lighter combat-log handling in dungeons.

## v0.43.1 (no more cut-off text)
- Long lines in the Waypath+ window wrap instead of ending in "...": every row grows to fit its whole description (route notes, fishing spots, gear sources, tips, profession steps), on every tab.
- Section headers that don't fit on one line wrap too, and the footer at the bottom of the window takes a second line when it needs one.

## v0.43.0 (a profile for every character)
- **New characters aren't bank alts automatically any more.** The first time a character logs in with Waypath+ it asks: **New profile** (the full leveling guide with this character's own settings and progress, starting with the setup wizard) or **Bank alt** (the shopping list and mailbox helper for your main). The very first character gets a profile without asking.
- **Every character has its own profile:** settings and preset, route progress and ticked steps, quests, flight paths, professions plan, stat weights, 2nd spec and its gear set, and so on. Auction House prices and alerts, recipes, the bank-alt shopping data and window positions are shared by the account.
- Your existing data becomes your main's profile when you update; nothing is lost.
- Settings → *This character*: switch between a profile and a bank alt, make this character your main, or **start this character over** with a brand new profile. Also `/wp char profile`, `/wp char alt`, `/wp char reset`.
- Your main (the character bank alts buy for) is the first character with a profile, or whichever you pick with `/wp main`. Only your main's bags count for the bank alt's shopping list.

## v0.42.0 (faster Auction House scan that stays out of your way)
- **Full scans:** when the server allows it (every 15 minutes), opening the Auction House sends one request for every auction and Waypath+ reads the prices it needs in the background, a chunk per frame. It takes a few seconds instead of a second or more per item. The modern Auction House's full scan doesn't touch your Browse list at all.
- **Only out-of-date prices are checked:** between full scans, Waypath+ only looks up items whose price is more than 2 hours old, as fast as the server accepts searches (it used to wait 1.2 seconds per item and re-check everything every time). Reopening the AH right after a scan checks nothing.
- **Your searches come first:** the moment you search for something yourself, Waypath+ stops its own searches for that visit, so the Auction House is yours straight away. Your searches still update its prices. `/wp scan` or the Scan button finishes the rest.
- Every search (yours or Waypath+'s) now records the prices of every watched item it shows, and the Auction House tab shows the scan's progress (click to stop it) and when the last full scan ran.
- Prices for all your professions' materials are kept, for the Professions tab's cost of what you're missing.

## v0.41.0 (profession guide)
- **The Professions tab guides you through every profession.** Pick one of yours (or any of the twelve) and it shows:
  - **Now:** the craft for your skill and how many are left in this step, worked out from the guide's count and your current skill, so it counts down as you level.
  - **Materials:** how many more of each material you need to finish the step, counting your bags and bank ("14 more Linen Cloth"), with the Auction House cost of what's missing. Crafted reagents you're short of (bolts, bars, elixirs) add the materials to make them. When a step lists choices (Cooking), it picks the one you're closest to making.
  - **Where to go:** the densest herb or ore cluster for your skill, beasts to skin at your skill, fishing pools, and for each missing material the mob that drops it most for your level, the herb or vein it comes from, or the nearest vendor that sells it, plus your next trainer. **Double-click any place and the arrow takes you there** (double-click a missing material too).
  - **Next:** the step after this one and what you still need for it, and the whole 1-300 route on request.
- A toast tells you when a step is done and what's next.
- Opening a profession window reads the exact recipes from your client, so Forever's changes are counted correctly.
- New `tools/profs` builds the recipes, material sources, gathering clusters, skinning spots, fishing pools and trainer locations from the classic database and WoW Forever's spawn data. `tools/audit` checks that every craft has recipe data, every herb and vein has a place to go, every skinning step has beasts, and every trainer has a map pin.
- Routes follow the wow-professions.com WoW Forever guides (cross-checked with wowtbc.gg's Forever guides); their 225-300 sections still use the Classic route until the Forever versions are published.

## v0.40.0 (where does this drop?)
- **Click any item in My gear** (your upgrades, or a slot you're wearing) and a small window shows where to get it:
  - **Dungeon drops:** the dungeon, the boss that drops it and its level, the level to run it from, how many dungeon quests you have there, and a button to put the entrance on your map.
  - **Quest rewards:** the quest, who starts it and where (zone and coordinates), the level you can take it at and the quest's level, where you turn it in, what to do first, and whether it's in your log, done, or not open to your race or class. A button puts the quest giver on your map.
  - **Vendors and rare mobs:** who and where, with a map button. Crafted and Auction House items show the craft or the price.
  - When an item comes from more than one place, the other sources are listed too.
- The same window opens from the Gear guide and the 2nd Spec gear list (right-click a guide item whose quest is in your log to open the quest). Shift-click still links and Ctrl-click still previews. `/wp where <item>` opens it too.
- Gear lists now record each item's quest and boss level, and the waypoints include every gear vendor and rare mob.

## v0.39.0 (2nd spec for every class)
- **The Healing tab is now the 2nd Spec tab**, for every class. Pick any spec of your class as your second spec: all 28, tanks, healers and damage (Druids get Cat and Bear separately). Paladins keep Holy until they pick something else.
- **Spec & build:** the spec's WoW Forever talent build (the newest beta builds, level 30), the talents to work toward, its stat priority, how to play it, and what's new for it in Forever. From the mobalytics.gg verified Forever spec guides; the twice-weekly update swaps in level 60 builds once they're published.
- **Gear to collect:** once you pick a spec, this page shows your best piece per slot for it (worn, in your bags or in your bank), the next thing to hunt for in each slot, and a list from level 30 to 60 grouped by level with the dungeons most of it comes from. Each spec's list is built from WoW Forever's quest, dungeon and vendor data with that spec's own stat values: shields, Defense, dodge, parry, block and armor for tanks; +healing, mp5 and Intellect for healers; daggers for Assassination and Subtlety. The Gear guide tab links to it.
- **Everything that knew about the Holy set now follows your 2nd spec:** item tooltips ("Protection score"), bag icons, quest reward picks, the never-sell protection, the bank memory, upgrade toasts, and the swap when you change spec (any class, whenever your 2nd spec uses a different talent tree; Cat and Bear swap with the button). `/wp spec`, `/wp spec <name>`, `/wp gear 2` and `/wp gear 1`.
- The setup wizard asks for your 2nd spec.
- **Druid forms scale with weapon damage in WoW Forever:** feral gear now counts weapon damage, and druids can use polearms.
- Tooltips and scores read tank stats (Defense, dodge, parry, block, block value and armor).
- `tools/audit` checks every spec too: build, tips, stat values, and a gear list covering levels 30 to 60.

## v0.38.0 (every profession)
- **All twelve professions are in:** Mining, Herbalism, Skinning, Blacksmithing, Engineering, Alchemy, Leatherworking, Tailoring, Enchanting, Cooking, Fishing and First Aid. The Professions tab shows the ones you know or plan: your skill, the trainer for your next rank (and the closest one for your race when you haven't learned it yet), where you are in a 1-300 plan with the next steps and materials, supplies to buy, and material prices.
- **Plans come from the WoW Forever guides** (wow-professions.com, beta data), with Forever's changes: Healing Potions are made with First Aid now, Alchemy's new recipes, Herbalism needing character level = herb skill / 5. Where Forever's route isn't published yet (225-300 for several crafts) the Classic route fills in, marked as untested.
- **Herb alerts:** walk near a spot where an herb you can pick (and still learn from) grows, and you get the same heads-up as for ore. Herb and ore zones come from WoW Forever's spawn data (about 10,800 herb spots), and route cards show what you can gather in each zone.
- **Camping for every profession:** all 35 camp objects (Mana Well, Enchanted Lute, Reagent Bot, Camp Tent, Faction Banner, Incense Candle, Camp Chair, First Aid Kit and the rest, with their 140 and 300 upgrades and where the blueprints drop). "What to place when you camp alone" scores your own objects with your class's stat weights (and always picks the Camp Tent's rested XP while leveling).
- **Setup asks about all twelve professions**, and the fishing/cooking plan starts in your own starting zone with your closest trainers.
- Blacksmithing's plan now follows the WoW Forever route (it changed from Classic in several places).
- Gold tips for every profession.
- `tools/audit` checks every profession too: trainers for every rank, a plan from 1 to 300 with no gaps, a camp object, and a nearby trainer for every race.

## v0.37.0 (gear for every class)
- **Every class gets its own gear guide**, built from the item database and WoW Forever's quest and dungeon data with that class's own stat weights: Arms Warrior, Beast Mastery Hunter, Combat Rogue, Shadow Priest, Enhancement Shaman, Frost Mage, Affliction Warlock and Feral Druid (Retribution Paladin as before). Each list only has armor and weapons the class can use, and covers every slot it uses: two-handers or one-handers, off-hands, ranged weapons and wands, head to feet, rings and trinkets.
- **Scores follow your class:** item tooltips ("Arms score", "Frost score", ...), the Equip pop-up, bag arrows, quest reward picks and the My gear tab all score for your class, and never suggest plate before 40 or a weapon you can't use. Spell damage counts by school (Frost for a Frost mage, Shadow for warlocks and priests), and wands, bows and guns count for the classes that rely on them.
- **Stat weights are kept per class** (`/wp weight` changes your class's only). Your paladin's weights carry over.
- **Dungeons show what they drop for you:** the tracker and Route tab list each dungeon's best upgrades from your own gear guide, instead of Ret-only item names. Paladin-specific drop tips are now marked "Paladins:".
- No weapon stone reminder for casters and druids.
- `tools/audit` now checks every class's gear guide too (an upgrade for every slot at every stage of leveling).

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
