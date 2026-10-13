# RetGear

An all-in-one leveling and gearing companion for an **Undead (Horde) Retribution Paladin** (standard two-hander DPS, not Shockadin) with **Mining, Blacksmithing, Fishing and Cooking**, in World of Warcraft: Forever.

## Install
Copy the `RetGear` folder into `World of Warcraft\_forever_\Interface\AddOns\` (during the beta it's `_forever_beta_`), then restart the game. Type `/rg` or click the minimap button.

## First launch
A six-page **setup wizard** asks how much help you want (Full guidance, Balanced or Minimal), which professions you'll level, and which automation and extras to turn on. Run it again with `/rg setup` or from Settings.

## On your screen
- **Tracker** (right side): your quests grouped by zone (the zone you're in first), one line each with their level (in the game's colors), progress and distance; new quests nearby; your route tasks; the next dungeon's quests to pick up; your next gear upgrade; and the most important reminders. Click a quest to open it in your quest log, double-click it to turn the arrow to it on or off, right-click to show it on the map, and click a section header to fold it. Drag it anywhere; right-click the minimap button to hide it.
- **Quest bar**: click to target the quest mobs you still need, and use quest items in one click. The `RetGearTarget` macro does the same from a key.
- **Tooltips**: a **Ret score** on every item (and whether it's an upgrade), a **Holy score** for your dual-spec healing set, and a gold coin line when an item sells for more on the AH than at a vendor.
- **Fishing panel** (tracker): while you hold a fishing pole, your skill and catches per point, whether fish get away in this zone, your lure timer, fish per hour this session, and raw fish to cook.
- **Pop-ups**: Equip button for upgrades, level-up banner, "keep for the AH" and "Buy back" warnings at vendors.
- **Arrow and map pins**: the arrow follows your next route step on its own (it never overrides a pin you placed). Double-click the arrow, or right-click it, to turn it off. Right-click any step, or click a quest giver, dungeon or trainer, to pin it. 74 route steps, 45 quest givers, 56 dungeon entrances and the Fishing/Cooking trainers have WoW Forever coordinates from QuestieDB. `/rg way 45 60` pins any spot.

## Done for you
- Quests are **accepted and turned in automatically** (hold **Shift** to pause). The best reward is picked: the Ret upgrade, or the best vendor value. When a Ret and a healing upgrade compete, you choose.
- **Route steps tick themselves** from your quest log, flight paths, hearthstone, professions and spells.
- **Bags sorted** with one click: the Sort button on your bags and bank.
- **Junk is sold and gear repaired** at vendors, but anything worth more on the AH is kept.
- **AH prices** are checked every time you open the Auction House (Auctionator and TSM prices are used too).
- **Every fight is recorded** by the DPS coach, including your share of the group's damage and any aggro you pull off the tank.
- **In a party**: reminders for un-blessed party members and a missing Aura, center-screen alerts when someone needs Purify/Cleanse or is about to die, and a report after every dungeon run.

## The window (`/rg`)
Styled like the classic WoW interface: the stone-and-gold dialog frame, Character-window tabs along the bottom, tooltip-bordered rows and the purple XP bar (blue while rested). A- / A+ change the text size.

| Tab | What's in it |
|---|---|
| **Route** | Undead Horde path from Deathknell to 60 in four foldable sections: **Now** (your zones and dungeons, with only the steps left to do), **Coming up** (next 5 levels), **Later** and **Done**. Dungeon quests to collect, flight paths, travel, paladin milestones, buy-and-mail quests, camping/fishing steps, and your leveling pace |
| **Gear guide** | Ret upgrades from level 11 to 60 with where they drop, including your own Blacksmithing crafts |
| **My gear** | Score per slot, hit % vs cap, next upgrade for each slot, pre-raid checklist |
| **Talents** | Next talent point (WoW Forever talents) and the leveling priority |
| **DPS** | Last fight: DPS, efficiency, damage by ability, uptime, and what to fix first with the DPS each fix is worth; problems that keep repeating; fight history |
| **Group** | Solo vs grouped XP/hr, your paladin duties (who needs a Blessing, Aura), shared quests with a Share click, LFG posts for the right dungeon or group quest, and dungeon run reports |
| **Healing** | Holy set for dual spec at 40: your best healing piece per slot (worn, bags, bank) and a 40-60 hunting list. Your healing set is never sold |
| **Professions** → *Mining & smithing* | Where to mine, Blacksmithing 1-300 plan, smithing upgrades, smelt-or-sell |
| **Professions** → *Fishing & cooking* | Your Fishing and Cooking skill, next rank and how to get it, whether every fish bites in your zone, where to fish for your skill (Horde), raw fish in your bags that still level Cooking, fish to catch and cook (recipes, day/night and seasonal fish), poles, lures and gear you own, the Stranglethorn Fishing Extravaganza, and your catch history |
| **Professions** → *Camping* | Camp Benefits timer, which object to place (Sharpening Wheel vs Fish Bowl from your stats), campfires and camp objects, and the camping and cooking steps along your route |
| **Gold & AH** → *Sell & prices* | Your bag items to sell on the AH, plus tracked gear and materials with live prices |
| **Gold & AH** → *Gold tips* | Gold-making tips for your level with live prices (refreshed weekly) |
| **Gold & AH** → *Bank alt* | Quests you can skip farming for: what to buy and mail, with a shopping list for your bank alt |
| **Settings** | Every helper, grouped, on or off |

## Bank alt
Your paladin is your **main**. Any other character runs in **bank alt mode**: it won't touch your main's data, its tracker shows the shopping list, clicking an item searches the AH, and a button at the mailbox attaches everything and addresses it to your main. `/rg main` changes which character is your main.

## Commands
| Command | What it does |
|---|---|
| `/rg` | Open or close the window |
| `/rg group` · `/rg lfg Scarlet Monastery` | Group tab · post an LFG message |
| `/rg dps` · `/rg heal` · `/rg fish` · `/rg camp` · `/rg gold` · `/rg mail` · `/rg talents` · `/rg settings` | Open that tab |
| `/rg auto` | Auto accept / turn in on or off |
| `/rg next` | Pin your nearest quest objective (or turn-in) |
| `/rg undo` | Put the last task you ticked off back on the list (the tracker also shows an Undo line for 10 minutes) |
| `/rg way 45 60` | Pin a spot in your zone and follow the arrow |
| `/rg pace` | Time at this level, last level and your average |
| `/rg talents check` | Show how talent points are read on this client (send it to me if talents look wrong) |
| `/rg sort` · `/rg sort bank` | Sort your bags or bank (also the Sort button on your bags) |
| `/rg session` | XP, quests, ore and gold this session |
| `/rg profit` | Bag items to sell on the AH; `/rg profit min 25` sets the threshold in silver; `/rg profit ignore [item]` stops flagging an item |
| `/rg track [item]` · `/rg untrack [item]` | Watch an item's AH price |
| `/rg alert [item] 25` | Tell me when it's listed for 25 gold or less |
| `/rg scan` · `/rg autoscan` | Re-check prices at the AH · turn the automatic scan on or off |
| `/rg weight STR 2.5` · `/rg hitcap 9` · `/rg talenthit 3` · `/rg reset` | Tune the Ret score |
| `/rg setup` | Run the setup wizard again |
| `/rg tracker` · `/rg tooltip` | Show or hide the tracker / tooltip line / welcome screen |
| `/rg main` | Make this character your main |
| `/rg dps reset` | Clear fight history |

## Keeping it current
A weekly update checks the newest WoW Forever guides and refreshes the route, gear, gold tips, healing list, bank-alt quests and camping data. Each release is listed in `CHANGELOG.md`.

Waypoints and quest objectives come from [QuestieDB](https://github.com/Questie/QuestieDB)'s WoW Forever data; `tools/waypoints` and `tools/objectives` rebuild them. Data sources include Icy Veins, Wowhead, Warcraft Tavern, Mobalytics, wow-professions.com and Warcraft Wiki. Several dungeon drops are Classic-era until Forever's loot tables are confirmed.
