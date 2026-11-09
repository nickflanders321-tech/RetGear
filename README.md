# LibItemDB

<!-- charset-ok: same grounds as CHANGELOG.md. This file SHIPS inside the
     package but no WoW client font ever renders it -- the client loads no
     .md, and nothing here is ever drawn in game. Its readers are GitHub and
     the CurseForge page, in a browser. The arrows and em dashes predate this
     declaration and are load-bearing prose (`name -> link / id`); new text
     is written ASCII, so the declaration exists to keep the linter's report
     about current edits rather than permanently non-empty, which is how a
     report stops being read. -->

A standalone, **offline item database** for World of Warcraft. It resolves an
item **name → link / id** (and back), reads **item level + stats**, filters by
**type / subtype / stat**, and reconstructs **random-suffix variants**
("`<base> of the Bear`") — all without the item being in the client cache.
It also answers **where an item comes from and how often** (boss, quest,
vendor, crafting, gathering, PvP or reputation, with per-boss drop rates),
**where to go to get it** (the creatures, vendors and nodes, with zones, chances
and map points, shown in its own "Where to get it" window on Alt+click or a click
the player chooses), **which professions use it as a material** (drawn on the
item's own tooltip, with where the material comes from), **whether a
character can use it** (class tag, faction, and the armour / shield / weapon
proficiency of their class at their level), **what it is worth to a class and
spec** (EP scoring, rankings, BiS), and **what it is worth in gold** -- one
lookup over TradeSkillMaster, Auctionator, Auctioneer or its own Auction House
scan, with provenance -- so every addon that consumes it prices items the same
way, from the sources the player configured once in `/itemdb`.

WoW ships no searchable item table and no name→item API, so the only way to
answer "what item is named X?" offline is to have asked the server about every
item id once. LibItemDB ships that result as **static, pre-built data** — no
runtime scan for end users — captured per game version, in every language.

The folder on disk is `ItemDB`; the CurseForge project is **LibItemDB**.

**Not to be confused with Questie's `ItemDB`.** Questie 12 splits its database
into a separate addon, [QuestieDB](https://github.com/Questie/QuestieDB), whose
API documents `LibQuestieDB.Item` as "aliased as `ItemDB`". That is a different
thing entirely -- it answers quest-item questions for Questie. The two do not
contend: this library writes no `ItemDB` global of any kind (it registers only
`LibItemDB-1.0` through LibStub), so both can be installed together whichever
loads first. If you are looking for the addon folder, ours is `ItemDB` and its
project page is `LibItemDB`.

## Supported versions

Ships for every WoW flavour — Vanilla, TBC, Wrath, Cataclysm, Mists, Forever and (from v1.2.0)
Retail, each with its own `.toc`. Vanilla, TBC, Mists and Forever data is in **all 12 client
languages** (localized names, English fallback for anything untranslated), except where noted
below; Wrath, Cata and Retail are English-only so far.

- **Vanilla** (Era / Hardcore / SoD) — 24,127 items, 2,033 random-suffix tiers.
- **TBC** (Anniversary realms, build 2.5.6) — 30,032 items.
- **Mists** (Classic progression, build 5.5.4) — 88,265 items.
- **Forever** (`ItemDB_Camelot.toc`, Interface 16001, build 1.60.1.69913) —
  23,596 items in **12** languages (Italian since v1.1.0). Read the two caveats below before relying on
  it; they are real and they are not temporary oversights.
- **Wrath** (build 3.4.3) — 45,155 items. **Cataclysm** (build 4.4.2) — 65,797 items. From
  v1.2.0. Stats come from the client's item table, checked against the TBC and Mists walks before
  they ship. **Not included:** weapon DPS on either, all armor on Cata, shield armor and school
  resistances on Wrath -- no walk could confirm them.
- **Retail** (`ItemDB_Mainline.toc`, Interface 120100, build 12.1.0) — 176,130 items. From v1.2.0.
  Name, quality, type/subtype, equip slot, item level **and stats**, from a TOG Tools walk of the
  Retail client (2026-10-04). Stats are what the client reports for the plain item link, i.e. the
  base version of an item before any upgrade track or bonus id. Its TOC loads the whole addon --
  tooltip lines, the price window, the "Where to get it" window -- but **no scoring yet**: there
  is no Retail scoring model. Loads on Retail without errors alongside TOGProfessionMaster (2026-10-04);
  the tooltip, price and "Where to get it" windows are not yet individually checked there.

What the three new flavours carry:

| Feature | Wrath | Cata | Retail |
| --- | --- | --- | --- |
| Name / id / link lookup, `Search`, quality, type, item level | Yes | Yes | Yes |
| Stats | Yes, no weapon DPS / shield armor / resistances | Yes, no armor or weapon DPS | Yes (base item, before upgrades / bonus ids) |
| EP scoring (`GetItemScore`, `GetSlotRanking`, ...) | Yes | Yes | No |
| Fixed BiS lists (`GetRaidBiS`) | Yes | Yes | No |
| Material "used by" professions (`GetReagentUses`) | Yes | Yes | Yes, incl. quality and optional reagents |
| Expansion (`GetExpansion`) | Yes | Yes | Yes (unknown for ~8,000 items: `nil`) |
| Boss drops by instance (`GetSources`) | Yes | Yes (Cataclysm from the Encounter Journal) | Yes (Encounter Journal) |
| Per-boss drop chance (`GetDropRate`) | Yes | No | No |
| Quest / vendor / drop / gathered origins | Yes | Yes (Mists-era vendor stock) | Yes (TrinityCore's world database, plus AllTheThings for Dragonflight-onward gathering; some modern gems, pigments and meats have none yet) |
| Crafted-by profession and reputation origins | Yes | Yes | Yes, incl. Dragonflight-onward recipes |
| "Where to get it" (`GetItemPlaces`) | Yes | Yes | Yes (TrinityCore's world database) |
| Reputation and PvP rewards (RepLoot) | Yes | No | No |
| Class / faction / race / required level, sets, use-effects, talents | Yes | Yes | No |
| Hidden test / never-implemented items (`IsHidden`) | Yes | Yes | Yes, from v1.4.0 |
| Consumable buff stats (`GetEffects`, `GetConsumableBuffs`) | Yes | Yes | Yes, from v1.4.0, at level 90 (Retail scales them with level), with Versatility as `ITEM_MOD_VERSATILITY` |
| Raid buff stats (their own expansion's buffs), consumable exclusion groups, gems | Yes | Yes | No |

### Features by version

What each flavour's shipped data answers, read from the `Data/<Version>/_core/` files each TOC
loads. "No" means the getter answers `nil` / empty there, never an error -- feature-detect on the
answer, not on the flavour.

| Feature | Classic | TBC | Mists | Forever |
| --- | --- | --- | --- | --- |
| Name / id / link lookup, `Search`, quality, type, item level, stats | Yes | Yes | Yes | Yes |
| Random suffixes ("of the Bear") | Yes | Yes | Yes | No -- the game has none |
| Socket gems (`GetGem`) | No -- no sockets | Yes | Yes | No -- no sockets |
| Mounts typed as "Mount" | Yes | Yes | Yes (from v1.2.0) | Yes |
| Boss drops by instance (`GetSources`) | Yes | Yes | Up to Wrath instances | Classic instances, plus 3 new Forever dungeons (from v1.1.3) |
| Per-boss drop chance (`GetDropRate`) | Yes | Yes | Yes (from v1.2.0) | No |
| Quest / vendor / crafted / world-drop origins | Yes | Yes | Yes | Crafted and chests only |
| Reputation and PvP rewards | Yes | Yes | No | Yes |
| "Where to get it" window (`GetItemPlaces`) | Yes | Yes | Yes | No |
| Material tooltip: "Used by" professions | Yes | Yes | Yes | Yes |
| Material tooltip: gathering profession as the source | Yes | Yes | Yes | No |
| Tooltip "Expansion:" line (`GetExpansion`) | Yes | Yes | Yes (from v1.2.0) | No |
| Class tag, faction and required level | Yes | Yes | Yes (from v1.2.0) | Yes |
| Race restriction | Yes | Yes | Yes | Yes |
| `CanUse` / `ClassProficient` (proficiency rules) | Yes | Yes | Yes | Yes |
| Item sets and set bonuses | Yes | Yes | Yes (from v1.2.0) | Yes |
| Consumable use-effect stats | Yes | Yes | Yes (spell-scaled values correct from v1.2.0) | Yes |
| Consumable exclusion groups | Yes | Yes | Yes (from v1.2.0) | Yes |
| Raid / world / self / totem buff stats | Yes | Yes | Raid buffs (from v1.2.0, Mists' own) | Yes |
| Talent trees and talent effects | Yes | Yes | No -- Mists has talent tiers, not trees | Yes |
| Gear scoring (EP) | Yes | Yes | Yes (from v1.2.0, incl. Monk) | Yes, on Classic's weights |
| Ready-made BiS lists | Yes | Yes (none for hunters) | Yes (from v1.2.0, all 11 classes) | No |
| Vendor buy and sell prices, shipped (`GetVendorBasePrice` / `GetVendorSellPrice`) | Yes | Yes | Yes (from v1.2.0) | Yes |
| Vendor buy prices captured at merchants you open (`GetVendorBuyPrice`, `source = "merchant"`) | Yes | Yes | Yes | Yes (from v1.1.2) |
| Price ladder, Auction House scan, `/itemdb` | Yes | Yes | Yes | Yes |
| Names in all 12 client languages | Yes | Yes | Yes | Yes |

### What is different about Forever

**There are no random suffixes, at all.** The client ships neither an
`ItemRandomProperties` nor an `ItemRandomSuffix` table, and WoWSims' Forever
database carries zero of them. So `GetRandomProperty` returns `nil`,
`HasRandomProperty` returns `false` and `GetRandomProperties` returns an empty
list — permanently, not "until captured". `ResolveSuffix` and `GetSuffixLink`
still resolve the **base** item so you can fall back to the live tooltip; that
contract is specced. Feature-detect with `DB:GetRandomProperties()[1]` rather
than branching on the flavour.

**Stats come from the client itself, since v1.1.3.** Forever's core is built
from an in-game walk of every item id, exactly like Classic's, so every stat is
what the client's own `GetItemStats` reports: **23,596 items**, weapon DPS on
every weapon and spell power wherever the tooltip shows it. Before v1.1.3 the
stat numbers came from [WoWSims](https://github.com/wowsims/forever) (MIT),
because Forever stores stat _allocations_ that nothing shipped with the client
resolves; that build left most white weapons with no DPS and 1,098 items with no
spell power, so gear scores on Forever before v1.1.3 were low or zero for those
items.

**Forever is a RATING system, and the library converts for you.** Its client
stores hit, crit, haste, dodge, parry and block as _ratings_, not percentages —
WoWSims' own constants give 10 rating per 1% hit, 14 per 1% crit, 12 per 1%
dodge, 15 per 1% parry and 5 per 1% block, where every one of Classic's is 1.
The data is converted before it ships, so `HIT_PCT` and friends mean **percent on
every version**, exactly as they do on Vanilla and TBC, and you need no
per-version handling. **Hit and crit arrive on both the melee and the spell key**
(`HIT_PCT` and `SPELL_HIT_PCT`, `CRIT_PCT` and `SPELL_CRIT_PCT`) from v1.1.3,
because Forever merged them into one stat that covers attacks and spells alike;
before that only the melee key was set. Two exceptions, both deliberate: `DEFENSE` is a defense
**level** (the client's own divisor is 1), and `EXPERTISE` is the raw rating,
because Forever measures it per quarter-percent and no shipped scoring module
prices it.

**Scoring works on Forever, but its weights are Classic's and are _not_
Forever-tuned.** `DB:HasScoring()` is `true` and `GetItemScore` returns a
number. Forever loads Vanilla's scoring rules, which is measured rather than
assumed, over every position rather than a sample: both clients' talent trees
carry **432** talent positions across the same 27 trees, every position exists in
both at an identical class/tab/tier/column, and maxRank differs at **none** of
them. Forever's items use the same flat-percentage stat keys. The EP weights are
HawsJon's Classic scale — neither HawsJon nor WoWSims publishes a Forever one.
**32 of those 432 talents are renamed in place** (a further 17 ship with an empty
name, which is a gap in WoWSims' export rather than a removed talent), keeping
both their position and their spell id: Warrior's Axe, Mace and Sword
Specialization all display as "Weaponmaster", and Rogue's Dagger, Mace and Sword
Specialization as "Hack and Slash". Nothing merged — each is still a separate
talent with its own spell, as `GetTalents` shows.

**The effects behind those spells HAVE been compared now, and the answer is that
Forever's talents are substantially rebalanced — so treat the EP weights as a
starting point, not as Forever-tuned.** Reading `SpellEffect` for every shared
talent spell id on both builds (magnitudes normalised across the two schemas,
since Forever stores the value itself where Classic stores value − 1): **30 of
the 32 renamed talents have different effects, 24 of them structurally** — a
different aura or a different number of effects, not merely a retuned magnitude.
The renaming is not the useful signal, though: among the **383 talents whose name
is unchanged, 265 still differ and 147 differ structurally**. A same spell id is
not the same talent on Forever whether or not it was renamed.

The weapon specialisations the EP weights lean on are squarely in that set. Axe
Specialization (12700) and the Rogue's Dagger Specialization (13706) move from
aura 52 to aura 290; Mace Specialization (12284, 13709) from aura 42 to aura 280;
the Rogue's Sword Specialization (13960) becomes three separate effects. Only
Warrior Sword Specialization (12281) is unchanged. So per-weapon-skill valuations
on Forever are **known to be wrong**, not merely unverified — layer your own with
`LoadBiSWeights`, and read `GetBiSWeightsInfo` before trusting a shipped scale.

Every side table is populated: `GetAuraBuffs` has 100 ranks across 30 buffs,
`GetTalentEffects` 37 talents, `GetUseEffects` 15 on-use and 17 procs, and
`GetItemSchools` 249 school-specific items. The client carries no on-equip
aura 13 to read school masks from, so those come from the client's own
per-school stats (`ITEM_MOD_FROST_DAMAGE_DONE_SHORT` and so on), combined by
Vanilla's convention: a two-school item such as Robe of Winter Night is 40
spell damage to _either_ school, tagged `frost,shadow` — never 80.

**Consumable exclusion groups work on Forever, with a different vocabulary
from Vanilla's.** `GetConsumableGroup(id)` answers for 159 consumables — the
WoWSims slots `potions` (8), `flask` (7), `explosive` (2), `weapon-imbue` (3)
and `conjured` (1), every Well Fed food as `food` (127), and the 11 school
protection potions under `protection-<school>`. Vanilla's finer tokens
(`agility-elixir`, `zanza-buff`, …) come from per-item typed inputs that
WoWSims no longer publishes; Forever's come from its `ConsumesSpec` model,
where each slot is one field holding one item id. **Never hardcode a token** —
compare two items' tokens for equality and render the token as a label. An item
with **no** token is _unclassified_, not "stacks with everything"; treat `nil`
as unknown. That matters more here than on Vanilla, because five of Forever's
modelled consumables ship with no token — Gift of Arthas, Arcane Elixir, Greater
Arcane Elixir, Elixir of the Mongoose and Potion of Demonslaying — which are
almost exactly the battle/guardian elixirs WoWSims has not typed yet, and
guessing a slot for them would be inventing a constraint. Main-hand and off-hand imbues are **separate
slots** in that model, so an off-hand oil applies alongside a main-hand one —
both carry the single `weapon-imbue` token and how many weapon slots a player
has is yours to decide.

**Seventeen Forever talents have an empty `name`, and that is deliberate.**
Their rows are all present and complete — position, spell id and `maxRank` all
match Classic — but the client's own `SpellName` export carries no row for the
spell, so there is no name to ship. Polearm Specialization, Dark Pact,
Elemental Mastery, Defiance and Iron Will are among them. **We do not
substitute the Classic name for the same spell id**: that would assert the
talent is still called that on Forever, which nothing here knows, and the
library's line is that it ships facts and leaves judgements to you. So guard
for an empty string as well as `nil` — `tal.name or "?"` does **not** catch it,
because `""` is truthy in Lua.

**Proc rates are thin on Forever, so a proc is more often unpriced than
elsewhere.** Scoring a chance-on-hit effect needs a rate, and the client says
only _what_ procs, never _how often_. Vanilla and TBC get the rate from a
CMaNGOS world database; no such database exists for Forever, so the rate comes
from WoWSims' own model — which covers 38 items. The upshot for a consumer: on
Forever 132 proc effects have a scoreable effect but no rate and are therefore
left out of EP entirely, and **every set-bonus proc is unscored**
(`GetSet(...).procs` is empty for all 261 sets, though the flat bonuses in
`.bonuses` are complete). Read
`HasUnscoredProc(id)` before presenting a score as the whole story — on Forever
it is the common case, not the exception.

**Drop sources cover the Classic instances and, from v1.1.3, three new Forever
dungeons.** `GetSources` answers for 545
items across 27 instances and 205 bosses, from WoWSims' own AtlasLoot input,
plus **1,972 items whose origin is a place rather than a boss kill** — 1,732
crafted (the profession is the place: `{ instance = "Blacksmithing", source =
"crafted" }`) and 259 chest, object and trash drops (`{ instance = <zone>,
source = "drop" }`). Those inputs cover every expansion and join to ours by item
id alone, so rows are kept only where the zone exists in Forever's own
`AreaTable`; nine TBC and Wrath instances that do not (Trial of the Crusader,
The Shattered Halls, The Oculus and others) are refused rather than shipped. Both come back in the shape Vanilla's CMaNGOS-derived
locations already use, with no `boss` and no `encounterID` — so branch on
`encounterID` being present, not on the entry existing. Vanilla files a crafted
item under the bare place `"Crafted"` because its source knows no profession;
the `source` kind is `"crafted"` on both, so filter on that, never on the
place. The genuinely new Forever dungeons are not in that data; a second builder
(`tools/build-sources-imenso.py`) covers them from a community reference with no
licence (credited in the file). From v1.1.3, when the item data started carrying
their loot, that is **33 items across three dungeons and 11 bosses** — The Hall of
Thanes, City of Dalaran and Ruins of Lordaeron — under the source `"imenso"`.
The upstream says only beta-observed drops are confirmed, so treat these rows as
evidence. Their **`encounterID` is synthetic** — at or above `90000000`,
because that upstream names bosses and has no npc ids. Never join an encounter id
to npc data; like instance keys, they are opaque. Reputation and battleground rewards
answer too — **451 items across 12 sources**, as
`{ instance = <faction or battleground>, source = "reputation" | "pvp" }`,
from AtlasLoot's Classic tables intersected with Forever's own items.
So on Forever, `HasSources(id) == false`
means **unknown**, not "does not drop". Instance keys are numeric zone ids
there, where Vanilla uses strings like `"MoltenCore"` — keys were always
opaque, so never hardcode them. `GetDropRate` stays empty: the data has no
rates.

Italian (`itIT`) ships on Forever since 2026-09-24, so Forever has **12
languages**: 17,769 of its 23,596 names are Italian, and the other 5,827 fall
back to English. Every language falls back for about 4,400 items, because the
wago export this data is translated from has no localized name for the newer
Forever items at the pinned build; Italian also lacks some Blizzard never translated. Like
every Forever language it has names only. The client has no random-suffix table
(see "What is different about Forever").

**What shipping looks like is the thing worth knowing, and it is a real
limitation of the game rather than of this library.** The `itIT` files for
Vanilla, TBC and Mists are the **English list**. `Data/Vanilla/itIT/Names.lua`
is 555,376 characters against `enUS`'s 555,353 over the same 17,614 lines, and
carries **zero** non-ASCII bytes where `deDE` carries 5,318 — Italian is a
heavily accented language, so a genuinely Italian list cannot be pure ASCII.
Blizzard did not translate these items into Italian, so an Italian client sees
English names in game and this library returns the same. That is correct
behaviour, not missing data, and it is why `GetName` is documented as falling
back to English.

## Requirements

- **Ace3**, **VersionCheck-1.0** and **LibAceGUIWidgets** — hard dependencies
  (auto-installed by CurseForge). Ace3 backs the callbacks and the guild
  version-check; LibAceGUIWidgets builds the price window and the "Where to get
  it" window; the library's item lookups themselves don't depend on any of them.
- **Questbook** — optional, and not listed in the `.toc` (Questbook itself
  depends on this library). When it is installed and offers `TrackPlace`, a
  click on a "Where to get it" row asks it to guide the player there, and a stop
  icon appears when it offers `StopTracking`. Both are looked up at the moment
  they are used.
- **AllTheThings**, **TradeSkillMaster**, **TradeSkillMaster_AppHelper**,
  **Auctionator**, **Auc-Advanced** (Auctioneer) —
  `## OptionalDeps` in every `.toc`, never hard. They exist in the manifest only
  so the client loads them **before** this addon when they are present; nothing
  here fails without them. See [Bridged addons](#bridged-addons) and
  [Item prices](#item-prices----what-an-item-is-worth).
  **SmexyMats was here and is not any more** (MINOR 32): the library ships that
  data itself now, so listing an abandoned addon would advertise an integration
  that no longer exists.
- **SavedVariables:** `LibItemDB_PriceDB` — the price settings, the scan store,
  both windows' positions, the "Where to get it" faction switch and the reagent
  tooltip's settings. The only thing
  this library persists; it is named for its first use, not its only one.

## Bridged addons

**None of these is required.** Each is detected at the moment it is used, so
installing or removing one changes nothing else, and an addon that updates or
moves simply stops contributing rather than breaking anything. Everything lives
in `Integrations.lua`.

The point is to **bridge, not re-implement**: what comes back is the other
addon's own output — its wording, its formatting, its icons — so a tooltip drawn
by a TOG addon reads exactly like the one you already see elsewhere.

### The universal bridge — every addon, including ones with no API

```lua
myTooltip:SetOwner(parent, "ANCHOR_RIGHT")
myTooltip:SetSpellByID(craftSpellID)          -- or SetItemByID / SetHyperlink
lib:ApplyExternalTooltipHooks(myTooltip, "OnTooltipSetSpell")
myTooltip:Show()
```

`HookScript` **composes** — the frame's script becomes a function calling the
previous handler then the new one — and `GetScript` returns that whole chain.
Every handler in it takes the tooltip as its argument and writes to that
argument, so invoking the chain with **your** tooltip routes every addon onto
yours. The setter is what fires the script; it just fires on your frame, which
has none of their hooks, because they hooked `GameTooltip`.

**`GameTooltip` is never read, written, shown, hidden or re-owned** — a parallel
fan-out, not a scratchpad. Nothing flickers and there is nothing to restore.

This reaches addons that expose **no API at all**, because it replays their
handler rather than calling into them. Two hard requirements:

- The tooltip must be a **named** frame inheriting `GameTooltipTemplate`.
  RecipeMaster's de-duplication reads `_G[tooltip:GetName().."TextLeft"..i]` and
  calls `:GetText()` on it with no nil check (`TooltipHandler.lua:112`), so an
  anonymous one errors inside their addon; the call refuses it up front.
- **Populate before calling.** Handlers ask the tooltip what it is showing.
- **Call it before adding your own lines.** That same de-dup loop returns early
  on the first line whose left text is nil, so a line of yours that leaves
  `TextLeft` unset makes RecipeMaster silently add nothing.

### Per-addon reads, for values in your own layout

Use these when you want the numbers rather than their lines verbatim. They do not
overlap with the fan-out.

| Addon | What is bridged | How to read it |
| --- | --- | --- |
| **AllTheThings** | its own tooltip lines, keyed by **spell**, so it works for a recipe with no item at all | `lib:AttachExternalRecipeInfo(tooltip, spellID)` |
| **TradeSkillMaster** | **every price source this install registers** — 41 today across AuctionDB, Item, Accounting, Crafting, External and Operations — with TSM's own localized labels and money formatting | `lib:GetExternalPrices(itemLink)` |
| **Auctionator** | Auction Price, Vendor Price, Disenchant Value | `lib:GetExternalPrices(itemLink)` |

**`GetExternalMaterialInfo` is gone (MINOR 32), and nothing replaces it as a bridge.** It read
SmexyMats for "which professions use this material"; the library now ships that itself for every
version — `GetReagentUses(itemID)` / `IsReagent(itemID)`, and a tooltip line of our own. A caller
that used it switches to `GetReagentUses`, which answers whether or not the player has any other
addon installed. SmexyMats is no longer listed in `OptionalDeps` either.

`lib:GetAvailableIntegrations()` returns the ones usable right now, in display
order, resolved each call.

`GetExternalPrices` hands you every figure a price addon shows, as display rows.
For **one number keyed by item id**, with provenance, chosen by a named statistic
and falling through to the library's own Auction House scan, use `GetPrice` --
see [Item prices](#item-prices----what-an-item-is-worth).

### What each route can and cannot reach

| Addon | Fan-out | Per-addon read | Note |
| --- | --- | --- | --- |
| AllTheThings | yes | yes | either works |
| RecipeMaster | **yes** | no | namespace is the private vararg (`local _, rm = ...`) with **zero `_G` writes** — the fan-out is the only way. Prefer `"OnTooltipSetItem"`: their **item** path covers every profession, their **spell** path only Mining, Poisons, Engineering and Enchanting (`TooltipHandler.lua:131-145`) and adds nothing at all for the rest |
| Leatrix Plus | **yes** | no | no public API at all |
| SmexyMats | **no** | **removed** | kept here as the worked example of why a handler must take its tooltip as an ARGUMENT: theirs read the `GameTooltipTextLeft1` **global**, so it could never be redirected onto another frame. Our own tooltip line (below) is written the other way round |
| TradeSkillMaster | **no** | yes | it _does_ hook `GameTooltip`, but its handler gates on a private registry of tooltips it wrapped (`TooltipWrapper.lua:113`) and returns immediately for ours — good design on their part, and unreachable |
| Auctionator | n/a | yes | as above |

**Vendor price needs no addon at all**: `GetItemInfo` returns `sellPrice`
natively. Auctionator's is still worth showing when present, since matching the
number a player already sees is the whole point.

## Item prices -- what an item is worth

**MINOR 25.** One lookup, several sources, a fixed contract. Everything else in
this library answers "what IS this item"; this answers "what is it WORTH" -- and
stops there. It never answers "what do we charge for it": guild discounts,
officer overrides, donation rates and rank tiers are your addon's policy and
none of them live here. The library reports the market; you decide.

The sources, in default precedence (the user can reorder them in the window):
**Auctionator**, **Auctioneer** (Auc-Advanced), **TradeSkillMaster**, then
**LibItemDB's own Auction House scan**. Every third-party source is **off by
default** and feature-detected at call time; the own scan is on by default and
needs no other addon. Moved here from TOGProfessionMaster on 2026-09-14 so one
copy serves every consumer.

**With TradeSkillMaster on, its Desktop App's REGION figures answer first** --
the whole region's auction house, kept current by the app -- and a realm's own
listings only after them. That is the complete, always-current picture; the
own scan is the fallback for a machine with no price addon at all.

```lua
local DB = LibStub("LibItemDB-1.0", true)
if DB and DB.GetPrice then                          -- feature-gate on the method, not a MINOR
    local copper, why = DB:GetPrice(13468)          -- the account's default statistic ("best")
    if copper then
        -- why = { source = "tsm", sourceName = "TradeSkillMaster", statistic = "market",
        --         age = nil, at = nil }            (age / at are nil when the source cannot say)
        print(DB:FormatMoney(copper), "from", why.sourceName, DB:FormatPriceAge(why.age))
    end
    local low = DB:GetPrice(13468, "minBuyout")     -- a NAMED statistic, or nil if no source has it

    local prices, n = DB:GetPrices(bankItemIDs, "historical")   -- the bulk form: one source probe
    for id, row in pairs(prices) do print(id, row.value, row.source) end

    DB.RegisterCallback(myAddon, "LibItemDB_ScanComplete", function(_, kind, reason)
        refreshMyEstimates()                                    -- kind = "full" | "targeted"
    end)
end
```

**The contract, and every line of it is load-bearing:**

- **Keyed by `itemID`**, never by name or link. A link or a name answers `nil`.
- **Copper, as an integer. `nil` means NO DATA and is never a zero.** An unpriced
  item must not silently price at 0 -- that gives it away for free.
- **A NAMED statistic is answered only by a source that carries it.** Asking for
  `"market"` never quietly hands back a minimum buyout under a different label.
  The statistics are `"minBuyout"`, `"market"`, `"historical"`; `"best"` walks
  each source's statistics in that source's own preference -- `minBuyout`,
  `market`, `historical` for Auctionator, Auctioneer and the own scan (the
  ladder TOGPM used to run); `market`, `minBuyout`, `historical` for TSM,
  because its market figure is the region-wide one (below) -- before moving to
  the next source. `nil` statistic means the account's default (`best` out of
  the box; the user can change it). Name a statistic when you need a specific
  one; a minimum buyout is a _listing_ figure that only Auctionator, the realm
  half of TSM and the own scan carry.
- **Provenance on every answer**: `source` id, `sourceName`, the real
  `statistic` (never `"best"`), and `age` in seconds with the matching `at`
  epoch. The own scan is exact; Auctionator reports whole days; Auctioneer and
  TSM do not say, so `age` is `nil` there -- show "age unknown", never "fresh".
- **Scope**: the scan store is per **realm + faction** (`DB:GetPriceScope()`
  returns the key, `"Realm - Faction"`); settings are per **account**.
  Third-party sources scope themselves.
- **What each source carries**: Auctionator -- `minBuyout` (its Auction Price)
  and `historical` (its 14-day mean of daily lows, when the
  "cached historical fallback" toggle is on); Auctioneer -- `market`
  (GetMarketValue) and `historical` (its cached stat-engine value, toggle-gated);
  TSM -- all three, **region figures first**: `market` is `DBRegionMarketAvg`
  then `DBMarket` / `DBRecent`; `historical` is `DBRegionHistorical` /
  `DBRegionSaleAvg` then `DBHistorical`; `minBuyout` is `DBMinBuyout` (there is
  no region minimum buyout). The `DBRegion*` figures are the TSM Desktop App's
  whole-region data, delivered through TradeSkillMaster_AppHelper -- complete
  and kept current by the app, where a realm's own figures are only as fresh
  as the app's last publish for that realm. The "Region data from the TSM
  Desktop App first" toggle (`useTSMAppHelper`, on by default) gates the region
  half; off, TSM answers from realm figures alone. Own scan -- `minBuyout`
  only, the lowest per-unit buyout of the last scan.

| Method | Returns |
| --- | --- |
| `DB:GetPrice(itemID, statistic)` | `copper, provenance` or `nil`. See above |
| `DB:GetPrices(itemIDs, statistic)` | `results, count` -- `results[itemID] = { value, source, sourceName, statistic, age, at }` for every id that priced (absent otherwise; always a table). `itemIDs` is an **array** of ids, or a **set** `{ [itemID] = anything }` (read by its keys when the table has no array part) -- the shape a bank inventory already has. The source list is resolved **once** for the batch, which is why this exists |
| `DB:GetPriceSources()` | `{ { id, name, detected, enabled, precedence, statistics, external, age, count }, ... }` in precedence order. `detected` = the addon is present right now (a fed source: this realm + faction holds its data); `enabled` = the user turned it on; both must hold for a source to answer. `statistics` lists what that source can answer. `external` is `true` for a fed source (MINOR 26). `age` (seconds) and `count` are set only for the own scan and a fed source -- data the library holds and can date; a third party does not say, so both are `nil` |
| `DB:IsPriceSourceEnabled(id)` / `DB:SetPriceSourceEnabled(id, on)` | one source's toggle by id, whichever kind it is (MINOR 26). A built-in routes to its settings key below, cascade included; a fed source flips its own toggle. `false, reason` for an unknown id |
| `DB:StoreExternalPrices(sourceID, sourceName, entries)` | **feed the ladder a price list from outside this client** (MINOR 26) -- see "Fed sources" below. Returns the number of entries stored, or `nil, reason` |
| `DB:ClearExternalPrices(sourceID)` | drop a fed source's data for this realm + faction. `true` if anything was held |
| `DB:HasPriceData()` | `true` when ANY enabled source could answer on this machine (the own scan counts once it holds a price for this realm + faction). The difference between "this item has no price" and "you have no price data at all" |
| `DB:GetVendorBuyPrice(itemID)` | what a vendor **charges**: Auctionator's vendor cache (when enabled), else a price this account **saw at a merchant** (captured on `MERCHANT_SHOW`, the only source that knows your reputation discount), else the shipped base price (`GetVendorBasePrice`). `copper, { source = "auctionator-vendor" \| "merchant" \| "vendor-static" }` or `nil`. Deliberately separate from `GetPrice`: a vendor price is a fact, not a fallback for a missing auction price |
| `DB:StoreScannedPrice(itemID, copper, count)` / `DB:StoreVendorPrice(itemID, copper)` | feed the store yourself (another scanner, a captured merchant). Refuse junk (`false`) rather than storing it |
| `DB:GetScannedItemCount()` / `DB:GetLastScan()` | items priced for this realm + faction; `epoch, count` of the last full scan, or `nil` |
| `DB:GetScanRecord(itemID)` | **MINOR 47.** `copper, count, ageSeconds` for an item the **most recent** full scan for this realm + faction saw listed (or a scan stored after it), else `nil`. Unlike `GetScanListings` it answers after the Auction House closes and across a reload. `copper` is the per-unit lowest buyout; `count` the listings it came from (`1` when the scanner did not say). **`nil` for an item only an earlier scan saw** -- the last scan did not find it listed -- even though `GetPrice` still answers with that older figure; and `nil` when no full scan has completed here. A full scan stamps every item with the scan's own time, so the answer is exact rather than a time window (scans made before MINOR 47 stamped each item separately and may miss items until the next scan) |
| `DB:GetScanState()` | `{ running, kind = "full" \| "targeted" \| nil, scanned, total, lastScanAt, lastScanCount, auctionHouseOpen }` -- for a "resolving prices..." indicator. `scanned` / `total` count **items** for a targeted scan and **listings** for a full one; a full scan's `total` is `0` until the server's list arrives. Before MINOR 41 a full scan reported the last targeted scan's counters here |
| `DB:StartFullScan(auto)` | start the whole-house scan. `true`, or `false, "busy" \| "ah-closed" \| "no-api" \| "throttled"`. The Auction House must be open; the server allows a `getAll` roughly **once per 15 minutes per client**, shared with every other AH addon -- which is why auto-scan on open is off by default |
| `DB:StartTargetedScan(items, opts)` | scan a short list now: `items = { { itemId, itemName }, ... }` (queried by name on the legacy API; repeats queried once), `opts.onProgress(scanned, total, item)`, `opts.onComplete(reason, results)`. Same refusals as above plus `"no-items"`. Results live for the AH session via `GetScanListings(itemID)` -- `{ listings, lowestBuyout, count, scannedAt }`, where `count == 0` means "looked, nobody is selling it" -- and every lowest buyout also lands in the store |
| `DB:GetScanListings(itemID)` | what a scan saw for one item this AH session, or `nil`: `{ listings?, lowestBuyout, count, scannedAt }`. **`count == 0` is not `nil`** -- it means the scan looked and nobody was selling, which is a different fact from never having looked, and a "no sellers" message should use it rather than treating both as unknown. Answers from the targeted scan's results first, then from the **full** scan's record for that item while the Auction House is open; once it closes, only targeted results remain |
| `DB:CancelScan()` / `DB:IsScanning()` / `DB:IsFullScanning()` / `DB:ClearScanResults()` | targeted-scan control, the two flags, and "forget this session's targeted results" (the Auction House closing does that itself; the store is untouched) |
| `DB:IsAuctionHouseOpen()` / `DB:AuctionHouseSearch(itemName)` | the open state, and "switch the open AH to Browse and search for this name" -- the user sees the live results; nothing is bought |
| `DB:GetEffectiveScanDelay()` | seconds between targeted queries: the account's setting, else 1.5s on Classic Era and 3.0s elsewhere |
| `DB:GetPriceSetting(key)` / `DB:SetPriceSetting(key, value)` | the account's preferences: `useOwnScan`, `autoScan`, `scanDelay` (0 = client default, else 0.5-10), `useAuctionator`, `useAuctionatorHistorical`, `useAuctioneer`, `useAuctioneerCached`, `useTSM`, `useTSMAppHelper`, `defaultStatistic`. The setter validates and answers `false, reason`; `useAuctionator` / `useAuctioneer` going off take their fallback with them (`useTSMAppHelper` is TSM's primary half, not a fallback, and stays) |
| `DB:GetPriceSourceOrder()` / `DB:SetPriceSourceOrder(list)` / `DB:MovePriceSource(id, delta)` | precedence. Unknown ids are dropped, an omitted built-in is appended and an omitted fed source goes first, so the result is always a complete permutation |
| `DB:GetPriceStatistics()` / `DB:GetPriceStatisticLabel(id)` | `{ { id, label }, ... }` for a picker, and one label |
| `DB:FormatMoney(copper)` / `DB:FormatPriceAge(seconds)` | the client's coin string (plain text offline); `"never"` / `"just now"` / `"5m"` / `"2h 14m"` / `"3d 4h"` |
| `DB:TogglePriceWindow()` / `DB:OpenPriceWindow()` | the configuration window (also `/itemdb`). Built on first open; `nil` if LibAceGUIWidgets is missing |

**Callbacks** (CallbackHandler-1.0, so `DB.RegisterCallback(owner, event, fn)`
/ `DB.UnregisterCallback(owner, event)`): `LibItemDB_ScanComplete(kind, reason,
results)`, `LibItemDB_ScanProgress(kind, scanned, total, item)`,
`LibItemDB_AuctionHouse(isOpen)`, `LibItemDB_PriceSettingsChanged(key, value)`
-- `key` is a settings key, `"order"`, or `"external"` with the fed source id as
`value` (fed, cleared or toggled). Subscribe rather than poll.

`LibItemDB_ScanProgress` fires for both kinds. **Targeted:** before each
query, `scanned` / `total` are items and `item` is the `{ itemId, itemName }`
about to be queried. **Full (MINOR 41):** after each 500-listing batch,
`scanned` / `total` are listings read / listings returned and `item` is `nil`;
the last one has `scanned == total` (an empty house fires one `0, 0`), and
`LibItemDB_ScanComplete("full", ...)` follows. Nothing fires between starting a
full scan and the server's list arriving -- there is no count to report yet.
Before MINOR 41 full-scan progress was poll-only.

### Fed sources -- a price list from outside this client

**MINOR 26.** Your addon has a price list the library cannot see -- a guild's
published one, say, so every banker values a donation at the same figure
regardless of which price addons they run -- and you want it to ride the same
ladder every consumer already calls, rather than consulting it yourself before
every `GetPrice`. Feed it:

```lua
if DB.StoreExternalPrices then                      -- feature-gate on the method
    local n = DB:StoreExternalPrices("guildpricelist", "guild list (Pimptasty)", {
        [13468] = { market = 1250000, historical = 1100000, at = 1789000000 },
        [2770]  = { minBuyout = 550, at = 1789000000 },
    })
    -- ...and when the list is withdrawn or superseded by another authority:
    DB:ClearExternalPrices("guildpricelist")
end
```

- **`sourceID`** is a short id of your choosing; not one of the built-in ids
  (`auctionator`, `auctioneer`, `tsm`, `scan`). **`sourceName`** is the display
  text for the window's row; it is remembered from the last feed that gave one.
- **`entries`** is `{ [itemID] = { minBuyout = copper|nil, market = copper|nil,
  historical = copper|nil, at = epoch|nil } }` -- the same three statistic
  names as everywhere else, only the ones you have. Each is kept as a positive
  number rounded to whole copper; a non-number, a zero or a negative is dropped
  exactly as `StoreScannedPrice` drops it, and an entry with nothing left is not
  stored. `at` is when the figure was observed; an entry without one is dated by
  the newest `at` in the list, or by the feed itself if no entry carries one.
- **A feed REPLACES the source's whole table** for the current realm + faction.
  It is the list, not a delta. It is kept in `LibItemDB_PriceDB` beside the own
  scan, so it survives a reload, and a list fed on one realm never answers on
  another.
- **It is a source like the others.** It appears in `GetPriceSources` and the
  `/itemdb` window with `external = true`, a toggle (on by default, the user's
  to flip), a precedence the user can change, the statistics any entry carries,
  and the age of its newest figure. Lookups answer from it under the ladder's
  rules -- a named statistic only from an entry that carries it, `best` walking
  `minBuyout`, `market`, `historical` -- with provenance `{ source = sourceID,
  sourceName, statistic, age, at }`.
- **Default precedence FIRST**, the first time an id is fed: a guild list
  exists precisely to override the client's own view. After that the user's
  order stands, and a later feed of the same id lands where they put it.
  (So never feed on the machine whose sources _are_ the list -- a fed copy
  ranked first would hand the next build yesterday's figures as today's.
  `ClearExternalPrices` there instead.)
- **`ClearExternalPrices` drops the data, not the row.** The source keeps its
  toggle and precedence, shows as not detected until fed again, and the next
  feed of the same id lands where the user left it.
- `LibItemDB_PriceSettingsChanged("external", sourceID)` fires on every feed,
  clear and toggle, so redraw on that rather than polling.

**The window** -- `/itemdb` -- is where a player sets all of the above: one row
per source (detected / enabled / statistics / data age / order, with a
right-click menu for each source's extra toggles), the default statistic,
auto-scan, the scan delay,
and **Scan now** with the last scan's age. The Auction House also gets an
**ItemDB Scan** button. `/itemdb scan` starts a scan; `/itemdb price <id, link
or name> [statistic]` prints what the ladder answers, with its provenance.

**Not here, on purpose**: crafting-cost maths (a reagent is costed at its vendor
price even when someone lists it on the AH -- that is a profession addon's
policy), stale thresholds, and anything guild-synced.

## For addon authors

LibItemDB registers as a LibStub library. Depend on it (or list it as an
optional dependency) and query it:

```lua
local DB = LibStub("LibItemDB-1.0", true)
if DB and DB:IsReady() then
    local link  = DB:GetLink(19019)         -- coloured, interactive Thunderfury link
    local id    = DB:GetID("Black Lotus")   -- 13468
    local stats = DB:GetStats(13468)        -- { ITEM_MOD_..._SHORT = n, ... }

    -- plate (classID 4, subClassID 4) carrying strength
    for _, r in ipairs(DB:Search({ classID = 4, subClassID = 4, stat = "STRENGTH" })) do
        print(r.id, r.link, r.itemLevel)
    end

    -- where it drops, and how often: each boss row carries `rate` (percent) when known
    for _, src in ipairs(DB:GetSources(18814)) do print(src.instance, src.boss, src.rate) end
    local pct = DB:GetDropRate(18814, 11502)    -- the same number for one pair; nil = unknown

    -- can THIS character use it: the class tag AND the class's proficiency at their level
    -- (a hunter and a mace: false). Not the required level, not faction -- ask those separately.
    if DB.CanUse and DB:CanUse(18814) then ... end

    -- random suffix: field 8 of a modern link (e.g. Crystal Sword of the Bear)
    local p = DB:GetRandomProperty(1196)        -- { name="of the Bear", stats={"+6 Stamina","+7 Strength"} }
    local s = DB:BuildItemString(15218, 1196)   -- "item:15218::::::1196"
    GameTooltip:SetHyperlink(s)                 -- game renders the full, scaled tooltip

    -- buffs: enumerate a whole category (no hardcoded list) — raid / world / self / totem
    for _, b in ipairs(DB:GetBuffsInCategory("world")) do
        print(b.name, b.exclGroup, b.ranks[#b.ranks].stats)  -- all 8 Sayge's share one exclGroup
    end
    -- consumable buffs by our category (flask / elixir / potion / scroll / food / weapon / other)
    for _, c in ipairs(DB:GetConsumableBuffs("flask")) do print(c.name, c.stats) end
    -- source-buffs (Jujus, Badlands assays, Spirit of Zanza, Firewater, …) sit in "other";
    -- or fetch one directly by item id:
    local juju = DB:GetEffects(12451)           -- Juju Power: { ITEM_MOD_STRENGTH_SHORT = 30 }
end
```

### Consuming the library

This is the integration contract — everything another addon needs to consume LibItemDB. It is kept current
with every API/data change, so a consumer can re-ingest this section wholesale.

**Feature-gate.** `local DB = LibStub("LibItemDB-1.0", true)`, then guard what you use —
`if DB and DB:IsReady() then …` and `if DB.GetBuffsInCategory then …`. New APIs land at a higher library
`MINOR` (noted per feature in `CHANGELOG.md`); a player may have any version.

**Scope by expansion.** Item lookups, **consumable** use-effects + categories, hidden-item flags, the
price ladder and the proficiency rules ship for **Vanilla, TBC and Mists**. **Vanilla and TBC**
additionally ship the full drop graph with per-boss **drop rates**, item locations, reputation + PvP
rewards, item sets + set bonuses, class and faction restrictions, required levels, vendor buy / sell
prices, on-equip stats, on-use / proc effects, spell schools, mounts, aura buffs, talents + talent
effects, consumable exclusion groups, **EP stat weights** (so `GetItemScore` / `ScoreStats` /
`RankItems` / `GetSlotRanking` / `GetRaidBiS` work on both) and **fixed BiS lists** (TBC lacks hunter
lists, which WoWSims does not publish). **Mists** carries a drop graph of **80 instances / 5,501
items** — everything up to and including Wrath — with **no drop rates**, and with no Cataclysm or
Mists instances of its own: the upstream we build from (AtlasLootClassic) publishes `data.lua`,
`data-tbc.lua` and `data-wrath.lua` and nothing later. Until MINOR 33 it carried only Vanilla's 33. Feature-detect rather than branching on flavour — `if DB:HasSources() then`,
`if DB:HasBiSWeights() then`, `if DB.GetDropRate then` — and everything degrades to `nil` / empty rather
than erroring.

**`HasBiS()` and `HasBiSWeights()` are different questions.** EP weights and fixed BiS lists are separate
datasets, and TBC has the first without the second. Gate **scoring** on `HasBiSWeights()` and only
`GetBiS` / `IsBiS` / `GetBiSPhases` on `HasBiS()` — gating scoring on `HasBiS()` silently shows no EP at
all on TBC even though the weights are loaded.

**Call cost, and the one way consumers actually blow a frame.** Every getter decodes one packed string,
so the library is cheap per call and what costs you is **volume**. Measured against the shipped Vanilla
data (17,604 items) on desktop Lua 5.1 — the client is slower, so treat these as a floor:
`GetInfo` ≈ 2 µs, `GetStats` ≈ 3.8 µs, `GetItemScore` ≈ 7.8 µs, `GetSlotRanking` with no `pool`
≈ 8.4 ms (slot-indexed, so all seventeen slots cost one database pass, not seventeen).

_The trap is not the lookup, it is the constant context you rebuild around it._ Scoring a few thousand
rows is fine; re-reading the player's equipped weapons, or re-scoring their worn gear, **once per row**
is not — that is what produced the `script ran too long` report v0.7.1 was written for. Hoist anything
that does not vary per row, and invalidate it on `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`
(filtered to `"player"`, or forty raiders swapping gear clear your cache continuously) **and**
`PLAYER_ENTERING_WORLD`. That last one is not optional: `GetInventoryItemID` answers `nil` for both
"slot empty" and "inventory has not loaded yet" and you cannot distinguish them, so a cache built
before login lands stays wrong for the whole session and no equipment event will fix it.

**Ranking ties are stable within a session** — equal-scoring items come back in the same order, so a
redrawn ranking does not reshuffle rows that did not change.

**Scoring is per-expansion, and so is the stat vocabulary it reads.** TBC replaced Vanilla's flat
percentages with combat ratings, so the two clients genuinely disagree about what a stat _is_. The library
ships one core plus a `Scoring/<Version>.lua` rules module, and a TOC loads exactly one — a Vanilla client
never has TBC's rules in memory. This matters to a consumer in two places: `GetWeightStats()` returns a
**different list per expansion** (build your weight editor from it, never from a hardcoded list), and the
same stat table can score differently on each client, correctly. `DB:GetScoringVersion()` returns
`"Vanilla"` / `"TBC"` / `"Wrath"` / `"Cata"` / `"Mists"` (the last three from v1.2.0) / `nil`;
`DB:HasScoring()` is the feature gate. Retail registers no scoring.

**`opts.attack` is a WEAPON-SWING channel and nothing else (MINOR 24).** A proc fires on one of four
things, and `GetProcEffect`'s `sc` says which: `"any"` (a weapon swing), `"spell"` (a cast),
`"periodic"` (one of your DoT/HoT ticks) or `"taken"` (you were struck). **Only `"any"` reads
`opts.attack.hitsPerSec`** — the other three resolve from the per-class model, because nothing in a
character sheet reports how often you cast, how often your DoTs tick, or how often a boss hits you.
This is a correctness property you can rely on: passing a faster weapon **cannot** raise the value of
Skullflame Shield or Timbal's Focusing Crystal. Pass `attack` as the real (or hypothetically swapped)
loadout and let the library route it; do not pre-scale it yourself to "compensate" for a proc type.

**`opts.schools` gates school-restricted spell damage, and is opt-in (MINOR 24).** Pass the set of
magic schools the spec actually casts — `{ fire = true, frost = true }`, a set, not a list — and an
item whose spell damage is school-restricted earns that EP only if the sets **intersect** (one match
is enough). Only the school-conditional key is dropped: the item's stamina, crit, set bonus, on-use
and proc are untouched. An item with no school tag is generic `+spell damage` and always counts, so
`nil` from `GetItemSchools` means _"not restricted"_, never _"unknown"_. **Omit the option and every
score is byte-identical to MINOR 23**, so adopting it is a deliberate act, never a surprise.

**The stat vocabulary — one decoder for every feature.** Every `stats` table (`GetStats`, `GetAuraBuff` /
`GetAuraBuffs`, `GetTalentEffect`, `GetConsumableBuffs`) uses these keys:

| Group | Keys | Apply as |
| --- | --- | --- |
| Flat stats | `ITEM_MOD_*_SHORT` (`STRENGTH`, `AGILITY`, `STAMINA`, `INTELLECT`, `SPIRIT`, `ATTACK_POWER`, `RANGED_ATTACK_POWER`, …), `ITEM_MOD_SPELL_POWER`, `ITEM_MOD_SPELL_HEALING_DONE_SHORT`, `ITEM_MOD_MANA_REGENERATION`, `RESISTANCEn_NAME` | add |
| Flat percentages / points — **Vanilla** | `CRIT_PCT`, `SPELL_CRIT_PCT`, `HIT_PCT`, `DODGE_PCT`, `PARRY_PCT`, `BLOCK_PCT`, `MELEE_HASTE_PCT`, `WEAPON_SKILL_*`, `DEFENSE` | add (already a percent / point value) |
| Combat ratings — **TBC** | `ITEM_MOD_HIT_RATING`, `ITEM_MOD_CRIT_RATING`, `ITEM_MOD_HASTE_RATING`, `ITEM_MOD_EXPERTISE_RATING`, `ITEM_MOD_RESILIENCE_RATING`, `ITEM_MOD_DEFENSE_SKILL_RATING`, `ITEM_MOD_DODGE_RATING`, `ITEM_MOD_PARRY_RATING`, `ITEM_MOD_BLOCK_RATING`, and the `_SPELL_` / `_MELEE_` / `_RANGED_` variants | add (a rating, **not** a percent — TBC gear carries no flat percentages, and Vanilla carries no ratings) |
| Gem sockets — **TBC** | `EMPTY_SOCKET_RED` / `_YELLOW` / `_BLUE` / `_META` / `_PRISMATIC` | a socket COUNT, not a stat. **Scored** as the best gem that fits it under the class/spec's own weights (so a red socket is worth more to a warrior than a mage). Socket _bonuses_ are not modelled, so it's an upper bound |
| Weapon speed | `MELEE_WEAPON_SPEED` (melee weapons), `WEAPON_SPEED` (ranged weapons) | seconds, the base swing speed. Not a stat to add: it describes the weapon (see _Scoring a sharpening stone_) |
| Consumable-only | `WEAPON_DAMAGE`, `HEALTH`, `MANA`, `ABSORBn` (school-absorb; `n`: 1 Holy, 2 Fire, 3 Nature, 4 Frost, 5 Shadow, 6 Arcane — same index as `RESISTANCEn`, where 0 = Armor) | add. `WEAPON_DAMAGE` is damage **per hit** on the weapon the stone is applied to, not DPS — see _Scoring a sharpening stone_ below |
| On-use only — **Vanilla, TBC** (MINOR 45) | `TARGET_ARMOR` (armour removed from your target, your own attacks only), `THREAT_REDUCTION_PCT` (melee/ranged threat reduced, percent), `SPELL_THREAT_REDUCTION_PCT` (spell threat reduced, percent) | in `GetUseEffect` rows only, never in `GetStats`. Positive = a reduction (Fetish of the Sand Reaver is `THREAT_REDUCTION_PCT=70`). See _Pricing armour and threat reduction_ below |
| On-use attack speed — **Vanilla, WoW Forever** | `MELEE_HASTE_PCT`, `RANGED_HASTE_PCT` in `GetUseEffect` rows (Kiss of the Spider is `20` of each for 15 s) | a percent faster swing / shot while the buff lasts. A buff carrying both is one buff: a spec gains from the half it fights with, not both. From TBC on the same trinkets carry `ITEM_MOD_HASTE_RATING` instead |
| **Percent — multiplicative** | `PCT_STRENGTH`, `PCT_AGILITY`, `PCT_STAMINA`, `PCT_INTELLECT`, `PCT_SPIRIT`, `PCT_ATTACK_POWER`, `PCT_ARMOR`, `PCT_DAMAGE` | **multiply** — `PCT_STRENGTH=10` = +10% on summed flat stats |

The only rule: treat `PCT_*` as multipliers, the two weapon-speed keys as a property of the weapon, and
everything else as a flat add.

**Buffs (raid / world / self / totem) — enumerate, don't hardcode.** `GetBuffCategories()` → the sections;
`GetBuffsInCategory(cat)` → `{ {cat, name, exclGroup, ranks={{spellID,stats},…}}, … }` sorted by name
(`ranks[#ranks]` = max rank). Single lookups: `GetAuraBuffs(name)`, `GetAuraBuff(spellID)`. Anything added
to the DB shows up automatically.

**Aura exclusion groups — the same "one active per slot" rule, for buffs (MINOR 31).** `exclGroup` on every
`GetAuraBuff` / `GetAuraBuffs` / `GetBuffsInCategory` row, or `GetAuraGroup(name)` for a single buff. Keyed
by buff **name**, because every rank of a buff shares the slot. Two buffs answering the same token cannot
both be active, so a raid-buff preset offers the pair **once**: `Blessing of Kings` and `Greater Blessing of
Kings` are both `blessing-of-kings`, and all eight `Sayge's Dark Fortune of …` are `sayges-fortune`. Every
other buff has a token of its own, which is a positive statement that nothing else shares its slot.
Five of the eight Sayge's are enumerated by the source outright; `Strength`, `Armor` and `Resistance`
are filed under the same slot on their shared name and single vendor source, which is a **curated**
extension over a closed set of eight rows rather than something the source states. The build output
names every slot it did not take from the version's own model, so that distinction stays visible.
`nil` means **no source names a slot for that buff** — _unknown_, never _"stacks with everything"_ — which
today is only the two hunter aspects (`Aspect of the Hawk` / `Aspect of the Monkey`: genuinely exclusive in
game, but WoWSims models them as a rotation choice rather than a buff slot, and we would rather say nothing
than ship a token we invented). Tokens are the WoWSims buff-proto field name, kebab-cased, so a totem reads
`strength-of-earth-totem` and Mark of the Wild reads `gift-of-the-wild`. **Totems each carry their own
token and never share one:** two shamans really can give two different totems, so no static exclusion
between them exists to state. Present on Vanilla, TBC and Forever.

**Consumables (potions / elixirs / flasks / food / stones / oils) — same shape.** Vanilla files every
consumable under one subclass, so **we** classify them: `GetConsumableCategories()` → `flask`, `elixir`,
`potion`, `scroll`, `food`, `weapon` (sharpening stones / oils), `other` (assays, jujus,
firewater, …); `GetConsumableBuffs(category)` → `{ {id, name, type, stats, exclGroup}, … }` sorted by
name (nil = all), `type` being that category. Single lookups: `GetEffects(id)`, `HasEffects(id)`. The buff
name can differ from the item name (Ground Scorpok Assay → "Strike of the Scorpok").

**Only real BUFFS are here.** A consumable that heals or restores over time rather than granting a stat
— every bandage, and potions like Dreamless Sleep — carries **no effect row at all**, so it won't appear
in `GetConsumableBuffs` and there is no `bandage` category in practice. A restore isn't a stat and must
never be summed into a stat total. `HEALTH` / `MANA` mean a **bigger max pool** (Flask of the Titans,
Flask of Distilled Wisdom), never a heal. The same goes for what food and drink do **while you sit**: a
plain drink (Refreshing Spring Water, Moonberry Juice) has no row, and a food's row is only its **Well Fed**
buff. A Well Fed buff that regenerates is real regen and is carried as `ITEM_MOD_MANA_REGENERATION` /
`ITEM_MOD_HEALTH_REGEN_SHORT` per 5 seconds (Nightfin Soup = 8 mp5, Poached Sunscale Salmon = 6 hp5).
`ScoreStats` / `GetItemScore` price hp5 as a heal on Vanilla and TBC: hp5 / 5 = healing per second,
x 3.5 = healing power, x the scale's healing weight -- so it is worth EP to a healer and 0 to a
scale with no healing weight. A protection potion's `ABSORBn` shield is priced as a health pool of that
size in every flavour with a scoring model (through Stamina at that flavour's HP per point on Vanilla,
Cata and Mists; through the scale's own `Health` weight on TBC and Wrath), so it is worth EP wherever
Stamina or Health is weighted. Magic resistance
(`RESISTANCEn` with n 1–6) is deliberately **not** priced and scores 0. Before MINOR 42 every drink carried its drinking tick as mp5 (Spring Water = 42 mp5, Blessed Sunfruit
Juice = 735 mp5 instead of its +10 Spirit); a consumer that summed those got wildly wrong totals.

**Consumable exclusion groups — "one active per slot".** WoW lets you hold only one of each _kind_ of
consumable buff at a time (one agility elixir, one strength source, one flask, one food, one attack-power
buff, …) but doesn't tag the grouping in the client DB2, so a buffs planner can't derive it from the game.
The lib carries it as `exclGroup` (on each `GetConsumableBuffs` row, or `GetConsumableGroup(id)` for a
single item): a stable token like `agility-elixir`, `strength-buff`, `attack-power-buff`, `armor-elixir`,
`health-elixir`, `spell-power-buff`, `fire-power-buff`, `frost-power-buff`, `shadow-power-buff`,
`mana-regen-elixir`, `flask`, `food`, `alcohol`, `hit-consumable`, `zanza-buff`, `potions`,
`weapon-imbue`, `explosive`, `sapper-explosive`, `conjured`, and per-school protection potions
`protection-<school>` (`protection-fire`, `protection-frost`, `protection-nature`, `protection-shadow`,
`protection-arcane`, `protection-holy`, `protection-all`). Two items with the same token are mutually
exclusive; enforce one selection per token. Most slots come from WoWSims (the same MIT data behind BiS).
Two are ItemDB's own rules: potions WoWSims leaves untyped join `potions` when the client gives them the
same potion cooldown that at least two thirds of WoWSims' potions share (Vanilla, TBC, Cata and Mists;
Wrath's WoWSims types no potions and Forever's split their cooldowns, so neither gets any), and every
school protection potion —
whether WoWSims typed it or not — is filed under its school, so a planner can pick Fire **and** Shadow
protection on every flavour. That the schools stack is inferred from the shared cooldown and pre-combat
use, **not verified in game**. Flask of Petrification (13506) is `flask` on TBC, has no group on Vanilla
or Forever (WoWSims does not type it there and it ships no Effects row), and is `protection-all` from
Wrath on, because the client itself renames it Potion of Petrification and moves it from the flask
subclass to potions there.
`exclGroup` is `nil` when the consumable isn't part of any exclusion slot.

`food` means **Well Fed**, and since MINOR 42 it covers every Well Fed food the game data describes, not
only the ones WoWSims offers: on Vanilla 67 items (was 11), on TBC 134. Those come from the item's own
spells — a food whose use passes through the eat/drink spell and leaves a lasting buff — so drinks,
rations and alcohol (`alcohol`, which stacks with Well Fed) are not in it. Seasonal (SoD) foods carry no
group, like every seasonal consumable.

**Scoring a sharpening stone / weightstone (MINOR 42; Vanilla, TBC, Wrath, Cata and Mists).** `WEAPON_DAMAGE` is flat damage
per hit, so it is DPS only once the weapon's swing speed is known. Pass it:

```lua
-- main-hand stone on a 2.6s sword
DB:ScoreStats(DB:GetEffects(12404), classID, spec, { attack = { weaponSpeed = 2.6 } })
-- off-hand stone: equipLoc picks the off-hand DPS weight, offhandSpeed its speed
DB:ScoreStats(DB:GetEffects(12404), classID, spec,
    { equipLoc = "INVTYPE_WEAPONOFFHAND", attack = { weaponSpeed = 2.6, offhandSpeed = 1.5 } })
```

EP = damage ÷ speed × the hand's weapon-DPS weight (`DPS_MAINHAND`, or `DPS_OFFHAND` for
`INVTYPE_WEAPONOFFHAND`), the same weight the weapon's own DPS goes through. `offhandSpeed` falls back to
`weaponSpeed`. **No speed, no score:** without one the stone answers 0 rather than a guessed number; a
ranged `equipLoc` also answers 0. It is a lower bound — instant attacks that add weapon damage (Sinister
Strike, Heroic Strike) take the bonus too and are not modelled. Feature-detect with
`DB.SCORE_WEAPON_DAMAGE`.

**The speed of a weapon the player is not wearing** is in its own stats: `GetStats(id).MELEE_WEAPON_SPEED`
(seconds, the base swing speed, not haste-adjusted) on every one-hand, two-hand, main-hand and off-hand
weapon, and `WEAPON_SPEED` on bows, guns, crossbows, thrown and wands. Shipped since v1.2.0 on every
flavour. The two keys are deliberately separate: `WEAPON_SPEED` has meant ranged speed since it shipped,
and the key is what tells a hunter's bow from a polearm the hunter could also equip. So for a planned
main hand, `attack = { weaponSpeed = DB:GetStats(mainID).MELEE_WEAPON_SPEED }`.

**Which weapons a stone fits** comes from `GetImbueWeapons(id)` (also the `weapons` field of its
`GetConsumableBuffs` row): `Axe`, `Dagger`, `Polearm`, `Sword` for a sharpening stone, `Fist Weapon`,
`Mace`, `Staff` for a weightstone, matched against `GetItemType` of the weapon. `nil` means no weapon-type
rule, which is every oil.

`weapon-imbue` covers the oils, sharpening stones and weightstones, and it is **one token for both hands**
by design. WoWSims models a main-hand and an off-hand imbue as two independent fields, so an off-hand oil
really does apply alongside a main-hand one — but how many weapon slots a player has is a rule about the
player, not about the item, so the lib states membership and leaves "2H = one slot, dual-wield = two" to
you. The shaman and rogue imbues are **not** here: they are self-cast spells rather than items, and this
table is keyed by item id.

**Vocabulary by expansion.** Vanilla and Forever carry the fine per-slot tokens above; TBC carries the
coarser `battle-elixir` / `guardian-elixir` / `flask` split, which is the system that expansion actually
uses. Forever's set is smaller (`potions`, `flask`, `food`, `explosive`, `weapon-imbue`, `conjured`)
because WoWSims has not classified its battle/guardian elixirs yet — those ship with **no** token, which
means unclassified rather than unrestricted.

**"What is this stack of cloth for?" — the reagent → professions direction (MINOR 32).**
`GetReagentUses(itemID)` → `{ {id, name}, … }` sorted by name, or `nil` if no profession uses the
item as a material; `IsReagent(itemID)` is the cheap boolean for a tooltip hook that asks of every
item the player looks at. `id` is the client's skill line id and `name` is **enUS**, so a consumer
with a localised source resolves its own name from the id — the same arrangement `SourceNames` uses.
This is the reverse of a recipe's reagent list: `GetSources` says where an item _comes from_ and
LibProfessionDB says what a recipe _needs_, and until now nothing answered what a material is _for_.

**The library shows this itself, on the game's tooltips, with no consumer needed** — that is the
display half of folding SmexyMats in, and it is on by default (`SetReagentTooltipEnabled(false)`
turns it off, persistently). `AddReagentLines(tooltip, itemID)` puts the same line on **any** tooltip
frame, including one you drew: the frame is always the argument and is never looked up by name, which
is precisely the defect that made the old addon's handler useless on a custom tooltip. If you keep a
persistent tooltip of your own, `EnableReagentTooltip({ yourTooltip })` hooks it once instead of
calling per refresh.

The same call adds a **"Source:" line** above "Used by", the other half of what SmexyMats showed:
the gathering professions that yield the material first (Mining, Herbalism, Skinning, Fishing),
then Drop / Vendor / Crafted / Quest / PvP / Reputation, each word once. It is read from
`GetSources`, and it appears **only on reagents**, never on gear. It is left out when nothing is
known about where the item comes from; on Forever gathering is not known (see the `gathered` kind
below). In full, the block reads, top to bottom: an "ItemDB" heading, "Expansion:", "Source:",
"Used by:" and "Item ID:". Each is a `GetTooltipOption` setting, and the Item ID line is the one
drawn on every item rather than only on materials.

**`GetSources` rows gained a `gathered` kind (Vanilla, TBC and Mists).** On such a row `instance` is
the profession name (`"Mining"`, `"Herbalism"`, `"Skinning"`, `"Fishing"`, `"Enchanting"`
for what disenchanting yields, and from v1.2.0 `"Jewelcrafting"` for what prospecting yields and
`"Inscription"` for what milling yields) rather than a place. From v1.2.0 Wrath, Cata and Retail
carry it too. It is always **added to** an item's other
rows and never replaces one: Copper Ore is both `{ "World Drop", "drop" }` and
`{ "Mining", "gathered" }`. A consumer that switches on `source` should expect this kind, or skip
kinds it does not know.

**A `crafted` row's `instance` is now the profession that makes the item** on Vanilla and TBC
(`"Tailoring"` for Bolt of Linen, `"Mining"` for a smelted bar), which is what Forever's rows
already carried. It reads `"Crafted"` only when no profession teaches the spell. Match crafted
items by `source == "crafted"`, never by the `"Crafted"` string.

Both are derived from the client's own `SpellReagents` / `SkillLineAbility` / `SkillLine` tables,
not from LibProfessionDB's shipped data, so the two libraries are independent projections of one
source rather than two copies. Which skill lines count as professions is the client's
`SkillLine.CategoryID` (9 and 11), **not** a name list — class spell trees are category 7 and are
excluded, because their "reagents" are spell components rather than materials. Shipped for Vanilla
(469 items, 9 professions), TBC (618 / 10), Mists (969 / 17) and Forever (579 / 13); `nil` on a
version with no table means _no data_, never _"not a reagent"_.

**Talents.** `GetTalentClasses()` → classIDs with data; `GetTalentTree(classID)` returns the same `tree`
_shape_ the live `GetTalentInfo` API builds (tab in game order). `index` numbers a tab's talents by
(tier, column) and is internally consistent — `prereq` is a same-tab `index`. **If you overlay live-API
data** (e.g. the current character's points), correlate by `tier`/`column`/`spellID`, **not** the raw
index — the Classic `GetTalentInfo` index order isn't a documented guarantee. You fill `spec` and the icon
(from each talent's `spellID`).
`GetTalentEffect(classID, tab, index, rank)` → `{ stats, weapons }`; when `weapons` is present the effect
applies only while wielding one of those types (match against `GetItemType(item)`).

**Caveats.**

- **`nil` ≠ zero** — a getter returns `nil` / empty when the lib doesn't model something, not when the
  value is genuinely 0.
- **Hidden items stay queryable.** `GetStats` / `GetItemScore` answer for test / never-obtainable items
  (e.g. _Alex's Ring of Audacity_, 12947); **filter your own candidate lists with `DB:IsHidden(id)`**. The
  lib's own list APIs — `Search`, `GetSlotRanking`, `GetRaidBiS`, and `GetConsumableBuffs` — already drop
  them by default.
- **Not modelled** (absent, not zero): talent spell-property modifiers & procs; consumable heal-on-hit
  (Sheen of Zanza) and move-speed (Swiftness of Zanza); conditional vs-creature-type enchants (Consecrated
  Sharpening Stone).

### API

| Method | Returns |
| --- | --- |
| `DB:IsReady()` | `true` once core data for this client is loaded |
| `DB:Count()` | number of items in the database |
| `DB:GetMeta()` | `locale, build` the loaded data was captured for |
| `DB:GetSeason()` | the realm's `Enum.SeasonID` — `0` no season (Era), `2` Season of Discovery, `3` Hardcore, `11`/`12` Fresh/Anniversary. Feature-detected across the two namespaces different clients ship (`C_Seasons`, then `C_SeasonInfo`), and `0` when neither exists, so it is always a number |
| `DB:IsSeasonalRealm()` | `true` on the realms whose item range includes the seasonal additions (SoD and Fresh/Anniversary). This is what gates the `_seasonal/` overlay data files, so on an Era realm those items are simply absent rather than filtered |
| `DB:GetName(id)` | item name (active locale) |
| `DB:GetInfo(id)` | `name, quality, classID, subClassID, equipLoc, itemLevel, requiredLevel` — `requiredLevel` **appended in MINOR 14**; the first six are unchanged, so a caller written against six returns needs no edit |
| `DB:GetItemType(id)` | short display type, always populated (Sword / Staff / Ring / Neck / Off-Hand / Shield / Cloth / Potion / Arrow / Quiver / Bag / Mount …) — for a "Type" column that's never blank |
| `DB:GetQuality(id)` | item quality (0–7) |
| `DB:GetItemLevel(id)` | item level |
| `DB:GetRequiredLevel(id)` | **MINOR 14.** Required **player** level to equip/use — _not_ item level, and the two routinely differ (Thunderfury is ilvl 80, required level 60). `0` for an item with no requirement, `nil` for an id the DB doesn't have, so "no requirement" and "no data" stay distinguishable — use `or 0` if you want to collapse them. Sort a bank/bag on this rather than `GetItemLevel`, and you no longer need `GetItemInfo` (which returns `nil` on a cold cache and forces a retry loop) |
| `DB:GetVendorBasePrice(id)` | **MINOR 21.** What a vendor **charges you** for the item, in copper, or `nil`. Three things you cannot infer from the name, each of which fails as a plausible wrong number rather than an error: **(1)** this is the opposite direction to `GetItemInfo`'s `sellPrice`, which is what a vendor pays _you_ — the client has that natively and has no buy price at all outside an open merchant window (`GetMerchantItemInfo`), which is why this ships as data. **(2)** It is the **BASE** price — what a **Neutral** player pays. Reputation discounts are applied server-side at purchase and exist in no client table, so anyone above Neutral with the relevant faction pays less and the client is never told how much. Label it as a base/list price, or don't show it. **(3)** `nil` means **"no vendor record"** — it is _not_ proof that no vendor sells it. The gate is an emulator vendor dump from a **later expansion** (Wrath / Cata), so an item sold only by a Vanilla- or TBC-era vendor is absent while a vendor really does sell it; absence also covers a `BuyPrice` of 0 and an id this version doesn't ship. **Don't build a "not sold by vendors" label on top of `nil`.** Unlike `GetRequiredLevel`, `nil` does _not_ distinguish an unknown item — there is no third state to represent, because `0` is unreachable by construction (the builder requires `> 0` and the loader rejects `0`), whereas `GetRequiredLevel`'s `0` is a real domain value. Use `HasItem(id)` if you need to tell them apart. Coverage is Vanilla + TBC (862 / 1,708 items) |
| `DB:GetVendorSellPrice(id)` | **MINOR 22.** What a vendor **pays you**, in copper, or `nil`. The opposite direction to `GetVendorBasePrice` and roughly **4x smaller** — never substitute one for the other. `GetItemInfo`'s 11th return is the same number, but **only for an item the client has cached**; it is `nil` otherwise and forces a `GET_ITEM_INFO_RECEIVED` retry loop, which is exactly what this removes. `nil` here is a **clean** statement — the item has no sell value (a quest item, a token) — unlike buy price, because nothing gates it. **No reputation discount is applied**: faction discounts are believed buy-side only (the sources define them in terms of buying and are silent on selling), but that is _not_ verified and no client source can settle it, since the mechanic is entirely server-side. Coverage Vanilla + TBC (18,140 / 21,720 items) |
| `DB:GetStats(id)` | `{ GetItemStats key = value }` (e.g. `ITEM_MOD_STRENGTH_SHORT = 24`) — for gear the equipped stats (core **plus** the on-equip hit/crit/defense the game hides, and — since MINOR 43 — the school resistances `RESISTANCE1_NAME`..`RESISTANCE6_NAME` that Vanilla/TBC/Wrath's `GetItemStats` leaves out), for a consumable the buff it grants. **"+N physical damage"** (Might of Cenarius) is `ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT` on Vanilla, TBC, Wrath and Forever, although the game's own `GetItemStats` reports it as `ITEM_MOD_SPELL_DAMAGE_DONE` -- don't add it to spell damage. Mists still carries it as spell damage. **"Your attacks ignore N of your opponent's armor"** (TBC, e.g. Shady Dealer's Pantaloons) is `ITEM_MOD_IGNORE_ARMOR`, an ItemDB spelling with no client equivalent; the game reports it as `ITEM_MOD_SPELL_PENETRATION`, which is not what it is. `ITEM_MOD_SPELL_PENETRATION` is the tooltip value ("by 10"), one lower than the game's `GetItemStats` on Classic Era and TBC |
| `DB:GetEffects(id)` | just the **use-effect** (consumable) buff stats, decoded like `GetStats`. Empty table for an item with none, never `nil` |
| `DB:HasEffects(id)` | `true` if the item carries a use-effect row at all — the cheap check before `GetEffects` |
| `DB:GetLink(id)` | reconstructed coloured/interactive item link |
| `DB:HasItem(id)` | `true` if the id is known |
| `DB:GetID(name)` | first id whose name matches (exact, case-insensitive) |
| `DB:GetClasses()` / `DB:GetSubClasses(classID)` | categories present |
| `DB:Search(opts)` | array of matches (see below) |
| `DB:Iterate()` | `for id, name, quality, classID, subClassID, equipLoc, itemLevel in DB:Iterate()` |
| `DB:GetRandomProperty(propID)` | `{ name, stats = { line, ... } }` for a suffix tier |
| `DB:GetRandomProperties()` | `{ {id, name, stats}, ... }` of all suffix tiers |
| `DB:HasRandomProperty(propID)` | `true` if the suffix id is known |
| `DB:BuildItemString(id, propID, enchantID, gem1, gem2, gem3, gem4)` | `"item:id::::::propID"` for `SetHyperlink` (game renders stats). **`enchantID` and the four gem ids added in MINOR 15**, all optional and trailing, so two-argument callers are byte-identical. Layout after the id is `enchant:gem1:gem2:gem3:gem4:suffix` — `BuildItemString(10132, 863, 2504)` → `"item:10132:2504:::::863"`. `0` and `nil` both mean absent, and an id with nothing else collapses to `"item:<id>"`. **If you store links and rebuild them, pass the enchant** — omitting it silently renders the item unenchanted. Gems are TBC onward; Vanilla has no sockets, so those slots are inert there |
| `DB:GetSuffixLink(id, propID, enchantID, gem1, gem2, gem3, gem4)` | coloured/interactive suffixed link; same trailing optional fields, same MINOR 15 |
| `DB:ResolveSuffix(id, propID)` | full descriptor (base + suffix name, stats, link) |
| `DB:ResolveName(fullName)` | resolves "Black Lotus" or "Demon Blade of the Eagle" |
| `DB:GetSources(id)` | `{ {instanceKey, instance, boss, encounterID, source, rate}, ... }` — where it comes from: boss drop (with `instanceKey`/`boss`), or a `{instance, source}` origin where `source` is `quest`/`vendor`/`crafted`/`pvp`/`reputation`/`drop`/`gathered` (see the `gathered` kind above). **`rate` added in MINOR 27**: the drop chance from _that_ boss as a percent (`33`), present only on a boss row and only when known — absent means unknown, never 0%. Computed from the CMaNGOS server loot tables for every boss in the graph, Vanilla and TBC (heroic loot included), so it is the rate the emulator _rolls_, not a count observed on live realms — the two can differ where Blizzard re-tuned a table. A quest-gated drop (rolled only for a party holding the quest) has no single rate and carries none |
| `DB:GetDropRate(id, encounterID)` | the same number without building the list: percent, or `nil` when the pair is unknown. Nil-safe on either argument; `encounterID` may be the number or its string. **MINOR 27** — feature-gate on `if DB.GetDropRate then` |
| `DB:GetTokenRewards(id)` | **MINOR 44.** The gear a boss-dropped token is turned in for — `{ rewardItemID, ... }`, a **fresh table per call, sorted by item id**, or `nil` when the item is not a token (**never** an empty table). Every class's rewards are listed together (Desecrated Robe `22351` → `{ 22496, 22504, 22512 }`); read each one's level with `GetItemLevel` and its slot as `GetInfo`'s 5th return (`equipLoc`) — there is no `GetSlot`. Covers quest turn-ins (Naxxramas, AQ20/AQ40, Zul'Gurub, the boss heads — a turn-in that pays out through a follow-up quest is followed) and vendor exchanges (TBC T4–T6 and Sunwell, Wrath's Naxxramas and Ulduar tier tokens). Only rewards that exist on the running flavour are listed. **Ships for Vanilla, TBC, Wrath and Mists** (Mists: the Wrath-era tokens only today; Pandaria's own tier tokens are not built, and answer `nil`). Forever, Cata and Retail answer `nil` for everything. A "token" here is an item a boss drops that is not itself gear and is turned in, one per reward, for gear — a currency (Badge of Justice) or a crafting material is not one. Feature-gate on `if DB.GetTokenRewards then` |
| `DB:GetInstanceItems(instanceKey)` | `{ id, ... }` — every item that drops in the instance |
| `DB:GetInstances()` | `{ {key, name, bosses, source, expansion, kind}, ... }` — the instance list, sorted. **`expansion` added in MINOR 16**: `"Vanilla"` / `"TBC"` / … — the expansion the instance's CONTENT belongs to, _not_ the client serving it, so a TBC client returns Karazhan `"TBC"` **and** Molten Core `"Vanilla"`. `nil` where the shipped data predates the tag; treat that as "current expansion" (the flat-list behaviour you had before). **`kind` added in MINOR 33**: `"raid"` / `"dungeon"` / `nil` — see `GetInstanceKind` below for the contract, which is _not_ the same as `expansion`'s. **MINOR 34**: both `expansion` and `kind` are now served only for instances this list contains, so a key you read here and a key you ask about separately can no longer give different answers about whether a place exists. **`source`** names where the instance's loot list came from: `"atlasloot"` (Vanilla, TBC, Wrath, Mists, and Cata up to Wrath content), `"journal"` (the client's own Encounter Journal: all of Retail, and Cataclysm's own instances on Cata), `"atlasloot+journal"` (an instance both describe: Cata's four revamps, Deadmines, Shadowfang Keep, Zul'Gurub and Zul'Aman), `"wowsims"` and `"imenso"` (Forever). Treat it as provenance, not as a kind. **From v1.2.0** `expansion` also takes `"WoD"`, `"Legion"`, `"BfA"`, `"Shadowlands"`, `"Dragonflight"`, `"TWW"` and `"Midnight"`, on Retail |
| `DB:GetInstanceKind(instanceKey)` | **MINOR 33.** `"raid"` \| `"dungeon"` \| `nil` — what kind of place an instance is, so you do not keep your own set of our instance keys. **`nil` means UNKNOWN and must never be read as "not a raid"**, and keep that branch even though every shipped flavour now classifies every instance it lists: the promise is about what the data guarantees, not about today's coverage, and a flavour whose upstream gains an instance before it gains a `ContentType` puts you straight back into it. It is a FACT about the place, not a judgement about which raids count — our Vanilla data calls `UpperBlackrockSpire` a `"dungeon"` (AtlasLoot's own classification) and raid SIZE is deliberately flattened away, so "does this raid earn a badge" stays your rule. **MINOR 34**: a `kind` is only ever served for an instance `GetInstances()` also lists, so the two can no longer disagree about whether a place exists |
| `DB:GetInstanceEncounters(instanceKey)` | `{ {encounterID, boss}, ... }` — an instance's bosses, in order |
| `DB:GetLootModules()` | `{ {key, name}, ... }` — uniform loot browser: the source modules this client can populate (`instances` / `factions` / `pvp` / `collections`), non-empty only |
| `DB:GetLootCategories(moduleKey)` | `{ {key, name}, ... }` — a module's subcategories (each instance / faction / battleground, or "Class Sets"), sorted |
| `DB:GetLootSections(moduleKey, categoryKey)` | `{ {header, items={id,…}}, ... }` — the loot in display order; one section per boss (kill order) for instances, one per reputation tier (Friendly→Exalted) for pvp/factions, one per set for collections |
| `DB:HasSources(id)` / `DB:HasSourceData()` | `true` if the item / this client has drop data |
| `DB:GetItemSet(id)` | `setID, setName` if the item is part of a set |
| `DB:GetSet(setID)` | `{ id, name, items, bonuses = { [pieces] = {stats} }, procs = { [pieces] = {proc rows} } }` |
| `DB:GetSetBonusStats(setID, pieces)` | merged flat stats a set grants at N pieces |
| `DB:GetSetBonusEP(setID, classID, spec)` | `{ [threshold] = ep, … }` — EP of each set-bonus stage (flat **and** chance-on-hit proc); sum the stages you've equipped |
| `DB:GetBiS(classID, spec, phase [, source])` | `{ [SLOT]=itemID }` — the BiS set; default source `"wowsims"`. **Vanilla also ships `"bisclassic"` (MINOR 45)**: phases 0 (pre-raid) to 6 for nine classes, where `wowsims` stops early (hunter at phase 1). Its specs reuse the `wowsims` tokens where they mean the same spec (`default`, `tank`, `shadow`, `enhancement`, `balance`, `feral`) and add `tank_threat`, `melee_weave`, `daggers`, `holy`, `zero_sp`, `alternative`, `retribution_spell`, `feral_tank_*`, `restoration` plus resistance lists (`fire_resistance`, `nature_resistance`, …; paladin and shaman prefix the spec, e.g. `holy_fire_resistance`). **Two suffixes**, because the source's lists differ by race and weapon setup and one set must never mix them: where a spec's list differs by race, the group covering the most races keeps the plain token and every other group appends its races (`_human`, `_orc`, `_dwarf_nightelf`); and where the source offers both setups, the plain token is the one-hand setup (main hand + off hand) and `_2h` is the two-hander (e.g. warrior fury: `default`, `default_2h`, `default_human`, `default_human_2h`, `default_orc`, `default_orc_2h`; hunter: `default` = Orc / Tauren / Troll, `default_dwarf_nightelf`). A spec that offers one setup only (rogue, retribution, enhancement) has no `_2h`. Pick the token for the player's race and setup, and fall back to the plain one; `GetBiSSetSpecs(classID, "bisclassic")` lists the tokens a class has, so you never rebuild the naming rule. Detect it with `#DB:GetBiSPhases(3, "default", "bisclassic") > 0`. PvP-rank gear is not in it; random-suffix rankings collapse to the bare item id |
| `DB:IsBiS(itemID [, source])` | `{ {source, classID, spec, phase, slot}, ... }` — where it's BiS; empty table if never. A new list each call, safe to sort or trim (the hit records inside are shared: do not edit them). **One hit per spec token per phase**, so under `bisclassic` an item in all three warrior race groups' lists gives three hits a phase (MINOR 45) |
| `DB:GetItemFaction(id)` | `"Alliance"` / `"Horde"` / `nil` (usable by both) |
| `DB:FactionUsable(id)` | `true` if the player can use the item. **Reads as `true` in three different situations** and does not distinguish them: the item is neutral, the item's faction is unknown to us, or it matches your side. That is the right default for a filter — it never hides something you can actually use — but it means **absence of data is indistinguishable from "anyone can use it"**, so this call can never tell you the faction table failed to load. If you need to know whether a restriction is genuinely recorded, ask `GetItemFaction(id)` and check for `nil` |
| `DB:GetPlayerFaction()` | `"Alliance"` / `"Horde"`, or `nil` if the client cannot say |
| `DB:GetRequiredReputation(id)` | **MINOR 47.** `factionID, minStanding` for an item that needs reputation to buy or use, else `nil` (also `nil` for a non-number id). `factionID` is the client's, as `GetFactionInfoByID` takes it; `minStanding` is the client's **1-8** standing index (5 Friendly, 6 Honored, 7 Revered, 8 Exalted) -- compare it with the `standingID` the faction API returns. From the client's own item data (`MinFactionID` / `MinReputation`), not names. Shipped for Vanilla, TBC, Wrath, Cata, Mists and Forever; **not Retail**, whose renown and friendship factions do not use the 1-8 scale, so there it always answers `nil` |
| `DB:GetItemClasses(id)` | class bitmask the item is restricted to (bit = `2^(classID-1)`), or `nil` (any class). A **number**, not a string |
| `DB:ClassUsable(id, classID)` | `true` if that class (default: the player) can use the item. Same three-way `true` as `FactionUsable` — unrestricted, unknown class, or permitted. Carries the same live-player default trap described under `RaceUsable`: pass `classID` explicitly when the subject is a stored profile or an alt rather than the character at the keyboard |
| `DB:GetPlayerClass()` | the player's numeric `classID` (`UnitClass`'s 3rd return), or `nil` |
| `DB:GetItemRaces(id)` | **MINOR 30.** `low, high` — the race bitmask (bit = `2^(raceID-1)`) an item is restricted to, as **two 32-bit halves**, or `nil` for any race. On Vanilla and TBC `high` is always `nil` and you read `low` exactly as you read `GetItemClasses`. It is two values because `AllowableRace` is **64-bit** and Lua 5.1 has only doubles: Forever's race ids reach 96 and its faction masks set bits up to 64 (`6130900294268439629`), which a double cannot hold exactly — one number would round and every bit test against it would be silently wrong. Mists needs the high word on 2,545 of its 2,580 restricted items. Prefer `RaceUsable` unless you are rendering the mask |
| `DB:RaceUsable(id, raceID)` | **MINOR 30.** `true` if that race (default: the player's) can use the item. Same three-way `true` as `FactionUsable` and `ClassUsable` — unrestricted, unknown race, or permitted — so it **fails open** and a filter never hides gear a player can really use. Handles the high word itself, so a consumer never does 64-bit arithmetic. `GetItemRaces(id) == nil` is how you tell "no restriction" from "restricted and you qualify". **PASS `raceID` EXPLICITLY WHENEVER YOU ARE NOT JUDGING THE LOGGED-IN CHARACTER.** The default is the _live_ player's race, which is right for a bag or a vendor list and **wrong for a stored profile or an alt** — it would judge a saved night elf by whoever happens to be logged in, silently, returning a perfectly plausible boolean either way. If a stored profile has no race recorded, skip the check rather than letting it default: failing open is the honest answer, where judging a character by a different character is not. (Found by Dibs adopting this into alt planning, which a delivery here could not have seen.) |
| `DB:GetPlayerRace()` | the player's numeric `raceID` (`UnitRace`'s 3rd return), or `nil`. **MINOR 30** |
| `DB:GetPlayerLevel()` | the player's level (`UnitLevel`), or `nil` if the client cannot say. **MINOR 27** |
| `DB:ClassProficient(classID, itemClassID, subClassID, equipLoc, level)` | **MINOR 27.** Pure; no item lookup. `true` unless the class demonstrably lacks the _training_: armour material (Cloth 1 / Leather 2 / Mail 3 / Plate 4, on body slots only — cloaks, rings, necks, trinkets, held items pass for everyone), shields (Warrior / Paladin / Shaman), and weapon subclasses per class (a hunter and a mace: `false`). **Level-aware**: Mail for Hunter / Shaman and Plate for Warrior / Paladin arrive at 40, so below it the cap is one tier down; `nil` level means no level rule. Fails **open** wherever the tables have nothing to say: a `nil` class, a class off the table (Death Knight — in every branch, shields included), a non-armour/weapon item, or a `nil` subclass all answer `true`. Subclass `0` is a real value (1H axe; generic armour), never "unknown". Ids may be numbers or numeric strings. One table set for every flavour (Vanilla's rules); they are the fleet's pinned values, not read from the client |
| `DB:CanUse(id, classID, level)` | **MINOR 27.** `ClassUsable(id, classID) and ClassProficient(classID, <the item's class / subclass / equipLoc>, level)`. `classID` defaults to the player's, `level` to `GetPlayerLevel()`. Does **not** check the item's required level (you decide whether "not yet" means "not for me") and does **not** check faction (`FactionUsable` is separate; a guild bank must not apply it). An item the database does not know answers `true`. Both defaults read the LIVE player, so pass `classID` and `level` explicitly for a stored profile or an alt — see the trap under `RaceUsable` |
| `DB.PROFICIENCY` | the tables themselves, as data: `armorCap[classID]`, `armorTrainedAt40[classID]`, `shield[classID]`, `weapons[classID][subClassID]`, `bodyArmorLoc[equipLoc]`. Read them for a "which weapons can my class use" list instead of copying them. Constants |
| `DB:GetArmorCap(classID, level)` | the material that class may wear at that level (`1`..`4`), or `nil` for a class the table does not know. **MINOR 27** |
| `DB:GetItemSchools(id)` | `{ fire=true, … }` / `nil` — the magic school(s) an item's spell-damage bonus is restricted to (school-specific items only; generic `+spell damage` is `nil`). Gate the spell-damage EP to the matching spec |
| `DB:IsHidden(id)` | `true` for test/placeholder / never-implemented / removed-from-game items (kept in DB, not served in rankings/search) |
| `DB:GetUseEffect(id)` | `{ {k,m,d,cd}, ... }` — an equippable's on-use effects (stat, magnitude, buff secs, cooldown secs). Two things the numbers do not say: **(1)** an item whose use has charges and **no** cooldown (Classic Era's Manual Crowd Pummeler, 3 charges of +50% melee haste) carries `cd = 180`, ItemDB's modelled one use per fight, not a client value; it overstates an item whose charges run out. **(2)** Gear that casts a flask's, elixir's, food's or drink's own spell (Lapidis Tankard of Tidesippe; Cloak of Hidden Flasks, a Mists item) has **no** row — re-casting replaces the consumable's aura, so it adds nothing to what a player already runs |
| `DB:GetProcEffect(id)` | `{ {b,k,m,d,ppm/ch,icd,st,sc,pm,ws}, ... }` — chance-on-hit procs (bucket, magnitude, rate…). A spell that buffs several stats ships one row per stat, with the same rate fields (Shard of Contempt: an attack power row and a ranged attack power row; the library prices the pair once). On Wrath, a "+N spell power" effect ships as spell power alone — its equal healing half is the same bonus and is not shipped — so a Wrath healing row means healing beyond that spell's spell power. **`sc` says what SETS THE PROC OFF, and it is a real bit test as of MINOR 24** — one of `"any"` (a weapon swing), `"spell"` (a cast), `"periodic"` (one of your DoT/HoT ticks) or `"taken"` (you were struck). It is safe to branch on. Derived from `pm`, the raw DB2 `ProcTypeMask_0`, against the CMaNGOS/TrinityCore `PROC_FLAG_*` bits; a mask carrying both cast and swing bits resolves to `"any"`, because the effect does fire on melee and the swing rate is the only one a paperdoll can report. **`pm` still ships uninterpreted** — `sc` is a lossy flattening into one token, so if you need a distinction it does not draw (main-hand vs off-hand, healed vs damaged) read the mask. Treat an `sc` you do not recognise as `"any"`, which is what the library does. _Before MINOR 24 `sc` was a magnitude compare on a bitfield and was wrong in both directions; if you pinned a workaround against that, remove it._ **`ws` (MINOR 46) marks a STACKING WINDOW**: the proc opens a `d`-second window in which every further trigger adds one stack of `m`, up to `ws` stacks (Blackened Naaru Sliver: +44 attack power a hit, 10 stacks, 20 s; Death Knight's Anguish: +15 crit rating a stack). `m` is ONE stack, not the window's total — if you price a row yourself, multiply by the average stack count over the window at your own trigger rate, or the item is worth a tenth of what it should be. Absent on every other row. The library's own scorer does this |
| `DB:HasUnscoredProc(id)` | `true` if the item has a proc/utility effect not reflected in its EP (debuff/utility) |
| `DB:GetAuraBuff(spellID)` | `{ cat, name, exclGroup, stats }` — the stats a raid/world/self/totem BUFF grants (one rank), decoded like GetStats (buffs aren't items, so their magnitudes live here). Percent buffs (Kings, Zandalar, Sayge's, Mol'dar's) use a parallel `PCT_<STAT>` vocabulary — `PCT_STRENGTH=10` = +10% Strength, applied multiplicatively |
| `DB:GetAuraBuffs(name)` | `{ cat, name, exclGroup, ranks = { {spellID, stats}, … } }` sorted low→high — every rank of a named buff; the consumer serves whichever rank it wants (last = max) |
| `DB:GetAuraGroup(name)` | the buff's mutual-exclusion slot token (`blessing-of-kings`, `sayges-fortune`, `battle-shout`, …), or nil if no source names one. Keyed by buff **name** — every rank shares the slot. Two buffs with the same token can't both be active, so offer them as one pick. MINOR 31 |
| `DB:GetAuraSlots(name)` | **every** mutual-exclusion slot a buff fills, its `GetAuraGroup` slot first, then any extra ones in name order -- e.g. `{ "spell-power-pct", "crit" }` for Mists Arcane Brilliance, which fills two raid-buff categories. nil when the buff has no slot. A planner holding the buff treats all of them as filled. For such a buff, `GetAuraBuff` and each `GetAuraBuffs` rank also carry `slots = { [slot] = { KEY = val, … } }`, splitting its stats by slot so the second category is not counted on top of another buff that fills it; `slots` is absent for a one-slot buff. MINOR 39 |
| `DB:GetBuffCategories()` | sorted buff categories present — `{"raid","self","totem","world"}` |
| `DB:GetBuffsInCategory(cat)` | every buff in a category as `{ {cat,name,exclGroup,ranks}, … }` (GetAuraBuffs shape), sorted by name — drive a buff picker from the DB instead of a hand-kept list, grouping the rows by `exclGroup` for one pick per slot |
| `DB:GetConsumableCategories()` | sorted consumable categories **present** — today `elixir`, `flask`, `food`, `other` (assays, jujus, …), `potion`, `scroll`, `weapon` (stones/oils). **We** classify these (vanilla files every consumable under one subclass). Bandages are absent by design: they heal over time and grant no stat buff, so they carry no effect row |
| `DB:GetConsumableBuffs(category)` | consumables with a use-effect as `{ {id,name,type,stats,exclGroup,weapons}, … }` sorted by name (`type` = the category above; `stats` decodes like GetStats; `exclGroup` = mutual-exclusion slot, nil if none; `weapons` = `GetImbueWeapons(id)`); pass a category to restrict, nil for all |
| `DB:GetImbueWeapons(id)` | **MINOR 42.** The weapon types a sharpening stone / weightstone can be applied to, as a sorted list of `GetItemType` names (`{ "Axe", "Dagger", "Polearm", "Sword" }`), or `nil` when the item has no weapon-type rule — an oil (fits any weapon) or not a weapon imbue. Same shape as `GetTalentEffect`'s `weapons`; a fresh table per call. From the game's own rule on the stone's spell. Every flavour except Retail (Vanilla, TBC, Wrath, Cata, Mists, Forever), which ships no consumable Effects data |
| `DB:GetConsumableGroup(id)` | the consumable's mutual-exclusion slot token (`agility-elixir`, `flask`, `food`, `weapon-imbue`, …) for "one active per group" enforcement, or nil if ungrouped. Vanilla and Forever use per-slot tokens, TBC the `battle-elixir` / `guardian-elixir` / `flask` split. String or number id |
| `DB:GetReagentUses(id)` | `{ {id, name}, … }` sorted by name — the professions that use this item as a crafting **material**, or nil if none does. `id` is the client's skill line id of the PROFESSION (on Retail, a recipe on "Midnight Alchemy" reports Alchemy, 171); `name` is enUS. The reverse of a recipe's reagent list; on Retail it includes quality materials and optional reagents taken through crafting slots. MINOR 32 |
| `DB:IsReagent(id)` | `true` if any profession uses the item as a material — the cheap gate for a tooltip hook. nil data for a version means no table, never "not a reagent". MINOR 32 |
| `DB:GetExpansion(id)` | the expansion an item comes from, as the client's `LE_EXPANSION_*` number: `0` Classic, `1` The Burning Crusade, `2` Wrath, `3` Cataclysm, `4` Mists ... `11` Midnight. `nil` when the item is not shipped, when the expansion is not known (Retail, ~8,000 items), and on every item on Forever, which ships no expansion data. Up to Mists an item is the first of Vanilla, TBC, Wrath, Cata, Mists whose data ships it; past that (Retail only) it is Retail's own `ItemSparse.ExpansionID`. Every flavour but Forever from v1.2.0 (Vanilla and TBC since MINOR 35). **Reading `lib.expansionOf` directly:** a value of `-1` there means "not known", not an expansion. |
| `DB:GetItemPlaces(id)` | **where to get an item**, as an array of rows in display order (drops by chance, then vendors, then objects, then quest givers), or nil when none is shipped. Each row: `kind` (`"drop"` / `"vendor"` / `"object"` / `"quest"`), `id` (creature or gameobject entry), `questID` (`"quest"` rows: the quest that creature gives which rewards the item, or nil when not recorded; **MINOR 40**; an older library silently skips quest givers; a consumer decoding the packed tokens itself reads the letters from `DB.PLACE_KIND` -- `{ d = "drop", v = "vendor", g = "object", q = "quest" }`, read-only, MINOR 40 -- rather than keeping a copy), `name` (in the **client's language** -- deDE, esES, esMX, frFR, koKR, ruRU, zhCN, zhTW -- where the server database translates it, else English), `englishName` (always English: match on this, never on `name`, when comparing against other English data such as `GetSources`' boss names), `chance` (percent, drops and objects only; the chance **per kill or per loot**, not per hour), `questOnly` (true when it drops only while on a quest), `condition` (drops only; nil for a plain drop, else what else the server requires: `"Alliance"` / `"Horde"` for one faction's players, `"skill"` for a profession with its skill line id in `conditionSkill`, `"event"` for a world event or holiday, `"questDone"` / `"questTaken"` / `"questNotStarted"`, or `"other"`), `side` (creatures: `"A"`, `"H"`, `"AH"`, or `""` for hostile to both -- whether that side can talk to it), `profession` (objects: `"Mining"`, `"Herbalism"`, `"Fishing"`, or `""` for a plain chest), and `places`: `{ { uiMapID, count, points = { {x, y}, … } } }` for open-world zones, where `points` are **0-100** coordinates on that `uiMapID` (at most three per zone, standing for `count` spawns; `C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x/100, y/100))` gives world yards), or `{ instance, count }` inside an instance. Capped at 8 drops (highest chance first), 8 vendors (spread over sides and zones), 6 objects and 4 quest givers. Quest givers are **Retail only**, from the client's own collectable-source tables, so they cover items that are transmog appearances (gear), not materials or consumables; Retail vendors come from the same tables as well as TrinityCore's. Creature drops list only the loot table's own rows -- shared world-drop pools (random greens, world epics) name no creature. Fresh tables every call. Vanilla, TBC and Mists (Mists from SkyFire 5.4.8's world database: its Pandaria herb and ore nodes carry no loot table there, so those rows name the node's own yield with **no `chance`**). MINOR 36 |
| `DB:WhereStopTracking()` | stop whatever Questbook is guiding the player to, through Questbook's public `StopTracking`; `true` when something was stopped, `false` when nothing was or Questbook has no `StopTracking`. The window shows a stop icon beside its "i" for this only while Questbook offers it. MINOR 36 |
| `DB:OpenWhereWindow(item)` | open the **"Where to get it"** window on an item (`item` = an id, an item link, or any string with `item:<id>`): one row per place, from `GetItemPlaces` and `GetSources` together, with Source / Name / Zone / Chance / Spawns columns and a strip on top naming the item. Built on first use, reused after. Returns the window table, or nil for no item id, or (with a chat line) when LibAceGUIWidgets with `RowList` is missing. Players also open it by clicking any item with their chosen click -- **Alt+click** unless they change it (the `altClick` and `whereClick` tooltip settings) -- and with an **unbound key binding**, "Where to get the item under the mouse", under AddOns > LibItemDB. MINOR 36 |
| `DB:ParseClickBinding(binding)` | `canonical, mods` for a click binding string (`"shift-ctrl-RightButton"` -> `"CTRL-SHIFT-RightButton"`, `{ CTRL = true, SHIFT = true }`), or nil for anything that is not one: an unknown or repeated modifier, an unknown button, or **no modifier at all** (a plain click on an item is the game's own). MINOR 38 |
| `DB:ClickBindingText(binding?)` | that binding as a player reads it: `"Alt+Click"`, `"Ctrl+Shift+Right-Click"`, `"Alt+Button 4"`. `binding` omitted reads the stored `whereClick`. nil for a string that is not a binding. MINOR 38 |
| `DB:IsWhereClick()` | whether the click happening **right now** is the player's "Where to get it" click. Modifiers must match **exactly** (Ctrl+Alt is not Alt), so a combination another addon owns never opens it by overlap. The mouse button is compared where the client's `GetMouseButtonClicked` answers; where it does not, the modifiers alone decide. Does not look at `altClick`. MINOR 38 |
| `DB:WhereSearch(text)` | show the window's **search strip** results for `text`: every item whose name contains it (any case), sorted by name, capped at 100. Opens the window if needed, even with no item yet. A blank `text` goes back to the item's places. Players type in the strip at the top of the window (three letters, or Enter), or use `/itemdb where [id, link or name]`. Returns the window, or nil when LibAceGUIWidgets with `RowList` is missing. MINOR 36 |
| `DB:BuildWhereSearchRows(text)` | the search results without a window: `rows, capped`, each row `{ id, name (coloured link), plainName, typeName, subName, itemLevel }`. MINOR 36 |
| `DB:BuildWhereRows(id, faction?)` | the window's rows without a window: `{ {kind, name, zone, chance, chanceText, spawns, uiMapID, points}, … }`, bosses first, then drops, vendors, objects, then quest / crafted / reputation / PvP. `faction` (`"Alliance"` / `"Horde"`) drops the vendors that faction can't use and the drops only the other faction gets (`condition` `"Alliance"` / `"Horde"`). `chanceText` carries the condition as a suffix, e.g. `3.0% (Horde)`, `<0.1% (Blacksmithing)`, `5.0% (event)`. `zone` is the client's localized zone name (`C_Map.GetMapInfo`). MINOR 36 |
| `DB:WhereTrack(row)` | hand one of those rows to **Questbook**, when it is installed and offers `TrackPlace`, which guides the player there; the point used is the one nearest the player when they stand on that map. Returns true when Questbook took it, false otherwise (not installed, no point, or refused). MINOR 36 |
| `DB:GetTooltipSwitches()` | the names of the tooltip's on/off settings, sorted -- what a settings UI should offer a checkbox for. MINOR 35 |
| `DB:GetTooltipOption(key)` / `DB:SetTooltipOption(key, value)` | the reagent tooltip's settings, saved per account: `enabled` (default true), `header` (default true: a blank line and an "ItemDB" heading above the lines, drawn only on a frame with `AddLine`), `expansion` (default true: an "Expansion:" line first), `source` (default true: the "Source:" line), `usedBy` (default true: the "Used by:" line), `itemID` (default true: an "Item ID:" line last, on **every** item, not only materials), `icons` (default true: professions and source kinds drawn as game icons, a word with no icon stays a word), `iconSize` (default 20, clamped 8..64), `colorblind` (default false: when true every label is drawn in `color1` and every value in `color2`), `color1` / `color2` (six hex digits, default `"ffffff"`; anything else is refused), `altClick` (default true: the on/off switch for opening the "Where to get it" window by clicking an item; MINOR 36), `whereClick` (default `"ALT-LeftButton"`: **which** click that is, in WoW's binding spelling -- modifiers in `ALT`, `CTRL`, `SHIFT` order, then `LeftButton` / `RightButton` / `MiddleButton` / `Button4` / `Button5`; any case and order is accepted and stored canonical, and a click with no modifier is refused; MINOR 38). `Get` returns nil for an unknown key; `Set` returns false for an unknown key or before SavedVariables exist. The defaults are SmexyMats' own. Players change them on the **Tooltip** tab of `/itemdb`, where `whereClick` is set by performing the click on LibAceGUIWidgets' `LAGW-ClickBinding` control (LibAceGUIWidgets MINOR 38; an older copy gets a dropdown of combinations instead). MINOR 35 |
| `DB:AddReagentLines(tooltip, id?)` | append our block to **any** tooltip frame: an "ItemDB" heading, then "Expansion:", "Source:" (when the origin is known) and "Used by:" on materials, and "Item ID:" on every item, each switchable with `SetTooltipOption`. `id` omitted reads what the tooltip is showing. Safe to call twice for the same tooltip and item. Returns true only when a line was added. MINOR 32 |
| `DB:EnableReagentTooltip(frames?)` | attach the automatic hook; called once at load for the game's own tooltips. Pass `frames` to hook your own persistent tooltip instead. Idempotent; false means there was nothing to hook, which is not an error. MINOR 32 |
| `DB:IsReagentTooltipEnabled()` / `DB:SetReagentTooltipEnabled(on)` | the player's on/off switch for that line, persisted in the library's SavedVariables. Defaults to **on**. MINOR 32 |
| `DB:GetTalentTree(classID)` | `{ [tab] = { id, name, talents = { [index] = {tier,column,maxRank,name,spellID,prereq} } } }` — a class's full talent tree for an offline planner (any class, not just the logged-in one). `index` numbers a tab's talents by (tier,column), internally consistent (`prereq` is a same-tab index); to overlay live `GetTalentInfo` data, match by `tier`/`column`/`spellID`, not the raw index. `spellID` (rank 1) resolves icon/tooltip |
| `DB:GetTalentClasses()` | sorted class IDs that have talent data — for a class picker |
| `DB:GetTalentEffect(classID, tab, index, rank)` | `{ stats = {KEY=val,…}, weapons = {"Axe",…} or nil }` — the whole-character stat modifiers a talent grants at a rank (crit/hit/%stats/%AP/%armor/dodge/parry/block/defense/weapon-skill), so a planner folds a build into gear scoring. `weapons` (present ⇒ conditional) means "only while wielding one of these types" (match vs `GetItemType`). Passive talents only; spell-property mods, procs and conversions are absent |
| `DB:GetItemScore(id, classID, spec, opts)` | EP score (opts `setBonus`, `useEffects`, `usePremium`, `attack`, `schools`). **`schools` (MINOR 24)** = the magic schools this spec actually casts, as a **set**: `{ fire = true, frost = true }`, not a list. An item whose spell damage is school-restricted (see `GetItemSchools`) earns that EP only when your set and the item's **intersect**; one match is enough. Only the school-conditional keys are dropped — the item's stamina, crit and everything else still score, and so do its set bonus, on-use and proc, which carry no school of their own. An item with **no** school tag is generic `+spell damage` and always counts, so `nil` from `GetItemSchools` means _"not restricted"_, never _"unknown"_. **Omit `schools` and nothing changes** — every score is identical to MINOR 23. Vanilla and TBC. `attack` = paperdoll context for weapon-skill + proc scoring: `weaponType`/`weaponDPS` (melee), `rangedType`/`rangedDPS` (ranged, so a stat-stick's +ranged skill scores), `hitsPerSec`. **`weaponDPS` also prices an extra-attack proc on a non-weapon** (Hand of Justice; breakdown key `PROC_EXTRA_ATTACK`, from MINOR 46): extra attacks per main-hand swing × your white DPS × the spec's `DPS_MAINHAND` weight; a dual-wielder should also pass `attack.mainSwingsPerSec` (main-hand swings only), otherwise `hitsPerSec` is taken as the main-hand rate — melee only, so a hunter's ranged weight never prices it. Without `weaponDPS` the expansion's default white DPS is used: the weapon DPS of one raid two-hander, without attack power, so a floor (Vanilla and Forever 90, TBC 120, Wrath 223, Mists 4186); a flavour with no default (Cata, which ships no extra-attack row) prices it 0. **`hitsPerSec` deliberately does NOT reach a spell-triggered proc (MINOR 23)**: a paperdoll can only report weapon _swings_, and some set bonuses and trinkets fire on a **cast** (Vestments of Faith's 8-piece, on a priest's spells). Those are priced off the expansion's `castsPerSec` instead, so handing us a fast weapon can no longer inflate them. **Extended in MINOR 24 to every trigger a character sheet cannot report:** a proc that fires on a **DoT tick** (Timbal's Focusing Crystal, Ashtongue Talisman of Shadows) reads `ticksPerSec`, and one that fires **when you are struck** (Skullflame Shield, Freezing Band, Girdle of Reprisal, Darkmoon Card: Vengeance and ~20 more) reads `hitsTakenPerSec`. The rule is one line: **`hitsPerSec` is the only rate `opts.attack` can override, so only a swing-triggered proc reads it** — nothing in a paperdoll knows how often you cast, how often your DoTs tick, or how often you get hit. All four rates now ship per class in `ScoreModel.lua` (`hitsTakenPerSec` = 0.5, from the 2000 ms modal raid-boss swing timer; `ticksPerSec` = maintained DoTs ÷ 3 s, the measured tick period), so **a when-struck trinket no longer gets better when you equip a faster weapon** |
| `DB:GetItemScoreBreakdown(id, classID, spec, opts)` | `{ total, parts={ {kind,key,label,value,weight,ep,factors}, … } }` — itemized EP for a tooltip; `total` == `GetItemScore`, `Σ ep == total`. Takes the same `opts`, `schools` included: a gated stat is **omitted** from `parts` rather than shown as `0`, so you never render a misleading "Spell Damage = 0" row. `factors` = ordered `{label,value,pct?}` multiplicands whose product == the row's `ep` (renders the "how", e.g. `280 × 17% × 1.3 × 0.55`). **MINOR 29** adds `kind = "unpriced"` rows — a stat the item really carries that the active scoring rules have no vocabulary for, given as `{kind,key,value,ep=0}` with no `weight` or `factors`. It is not the same as a weight of `0`: a key the rules _know_ and this spec values at nothing stays omitted, as before, because that is a judgement rather than a blind spot. Today it fires on Forever, whose items carry `EXPERTISE` and `ARMOR_PENETRATION` while the client loads Vanilla's rules, which have neither stat. `Σ ep == total` still holds (these rows are `0`); feature-detect with `DB.SCORE_REPORTS_UNPRICED` rather than pinning the MINOR, and render them as "not valued by this scale" rather than as a score of zero |
| `opts.equipLoc` on the two above | **MINOR 30.** Score the item **as this slot** instead of the one it reports — pass `"INVTYPE_WEAPONOFFHAND"` to price a one-hander for the off-hand. A one-hander is `INVTYPE_WEAPON`, which every scale maps to `DPS_MAINHAND`, so without this the same item planned into either hand scored identically. Feeds the per-hand DPS weight **and** the proc damage bucket (a proc on an off-hand weapon fires at the off-hand's rate). Omit it and nothing changes; feature-detect on `DB.SCORE_OPTS_EQUIPLOC`. Note the scales themselves now weight `DPS_OFFHAND` at **half** `DPS_MAINHAND` — the engine's base off-hand damage multiplier, untalented — so this option produces a real difference rather than a cosmetic one |
| `DB:ScoreStats(stats, classID, spec, opts)` | EP of an **arbitrary stat table** (a buff / consumable / enchant / talent's stats), scored exactly as `GetItemScore` scores an item's own stats — same weights, same key folding, same melee-vs-ranged AP max-pairing, per-hand DPS and weapon-skill formula. `opts = { source, equipLoc, attack }`, all optional. **Use this instead of your own Σ stat × weight:** the effects data and the weight scales use different key spellings (`ITEM_MOD_MANA_REGENERATION` vs `ITEM_MOD_POWER_REGEN0_SHORT`, `ITEM_MOD_SPELL_POWER` vs `ITEM_MOD_SPELL_DAMAGE_DONE`) and the alias table that bridges them is private, so a hand-rolled sum silently scores every mp5 and spell-power consumable at **0**. Stat table only — set/use/proc effects are item-keyed, so use `GetItemScore` for a real item. Flat `HEALTH` / `MANA` pools are priced as the primary stat that delivers them (10 HP per Stamina, 15 mana per Intellect), since no weight scale carries a raw-pool weight; exact for physical specs, slightly generous for casters (Intellect also buys spell crit). `nil` if there are no weights for that class/spec |
| `DB:RankItems(pool, classID, spec, opts)` | **the ranking primitive the three below are built on.** `pool` = array of item ids; returns `{ {id, score, name, equipLoc, link}, … }` sorted best first. Items scoring **0 are omitted**, not listed last. `opts` takes everything `GetItemScore` does plus the filters: `slot` (one `equipLoc`), `max` (cap), `allFactions` / `allClasses` (default **off** — the pool is filtered to what this character can actually use), `includeHidden` (default off), and `keepDuplicates` (default off, so two items sharing a name **and** slot collapse to the best one; items sharing a name across _different_ slots are never collapsed) |
| `DB:GetRaidBiS(instanceKey, classID, spec, opts)` | an instance's drops ranked by EP — "what to want here". `setBonus` defaults **on** here, unlike `RankItems`; pass `perSlot` to group |
| `DB:GetSlotRanking(classID, spec, slot, opts)` | top-N (default 5) items for a slot, ranked. Considers the **whole database** when given no pool — via a per-`equipLoc` index built once, so calling it for every slot in turn costs one database walk, not one per slot. Items that score **equal** come back in a stable order within a session. (Both changed in addon v0.7.1 with no `MINOR` bump: same signature, same results, ~5x faster per call — nothing to feature-gate) |
| `DB:GetBiSItem(classID, spec, phase, slot, src)` | one slot's BiS item id, or `nil` |
| `DB:GetBiSPhases(classID, spec, src)` / `DB:GetBiSSpecs(classID, src)` | sorted phases a fixed set has / specs an **EP weight scale** has (`src` is a weight scale here). Empty table, never `nil` |
| `DB:GetBiSSetSpecs(classID [, src])` | sorted spec tokens a **fixed BiS set** source holds (default: the default set source) — includes `bisclassic`'s race and `_2h` tokens, which no weight scale has. Empty table, never `nil` (MINOR 45) |
| `DB:GetBiSSources()` | loaded **EP weight scale** names, sorted — what a scale picker lists |
| `DB:GetDefaultBiSSource()` / `DB:SetDefaultBiSSource(src)` | read / set the active weight scale. The setter returns `false` and changes nothing if that scale is not loaded |
| `DB:GetBiSWeights(classID, spec, src)` | the raw `{ statKey = weight }` table, or `nil`. Spec tokens are lowercase with underscores (`protection`, `feral_tank`). **Shaman `tank` (`[7].tank`, v1.5.0, Vanilla / TBC / Forever) is not HawsJon's:** HawsJon publishes none, so it is a copy of HawsJon's Protection Paladin scale without its off-hand weapon weight (`DPS_OFFHAND`), so an off-hand weapon never outscores a shield. Parry is included, because Classic and TBC Shamans learn parry from an Enhancement talent. Detect it by a non-`nil` return, not by `MINOR` |
| `DB:GetBiSWeightsInfo(src)` | **MINOR 28.** Provenance for a weight scale: `{ source = "hawsjon", authoredFor = "Vanilla" }`, or `nil` if that scale is not loaded. Omit `src` for the active default. `authoredFor` is the game version the scale was **tuned against**, which is not always the one you are running — Forever ships Classic's scale, so it reports `"Vanilla"`. It is `nil` for a scale that declared none (a player's own), and `nil` means **unknown**, never "matches your version". These are facts, not a verdict: compare `authoredFor` against your client and decide for yourself what to tell the player — the library deliberately ships no `tuned`/`trustworthy` boolean, because whether Classic's weights suit a Forever raider is the player's call, not ours |
| `DB:GetScoreModel(classID, spec, src)` | the resolved scoring constants for a class/spec (`usePremium`, `hitsPerSec`, `castsPerSec`, `ticksPerSec`, `hitsTakenPerSec`, `epPerRawDPS`, `epPerHPS`). Every key always has a value — per-spec overrides merge over the class default, which merges over the expansion's own model |
| `DB:GetWeightStats()` | `{ {key, label}, … }` — the stats **this expansion's** scale can set, in display order. Build a weight editor from this, never a hardcoded list (see the TBC section below). Empty when no `Scoring/` module is loaded |
| `DB:HasBiS()` | `true` once a fixed BiS **list** is loaded. Not the scoring gate — see `HasBiSWeights()` |
| `DB:LoadBiS(src,…)` / `DB:LoadBiSWeights(src,…)` / `DB:LoadScoreModel(src,…)` | register your own BiS list / EP weights / scoring constants. Each **merges** into the named source rather than replacing it, and the first `LoadBiS` source loaded becomes the default |
| `DB:GetGem(id)` | `{ colours = "RY", stats = {…} }` for a socket gem, or `nil`. `colours` is which socket colours it fits — `R`/`Y`/`B` (several for a hybrid), `M` for a meta gem, `C` for a cogwheel (Cata/Mists) or `H` for a Sha-Touched gem (Mists) — `C`/`H` since MINOR 46, before which those gems read `M`. **Shipped on TBC (132 gems) and Mists (605, MINOR 34); empty on Vanilla and Forever, which have no sockets.** A meta gem's special _effect_ (its "+3% critical damage" line) is not modelled — only the stats it also grants |
| `DB:GetGems()` | every gem as `{ [id] = {colours, stats} }` — for a gem picker, or to build your own best-gem-per-colour table |
| `DB:HasBiSWeights()` | `true` once an EP weight scale is loaded — **the gate for all scoring** (`GetItemScore`, `ScoreStats`, `RankItems`, `GetSlotRanking`, `GetRaidBiS`). Distinct from `HasBiS()`, which only covers fixed BiS lists; TBC has weights but no lists |
| `DB:GetScoringVersion()` | `"Vanilla"` / `"TBC"` / `nil` — which expansion's scoring rules this client loaded. Scoring behaviour and the `GetWeightStats` list follow from it |
| `DB:HasScoring()` | `true` once a `Scoring/<Version>.lua` module is registered. `false` on a flavour with no rules module (Retail), where every EP/BiS call returns `nil`. Wrath, Cata and Mists have rules from v1.2.0 |

`Search` `opts = { query, loose, classID, subClassID, quality, stat, minValue,
minLevel, maxLevel, max }`. Results carry `{ id, name, quality, classID,
subClassID, equipLoc, itemLevel, stats, typeName, subName, link }`, sorted by
name, with a `.capped` flag when the cap (`max`, default 300) is hit.

`query` is a case-insensitive substring of the name. **`loose = true` (MINOR 37)** also ignores
apostrophes, hyphens, colons and commas and folds runs of spaces, on both the query and the name,
so `"eko"` finds `"Frostsaber E'ko"` and `"sayges"` finds `"Sayge's ..."`. Without it the match is
exactly the plain substring it always was. An older library ignores the field, so it needs no
feature-gate -- but an older library also will not find `"eko"`. A query made only of those
characters (`"'"`) becomes empty under `loose` and matches every item, capped by `max`.

`stat` matches any stat key that CONTAINS it (case-insensitive), with a value of at least
`minValue` (default 1): `"CRIT"` finds melee and spell crit alike. So `"WEAPON_SPEED"` finds both
ranged weapons (`WEAPON_SPEED`) and, from v1.2.0, melee ones (`MELEE_WEAPON_SPEED`). To keep
only ranged weapons, filter the results on `stats.WEAPON_SPEED`.

**Random suffixes:** the modern Era client encodes a random suffix as a _positive_
`ItemRandomProperties` id in field 8 of the item link (`item:15218::::::1196`).
Each id is one suffix family at one fixed magnitude tier. The stats aren't
scaled by a formula — `BuildItemString(itemID, propID)` hands the game a link and
the client renders the correct tooltip itself, so a compact `(itemID, propID)`
pair fully reconstructs a suffixed item.

### Running on TBC — what a consumer needs to change

**Short version: nothing, if you already feature-detect.** TBC now ships the same data Vanilla
does, under the same API, so a consumer that gates on `HasSources()` / `HasBiSWeights()` / `if
DB.GetGem then` works on both with one code path. The list below is what actually differs, and
the three things that will silently misbehave if you assume Vanilla.

**1. Gate scoring on `HasBiSWeights()`, not `HasBiS()`.** These are different datasets. `HasBiS()`
covers only the fixed BiS gear lists (`GetBiS` / `IsBiS` / `GetBiSPhases`). Everything that
_scores_ — `GetItemScore`, `ScoreStats`, `RankItems`, `GetSlotRanking`, `GetRaidBiS` — needs
weights, and an expansion can have one without the other. Gating EP on `HasBiS()` is the single
most likely way to show no scores at all on a client that has perfectly good weights loaded.

**2. Build any weight editor from `GetWeightStats()`.** It returns a **different list per
expansion** and a hardcoded list will be wrong on one of them:

| | Vanilla | TBC |
| --- | --- | --- |
| accuracy / crit | `HIT_PCT`, `CRIT_PCT`, `SPELL_HIT_PCT`, `SPELL_CRIT_PCT` (flat %) | `ITEM_MOD_HIT_RATING`, `ITEM_MOD_CRIT_RATING`, `ITEM_MOD_HIT_SPELL_RATING`, `ITEM_MOD_CRIT_SPELL_RATING` (per rating point) |
| avoidance | `DODGE_PCT`, `PARRY_PCT`, `BLOCK_PCT`, `DEFENSE`, `BLOCK_VALUE` | `ITEM_MOD_DODGE_RATING`, `ITEM_MOD_PARRY_RATING`, `ITEM_MOD_BLOCK_RATING`, `ITEM_MOD_DEFENSE_SKILL_RATING` |
| TBC-only | — | `ITEM_MOD_HASTE_RATING`, `ITEM_MOD_HASTE_SPELL_RATING`, `ITEM_MOD_EXPERTISE_RATING`, `ITEM_MOD_RESILIENCE_RATING` |
| Vanilla-only | `WEAPON_SKILL_*` (16 keys), `RANGED_HASTE_PCT` | — |

`DB:GetScoringVersion()` returns `"Vanilla"` / `"TBC"` / `nil` if you need to label the UI.

**Melee + ranged rating twins count once.** One aura that improves both attack types is stored
under both spellings (TBC Gloves of Holy Might: `ITEM_MOD_CRIT_MELEE_RATING = 14` and
`ITEM_MOD_CRIT_RANGED_RATING = 14` for one "+14 crit" line). When both are present and the scale
prices them as one rating, scoring takes them once, like the melee / ranged attack-power pair: the
larger when they share a sign, the sum when they don't. Crit, hit and haste. Since v1.7.0 this
**lowers** the EP of every such item against earlier releases (it was counted twice), and the
breakdown shows one row under the unified key. `GetStats` still returns both spellings.

**Physical damage scores 0.** `ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT` is in the Vanilla (and so
Forever), TBC and Wrath `GetWeightStats()` lists (label "Physical Damage") with no shipped weight, because what +N damage per hit
is worth depends on weapon speed. Set a weight on it in your own scale if you want it priced.
`ITEM_MOD_IGNORE_ARMOR` ("Armor Ignored", TBC list only) also scores 0: no shipped scale is
confirmed to weight flat armour ignored per point.

From Wrath on, a flat percentage is priced through the one unified rating, **times the spec's share
of the attack family the key serves**: `SPELL_CRIT_PCT`, `SPELL_HIT_PCT` and `SPELL_HASTE_PCT` count
only as far as the spec uses spells, `CRIT_PCT` / `HIT_PCT` only as far as it fights physically,
`MELEE_HASTE_PCT` / `RANGED_HASTE_PCT` only for a melee or a ranged spec. The share follows the
**class / spec a weight table was loaded under** (`LoadBiSWeights`, from any source — yours
included): tanks and hybrids carry a **stated** share there, every tank and retribution counting as
melee (0 spell) and enhancement as 0.3 spell. Both values are estimates, not simulation results. A
spec with no stated share has it read off the table's own weights: spell power against attack
power, or Intellect against Strength / Agility when it weights neither. So a pure caster or a pure
physical spec gets 1 or 0, and an unstated hybrid gets the ratio of its two weights. Registering one
table object under two specs names it by the last registration. A spell-crit-only buff is worth 0 to an
arms warrior; Burning Blossom's `CRIT_PCT=3,SPELL_CRIT_PCT=3` is worth one 3% crit to anyone, never
6%; a buff of +3% melee crit and -3% spell crit keeps its penalty for a caster. The breakdown row
lists the share as a factor when it is not 1. The same conversion now prices a % buff **inside** an
on-use or proc effect (a crit % proc used to score 0 from TBC on). Vanilla and TBC weight melee and
spell crit / hit separately and add them as before.

Detecting it: there is no capability flag. The family split ships in **MINOR 42** with the rest of
that release, so `select(2, LibStub:GetLibrary("LibItemDB-1.0")) >= 42` (or `DB.SCORE_WEAPON_DAMAGE`, which arrived in
the same MINOR) is the test. The `family` field of a Scoring module's `derived` rule is internal to
ItemDB's own Scoring files.

**Pricing armour and threat reduction (MINOR 45, Vanilla and TBC).** No weight table prices either,
and both amount to "N% more damage", so `ScoreStats` / `GetItemScore` price them through the spec's
own crit weight, taking 1% crit as 1% more damage (0.5% for spell crit, which adds half rather than
double). That is ItemDB's own model, not a community weight, and it is stated rather than simulated:

- `TARGET_ARMOR`: physical damage scales by `K / (A + K)`, so 1% more damage is `(A + K) / 100`
  armour. Vanilla uses `A = 3731` (a level-63 boss) and `K = 5500`, so 92 armour = 1% crit. TBC uses
  `A = 7685` (Magtheridon) and `K = 10557.5`, so 182 armour = 1% crit, converted through crit rating.
- `THREAT_REDUCTION_PCT` / `SPELL_THREAT_REDUCTION_PCT`: 1% less threat is priced as 1% more damage
  (a threat-capped DPS can push that much harder). That is an **upper bound**, because not every fight
  is threat-capped. Tanks (protection, feral tank, shaman tank) and healers (holy, discipline,
  restoration) score them at **0**. That exclusion reads the class and spec a scale was registered
  under with `LoadBiSWeights`; a scale you build yourself has no spec and is never excluded.
- A use effect that stacks a proc during its window (Badge of the Swarmguard: up to six stacks of
  -200 armour over 30 s) carries the **average** stack count at the proc rate CMaNGOS lists, not the
  cap: about 661 armour. Icon of Unyielding Courage (TBC, 600 armour for 20 s) is priced the same way.
  Like every use effect, the value is scaled by its uptime (duration / cooldown) and the scoring
  model's use premium. A use buff that lasts at least its cooldown is a flat stat, so it scores at
  uptime 1 with **no** premium, whatever premium the caller passed (MINOR 46; Mark of the Dragon
  Lord on Cata and Mists).

Before MINOR 45 these items carried no use effect, scored 0 and answered `HasUnscoredProc` true.

**3. Instance keys are per-expansion, and a later client carries the earlier expansions too.**
`GetInstances()` returns **59** instances on TBC — the 26 Outland ones (`Karazhan`, `BlackTemple`,
`SunwellPlateau`, …) **plus all 33 vanilla ones**, because Molten Core, BWL, AQ, Onyxia, ZG and
Naxxramas still exist and are still runnable at 70. Era returns the 33. **Any hardcoded set of
instance keys — a "which of these are raids" list, a raid-only BiS badge — is Vanilla-only and
must become data-driven or version-aware.** Read `entry.key` from `GetInstances()`, and
`entry.expansion` (MINOR 16) to group current-expansion content separately from older content
rather than guessing from the key.

**For the raid list specifically, `entry.kind` / `DB:GetInstanceKind(key)` (MINOR 33) is the
answer, and it exists because that hazard is not hypothetical.** On **WoW Forever** the keys are
numeric **zone ids**, not slugs like `MoltenCore` — so a hardcoded Vanilla set matches nothing
there, no instance classifies as a raid, and a raid-only feature silently disappears with no
error to notice. That is a real consumer defect, reported by Dibs against their own `RAID_KEYS`
(DIBSREQ-IDB-009), and it fails **closed and quiet**, which is the worst combination.
Two things to hold on to when you switch:

- **`nil` means UNKNOWN, never "not a raid".** Every instance we ship carries a kind today
  (Vanilla 33/33, TBC 59/59, Mists 80/80, Forever 24/24), but that is a fact about the current
  data and not a guarantee: an instance whose upstream carries no classification is absent here
  rather than guessed, and a consumer reading absence as a negative would reclassify it.
- **It is a fact, not a verdict.** Raid SIZE is flattened away on purpose, and we follow the
  upstream's classification even where a consumer would reasonably disagree. **The two cases to
  know about, because both have already bitten a consumer:**
  - `UpperBlackrockSpire` is `"dungeon"` — AtlasLoot's own classification, and UBRS is a
    10-player instance in Vanilla. If your feature counts it as a raid, that exception is yours.
  - **`WorldBosses` and `WorldBossesBC` are `"raid"`** (both keys on TBC and Mists; Vanilla ships
    only the first). These are AtlasLoot's synthetic groupings for Azuregos, Kazzak, Doomwalker
    and the like rather than places. **If you give world bosses a category of their own, test for
    them BEFORE you test for raid** — otherwise adopting `kind` silently makes that category
    unreachable, which is exactly what happened to Dibs and was caught by a spec rather than by
    running the code.

  The library will not make either call for you: reclassifying would break the consumer who wants
  world bosses counted as raid content, who is no less reasonable than the one who does not.

**New on TBC, absent on Vanilla:**

- **Gem sockets.** Items carry `EMPTY_SOCKET_RED` / `_YELLOW` / `_BLUE` / `_META` / `_PRISMATIC`
  as socket **counts**. `GetItemScore` already values them at the best gem that fits under that
  class/spec's weights, and `GetItemScoreBreakdown` emits a `kind = "socket"` row per colour, so
  a tooltip needs no extra work. `GetGem(id)` / `GetGems()` expose the gem table if you want to
  build a gem picker. Socket _bonuses_ are not modelled, so socket value is an upper bound.
  **Cata and Mists add two engineering-only sockets:** `EMPTY_SOCKET_COGWHEEL` (Cata and Mists,
  filled by cogwheel gems, `colours = "C"`) and `EMPTY_SOCKET_HYDRAULIC` (Mists, filled by
  Sha-Touched gems, `colours = "H"`). Before MINOR 46 both scored 0, and their gems were labelled
  `M` and counted toward meta sockets, so Cata/Mists meta-socket values were too high.
  `HasScoring()` is the flag to branch on, as always.
- **Elixir exclusion groups.** `GetConsumableGroup(id)` returns `battle-elixir`,
  `guardian-elixir` or `flask` on TBC (Vanilla returns its finer `agility-elixir` /
  `strength-buff` / … tokens). **The schema says "one active per group" but not cross-group
  exclusion — on TBC a flask also cancels both elixirs, and a consumer must apply that itself.**
- **Combat ratings in stat tables.** Anything reading `GetStats` keys directly (a paperdoll
  aggregator, an enchant parser) needs the `ITEM_MOD_*_RATING` keys above; a Vanilla-only key
  list silently drops the majority of TBC gear's secondary stats.

**Still Vanilla-only:** nothing in the data. Both expansions ship items, names, suffixes,
consumable effects, drop sources, item locations, reputation + PvP rewards, sets and set bonuses,
class and faction restrictions, on-equip stats, on-use/proc effects, spell schools, mounts,
hidden flags, talents, talent effects, aura buffs, consumable groups, EP weights and BiS lists.
The only gap is **hunter BiS lists on TBC**, which wowsims doesn't publish.

## Data layout

```text
Data/<Version>/_core/<Class>.lua      -- quality | sub | equip | itemLevel | stats  (loaded once)
Data/<Version>/_core/Sources.lua      -- item -> boss -> instance drop graph, from AtlasLoot  (loaded once)
Data/<Version>/_core/DropRates.lua    -- item -> boss -> drop chance (percent), from the CMaNGOS loot tables  (loaded once)
Data/<Version>/_core/TokenRewards.lua -- token -> the gear it is turned in for, from the world DB's quests and vendors  (loaded once)
Data/<Version>/_core/SourceNames.lua  -- instance + boss display names (English)  (loaded once)
Data/<Version>/_core/<Dataset>.lua    -- every other side-table (Sets, Classes, Factions, EquipStats, ReqLevels, ...)  (loaded once)
Data/Vanilla/_seasonal/<Class>.lua    -- the SoD / Anniversary overlay, guarded by lib:IsSeasonalRealm()
Data/<Version>/<locale>/Names.lua     -- id -> localized name  (GetLocale-guarded)
Data/<Version>/<locale>/RandomProps.lua  -- suffix names + stat lines  (GetLocale-guarded)
Scoring/<Version>.lua                 -- that expansion's SCORING RULES; a TOC loads exactly one
```

The **core** is locale-independent (stats/level/class), so it ships and parses
once. Only **names** and **suffix tables** are per-language; each guards on
`GetLocale()`, so only the active language loads. Names a language hasn't
translated fall back to English, so every locale is complete.

## Building / regenerating data

Stats come from a full client item-ID walk — the **Item DB** developer tool in
TOG Tools (Settings → General → Developer Tools) — because the client's
`GetItemStats` is the only complete, aggregated source (spell power, mp5,
resistances). classID and the localized names come from wago.tools. After
walking a game version's client, run (the `tools/` folder is excluded from the
packaged addon):

```sh
# Every builder takes the VERSION as its argument, so the whole pipeline is one pass per
# expansion -- swap TBC for Vanilla and re-run. Getting the version wrong is a quiet failure,
# not a loud one (you get another expansion's data), so each script picks its own sources from
# the version rather than inheriting a default.

# core + that client's own-locale names (run once per game version):
tools/build-core.py TBC
# every other language's names + all suffix tables (from wago):
tools/build-locales.py TBC --all
# consumable use-effect stats (from wago DB2):
tools/build-effects.py TBC
# drop sources (instance / boss) from AtlasLootClassic -- picks data.lua / data-tbc.lua /
# data-wrath.lua by version (data.lua is VANILLA only; reading it for TBC ships Molten Core
# as TBC's drop graph):
tools/build-sources.py TBC
# per-boss drop CHANCE (percent), computed from that expansion's CMaNGOS loot tables
# (creature_loot_template + reference_loot_template, the server's own roll rules) for every
# boss in Sources.lua, heroic loot merged. Needs the DB build-proc-rates.py downloads; reads the
# cached AtlasLoot files only to learn every creature id a boss block names:
tools/build-droprates.py TBC
# on-equip stats GetItemStats omits: hit/crit + defense/dodge/parry/block + weapon
# skill + spell pen + ranged haste (from DB2 auras), plus ammo added-ranged-DPS
# (AMMO_DAMAGE), ranged weapon speed (WEAPON_SPEED) and melee weapon speed (MELEE_WEAPON_SPEED):
tools/build-equip-stats.py TBC
# the magic school(s) a school-specific spell-damage item is restricted to (DB2 aura-13 school
# mask) — so a consumer gates spell-damage EP to the matching spec (a +Fire item -> fire mage, not frost):
tools/build-spell-schools.py TBC
# mount items (their on-use spell applies aura 78) — Classic files them as Junk, so GetItemType
# can type them as "Mount":
tools/build-mounts.py TBC
# CMaNGOS world DB: DOWNLOADS that expansion's DB (cmangos/<x>-db `latest` release) and resolves
# proc rates (PPM/chance) from it. Run before build-use-effects / build-sets / build-item-sources
# / build-consumable-groups, all of which read the same per-expansion DB:
tools/build-proc-rates.py TBC
# equippable on-use + chance-on-hit proc effects for EP scoring (uses that version's proc rates):
tools/build-use-effects.py TBC
# raid/world/self/totem BUFF-aura stats, every rank (buffs aren't items) — buff NAMES resolved to
# player-learnable ranks via wago SpellName + SkillLineAbility, stats from SpellEffect:
tools/build-aura-buffs.py TBC
# every class's talent tree STRUCTURE (Talents.lua) + per-rank stat EFFECTS (TalentEffects.lua) for an
# offline planner — from wago Talent + TalentTab + SpellName + SpellEffect + SpellEquippedItems + SpellMisc
# (the trees the live API only exposes for the current class; effects are passive-only, weapon-tagged):
tools/build-talents.py TBC
# Mists only, once: CMaNGOS stops at Wrath, so convert SkyFire 5.4.8's world-DB release
# (github.com/ProjectSkyfire/SkyFire_548 releases) to tools/cmangos_cache/mistsskyfire.sqlite:
tools/mysqldump-to-sqlite.py <dump.sql> tools/cmangos_cache/mistsskyfire.sqlite
# item source locations (quest/vendor/crafted/pvp/reputation/drop/gathered), from that expansion's
# CMaNGOS DB (SkyFire's on Mists):
tools/build-item-sources.py TBC
# where to get an item: the creatures that drop it (with chance), the vendors that sell it and the
# objects that yield it, each with zones + a few map points, plus PlaceNames.lua per language
# (CMaNGOS / SkyFire DB + wago UiMapAssignment; a spawn inside several overlapping zone
# rectangles takes the zone QuestieDB records for that creature/object -- fetch it first):
tools/fetch-questie.py
tools/build-item-places.py TBC
# reputation + PvP reward gear, from AtlasLoot's PvP/Factions modules (fetched per expansion).
# Vanilla groups by reputation tier; TBC by Honor / Arena season / zone, with class-set rows
# carrying ItemSet ids. Feeds GetSources + the loot browser:
tools/build-rep-loot.py TBC
# consumable "one active per group" slots. Vanilla: wowsims/classic typed inputs. TBC: the
# CMaNGOS spell_elixir table (battle / guardian / flask) -- it is in neither the DB2 nor
# spell_template:
tools/build-consumable-groups.py TBC
# socket gems + which colours they fit, from Pawn's per-expansion gem file. TBC onward only
# (Vanilla has no sockets); lets the scorer value an empty socket at the best gem that fits:
tools/build-gems.py TBC
# our (MIT) scoring-model constants — premium / proc rate / conversions:
tools/build-score-model.py TBC
# item sets + decoded set bonuses (DB2 ItemSet/ItemSetSpell; set procs use that version's DB):
tools/build-sets.py TBC
# fixed BiS gear lists per class/spec/phase (wowsims):
tools/build-bis.py TBC
# per-spec EP stat weights, incl. tank/avoidance (HawsJon, as shipped with Pawn). The scale is
# TBC-native: on Vanilla each rating weight is pre-multiplied into per-1% units, on TBC it stays
# per rating point, so the version picks both the multipliers AND the stat-key map:
tools/build-bis-weights.py TBC
# per-item Alliance/Horde restriction (from DB2):
tools/build-factions.py TBC
# per-item class restriction (AllowableClass + mis-flagged dungeon/AQ40/T3 sets):
tools/build-classes.py TBC
# flag test/placeholder + above-cap + the AllTheThings never-implemented / removed-with-patch
# lists (via tools/att_extract.lua, if ATT is installed) + a hand-curated backstop
# (tools/curated_hidden.py) — kept in DB, not served:
tools/build-hidden.py TBC
# required player level, from wago ItemSparse (run before split-seasonal so it gets partitioned):
tools/build-req-levels.py Vanilla
# vendor BUY price, wago ItemSparse.BuyPrice gated on emulator npc_vendor. Needs the
# npc_vendor dumps: read from a sibling ProfessionDB install, or tools/emulator_data/:
tools/build-vendor-prices.py Vanilla
# LAST, Vanilla only: partition original-Classic base vs SoD/Anniversary overlay.
# Builders read base + _seasonal ids (except the few whose tables this never partitions --
# Tests/seasonal_ids_check.py's EXEMPT), so rebuilding one table after a split is safe;
# re-run this afterwards to move its seasonal rows back into the overlay:
tools/split-seasonal.py Vanilla
```

The 1.15 client's data is a superset — original vanilla items **plus** the SoD /
Fresh-Anniversary reissues (ID >= 25000, mostly 200000+). `split-seasonal.py` moves
those into `Data/<Version>/_seasonal/`, guarded by `lib:IsSeasonalRealm()`
(`C_Seasons.GetActiveSeason` / `C_SeasonInfo`), so an **Era / Hardcore** realm loads
only the original-Classic items while **SoD / Fresh** realms also load the overlay —
consumers get the right set automatically. Run it **after** the other builders.

An item is seasonal when its ID is at/above the threshold **and** AllTheThings does not
place it in this era's own tree. The ID alone conflates "high item ID" with "seasonal
realm": items added to Classic **Era** sit above the line too, and were being hidden on
Era — Chronoboon Displacer (184937) among them. The client's data carries no flag
separating an Era addition from a SoD one, so that fact comes from ATT's curated
`db/Vanilla` vs `db/VanillaSOD` trees (the same source `build-hidden.py` already uses).
ATT coverage is partial by design, so membership only ever **keeps** an item in base and
never pushes one into the overlay; with ATT absent the build degrades to the previous
threshold-only behaviour. The script re-partitions the **union** of both sides, so it is
idempotent and a rule change can move items either way.

The pipeline is **version-aware**: pass just the Version. It reads
`<WoW>/.build.info`, finds the installed client whose build MAJOR maps to that
Version (1→Vanilla, 2→TBC, 3→Wrath, 4→Cata, 5→Mists), auto-locates that client's
walk SavedVariables, and fetches classID/names/suffixes from the matching wago
build — so it tracks the progressing Anniversary client automatically. Override
with `--sv` / `--wago-build` if needed. Stats/levels are locale-independent, so
you only walk **once per game version**; languages come from wago.

**Drop sources** don't need a walk. `build-sources.py` builds the whole
instance → boss → items graph from AtlasLootClassic's Classic loot tables,
intersected with the version's `_core` so a version only carries drops for items
it ships. (The Classic client has no Dungeon Journal, and the Retail Journal was
audited to be ~40% incomplete for Classic — `tools/audit-sources.py` keeps that
Journal comparison around as a cross-check, but it isn't shipped.) **Drop rates** are
computed by `build-droprates.py` from the **CMaNGOS** loot tables — the same world database
the proc rates and locations come from — by porting the server's roll rules (independent
non-grouped entries, one pick per group with explicit chances tried before an even split of
the rest, references processed `maxcount` times), for every boss npcID in the graph — a boss
whose loot the emulator keeps on a chest (Majordomo, the Four Horsemen) is matched to that
chest by item overlap — so `GetSources` rows carry a `rate` and `GetDropRate` answers a pair
directly. A consumer must
not read AtlasLoot live for this — the whole point is that an item fact does not depend on
which other addons a player has installed.

**Source locations** (Vanilla, TBC and Mists) fill the gap the boss graph leaves.
`build-item-sources.py` reads the **CMaNGOS** server DB (SkyFire 5.4.8's on Mists) and derives every item's real origin — quest (→ the giver's
instance, else the quest zone), vendor, crafted (create-item spell), world drop, plus PvP-rank
(→ `PvP`) and reputation (→ the faction) from wago `ItemSparse` — into `_core/ItemLocations.lua`.
Honor/mark gear sold by a battleground reward vendor reads that battleground, **unless a vendor
outside a battleground also sells the item** — so common food, water and reagents a quartermaster
happens to stock keep their real vendors and quests (fixed in v1.1.4). Instance names are
normalized to the AtlasLoot `SourceNames` spelling (`NAME_ALIAS`, e.g. _Temple of Ahn'Qiraj_)
so the two graphs agree. `GetSources` merges the locations under the boss graph so nothing reads
"Other"; boss drops keep their full detail, and each place shows once — a location whose instance
is already shown (by the boss graph or an earlier location) is collapsed.

## Testing

Offline, local, zero-dependency. From the repo root:

```text
lua Tests/wowapi/run.lua
```

`run.lua` lives in the **WoWAPITesting** harness, in as a git submodule at
`Tests/wowapi`, and needs only a Lua 5.1 interpreter. It prints a per-spec
pass/fail list ending in a `N passed, N failed, N pending` summary.

**Do not install or use `busted`.** The `.busted` file in the root is vestigial
config, not the entry point; if `busted` isn't on PATH that is expected and is
not a problem to solve. **There is no CI test job and none should be added** —
one developer, and a failing test has to stop the change locally, before it
lands. `.github/workflows/` does packaging only.

Coverage is measured, not asserted:

```text
lua Tests/wowapi/coverage.lua LibItemDB-1.0.lua Integrations.lua ItemDB.lua Scoring/Vanilla.lua Scoring/TBC.lua Price/Sources.lua Price/Scanner.lua Price/Window.lua
```

It takes the executable-line set from Lua 5.1 bytecode debug info rather than
guessing from source, and exits non-zero below 100% unless `COVERAGE_MIN` says
otherwise. Every shipped Lua file above is held at **100% line coverage**; that
is the bar for any change, not a target. (`LibItemDB-1.0.lua` sat at ~57% until
v0.7.0, when the scoring, search and suffix paths were specced.)

**A caveat worth knowing before trusting a green run:** a line counts as covered
the moment its condition is _evaluated_, so every `if not X then return end`
guard reads as covered while the branch it protects has never run. 100% is a
floor, not proof.

Writing specs, in short: modules read WoW APIs into file-scope locals **at load
time**, so stage globals _before_ `wow.loadAddonFile` — assigning after is a
no-op. Drive the branch a real client takes (the `C_*` namespaced form), and
stage the deprecated bare global as `nil` so reaching for it fails the suite
instead of passing quietly.

### Historical record

The conversation boards this repo used to carry -- `docs/AUDIT.md`
(peer-review findings), `docs/LIBRARY_CONTRACTS.md` (requests from the addons
that consume `LibItemDB-1.0`: `IDBREQ-*` / `DIBSREQ-*` / `LIBREQ-*`),
`docs/DEPENDENCY_CONTRACTS.md` (what ItemDB asked of ProfessionDB and
TOGProfessionMaster) and `Tests/HARNESS_CONTRACT.md` (what it asked of the
WoWAPITesting harness) -- were **frozen on 2026-09-10 and imported into the
writ inbox on 2026-09-18**, every thread with its state, and removed the same
day, per the operator's rule that a migrated board is deleted so no session
reads it as a live channel; `git log -- docs/AUDIT.md` (and the other three
paths) still shows every line. Requests and findings between the fleet's addons
travel through the inbox; `CHANGELOG.md` records what each one produced, naming
the request id so the two can be joined.

[`docs/TBC-Parity.md`](docs/TBC-Parity.md) is the one standing document: the
feature-by-feature ledger of what TBC ships against Vanilla, kept current.

**If you consume this library from outside the fleet and want to raise
something**, open an issue on [GitHub](https://github.com/Pimptasty/ItemDB) or
ask on Discord: which game version, which item, what you expected — and for a
price question, which price addons you run and what `/itemdb price` printed.

## Credits

Drop-source data (instance → boss → items) is derived from
**[AtlasLootClassic](https://github.com/Hoizame/AtlasLootClassic)** (GPL-2.0).
Best-in-Slot gear sets are derived from **[WoWSims](https://github.com/wowsims)**
(MIT), as is the weapon-skill EP formula (the Classic attack-table math, ported from
`sim/core`) and the handful of feral-attack-power values (which the client keeps only in
tooltip text), lifted from WoWSims' parsed item database. The Vanilla `"bisclassic"` BiS
provider is derived from the per-spec rankings of
**[BestInSlotClassic](https://github.com/Warkdev/BestInSlotClassic)** by Warkdev (GPL-2.0). Per-spec EP stat weights are **HawsJon's** Classic weights
([tbcwowaddons.weebly.com](http://tbcwowaddons.weebly.com/pawn.html)), as shipped
with **[Pawn](https://github.com/VgerMods/Pawn)** by Vger (CC BY-NC-ND) — the
community-standard values Pawn auto-installs on Classic. Weapon/trinket **proc rates**
(procs-per-minute / chance) and item **source locations** (quests, vendors, crafting, PvP and
reputation gear) and per-boss **drop rates** are derived from the
**[CMaNGOS](https://github.com/cmangos)** server
databases ([classic-db](https://github.com/cmangos/classic-db) /
[tbc-db](https://github.com/cmangos/tbc-db), GPL-3.0 — the server _core_ is GPL-2.0, but
only the database repos are read), which reverse-engineered and tested them — the client
itself doesn't store them. The **never-implemented / removed-from-game** hidden list is
derived from **[AllTheThings](https://github.com/ATTWoWAddon/AllTheThings)** (MIT) — its
curated catalog of items that exist in the client but were never obtainable, or were removed
in a past patch (which no client signal reveals). In every case LibItemDB does not redistribute their files:
only the factual mappings / numeric values are extracted and re-expressed in this
library's own format, and each project is gratefully acknowledged. HawsJon's weights ship as the read-only `"hawsjon"`
scale; the `LoadBiSWeights` API lets players layer their own on top. All other data
(stats, names, drop-source structure, equip stats, set bonuses) is built from
Blizzard client data via [wago.tools](https://wago.tools). BiS is one curated,
sim-driven opinion, dated per phase — the `LoadBiS` / `LoadBiSWeights` API lets you
load your own instead.
