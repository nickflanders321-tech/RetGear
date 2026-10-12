# RetGear

Gearing helper for an **Undead (Horde) Retribution Paladin** (standard two-hander DPS, not Shockadin) who levels **Mining and Blacksmithing**, in World of Warcraft: Forever.

## What it does
- **Leveling route** (opens first): an Undead Horde path from Deathknell to 60, zone by zone, with quest hubs, where you can mine along the way, paladin milestones (Seal of Command at 20, warhorse at 40, Charger at 60) and every dungeon. Each dungeon says when to head over and lists the Horde quests to grab first: name, quest giver and where. Chat reminds you two levels early to start collecting them.
- **Syncs with your quest log:** dungeon quests show whether they're in your log, ready to turn in, or done, and route steps tick themselves when the game confirms them (flight paths, hearthstone, professions, Seal of Command, named quests). Your completed-quest history is read on login.
- **Travel tips:** the flight path to grab in every zone, zeppelins (Undercity to Orgrimmar and Grom'gol), the Ratchet-Booty Bay boat, and where to set your hearthstone. Open any flight master once and RetGear remembers which flight paths you know, then marks each one on the route as learned or still to grab.
- **Tooltip score on every item:** a Ret score in Attack Power equivalents, and how much better or worse it is than what you're wearing. Hit only counts up to your hit cap.
- **Leveling guide** (`/rg`): Horde-friendly upgrades from level 11 to 60, including your own Blacksmithing crafts, plus tips for the new Undead paladin start at Bandarion Keep, each with where it comes from (quest and zone, dungeon boss, or profession). It shows whether each one is an upgrade for you right now, and flags items you already own.
- **My gear tab:** your score per slot, your hit % against the cap, and the next guide upgrade for each slot.
- **Professions tab:** your Mining and Blacksmithing skill, where to mine next on the Horde side, which Blacksmithing crafts are Ret upgrades (and whether you can make them yet), and live prices for ore and bars.
- **Level-up alerts:** when you ding, it lists the guide upgrades you can now use.
- **Auction House prices:** opening the AH checks the price of every buyable item in the guide, plus anything you track. Auctionator or TradeSkillMaster prices are used when installed.

## Commands
| Command | What it does |
|---|---|
| `/rg` | Open or close the window |
| `/rg track [item]` | Watch an item's AH price (shift-click the item into the command) |
| `/rg alert [item] 25` | Tell me when it's listed for 25 gold or less |
| `/rg scan` | Re-check prices while at the AH |
| `/rg weight` | List stat weights; `/rg weight STR 2.5` changes one |
| `/rg hitcap 9` | Set your hit cap (9% for raid bosses, about 5% for same-level mobs) |
| `/rg talenthit 3` | Add hit % you get from talents |
| `/rg tooltip` | Turn the tooltip line on or off |
| `/rg autoscan` | Turn the automatic scan when you open the AH on or off |
| `/rg reset` | Put stat weights back to the defaults |

## Install
Copy the `RetGear` folder into `World of Warcraft\_forever_\Interface\AddOns\` (during the beta it's `_forever_beta_`), then restart the game.
