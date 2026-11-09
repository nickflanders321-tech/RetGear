# Changelog

<!-- charset-ok: no WoW client font ever renders this file -- nothing loads
     a .md, and the packager publishes it verbatim as the GitHub release
     body, which is read in a browser. The stronger reason is that released
     entries MUST NEVER BE EDITED (repo law), and the em dashes are spread
     through every shipped version back to v0.1.0, so transliterating them
     would mean rewriting release history to satisfy a rule about in-game
     glyphs. New text here is written ASCII anyway; this declaration exists
     so the linter's report stays about the current entry instead of being
     permanently non-empty, which is how a report stops being read. -->

## [v1.8.0] - 2026-10-26

### `GetScanRecord`: what the last full scan saw, after the AH closes (MINOR 47)

- New `lib:GetScanRecord(itemID)` -> `copper, count, ageSeconds` for an item the most recent full
  scan for this realm + faction saw listed (or a scan stored after it), else `nil`. Asked for by
  TOGProfessionMaster (inbox a583dabb): its Missing Recipes `[AH]` button read `GetScanListings`,
  which answers only while the Auction House is open, so a player who scanned and closed the AH
  saw nothing for a pattern with five listings.
- `Price/Scanner.lua` `fullStore` now stores every item under the scan's own timestamp through the
  new private `lib:_PriceStoreScanned(itemID, copper, count, at)`, and `_PriceRecordScan(count, at)`
  stamps the scan with the same value. Before, `StoreScannedPrice` stamped each item with `now()`
  while the scan was stamped afterwards, so "seen by the last scan" needed a time window; TOGPM's
  stand-in used 60 seconds of slack. Now it is an equality, pinned by a spec whose clock moves a
  second on every read. `StoreScannedPrice` keeps its signature and its `now()` stamp.
- Records stored before this change are not re-stamped: until the next full scan, an item stored
  in a slow store loop can read as older than the scan and answer `nil`.

### `GetRequiredReputation`: the faction and standing an item needs (MINOR 47)

- New `lib:GetRequiredReputation(itemID)` -> `factionID, minStanding` (client 1-8 index), else
  `nil`; `lib:LoadReputation` loads it. Asked for by TOGProfessionMaster (inbox e1313d35) for a
  "can I buy this" vendor filter on Missing Recipes.
- New `tools/build-reputation.py` reads wago `ItemSparse.MinFactionID` / `MinReputation`. DB2's
  standing is 0 Hated .. 7 Exalted and the client's is 1-8 (`MAX_REPUTATION_REACTION = 8` in
  Classic Era's `ReputationFrame.lua`), so it ships `MinReputation + 1`, checked against Cenarion
  Circle's Spitfire Bracers / Gauntlets / Breastplate (4 / 5 / 6) and Dreamscale Breastplate (7).
  It refuses a standing outside 0-7 and refuses to write when the columns are missing.
- `Data/<Version>/_core/Reputation.lua` for Vanilla (418 items, 158 of them moved to the seasonal
  overlay by `split-seasonal.py`), TBC (707), Wrath (938), Cata (1,146), Mists (1,581) and Forever
  (468), each at the build its sibling files carry, listed in every flavour's TOC after
  `Factions.lua`. Not Retail: renown and friendship factions do not use the 1-8 scale.

## [v1.7.0] - 2026-10-20

### Tests and tools: luacheck declared; gear EP audit tidy (tools only)

- `.writ-suites.json` declares a `luacheck` suite (`luacheck .`). Until now no suite ran it: the
  44-suite gate on 2026-10-20 had no lint step for Lua at all. `.luacheckrc` now also excludes
  `tools/wago_cache`, the git-ignored downloads (1,905 third-party files, ~679,000 warnings). The
  45 repo files are all clean.
- `Tests/gear_ep_audit.lua`: the gear filter tested `INVTYPE_NON_EQUIP` twice (an exact compare and
  a prefix match); only the prefix match remains (Peer Review 3988623c G4). The header now says that
  rows are scored with no options, so procs run at the flavour model's defaults, and what that
  misses (G5). G1's red-check was done with a real defect: removing TBC's `whiteDPS` turned
  gear-ep-tbc red on exactly Hand of Justice's extra-attack row, and restoring it turned it green.
- `Tests/sources_order_check.py` docstring: the "running build-sources-journal.py Cata" line it
  prints is the builder's own announcement before it calls the stand-in, not a rebuild. The check
  writes nothing.

### Hand of Justice priced on TBC, Wrath and Mists; one `whiteDPS` definition (tools + scoring)

- Cause, traced in the client data: from TBC on, Hand of Justice's equip spell 15600 carries
  `SpellAuraOptions.ProcChance = 100` (wago 2.5.6.68941, 3.4.3.58936, 4.4.2.60895, 5.5.4.68806),
  the "server decides" sentinel `real_chance()` refuses; Vanilla's client says 2. The item has no
  `item_template` rate either, so `tools/build-use-effects.py` found no rate and listed it
  unscored. The world DBs do carry it: `spell_proc_event` 15600 `ppmRate = 1` in tbcmangos,
  wotlkmangos and mistsskyfire (desk `itemdb-worlddb`). The builder loaded that table already but
  read it only for on-use windows. It is now the LAST rate tier for an EQUIP proc with no other
  rate, so every row that already had a rate is unchanged.
- Data: UseEffects rebuilt pinned (TBC 2.5.6.68941, Wrath 3.4.3.58936, Mists 5.5.4.68806, Vanilla
  1.15.9.69722 then `split-seasonal.py Vanilla`). HoJ ships `extra_attack` at `ppm=1` on all three.
  The same tier gave a world-DB rate to other equip procs that had none, HoJ included: proc rows
  Vanilla 191 -> 205, TBC 237 -> 254, Wrath 317 -> 335, Mists 376 -> 397, with unscored falling
  by the same 14 / 17 / 18 / 21 (file headers; the build log names each as a `spell ppm <item>`
  line). Those items gain EP. On Vanilla that is 14 items, not HoJ, which already had `ch=2`. Cata has no world DB of its own (`SPELL_PPM_DB` is Mists-only on purpose, Peer Review
  a7919e37), so HoJ stays unscored on Cata.
- `whiteDPS` has ONE definition, written in the library's `extra_attack` bucket comment: the WEAPON
  DPS of one named raid two-hander, from the flavour's own core where it carries a DPS key and
  from WoWSims' database where it does not (Wrath), no attack-power term (a floor).
  Vanilla's 90 already was that (Corrupted Ashbringer 22691, `DAMAGE_PER_SECOND=90` in our core);
  only its comment said "the wearer's white DPS", now corrected. TBC declares 120 (Gorehowl 28773,
  119.86) and Mists 4186 (Starshatter 86140, 4185.97), both first-tier weapons like Wrath's
  Naxxramas-25 223. Cata declares none: it ships no `extra_attack` row. Pinned by the new
  `Tests/tbc_scoring_spec.lua` and a `Tests/mists_scoring_spec.lua` case. KNOWN COST: the tier
  rule is a first-tier raid weapon, and Vanilla is the exception: it keeps Naxxramas' 90, the last
  tier, because changing it would move live Vanilla scores (`MELEE_HASTE_PCT` and the weapon-skill
  default read the same number).

### Mists mana procs priced for healers; gear EP audit reads ranged-AP twins (library + tools)

- `LibItemDB-1.0.lua` proc scorer: a mana-return proc (`b = "mana"`) read the raw `w[mp5]`
  weight, so a flavour that DERIVES mp5 instead of weighting it scored every mana proc 0. Mists
  does exactly that (`Scoring/Mists.lua` prices mp5 as Spirit for healers), so the Idols of
  Wisdom, Price of Progress, Fathom-Brooch of the Tidewalker and the rest of 20 mana-proc rows
  scored nothing (gear-ep-mists run 20261020-102821.409-464835343). The mana branch now resolves its weight through
  `effectWeight`, like the buff branch, and its breakdown shows the derived factors. EP CHANGE on
  Mists: those procs now score for healer specs; every other spec and every other flavour is
  unchanged (only Mists declares a derived mp5). Pinned by a new `Tests/libitemdb_spec.lua` block.
  No operator ruling covers mana returns: pricing them rests on ItemDB's inference from the
  "healing has EP" ruling (directive 97bf22ed, which is about healing). If a ruling is wanted, the
  question is "should a mana-return proc have EP for healers?".
- `Tests/gear_ep_audit.lua`: on Cata and Mists a generic "+X attack power" effect ships as an AP
  row and an identical ranged-AP twin, and the twin is unpriced on purpose (the scales put a
  hunter's AP weight on melee AP; pricing both would pay a hunter twice, `Scoring/Cata.lua`
  "RANGED ATTACK POWER"). The audit failed all 54 / 52 twins; it now lists a twin (`isRangedTwin`:
  a melee-AP sibling on the same item with every field equal but the key and the amount) and
  still fails a lone ranged-AP row. Cata spell penetration is a documented zero there, as
  `Scoring/Cata.lua` already says. KNOWN COST: Cata 232012 Coren's Chilled Chromium Coaster ships
  melee AP 3576 beside ranged AP 4000 (`Data/Cata/_core/UseEffects.lua:505`; 71335, the same name,
  ships 4000 on both), so a Cata hunter is priced on 3576. Why the halves differ was not checked.
- Comments: `Scoring/Mists.lua`'s socket block (Mists ships 17 cogwheel and 3 hydraulic gems) and
  mana-proc note, `Scoring/Cata.lua`'s socket block, and the AP-pair note in the proc scorer
  (11817, 34472 and 34427 now ship the pair).
- `tools/build-sets.py` `classify_proc` read only the first stat aura of a set-bonus proc, the
  same defect `build-use-effects.py` had (Peer Review 9ddcdb05 N3). It now returns every stat
  aura and the caller writes one row per aura with the same rate fields; Wrath's equal spell-power
  / healing pair is settled by the shared `settle_heal_twin`, which moved from
  `build-use-effects.py` into `itemdb_common` so both builders use one copy. Every Sets.lua rebuilt
  pinned at its header build (Vanilla re-split): scored set procs TBC 35 -> 45, Wrath 39 -> 44,
  Cata 31 -> 36, Mists 34 -> 40, Forever 0 -> 0. The new rows are the second half of a two-stat
  proc -- on TBC, the ranged twin of an attack-power proc or the healing half of a "+damage and
  healing" proc (read from the TBC diff; the other versions' diffs were not read). The header now
  names `ch|ppm` and `pm`, which the rows carry (N4). EP CHANGE: set-bonus procs that buff two
  stats now price both halves as the scorer pairs them (AP max-paired; TBC healing and spell power
  priced per spec). Not checked in game.
- `Tests/tarball_read_check.py` gains an empty-regex case and a `main()`-level case (N5).

### Tools only -- the gear EP audit's exceptions are tied to the scoring rules (Peer Review 3988623c, 737072573d5f, e750e48b)

- `Tests/gear_ep_audit.lua` section 2 now prices each on-use / proc ROW alone (the item's lists
  are swapped for that one row while it is scored), so a priced row no longer hides a dead one on
  the same item; a part counts only when `(part.ep or 0) ~= 0`. The summary line prints the row
  count and the section title says ROWS.
