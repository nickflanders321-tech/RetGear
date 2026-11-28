local _, RG = ...
-- Onyxia's Lair attunement (Journey > Onyxia attunement): the whole Drakefire Amulet chain for your faction, in the order
-- that costs the fewest trips, with where each quest starts and ends and what to do for it.
--
-- The quests, their levels and where they start and end come from the game's own quest data (RG.QDATA), the same data the
-- guide and the planner use, so they match this client. What is written here is the grouping into trips and the advice on
-- what to do on the same visit. That advice comes from these guides, checked against the quest data:
--   Icy Veins' Onyxia attunement guides, Wowpedia's quest chain pages and WoW Forever guides.
-- Each quest is ticked from the game's own record of what you've finished, so the plan picks up wherever you are.

local function done(id) return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) or false end
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false end

-- one stage is a trip: the quests you do while you are in that place, and what to do on the same visit
-- ids are the game's quest ids (checked against RG.QDATA); text is the advice for that quest
local ALLIANCE = {
  { title = "Burning Steppes: Dragonkin Menace", where = "Morgan's Vigil, Burning Steppes", from = 48,
    quests = { { 4182, "Helendis Riverhorn at Morgan's Vigil wants Black Broodlings, Black Dragonspawn, Black Wyrmkin and a Black Drake killed around the Steppes." } },
    tips = { "Level 48 is enough to start. Do the kills while you level in the Steppes, and take the Vigil's other quests alongside." } },
  { title = "Lakeshire, Stormwind, back to the Vigil: The True Masters", where = "Lakeshire (Redridge), Stormwind Keep, Morgan's Vigil", from = 48,
    quests = { { 4183, "Take Helendis's letter to Magistrate Solomon in Lakeshire." },
               { 4184, "Solomon sends you on to Highlord Bolvar Fordragon in Stormwind Keep." },
               { 4185, "Bolvar has you deal with Lady Katrana Prestor in the Keep, then return to him." },
               { 4186, "Bolvar sends you back to Magistrate Solomon in Lakeshire." },
               { 4223, "Solomon sends you to Marshal Maxwell at Morgan's Vigil." },
               { 4224, "Maxwell wants Ragged John killed, in the Steppes." } },
    tips = { "Solomon and Bolvar are each visited twice: fly Morgan's Vigil, Lakeshire, Stormwind, Lakeshire, Vigil in one loop.",
             "Do it on a Stormwind trip you were making anyway." } },
  { title = "Blackrock Depths: Marshal Windsor", where = "Blackrock Depths", from = 48,
    quests = { { 4241, "Marshal Maxwell sends you into Blackrock Depths after Marshal Windsor." },
               { 4242, "Free Windsor, then take Abandoned Hope back to Maxwell at Morgan's Vigil." } },
    tips = { "Take the Depths' other quests on the same run.",
             "A Crumpled Up Note only drops after Abandoned Hope, so you cannot fold the next stage into this run." } },
  { title = "Blackrock Depths again: the Note, the Shred and Jail Break!", where = "Blackrock Depths", from = 50,
    quests = { { 4264, "A Crumpled Up Note drops from enemies in the Depths." },
               { 4282, "Kill General Angerforge and Golem Lord Argelmach and loot Marshal Windsor's lost information from each." },
               { 4322, "Escort Windsor out. Hand it in to Marshal Maxwell at Morgan's Vigil." } },
    tips = { "All three quests fit one run: pick up the Note first, then clear the Shred of Hope bosses, then do Jail Break! on the way out.",
             "Hand in Jail Break! at Maxwell, who also gives the Stormwind quest that follows." } },
  { title = "Stormwind: Rendezvous and The Great Masquerade", where = "Stormwind City", from = 50,
    quests = { { 6402, "Maxwell sends you to meet Squire Rowe in Stormwind." },
               { 6403, "The Great Masquerade: see Windsor into the Keep, then report to Highlord Bolvar Fordragon." } },
    tips = { "It is a group event with a fight: bring a few friends. Bolvar gives The Dragon's Eye as the quest that follows." } },
  { title = "Winterspring: The Dragon's Eye", where = "Haleh, Winterspring", from = 50,
    quests = { { 6501, "Take The Dragon's Eye to Haleh in Winterspring." } },
    tips = { "Haleh gives the Drakefire Amulet quest on the spot: pick it up before you leave." } },
  { title = "Upper Blackrock Spire: General Drakkisath", where = "Upper Blackrock Spire", from = 55,
    quests = { { 6502, "Kill General Drakkisath, loot the Blood of the Black Dragon Champion, and take it to Haleh in Winterspring for the Drakefire Amulet." } },
    tips = { "The Upper Spire needs the Seal of Ascension: its quest takes gemstones that drop in the Lower Spire.",
             "The amulet is what gets you into Onyxia's Lair." } },
}

