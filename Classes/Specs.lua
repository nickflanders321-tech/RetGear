-- Waypath+ specs: every talent spec of every class, for the 2nd Spec tab.
-- Pick one as your second spec and Waypath+ scores gear for it, collects the
-- best pieces you own into a second set (never sold), lists what to hunt for,
-- and swaps the set on when you change spec (dual spec unlocks at level 40 in
-- WoW Forever; learn it at your class trainer in a capital city).
--
-- Builds, stat priorities, tips and Forever changes follow the newest WoW
-- Forever spec guides (mobalytics.gg verified builds, October 2026). The beta
-- is capped at level 30, so the builds are the level 30 beta builds plus the
-- talents the guides say to work toward; the twice-weekly update replaces them
-- with level 60 builds once the guides publish them.
--
-- Fields:
--   key, name, role (shown), kind = "heal" | "tank" | "melee" | "ranged" | "caster"
--   tab      = talent tree (1-3, in the game's order) the spec spends most points in
--   main     = true for the class's leveling spec: it uses the class's own weights
--              and gear guide (Classes/<Class>.lua)
--   weights  = stat values for this spec (same units as the class weights)
--   model    = weapon model (2H, DW, ranged, caster, feral, tank)
--   weapons  = weapon subclasses this spec wants (defaults to the class's)
--   shield   = wants a shield in the off hand
--   stats, build, goal, tips, forever, source
local _, RG = ...
RG.SPECS = {}
local function S(class, list) RG.SPECS[class] = list end

-- Shared stat sets ---------------------------------------------------------
local function healer(extra)
  local w = { HEAL = 1.0, INT = 0.6, MP5 = 2.2, SPI = 0.3, CRIT = 9, STA = 0.1 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end
local function tank(extra)
  local w = { STA = 1.0, ARMOR = 0.05, DEF = 1.5, DODGE = 12, PARRY = 10, BLOCK = 5, BLOCKVAL = 0.3,
    STR = 0.7, AGI = 0.7, AP = 0.3, HIT = 10, CRIT = 4, WEAPON_DPS = 4 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

-- ---------------------------------------------------------------------------
S("WARRIOR", {
  { key = "arms", name = "Arms", role = "Melee DPS", kind = "melee", tab = 1, main = true, icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    stats = "Strength and Agility, then Stamina",
    build = { "Arms 21: Improved Rend 3, Deflection 5, Improved Charge 2, Improved Overpower 2, Deep Wounds 3, Impale 2, Two-Handed Weapon Specialization 2, Spearing Strike 1, Sweeping Strikes 1" },
    goal = "Sweeping Strikes at 30, then deeper Arms (Mortal Strike) toward 60",
    tips = { "Charge between packs for Rage, open with Rend, then Heroic Strike or Cleave by mob count.",
      "Use Spearing Strike before Heroic Strike when it's off cooldown, and Overpower every dodge.",
      "Sweeping Strikes on every pack of two or more, especially in dungeons.",
      "Execute spends all your Rage: only use it when the mob would live long enough to matter." },
    forever = { "Spearing Strike is new in Arms.", "Weaponmaster lets you train weapon types without changing spec." },
    source = "https://mobalytics.gg/wow-forever/classes/arms-warrior-guide" },
  { key = "fury", name = "Fury", role = "Melee DPS", kind = "melee", tab = 2, icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
    weights = { STR = 2.0, AGI = 1.0, AP = 1.0, CRIT = 22, HIT = 20, STA = 0.3, SPI = 0.1, WEAPON_DPS = 12, SLOW_BONUS = 2, RANGED_DPS = 0.5 },
    model = "DW", hitCap = 9,
    stats = "Strength (about 2 Attack Power each), Agility for crit, then Stamina",
    build = { "Fury 21: Cruelty 5, Unbridled Wrath 5, Lingering Rage 5, Enrage 5, Death Wish 1" },
    goal = "Death Wish at 30; Fury dual-wields in dungeons, so collect two fast one-handers",
    tips = { "Keep Battle Shout up; Demoralizing Shout or Thunder Clap on packs.",
      "Open with Charge and Rend, then Heroic Strike on one target or Cleave on several.",
      "Overpower whenever a mob dodges.",
      "Save Death Wish for bosses and big pulls." },
    forever = { "Flurry and Bloodthirst were cut back hard, and the Fury tree was redone (October 2026).", "The guide's beta build levels with a two-hander; a main hand and off hand are listed here for dungeon Fury." },
    source = "https://mobalytics.gg/wow-forever/classes/fury-warrior-guide" },
  { key = "prot", name = "Protection", role = "Tank", kind = "tank", tab = 3, icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    weights = tank({ STR = 0.8, WEAPON_DPS = 4 }), model = "tank", shield = true, hitCap = 9,
    stats = "Stamina and Armor, then Defense, Dodge, Parry and Block, then Strength for threat",
    build = { "Protection 20: Shield Specialization, Improved Revenge, Shield Block from 16, Defiance and Bastion for shield threat" },
    goal = "Defiance and Bastion (shield threat); 1-60 leveling with a shield is viable in Forever",
    tips = { "Charge and Thunder Clap now work in Defensive Stance: open with both on a pack.",
      "Shield Block on cooldown, Revenge every time it lights up, Sunder Armor on the skull.",
      "Tab through the pack with Sunder and Revenge to spread threat.",
      "Keep a one-hander with Stamina or Strength and the best shield you can find." },
    forever = { "More Rage, buffed Revenge and Rend, Charge and Thunder Clap in Defensive Stance.", "Defiance and Bastion improve threat with a shield." },
    source = "https://mobalytics.gg/wow-forever/classes/protection-warrior-guide-kalltorak" },
})

S("PALADIN", {
  { key = "holy", name = "Holy", role = "Healer", kind = "heal", tab = 1, icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    weights = healer({ INT = 0.7, MP5 = 2.2, CRIT = 13, SPI = 0.25, STA = 0.05 }), model = "caster", shield = true, hitCap = 0,
    weapons = { 4, 7 },
    stats = "Healing Power, Intellect, Mana per 5, then Spirit and crit (crit feeds Illumination)",
    build = { "Holy 21: Divine Intellect 5, Healing Light 3, Spiritual Focus 2, Reverence 3, Purifying Power 2, Divine Favor 1, Illumination 4, Holy Shock 1" },
    goal = "Illumination 5/5 and Holy Shock, then Light's Vigil (new group heal) at launch",
    tips = { "Keep a down-ranked Holy Light on your bars and use it most: move up a rank only when it isn't enough.",
      "Flash of Light for quick top-ups, Holy Shock for instant emergencies.",
      "Lay on Hands is your last resort: it costs all your mana.",
      "Tank first, but don't let the rest of the group drop.",
      "At camp, a Fish Bowl (+8% Intellect, Spirit and Stamina) beats the Sharpening Wheel when you heal." },
    forever = { "Light's Vigil is a new talent that gives paladins a group heal (not in the beta).", "Judgement no longer uses up your Seal." },
    source = "https://mobalytics.gg/wow-forever/classes/holy-paladin-guide" },
  { key = "prot", name = "Protection", role = "Tank", kind = "tank", tab = 2, icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
    weights = tank({ INT = 0.4, SP = 0.3, SP_HOLY = 0.3, STR = 0.7, WEAPON_DPS = 3 }), model = "tank", shield = true, hitCap = 9,
    weapons = { 0, 4, 7 },
    stats = "Stamina first, then Strength and Agility, then Intellect for mana; Spirit is least useful",
    build = { "Protection 21: Redoubt 5, Anticipation 5, Precision 3, Shield Specialization 3, Improved Righteous Fury 3, Improved Seal of Fury 1, Swift Judgement 1" },
    goal = "Full Protection or Vengeance Protection at 60 (the guide lists both; details still to come)",
    tips = { "Pull into the pack with Consecration, Seal of Fury or Righteousness up.",
      "Judgement the main target, then Holy Strike; tab around to Judge the others.",
      "Recast Consecration while the pack is healthy; melee the last one or two to save mana.",
      "Swift Judgement lets you Judge again on the same or another target." },
    forever = { "Holy Strike and Seal of Fury are new, and make Protection work from leveling to 60.", "Improved Holy Strike was removed (September 2026)." },
    source = "https://mobalytics.gg/wow-forever/classes/protection-paladin-guide" },
  { key = "ret", name = "Retribution", role = "Melee DPS", kind = "melee", tab = 3, main = true, icon = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    stats = "Strength, then Agility (Intellect over Agility once you have Champion of the Light)",
    build = { "Holy 13: Divine Intellect 5, Improved Seals 3, Reverence 3, Spiritual Focus 2",
      "Retribution 38: Benediction 5, Conviction 5, Vindication 3, Sanctified Judgement 3, Two-Handed Weapon Specialization 3, Vengeance 3, Champion of the Light 3, Twist of Light 1, Sacred Arbiter 1, Seal of Command 1" },
    goal = "Twist of Light Retribution (13/0/38)",
    tips = { "Seal of Righteousness on fast weapons, Seal of Command on slow ones (3.8 sec or slower).",
      "Holy Strike and Judgement on cooldown; Consecration on packs.",
      "Pick the slower of two similar weapons: Holy Strike and Seal of Command scale with weapon damage." },
    forever = { "Holy Strike is new; Consecration is trained, not a talent.", "Pursuit of Justice gives 15% speed all the time." },
    source = "https://mobalytics.gg/wow-forever/classes/retribution-paladin-guide" },
})

S("HUNTER", {
  { key = "bm", name = "Beast Mastery", role = "Ranged DPS", kind = "ranged", tab = 1, main = true, icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    stats = "Agility, then Strength, then Intellect",
    build = { "Beast Mastery 21: Deadly Aspects 5, Focused Fire 2, Unleashed Fury 5, Ferocity 2, Pathfinding 2, Improved Revive Pet 2, Bestial Swiftness 1, Summon Hawk 1, Intimidation 1" },
    goal = "Intimidation at 30, then Bestial Wrath",
    tips = { "Recast Summon Hawk when its 6 sec cooldown is up to keep two hawks out.", "Rapid Fire on hard fights; it pulls a lot of threat." },
    forever = { "Summon Hawk is a new talent." },
    source = "https://mobalytics.gg/wow-forever/classes/beast-mastery-hunter-guide" },
  { key = "mm", name = "Marksmanship", role = "Ranged DPS", kind = "ranged", tab = 2, icon = "Interface\\Icons\\Ability_Marksmanship",
    weights = { AGI = 2.0, RAP = 1.0, AP = 0.2, CRIT = 22, HIT = 20, STA = 0.2, INT = 0.6, SPI = 0.1, WEAPON_DPS = 0.5, RANGED_DPS = 16 },
    model = "ranged", hitCap = 9,
    stats = "Agility, then Intellect (mana, and Careful Aim turns it into damage)",
    build = { "Marksmanship 21: Hawk Eye 3, Lethal Attacks 5, Careful Aim 5, Rapid Killing 2, Mortal Shots 5, Trueshot Aura 1" },
    goal = "Trueshot Aura at 30; the slowest, hardest-hitting bow or gun you can find",
    tips = { "Pet in, Hunter's Mark, open from max range with Aimed Shot.",
      "Keep Serpent Sting up: Rapid Killing's proc boosts the next mob.",
      "Multi-Shot from 18; save Rapid Fire for groups, where a tank holds the threat." },
    forever = { "Lone Wolf lets hunters play without a pet." },
    source = "https://mobalytics.gg/wow-forever/classes/marksmanship-hunter-guide" },
  { key = "sv", name = "Survival", role = "Melee DPS", kind = "melee", tab = 3, icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
    weights = { AGI = 2.0, STR = 1.0, AP = 1.0, CRIT = 20, HIT = 18, STA = 0.3, INT = 0.3, WEAPON_DPS = 14, SLOW_BONUS = 3, RANGED_DPS = 3 },
    model = "2H", hitCap = 9,
    stats = "Agility, then Strength, then Intellect",
    build = { "Survival 21: Improved Tracking 5, Deflection 4, Savage Strikes 2, Surefooted 3, Deterrence 1, Counterattack 1, Predator's Edge 4, Strider Kick 1" },
    goal = "Survival's melee talents come online from level 30: a big two-hander matters most",
    tips = { "Open at range, then pull the mob off your pet and finish in melee with Raptor Strike, Strider Kick and Mongoose Bite.",
      "Deterrence (5 min cooldown) is for emergencies and Counterattack procs.",
      "Frost Trap to slow packs, Explosive Trap for area damage in groups." },
    forever = { "Survival was reworked into a full melee spec." },
    source = "https://mobalytics.gg/wow-forever/classes/survival-hunter-guide" },
})

S("ROGUE", {
  { key = "assassination", name = "Assassination", role = "Melee DPS", kind = "melee", tab = 1, icon = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    weights = { AGI = 2.0, STR = 1.0, AP = 1.0, CRIT = 22, HIT = 20, STA = 0.3, WEAPON_DPS = 12, RANGED_DPS = 0.5 },
    model = "DW", hitCap = 9, weapons = { 15, 2, 3, 16, 18 },
    stats = "Agility, then Strength, then Stamina",
    build = { "Assassination 21: Malice 5, Lethality 5, Ruthlessness 3, Improved Slice and Dice 3, Remorseless Attacks 2, Relentless Strikes 1, Cold Blood 1, Mutilate 1" },
    goal = "Mutilate at 30 (you give up Blade Flurry): daggers in both hands",
    tips = { "Cheap Shot from behind for 2 combo points, keep Slice and Dice up, build with Mutilate.",
      "Sap one of a pair or three, then Evasion or Blind for the rest.",
      "Thistle Tea gives 100 energy back (5 min cooldown)." },
    forever = { "Assassination focuses on poison damage." },
    source = "https://mobalytics.gg/wow-forever/classes/assassination-rogue-guide" },
  { key = "combat", name = "Combat", role = "Melee DPS", kind = "melee", tab = 2, main = true, icon = "Interface\\Icons\\Ability_BackStab",
    stats = "Agility, then Strength, then Stamina",
    build = { "Combat 21: Improved Sinister Strike 2, Improved Eviscerate 3, Precision 3, Deflection 3, Endurance 2, Riposte 1, Improved Sprint 1, Dual Wield Specialization 5, Blade Flurry 1" },
    goal = "Blade Flurry at 30, Adrenaline Rush after",
    tips = { "Chain Cheap Shot into a 5-point Kidney Shot on elites, then Gouge to get energy back." },
    forever = { "Combat keeps its up-front style." },
    source = "https://mobalytics.gg/wow-forever/classes/combat-rogue-guide" },
  { key = "subtlety", name = "Subtlety", role = "Melee DPS", kind = "melee", tab = 3, icon = "Interface\\Icons\\Ability_Stealth",
    weights = { AGI = 2.0, STR = 1.0, AP = 1.0, CRIT = 22, HIT = 18, STA = 0.4, WEAPON_DPS = 12, RANGED_DPS = 0.5 },
    model = "DW", hitCap = 9, weapons = { 15, 2, 3, 16, 18 },
    stats = "Agility, then Strength, then Stamina",
    build = { "Subtlety 21: Camouflage 4, Opportunity 2, Setup 3, Improved Ambush 3, Initiative 3, Ghostly Strike 1, Serrated Blades 3, Premeditation 1, Hemorrhage 1" },
    goal = "Hemorrhage at 30 as your builder, Rupture as your finisher; daggers for Ambush and Backstab",
    tips = { "Open with Ambush or Cheap Shot from behind, then Ghostly Strike for the dodge bonus.",
      "Rupture on mobs that live 10+ seconds, Eviscerate on the ones about to die.",
      "Vanish fails while a damage-over-time effect is on you: use Evasion or Sprint instead.",
      "Strongest in PvP and in groups, where a tank lets you stay behind the mob." },
    forever = { "Subtlety leans into bleeds and Stealth." },
    source = "https://mobalytics.gg/wow-forever/classes/subtlety-rogue-guide" },
})

S("PRIEST", {
  { key = "disc", name = "Discipline", role = "Healer", kind = "heal", tab = 1, icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
    weights = healer({ INT = 0.8, SPI = 0.5, MP5 = 2.0, CRIT = 8, RANGED_DPS = 2 }), model = "caster", hitCap = 0,
    stats = "Intellect, then Spirit, then Stamina; never Strength or Agility",
    build = { "Discipline 16: Wand Specialization 2, Power in Light 5, Holy Precision 3, Meditation 3, Mental Agility 3", "Shadow 5: Spirit Tap 5" },
    goal = "Penance (new) around 30, plus Inner Focus and Improved Inner Fire; the level 60 build isn't final yet",
    tips = { "Power Word: Shield and Renew between pulls; don't shield a Warrior or Druid tank at the start of a pull (it stops their Rage).",
      "Holy Fire, then Smite or wand depending on mana when you solo.",
      "Keep Power Word: Fortitude up on the group." },
    forever = { "Penance is new for Discipline.", "Fear Ward is baseline for every priest." },
    source = "https://mobalytics.gg/wow-forever/classes/discipline-priest-guide" },
  { key = "holy", name = "Holy", role = "Healer", kind = "heal", tab = 2, icon = "Interface\\Icons\\Spell_Holy_Renew",
    weights = healer({ INT = 0.5, SPI = 0.7, MP5 = 2.0, CRIT = 8, RANGED_DPS = 2 }), model = "caster", hitCap = 0,
    stats = "Intellect and Spirit, then Stamina; never Strength or Agility",
    build = { "Discipline 8: Twin Disciplines 5, Improved Power Word: Shield 3", "Holy 13: Improved Renew 3, Holy Specialization 5, Divine Fury 5" },
    goal = "Divine Fury and Improved Power Word: Shield, then Spiritual Guidance deeper in Holy",
    tips = { "Renew on the tank first, Power Word: Shield before big hits.",
      "Lesser Heal for cheap healing, Heal for big hits, Flash Heal sparingly.",
      "Prayer of Healing (level 30) when the whole group takes damage.",
      "Keep Fortitude and Divine Spirit up, and watch your mana when the group pulls fast." },
    forever = { "Fear Ward is baseline for every priest." },
    source = "https://mobalytics.gg/wow-forever/classes/holy-priest-guide" },
  { key = "shadow", name = "Shadow", role = "Ranged DPS", kind = "caster", tab = 3, main = true, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    stats = "Intellect and Spirit, then Stamina",
    build = { "Discipline 2: Wand Specialization 2", "Shadow 19: Spirit Tap 5, Shadow Focus 3, Shadow Weaving 3, Improved Shadow Word: Pain 2, Shadow Reach 2, Improved Mind Flay 2, Mind Flay 1, Vampiric Embrace 1" },
    goal = "Shadowform",
    tips = { "Mind Blast, Shadow Word: Pain, Mind Flay until the mob reaches you, then wand." },
    forever = { "Troll priests get Hex of Weakness and Shadowguard." },
    source = "https://mobalytics.gg/wow-forever/classes/shadow-priest-guide" },
})

S("SHAMAN", {
  { key = "ele", name = "Elemental", role = "Ranged DPS", kind = "caster", tab = 1, icon = "Interface\\Icons\\Spell_Nature_Lightning",
    weights = { SP = 1.0, SP_NATURE = 1.0, SP_FIRE = 0.3, INT = 0.6, STA = 0.4, SPI = 0.1, CRIT = 9, HIT = 9, MP5 = 1.5 },
    model = "caster", shield = true, hitCap = 16, weapons = { 4, 10, 13, 15 },
    stats = "Intellect, then Stamina; Spirit matters less",
    build = { "Elemental 21: Convection 5, Concussion 5, Elemental Alacrity 3, Eye of the Storm 3, Reverberation 2, Call of Thunder 1, Elemental Focus 1, Lightning Overload 1" },
    goal = "Lightning Overload 3/3, then Elemental Mastery; Chain Lightning at 32",
    tips = { "Lightning Bolt is your main damage.",
      "Flame Shock for damage, Frost Shock to kite, Earth Shock to interrupt.",
      "Keep Lightning Shield up; Stoneclaw Totem tanks for you in a pinch." },
    forever = { "Totemic Projection moves your totems; Call of the Ancestors drops all four at once.", "Shamans can't use wands." },
    source = "https://mobalytics.gg/wow-forever/classes/elemental-shaman-guide" },
  { key = "enh", name = "Enhancement", role = "Melee DPS", kind = "melee", tab = 2, main = true, icon = "Interface\\Icons\\Spell_Nature_LightningShield",
    stats = "Strength, Intellect (Mental Dexterity turns it into Attack Power) and Agility, then Stamina and Spirit",
    build = { "Enhancement 21: Thundering Strikes 5, Improved Lightning Shield 3, Mental Dexterity 3, Elemental Weapons 3, Shamanistic Focus 1, Flurry 4, Stormstrike 1, Improved Stormstrike 1" },
    goal = "Stormstrike at 30",
    tips = { "Rockbiter with a two-hander, Flametongue with a one-hander and shield.", "Lightning Bolt to pull, then Stormstrike and a shock." },
    forever = { "Maelstrom Weapon is buffed for Enhancement." },
    source = "https://mobalytics.gg/wow-forever/classes/enhancement-shaman-guide" },
  { key = "resto", name = "Restoration", role = "Healer", kind = "heal", tab = 3, icon = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    weights = healer({ INT = 0.7, MP5 = 2.4, SPI = 0.15, CRIT = 9, STA = 0.2 }), model = "caster", shield = true, hitCap = 0, weapons = { 4, 10, 13, 15 },
    stats = "Intellect and Stamina; Spirit is useful but matters less",
    build = { "Restoration 21: Improved Healing Wave 5, Tidal Focus 5, Mindfulness 3, Ancestral Healing 3, Totemic Focus 2, Water Shield, Tidal Mastery, Nature's Swiftness 1" },
    goal = "Mana Tide Totem and Nature's Swiftness; Chain Heal is your best heal once you can train it",
    tips = { "Healing Wave is your main heal: down-rank it to save mana; keep rank 2 on your bars.",
      "Pre-cast a low-rank Healing Wave rather than spamming Lesser Healing Wave.",
      "Rank 1 Earth Shock is a cheap interrupt.",
      "Healing Stream or Mana Spring by what the group needs; Strength of Earth when most of the group uses Attack Power." },
    forever = { "Riptide is a new shaman heal.", "Totemic Projection and Call of the Ancestors make totems easier to manage." },
    source = "https://mobalytics.gg/wow-forever/classes/restoration-shaman-guide" },
})

S("MAGE", {
  { key = "arcane", name = "Arcane", role = "Ranged DPS", kind = "caster", tab = 1, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    weights = { SP = 1.0, SP_ARCANE = 1.0, INT = 0.8, SPI = 0.4, STA = 0.2, CRIT = 8, HIT = 9, MP5 = 1.5, RANGED_DPS = 3 },
    model = "caster", hitCap = 16,
    stats = "Intellect, then Spirit, then Stamina",
    build = { "Arcane 21: Improved Channeling 5, Arcane Concentration 5, Arcane Meditation 3, Arcane Impact 3, Arcane Focus 2, Arcane Blast 1, Missile Barrage 1, Presence of Mind 1" },
    goal = "Arcane Blast, Missile Barrage and Presence of Mind: the spec doesn't work without them (online from 25)",
    tips = { "Arcane Blast until Missile Barrage procs, then Arcane Missiles: that's the whole rotation.",
      "Presence of Mind to finish a mob that reaches you.",
      "Improved Channeling means you can usually stand and cast instead of Blinking away." },
    forever = { "Arcane Blast and Missile Barrage are new." },
    source = "https://mobalytics.gg/wow-forever/classes/arcane-mage-guide" },
  { key = "fire", name = "Fire", role = "Ranged DPS", kind = "caster", tab = 2, icon = "Interface\\Icons\\Spell_Fire_FireBolt02",
    weights = { SP = 1.0, SP_FIRE = 1.0, INT = 0.5, SPI = 0.2, STA = 0.2, CRIT = 11, HIT = 9, MP5 = 1.2, RANGED_DPS = 3 },
    model = "caster", hitCap = 16,
    stats = "Intellect, then Spirit, then Stamina; crit matters more for Fire",
    build = { "Fire 21: Improved Fireball 5, Ignite 5, Flame Throwing 2, Burning Soul 3, Improved Scorch 3, Pyroblast 1, Heating Up 1, Blast Wave 1" },
    goal = "Hot Streak (instant Pyroblasts); a normal build also takes Elemental Precision early",
    tips = { "Frostbolt to slow, then Fireball; Scorch stacks its debuff to 5.",
      "Pyroblast when Hot Streak procs.",
      "Frost Nova and Blizzard to control packs; Polymorph the casters." },
    forever = { "Hot Streak is new for Fire." },
    source = "https://mobalytics.gg/wow-forever/classes/fire-mage-guide" },
  { key = "frost", name = "Frost", role = "Ranged DPS", kind = "caster", tab = 3, main = true, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    stats = "Intellect, then Spirit, then Stamina",
    build = { "Frost 21: Improved Frostbolt 5, Elemental Precision 2, Ice Shards 5, Frostbite 3, Ice Lance 1, Shatter 3, Ice Block 1, Fingers of Frost 1" },
    goal = "Fingers of Frost, Ice Lance and Shatter; Improved Blizzard for area farming",
    tips = { "Frostbolt, then Ice Lance on frozen targets." },
    forever = { "Ice Lance and Fingers of Frost are new; Chill was weakened." },
    source = "https://mobalytics.gg/wow-forever/classes/frost-mage-guide" },
})

S("WARLOCK", {
  { key = "aff", name = "Affliction", role = "Ranged DPS", kind = "caster", tab = 1, main = true, icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    stats = "Spell Power, Hit, Crit, then Intellect, Spirit and Stamina",
    build = { "Affliction 26: Improved Corruption 5, Suppression 4, Malediction 5, Improved Bane of Agony 2, Pandemic 3, Nightfall 2, Malevolence 5" },
    goal = "Wrack (capstone)",
    tips = { "Bane of Agony, Corruption and Immolate up; don't reapply before they run out." },
    forever = { "Malediction, Pandemic and Nightfall boost your damage over time; DoTs and Drains can crit." },
    source = "https://mobalytics.gg/wow-forever/classes/affliction-warlock-guide" },
  { key = "demo", name = "Demonology", role = "Ranged DPS", kind = "caster", tab = 2, icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    weights = { SP = 1.0, SP_SHADOW = 1.0, SP_FIRE = 0.3, STA = 0.7, INT = 0.5, SPI = 0.6, CRIT = 4, HIT = 8, MP5 = 1.0, RANGED_DPS = 4 },
    model = "caster", hitCap = 16,
    stats = "Spell Power, Hit, Intellect, Crit, then Spirit (it boosts Life Tap) and Stamina",
    build = { "Affliction 8: Improved Corruption 5, Suppression 3", "Demonology 18: Unholy Power 5, Demonic Energies 2, Fel Vitality 3, Improved Sayaad 3, Master Summoner 2, Demonic Brand 3" },
    goal = "Demonic Brand (your Succubus hits harder on the branded target)",
    tips = { "Keep your demon alive: it does a lot of your damage.",
      "DoTs on the main target, Searing Pain every 10 seconds or so to keep Demonic Brand up.",
      "Stop casting once your DoTs will finish the mob; wand to save mana.",
      "Turn off auto-cast Torment so you choose what your Voidwalker taunts." },
    forever = { "Demonic Energies heals your demon; Life Tap gives your demon mana too.", "Demonic Sacrifice can be used while keeping an active pet." },
    source = "https://mobalytics.gg/wow-forever/classes/demonology-warlock-guide" },
  { key = "destro", name = "Destruction", role = "Ranged DPS", kind = "caster", tab = 3, icon = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    weights = { SP = 1.0, SP_SHADOW = 0.8, SP_FIRE = 0.8, STA = 0.4, INT = 0.4, SPI = 0.3, CRIT = 10, HIT = 9, MP5 = 1.0, RANGED_DPS = 4 },
    model = "caster", hitCap = 16,
    stats = "Spell Power, Hit, Crit (Ruin makes crits hit much harder), then Intellect, Spirit and Stamina",
    build = { "Affliction 2: Suppression 2", "Destruction 24: Bane 5, Ruin 5, Cataclysm 3, Agonizing Flames 3, Fire and Brimstone 3, Destructive Reach 2, Shadowburn 1, Conflagrate 1, Bane of Havoc 1" },
    goal = "Ruin, Conflagrate and Bane of Havoc (two-target cleave); the extra points come from Legacy talents",
    tips = { "Send the Succubus in first, Curse of the Elements or Recklessness on bosses.",
      "Immolate, Bane of Agony if the mob will live, Shadow Bolt or wand as filler.",
      "Conflagrate at the end of Immolate; Shadowburn when you have shards. Both are instant and work on the move." },
    forever = { "Incinerate and Bane of Havoc are new; Ruin hits harder." },
    source = "https://mobalytics.gg/wow-forever/classes/destruction-warlock-guide" },
})

S("DRUID", {
  { key = "balance", name = "Balance", role = "Ranged DPS", kind = "caster", tab = 1, icon = "Interface\\Icons\\Spell_Nature_StarFall",
    weights = { SP = 1.0, SP_NATURE = 0.6, SP_ARCANE = 0.6, INT = 0.6, SPI = 0.3, STA = 0.2, CRIT = 9, HIT = 9, MP5 = 1.5 },
    model = "caster", hitCap = 16,
    stats = "Intellect, then Spirit, then Stamina; never Strength or Agility",
    build = { "Balance 21: Improved Wrath 5, Moonglow 3, Nature's Majesty 2, Improved Moonfire 2, Nature's Reach 2, Nature's Splendor 1, Insect Swarm 1, Vengeance 4, Nature's Grace 1" },
    goal = "Nature's Grace at 30; deeper Balance once the level cap rises",
    tips = { "Open with Wrath or Starfire, then Insect Swarm and Moonfire, then Wrath.",
      "Entangling Roots when a mob closes in; plain Wrath spam is cheaper on mana.",
      "In groups, DoT every target and keep Faerie Fire on the boss." },
    forever = { "Faerie Fire and Nature's Grasp are baseline." },
    source = "https://mobalytics.gg/wow-forever/classes/balance-druid-guide" },
  { key = "feral", name = "Feral (Cat)", role = "Melee DPS", kind = "melee", tab = 2, main = true, icon = "Interface\\Icons\\Ability_Druid_CatForm",
    stats = "Strength, then Agility and Stamina, then Intellect",
    build = { "Feral 37: Ferocity 5, Heart of the Wild 5, Feral Swiftness 2, Shredding Attacks 3, Savage Fury 2, Feral Charge 1, Sharpened Claws 2, Shifting Power 1, Predatory Strikes 3, Blood Frenzy 2, Improved Shifting Power 2, Leader of the Pack 1, Natural Instinct 2, Rend and Tear 5, Berserk 1",
      "Restoration 14: Furor 5, Naturalist 5, Natural Shapeshifter 3, Gift of the Earthmother 1" },
    goal = "Berserk",
    tips = { "Rake on anything that lives 6+ seconds; Ferocious Bite at 5 combo points." },
    forever = { "Cat and Bear Form now scale with your weapon's damage." },
    source = "https://mobalytics.gg/wow-forever/classes/feral-druid-guide" },
  { key = "bear", name = "Feral (Bear)", role = "Tank", kind = "tank", tab = 2, icon = "Interface\\Icons\\Ability_Racial_BearForm",
    weights = { STA = 1.2, AGI = 1.0, STR = 0.8, ARMOR = 0.06, DEF = 1.5, DODGE = 12, HIT = 8, CRIT = 4, AP = 0.3, INT = 0.1, WEAPON_DPS = 4 },
    model = "feral", hitCap = 9,
    stats = "Stamina and Armor, then Agility (dodge and armor) and Strength; weapon damage counts in Forever forms",
    build = { "Same Feral tree as Cat: the guide's build is made to flex between damage and tanking" },
    goal = "One Feral tree that tanks and does damage: swap gear, not talents",
    tips = { "Bear Form, Feral Charge in, Demoralizing Roar, then Maul and Swipe.",
      "Faerie Fire (Feral) to pull casters and keep armor down.",
      "Furor gives you Rage the moment you shift." },
    forever = { "Bear Form scales with weapon damage, so a strong two-handed staff, mace or polearm matters.", "Feral Swiftness's dodge works in every form." },
    source = "https://mobalytics.gg/wow-forever/classes/feral-druid-guide" },
  { key = "resto", name = "Restoration", role = "Healer", kind = "heal", tab = 3, icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
    weights = healer({ INT = 0.5, SPI = 0.6, MP5 = 2.0, CRIT = 6 }), model = "caster", hitCap = 0,
    stats = "Intellect, then Spirit (Reflection keeps mana coming back while you cast), then Stamina",
    build = { "Restoration 21: Nature's Focus 5, Naturalist 5, Gift of Nature 5, Reflection 3, Swiftmend 1, Gift of the Earthmother 1, Nature's Swiftness 1" },
    goal = "Swiftmend and Nature's Swiftness at 30; Tranquility for group healing",
    tips = { "Rejuvenation and Regrowth on the tank and let them tick.",
      "Healing Touch when you have time; Nature's Swiftness, Healing Touch and Swiftmend together for a huge heal in about a second.",
      "Down-rank heals to save mana, and stop casting for 5 seconds to let Spirit regen kick in." },
    forever = { "Tranquility arrives at level 30.", "Rebirth needs Stranglethorn Seeds." },
    source = "https://mobalytics.gg/wow-forever/classes/restoration-druid-guide" },
})

-- Index: RG.SPEC_BY[class][key]; each spec knows its class token.
RG.SPEC_BY = {}
for class, list in pairs(RG.SPECS) do
  RG.SPEC_BY[class] = {}
  for _, s in ipairs(list) do s.class = class; RG.SPEC_BY[class][s.key] = s end
end
RG.SPECS_UPDATED = "2026-10-13"