- Flavour-scoped zeros: Armor Ignored is excepted on TBC only, resilience on Cata and Mists only
  (TBC's scale weights resilience, so a TBC regression there now fails).
- On Cata and Mists the skipped keys are read from the rules actually registered (a copy, so the
  live rules are not mutated), not from a list kept in the audit.
- New `SCORER_KEYS`: a key priced by a registered `lib.StatScorers` function is never excepted,
  on any flavour -- `WEAPON_DAMAGE` (weaponDamage), `AMMO_DAMAGE` (ammo), and `WEAPON_SPEED` /
  `MELEE_WEAPON_SPEED` (speed, registered by Mists only). Before this, Mists excepted both speed
  keys as "not a stat" although `Scoring/Mists.lua` prices them, so a broken speed scorer would
  have passed.
- New failure class, "stale exception": an excepted key that is priced anyway fails, so a
  scorer that starts pricing an excepted key goes red until it is named in `SCORER_KEYS`. That
  is what keeps the hand-kept map honest.
- Red-checked 2026-10-20 by putting the defect in: with `speed` removed from `SCORER_KEYS`,
  gear-ep-mists failed on exactly `WEAPON_SPEED` and `MELEE_WEAPON_SPEED` as stale exceptions
  (run 20261020-132952.723-2215040992); restored, it passes (20261020-133101.345-1009074479).
  `weaponDamage` could not serve: no shipped Cata gear carries `WEAPON_DAMAGE`, so dropping it
  fails nothing.
- `SCORER_KEYS` gains `sockets` (every `EMPTY_SOCKET_*` key the sockets scorer reads), so it
  matches the four registered scorers; the weapon-speed exception reason no longer calls speed
  "not a stat", which is false on Mists (Peer Review 70bfa528).
- `isRangedTwin` ignores the amount on proc rows only; an on-use twin must match it too, since d
  and cd are all it carries beside the amount (Peer Review 9a3ffa52 N-A). gear-ep-cata
  20261020-133316.577-1155008721, -tbc 20261020-133329.242-588795676 and -wrath
  20261020-133554.172-941912331 pass with both changes.
- Comments: `Scoring/Cata.lua` names its one hydraulic-socket item, 60892, as hidden; the
  library's `GEM_SUBCLASS_SOCKET` says why one Cata/Mists map serves every flavour and that a
  Retail scoring file must make it per-flavour first.

### School resistance under one key on Mists and Retail; Forever-only stats listed (tools + data)

- Gear EP audit finding: Mists and Retail cores carried a school resistance twice on one row --
  `ITEM_MOD_FIRE_RESISTANCE_SHORT=60` beside `RESISTANCE2_NAME=60` -- so `GetStats` reported it
  twice and anything summing resistances doubled it. The builders were already right
  (`build-core.py` `collapse_resist`, `build-core-wago.py` emits `RESISTANCEn_NAME` only, and the
  Cata core was clean); the shipped data predated them.
- New `tools/build-resist-collapse.py`: applies build-core.py's own `collapse_resist` to every
  row of a version's `_core` and `_seasonal` class files in place, reads no DB2, and calls
  `validate_version` unconditionally. Needed because there is no Mists walk on this box to
  replay. Mists: 699 rows (948 duplicate keys dropped); Retail: 542 rows (671); Vanilla: 1 row
  (`_seasonal/Armor.lua` 213299). A second run changes nothing. No re-stamp: the class files
  keep their walk build.
- `Tests/equip_resist_check.py`: no core row on any version may carry
  `ITEM_MOD_*_RESISTANCE*_SHORT`. Red-checked against the real defect before the fix (Mists 948,
  Retail 671, Vanilla 1).
- Forever's `EXPERTISE`, `ARMOR_PENETRATION`, `ITEM_MOD_ATTACK_POWER_VS_*_SHORT` and
  `ITEM_MOD_SPELL_DAMAGE_VS_*_SHORT` stay as they are and unpriced: Classic Era has no such stats
  for `Scoring/Vanilla.lua` to price (expertise and armour penetration are Forever combat ratings
  24/25 in wow-ui-source-forever `PaperDollFrame.lua`; the Era walk records no creature-type
  stat). Forever items' generic attack power beside the creature-type bonus is real (Beastslayer
  11907: ItemSparse stat 38 next to stat 131). `Tests/gear_ep_audit.lua` lists them as known
  exceptions; `Tests/forever_vocab_check.py` pins all three behaviours. `gear-ep-forever` now
  passes with 0 unpriced (13 before).
- Not verified: that Forever's armour penetration is a flat armour-ignored value.
- No resistance number was lost by the collapse (self-audit 2026-10-20 R1): `collapse_resist`
  keeps `RESISTANCEn_NAME` and drops its twin without comparing them, so the new
  `build-core.resist_conflicts` names a single-school pair that disagrees (the all-schools key
  is left out: "+10 all" beside a larger fire value is extra fire), and `build-resist-collapse.py`
  prints each as `CONFLICT`. `equip_resist_check.py` pins the helper and reads every pre-collapse
  core row at commit a6bd125 through git: Mists 699, Retail 542 and Vanilla 1 rows carried both
  spellings, and every pair agreed (34/34). Those counts match the agent's own.

### Cogwheel and hydraulic sockets priced; their gems no longer read as meta (tools + data + library)

- Gear EP audit finding: `EMPTY_SOCKET_COGWHEEL` (Cata 7 items, Mists 15) and
  `EMPTY_SOCKET_HYDRAULIC` (Mists 30, e.g. 86226 Claws of Shek'zeer) priced 0 for every spec,
  because the socket scorer's colour map had only R/Y/B/M/prismatic. Worse, `tools/build-gems.py`
  wrote every gem with no red/yellow/blue Pawn flag as meta `M`, so cogwheels and Sha-Touched
  gems were counted as candidates for META sockets and inflated Cata/Mists meta-socket scores.
- `LibItemDB-1.0.lua`: `EMPTY_SOCKET_COGWHEEL = "C"`, `EMPTY_SOCKET_HYDRAULIC = "H"` and
  `GEM_SUBCLASS_SOCKET = { [9] = "H", [10] = "C" }` (around line 2666); a gem is matched to its
  socket by its core subclass, so the library is right even against an old Gems.lua.
- `tools/build-gems.py`: `SOCKET_SUBCLASS` per version (`Cata {10: C}`, `Mists {9: H, 10: C}`;
  per version because Retail numbers gem subclasses differently) and `META_SUBCLASS = 6`;
  `colourless_kind()` gives C/H/M from the subclass read out of the shipped `_core/Gem.lua`, and
  a colourless gem that fits no socket is skipped and listed on stderr instead of written as `M`
  (none did). Cata Gems.lua: 9 rows M->C (59477-59480, 59489, 59491, 59493, 59496, 68660). Mists:
  the same 9 plus 77540-77547 M->C and 89873, 89881, 89882 M->H; 60 meta, 17 cogwheel, 3
  hydraulic. TBC and Wrath rebuilt byte-identical. Rebuilt through `itemdb-build` (the builder
  takes no `--wago-build`; its only versioned input is the cached Pawn file).
- Cata and Mists meta-socket scores DROP: the meta socket's best gem can no longer be a cogwheel.
- 98056 (Mists, subclass 9) has no gem row, and is now HIDDEN instead: it is an unobtainable
  duplicate of the Sha-Touched gem Crystallized Horror 89882 (no loot, vendor or quest source in
  SkyFire 5.4.8, absent from AllTheThings, same enchant 5115), so `tools/curated_hidden.py` lists it
  and `Data/Mists/_core/Hidden.lua` carries it. Search and the gem rankings no longer offer it.
- Pinned in `Tests/gems_socket_check.py` (new, declared in `.writ-suites.json`, 21 assertions;
  red-checked by emptying `SOCKET_SUBCLASS`). Not verified: in game, and the shipped-file half of
  that check was not run against the old Gems.lua.

### Stacking proc windows priced: Blackened Naaru Sliver, Death Knight's Anguish (tools + data + library)

- Gear EP audit finding: Blackened Naaru Sliver (34427) shipped `d=0 st=1` on TBC, Wrath, Cata
  and Mists and priced 0. Its equip spell 45355 (10% on hit, 45 s cooldown) triggers 45040 Battle
  Trance (20 s, 100% on hit), which triggers 45041 Combat Insight (+44 AP and +44 ranged AP,
  CumulativeAura 10, no timer of its own). `proc_effect` took the inner spell's 0 duration and the
  outer spell's stack cap. wowsims/wotlk `melee_trinkets.go` models the same 20 s, 10-stack window.
- `tools/build-use-effects.py` `proc_window()`: taken only when the middle spell has a duration
  and a 100% chance with the outer proc's scope, and the inner spell has no timer and a stack cap
  of 2 or more. One row per stat (both AP and ranged AP now ship), carrying the new `ws` field.
- `LibItemDB-1.0.lua`: `averageStacks()` (a port of the builder's `average_stacks`, same 0.05 s
  step); `scoreProcEffects` prices a `ws > 1` row as `m x averageStacks(trigger rate, d, ws) x
  uptime x weight`, the trigger rate being the row's own (`hitsPerSec`). No world DB has a rate
  for the window, so none is baked in. README documents `ws` under `GetProcEffect`; it ships in
  MINOR 46, which is unreleased.
- The same shape moved Death Knight's Anguish (38212, +15 crit rating a stack) from
  `LoadUnscoredProcs` to priced on Wrath, Cata and Mists. Nothing else moved in those four. Each
  UseEffects rebuilt pinned at its header's build (TBC 2.5.6.68941, Wrath 3.4.3.58936, Cata
  4.4.2.60895, Mists 5.5.4.68806). Vanilla and Forever UseEffects were rebuilt pinned later, with
  the one-row-per-aura change below; neither gained a `ws` row (Peer Review 6b47813f item 3).
  That no Vanilla or Forever proc has the two-hop window shape is the likely reason, not
  verified.
- Pinned in `Tests/use_window_check.py` (red-checked by putting the defect back, which failed on
  the exact old row) and in a 7-test `Tests/libitemdb_spec.lua` block, which also pins the capped
  `averageStacks(0.5, 20, 10)` = 4.791521286738454 (the builder's own figure, held in both ports)
  and the resulting ~187 EP (44 x 4.7915 x 20/45 x 2). The uncapped bound is ~196 EP (the spec's
  ws=100 fixture). `gear-ep-tbc`: 0 unpriced on-use/proc items.

### One proc row per stat aura (tools + data)

- `tools/build-use-effects.py` `proc_effect` read only the first stat aura of a proc spell, so a
  spell buffing two stats shipped half. It now returns every stat aura and the main loop writes one
  row per aura, with the same rate fields. Shard of Contempt (34472) ships its attack power AND
  ranged attack power rows on TBC, Wrath, Cata and Mists; on Vanilla, 11817 gains its ranged twin
  and Felstriker (12590) gains `HIT_PCT=100` beside `CRIT_PCT=100` (3 s). TBC and Wrath ship the
  same two rows (`Data/TBC/_core/UseEffects.lua:208`, `Data/Wrath/_core/UseEffects.lua:290`) and
  price `HIT_PCT` linearly as hit rating (`Scoring/TBC.lua:136`, `Scoring/Wrath.lua:129`). KNOWN
  COST on Vanilla, TBC and Wrath: +100% hit is far past the hit cap and the price is not capped,
  so Felstriker's hit half is overpriced; by how much is not measured. Whether those TBC/Wrath rows
  are new in this rebuild was not checked.
- EP CHANGE for hunters (Peer Review 9ddcdb05 N1): 11817 on Vanilla, and 34472 / 34427 from TBC
  on, now ship the attack power AND ranged attack power halves of one proc. The proc scorer
  max-pairs the two (`apPairEp`), so a hunter's score takes the larger half, where before it took
  the melee half alone on 11817. That 11817 shipped melee AP only before is from the builder's
  first-aura bug, not from a diff (not verified); the size of the move was not measured.
- Wrath: a "+N spell power" spell carries a damage aura and an equal healing aura; the builder's
  new `settle_heal_twin` (Wrath only) drops the healing half when it equals the spell power and
  keeps only the excess. 47662 and 47671 (which had shipped the healing half alone under the
  first-aura bug) now ship `ITEM_MOD_SPELL_POWER=234`. `Scoring/Wrath.lua` prices any healing
  row left as spell power 1:1 for healer specs only (`effectWeight` gains `only =`).
- Every UseEffects file rebuilt pinned at its header build; Vanilla re-split with
  `split-seasonal`. `gear-ep-wrath` passes with 0 unpriced keys. Pinned in
  `Tests/use_window_check.py` and `Tests/wrath_scoring_spec.lua`.

### Attack-speed on-use trinkets priced (tools + data + scoring)

- Kiss of the Spider (22954) shipped in `LoadUnscoredProcs` at 0 EP on Classic Era: its use spell
  28866 is +20% melee (aura 138) and +20% ranged (aura 140) attack speed, and `build-use-effects.py`
  read neither. The aura -> key map is now `itemdb_common.HASTE_AURA_KEYS`, shared with
  `build-aura-buffs.py` (it was a private `HASTE_KEY` in each builder): 138 -> `MELEE_HASTE_PCT`,
  140 -> `RANGED_HASTE_PCT`, and WoW Forever's aura 319 (the same spell's melee half there) ->
  `MELEE_HASTE_PCT`. Two auras naming one key add, through the shared `haste_fold`.
- Chance-on-hit haste procs: `proc_effect` returns every haste half of the spell (`haste_by_key`),
  and the main loop prices the half that speeds this weapon's own swing -- ranged haste on a ranged
  weapon (`RANGED_INV`), melee haste otherwise. Before, a ranged-haste proc was unscored while the
  same aura on-use was priced.
- `Scoring/Vanilla.lua`: `DERIVED.MELEE_HASTE_PCT` prices 1% as `MODEL.whiteDPS / 100` main-hand
  weapon DPS, `family = "melee"`, so hunters take only the ranged half (their scales already weight
  `RANGED_HASTE_PCT`). An approximation, stated in the comment; a DERIVED row is fixed at load, so a
  caller's `opts.attack.weaponDPS` does not reach it. `Scoring/TBC.lua` converts both halves to
  haste rating like Wrath/Cata/Mists.
- Charges-only on-use (Manual Crowd Pummeler 9449: 3 charges of +50% melee haste, no cooldown on
  Classic Era and TBC) is now priced as one use per `CHARGE_USE_CD` = 180 s, ItemDB's own figure,
  matching Forever's cooldown on the same item and Season of Discovery's 213407 casting the same
  spell. Positive charges only (negative charges mean a one-shot item that is deleted). KNOWN COST:
  three charges are three uses and the mace is kept once they are spent, so this prices a finite
  buff as if it were reusable without limit.