local HORDE = {
  { title = "Kargath: Blood and Thunder", where = "Kargath, Badlands", from = 55,
    quests = { { 98325, "Warlord Goretooth in Kargath starts the chain." } },
    tips = { "Goretooth also gives Warlord's Command, which is what sends you into the Lower Spire: take both before you go." } },
  { title = "Lower Blackrock Spire: Warlord's Command", where = "Lower Blackrock Spire", from = 55,
    quests = { { 4903, "Kill Overlord Wyrmthalak, Highlord Omokk and War Master Voone, then hand it in to Goretooth in Kargath." } },
    tips = { "The Seal of Ascension quest takes gemstones that drop in the same Lower Spire, from bosses including Highlord Omokk and War Master Voone: do both on this run." } },
  { title = "Orgrimmar: Eitrigg's Wisdom", where = "Orgrimmar", from = 55,
    quests = { { 4941, "Council with Eitrigg, then report to Thrall." } },
    tips = { "Thrall hands you For The Horde! at the same spot, so stay in Orgrimmar to pick it up." } },
  { title = "Upper Blackrock Spire: For The Horde!", where = "Upper Blackrock Spire", from = 55,
    quests = { { 4974, "Kill Warchief Rend Blackhand and bring his head back to Thrall in Orgrimmar." } },
    tips = { "You need the Seal of Ascension to enter. Hand in at Thrall, who also gives What the Wind Carries." } },
  { title = "Orgrimmar to Desolace: Thrall and Rexxar", where = "Orgrimmar, then Rexxar in Desolace", from = 55,
    quests = { { 6566, "Thrall tells his story. What the Wind Carries is a short talk with him." },
               { 6567, "The Champion of the Horde: take it to Rexxar in Desolace." } },
    tips = { "The next quest starts with Rexxar, so continue straight on." } },
  { title = "Desolace to the Plaguelands: Myranda and the eyes", where = "Rexxar in Desolace, then Myranda the Hag in the Western Plaguelands", from = 55,
    quests = { { 6568, "The Testament of Rexxar: take it to Myranda the Hag in the Western Plaguelands." },
               { 6569, "Oculus Illusions: Black Dragonspawn Eyes drop from Rage Talon Dragonspawn, Rage Talon Flamescale, Rookery Guardians and Overlord Wyrmthalak." } },
    tips = { "Wyrmthalak is a Lower Spire boss: if you are in the Spire for any reason, check for eyes there." } },
  { title = "Dustwallow Marsh: Emberstrife", where = "Emberstrife, Dustwallow Marsh", from = 55,
    quests = { { 6570, "Hand in to Emberstrife. He gives you the four Test of Skulls quests." } },
    tips = { "Pick up all of them at once." } },
  { title = "The Test of Skulls: four dragons", where = "Tanaris, Winterspring, Swamp of Sorrows, Wetlands", from = 55,
    quests = { { 6584, "The Skull of Chronalis: Chronalis, in Tanaris." },
               { 6582, "The Skull of Scryer: Scryer, in Winterspring." },
               { 6583, "The Skull of Somnus: Somnus, in the Swamp of Sorrows." },
               { 6585, "The Skull of Axtroz: Axtroz, in the Wetlands. Opens once the other three are handed in." } },
    tips = { "These are elite dragons: bring a group.",
             "Do Chronalis, Scryer and Somnus first and hand all three in on one visit to Emberstrife, then go for Axtroz and hand that in last." } },
  { title = "Desolace: Ascension...", where = "Emberstrife, then Rexxar in Desolace", from = 55,
    quests = { { 6601, "Ascension...: take it to Rexxar in Desolace." } },
    tips = { "Rexxar gives the final quest here." } },
  { title = "Upper Blackrock Spire: General Drakkisath", where = "Upper Blackrock Spire", from = 55,
    quests = { { 6602, "Kill General Drakkisath, loot the Blood of the Black Dragon Champion, and take it to Rexxar in Desolace." } },
    tips = { "The amulet is what gets you into Onyxia's Lair." } },
}


