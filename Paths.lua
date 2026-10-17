-- Walking routes that ship with Waypath+ (nothing here yet).
-- To add some: walk the routes in game, type /wp trail export, copy the text, and paste it between the
-- [==[ and ]==] below (keep the first line, WPT1). Raise SHARED_TRAIL_V so players' saved copies merge it again.
-- Everyone can also share routes without a new version: /wp trail import.
local _, RG = ...
RG.SHARED_TRAIL_V = 1
RG.SHARED_TRAIL = nil
--[[
RG.SHARED_TRAIL = [==[
WPT1
]==]
]]