- Gear that casts a consumable's own spell is unscored (`consumable copy` in the build log):
  re-casting replaces the aura, so it adds nothing to the flask, elixir, food or drink a player
  already runs. A consumable is upkeep by `Item.SubclassID` (2 Elixir, 3 Flask, 5 Food & Drink)
  OR by its `ItemEffect.SpellCategoryID` (11 Item - Food, 59 Item - Drink, 79 Item - Potion
  (Non-Combat)) -- the category is needed because Classic Era's client files its consumables
  under subclass 0. Effect: 4696 Lapidis Tankard of Tidesippe (a drink's mana regen) is unscored on
  Vanilla, Forever and Mists (TBC, Wrath and Cata already left it unscored), and Forever 286541
  Bael'dun Tankard likewise; Mists 81136 Cloak of Hidden Flasks
  (Flask of Falling Leaves) stays unscored.
- Rebuilt pinned, every row against HEAD: Vanilla +22954, +19343 Scrolls of Blinding Light, +9449
  priced, 4696 unscored, re-split through `split-seasonal.py`; TBC +9449 (500 haste rating); Forever
  +22954 both halves, +9449, +19343, 4696 and 286541 unscored; Wrath +44096, an earlier fix never
  rebuilt into Wrath; Mists 4696 unscored; Cata unchanged. From TBC on, Kiss is +200 haste rating,
  which already shipped.
- `Data/Mists/_core/AuraBuffs.lua` (rebuilt at 5.5.4.68806 through the shared map): the five 10%
  melee-haste raid buffs (Cackling Howl, Serpent's Swiftness, Swiftblade's Cunning, Unholy Aura,
  Unleashed Rage) also carry `RANGED_HASTE_PCT=10`, which Mists' aura 342 grants. The ranged half
  is from the client data only, not seen in game. The generated header now names the haste keys
  each file's own rows carry (`build-aura-buffs.py`, Peer Review N2 and fd6f4b3b F3): Mists lists
  `RANGED_HASTE_PCT`, Wrath and Cata do not, because no row there has one. Wrath and Cata
  AuraBuffs were rebuilt pinned (3.4.3.58936, 4.4.2.60895) on 2026-10-19; `git diff` after that
  per-file header rebuild is +6 -6 on each, all in the header comment, every row identical to HEAD
  (Peer Review N3). `aura_buffs_check` now holds each modern header's key list equal to the
  `*HASTE_PCT` keys its rows carry (Peer Review N4; red-checked by putting `RANGED_HASTE_PCT` back
  into the Wrath header, which failed exactly that check, 1 of 74).
- `Tests/libitemdb_spec.lua`: four haste specs; `Tests/use_window_check.py` pins both halves of
  22954, 9449's charge row, 4696 as a consumable copy, and every scored on-use whose buff lasts at
  least its cooldown (13143 Mark of the Dragon Lord on Cata/Mists, hidden 1912); the lib's
  no-premium comment now names 13143 instead of the unscored 81136.
- EP CHANGE in `scoreUseEffects` (`LibItemDB-1.0.lua`, Peer Review A6): a use buff that lasts at
  least its cooldown now scores with uptime 1 and premium 1 -- the use premium (the default, or a
  caller's `premium`) is dropped, because a buff that never falls off is a flat stat, not a burst.
  Shipped effect: 13143 Mark of the Dragon Lord scores lower on Cata and Mists than in v1.6.x
  (+44 spirit, d=1800 on cd=1800); 1912 Deprecated Reed Pipe also qualifies but is hidden on every
  flavour.
- `Tests/use_window_check.py` (Peer Review J1/J3/J4): one `use_effects_blocks` helper splits each
  UseEffects.lua for all three readers; a guard counts every `[id]=` row and `{k=` entry in the
  LoadUseEffects block against what `ROW` parsed, so a row the regex misses fails instead of
  vanishing (red-checked: narrowing `ROW`'s `m=` to integers failed it on Vanilla, TBC, Wrath and
  Forever); and the full-uptime check is renamed `on-use rows (served and hidden) with d >= cd`,
  because it reads hidden rows on purpose (1912).
- Red-checked the Mists aura 342 ranged half (Peer Review D1): with 342 mapped to melee only and
  Mists AuraBuffs rebuilt, `aura_buffs_check` failed exactly `Mists Unholy Aura 55610 is 10% melee
  AND 10% ranged haste` (1 of 71); restored and rebuilt at 5.5.4.68806.
- Re-checked against the data on 2026-10-19 (Peer Review D2): `use_window_check.py` pins 13143 on
  Cata/Mists and 1912, which every flavour's Hidden.lua lists; Mists 81136 sits in `LoadUnscoredProcs`; and SoD 213407's
  ItemEffect row at 1.15.9.69722 casts spell 13494, the same spell as 9449's.
- Also: `Data/Vanilla/_core/Effects.lua` held two rows joined on one line (4423, 4424), so its
  header stated 231 rows and `data_shrink_check` reported a loss. Regenerated with
  `build-effects.py` at 1.15.9.69722 and re-split; it is byte-identical to HEAD again.

### Developer test rings no longer ranked (data only)

- The "Indalamar's Ring of N stat" family (33986-33998, 34094, 34095, 34550, 34551; epic,
  ilvl 130, no source -- guildorder.com's 34095 page: "dungeon journal does not list a source")
  matched no `build-hidden.py` JUNK pattern, so rankings and BiS could serve them; 34095 ranked
  first by melee hit. New pattern `r"^Indalamar's "` -- measured over every version's enUS names, it
  catches only that developer's test items (the rings, "Trinket of Pwnage", "Super Hot",
  "Debuffer", "Holy Hand Grenade"). Not confirmed unobtainable by an official source.
- Hidden.lua rebuilt pinned at each file's stamped build: TBC +13 (4,730), Wrath +15 (6,320), Cata
  +20 (10,070), Mists +21 (13,458); the Indalamar's ids account for TBC +13, Wrath +15, Cata +15
  and Mists +16. Vanilla, Forever and Retail ship no such names.
- SIDE EFFECT of the same rebuild, not of the pattern: Cata and Mists Hidden.lua each gained 5
  AllTheThings rows (ATT count 3,665 -> 3,670 and 5,784 -> 5,789), so these items are no longer
  served there: 43670 Prophet's Enchanted Tiki, 43697 Artifact from the Nathrezim Homeworld, 43726
  The Idle Crown of Anub'arak, 43821 Faceless One's Withered Brain, 43823 Head of Cyanigosa. Why
  ATT's signal moved was not checked; a newer installed AllTheThings is the likely cause, not
  verified.
- `Tests/hidden_patterns_check.py` (new, declared in `.writ-suites.json`): real test names hidden,
  near-miss real names served, every shipped Indalamar's id in Hidden.lua. Red-checked by breaking
  the pattern (6 of 23 failed).
- Forever carries the same family under another name: "Leafre's Ring of ..." (WoW Forever's
  counterpart of the Indalamar's rings). New pattern `r"^Leafre's "` in `build-hidden.py`; over
  Forever's enUS names it matches only those three rings. Forever Hidden.lua rebuilt at
  1.60.1.69913, 1,664 -> 1,667. The three names are in `hidden_patterns_check.py`; red-checked by
  breaking the pattern (1 of 36 failed). Not confirmed unobtainable by an official source.

### Hidden.lua records which AllTheThings it read (tools + data headers)

- Peer Review (thread f3669537, finding 2): the side effect above could not be explained from
  the files, because the header stamped the build and the removed-with-patch cutoff but not the
  ATT release. `att_hidden` now returns the source it read, and `build-hidden.py` stamps it as
  `-- AllTheThings read: installed <toc ## Version>` (or `source cache <sha>` /
  `not read (<why>)`). The next ATT update shows as a changed stamp, separate from a JUNK change.
- Every Hidden.lua rebuilt pinned at its stamped build so each carries the stamp (ATT 5.4.3).
  TBC, Wrath, Cata, Mists and Vanilla: stamp line only (Vanilla re-run through
  `split-seasonal.py`, 0 rows moved). Forever and Retail moved, by ATT rows only (the name and
  level counts did not change); that their last build read an older ATT is the likely cause, not
  verified, since nothing recorded it then: Forever 1,664 -> 1,663 (191481 Tabard of Mastery no longer hidden);
  Retail 13,923 -> 13,927 (+25 hidden, among them the same five 4367x-4382x items as Cata/Mists,
  144373-144379 and 151221-151264; -21 served again: 185784-185785, 250293, 17 ids in
  255473-255491, 268551). Not checked item by item against the game.
- Forever's drop is now confirmed and fixed (Peer Review fd6f4b3b): installed ATT 5.4.3's
  `db/Camelot` no longer mentions 191481 at all, and that entry was its only Forever hidden flag.
  The Tabard of Mastery is a Season of Mastery reward (ATT u=16) and already hidden on Vanilla,
  Wrath, Cata and Mists. That it is unobtainable on Forever rests on the older ATT build having
  flagged it there (HEAD's Forever header counted it as ATT); it was not checked in game. It is
  now in `tools/curated_hidden.py`
  `MANUAL_HIDDEN`. Forever Hidden.lua rebuilt pinned at 1.60.1.69913: 1,664 again (5 ATT, 5
  hand-curated); `data_shrink_check` and `hidden_patterns_check` (33/33 at the time) green.
- `tools/build-hidden.py` now logs every ATT id it does not count, split into "not in this
  version's names" and "already hidden by name or RequiredLevel" (Peer Review 6b47813f item 5).
  Forever's sixth ATT id is 4116, which Forever does not ship; that rebuild was row-identical
  (1,664). The shipped Forever Hidden.lua now holds 1,667 (1,639 by name): a later rebuild added
  the three Leafre's test rings (274978, 276765, 285326), hidden by name (Peer Review ca334b59 F3).
- `Tests/hidden_patterns_check.py`'s data half widened from the Indalamar's family to every name
  ANY JUNK pattern matches, on every version with a Hidden.lua (33 checks). Red-checked with a
  real defect, an added `^Linen Cloth$` pattern no file was rebuilt with: 7 of 33 failed. The
  three Leafre's names (above, added later) took the check to 36.
- Self-audit: a non-zero `att_extract.lua` exit is now stamped (`, extract exit N`) rather than
  read as a clean ATT read. The ATT cache paths were spelled in three files (`build-hidden.py`,
  `build-item-sources.py`, `fetch-att.py`); the two builders now import `ATT_CACHE_DIR` /
  `ATT_CACHE_META` from `itemdb_common`, and `Tests/itemdb_common_check.py` holds the
  import-free `fetch-att.py` to them (red-checked: renaming the shared pin file fails it).

### Seasonal test items hidden again on Classic Era (data + tools)

- Peer Review (thread 502f816e): `build-hidden.py` and `hidden_patterns_check.py` both called
  `read_names(version, "enUS")` without `include_seasonal`, so neither saw the names
  `split-seasonal.py` had moved to `Data/Vanilla/_seasonal/enUS/Names.lua`. The shipped Vanilla
  Hidden.lua had been built after a split, so seasonal test and placeholder items (209526 TEST
  Darkwater Talwar, 213391 UNUSED Electrified Mithril Gauntlets, 215235 2hander Animation as
  1hander test copy, ...) were served on Season of Discovery and Fresh Anniversary realms. Both now
  pass `include_seasonal=True`, so the builder's output no longer depends on whether it runs
  before or after the split.
- `Data/Vanilla/_core/Hidden.lua` rebuilt pinned at 1.15.9.69722: 2,110 -> 2,137 (+25 by name,
  +2 by RequiredLevel > 60; ATT unchanged at 417). Red-check: the widened check failed on exactly
  these rows before the rebuild, then passed 33/33 after it.
- Peer Review (502f816e P1): the same defect was in ten more builders. `Tests/seasonal_ids_check.py`
  already required `include_seasonal=True`, but judged only builders some `_seasonal` overlay header
  names -- and a builder that never saw a seasonal id never made an overlay, so it was never
  judged. The check now judges every `tools/build-*.py`; seven are `EXEMPT` with a written reason
  (build-sources, -imenso, -journal, -wowsims, build-bis, build-bis-classic, build-rep-loot: their
  tables are in split-seasonal's `skip` set, so a seasonal row would load on Era unguarded).
  Red-checked by dropping build-hidden's flag: the check named `build-hidden.py:363`.
  `build-expansions.py` is EXEMPT too, found by the self-audit after I had first "fixed" it:
  Expansion.lua is grouped (`[-1] = "id,id,..."`), not one `[id]=` row per item, so split-seasonal
  cannot partition it, and reading seasonal ids put 6,522 of them in the BASE file as expansion -1
  "not known", loading on Era. Reverted and rebuilt (17,605, all expansion 0).
- Peer Review (ab446d2d P1): the exemptions are now checked, not just written.
  split-seasonal's skip set is the module constant `SKIP` (Expansion added: it is keyed by
  expansion, not item id). `seasonal_ids_check` now asserts three things. Every table an EXEMPT
  builder writes in a split version, read from the `_core` headers, is in `SKIP`. No EXEMPT builder
  passes `include_seasonal`, which is the guard that was missing for the Expansion regression. And
  every table split does partition is `[id]=` or `["key"]=` rows at column 0. Building it found two
  false reasons: build-sources-imenso and -wowsims write only Forever (which has no `_seasonal`),
  not `skip`-set tables. Their reasons now say so, and the check holds them to it. Red runs: with
  RepLoot dropped from `SKIP`, the check named RepLoot. Re-adding the Expansion flag and rebuilding
  went red on all three new pins, the shape pin naming `Expansion.lua:15 [-1] = "..."`. Reverted
  and rebuilt; split then moved 0. 48/48.
- Self-audit (a88dc308 F1): an EXEMPT builder calling `shipped_ids()` (always base + overlay)
  is now refused too. Red-checked by switching `build-expansions.py:75` to it.
- Peer Review (a88dc308 P2): `core_rows` is now a judged gate beside `core_ids` and
  `read_names`. It has the same `include_seasonal=False` default, and nothing was looking at it.
  The gate also reads a positional flag (`core_ids(v, True)`), per Peer Review N1. The first run
  went red on `build-tokens.py:224` and on `build-core-wago.py:398/:588` and
  `build-core-wowsims.py:364`. build-tokens now passes the flag, since TokenRewards is partitioned.
  Vanilla was rebuilt and is unchanged (87 tokens, 250 rewards); split moved 0. The other three
  calls sit in verify/report functions (`read_core`, `verify_structure`, `verify_armor`).
  Those are exempted by function, not by builder, in `REPORT_ONLY`, and each is held to making
  no write call. `derive-core-maps.py` is not judged: it writes no Data file.
- Peer Review (a88dc308 F2): two pins that the split moves only item rows. First, every Load
  table in a partitioned base file whose keys are mostly not shipped item ids must be named in
  `NON_ITEM_TABLES`, and all its keys must sit below `THRESHOLD`. Today that is only
  Reagents.lua's skill-line table, which split-seasonal's own docstring said stayed in the base
  "by position, not design". Second, no base TokenRewards row may name a seasonal-only reward,
  because split moves a row by its token key. Red runs: unlisting Reagents#2 named it, and adding
  202254 to token 5824's rewards named `TokenRewards.lua:15`. Both reverted. Self-audit: the
  table-opener regex first knew only `lib:LoadX({`, so the 13 `lib:LoadCore(n, {` class files
  were never judged. Now it also matches `lib:LoadX(<args>, {`, and a pin refuses any opener it
  does not recognise. Red-checked with the old regex: all 13 class files named. 59/59.
- Peer Review (a88dc308 L1, L2). The no-write pin now also knows json `dump`, the shutil copy
  family, `move`/`rename`/`unlink`/`mkdir`/`touch`, and `print(file=...)` to anything but
  stdout/stderr. Bare `copy` and `replace` are left out, because `dict.copy` and `str.replace`
  share the names. An item-keyed table may no longer carry an unshipped key >= THRESHOLD, since
  split would move that row by a meaningless key. Red runs: a planted `write_text` in
  `read_core` named `write_text@408`, and a planted `[299999]` row in Effects.lua named
  `Effects.lua#1`. Both reverted. 59/59.
- Self-audit 6633cdd6 F4, which Peer Review agreed was latent: the `REPORT_ONLY` exemption now
  also checks every place the function is called. A call passes when it sits in another
  report-only or `verify*` function, when its result is thrown away (main's
  `verify_structure(v, b)`), or when it is inside an `if` whose body ends in `sys.exit` (main's
  `if args.verify:` branch for `verify_armor`). Any other call is named, because the base-only
  answer could then reach a write. The two allowances based on names or code shape are checked
  too. A `verify*` caller's whole body must make no write, and an allowed exit branch must make
  no write before its `sys.exit`. Red runs: `_planted = verify_structure(v, b)` in main named
  `main@633`, and a `write_text` planted in build-core-wowsims' `--verify` branch named
  `exit branch@477:write_text@482`. Both reverted. 68/68.
- Peer Review (4797cfd8 W1-W3). Every no-write pin uses a write set worked out from the code,
  not a fixed list. Any function in `itemdb_common.py` or the builder whose body writes,
  directly or through another such function, counts as a write. That brings in ItemDB's own
  Data writers, `write_names`, `write_source` and `write_spell_schools`, which the old list
  missed. `open()` now counts only in a write mode, so `p.open("rb")` is a read. Writes to the
  download cache are excluded when the target is `CACHE_DIR`, or a variable built from it or
  from a `*_cache_path()` helper. Without that, `wago_csv`'s cache write made every DB2 reader
  look like a writer. New pins hold that exclusion honest: `CACHE_DIR` must sit under `tools/`,
  and every `*_cache_path` helper must build on it. `shutil.copy` and `os.replace` /
  `os.rename` / `os.remove` are now recognised, while `Path(...).replace` stays the known gap
  (W2). A comment records that the three report-only functions fill no container they are
  passed (W3). Red runs: `write_source` planted in `verify_structure` and in
  build-core-wowsims' `--verify` branch, plus `shutil.copy` in `read_core`. All three were
  named, and the copy also turned `read_core` into a writer, which flagged its `verify` caller.
  All reverted. 72/72. Peer Review's follow-up note: `extractall`, `urlretrieve` and `rmtree`
  now count as writes too. Red run: an `extractall` planted in the `--verify` branch named
  `extractall@482`. Reverted.
- Fixed: build-consumable-groups, -droprates, -factions, -gems, -item-places (both
  its `core_ids` and the gathering-node `read_names`), -mounts, -races, -reagents, -spell-schools,
  -use-effects. Vanilla rebuilt with each, then `split-seasonal.py`: 1,259 seasonal rows into
  seven NEW overlays, now listed in `ItemDB.toc` -- `_seasonal/Factions.lua` 517,
  `UseEffects.lua` 481, `SpellSchools.lua` 178, `Reagents.lua` 31, `Hidden.lua` 27 (the 27
  above, moved), `Mounts.lua` 18, `Races.lua` 7. So on SoD / Fresh realms, seasonal items now
  have their faction and race limits, on-use and proc effects, spell school, reagent use and mount
  flag, none of which they had before. ConsumableGroups, DropRates and ItemPlaces moved no rows;
  all three are keyed `[id]=` (read), so a seasonal row would have been partitioned. That their
  sources (WoWSims, CMaNGOS) carry no seasonal item is the likely reason, not verified. Base files unchanged in count (`data_shrink_check`: no base shrink). None of it is
  checked in game.
- `hidden_patterns_check.py` reads `_seasonal/Hidden.lua` as well as `_core`.

### On-equip spell stats one low on Classic Era and TBC gear (data only)

- Operator, 2026-10-18: Hand of Justice (11815) is +20 Attack Power in game; the core shipped 19.
  Root cause: the Classic Era and TBC clients' `GetItemStats` returns an on-equip aura's raw
  `EffectBasePoints` and leaves out the `EffectDieSides` (1) the tooltip adds, and the walk records
  `GetItemStats`. Seasonal items carry DieSides 0, so their walk value was already right; the Mists
  and Forever walks already report the tooltip value (Drake Fang Talisman 19406: 56 there, 55 here).
- `tools/itemdb_common.py`: `equip_aura_rows` (raw base + DieSides of every on-equip APPLY_AURA)
  and `equip_die_corrections`, which raises a key by its auras' summed DieSides ONLY when the walk's
  value equals their summed raw base -- so a corrected core, a seasonal item and a client that
  already reports the tooltip value come back unchanged. `EQUIP_DIE_KEYS` (aura -> walk key) was
  derived from the data, not from names: AP 99/124, spell damage 13 (all schools and per school),
  healing 135, mp5 85, health regen 161, equip-spell school resistances 22, and TBC's aura-189
  ratings (defence, dodge, parry, block, hit, spell hit, melee/ranged crit, spell crit). Armour via
  aura 22 matched 2 of 12 items and is left out.
- `tools/build-equip-spell-fix.py` (new; desk `itemdb-build` builder `equip-spell-fix`) applies it
  to the shipped class files in place, by item id, without replaying the walk. Keys raised, Vanilla
  at 1.15.9.69722: AP 596, melee AP 31, ranged AP 74, spell power 1,794, spell damage 378, healing
  632, mp5 513, health regen 38, resistances 74. TBC at 2.5.6.68941: the same families (AP 1,487,
  spell power 2,315, spell damage 1,458, healing 1,181, mp5 1,180, ...) plus 1,544 rating keys.
  A second run changes nothing. `build-core.py` applies the same correction to every new
  walk.
- KNOWN: the 15 TBC items whose walk folds melee and spell crit into one `ITEM_MOD_CRIT_RATING` fail
  the summed-base proof and stay one low. Wrath's on-equip stats: see the next section.
- `Tests/equip_spell_stats_check.py` (new, declared in `.writ-suites.json`): nothing left at the raw
  base, 4,879 Vanilla and 9,413 TBC keys at base + DieSides, and pins for 11815 (+20, the operator's
  tooltip) and 19406's TBC hit 20 / dodge 12 / AP 56 against the Mists walk. It was red on 11815
  before the fix.
- Peer Review 868b8260: the proof runs per row (a base and a seasonal row are proved separately;
  0 ids carry both today, so no data moved), and `parse_blob` / `apply_blob` in `itemdb_common` are
  the one blob rewrite, `apply_blob` raising on a delta it could not apply.
- Peer Review de472a90 finding 1: `EQUIP_DIE_KEYS`' `(13, None)` row also caught aura 13 misc 1
  (PHYSICAL damage), so TBC Bronze Band of Force 30804 -- 13/126 and 135/126 at 5 + 1 beside a
  13/1 at 0 + 1 -- was lifted by 2 to `SPELL_POWER` 7; the tooltip is 6. `(13, 1)` now maps to
  `SPELL_DAMAGE_DONE` only, which is how `GetItemStats` reports it (Might of Cenarius 21189, whose
  only aura is 13/1 at 3 + 1: TBC walk 3, Mists walk 4). `equip_die_keys` is the lookup (an exact
  entry wins), and `equip_die_overlift` undoes what the old lookup lifted; the fix tool ran it on
  TBC (30804 7 -> 6, the only row) and Vanilla (none). The check pins 30804 and 21189 and asserts
  nothing is left over-lifted.

### Wrath on-equip spell stats (data)

- `Data/Wrath/_core` shipped every on-equip aura stat EMPTY: Hand of Justice 11815 and Drake Fang
  Talisman 19406 had no stats at all. `build-core-wago.py` builds Wrath from ItemSparse, which
  holds only an item's native stats; attack power, spell power, healing, mp5, health regen,
  armour and ratings on Classic gear are on-equip auras (ItemEffect -> SpellEffect).
- `build-core-wago.py` now decodes them under the classic profile (`aura_stats`, `item_auras`):
  the amount is base + DieSides (the tooltip); attack power and TBC ratings become ItemSparse stat
  slots so `fold_ratings` reports them exactly as stored ones; Wrath ratings take one unified key
  per group. The TBC walk gate holds it: 0 unexplained over 30,031 items, with 229 rows explained
  as the walk's own raw-base omission (see the previous section).
- Wrath rebuilt at 3.4.3.58936: auras decoded on 9,237 items, of which 9,231 ship -- the other six
  (209528-209533) have no ItemSparse row, so nothing is written for them (the builder now prints
  them); 24,359 items with stats. 11815 AP 20; 19406 AP 56 / hit 20 / dodge 12; 21189 physical
  damage 4; 30804 spell power 6 plus physical damage 1 -- each equal to the Mists walk, which
  reports the physical part as spell damage (see the next section).
- `WALK_DRIFT['TBC']` gains 34702: 2.5.5 ItemSparse armour 74, TBC walk 78, Wrath ItemSparse 78.
- Aura 123 misc 1 (ignore N armour) is decoded as `ITEM_MOD_IGNORE_ARMOR` for every version (see
  the spell-penetration section). No Wrath item carries it: 3.x converted those items to armour
  penetration rating, which Wrath ItemSparse already holds (904 items).
- `Tests/core_wago_check.py` compares the shipped core against ItemSparse PLUS the auras, asserts
  the decode found more than 5,000 items, and pins the five items above.
- Cata is built from the modern profile, whose ItemSparse already reports these stats (its 19406
  carries AP 56); the aura decode is off there and Cata was not rebuilt.

### The two on-equip aura decodes are held to agree (tools only, Peer Review de472a90 finding 5)

- `itemdb_common.EQUIP_DIE_KEYS` (the walk keys an aura is reported under) and `build-core-wago.py`'s
  `AURA_AP` / `AURA_KEY` / `RESIST_AURA` / `TARGET_RESIST_AURA` / `CR_BIT_STAT` / 13-135 pairing (the
  Wrath decode) say the same thing in two shapes; the wago one folds ratings and attack power through
  ItemSparse stat slots, so it cannot simply read the other table.
- `Tests/aura_decode_agree_check.py` (new, declared in `.writ-suites.json`) decodes every
  `EQUIP_DIE_KEYS` entry as a one-aura item through the real `sparse_stats` and requires the keys to be
  ones that table names (or their `EQUIP_STORED_KEY` respelling) at `equip_amount`. What one side
  knows and the other deliberately does not is listed exactly: aura 22's magic schools (not decoded
  by the classic profile), 22's armour bit (not in the lift), and aura-189 bits 17-19 / 23-24 (no
  single-aura walk evidence). 42 checks; red on a planted `AURA_KEY` 161 respelling.

### Spell penetration one high, and armour-ignore stored as spell penetration (Peer Review de472a90 finding 4)

- Spell penetration is aura 123 (MOD_TARGET_RESISTANCE) with a NEGATIVE base. The Classic Era and
  TBC `GetItemStats` reports it negated and, like the positive auras, without the die: walk
  `-(base)`, tooltip `-(base + DieSides)`, so every walk value was one HIGH. Verified on three
  wowhead tooltips, 2026-10-18: Field Marshal's Silk Spaulders 16444 walk 11, "by 10"; Doomcaller's
  Robes 21334 walk 21, "by 20"; Shady Dealer's Pantaloons 30898 walk 176, "ignore 175".
  `equip_die_corrections` could not see it: it summed the raw base (-11) against the walk's 11.
- `itemdb_common.EQUIP_AURA_SIGN` (`{123: -1}`) and `equip_amount` make the lift, the respell proof,
  the fix tool's derivation and `build-core-wago.py`'s decode read the aura as positive.
  `EQUIP_DIE_KEYS` gains `(123, None)` -> `SPELL_PENETRATION`.
- Aura 123 misc 1 (PHYSICAL) is "your attacks ignore N of your opponent's armor", which the TBC
  walk also reports as `SPELL_PENETRATION`, so casters' scales priced a rogue's pants. It is now
  stored as `ITEM_MOD_IGNORE_ARMOR` (ItemDB's own spelling: `F:\Blizzard API Docs\GlobalStrings\enUS.lua`
  has only `ITEM_MOD_ARMOR_PENETRATION_RATING` and `ITEM_MOD_EXTRA_ARMOR`, and a rating is a different
  stat -- Peer Review 6e9ed265 F2) through
  `EQUIP_STORED_KEY`, and `physical_damage_renames` / `physical_damage_mixed` are renamed
  `stored_key_renames` / `stored_key_mixed` because they now cover both.
- Data: TBC 192 rows lowered by 1 and 138 respelled; Vanilla 35 lowered (30 base, 5 seasonal; no
  Vanilla item carries misc 1). `build-equip-stats.py` emitted misc 1 as `SPELL_PENETRATION` too --
  and `GetStats` fills a key the core lacks from EquipStats, so 30898 would have carried both keys
  after the respell -- it now emits `ITEM_MOD_IGNORE_ARMOR`; TBC `EquipStats.lua` rebuilt at
  2.5.6.68941 (138 rows). Wrath rebuilt; the TBC gate's walk-raw-base explanations fell from 229 to
  37 and `SPELL_PENETRATION` (54) and `IGNORE_ARMOR` (138) are exact.
- Scoring: `Scoring/TBC.lua` lists `ITEM_MOD_IGNORE_ARMOR` ("Armor Ignored") with no shipped weight.
  KNOWN COST: it prices 0. HawsJon's TBC `ArmorPenetration` mapped onto it gave Arms 1.1 EP per
  point (175 ignored ~= 430 AP), which I could not confirm is a per-flat-armour unit, so the mapping
  was reverted and `BiSWeights.lua` is unchanged. So Arms and Fury scoring prices Shady Dealer's
  Pantaloons 30898's 175 armour ignored at 0 until a weight with a confirmed unit exists.
- `build-equip-stats.py` decodes aura 123 through `itemdb_common.equip_amount` with the row's own
  `EffectDieSides` instead of a hard-coded `base + 1` (Peer Review 6e9ed265 F5), so the sign rule has
  one copy. Vanilla and TBC `EquipStats.lua` rebuilt at their pins: no row moved.
- Pins: `equip_spell_stats_check` (51): 16444 / 21334 at 10 / 20 on Vanilla and TBC, 30898
  `IGNORE_ARMOR` 175 and no spell penetration, the negative-base lift on 16444's real rows
  (11 -> -1), the respell on 30898's, and 30804's real rows as the live witness of a MIXED key
  (13/1 beside 13/126, counted by `stored_key_mixed` and left as walked by `stored_key_renames`,
  Peer Review 6e9ed265 F4); red on 8 before the data fix. `core_wago_check` (59): Wrath 16444 at 10. `libitemdb_spec`: a TBC
  fire mage's spell-penetration weight prices `SPELL_PENETRATION` 175 and not `IGNORE_ARMOR` 175.
- The TBC gate's walk-raw-base explanation is a value coincidence, so it now applies only to the
  37 (item, key) pairs checked in at `tools/walk_exceptions.json` (`build-core-wago.RAW_BASE`); a
  new match fails the gate and shows as a diff of that file (Peer Review de472a90 F6).
  `core_wago_check` (61) holds the observed set equal to the file both ways; red on the empty list.
  It also refuses a pair written twice (the json loads into a set, which would hide it), and
  `explain()`'s docstring says the raw-base test runs first, so a mismatch another reason would
  cover must still be listed (Peer Review 2f81f49d N1, N2).
- `WALK_DRIFT` (the 12 TBC items whose armour the walk and every cached ItemSparse disagree on)
  moved out of `build-core-wago.py` into the same file, with its explanation, so both per-item
  exception lists live in one place in one form. `verify()` now reports the drift ids it used, and
  `core_wago_check` holds them equal to the file both ways, where it used to check only that the
  count did not exceed the list -- a listed item that stopped drifting went unnoticed. Red on a
  bogus listed id.
- `aura_decode_agree_check` (51) counts resilience bits 14-16 among the unproved rating bits, and
  sweeps every aura id 0..511 against 27 masks: anything that decodes must be an aura
  `EQUIP_DIE_KEYS` knows, and each any-misc entry must agree on every mask it decodes (162 pairs),
  not one representative (Peer Review 7fb1a54b). Red on a planted constant-free aura-200 branch and
  a planted (161, 4) respelling. No unexpected hit.
- `aura_decode_agree_check` (54) now also holds the aura-189 masks `EQUIP_DIE_KEYS` does not name
  (13 in the sweep): each may land only on the keys of the named masks it shares a bit with. Two
  exceptions are listed exactly: a single hit bit (32 or 64) folds to `HIT_MELEE_RATING` /
  `HIT_RANGED_RATING`, where the walk evidence (mask 96) is `HIT_RATING`. No TBC walk item carries
  either split hit key, so neither side has evidence against the other, and `Scoring/TBC.lua`
  aliases both onto `HIT_RATING`. The masks no named mask covers must be exactly the unproved
  rating bits. Red on `CR_BIT_STAT` bit 9 pointed at spell crit.
- That sweep only held single bits, so it now also decodes every aura-189 mask an on-equip spell
  really carries in the cached TBC and Wrath data (13 masks; the unnamed multi-bit ones are exactly
  224 and 1792, pinned). 1792 (all three crits, Wrath item 867) folds to `CRIT_RATING`, a key
  neither named crit mask names; the TBC walk itself reports that fold for a 768 and a 1024 aura at
  one amount (16577, 29598, ...). It is listed by hand as `FOLD_189` and asserted exactly, rather
  than allowed by calling the decode under test (Peer Review b7dc73db S1, 4b920cc8). Red on 1792
  before it was listed. (54 -> 57 checks.)
- Item 34095 is `HIT_RATING` 100 in the TBC core and melee 200 / ranged 100 in Wrath because the
  item changed, not the decode: the test ring has no aura, and 2.5.5's row is melee 100 + ranged
  100 ("Indalamar's Ring of 100 Hit Rating") where 3.4.3's is 200 / 100 ("...of 200 Hit Rating").
  `core_wago_check` (63) pins both rows (Peer Review b7dc73db S2).

### Physical damage no longer priced as spell damage (todo #8, Peer Review a93de54c)

- "+N physical damage" (aura 13 misc 1, Might of Cenarius 21189 "+4 damage") is reported by
  `GetItemStats` as `ITEM_MOD_SPELL_DAMAGE_DONE`, so the Vanilla and TBC walk cores stored it there
  and every scale priced a melee ring as spell damage. My Wrath rebuild above did the same, and
  `Scoring/Wrath.lua` aliases that key to spell power.
- The cores now store it as `ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT`, the spelling the Forever walk
  already uses. `itemdb_common.EQUIP_STORED_KEY` is the one table (walk key -> stored key);
  `stored_key_renames` respells a key only when every aura reporting under it is a 13/1 aura
  and the value equals their summed base + DieSides, the same proof shape as the DieSides lift, so an
  item mixing physical and school damage under one number is left as walked. New
  `stored_key_mixed` counts those, and the fix tool and `equip_spell_stats_check` print the
  count: 0 in every Vanilla and TBC scope today (Peer Review 0c2a1e34 finding 3). New
  `rename_blob` raises on a missing or colliding key.
- Applied by `build-equip-spell-fix.py` (after the lift) and by `build-core.py`'s
  `lift_equip_dies`: TBC 4 rows (21189, 21766, 24114, 32654; 30804 has no spell-damage key, its
  physical aura's raw base is 0), Vanilla 20 (21189 and 19 seasonal items). `build-core-wago.py`
  emits the stored key directly for every version and compares it in the TBC gate (4 exact, 30804's
  1 explained as walk-raw-base, 0 unexplained); Wrath ships it on 5 items, and its spell-damage-only
  rows (97) are school damage.
- Scoring: Vanilla, TBC and Wrath list it in `weightStats` ("Physical Damage") with no shipped
  weight, so it prices 0 and no breakdown calls it unknown. Its value scales with weapon speed, so a
  flat weight would be wrong; a custom scale can still set one. The stale "one legacy item" comment
  in `Scoring/Wrath.lua` is corrected.
- Mists (Peer Review 0c2a1e34 finding 4): an earlier line here said the Mists wago schema has no
  `EffectBasePoints`, so the proof could not run. That was wrong -- `SpellEffect` at 5.5.4.68806
  carries it (desk `itemdb-schema`); the Mists core had simply been built before the rename
  existed. `build-equip-spell-fix.py Mists` respelled 5 rows (21189, 21766, 24114, 32654 and
  30804's physical 1, which Wrath's DB2 decode also gives), matching the TBC core by item id;
  185987's spell damage 20 is a real school aura and stays. It also lifted 4 seasonal ranged-AP
  rows (185985, 186069, 199722, 209803) by 1, to the TBC walk's and Wrath decode's value: Mists'
  walk reports aura 124 at the raw base, unlike the other auras. `Scoring/Mists.lua` lists
  "Physical Damage" in `weightStats` like the other three. Pins: `equip_spell_stats_check` now
  covers Mists (21189, 32654, 30804, 185987, 185985; red-checked by putting 21189's old spelling
  back), and `mists_scoring_spec` holds 21189's 4 at 0 with no unpriced row (red-checked by
  removing the vocabulary row). In-game tooltips not checked.
- Pins: `equip_spell_stats_check` (40): 21189 physical 4 and no spell damage on Vanilla and TBC,
  nothing left to respell, `rename_blob`, the proof on 21189's real rows (4 respelled, raw 3 not),
  and `build-core.lift_equip_dies` turning a raw walk record's 3 into physical 4 -- red-checked by
  removing the rename from `lift_equip_dies`. `core_wago_check` (58): Wrath 21189 physical 4 /
  no spell damage, 30804 spell power 6 / physical 1. `wrath_scoring_spec`: 21189's 4 scores 0 for
  a holy priest with no unpriced row, where the walk spelling scores 4.

### Melee + ranged rating twins counted once in scoring (Peer Review de472a90 X1)

- One aura improving melee AND ranged crit (TBC aura 189 misc 768) is reported under both
  `ITEM_MOD_CRIT_MELEE_RATING` and `ITEM_MOD_CRIT_RANGED_RATING`, and every flavour's rules alias
  both onto `ITEM_MOD_CRIT_RATING`. `scoreStats` summed them, so Gloves of Holy Might 867 (14 and
  14 for one +14 line) scored as 28 crit rating. At least 391 TBC core rows carry such a pair
  (Peer Review's lower bound from a text search, not counted by me).
- `LibItemDB-1.0.lua` `settleTwins`: crit, hit and haste melee/ranged pairs that alias to the same
  key now count once, by attack power's sign rule (`apPairEp`: same sign takes the larger, opposite
  signs sum). A lone side and the generic key are untouched. This LOWERS the EP of every such item
  -- a correction, not a regression.
- `Tests/wrath_scoring_spec.lua`: three specs (each twin family, the sign rule, one breakdown row).
  Red-checked: with the `settleTwins` call removed exactly these three fail (947 passed, 3 failed).
  A fourth pins an unequal pair (12 / 20) as ONE breakdown row at 20: rows are keyed by the alias
  (`ITEM_MOD_CRIT_RATING`), so the melee-or-ranged spelling `settleTwins` keeps (Peer Review
  a93de54c F7, now the side `apPairEp` chose) never reaches a label.
- KNOWN COST (Peer Review de472a90): an item with a melee-only crit aura AND a both-types crit aura
  reports melee greater than ranged; settling keeps only the larger, so the ranged-only part is
  dropped for a hunter. Whether any shipped item has that shape is not verified.

### Hand of Justice's extra attack priced in EP (MINOR 45 -> 46)

- Operator, 2026-10-18: Hand of Justice (11815) showed only its Attack Power in Dibs' EP and
  nothing for the 2% extra attack. `tools/build-use-effects.py` priced an extra attack as one swing
  of the item's OWN weapon damage, so a non-weapon had nothing to price with and was filed in
  `LoadUnscoredProcs`. It now ships `{b="extra_attack", m=<swings>}` for any item with no
  weapon damage in the client data; a weapon with damage (Ironfoe) keeps its `damage` row. The
  Wrath heirloom Battleworn Thrash Blade (44096) is a weapon yet ships `extra_attack`
  (`Data/Wrath/_core/UseEffects.lua:445`), so the builder found no damage for it; that a scaling
  heirloom carries none in ItemSparse is the likely reason, not verified.
- `LibItemDB-1.0.lua` `scoreProcEffects`: new `extra_attack` bucket (breakdown key
  `PROC_EXTRA_ATTACK`, label "Extra attack proc"): extra swings per swing (rate / swing rate x m,
  i.e. ch% x m) x white DPS x the `DPS_MAINHAND` weight only, since extra attacks are melee. White
  DPS is `opts.attack.weaponDPS`, else the new `model.whiteDPS`. `Scoring/Vanilla.lua` declares 90,
  the figure its weapon-skill scorer already assumed (`WS_DEFAULT_DPS` now reads it, one constant).
  Arms warrior: 0.02 x 90 x 5.31 = 9.6 EP added to HoJ.
- Assumption, stated: only swings are counted as triggers and the extra attack's rage and
  on-next-swing interactions are not modelled, so this is a floor, not a sim result.
- Data: `Data/Vanilla/_core/UseEffects.lua` rebuilt at 1.15.9.69722 (HoJ is the only Vanilla
  item: 190 -> 191 proc rows, 334 -> 333 unscored); `Data/Forever/_core/UseEffects.lua` at
  1.60.1.69913 (10 extra-attack items, 477 -> 467 unscored).
- Superseded by "Hand of Justice priced on TBC, Wrath and Mists" at the top of this version: the
  missing half on TBC and later was the RATE, and TBC and Mists now declare a `whiteDPS`. Vanilla's
  row carries `ch=2`; Wrath's 44096 row carries `ppm=1.08`.
- Wrath now declares `whiteDPS = 223` in `Scoring/Wrath.lua`'s fallback `MODEL`, so the
  heirloom Battleworn Thrash Blade (44096) prices its extra attack instead of scoring 0. 223 is
  the weapon DPS of Betrayer of Humanity (40384, Naxxramas-25 two-hander): (606 + 910) / 2 / 3.4,
  read from WoWSims WotLK `assets/database/db.json`. It leaves out attack power, so it is a floor.
- Tools: `tools/tarball-read.py` (desk `itemdb-tarball`) gained a `grep:<path-end>:<regex>`
  mode, because `db.json` is too large to print whole. The tool's command did not change. A bad
  regex or a spec with no `:` now prints one error line instead of a traceback (`parse_grep`,
  which `main` sends every `grep:` argument through), pinned by `Tests/tarball_read_check.py`
  (new, declared in `.writ-suites.json`). That check covers `parse_grep` only, so a `main` that
  compiled the pattern inline again would stay green.
- `Tests/libitemdb_spec.lua`: seven specs (the warrior value, the hunter using the main-hand and
  not the ranged weight, the paperdoll override, a caster at 0, the itemized row's factors, the
  main-hand swing rate, a set stage). Red-checked by disabling the bucket: exactly the six value
  specs failed.
- Peer Review 366810d1. E1: the share divided by `hitsPerSec`, the same rate that multiplies a
  swing-triggered row, so the two cancelled and a dual-wielder (more hits than main-hand swings)
  priced HoJ low. It now divides by `opts.attack.mainSwingsPerSec`, else `model.mainSwingsPerSec`,
  else `hitsPerSec` (default scores unchanged). F2: the model / rate resolution was written at four
  sites and the `weaponDPS` override at two; new local `procContext` serves all four (both
  `GetItemScore` / `GetItemScoreBreakdown` item and set paths, `GetSetBonusEP`).

## [v1.6.0] - 2026-10-17

The first four sections below ship (a second Vanilla BiS provider; threat and armour
reduction priced in EP -- both MINOR 45; on-use rating trinkets priced from TBC on; `IsBiS`
returning a fresh list); the rest are under `tools/` or `Tests/`, which the packager does not
ship, plus `.pkgmeta` (packaging only) and `README.md`.

### Vanilla: a second BiS provider, "bisclassic", through phase 6 (MINOR 44 -> 45)

- `Data/Vanilla/_core/BiSClassic.lua` registers `lib:LoadBiS("bisclassic", ...)`: 623 sets for
  9 classes, phases 0-6, including the fire / nature / shadow / frost / arcane resistance lists.
  The `wowsims` provider stops early (hunter at phase 1, mage and shadow priest at 1, rogue at 2,
  warlock at 0 + 2, warrior tank at 1; WoWSims master checked 2026-10-16), so nothing in the
  library answered "what is BiS in AQ40 / Naxx" for most classes (Dibs thread 000389037f53, the
  Badge of the Swarmguard report). `wowsims` stays the default: `ItemDB.toc` loads it first.
- Source: BestInSlotClassic (GPL-2.0, github.com/Warkdev/BestInSlotClassic) at commit
  302ab4ecca0c, cached by the new `tools/fetch-bisclassic.py` (desk `itemdb-fetch`, source
  `bisclassic`) and read by the new `tools/build-bis-classic.py`. Facts extracted, files not
  redistributed -- the AtlasLootClassic terms. Its model is a per-class/spec priority ranking
  plus each item's phase; the builder mirrors its `SearchBis` (an item counts from its phase on,
  lowest priority wins). Choices the source leaves to its UI, made here: phase 0 is phase 1
  without raid or world-boss items; a fractional phase (2.5) counts from the next whole phase;
  PvP-rank gear is left out; random-suffix rankings collapse to the bare item id.
- Weapons and races (Peer Review 5ba689c6 B1-B3; the first cut got all three wrong and built
  warrior fury phase 1-2 from the Orc main hand 17068 and the Human off hand 18832, a pairing no
  race's list gives). Now: ONE SET PER RACE GROUP (the races whose rankings are identical), the
  largest group on the plain token and the others suffixed with their race names
  (`default_human`, `default_orc`, hunter `default_dwarf_nightelf`); one-hander and two-hander
  priorities are never compared -- the source numbers them as separate lists -- so a spec its
  `WEAPON_ICONS` offers both setups gets the one-hand set on its token and the two-hander on
  `<token>_2h` (dropped when it ranks no two-hander); rankings are keyed by (item, OffHand), so
  an item the source ranks as both a main hand and an off hand (19363, 19104, 19170) keeps both.
  `Tests/bis_classic_check.py` gains fixtures for each, red-checked by restoring the merge and the
  item-only key (both went red, then green).
- KNOWN, reported to Dibs: Badge of the Swarmguard (21670) is BiS here for Enhancement Shaman
  (phases 5-6), not for hunters -- BestInSlotClassic ranks it 12th-13th among hunter trinkets,
  behind Drake Fang Talisman and Jom Gabbar. `IsBiS(21670)` now answers for the shaman.
- CONSUMER-VISIBLE through an unchanged API: `IsBiS(itemID)` with no `source` reads every
  loaded provider, so on Vanilla it now also returns `bisclassic` hits -- including the
  resistance lists. A consumer that shows "BiS for ..." from it without a source will show more.
  Pass `"wowsims"` to keep the old answer.
- Items restricted to one faction (the source's `Faction` field) are not filtered: a set is
  faction-agnostic, like `wowsims`'.
- `split-seasonal.py` skips `BiSClassic` like `BiS` (it is keyed by class, not item).
- `Tests/bis_classic_check.py` pins the selection rule on a synthetic ranking.
- Peer Review c9097ad3 B6-B8. New `lib:GetBiSSetSpecs(classID [, source])`: the sorted spec
  tokens a FIXED SET source holds (default: the default set source), so a consumer finds
  `default_human` or `tank_2h` without rebuilding the naming rule. `GetBiSSpecs` was the only
  lister and reads the EP weight scales, which carry none of those tokens; its README row now says
  so. Same MINOR 45, because 45 is not released yet. README `IsBiS` row: one hit per spec token
  per phase, so a warrior item in all three race groups' lists gives three a phase.
  `build-bis-classic.py` `race_rankings` evaluated only the races some row named, so a playable
  race no row named got no set at all. New `PLAYABLE_RACES` (the original-Classic race/class
  matrix): with an unrestricted row present every playable race is evaluated and an unnamed one
  gets the unrestricted rows, as the source's `SearchBis` gives it; without one, a missing race
  or a named race the class cannot be is refused. The real cache builds the same 623 sets. Four
  new fixtures, red-checked by disabling the unnamed-race path (the check went red).

### Vanilla and TBC: threat reduction and target-armour reduction priced in EP (MINOR 45)

- Operator, 2026-10-16: _"threat reduction is HUGE for DPS classes"_. Fetish of the Sand Reaver
  (21647, -70% threat for 20 s every 3 min), Eye of Diminution (23001, -35% for 20 s every 2 min),
  Badge of the Swarmguard (21670) and, on TBC, Icon of Unyielding Courage (28121, ignore 600
  armour for 20 s every 2 min) were in `LoadUnscoredProcs`, scored 0, and Dibs' list hid them.
- `tools/build-use-effects.py`: the on-use path now emits `THREAT_REDUCTION_PCT` /
  `SPELL_THREAT_REDUCTION_PCT` (aura MOD_THREAT, sign flipped so a reduction is positive) and
  `TARGET_ARMOR` (aura 123 MOD_TARGET_RESISTANCE, negative, armour bit). New `use_window`: an
  on-use spell whose aura is a proc trigger (the Badge) emits the AVERAGE stack count over its
  window -- Poisson arrivals at the proc's CMaNGOS `spell_proc_event` ppm (26480: 15 per minute),
  capped by the triggered aura's `CumulativeAura` -- 661.1 armour, not the 1,200 cap. New pure helpers `use_keys` / `average_stacks`, pinned by the new
  `Tests/use_window_check.py` (18 assertions, red-checked by restoring the old sign test).
- `Scoring/Vanilla.lua` / `Scoring/TBC.lua`: derived rules for the three keys through the spec's
  crit weight (1% crit taken as 1% damage, 0.5% for spell crit). Armour: `(A + K) / 100` points per
  1%, Vanilla `A = 3731`, `K = 5500` (WoWSims Classic level-63 boss and armour constant); TBC
  `A = 7685` (Magtheridon), `K = 10557.5`, through crit rating. Threat 1:1 with damage is an UPPER
  BOUND, ItemDB's own and stated as such; no community weight exists for it.
- `LibItemDB-1.0.lua` `effectWeight`: a derived rule may carry `exclude = { [classID] = { [spec] =
  true } }`, read from `lib.bisWeightsSpec`. Threat reduction excludes every tank and healer spec.
  A scale not registered through `LoadBiSWeights` has no spec and is not excluded.
- Data: `Data/Vanilla/_core/UseEffects.lua` and `Data/TBC/_core/UseEffects.lua` rebuilt at the
  builds their siblings carry; the diff is exactly those items leaving the unscored list. The
  post-build `split-seasonal.py` added its partition marker line to `Data/Vanilla/_core/ItemPlaces.lua`
  and `TokenRewards.lua`, which had not been through it before; no row changed.
- `Tests/libitemdb_spec.lua`: seven specs on synthetic rows (armour and threat pricing, the
  tank / healer exclusion, an unregistered scale), red-checked by disabling the exclusion.
- Peer Review 917f21ea follow-ups. The exclusion list is ONE table, `lib._noThreatSpecs` in the
  core, which both `Scoring/Vanilla.lua` and `Scoring/TBC.lua` read (each carried its own copy).
  New specs: both flavours' threat rules hold that table; every spec it names is a spec the shipped
  Vanilla, TBC and Forever scales load (red-checked with `feral_tnak`); and no two specs in any
  flavour's shipped scale share one table, since `lib.bisWeightsSpec` is keyed by table and a
  shared one would carry the last spec's exclusion. The TBC `[2].default` and `[5].default` scales
  are byte-identical to `holy` and `discipline`, so excluding them is correct.
  `Data/Forever/_core/UseEffects.lua` rebuilt at 1.60.1.69913 (Forever loads `Scoring/Vanilla.lua`):
  15 -> 17 on-use rows, 480 -> 478 unscored.
- Peer Review a7919e37. The Badge of the Swarmguard (21670) still scored 0 on Forever: `use_window`
  read its ppm from CMaNGOS only, and Forever has no CMaNGOS DB. It now falls back to the
  version's OWN wowsims ppm (by the on-use spell, then by the item; a per-hit chance is not a ppm
  and is skipped), never Vanilla's CMaNGOS rate, which `build-sets.py` removed as a defect.
  Forever rebuilt at 1.60.1.69913: 17 -> 18 on-use rows, 478 -> 477 unscored; the Badge prices at
  481.3 armour (Vanilla, at CMaNGOS's 15 ppm: 661.1). `Tests/use_window_check.py` now also reads
  Forever's file (26 assertions). New spec, the reverse of the token check: every tank or healer
  scale in the Vanilla, TBC and Forever weights (Stamina weighted 0.5 or more, or healing 0.5 or
  more and above spell damage) is in `lib._noThreatSpecs`. Red-checked by dropping shaman `tank`
  from the list, and the shared-table spec by aliasing one Vanilla rogue scale: exactly those two
  failed. The `_noThreatSpecs` comment now names Forever.

### TBC to Mists: on-use rating trinkets priced; the Badge scored on Wrath and Mists

- `build-use-effects.py`'s `use_keys` had no branch for aura 189 (MOD_RATING), so every on-use
  buff that grants a combat rating (haste, crit, hit, dodge, armour penetration, mastery ...) fell
  through to the unscored list on every flavour from TBC on. It now decodes the mask through the
  shared `itemdb_common.rating_keys(misc, version)`, the table `build-effects.py` and
  `build-aura-buffs.py` already use, so an on-use trinket and a food carrying the same bit name the
  same key. Rebuilt, each at the build its siblings carry: Wrath 115 -> 166 on-use rows (940 -> 889
  unscored), Cata 189 -> 273 (1421 -> 1338), Mists 264 -> 399 (1954 -> 1820); TBC now ships 83
  on-use rows and 601 unscored. Vanilla and Forever are unchanged (no aura 189 in a 1.x client).
- The Badge of the Swarmguard (21670) on Wrath: CMaNGOS wotlk has its ppm (15), but there its
  stacking aura is +28 armour penetration rating, not -200 target armour, so the missing rating
  branch was the whole cause. It prices at 92.6 armour penetration rating.
- On Mists: no CMaNGOS DB, and wowsims/mop does not model the Badge. `use_window` now also reads
  per-spell ppm from Mists' own SkyFire 5.4.8 world DB (`mistsskyfire.sqlite`, the same
  `spell_proc_event` columns), Mists only, so Cata never takes Mists' number. 26480 is ppm 3 there;
  the stack is +28 crit rating on that client, so the Badge prices at 21 crit rating. Meteorite
  Crystal (46051, SkyFire ppm 5) also gained a use window: 100 spirit.
- On Cata the Badge stays unscored: no world DB, and the cached wowsims/cata source has no Badge
  model (its only TBC trinket file is commented out).
- Peer Review cc49825a U1/U2: the build log now names the tier each use window took its ppm from
  (Forever: wowsims/forever spell 26480, ppm 10, 2.407 stacks), and `use_window`'s docstring notes
  that the by-item wowsims tier keeps an item's first proc. `Tests/use_window_check.py` pins
  Forever's `m=481.3`, the Wrath and Mists Badge rows, and five `use_keys` aura-189 cases (33
  assertions); red-checked by disabling the branch, exactly the three positive decodes failed.

### `IsBiS` returns a fresh list (Peer Review cc49825a I1)

- `lib:IsBiS(itemID)` with no source returned the reverse index's own list, so a consumer that
  sorted or trimmed the result edited every later answer for that item until the index rebuilt.
  Both paths now build a new list (the hit records inside are still shared). New spec mutates one
  result and asserts the next call is unchanged; it failed (3 expected, 4 got) before the fix.

### Tools only -- the armor-curve verify says what it skipped (Peer Review 3748bed0)

- My TBC self-audit said shields went unchecked because wago serves no `ItemArmorShield` at
  2.5.6.68941. Wrong: no TBC shield carries walk armour (507 of them, the TBC walk's KNOWN COST),
  so `verify_armor` skipped every one at its `want <= 0` test before the table mattered, and the
  run printed only exact / low / OVER -- a green line that read as if shields were covered. The
  verify now prints a "not checked" line: shields and cloth/leather/mail/plate with no walk armour
  (the latter named, up to 12). TBC at 2.5.6.68941: 507 shields and 6 body pieces skipped (4728,
  5091, 19837, 33073-33075 -- ilvl-0 placeholders, a shirt-slot and a ranged-slot piece), 11,362
  exact, 0 OVER. The comment that claimed the
  unchecked count stops a TBC run is corrected: it guards only a version whose walk carries shield
  armour (Vanilla, Forever, Mists, Retail). `verify_armor` now returns a third value, the skipped
  counts.
- A hidden item (test / placeholder, never served) that comes out OVER is excused, named and not
  failed; hidden items that match still count as exact. Forever's OVER row 16213 is "Test Quality
  Modifier Chest", whose armour is whatever a developer typed. (The first cut skipped every hidden
  row, which cut TBC's exact matches from 11,362 to 9,769 -- caught in the self-audit.)
  `hidden_ids` moved from `build-core-wago.py` into `itemdb_common` so both builders read Hidden.lua
  one way.
- Forever's other OVER row, 273646 "Half-Eaten Boots" (walk 43, curve 143), is now a listed
  `ARMOR_EXCEPTIONS` entry, printed by name on every run. The row is still compared: only an OVER
  result is excused, and an entry whose row is no longer OVER prints as STALE so it cannot go on
  excusing nothing. Its cause is NOT VERIFIED: wago's Forever
  `ItemSparse` at 1.60.1.69913 has no row for it (its `Item` row is there). A "-100 Armor" bonus
  would fit the gap exactly. Forever's verify now exits 0 (7,537 exact, 592 low, 0 OVER); Vanilla
  passes too (6,715 exact, 12 low, 0 OVER).
- `Tests/armor_curve_check.py` 13 -> 18 checks. The skipped-count check was written first and
  failed on the old two-value return.

### Docs -- the changelog back under GitHub's release-body limit

- CHANGELOG.md was 127,330 characters, over GitHub's 125,000-character release-body limit, so the
  next release would have been rejected with HTTP 422. v1.1.3, v1.1.2 and v1.1.1 moved unchanged
  to CHANGELOG_ARCHIVE.md; checked section by section (32 before, 32 after, no word changed).
- markdownlint's line-length rule (MD013) stays off. Turning it on at 80 columns (Peer Review
  b4eb143b, M1) was tried and reverted on the operator's ruling, 2026-10-17: "there is only one
  line length rule, you need to move stuff from the changelog into the archive". The one length
  this repo keeps is the changelog's size, kept by archiving the oldest whole versions. The
  80-column reflow tool written for M1 was removed with it.
- The `markdownlint` suite was shown to fail (with MD013 on it exited 1, so the npm shim passes
  the failure through), and it now lints CHANGELOG_ARCHIVE.md too (Peer Review b4eb143b, M2).
- CLAUDE.md: "merge- precedence" corrected to "merge-precedence", and the README rules' closing
  paragraph ("Write it for a dev...") moved out of the last nested bullet it had been read into.

### Tools only -- `derive-core-maps.py` re-run on Vanilla, TBC and Mists (Peer Review d89d615b)

- First run of `read_walk_core` on `itemdb_common.core_rows` since the v1.4.1 refactor: every
  InventoryType maps to one token on all three versions, matching `itemdb_common.INVTYPE`. Every
  stat id's top key matches `build-core-wago.STAT_KEY`, or `EXTRA_ARMOR` / `RESIST_STAT` for ids
  50-56, except Mists ids 11 and 40 (2 items each, no mapping; not investigated).
- The structural check now NAMES every item where wago and the walk disagree (the full list, not
  a truncated one), instead of only counting them. TBC's 2 are the WoW Tokens (122270, 122284), which the client reports as quality
  8 with no subclass. Mists has 98 quality, 18 item-level and 7 subclass differences, where the
  shipped walk value is the client's own answer; nothing shipped changed.
- The comment claiming the true stat key "wins by orders of magnitude" is replaced with what was
  measured: about 3-4 to 1 for the primary stats, with ratings among the runner-ups on TBC/Mists.
- A stat id with five or fewer hits now lists its items. That named Mists ids 11 and 40: Test
  Sword Chest 13712, Test Sword Skill Trinket 33003 and Juno's Test Gem 34967, all in
  `Data/Mists/_core/Hidden.lua`. `build-core-wago.py` documents them as deliberately unmapped.
- `build-core-wago.py` gains `verify_structure()`: before it writes Wrath/Cata it reports where
  wago's quality, subclass, equip slot and item level disagree with the TBC and Mists walks, which
  `verify()` (stats only) never compared. Its docstring said the gate compared "every emitted key on
  every item", which read as covering structure; it now says the gate is stats only. Report-only, because no Wrath/Cata client is on hand to say which
  side is right; `Tests/core_wago_check.py` holds the counts exactly (TBC: the two WoW Tokens;
  Mists: 98 / 7 / 18), so a new drift goes red. Red-checked by reading item level from the wrong
  field: both counts failed.
- Forever also run: its ItemSparse carries no stat amounts, so nothing matches by value; its core
  is walk-built, so nothing shipped depends on that.
- Peer Review c53c25e2 nits: `verify_structure`'s docstring names the equip slot it compares, and
  the header `build-core-wago.py` writes into Wrath/Cata files now says stats are gated and
  structure only reported. The shipped Data headers pick that up at their next rebuild.

### Packaging -- `.pkgmeta` cleaned, and its checker declared

- `.pkgmeta` carried comment lines, which the no-comments rule forbids; removed. One was
  `# curseforge-project-id: 1558208`, which the packager never read: `release.sh` takes the id
  from `-p` or the TOC's `## X-Curse-Project-ID: 1558208` (in `ItemDB.toc`).
- Dropped the `"*.sh"` and `"*.bat"` ignore entries; no tracked file matches either.
- The harness's `.pkgmeta` checker is now the declared `pkgmeta` suite in `.writ-suites.json`.
  Its WARN [7] (no `curseforge-project-id:`) asked for a key `release.sh` does not read; reported to
  WoWAPITesting (inbox d446ea6d), fixed in harness f6e5fde, which reads the TOC id instead.

### Docs -- `GetTokenRewards` named a `GetSlot` the library does not have (Dibs, inbox 65ade047)

- The comment above `lib:GetTokenRewards` and its `README.md` row told consumers to read each
  reward's slot with `GetSlot`. No such method exists, so following that raised a nil-method
  error. Both now name `GetInfo`'s 5th return (`equipLoc`). Comment and docs only.

### Tests -- harness pin 407bd26 -> f6e5fde

- Harness f5389cb runs a block's examples after its whole body, as busted does. That left
  `Tests/pricewindow_spec.lua`'s file-level `require("env.frames")` + `libs.load("LibAceGUIWidgets-1.0")`
  in place before its two "without the widget library" examples, and both failed. The load now
  happens once, in the window block's first `before_each`. Suite 926/926.

## [v1.5.0] - 2026-10-16

### Added -- a Shaman tank weight scale (Dibs' contract 46c74258)

- `GetBiSWeights(7, "tank")` now resolves on Vanilla, TBC and Forever, in the default `hawsjon`
  source. HawsJon publishes no Shaman tank scale and no published Classic one was found, so
  `tools/build-bis-weights.py`'s new `DERIVED_SPECS` copies HawsJon's own Protection Paladin
  scale -- the one published model of a mana-using shield tank whose threat comes from spell
  damage. Each generated `BiSWeights.lua` says in its header that `[7].tank` is a copy, not
  HawsJon's, and the builder refuses to copy once HawsJon publishes the spec itself.
- The copy drops `DPS_OFFHAND` (`DERIVED_DROP`). A paladin can never dual-wield, so that weight
  never applied to its own scale; a TBC shaman can (Dual Wield, 30798), and keeping it would let
  an off-hand weapon compete with a shield on a tank scale. Dropped on all three versions so they
  share one rule (Peer Review 4c1a17ee P3).
- `PARRY_PCT` is kept, verified from the client data rather than the talent's name: Enhancement
  talent 16268 ("Parry" on Era, "Spirit Weapons" on TBC) learns spell 18848, whose `SpellEffect`
  is the same effect (type 22) as the baseline Parry spell 3127, in both the 1.15.9.70003 and
  2.5.6.68941 tables. Shield Specialization backs the block weights and Anticipation the dodge
  weight. Forever's tree was not checked. (The first cut of this entry and the builder comment
  said TBC had no `Talents.lua` and that Anticipation gives defense; both were wrong -- Peer
  Review 4c1a17ee P1/P2.)
