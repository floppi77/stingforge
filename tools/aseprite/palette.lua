--[[
  palette.lua -- Paletten der Apidya-Welten
  Jede Rampe läuft dunkel -> hell, mit kühlem Schatten und warmem Licht (Hue-Shift).
  Die Welten teilen sich Materialgrundtöne, damit die Bildsprache konsistent bleibt;
  Welt 1-3 organisch/warm, 4-6 rostig-industriell, 7-10 kalt-technisch bis Alien.
]]

local P = dofile("/home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/aseprite/lib/pixel.lua")

local PAL = { R = {}, C = {} }
local R, C = PAL.R, PAL.C

------------------------------------------------------------------------------
-- 1. Wiese / Blumental (Welt 1)
------------------------------------------------------------------------------
R.amber5 = P.ramp(0xd9a51e, 5)                    -- Bienen-Gelb
R.amber3 = P.ramp(0xc99a2a, 3)
R.honey = P.ramp(0xe8b93a, 4)
R.wax = P.ramp(0xc07f38, 4)
R.chitin = P.ramp(0x6f4423, 4)                    -- brauner Panzer
R.chitin_dark = P.ramp(0x3a2418, 4)
R.black_chitin = P.ramp(0x2a1f26, 4)
R.leaf = P.ramp(0x5f9e33, 5)
R.leaf_dark = P.ramp(0x37662a, 4)
R.grass = P.ramp(0x8cc23a, 4)
R.petal_pink = P.ramp(0xe0669c, 5)
R.petal_white = P.ramp(0xf0e9d8, 4)
R.petal_blue = P.ramp(0x6f8fe0, 4)
R.wing_clear = P.ramp(0xbcd9f2, 4)
R.wing_amber = P.ramp(0xe8c98a, 4)
R.soil = P.ramp(0x6b4a2e, 4)
R.eye_red = P.ramp(0x8f1f38, 3)

------------------------------------------------------------------------------
-- 2. Teich / Fluss (Welt 2)
------------------------------------------------------------------------------
R.teal = P.ramp(0x2f8f8a, 5)
R.teal_dark = P.ramp(0x1c4f57, 4)
R.water = P.ramp(0x3a6fa8, 4)
R.lily = P.ramp(0x4e7f3a, 4)
R.fish = P.ramp(0x9fb2bd, 4)                      -- silbriger Fisch
R.fish_green = P.ramp(0x7f9e6a, 4)
R.shell = P.ramp(0xb98a6a, 4)
R.dragon = P.ramp(0x3f8fd0, 5)                    -- Libellen-Blau
R.dragon_wing = P.ramp(0xcfe4f4, 4)

------------------------------------------------------------------------------
-- 3. Bienenstock (Welt 3)
------------------------------------------------------------------------------
R.hive = P.ramp(0xd99a2a, 5)
R.hive_dark = P.ramp(0x8a5a1e, 4)
R.royal = P.ramp(0xf0c24a, 5)
R.grubs_white = P.ramp(0xe8dcc0, 4)               -- Larven/Maden
R.pollen_yellow = P.ramp(0xf2cf3a, 4)

------------------------------------------------------------------------------
-- 4./5. Kanalisation / Industrie
------------------------------------------------------------------------------
R.rust = P.ramp(0x8a4a26, 5)
R.rust_dark = P.ramp(0x4a2a1c, 4)
R.moss = P.ramp(0x4a6b2a, 4)
R.sludge = P.ramp(0x7ea83a, 5)                    -- giftiger Schlamm
R.sludge_dark = P.ramp(0x3f5a1e, 4)
R.iron = P.ramp(0x4a5058, 4)
R.brass = P.ramp(0xb58a3a, 4)