-- shown when the quest data has no entry (it is trimmed to your own race and class)
local NAMES = { [4182]="Dragonkin Menace", [4183]="The True Masters", [4184]="The True Masters", [4185]="The True Masters", [4186]="The True Masters",
  [4223]="The True Masters", [4224]="The True Masters", [4241]="Marshal Windsor", [4242]="Abandoned Hope", [4264]="A Crumpled Up Note",
  [4282]="A Shred of Hope", [4322]="Jail Break!", [6402]="Stormwind Rendezvous", [6403]="The Great Masquerade", [6501]="The Dragon's Eye",
  [6502]="Drakefire Amulet", [98325]="Blood and Thunder", [4903]="Warlord's Command", [4941]="Eitrigg's Wisdom", [4974]="For The Horde!",
  [6566]="What the Wind Carries", [6567]="The Champion of the Horde", [6568]="The Testament of Rexxar", [6569]="Oculus Illusions",
  [6570]="Emberstrife", [6582]="The Test of Skulls, Scryer", [6583]="The Test of Skulls, Somnus", [6584]="The Test of Skulls, Chronalis",
  [6585]="The Test of Skulls, Axtroz", [6601]="Ascension...", [6602]="Blood of the Black Dragon Champion" }

local SOURCES = "Icy Veins, Wowpedia, WoW Forever guides and the game's own quest data"

-- where a quest starts (what = "pickup") or ends ("turnin"): { map, x, y, name } from the quest data
local function point(d, what)
  local p = d and (what == "pickup" and d.s or d.e)
  if p and p[1] and p[2] and p[3] then return { p[1], p[2], p[3], (p[4] and p[4] ~= "" and p[4]) or d.n } end
end

local function stateOf(id)
  if done(id) then return "done" end
  if onQuest(id) then return "have" end
  return "todo"
end

-- the chain for the player's faction: stages of quests with their state, the next quest to do, and how far along you are
function RG.AttunementPlan()
  local alliance = (RG.PLAYER_FACTION or (UnitFactionGroup and UnitFactionGroup("player"))) == "Alliance"
  local src = alliance and ALLIANCE or HORDE
  local plan = { alliance = alliance, name = alliance and "Alliance" or "Horde", stages = {}, total = 0, doneN = 0, sources = SOURCES }
  local finalId = alliance and 6502 or 6602
  local nextStep
  for si, st in ipairs(src) do
    local out = { n = si, title = st.title, where = st.where, tips = st.tips, steps = {}, from = st.from }
    for _, q in ipairs(st.quests) do
      local id = q[1]
      local d = RG.QDATA and RG.QDATA[id]
      local state = stateOf(id)
      local step = { id = id, text = q[2], state = state, name = (d and d.n) or NAMES[id] or ("Quest " .. id), level = d and d.l or nil }
      step.pickup = point(d, "pickup")
      step.turnin = point(d, "turnin")
      step.wp = (state == "have" and (step.turnin or step.pickup)) or step.pickup or step.turnin
      out.steps[#out.steps + 1] = step
      plan.total = plan.total + 1
      if state == "done" then plan.doneN = plan.doneN + 1
      elseif not nextStep then nextStep = step; step.isNext = true end
    end
    plan.stages[#plan.stages + 1] = out
  end
  plan.next = nextStep
  plan.complete = done(finalId)
  return plan
end

function RG.AttunementItemInBags()
  -- the Drakefire Amulet (item 16309): the key itself
  if GetItemCount then local ok, n = pcall(GetItemCount, 16309); if ok and n and n > 0 then return true end end
  return false
end