- `itemdb_common.header` writes a blank header line as `--` with no trailing space after it.
  Every builder's generated headers lose that whitespace the next time they are rebuilt.
- No scorer change: the Vanilla/TBC scoring rules carry no spec-keyed tables, and the
  per-class `ScoreModel` default applies. No MINOR bump -- the API is unchanged and Dibs detects
  the scale by `GetBiSWeights` returning non-nil.
- New `Tests/derived_weights_check.py` (declared in `.writ-suites.json`, red-checked by editing
  one weight in the shipped row, then by putting `DPS_OFFHAND` back) pins that each derived
  scale equals its source minus the dropped keys, that the header names it as a copy and each
  drop, and that `[7].default` is still `elemental`.

### Added -- what a tier token is turned in for (MINOR 44, Dibs' contract 1c5f8e8d2faf)

- `DB:GetTokenRewards(itemID)` returns the gear a boss-dropped token is exchanged for, every
  class's together, as a fresh table sorted by item id, or `nil` for an item that is not a token
  (never an empty table). Dibs prices a token by a substitute item level and slot, and asked for a
  default derived from the rewards. `lib:LoadTokenRewards` replaces per token. MINOR 43 -> 44.
- New `tools/build-tokens.py` -> `Data/<V>/_core/TokenRewards.lua` for Vanilla (87 tokens),
  TBC (159), Wrath (226) and Mists (115), listed in those four TOCs. The client has no such
  table; the exchange is server-side, so it reads the same world DB `build-droprates.py` does:
  `quest_template` turn-ins (every Vanilla token) and `npc_vendor`/`npc_vendor_template`
  `ExtendedCost` against the client's `ItemExtendedCost` DB2 (TBC onward). A token is an item
  required by count 1, not itself equippable, dropped by an encounter in `Sources.lua` or
  `DropRates.lua`, and rewarding equippable gear in that version's `_core`.