------------------------------------------------------------------------------
-- 6. Maschinenwelt
------------------------------------------------------------------------------
R.steel = P.ramp(0x5c6b7a, 5)
R.steel_dark = P.ramp(0x2e3844, 4)
R.gunmetal = P.ramp(0x39424f, 5)
R.copper = P.ramp(0xb5713a, 4)
R.chrome = P.ramp(0xb8c4d0, 5)
R.glass = P.ramp(0x6fa8c8, 4)
R.mirror = P.ramp(0x9fb0c8, 5)                    -- Spiegelkugel
R.warning = P.ramp(0xe2c024, 4)
R.energy_cyan = P.ramp(0x3fd8f0, 5)
R.energy_magenta = P.ramp(0xef2f8e, 5)
R.energy_orange = P.ramp(0xff8a2a, 5)
R.energy_red = P.ramp(0xe83a3a, 4)
R.piston = P.ramp(0x7a8492, 4)

------------------------------------------------------------------------------
-- 7./8. Labor / Zucht
------------------------------------------------------------------------------
R.ceramic = P.ramp(0xd8dee4, 4)
R.violet = P.ramp(0x8a5ad0, 5)
R.violet_dark = P.ramp(0x4a2e7a, 4)
R.bio = P.ramp(0x6fd06a, 4)
R.bio_dark = P.ramp(0x2f6a3a, 4)

------------------------------------------------------------------------------
-- 9./10. Alien / Kern
------------------------------------------------------------------------------
R.alien = P.ramp(0x7a4ad0, 5)
R.alien_dark = P.ramp(0x3a2266, 4)
R.bone = P.ramp(0xe8e0c8, 4)
R.crystal = P.ramp(0x9fd8f0, 4)
R.void = P.ramp(0x2a2a3a, 4)
R.gold_trim = P.ramp(0xe8b93a, 4)

------------------------------------------------------------------------------
-- Einzelfarben / Hilfs-Rampen
------------------------------------------------------------------------------
R.eye_glow = P.ramp(0xf04a6a, 3)
R.eye_green = P.ramp(0x8fe04a, 3)
R.white_hot = { P.c(0xffffff), P.c(0xfffbe8), P.c(0xfff6c8) }
R.outline = P.c(0x161018)
R.outline_soft = P.c(0x241a24)

-- Leucht-Rampe (Kern): {hot, mid, edge}
function PAL.glow(hue, n)
  local ramps = {
    cyan = { 0xffffff, 0xcff8ff, 0x3fd8f0, 0x1a6a8a },
    magenta = { 0xfff0f8, 0xffa8d8, 0xef2f8e, 0x7a1a4a },
    orange = { 0xfff6d8, 0xffd08a, 0xff8a2a, 0x8a3a10 },
    yellow = { 0xffffff, 0xfff6b0, 0xf2cf2a, 0x8a6a10 },
    red = { 0xffe8e0, 0xff9a8a, 0xe83a3a, 0x7a1a1a },
    green = { 0xffffff, 0xd8ffb0, 0x8fe04a, 0x2f6a2a },
    violet = { 0xfff0ff, 0xd8b0ff, 0x8a5ad0, 0x3a2070 },
  }
  local s = ramps[hue] or ramps.cyan
  return { C4 = P.c(s[1]), C3 = P.c(s[2]), C2 = P.c(s[3]), C1 = P.c(s[4]) }
end

-- Akzentfarben
C.white = P.c(0xffffff)
C.hot_white = P.c(0xfffbe8)
C.spec = P.c(0xfff6d0)
C.red = P.c(0xe83a3a)
C.magenta = P.c(0xef2f8e)
C.cyan = P.c(0x3fd8f0)
C.orange = P.c(0xff8a2a)
C.gold = P.c(0xe8b93a)
C.green = P.c(0x8fe04a)
C.violet = P.c(0xa87ae8)
C.dark = P.c(0x161018)
C.shadow_blue = P.c(0x2a2a4a)

-- Spielergeschosse: gelb-weiß, Gegnergeschosse: magenta/rot (Form zusätzlich anders)
R.shot_core = P.ramp(0xfffbe0, 4)
R.shot_glow = P.ramp(0xf2cf2a, 4)
R.ebullet = P.ramp(0xef2f8e, 4)
R.ebullet_hot = P.ramp(0xff6aa8, 3)

-- Welt-übergreifende Standard-Kontur
PAL.OUTLINE = C.dark

return PAL
