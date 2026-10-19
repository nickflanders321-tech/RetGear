-- Waypath Arena ranked ladder: a hidden Elo rating (chess) shown as Valorant-style tiers, divisions and rank points.
-- Beat a stronger opponent and you gain a lot; beat a weaker one and you gain little; a loss costs more the weaker the
-- opponent was. The computer opponents have fixed ratings (Apprentice 800, Adept 1200, Archmage 1600), so they can carry
-- you to the middle of the ladder; the top tiers need real players.
local ADDON, RG = ...
RG = RG or {}
local R = {}
RG.Rank = R
local floor, max, min = math.floor, math.max, math.min

R.BASE, R.START, R.PLACEMENT = 700, 1000, 5
R.AI = { 800, 1200, 1600 }
R.TIERS = {
  { "Wanderer",    { 0.66, 0.6, 0.52 } },
  { "Scout",       { 0.45, 0.82, 0.45 } },
  { "Pathfinder",  { 0.42, 0.67, 1.0 } },
  { "Trailblazer", { 0.78, 0.52, 1.0 } },
  { "Navigator",   { 1.0, 0.62, 0.25 } },
  { "Cartographer", { 1.0, 0.4, 0.4 } },
  { "Waymaster",   { 1.0, 0.85, 0.35 } },
}
local ROMAN = { "III", "II", "I" }

-- where a rating sits on the ladder
function R.info(rating)
  rating = floor(rating or R.START)
  local rp = max(0, rating - R.BASE)
  local ti = min(7, floor(rp / 300) + 1)
  local t = R.TIERS[ti]
  local r = { tier = ti, name = t[1], color = t[2], rating = rating, rp = rp }
  if ti == 7 then
    r.div, r.rr, r.top = 0, rp - 1800, true
    r.label = t[1]
    r.toNext = nil
  else
    local within = rp - (ti - 1) * 300
    local d = floor(within / 100)
    r.div, r.rr = d + 1, within - d * 100
    r.label = t[1] .. " " .. ROMAN[d + 1]
    r.toNext = 100 - r.rr
  end
  r.key = ti * 10 + (r.div or 0)   -- grows when you are promoted
  return r
end

function R.expected(me, opp) return 1 / (1 + 10 ^ ((opp - me) / 400)) end

-- the change in rating for a result (S = 1 win, 0 loss)
function R.delta(me, opp, won, games)
  games = games or 99
  local K = games < R.PLACEMENT and 48 or (games < 20 and 36 or 28)
  local d = floor(K * ((won and 1 or 0) - R.expected(me, opp)) + 0.5)
  if won then d = max(d, 3) else d = min(d, -3) end
  return d
end

-- apply a finished game to a saved profile table (a). Returns what changed.
function R.apply(a, opp, won)
  local before = a.rating or R.START
  local games = a.rGames or 0
  local d = R.delta(before, opp, won, games)
  local after = max(R.BASE, before + d)
  a.rating, a.rGames, a.rPeak = after, games + 1, max(a.rPeak or 0, after)
  local bi, ai = R.info(before), R.info(after)
  return { delta = after - before, before = bi, after = ai, promoted = ai.key > bi.key, demoted = ai.key < bi.key,
           placement = games < R.PLACEMENT and (games + 1) or nil }
end

function R.rating(a) return a and a.rating or R.START end

-- Seasons are calendar months. When a new month starts, last season's best rank pays out (coins, and a pack from
-- Trailblazer up) and the ladder is pulled halfway back toward the start, so there is always something to climb.
function R.seasonId() return date and date("%Y-%m") or "season" end
function R.seasonName() return date and date("%B") or "this season" end
function R.checkSeason(a)
  if not a then return nil end
  local id = R.seasonId()
  if not a.season then a.season = id; return nil end
  if a.season == id then return nil end
  local prev = a.season
  a.season = id
  if (a.rGames or 0) < R.PLACEMENT then return nil end    -- still in placement: nothing to pay out yet
  local info = R.info(a.rPeak or a.rating or R.START)
  local rating = max(R.BASE, floor(((a.rating or R.START) + R.START) / 2 + 0.5))
  a.rating, a.rPeak = rating, rating
  return { prev = prev, peak = info, coins = info.tier * 12, packs = info.tier >= 4 and 1 or 0, rating = rating }
end