- Three defects found while building it, each fixed and pinned by the new
  `Tests/tokens_check.py` (declared in `.writ-suites.json`, red-checked):
  - Head of Onyxia and Head of Nefarian were missing: quest 7490 takes the head and rewards
    nothing; its `NextQuestInChain` 7491 needs no item and rewards the rings. A reward-less
    turn-in is now followed down its talk-only chain (depth 3).
  - Chestguard of the Fallen Defender listed six Gladiator pieces beside its seven T4 chests.
    tbc-db prices Karynna's Season 1 stock (template 555) at the same `ExtendedCost` 1235 the
    T4 vendor uses, and the 2.5.6 client reads 1235 as one T4 chest token. A vendor now counts
    only when most of its cost rows resolve to a token (template 554 and npc 26089 fail that,
    at exactly half), and a reward carrying resilience is never a token reward. Every T4, T5,
    T6 and Sunwell row now matches AtlasLoot's own token table (AtlasLootClassic
    `Data/Token.lua`, BCC); 29753 and 30243 are pinned against it.
  - SkyFire's `quest_template` has no required-item columns, so Mists refused to build; the
    quest half now degrades to nothing there and the vendor half carries it.
- Not covered, stated rather than hidden: Forever, Cata and Retail ship no file: the pipeline has no
  world DB for any of the three. Mists carries the Wrath-era tokens only;
  why Pandaria's own tier tokens are absent was not investigated. Wrath's Trial of the Crusader
  trophies were not checked. Nothing ran in a live client.

