# RetGear

An all-in-one leveling and gearing companion for an **Undead (Horde) Retribution Paladin** (standard two-hander DPS, not Shockadin) with **Mining, Blacksmithing, Fishing and Cooking**, in World of Warcraft: Forever.

## Install
Copy the `RetGear` folder into `World of Warcraft\_forever_\Interface\AddOns\` (during the beta it's `_forever_beta_`), then restart the game. Type `/rg` or click the minimap button.

## On your screen
- **Tracker** (right side): your current route step and tasks, dungeon quests to collect, your next gear upgrade, and the 5 most important reminders (Blessing and Seal, camp buff, talents, trainer, bags, and more). Drag it anywhere; right-click the minimap button to hide it.
- **Quest bar**: click to target the quest mobs you still need, and use quest items in one click. The `RetGearTarget` macro does the same from a key.
- **Tooltips**: a **Ret score** on every item (and whether it's an upgrade), a **Holy score** for your dual-spec healing set, and a gold coin line when an item sells for more on the AH than at a vendor.
- **Pop-ups**: Equip button for upgrades, level-up banner, "keep for the AH" and "Buy back" warnings at vendors.
- **Arrow**: points to your map pin (`/rg way 45 60`).

## Done for you
- Quests are **accepted and turned in automatically** (hold **Shift** to pause). The best reward is picked: the Ret upgrade, or the best vendor value. When a Ret and a healing upgrade compete, you choose.
- **Route steps tick themselves** from your quest log, flight paths, hearthstone, professions and spells.
- **Junk is sold and gear repaired** at vendors, but anything worth more on the AH is kept.
- **AH prices** are checked every time you open the Auction House (Auctionator and TSM prices are used too).
- **Every fight is recorded** by the DPS coach.

## The window (`/rg`)
| Tab | What's in it |
|---|---|
| **Route** | Undead Horde path from Deathknell to 60: zones, dungeons and when to go, quest givers, flight paths, travel, paladin milestones, buy-and-mail quests, camping/fishing steps, and your leveling pace per level |
| **Gear guide** | Ret upgrades from level 11 to 60 with where they drop, including your own Blacksmithing crafts |
| **My gear** | Score per slot, hit % vs cap, next upgrade for each slot, pre-raid checklist |
| **Talents** | Next talent point (WoW Forever talents) and the leveling priority |
| **DPS** | Last fight: DPS, efficiency, damage by ability, uptime, and what to fix first with the DPS each fix is worth; problems that keep repeating; fight history |
| **Healing** | Holy set for dual spec at 40: your best healing piece per slot (worn, bags, bank) and a 40-60 hunting list. Your healing set is never sold |
| **Professions** | Where to mine, Blacksmithing 1-300 plan, smithing upgrades, smelt-or-sell |
| **Camp** | Camp Benefits timer, which object to place (Sharpening Wheel vs Fish Bowl from your stats), campfires and camp objects, Fishing and Cooking plan, fish worth keeping |
| **AH** | Your bag items to sell on the AH, plus tracked gear and materials with live prices |
| **Gold** | Gold-making tips for your level with live prices (refreshed weekly) |
| **Bank alt** | Quests you can skip farming for: what to buy and mail, with a shopping list for your bank alt |
| **Settings** | Every helper, grouped, on or off |

## Bank alt
Your paladin is your **main**. Any other character runs in **bank alt mode**: it won't touch your main's data, its tracker shows the shopping list, clicking an item searches the AH, and a button at the mailbox attaches everything and addresses it to your main. `/rg main` changes which character is your main.

## Commands
| Command | What it does |
|---|---|
| `/rg` | Open or close the window |
| `/rg dps` · `/rg heal` · `/rg camp` · `/rg gold` · `/rg mail` · `/rg talents` · `/rg settings` | Open that tab |
| `/rg auto` | Auto accept / turn in on or off |
| `/rg way 45 60` | Pin a spot in your zone and follow the arrow |
| `/rg pace` | Time at this level, last level and your average |
| `/rg session` | XP, quests, ore and gold this session |
| `/rg profit` | Bag items to sell on the AH; `/rg profit min 25` sets the threshold in silver; `/rg profit ignore [item]` stops flagging an item |
| `/rg track [item]` · `/rg untrack [item]` | Watch an item's AH price |
| `/rg alert [item] 25` | Tell me when it's listed for 25 gold or less |
| `/rg scan` · `/rg autoscan` | Re-check prices at the AH · turn the automatic scan on or off |
| `/rg weight STR 2.5` · `/rg hitcap 9` · `/rg talenthit 3` · `/rg reset` | Tune the Ret score |
| `/rg tracker` · `/rg tooltip` · `/rg welcome` | Show or hide the tracker / tooltip line / welcome screen |
| `/rg main` | Make this character your main |
| `/rg dps reset` | Clear fight history |

## Keeping it current
A weekly update checks the newest WoW Forever guides and refreshes the route, gear, gold tips, healing list, bank-alt quests and camping data. Each release is listed in `CHANGELOG.md`.

Data sources include Icy Veins, Wowhead, Warcraft Tavern, Mobalytics, wow-professions.com and Warcraft Wiki. Several dungeon drops are Classic-era until Forever's loot tables are confirmed.