### Fixed -- the armor-curve verify hid its own failures (tools only, nothing ships)

- `tools/build-core-wowsims.py` `verify_armor` printed low and OVER rows from one list capped at
  12. Low rows (items with bonus armor, expected, often hundreds) filled the cap first, so the
  Forever run of 2026-10-12 reported `OVER 2` and named neither item. OVER rows are the failures,
  so they now print in full under their own heading; low rows keep the first-12 sample.
- That run's two OVER items are 16213 (walk 531, curve 541) and 273646 (walk 43, curve 143).
  16213 is "Test Quality Modifier Chest", flagged hidden, and its Forever `ItemSparse` row
  (1.60.1.69913) carries `QualityModifier=-10`, which `base_armor` does not read; whether that
  field accounts for the 10-armor gap is not verified. 273646 ("Half-Eaten Boots", Forever-only)
  has no row in the cached Forever `ItemSparse` at that build, so the walk came from a newer
  client and the item cannot be inspected at the pin. Players are unaffected: Forever's core is
  walk-built, so its shipped armor is the client's own figure and this formula does not reach it.
  Rerun 2026-10-12 with the fix: both rows print under `OVER:`; Vanilla unchanged (6,715 exact,
  12 low, 0 over).
- No shipped flavour carries curve-built armor today: every `Data/*/_core/Armor.lua` header (and
  Vanilla's `_seasonal/Armor.lua`) names `build-core.py` (a walk) or `build-core-wago.py`, and
  `build-core-wowsims.py` refuses to overwrite either. So neither OVER cause reaches a player.
- `armor_curves` treats `ItemArmorShield` as optional. wago answers HTTP 400 for it at TBC
  2.5.6.68941 while serving the other three curve tables, and the TBC verify died there before
  checking a single piece. Shields are now "not computable" (`base_armor` returns `None`) and
  `--verify` counts them as `unchecked`, never as low (low means "carries bonus armor"). A 504 or
  any other error still raises. The TBC verify itself has not run yet: wago answered 504 at both
  2.5.6.68941 and 2.5.5.67511 the same day.
- Peer Review (ad843502): unchecked rows first sat outside the total, so `--verify` exited 0 with
  every shield skipped, and a build at such a pin would have shipped every shield with no base
  armor. Now unchecked rows count toward the total and never toward a pass, so `--verify` exits 1
  while any remain; and the new `require_shield_curve` makes the build refuse when the shield
  table is absent and any shield would ship. A wrong 400 then costs a rerun, never bad data.
- New `Tests/armor_curve_check.py` (declared in `.writ-suites.json`, 13 cases) pins that path,
  the 504 re-raise, the build refusal, the failing partial verify and the robe-reads-chest row.
  Red-checked three ways: the `None` guard replaced with an empty table (got 0), the old return
  restored (got `(1, 1)`), and the refusal short-circuited (got `False`).
- New repo desk tools: `itemdb-verify-pinned` (a builder's `--verify` at an exact
  `--wago-build`, so the check reads the build the shipped files carry -- wago.tools answered 504
  for the installed 1.15.9.70003 while 1.15.9.69722 is cached) and `itemdb-derive-maps`
  (`tools/derive-core-maps.py --version V --wago-build B`, read-only; `itemdb-build` cannot pass
  its version flag).

## [v1.4.1] - 2026-10-12

### Fixed -- where-to-get places filed in the wrong zone (Dibs' DIBSREQ-IDB, Searing Whelp)

Dibs' report (inbox `2c393671f8ee`): Dibs showed Small Flame Sac dropping from Searing Whelps in
Thousand Needles on Classic Era. The whelps live in the Wyrmbog, Dustwallow Marsh.

- Root cause: `tools/build-item-places.py` files each spawn under the zone whose
  `UiMapAssignment` rectangle holds it. Those rectangles are map-image bounding boxes and overlap
  far past the real borders: every Searing Whelp (4324) spawn is inside the Barrens, Thousand
  Needles AND Dustwallow rectangles, and the tie-break ("the smallest rectangle") chose Thousand
  Needles. No rule over the rectangles alone gets it right (smallest, deepest-inside and nested
  were all tried), and the CMaNGOS `creature_zone` / `gameobject_zone` tables are empty.
- New `tools/fetch-questie.py` (desk `itemdb-fetch`, source `questie`) caches QuestieDB's
  (github.com/Questie/QuestieDB) NPC and object spawn tables for Classic, TBC, Wotlk, Cata, MoP
  and Forever at a pinned commit (`cd4ac424`, `tools/wago_cache/questie.source.json`), each file
  verified against its git blob id, and reads them: per entity, `{AreaTable zone: [(x, y)]}`.
  It shares `fetch-att.py`'s GitHub helpers (`resolve` / `fetch_one` now take the repo's API,
  cache and raw roots, defaulting to AllTheThings').
- `Placer.places` takes that as a hint: a spawn inside several rectangles goes to the zone
  QuestieDB files the entity under (nearest recorded point when it lists several candidates),
  then the zone the entity's unambiguous spawns use, then the smallest rectangle. The AreaTable
  id becomes a UiMap through the client's own `UiMapAssignment.AreaID` (`zone_areas`, a SET of
  UiMaps per area, so an area on two zone maps hints both). The coordinates shipped are still the
  CMaNGOS spawn's; QuestieDB only picks the zone, and none of its data is shipped. QuestieDB
  carries no licence file (GitHub's licence API answers 404, recorded in `questie.source.json`);
  it is a build-time input only.
- A hint whose nearest QuestieDB point is more than `HINT_MAX_YARDS` (250) from the spawn gives
  way to the entity's clear spawns, but still beats the smallest rectangle. Measured on shipped
  spawns before choosing it: Vanilla, the same world as QuestieDB, median 0 yards, 99th
  percentile 49, max 4,644; Cata, whose places are SkyFire 5.4.8 spawns against QuestieDB's 4.x
  points, median 0, 90th 50, 99th 560. It moved four entities on Cata and Mists, none elsewhere:
  Coral Shark (5434) drops The Cape of Stranglethorn, Winterfall Runner (10916) drops Felwood,
  and the Firefin Snapper and Oily Blackmouth schools (180683 / 180682) drop Thousand Needles.
  Which side is right for those four is not verified.
- `tools/fetch-questie.py` refuses a line that opens a row (`[<id>]`) but is not one whole
  `[id] = {...},` line, instead of skipping it, and looks the licence up before its
  already-pinned early return so a cache pinned offline does not keep "not reached".
- The builder reports which rule settled the overlapping spawns -- summed over the entities it
  ships, not every entity it placed (a vendor weighed for the zone spread and not chosen used to
  count) -- the distance spread above, any QuestieDB area that sits on more than one zone map
  (none on any flavour; its points would be measured in a frame that may not be theirs), and how
  many places changed zone against the file it replaces AND against git HEAD. Rebuilt every
  flavour QuestieDB covers; places that changed zone against HEAD, the cap included: Vanilla 775
  of 4,725, TBC 916 of 6,510, Wrath 1,213 of 8,559, Cata 1,253 of 9,601, Mists 1,351 of 10,216.
  Vanilla's shipped overlapping spawns: 36,450 settled by QuestieDB, 344 by the entity's
  clear spawns, 96 by clear spawns over a far hint, 14 by a far hint, 33 by the smallest
  rectangle. Checked in the built file, not in a client: Searing Whelp to Dustwallow Marsh,
  Skeletal Warrior (48) and Gavin Gnarltree (225) from Deadwind Pass to Duskwood, Gruff Swiftbite
  (100) from Duskwood to Elwynn Forest, Mine Spider (43) to Elwynn Forest. Vendor choice shifts
  slightly where a vendor's zone changed (vendors are spread over zones), so a few translated
  names enter or leave `PlaceNames.lua`. Retail is unchanged: QuestieDB stops at Mists. Vanilla is
  pinned to 1.15.9.69722, the build its siblings carry.
- `Tests/item_places_check.py`: the hint against both old rules, nearest-point choice, an area
  on two zone maps, the distance cap both ways, the shipped-only report, a split row refused, the
  move report, and the real case on real data -- Searing Whelp places in 1445 only, and without
  the hint it still comes out 1441, so the check can fail. A missing cache fails it rather than
  skipping.

### Changed -- Peer Review `f4bc13b5` follow-ups

- `Tests/itemdb_common_check.py`'s every-`[id]=` assertion now red-checks itself on every run: a
  scratch tree with one row `core_rows` cannot read must come out unequal.
- `Data/Vanilla/_core/EquipStats.lua` (hand-edited for the earlier red-check) is rebuilt by the
  builder at 1.15.9.69722 and re-split, rather than restored by hand.
- New desk tool `itemdb-verify` (repo scope) runs a builder's read-only `--verify`, which
  `itemdb-build` cannot pass.

### Fixed -- gear school resistances on Vanilla, TBC and Wrath (MINOR 43, Dibs' DIBSREQ-IDB)

Dibs' contract (inbox `f93b32b37ec4`): a frost-resistance sort in Dibs' Planner found almost
nothing on Classic Era, because `GetStats` returned no school resistance for most gear. Glacial
Cloak (22658) had stamina and armor but not its 24 frost; Polar Tunic (22661) was missing 40
frost and Arcanist Robes (16798) 10 fire.

- Root cause: the Classic clients' `GetItemStats` never reports `ItemSparse.Resistances_1..6`
  (0 items in the Vanilla and TBC walks, as `build-core-wago.py` already recorded), so the
  walk-built cores carried only resistance that comes from an on-equip aura (16061: column 0,
  walk fire 9). The Wrath core reproduces the TBC walk and so lacked them too.
- `tools/build-equip-stats.py` now reads `Resistances_1..6` in its existing `ItemSparse` pass and
  emits `RESISTANCE<n>_NAME` (1 holy, 2 fire, 3 nature, 4 frost, 5 shadow, 6 arcane) into
  `EquipStats.lua`, which `GetStats` merges. An item whose core ALREADY carries a school (an
  on-equip aura the walk reported) and whose `ItemSparse` column names the same school would need
  the two summed, which `GetStats`' core-wins merge cannot do -- so the builder REFUSES and names
  the item (Peer Review `13334356` F1; the first cut only counted it on stderr). None exists on
  any version today.
- Rebuilt: Vanilla 1,371 items (pinned to 1.15.9.69722, the build its siblings carry, then
  `split-seasonal.py`), TBC 667, Wrath 723. Forever gains none: its `ItemSparse` columns are
  empty and its walk already reports resistances. Mists, Cata and Retail store resistances as
  stat slots, which their cores already read; not rebuilt.
- `itemdb_common.core_rows` is now THE reader of the shipped class files (`CORE_ROW` + the
  `lib:LoadCore(` test), and `core_ids` is a view over it. It replaces four private copies of the
  row regex and file walk in `build-equip-stats.py`, `build-core-wago.py`, `build-core-wowsims.py`
  and `derive-core-maps.py` (whose hand-kept `NON_ITEM` side-table list is gone). Found through
  it: `core_resist_keys` assigned per row, so an id with a base AND a seasonal row kept only the
  last file's schools (Peer Review `13334356` F1b); it now takes the union.
- `Tests/data_baseline.json` re-recorded. The 14 shrinks it accepted were all already in the
  released v1.4.0 tree, HEAD being that release: `Data/Retail/_core/Effects.lua` 1,186 -> 1,182
  (-4), `Data/Vanilla/_seasonal/Quest.lua` 451 -> 450 (-1) and the twelve
  `Data/Vanilla/_seasonal/<locale>/Names.lua` 6,523 -> 6,522 (-1 each; the same item moved to the
  base `Quest.lua` / `Names.lua`, both +1). Also adopted: Retail `Hidden.lua` (new, 13,923) and
  the grown `Hidden.lua` on Cata, Forever, Mists, TBC and Wrath.
- MINOR 42 -> 43 so a consumer can gate on the data (`select(2, LibStub("LibItemDB-1.0")) >= 43`);
  no API change. `CLAUDE.md`'s MINOR rule now says so: it moves for an API change OR when a
  consumer needs to detect new data (Peer Review `13334356` F2).
- `Tests/equip_resist_check.py` red-checked by removing Glacial Cloak's row from the Vanilla file:
  it failed on that item, and passed again once restored.

Older versions (v0.0.1 to v1.4.0) are in [CHANGELOG_ARCHIVE.md](CHANGELOG_ARCHIVE.md).
