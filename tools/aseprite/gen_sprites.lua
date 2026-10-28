--[[
  gen_sprites.lua -- Reproduzierbarer Sprite-Generator für "Apidya Reimagined"
  Aufruf:  aseprite -b --script tools/aseprite/gen_sprites.lua
  Optional: APIDYA_ONLY="bee,drone" (Komma-Liste) generiert nur diese Sprites.

  Ergebnis pro Asset:
    assets/aseprite/<name>.aseprite   (Quelle, alle Frames, Tag = "play")
    assets/sprites/<name>.png         (horizontaler Frame-Streifen, transparent)
    assets/sprites/manifest.json      (w, h, frames, fps)
]]

local ROOT = "/home/floppi/Dokumente/DSH/Workspaces/Apidya/"
local LIB = ROOT .. "tools/aseprite/lib/"
local P = dofile(LIB .. "pixel.lua")
local S = dofile(LIB .. "shapes.lua")
local PAL = dofile(ROOT .. "tools/aseprite/palette.lua")

local R, C = PAL.R, PAL.C
local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt
local sin, cos, pi, rad = math.sin, math.cos, math.pi, math.rad

--------------------------------------------------------------------------------
-- Infrastruktur
--------------------------------------------------------------------------------
local MANIFEST, ORDER = {}, {}
local ONLY = os.getenv("APIDYA_ONLY")

local function wanted(name)
  if ONLY == nil or ONLY == "" then return true end
  for n in ONLY:gmatch("[^,]+") do
    n = n:gsub("%s", "")
    if n == name then return true end
  end
  return false
end

local function emit(spec)
  if not wanted(spec.name) then return end
  spec.asePath = ROOT .. "assets/aseprite/" .. spec.name .. ".aseprite"
  local t0 = os.clock()
  local spr = P.buildSprite(spec)
  P.exportStrip(spr, spec.w, spec.h, spec.frames, ROOT .. "assets/sprites/" .. spec.name .. ".png")
  spr:close()
  MANIFEST[spec.name] = { w = spec.w, h = spec.h, frames = spec.frames, fps = spec.fps }
  ORDER[#ORDER + 1] = spec.name
  print(string.format("  %-16s %3dx%-3d %d Frames  %.2fs", spec.name, spec.w, spec.h, spec.frames, os.clock() - t0))
end

-- Rotationshelfer
local function rot(px, py, ox, oy, ang)
  local ca, sa = cos(ang), sin(ang)
  local dx, dy = px - ox, py - oy
  return ox + dx * ca - dy * sa, oy + dx * sa + dy * ca
end

--------------------------------------------------------------------------------
-- 1) SPIELER / SUPPORT
--------------------------------------------------------------------------------

-- Biene: 40x32, 6 Frames Flügelschlag
local function drawBee(img, f, spec)
  local N = spec.frames
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local flat = 0.45 + 0.55 * abs(cos(ph + 0.35))   -- Flügelbreite (Extreme = schmal)
  local bob = floor(sin(ph + 0.9) * 0.8 + 0.5)

  local g = P.grid(40, 32)
  local ax, ay = 11.5, 20.0 + bob
  local tx, ty = 21.0, 18.0 + bob
  local hx, hy = 29.5, 15.5 + bob

  -- Hinterflügel
  local wrx, wry = 19.0, 13.0 + bob
  local tipBx, tipBy = rot(15.0, 2.5 + bob, wrx, wry, -0.30 + flap * 0.30)
  local wspecB = { x0 = wrx, y0 = wry, x1 = tipBx, y1 = tipBy,
                   cx = 15.5, cy = 6.0 + bob - flap * 1.2,
                   w = 2.3 * flat, label = "wing_b", points = 18, root = 0.55, tip = 0.25 }
  S.leaf(g, wspecB)

  -- Beine (hinter dem Körper)
  local legs = {
    { { -4.0, 5 }, { -6.5, 8.5 }, { -7.5, 11 } },
    { { 0.0, 5.5 }, { -0.5, 9.5 }, { -2.0, 12 } },
    { { 4.0, 4.5 }, { 5.5, 8.5 }, { 5.0, 11 } },
  }
  S.legSet(g, { tx, ty + 0.5 }, legs, 0.85, "leg")

  -- Stachel
  S.spike(g, 5.0, 20.5 + bob, 0.9, 22.2 + bob, 2.0, "stinger")

  -- Körper
  P.ellipse(g, ax, ay, 7.1, 5.6, "abdomen")
  P.ellipse(g, ax + 5.6, ay - 0.8, 3.6, 4.6, "abdomen")
  P.ellipse(g, tx, ty, 5.1, 4.7, "thorax")
  P.ellipse(g, 25.0, ty - 1.0, 2.4, 3.4, "thorax")
  P.ellipse(g, hx, hy, 4.1, 3.9, "head")
  -- Fühler
  P.chain(g, { { hx + 0.5, hy - 3.3 }, { hx + 5.0, hy - 8.0 }, { hx + 3.4, hy - 10.4 } }, 0.75, "leg")
  P.chain(g, { { hx - 2.0, hy - 3.4 }, { hx + 0.5, hy - 9.0 }, { hx + 2.2, hy - 10.2 } }, 0.75, "leg")

  -- Vorderflügel
  local frx, fry = 23.5, 12.8 + bob
  local tipFx, tipFy = rot(27.5, 1.0 + bob, frx, fry, 0.42 - flap * 0.34)
  local wspecF = { x0 = frx, y0 = fry, x1 = tipFx, y1 = tipFy,
                   cx = 28.5, cy = 7.0 + bob + flap * 1.4,
                   w = 2.9 * flat, label = "wing_f", points = 20, root = 0.55, tip = 0.22 }
  S.leaf(g, wspecF)

  P.render(img, g, {
    regions = {
      abdomen = { ramp = R.amber5, base_light = 0.62, bulge = 1.05, outline = C.dark, prio = 1 },
      thorax = { ramp = R.amber3, base_light = 0.66, bulge = 1.0, outline = C.dark, prio = 2 },
      head = { ramp = R.chitin_dark, base_light = 0.58, bulge = 1.0, outline = C.dark, prio = 3 },
      stinger = { ramp = R.black_chitin, base_light = 0.55, outline = C.dark },
      leg = { ramp = R.chitin_dark, base_light = 0.52, outline = C.dark, dither = false },
      wing_b = { ramp = R.wing_clear, base_light = 0.78, bulge = 0.25, alpha = 120,
                 outline = P.c(0x8fb4d0), dither = false, sep = false },
      wing_f = { ramp = R.wing_clear, base_light = 0.88, bulge = 0.25, alpha = 150,
                 outline = P.c(0xa8cbe4), dither = false, sep = false, prio = 5 },
    },
  })

  -- Bienenbinden auf dem Abdomen
  local off = -3
  P.bands(img, g, "abdomen", P.c(0x241a22), { period = 5, thick = 2, offset = off })
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    local m = ((x + off) % 5 + 5) % 5
    if m == 1 then return P.mix(cur, P.c(0xffe27a), 0.35) end
    if m == 4 then return P.mul(cur, 0.78) end
    return nil
  end)
  -- Flaum: helle Punkte am Thorax-Rand, dunkle Naht zum Abdomen
  P.paintIn(img, g, "thorax", function(x, y, u, v, cur)
    if ((x * 2 + y * 3) % 7 == 0) then return P.mix(cur, P.c(0xf6dc72), 0.40) end
    return nil
  end)
  -- Auge
  P.eye(img, g, hx + 1.4, hy + 0.2, 2.9, 3.0, { label = "head" })
  -- Kopf-Rimlight (oben)
  P.paintIn(img, g, "head", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "head" then return P.mix(cur, P.c(0xd9a15a), 0.45) end
    return nil
  end)
  -- Mundwerkzeug
  img:drawPixel(floor(hx + 3), floor(hy + 2), P.c(0x2a1a12))
  img:drawPixel(floor(hx + 4), floor(hy + 2), P.c(0x8a5a2a))

  -- Flügeladern (parallel zur Spindel) und Lichtkanten
  S.wingDetail(img, g, "wing_f", wspecF, { count = 2 })
  S.wingDetail(img, g, "wing_b", wspecB, { count = 2 })
  -- Glanzlichter
  P.glint(img, floor(tx - 1), floor(ty - 3), P.c(0xfff8d0), 2)
  img:drawPixel(floor(ax - 2), floor(ay - 3), P.c(0xfff0a0))
  -- Antennenspitzen
  img:drawPixel(floor(hx + 3), floor(hy - 10), P.c(0xe0402a))
  img:drawPixel(floor(hx + 2), floor(hy - 10), P.c(0xe0402a))
end

emit({ name = "bee", w = 40, h = 32, frames = 6, fps = 14, draw = drawBee })

local function R_(ramp, bl, extra)
  local t = { ramp = ramp, base_light = bl or 0.62, bulge = 1.0, outline = C.dark }
  if extra then for k, v in pairs(extra) do t[k] = v end end
  return t
end

-- ------------------------------------------------------------------ DRONE 20x20
-- Kleiner Begleitdrohn: rundlicher Helfer mit Flügeln, schwebt neben der Biene
local function drawDrone(img, f)
  local N, W, H = 4, 20, 20
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local flat = 0.45 + 0.55 * abs(cos(ph))
  local bob = floor(sin(ph + 0.5) * 1.1 + 0.5)
  local g = P.grid(W, H)

  local cx, cy = 10.0, 11.0 + bob
  -- Flügel
  local w1 = { x0 = cx, y0 = cy - 3.0, x1 = cx + 7.5 + flap * 1.5, y1 = 1.0 + bob,
               cx = cx + 8, cy = 5.0, w = 2.0 * flat, label = "wing", points = 12, root = 0.5, tip = 0.2 }
  S.leaf(g, w1)
  -- Antenne
  P.chain(g, { { cx - 2.0, cy - 4.5 }, { cx - 4.5, cy - 7.5 } }, 0.5, "ant")
  -- Körper (rund, golden) + Kopfring
  P.ellipse(g, cx, cy + 1.0, 5.2, 4.6, "body")
  P.ellipse(g, cx - 0.5, cy - 3.0, 3.2, 2.6, "head")
  -- kleine Beine
  P.chain(g, { { cx - 3.0, cy + 5.0 }, { cx - 4.5, cy + 7.5 } }, 0.6, "leg")
  P.chain(g, { { cx + 2.5, cy + 5.0 }, { cx + 3.5, cy + 7.5 } }, 0.6, "leg")

  P.render(img, g, {
    regions = {
      body = R_(R.amber5, 0.64, { bulge = 1.2, outline = C.dark }),
      head = R_(R.chitin, 0.62, { bulge = 1.1, outline = C.dark }),
      ant = R_(R.chitin_dark, 0.54, { dither = false, outline = C.dark }),
      leg = R_(R.chitin_dark, 0.52, { dither = false, outline = C.dark }),
      wing = R_(R.wing_amber, 0.86, { bulge = 0.25, alpha = 165, sep = false, dither = false,
        outline = P.c(0xd8c8a0) }),
    },
  })
  P.bands(img, g, "body", P.c(0x241a22), { period = 3, thick = 1, offset = -2 })
  P.eye(img, g, cx - 1.0, cy - 3.0, 2.0, 2.0, { label = "head", core = P.c(0x2a1020),
    mid = P.c(0x6a3ae0), rim = P.c(0xb890ff) })
  img:drawPixel(floor(cx + 2), floor(cy - 4), P.c(0xfff6c0))
  P.glint(img, floor(cx - 2), floor(cy - 1), P.c(0xfffdf0), 1)
end
emit({ name = "drone", w = 20, h = 20, frames = 4, fps = 10, draw = drawDrone })

--------------------------------------------------------------------------------
-- 2) GESCHOSSE
--------------------------------------------------------------------------------
-- Spielergeschosse: hellgelb/weiß, runde bis rhombische Form.
-- Gegnergeschosse: magenta/rot, gezackt, spitz oder kantig (andere Silhouette).
local SHOT = {
  hot = P.c(0xfffdf0), core = P.c(0xfff2a8), glow = P.c(0xf5b81f),
  edge = P.c(0xc47a12), halo = P.c(0xf5d45a),
}
local EB = {
  hot = P.c(0xffe0f0), core = P.c(0xff5aa8), mid = P.c(0xef2f8e),
  dark = P.c(0x8a1150), deep = P.c(0x3a0a28), halo = P.c(0xff7ab8),
}

-- rhombischer Energiekörper mit Kern und Glimmsaum
local function energyShard(img, cx, cy, rx, ry, hot, core, glow, halo, opts)
  opts = opts or {}
  for y = floor(cy - ry - 2), floor(cy + ry + 2) do
    for x = floor(cx - rx - 2), floor(cx + rx + 2) do
      local dx, dy = abs(x + 0.5 - cx) / rx, abs(y + 0.5 - cy) / ry
      local q = dx + dy   -- Raute
      local c
      if q <= 0.42 then c = hot
      elseif q <= 0.72 then c = core
      elseif q <= 1.0 then c = glow
      elseif q <= 1.7 and P.bayer(x, y) < (1.7 - q) / 0.7 then c = glow
      end
      if c then img:drawPixel(x, y, c) end
    end
  end
  if opts.tail then
    for i = 1, opts.tail do
      local a = 0.9 - i * 0.18
      img:drawPixel(floor(cx - rx - i), floor(cy), P.rgba(halo.red, halo.green, halo.blue, floor(255 * a)))
    end
  end
end

local function drawBulletBase(img, f)
  local g = P.grid(12, 8)
  local big = (f == 2) and 1 or 0
  P.poly(g, { { 0.5, 3.5 }, { 4, 0.8 }, { 10.5, 2.6 }, { 10.5, 4.4 }, { 4, 6.2 } }, "s")
  P.render(img, g, { regions = { s = { ramp = R.shot_glow, base_light = 0.72, bulge = 0.8,
    outline = SHOT.edge, dither = false } }, outline = false })
  energyShard(img, 6.0, 3.5, 4.6 + big * 0.7, 2.4 + big * 0.3, SHOT.hot, SHOT.core, SHOT.glow, SHOT.halo)
  img:drawPixel(3, 3, SHOT.hot)
  img:drawPixel(9, 3, SHOT.hot)
end
emit({ name = "bullet_base", w = 12, h = 8, frames = 2, fps = 12, draw = drawBulletBase })

local function drawBulletFan(img, f)
  -- Geschwungene Doppelklinge: klar anders als der gerade Basis-Bolzen
  local g = P.grid(12, 8)
  local d = (f == 2) and 1 or 0
  S.leaf(g, { x0 = 1.0, y0 = 7.0, x1 = 11.2, y1 = 1.2, cx = 3.0, cy = 0.8,
              w = 2.3 + d * 0.3, label = "s", points = 16, root = 0.8, tip = 0.3 })
  S.leaf(g, { x0 = 1.0, y0 = 7.0, x1 = 10.5, y1 = 6.6, cx = 2.0, cy = 4.0,
              w = 1.5 + d * 0.2, label = "s", points = 14, root = 0.7, tip = 0.25 })
  P.render(img, g, { regions = { s = { ramp = R.shot_glow, base_light = 0.66, bulge = 0.6,
    outline = SHOT.edge, dither = false } } })
  -- Kernschneise entlang der oberen Klinge
  for i = 0, 8 do
    local t = i / 8
    local x = 1.5 + t * 9.0
    local y = 6.6 - t * 5.2
    img:drawPixel(floor(x), floor(y), SHOT.hot)
    img:drawPixel(floor(x), floor(y) - 1, SHOT.core)
  end
  img:drawPixel(10, 1, SHOT.hot)
  img:drawPixel(2, 6, SHOT.core)
  if f == 2 then
    img:drawPixel(11, 2, SHOT.hot); img:drawPixel(9, 0, SHOT.core)
  end
end
emit({ name = "bullet_fan", w = 12, h = 8, frames = 2, fps = 12, draw = drawBulletFan })

local function drawBulletLightning(img, f)
  local g = P.grid(16, 8)
  local shift = (f == 2) and 1 or 0
  local path = { { 0.6, 4.0 }, { 3.4, 2.4 - shift }, { 5.8, 5.2 + shift }, { 8.6, 2.0 },
                 { 11.4, 4.8 }, { 15.0, 3.2 } }
  P.chain(g, path, 1.45, "s")
  P.render(img, g, { regions = { s = { ramp = R.shot_core, base_light = 0.74, bulge = 0.4,
    outline = P.c(0xc2d8ec), dither = false } } })
  -- gelblicher Mantel an der Kante, weißer Kern
  P.paintIn(img, g, "s", function(x, y, u, v, cur)
    return P.mix(cur, SHOT.glow, 0.30)
  end)
  for i = 1, #path - 1 do
    P.line(img, floor(path[i][1]), floor(path[i][2]),
           floor(path[i + 1][1]), floor(path[i + 1][2]), SHOT.hot)
  end
  -- kleine Zacken
  img:drawPixel(2, 6, SHOT.core); img:drawPixel(7, 0, SHOT.core)
  img:drawPixel(10, 6, SHOT.core); img:drawPixel(13, 1, SHOT.core)
  if f == 2 then img:drawPixel(4, 1, SHOT.core); img:drawPixel(12, 6, SHOT.core) end
end
emit({ name = "bullet_lightning", w = 16, h = 8, frames = 2, fps = 12, draw = drawBulletLightning })

local function drawBulletPlasma(img, f)
  local g = P.grid(16, 16)
  local r = 4.2 + (f == 2 and 0.8 or 0)
  P.ellipse(g, 8, 8, r, r, "s")
  P.render(img, g, { regions = { s = { ramp = R.shot_glow, base_light = 0.70, bulge = 0.9,
    outline = SHOT.edge, dither = false } } })
  S.orb(img, 8.0, 8.0, 4.6 + (f == 2 and 0.7 or 0), { SHOT.hot, SHOT.core, SHOT.glow, SHOT.edge },
    { hard = false })
  -- rotierende Plasma-Arme
  local a0 = (f == 2) and 0.6 or 0.0
  for k = 0, 3 do
    local a = a0 + k * pi / 2
    local x1, y1 = 8 + cos(a) * 4.2, 8 + sin(a) * 4.2
    local x2, y2 = 8 + cos(a + 0.5) * 6.6, 8 + sin(a + 0.5) * 6.6
    P.line(img, floor(x1), floor(y1), floor(x2), floor(y2), SHOT.glow)
  end
  P.glint(img, 5, 5, SHOT.hot, 2)
end
emit({ name = "bullet_plasma", w = 16, h = 16, frames = 2, fps = 12, draw = drawBulletPlasma })

local function drawBomb(img, f)
  local g = P.grid(20, 20)
  P.ellipse(g, 9.5, 12.5, 7.0, 6.6, "body")
  P.ellipse(g, 9.5, 6.4, 3.0, 2.4, "cap")
  P.rect(g, 8, 3, 3, 3, "cap")
  P.chain(g, { { 10.5, 3.2 }, { 12.6, 1.4 }, { 15.1, 2.2 } }, 0.65, "fuse")
  P.render(img, g, {
    regions = {
      body = { ramp = R.honey, base_light = 0.62, bulge = 1.1, outline = C.dark },
      cap = { ramp = R.brass, base_light = 0.64, bulge = 0.8, outline = C.dark },
      fuse = { ramp = R.rust_dark, base_light = 0.55, outline = C.dark, dither = false },
    },
  })
  -- Bänder
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if y == 11 or y == 14 then return P.mul(cur, 0.72) end
    return nil
  end)
  -- Honig-Glanz
  P.glint(img, 6, 9, C.hot_white, 2)
  img:drawPixel(7, 11, P.mul(C.hot_white, 0.6))
  local sp = (f == 2) and 1 or 0
  S.orb(img, 15.4, 2.0, 1.5 + sp * 0.6, { P.c(0xffffff), P.c(0xffe08a), P.c(0xff9a2a), P.c(0x8a3a10) },
    { hard = true })
  if f == 2 then img:drawPixel(17, 3, P.c(0xffc85a)) end
  -- Bombe-Glyph (Ring um Kapsel)
  img:drawPixel(9, 5, P.c(0x2a1a10)); img:drawPixel(10, 5, P.c(0x2a1a10))
end
emit({ name = "bomb", w = 20, h = 20, frames = 2, fps = 12, draw = drawBomb })

-- --- Gegnergeschosse ---
local function drawEBOrb(img, f)
  local g = P.grid(12, 12)
  local r = 3.4 + (f == 2 and 0.6 or 0)
  P.ellipse(g, 6, 6, r, r, "s")
  -- Stacheln (Silhouette klar verschieden von runden Spielergeschossen)
  for k = 0, 5 do
    local a = k * pi / 3 + (f == 2 and 0.26 or 0)
    S.spike(g, 6 + cos(a) * (r - 0.6), 6 + sin(a) * (r - 0.6),
            6 + cos(a) * (r + 2.2), 6 + sin(a) * (r + 2.2), 1.1, "s")
  end
  P.render(img, g, { regions = { s = { ramp = R.ebullet_hot, base_light = 0.97, bulge = 0.9,
    outline = EB.hot, dither = false } } })
  S.orb(img, 6.0, 6.0, 2.9 + (f == 2 and 0.5 or 0), { P.c(0xffffff), P.c(0xffffff), EB.hot, EB.mid }, { hard = true })
  img:drawPixel(5, 4, P.c(0xffffff))
  img:drawPixel(6, 4, P.c(0xffffff))
end
emit({ name = "ebullet_orb", w = 12, h = 12, frames = 2, fps = 12, draw = drawEBOrb })

local function drawEBNeedle(img, f)
  local g = P.grid(14, 6)
  local d = (f == 2) and 1 or 0
  -- Pfeilspitze nach links, langer Schaft
  P.poly(g, { { 0.4, 3.0 }, { 5.0, 0.6 }, { 13.2, 2.2 }, { 13.2, 3.8 }, { 5.0, 5.4 } }, "s")
  P.render(img, g, { regions = { s = { ramp = R.ebullet_hot, base_light = 0.99, bulge = 0.7,
    outline = EB.hot, dither = false } } })
  -- heiße Spitze und Schaftader
  for x = 1, 5 do img:drawPixel(x, 3, P.c(0xffffff)) end
  for x = 6, 12 do img:drawPixel(x, 3, EB.hot) end
  img:drawPixel(1, 3, P.c(0xffffff))
  if f == 2 then
    img:drawPixel(11, 2, EB.hot); img:drawPixel(11, 4, EB.hot)
    img:drawPixel(13, 3, EB.halo)
  end
end
emit({ name = "ebullet_needle", w = 14, h = 6, frames = 2, fps = 12, draw = drawEBNeedle })

local function drawEBSpore(img, f)
  local g = P.grid(10, 10)
  local r = 2.8 + (f == 2 and 0.5 or 0)
  -- klumpige Sporenkugel mit Warzen
  P.ellipse(g, 5, 5, r, r, "s")
  P.ellipse(g, 4.2, 3.6, 1.6, 1.4, "s")
  P.ellipse(g, 6.4, 6.2, 1.5, 1.4, "s")
  P.ellipse(g, 2.6, 6.0, 1.2, 1.2, "s")
  P.render(img, g, { regions = { s = { ramp = R.ebullet_hot, base_light = 0.99, bulge = 1.2,
    outline = EB.hot, dither = false } } })
  S.orb(img, 5.0, 5.0, 2.6, { P.c(0xffffff), P.c(0xffffff), EB.hot, EB.hot }, { hard = true })
  img:drawPixel(3, 3, P.c(0xffffff))
  if f == 2 then
    img:drawPixel(7, 2, EB.halo); img:drawPixel(2, 7, EB.halo)
  end
end
emit({ name = "ebullet_spore", w = 10, h = 10, frames = 2, fps = 12, draw = drawEBSpore })

local function drawEBLaser(img, f)
  local g = P.grid(24, 8)
  P.rrect(g, 0.5, 1.5, 23.0, 5.0, 2.0, "s")
  P.render(img, g, { regions = { s = { ramp = R.ebullet_hot, base_light = 0.94, bulge = 0.5,
    outline = EB.mid, dither = false } } })
  -- Kernbalken mit Segmenten, durchgehend hell
  for x = 1, 22 do
    local seg = (floor(x / 4) % 2 == 0)
    img:drawPixel(x, 3, seg and P.c(0xffffff) or EB.hot)
    img:drawPixel(x, 4, seg and EB.hot or P.c(0xffffff))
  end
  img:drawPixel(0, 4, EB.mid)
  if f == 2 then
    for x = 2, 21 do img:drawPixel(x, 2, EB.halo) end
    for x = 3, 20 do img:drawPixel(x, 5, EB.mid) end
  end
end
emit({ name = "ebullet_laser", w = 24, h = 8, frames = 2, fps = 12, draw = drawEBLaser })

--------------------------------------------------------------------------------
-- 3) SAMMELOBJEKTE
--------------------------------------------------------------------------------
local function drawBlossom(img, f)
  local g = P.grid(16, 16)
  local n = (f - 1) * pi / 8
  for k = 0, 4 do
    local a = n + k * 2 * pi / 5
    P.ellipse(g, 8 + cos(a) * 3.6, 8 + sin(a) * 3.6, 3.0, 2.6, "petal")
  end
  P.ellipse(g, 8, 8, 2.6, 2.6, "core")
  P.render(img, g, {
    regions = {
      petal = { ramp = R.petal_pink, base_light = 0.66, bulge = 1.0, outline = P.c(0x6a1f42) },
      core = { ramp = R.pollen_yellow, base_light = 0.72, bulge = 1.0, outline = P.c(0x6a4a10) },
    },
  })
  -- Blütenblatt-Adern und Kern
  P.paintIn(img, g, "petal", function(x, y, u, v, cur)
    if (x + y) % 5 == 0 then return P.mix(cur, P.c(0xffd6ea), 0.30) end
    return nil
  end)
  S.orb(img, 8.0, 8.0, 2.2, { P.c(0xffffff), P.c(0xfff2a0), P.c(0xf2cf2a), P.c(0xa87a12) }, { hard = true })
  img:drawPixel(7, 7, P.c(0xffffff))
  -- Glanzpunkte auf zwei Blättern
  P.glint(img, floor(8 + cos(n) * 4.5), floor(8 + sin(n) * 4.5), C.hot_white, 1)
end
emit({ name = "blossom", w = 16, h = 16, frames = 4, fps = 10, draw = drawBlossom })

local function drawNectar(img, f)
  local g = P.grid(10, 10)
  local d = (f == 2) and 1 or 0
  -- Honigtropfen
  P.ellipse(g, 5, 6.4, 3.2 + d * 0.4, 3.0 + d * 0.4, "drop")
  S.spike(g, 5, 1.0, 5, 4.0, 1.8, "drop")
  P.render(img, g, { regions = { drop = { ramp = R.honey, base_light = 0.66, bulge = 1.1,
    outline = P.c(0x6a4210) } } })
  img:drawPixel(3, 5, C.hot_white); img:drawPixel(4, 5, P.c(0xfff6c0))
  img:drawPixel(3, 6, P.c(0xffe08a))
  if f == 2 then img:drawPixel(6, 3, P.c(0xfff6c0)) end
end
emit({ name = "nectar", w = 10, h = 10, frames = 2, fps = 10, draw = drawNectar })

local function drawHeart(img, f)
  local g = P.grid(14, 14)
  local s = (f == 2) and 0.5 or 0
  -- Herz aus zwei Kreisen + Spitze
  P.ellipse(g, 4.6, 5.4, 3.4 + s * 0.4, 3.2 + s * 0.4, "h")
  P.ellipse(g, 9.4, 5.4, 3.4 + s * 0.4, 3.2 + s * 0.4, "h")
  P.poly(g, { { 1.0, 6.0 }, { 13.0, 6.0 }, { 7.0, 12.8 + s } }, "h")
  P.render(img, g, { regions = { h = { ramp = P.ramp(0xe83a5a, 5), base_light = 0.66, bulge = 1.1,
    outline = P.c(0x4a1020) } } })
  img:drawPixel(4, 4, C.hot_white); img:drawPixel(5, 4, P.c(0xffd0d8))
  img:drawPixel(4, 5, P.c(0xffb0c0))
  img:drawPixel(3, 5, P.c(0xff9aae))
  if f == 2 then img:drawPixel(9, 3, P.c(0xffe0e8)) end
end
emit({ name = "heart", w = 14, h = 14, frames = 2, fps = 4, draw = drawHeart })

--------------------------------------------------------------------------------
-- 4) EFFEKTE
--------------------------------------------------------------------------------
local function drawExplode(img, f)
  local cx, cy = 24.0, 24.0
  local t = (f - 1) / 5
  local R1 = 3.0 + t * 21.0
  local hot = P.c(0xfffdf0)
  local c2 = P.c(0xffe08a)
  local c3 = P.c(0xff9a2a)
  local c4 = P.c(0xc4471a)
  local c5 = P.c(0x6a2410)
  -- Kern (verblasst)
  if t < 0.75 then
    S.orb(img, cx, cy, (1 - t * 1.2) * 7.0, { hot, c2, c3, c4 }, { hard = false })
  end
  -- expandierende Feuerwand
  S.ringWave(img, cx, cy, R1, 3.6 - t * 2.2, { hot, c2, c3, c4 }, { squash = 1.0 })
  -- Rauchring außen (später grau)
  if t > 0.35 then
    S.ringWave(img, cx, cy, R1 * 1.15, 2.6, { P.c(0x8a7a6a), P.c(0x6a5a54), P.c(0x4a4048), P.c(0x2a2430) }, {})
  end
  -- Trümmer/Partikel (deterministisch über Winkel)
  for k = 0, 11 do
    local a = k * pi / 6 + t * 0.6
    local d = R1 * (0.75 + 0.2 * ((k * 7) % 5) / 5)
    local px, py = cx + cos(a) * d, cy + sin(a) * d * 0.92
    local col = (k % 3 == 0) and c2 or ((k % 3 == 1) and c3 or c4)
    if t > 0.55 then col = P.mix(col, P.c(0x2a2430), (t - 0.55) / 0.45) end
    img:drawPixel(floor(px), floor(py), col)
    if t < 0.45 then img:drawPixel(floor(px) + 1, floor(py), P.mul(col, 0.8)) end
  end
  -- heller Blitz in den ersten Frames
  if f == 1 then
    for k = 0, 7 do
      local a = k * pi / 4
      P.line(img, floor(cx), floor(cy), floor(cx + cos(a) * 11), floor(cy + sin(a) * 11), c2)
    end
  end
end
emit({ name = "explode", w = 48, h = 48, frames = 6, fps = 18, draw = drawExplode })

local function drawSpark(img, f)
  local t = (f - 1) / 3
  local cx, cy = 8.0, 8.0
  local len = 2.0 + t * 5.5
  local hot = P.c(0xffffff)
  local c2 = P.c(0xfff2a8)
  local c3 = P.c(0xf5b81f)
  for k = 0, 3 do
    local a = k * pi / 2 + pi / 4 * 0.5
    local x2, y2 = cx + cos(a) * len, cy + sin(a) * len
    P.line(img, floor(cx), floor(cy), floor(x2), floor(y2), c2)
    img:drawPixel(floor(x2), floor(y2), hot)
    local xm, ym = cx + cos(a) * len * 0.6, cy + sin(a) * len * 0.6
    img:drawPixel(floor(xm), floor(ym), c3)
  end
  S.orb(img, cx, cy, 2.2 - t * 0.9, { hot, c2, c3, P.c(0xa87a12) }, { hard = true })
  -- diagonale Kurzstrahlen
  if t > 0.3 then
    for k = 0, 3 do
      local a = k * pi / 2 + pi / 4
      local x2, y2 = cx + cos(a) * len * 0.75, cy + sin(a) * len * 0.75
      img:drawPixel(floor(x2), floor(y2), c3)
    end
  end
end
emit({ name = "spark", w = 16, h = 16, frames = 4, fps = 16, draw = drawSpark })

local function drawPollen(img, f)
  local t = (f - 1) / 3
  local cx, cy = 20.0, 20.0
  local gold = { P.c(0xfffdf0), P.c(0xfff2a8), P.c(0xf2cf2a), P.c(0xb8860e) }
  -- Wolke aus Pollenkörnern, expandierend und verblassend
  for k = 0, 13 do
    local a = k * 2 * pi / 14 + 0.3
    local d = (4 + (k % 5) * 1.6) * (0.5 + t * 1.5)
    local px, py = cx + cos(a) * d, cy + sin(a) * d * 0.9 - t * 2
    local r = 1.6 + ((k % 3) * 0.5)
    local fade = 1 - t * 0.55
    local col = gold[(k % 3) + 1]
    col = P.rgba(col.red, col.green, col.blue, floor(255 * fade))
    S.orb(img, px, py, r, { P.c(0xffffff), P.c(0xfff2a8), P.c(0xf2cf2a), P.c(0xb8860e) }, { hard = true })
  end
  -- zentraler Schimmer
  if t < 0.6 then
    S.orb(img, cx, cy, 5.0 * (1 - t), { P.c(0xffffff), P.c(0xfff6c0), P.c(0xf2cf2a), P.c(0xd9a51e) },
      { hard = false })
  end
end
emit({ name = "pollen", w = 40, h = 40, frames = 4, fps = 8, draw = drawPollen })

local function drawRing(img, f)
  local t = (f - 1) / 5
  local cx, cy = 32.0, 32.0
  local r = 6.0 + t * 24.0
  local th = 4.0 * (1 - t) + 1.2
  local cols = { P.c(0xffffff), P.c(0xbfeaff), P.c(0x3fd8f0), P.c(0x1a6a8a) }
  S.ringWave(img, cx, cy, r, th, cols, { squash = 1.0 })
  -- innere zweite Welle (versetzt)
  if t > 0.2 then
    S.ringWave(img, cx, cy, r * 0.72, th * 0.6, cols, { squash = 1.0 })
  end
end
emit({ name = "ring", w = 64, h = 64, frames = 6, fps = 14, draw = drawRing })

--------------------------------------------------------------------------------
-- 5) GEGNER  (alle nach links ausgerichtet, Blickrichtung zum Spieler)
--------------------------------------------------------------------------------

-- Spots/Flecken in ein Label malen (Käfer, Marienkäfer)
local function spots(img, g, label, list, col)
  for _, sp in ipairs(list) do
    for y = floor(sp[2] - sp[3] - 1), floor(sp[2] + sp[3] + 1) do
      for x = floor(sp[1] - sp[3] - 1), floor(sp[1] + sp[3] + 1) do
        local dx, dy = (x + 0.5 - sp[1]) / sp[3], (y + 0.5 - sp[2]) / (sp[4] or sp[3])
        if dx * dx + dy * dy <= 1 and P.getp(g, x, y) == label then
          img:drawPixel(x, y, col)
        end
      end
    end
  end
end

-- ---------------------------------------------------------------- MOTH 40x28
local function drawMoth(img, f)
  local N, W, H = 4, 40, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local flat = 0.6 + 0.4 * abs(cos(ph))
  local bob = floor(sin(ph + 0.7) * 0.7 + 0.5)
  local g = P.grid(W, H)

  local tx, ty = 19.5, 15.0 + bob          -- Thorax
  local ax, ay = 26.5, 17.5 + bob          -- Abdomen (hinten rechts)
  local hx, hy = 13.5, 13.5 + bob          -- Kopf (vorne links)

  -- Hinterflügel (unten, hinter dem Abdomen)
  local wb = { x0 = 21.0, y0 = ty + 2.5, x1 = 36.0, y1 = 22.0 + bob - flap * 1.5,
               cx = 33.0, cy = 20.0, w = 5.4 * flat, label = "wing_b", points = 18,
               root = 0.55, tip = 0.35 }
  S.leaf(g, wb)
  -- Beine
  S.legSet(g, { 17.5, ty + 4.0 }, {
    { { -2, 2 }, { -4, 5 }, { -5.5, 6.5 } },
    { { 1, 2 }, { 1, 5.5 }, { 0, 7 } },
    { { 4, 1.5 }, { 6, 4.5 }, { 6, 6 } },
  }, 0.75, "leg")
  -- Körper
  P.ellipse(g, ax, ay, 4.4, 5.4, "abdomen")
  P.ellipse(g, tx, ty, 4.8, 4.4, "thorax")
  P.ellipse(g, hx, hy, 3.7, 3.5, "head")
  -- Gefiederte Fühler
  P.chain(g, { { hx - 1.5, hy - 2.8 }, { hx - 7.0, hy - 7.0 }, { hx - 11.0, hy - 7.5 } }, 0.65, "leg")
  for k = 0, 3 do
    local bx, by = hx - 3.0 - k * 2.0, hy - 4.0 - k * 1.4
    P.capsule(g, bx, by, bx - 0.5, by - 2.2, 0.45, "leg")
  end
  -- Vorderflügel (groß, oben rechts)
  local wf = { x0 = 20.0, y0 = ty - 3.5, x1 = 35.5, y1 = 1.5 + bob - flap * 2.0,
               cx = 26.0, cy = 0.5 + bob, w = 7.2 * flat, label = "wing_f", points = 22,
               root = 0.5, tip = 0.30 }
  S.leaf(g, wf)

  P.render(img, g, {
    regions = {
      abdomen = R_(P.ramp(0x8a6240, 4), 0.60, { bulge = 1.1 }),
      thorax = R_(P.ramp(0xb07a4c, 4), 0.68, { bulge = 1.0 }),
      head = R_(R.chitin, 0.62),
      leg = R_(R.chitin_dark, 0.50, { dither = false }),
      wing_f = R_(P.ramp(0xf0e6d2, 4), 0.82, { bulge = 0.28, alpha = 225, sep = false, dither = false }),
      wing_b = R_(P.ramp(0xdfd2b8, 4), 0.70, { bulge = 0.28, alpha = 205, sep = false, dither = false }),
    },
  })
  -- Flügel: Adern + dunkler Rand + Augenfleck
  S.wingDetail(img, g, "wing_f", wf, { count = 4, veins = P.rgba(168, 132, 104, 225),
    edge = P.rgba(250, 244, 226, 235) })
  S.wingDetail(img, g, "wing_b", wb, { count = 3, veins = P.rgba(160, 126, 100, 215),
    edge = P.rgba(240, 232, 214, 225) })
  -- gezackter Flügelrand (Mottenstaub)
  P.paintIn(img, g, "wing_f", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "wing_f" and ((x % 2) == 0) then return P.mix(cur, P.c(0xb89a78), 0.55) end
    return nil
  end)
  -- Augenfleck nahe der Flügelspitze
  P.paintIn(img, g, "wing_f", function(x, y)
    local dx, dy = (x - 31.5) / 2.3, (y - 5.0 - bob) / 2.1
    local q = dx * dx + dy * dy
    if q <= 1 then
      if q <= 0.30 then return P.rgba(52, 34, 38, 245) end
      return P.rgba(150, 108, 82, 240)
    end
    return nil
  end)
  -- Flaum
  P.paintIn(img, g, "thorax", function(x, y, u, v, cur)
    if ((x * 2 + y * 3) % 5 == 0) then return P.mix(cur, P.c(0xfff6e2), 0.5) end
    return nil
  end)
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if (y % 3 == 0) then return P.mul(cur, 0.86) end
    return nil
  end)
  -- Auge (groß, dunkel)
  P.eye(img, g, hx + 1.0, hy - 0.2, 2.4, 2.6, { label = "head", core = P.c(0x1a1024) })
  -- Behaarte Brust + Glanz
  P.glint(img, floor(tx - 1), floor(ty - 3), P.c(0xfff6e0), 1)
end
emit({ name = "moth", w = 40, h = 28, frames = 4, fps = 10, draw = drawMoth })


-- -------------------------------------------------------------- BEETLE 40x32
local function drawBeetle(img, f)
  local N, W, H = 3, 40, 32
  local t = (f - 1) / N
  local step = sin(t * 2 * pi)
  local bob = floor(step * 0.6 + 0.5)
  local g = P.grid(W, H)

  local cx, cy = 22.0, 20.0 + bob
  -- Beine (alternierend)
  local swing = step * 1.6
  S.legSet(g, { 15.5, 22.5 + bob }, {
    { { -2, 2.5 }, { -6 - swing, 6.5 }, { -8.5 + swing, 8.5 } },
    { { 3, 3.5 }, { 3 + swing, 7.5 }, { 2 - swing, 9.5 } },
    { { 8, 2.5 }, { 11 - swing, 6.5 }, { 13 + swing, 8.5 } },
  }, 1.0, "leg")
  -- Klauen an den Füßen
  -- Kopf
  P.ellipse(g, 7.5, 18.0 + bob, 4.0, 3.8, "head")
  -- Gabelhorn
  S.claw(g, 6.0, 15.0 + bob, 0.8, 8.0 + bob, 0.5, 10.5 + bob, 1.9, "horn", 12)
  S.spike(g, 1.2, 8.4 + bob, 1.2, 5.6 + bob, 1.1, "horn")
  -- Halsschild (Pronotum) - klar abgesetzt
  P.ellipse(g, 13.5, 19.0 + bob, 5.6, 6.0, "pronotum")
  -- Flügeldecken
  P.ellipse(g, cx + 2.5, cy, 10.6, 8.4, "shell")
  -- Fühler
  P.chain(g, { { 5.0, 15.5 + bob }, { 2.0, 12.0 + bob }, { 0.5, 13.0 + bob } }, 0.65, "leg")

  P.render(img, g, {
    regions = {
      shell = R_(P.ramp(0x7a4a26, 5), 0.60, { bulge = 1.2 }),
      pronotum = R_(P.ramp(0x94603a, 4), 0.66, { bulge = 1.05 }),
      head = R_(R.black_chitin, 0.58),
      horn = R_(R.black_chitin, 0.56),
      leg = R_(R.chitin_dark, 0.50, { dither = false }),
    },
  })
  -- Panzerkante (dunkler Saum am unteren Rand)
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    if v > 0.86 then return P.mul(cur, 0.62) end
    return nil
  end)
  -- Flügeldecken-Naht + Längsrillen
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    if x >= 25 and x <= 26 and v > 0.22 then return P.mul(cur, 0.5) end
    return nil
  end)
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    if x > 22 and (x % 3 == 0) then return P.mul(cur, 0.88) end
    return nil
  end)
  -- Glanzband über die Wölbung
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    local dy = abs(y - (13.0 + bob))
    if x > 17 and x < 32 and dy <= 1 and (x % 5 ~= 0) then
      return P.mix(cur, P.c(0xffe8c0), 0.50)
    end
    return nil
  end)
  -- Pronotum-Kante
  P.paintIn(img, g, "pronotum", function(x, y, u, v, cur)
    if v < 0.18 then return P.mix(cur, P.c(0xffdca8), 0.35) end
    if v > 0.88 then return P.mul(cur, 0.7) end
    return nil
  end)
  P.eye(img, g, 8.0, 17.5 + bob, 2.2, 2.2, { label = "head", mid = P.c(0x6a4a22), rim = P.c(0x9a7a3a) })
  P.glint(img, floor(cx - 2), floor(cy - 4), P.c(0xfff2d8), 2)
  img:drawPixel(1, floor(6 + bob), P.c(0x8a6a3a))
end
emit({ name = "beetle", w = 40, h = 32, frames = 3, fps = 9, draw = drawBeetle })


-- ---------------------------------------------------------------- WASP 36x24
local function drawWasp(img, f)
  local N, W, H = 3, 36, 24
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local flat = 0.5 + 0.5 * abs(cos(ph + 0.4))
  local bob = floor(sin(ph + 0.5) * 0.6 + 0.5)
  local g = P.grid(W, H)

  local bx, by = 13.0, 12.0 + bob
  -- Flügel (zwei schmale, nach oben)
  local w1 = { x0 = bx, y0 = by - 3, x1 = 18.0 + flap * 2, y1 = 1.0 + bob,
               cx = 18.5, cy = 6.0, w = 2.2 * flat, label = "wing_f", points = 16, root = 0.6, tip = 0.2 }
  S.leaf(g, w1)
  local w2 = { x0 = bx - 1, y0 = by - 3, x1 = 8.0 + flap * 1.5, y1 = 1.5 + bob,
               cx = 8.0, cy = 5.5, w = 1.9 * flat, label = "wing_b", points = 14, root = 0.6, tip = 0.2 }
  S.leaf(g, w2)
  -- Beine
  S.legSet(g, { bx - 1, by + 3.5 }, {
    { { -2, 2 }, { -4, 5 }, { -5.5, 7 } },
    { { 1, 3 }, { 1, 6 }, { 0, 8 } },
    { { 4, 2 }, { 6, 5 }, { 5.5, 7.5 } },
  }, 0.75, "leg")
  -- Stachel am Hinterleib
  S.spike(g, 28.0, by + 1.5, 34.5, by + 1.5, 1.6, "sting")
  -- Körper: Abdomen (nach hinten spitz), Taille, Thorax, Kopf
  P.ellipse(g, 23.0, by + 1.0, 6.6, 4.2, "abdomen")
  P.ellipse(g, 27.5, by + 1.0, 3.4, 3.0, "abdomen")
  P.capsule(g, 16.5, by + 1.0, 13.0, by + 0.5, 1.5, "waist")
  P.ellipse(g, bx - 1.0, by, 4.4, 4.0, "thorax")
  P.ellipse(g, 5.0, by - 0.5, 3.4, 3.2, "head")
  P.chain(g, { { 3.0, by - 3.2 }, { 0.5, by - 7.0 } }, 0.65, "leg")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.amber5, 0.62, { bulge = 1.05 }),
      waist = R_(R.black_chitin, 0.56, { dither = false }),
      thorax = R_(R.black_chitin, 0.60),
      head = R_(R.black_chitin, 0.60),
      sting = R_(R.black_chitin, 0.55, { dither = false }),
      leg = R_(R.chitin_dark, 0.50, { dither = false }),
      wing_f = R_(R.wing_clear, 0.86, { bulge = 0.25, alpha = 150, sep = false, dither = false }),
      wing_b = R_(R.wing_clear, 0.74, { bulge = 0.25, alpha = 125, sep = false, dither = false }),
    },
  })
  -- Warnbinden auf dem Abdomen
  P.bands(img, g, "abdomen", P.c(0x241a22), { period = 5, thick = 2, offset = -4 })
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    local m = ((x - 4) % 5 + 5) % 5
    if m == 4 then return P.mix(cur, P.c(0xffe27a), 0.35) end
    return nil
  end)
  -- Facettenauge, Warnstreifen am Kopf
  P.eye(img, g, 5.5, by - 0.5, 2.2, 2.4, { label = "head", core = P.c(0x2a1a30) })
  P.paintIn(img, g, "head", function(x, y, u, v, cur)
    if y == floor(by - 2.5) then return P.mix(cur, P.c(0xe8b93a), 0.5) end
    return nil
  end)
  S.wingDetail(img, g, "wing_f", w1, { count = 2, veins = P.rgba(120, 150, 180, 200) })
  S.wingDetail(img, g, "wing_b", w2, { count = 2, veins = P.rgba(120, 150, 180, 190) })
  P.glint(img, floor(23), floor(by - 2), C.hot_white, 2)
  img:drawPixel(34, floor(by + 1.5), P.c(0xfff0c0))
end
emit({ name = "wasp", w = 36, h = 24, frames = 3, fps = 12, draw = drawWasp })

-- --------------------------------------------------------------- APHID 24x20
local function drawAphid(img, f)
  local N, W, H = 3, 24, 20
  local t = (f - 1) / N
  local crawl = sin(t * 2 * pi)
  local bob = floor(crawl * 0.5 + 0.5)
  local g = P.grid(W, H)

  -- Beine
  S.legSet(g, { 11.0, 13.0 + bob }, {
    { { -2, 2 }, { -4 - crawl, 5 }, { -5.5, 6.5 } },
    { { 1, 3 }, { 1 + crawl, 6 }, { 0, 7.5 } },
    { { 4, 2 }, { 6 - crawl, 5 }, { 7.5, 6.5 } },
  }, 0.7, "leg")
  -- Körper
  P.ellipse(g, 12.5, 11.0 + bob, 6.2, 5.4, "body")
  P.ellipse(g, 7.0, 9.5 + bob, 3.2, 3.0, "head")
  -- Rückenröhren (Cornicles)
  P.chain(g, { { 17.0, 7.5 + bob }, { 19.5, 4.5 + bob } }, 0.8, "cornicle")
  P.chain(g, { { 15.0, 7.0 + bob }, { 16.5, 3.5 + bob } }, 0.8, "cornicle")
  -- Fühler
  P.chain(g, { { 5.0, 7.5 + bob }, { 2.5, 4.0 + bob }, { 1.0, 4.5 + bob } }, 0.6, "leg")

  P.render(img, g, {
    regions = {
      body = R_(R.leaf, 0.64, { bulge = 1.15 }),
      head = R_(R.grass, 0.68),
      cornicle = R_(R.leaf_dark, 0.56, { dither = false }),
      leg = R_(R.leaf_dark, 0.52, { dither = false }),
    },
  })
  -- Segmentierung + helle Rückenlinie
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if (x % 3 == 0) and x > 9 then return P.mul(cur, 0.85) end
    return nil
  end)
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if v < 0.22 and x < 17 then return P.mix(cur, P.c(0xe8f8a0), 0.40) end
    return nil
  end)
  P.eye(img, g, 6.5, 9.0 + bob, 1.7, 1.8, { label = "head" })
  P.glint(img, 11, 8 + bob, C.hot_white, 1)
end
emit({ name = "aphid", w = 24, h = 20, frames = 3, fps = 10, draw = drawAphid })

-- ----------------------------------------------------------------- POD 32x32
local function drawPod(img, f)
  local N, W, H = 4, 32, 32
  local open = ({ 0.15, 0.55, 0.95, 0.5 })[f]   -- Öffnungsgrad je Frame
  local g = P.grid(W, H)
  local cx, cy = 16.0, 18.0

  -- Ranke/Stiel unten
  P.chain(g, { { cx, cy + 9 }, { cx - 2, cy + 13 }, { cx + 3, cy + 15 } }, 1.2, "stem")
  -- Samenhülle (Kapsel) mit Klappen
  P.ellipse(g, cx, cy, 8.4, 9.0, "husk")
  -- Öffnung oben: zwei Klappen klappen nach außen
  local spread = 2.0 + open * 5.0
  P.poly(g, { { cx - 3.0, cy - 7.0 }, { cx - spread - 3.0, cy - 12.0 + open * 2 }, { cx - 0.5, cy - 9.5 } }, "lid")
  P.poly(g, { { cx + 3.0, cy - 7.0 }, { cx + spread + 3.0, cy - 12.0 + open * 2 }, { cx + 0.5, cy - 9.5 } }, "lid")
  -- innere Glut
  if open > 0.2 then
    P.ellipse(g, cx, cy - 5.5, 4.2 * open, 3.0 * open + 0.6, "glow")
  end

  P.render(img, g, {
    regions = {
      husk = R_(R.leaf_dark, 0.60, { bulge = 1.1 }),
      lid = R_(R.leaf, 0.66, { bulge = 0.9 }),
      glow = R_(R.petal_pink, 0.80, { bulge = 0.6, alpha = 235, dither = false }),
      stem = R_(R.leaf_dark, 0.52, { dither = false }),
    },
  })
  -- Kapselnähte + Noppen
  P.paintIn(img, g, "husk", function(x, y, u, v, cur)
    if (x + y) % 7 == 0 then return P.mul(cur, 0.82) end
    if (x * 3 + y * 5) % 11 == 0 and y > cy then return P.mix(cur, P.c(0xb8d86a), 0.35) end
    return nil
  end)
  -- innere Glut aufhellen
  if open > 0.2 then
    P.paintIn(img, g, "glow", function(x, y, u, v, cur)
      local d = sqrt((x - cx) ^ 2 + ((y - cy + 5.5) * 1.4) ^ 2)
      if d < 1.6 then return P.c(0xfff0f8) end
      if d < 2.8 then return P.c(0xff9ac8) end
      return P.c(0xd4a0e0)
    end)
  end
  P.glint(img, floor(cx - 5), floor(cy - 2), P.c(0xd8f0a0), 1)
end
emit({ name = "pod", w = 32, h = 32, frames = 4, fps = 8, draw = drawPod })

-- ------------------------------------------------------------- LADYBUG 40x32
local function drawLadybug(img, f)
  local N, W, H = 3, 40, 32
  local t = (f - 1) / N
  local crawl = sin(t * 2 * pi)
  local bob = floor(crawl * 0.5 + 0.5)
  local g = P.grid(W, H)

  S.legSet(g, { 20.0, 23.0 + bob }, {
    { { -6, 2 }, { -9 - crawl, 5 }, { -11, 7 } },
    { { 0, 3 }, { 0 + crawl, 6 }, { -1, 8 } },
    { { 6, 2 }, { 9 - crawl, 5 }, { 11, 7 } },
  }, 0.95, "leg")
  -- Kopf
  P.ellipse(g, 8.0, 18.5 + bob, 4.4, 4.0, "head")
  P.chain(g, { { 6.0, 15.5 + bob }, { 3.0, 11.5 + bob }, { 1.5, 12.5 + bob } }, 0.7, "leg")
  -- Halsschild
  P.ellipse(g, 13.5, 19.5 + bob, 4.4, 4.6, "head")
  -- Halbkugel-Panzer
  P.ellipse(g, 24.0, 19.0 + bob, 12.0, 9.0, "shell")
  -- Panzer minimal anheben in Frame 2
  if f == 3 then P.ellipse(g, 24.0, 16.5 + bob, 10.0, 5.6, "shell") end

  P.render(img, g, {
    regions = {
      shell = R_(P.ramp(0xd93a2a, 5), 0.62, { bulge = 1.2 }),
      head = R_(R.black_chitin, 0.58),
      leg = R_(R.black_chitin, 0.50, { dither = false }),
    },
  })
  -- Flügeldecken-Naht
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    if x == 24 or x == 25 then return P.mul(cur, 0.5) end
    return nil
  end)
  -- Flecken
  spots(img, g, "shell", {
    { 19, 14 + bob, 1.9 }, { 29, 14 + bob, 1.9 }, { 17, 20 + bob, 1.7 },
    { 31, 20 + bob, 1.7 }, { 24, 17 + bob, 1.4 }, { 24, 24 + bob, 1.5 },
  }, P.c(0x1a1018))
  -- Glanz auf dem Panzer
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    if v < 0.28 and x > 16 and x < 30 and (x + y) % 2 == 0 then
      return P.mix(cur, P.c(0xffd0b8), 0.45)
    end
    return nil
  end)
  P.glint(img, 20, 13 + bob, C.hot_white, 2)
  -- Kopf: weiße Wangenflecken + Auge
  spots(img, g, "head", { { 7, 17 + bob, 1.4 }, { 9.5, 20 + bob, 1.2 } }, P.c(0xf0e8d8))
  P.eye(img, g, 8.0, 18.0 + bob, 2.1, 2.2, { label = "head", core = P.c(0x2a1a24) })
end
emit({ name = "ladybug", w = 40, h = 32, frames = 3, fps = 10, draw = drawLadybug })

-- --------------------------------------------------------------- BORER 40x32
local function drawBorer(img, f)
  local N, W, H = 4, 40, 32
  local t = (f - 1) / N
  local spin = t * 6.0                     -- Bohrer dreht
  local bob = floor(sin(t * 2 * pi) * 0.6 + 0.5)
  local g = P.grid(W, H)
  local by = 17.0 + bob

  -- Körper (segmentiert) rechts
  for i = 0, 3 do
    local x = 22.0 + i * 4.4
    local r = 5.6 - i * 0.75
    P.ellipse(g, x, by + (i % 2) * 0.4, 3.4, r, "body")
  end
  -- Panzerringe
  for i = 0, 3 do P.capsule(g, 18.0 + i * 4.4, by - 4.4 + i * 0.55, 18.0 + i * 4.4, by + 4.4 - i * 0.55, 1.0, "ring") end
  -- kurze Beine
  P.chain(g, { { 24, by + 4 }, { 22.5, by + 8 }, { 24, by + 9.5 } }, 0.9, "leg")
  P.chain(g, { { 30, by + 4 }, { 31, by + 8 }, { 29.5, by + 9.5 } }, 0.9, "leg")
  -- Bohrkopf (gerundete Panzerplatte)
  P.rrect(g, 7.0, by - 5.0, 12.0, 10.0, 3.0, "head")
  -- Bohrerkegel
  P.poly(g, { { 0.4, by }, { 11.0, by - 4.4 }, { 11.0, by + 4.4 } }, "drill")
  P.rect(g, 11.0, by - 1.2, 2.0, 2.4, "drill")
  P.render(img, g, {
    regions = {
      body = R_(R.rust, 0.60, { bulge = 1.1 }),
      ring = R_(R.rust_dark, 0.55, { bulge = 0.8 }),
      head = R_(R.iron, 0.54, { bulge = 0.9 }),
      drill = R_(R.steel, 0.60, { bulge = 0.55 }),
      leg = R_(R.iron, 0.52, { dither = false }),
    },
  })
  -- Segmentfugen abdunkeln, Rostflecken
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if (x % 4 == 0) and x > 19 then return P.mul(cur, 0.72) end
    if (x * 3 + y * 5) % 13 == 0 then return P.mul(cur, 0.8) end
    return nil
  end)
  -- Bohrergewinde (rotiert), Kegel bleibt lesbar
  local spinPhase = floor(spin * 1.6) % 7
  P.paintIn(img, g, "drill", function(x, y, u, v, cur)
    local q = (x * 2 + y * 3 + spinPhase) % 7
    if q < 2 then return P.mul(cur, 0.55) end
    if q == 6 then return P.mix(cur, P.c(0xffffff), 0.35) end
    return nil
  end)
  -- Kopf: Bolzen und Sensor-Schlitz
  S.rivets(img, g, "head", 8, 17, floor(by - 3.5), P.c(0xc8d4e0))
  P.paintIn(img, g, "head", function(x, y, u, v, cur)
    if y >= floor(by - 1) and y <= floor(by + 1) and x > 9 and x < 16 then
      return (y == floor(by)) and P.c(0xffe07a) or P.c(0x8a4a10)
    end
    return nil
  end)
  P.glint(img, 27, floor(by - 3), C.hot_white, 1)
  -- Bohrer-Spitze glüht
  img:drawPixel(0, floor(by), P.c(0xfff0c0))
end
emit({ name = "borer", w = 40, h = 32, frames = 4, fps = 10, draw = drawBorer })

-- ---------------------------------------------------------------- GRUB 48x32
local function drawGrub(img, f)
  local N, W, H = 4, 48, 32
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local g = P.grid(W, H)

  -- C-förmiger, segmentierter Körper: Wellenbewegung pro Frame
  local segs = 7
  for i = 0, segs do
    local x = 12.0 + i * 4.6
    local wave = sin(ph + i * 0.55) * 1.1
    local y = 20.0 + wave
    local r = 6.2 - abs(i - 3) * 0.55
    P.ellipse(g, x, y, 2.9, r, "body")
  end
  -- Kopfkapsel + Mandibeln (links)
  local hy = 20.0 + sin(ph) * 0.8
  P.ellipse(g, 10.0, hy, 4.4, 4.6, "head")
  P.poly(g, { { 7.0, hy - 2.0 }, { 0.8, hy - 3.6 }, { 6.5, hy - 0.4 } }, "mand")
  P.poly(g, { { 7.0, hy + 2.0 }, { 0.8, hy + 3.6 }, { 6.5, hy + 0.4 } }, "mand")
  -- kleine Bauchfüße
  for i = 1, 5 do
    local x = 13.0 + i * 4.4
    P.capsule(g, x, 24.5, x - 0.8, 28.0, 0.85, "leg")
  end

  P.render(img, g, {
    regions = {
      body = R_(R.grubs_white, 0.66, { bulge = 1.2 }),
      head = R_(R.chitin, 0.60, { bulge = 1.0 }),
      mand = R_(R.chitin_dark, 0.56),
      leg = R_(R.chitin_dark, 0.52, { dither = false }),
    },
  })
  -- Segmentfurchen und helle Rückenlinie
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if (x % 5 == 0) then return P.mul(cur, 0.80) end
    if v < 0.20 and x > 11 then return P.mix(cur, P.c(0xfffdf0), 0.45) end
    return nil
  end)
  -- Kopf: Augenpunkte + Mund
  img:drawPixel(8, floor(hy - 1.5), P.c(0x1a1018))
  img:drawPixel(8, floor(hy + 1.5), P.c(0x1a1018))
  img:drawPixel(7, floor(hy - 1.5), P.c(0x6a4a2a))
  P.glint(img, 6, floor(hy - 2.5), C.hot_white, 1)
  img:drawPixel(1, floor(hy - 3.2), P.c(0xfff2c0))
  img:drawPixel(1, floor(hy + 3.2), P.c(0xfff2c0))
end
emit({ name = "grub", w = 48, h = 32, frames = 4, fps = 8, draw = drawGrub })

-- ----------------------------------------------------------- DRAGONFLY 44x28
local function drawDragonfly(img, f)
  local N, W, H = 3, 44, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local bob = floor(sin(ph + 0.4) * 0.7 + 0.5)
  local g = P.grid(W, H)

  local hx, hy = 8.0, 13.0 + bob
  -- Vier Flügel (2 Paar), schmal und lang
  local wings = {
    { x0 = 11.0, y0 = hy - 2.5, x1 = 22.0 + flap * 2.5, y1 = 0.6 + bob,
      cx = 17.0, cy = 2.5, w = 2.0, label = "wing_b" },
    { x0 = 11.0, y0 = hy + 2.5, x1 = 22.0 + flap * 2.5, y1 = 23.5 + bob,
      cx = 17.0, cy = 21.5, w = 1.8, label = "wing_b" },
    { x0 = 15.0, y0 = hy - 2.0, x1 = 31.0 - flap * 2.5, y1 = 1.0 + bob,
      cx = 25.0, cy = 3.0, w = 2.1, label = "wing_f" },
    { x0 = 15.0, y0 = hy + 2.0, x1 = 31.0 - flap * 2.5, y1 = 23.0 + bob,
      cx = 25.0, cy = 21.0, w = 1.9, label = "wing_f" },
  }
  for _, w in ipairs(wings) do
    w.points = 16; w.root = 0.5; w.tip = 0.25
    S.leaf(g, w)
  end
  -- Beine (dünn, gespreizt)
  P.chain(g, { { 14, hy + 3 }, { 11, hy + 7 }, { 8.5, hy + 8.5 } }, 0.6, "leg")
  P.chain(g, { { 17, hy + 3.5 }, { 16, hy + 8 }, { 14, hy + 9.5 } }, 0.6, "leg")
  -- Körper: Thorax + langer Hinterleib
  P.ellipse(g, 15.0, hy, 5.0, 4.2, "thorax")
  P.ellipse(g, hx, hy - 0.5, 4.0, 3.8, "head")
  local ax = 21.0
  for i = 0, 5 do
    local r = 3.0 - i * 0.22
    P.ellipse(g, ax + i * 3.3, hy + 0.2 - i * 0.12, 2.3, r, "abdomen")
  end
  -- Schwanzspitze mit Finnen
  P.poly(g, { { 40.5, hy - 1.4 }, { 43.6, hy - 0.2 }, { 40.5, hy + 1.4 } }, "abdomen")
  P.poly(g, { { 39.6, hy - 1.2 }, { 42.4, hy - 3.4 }, { 40.4, hy } }, "fin_tail")
  P.poly(g, { { 39.6, hy + 1.2 }, { 42.4, hy + 3.4 }, { 40.4, hy } }, "fin_tail")

  P.render(img, g, {
    regions = {
      thorax = R_(R.dragon, 0.62, { bulge = 1.0 }),
      head = R_(P.ramp(0x4f9a5a, 4), 0.64, { bulge = 1.0 }),
      abdomen = R_(R.dragon, 0.60, { bulge = 1.1 }),
      fin_tail = R_(R.dragon_wing, 0.78, { bulge = 0.4, alpha = 200, sep = false, dither = false }),
      leg = R_(R.teal_dark, 0.50, { dither = false }),
      wing_f = R_(R.dragon_wing, 0.86, { bulge = 0.22, alpha = 118, sep = false, dither = false }),
      wing_b = R_(R.dragon_wing, 0.74, { bulge = 0.22, alpha = 100, sep = false, dither = false }),
    },
  })
  -- Augenfacetten (zwei große Augen)
  P.eye(img, g, hx + 1.0, hy - 1.8, 2.6, 2.4, { label = "head", core = P.c(0x123a52),
    mid = P.c(0x2a7a9a), rim = P.c(0x5ac0d8), glint = C.hot_white })
  P.eye(img, g, hx + 0.2, hy + 1.6, 2.2, 2.0, { label = "head", core = P.c(0x123a52),
    mid = P.c(0x2a7a9a), rim = P.c(0x5ac0d8), glint = C.hot_white })
  -- Hinterleib-Segmente
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if (x % 4 == 0) and x > 20 then return P.mul(cur, 0.70) end
    if x > 20 and v < 0.28 then return P.mix(cur, P.c(0xa8e8ff), 0.45) end
    return nil
  end)
  for _, w in ipairs(wings) do
    S.wingDetail(img, g, w.label, w, { count = 1, veins = P.rgba(110, 140, 170, 190) })
  end
  P.glint(img, floor(15), floor(hy - 3), P.c(0xd8f8ff), 1)
end
emit({ name = "dragonfly", w = 44, h = 28, frames = 3, fps = 11, draw = drawDragonfly })

-- ------------------------------------------------------------- MOSQUITO 28x20
local function drawMosquito(img, f)
  local N, W, H = 3, 28, 20
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local bob = floor(sin(ph + 0.3) * 0.6 + 0.5)
  local g = P.grid(W, H)
  local by = 11.0 + bob

  -- Flügel (zwei schmale)
  local w1 = { x0 = 15.0, y0 = by - 2.0, x1 = 19.0 + flap * 2.5, y1 = 0.8,
               cx = 20.0, cy = 5.0, w = 1.5, label = "wing_f", points = 14, root = 0.6, tip = 0.2 }
  S.leaf(g, w1)
  local w2 = { x0 = 13.0, y0 = by - 2.0, x1 = 11.0 + flap * 2.0, y1 = 0.8,
               cx = 8.0, cy = 4.5, w = 1.3, label = "wing_b", points = 14, root = 0.6, tip = 0.2 }
  S.leaf(g, w2)
  -- lange Beine
  P.chain(g, { { 13, by + 3 }, { 10, by + 7 }, { 11, by + 9 } }, 0.55, "leg")
  P.chain(g, { { 15, by + 3.2 }, { 15, by + 8 }, { 13.5, by + 9.5 } }, 0.55, "leg")
  P.chain(g, { { 17, by + 3 }, { 19, by + 7.5 }, { 18, by + 9.5 } }, 0.55, "leg")
  -- Stechrüssel nach links
  P.capsule(g, 8.0, by, 0.5, by + 0.6, 0.55, "prob")
  -- Körper
  P.ellipse(g, 19.0, by, 4.4, 2.9, "abdomen")
  P.ellipse(g, 14.0, by - 0.4, 3.4, 3.0, "thorax")
  P.ellipse(g, 8.6, by - 0.6, 2.8, 2.6, "head")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.chitin_dark, 0.58, { bulge = 1.1 }),
      thorax = R_(R.iron, 0.58, { bulge = 1.0 }),
      head = R_(R.black_chitin, 0.56),
      prob = R_(R.iron, 0.60, { dither = false }),
      leg = R_(R.black_chitin, 0.48, { dither = false }),
      wing_f = R_(R.dragon_wing, 0.86, { bulge = 0.2, alpha = 140, sep = false, dither = false }),
      wing_b = R_(R.dragon_wing, 0.74, { bulge = 0.2, alpha = 118, sep = false, dither = false }),
    },
  })
  -- roter Hinterleib + helle Binden
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if x > 17 then return P.mix(cur, P.c(0xb02030), 0.55) end
    if (x % 3 == 0) then return P.mix(cur, P.c(0xe0d8c0), 0.35) end
    return nil
  end)
  P.eye(img, g, 8.4, by - 1.0, 2.0, 2.1, { label = "head", core = P.c(0x2a0a18),
    mid = P.c(0x7a1a3a), rim = P.c(0xc04a6a) })
  img:drawPixel(0, floor(by + 0.6), P.c(0xffe0e8))
  S.wingDetail(img, g, "wing_f", w1, { count = 1 })
end
emit({ name = "mosquito", w = 28, h = 20, frames = 3, fps = 12, draw = drawMosquito })

-- --------------------------------------------------------------- HOPPER 32x28
local function drawHopper(img, f)
  local N, W, H = 3, 32, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local crouch = ({ 1.6, -1.2, 0.6 })[f]        -- Sprungphasen
  local g = P.grid(W, H)
  local by = 13.0 - crouch * 0.5

  -- große Sprungbeine (hinten)
  S.leg(g, { { 20, by + 4 }, { 26, by + 1.5 - crouch }, { 29, by + 8 } }, 1.5, "leg")
  S.leg(g, { { 19, by + 5 }, { 24, by + 3.5 - crouch }, { 27, by + 10 } }, 1.2, "leg")
  -- Vorderbeine
  P.chain(g, { { 10, by + 4 }, { 8, by + 8 }, { 9.5, by + 10 } }, 0.8, "leg")
  P.chain(g, { { 14, by + 4.5 }, { 14, by + 9 }, { 15.5, by + 10.5 } }, 0.8, "leg")
  -- Körper
  P.ellipse(g, 17.0, by + 1.5, 7.6, 4.6, "body")
  P.ellipse(g, 9.5, by - 0.5, 4.4, 4.2, "head")
  -- Fühler
  P.chain(g, { { 7.5, by - 4 }, { 3.0, by - 8.5 }, { 0.8, by - 7.0 } }, 0.65, "leg")
  -- Flügeldeckel
  P.ellipse(g, 18.0, by - 1.5, 6.4, 2.6, "wing")

  P.render(img, g, {
    regions = {
      body = R_(R.leaf, 0.62, { bulge = 1.1 }),
      head = R_(R.grass, 0.66, { bulge = 1.0 }),
      wing = R_(R.leaf_dark, 0.58, { bulge = 0.7 }),
      leg = R_(R.leaf_dark, 0.54, { dither = false }),
    },
  })
  -- Panzerstruktur: Rückenkante, Segmente
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if v < 0.16 then return P.mix(cur, P.c(0xe8f8a8), 0.45) end
    if v > 0.82 then return P.mul(cur, 0.80) end
    return nil
  end)
  P.paintIn(img, g, "wing", function(x, y, u, v, cur)
    if (x % 3 == 0) then return P.mul(cur, 0.78) end
    return nil
  end)
  P.eye(img, g, 10.5, by - 1.0, 2.4, 2.4, { label = "head", core = P.c(0x1a2a10),
    mid = P.c(0x4a7a20), rim = P.c(0x8ac040) })
  P.glint(img, 16, floor(by - 1), P.c(0xf0ffc0), 1)
end
emit({ name = "hopper", w = 32, h = 28, frames = 3, fps = 9, draw = drawHopper })

-- ----------------------------------------------------------------- PIKE 44x28
local function drawPike(img, f)
  local N, W, H = 3, 44, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local tail = sin(ph)
  local g = P.grid(W, H)
  local cy = 14.0

  -- Schwanzflosse (schwingt)
  P.poly(g, { { 34.0, cy }, { 43.0, cy - 7.0 + tail * 2.2 }, { 39.5, cy },
              { 43.0, cy + 7.0 - tail * 2.2 } }, "fin")
  -- Rückenflosse
  P.poly(g, { { 24.0, cy - 4.4 }, { 31.0, cy - 8.0 }, { 33.0, cy - 4.0 } }, "fin")
  -- Bauchflosse
  P.poly(g, { { 21.0, cy + 4.0 }, { 25.0, cy + 8.0 }, { 27.0, cy + 4.4 } }, "fin2")
  -- Körper
  P.ellipse(g, 22.0, cy, 14.0, 5.6, "body")
  P.ellipse(g, 33.0, cy, 5.0, 3.4, "body")
  -- Kopf mit Raubtierkiefer
  P.ellipse(g, 9.0, cy - 0.5, 6.0, 5.0, "head")
  P.poly(g, { { 8.0, cy + 1.0 }, { 0.6, cy + 0.2 }, { 7.5, cy + 4.4 } }, "jaw")
  -- Zähne
  for i = 0, 3 do
    local x = 2.0 + i * 1.8
    local ty = cy + 0.4 + i * 0.55
    P.setp(g, x, ty, "tooth")
    P.setp(g, x + 0.6, ty + 0.4, "tooth")
  end
  P.setp(g, 6.0, cy - 3.4, "tooth")

  P.render(img, g, {
    regions = {
      body = R_(R.fish, 0.62, { bulge = 1.15 }),
      head = R_(P.ramp(0x8a9aa8, 4), 0.64, { bulge = 1.0 }),
      jaw = R_(P.ramp(0xb8c4cc, 4), 0.66, { bulge = 0.8 }),
      fin = R_(R.fish_green, 0.58, { bulge = 0.6 }),
      fin2 = R_(R.fish_green, 0.54, { bulge = 0.6 }),
      tooth = R_(P.ramp(0xf0f0e8, 3), 0.80, { dither = false, bulge = 0.4 }),
    },
  })
  -- Schuppenreihen + Seitenlinie
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if v > 0.34 and v < 0.40 then return P.mix(cur, P.c(0xe8f0f8), 0.40) end
    if (x + y) % 4 == 0 and v > 0.45 then return P.mul(cur, 0.86) end
    if v < 0.20 then return P.mix(cur, P.c(0xd8e8f0), 0.30) end
    return nil
  end)
  -- Kiemendeckel
  P.paintIn(img, g, "head", function(x, y, u, v, cur)
    if x > 11 and x < 13 then return P.mul(cur, 0.78) end
    return nil
  end)
  P.eye(img, g, 8.0, cy - 2.0, 2.4, 2.4, { label = "head", core = P.c(0x12080a),
    mid = P.c(0x8a7a20), rim = P.c(0xd8c060) })
  P.glint(img, 24, floor(cy - 2), C.hot_white, 2)
end
emit({ name = "pike", w = 44, h = 28, frames = 3, fps = 10, draw = drawPike })

-- ---------------------------------------------------------------- SPORE 32x32
local function drawSpore(img, f)
  local N, W, H = 4, 32, 32
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local pulse = sin(ph)
  local g = P.grid(W, H)
  local cx, cy = 16.0, 17.0

  -- Ranken/Tentakel (schwingen)
  for k = 0, 6 do
    local a = -0.2 + k * (2 * pi / 7)
    local len = 8.0 + 1.6 * sin(ph + k)
    local ex = cx + cos(a) * len
    local ey = cy + sin(a) * len * 0.9
    local mx = cx + cos(a + 0.5) * len * 0.6
    local my = cy + sin(a + 0.5) * len * 0.6
    P.chain(g, { { cx + cos(a) * 4, cy + sin(a) * 4 }, { mx, my }, { ex, ey } }, 1.0, "tent")
    P.ellipse(g, ex, ey, 1.3, 1.3, "tent")
  end
  -- Kugeliger Sporenkörper mit Warzen
  P.ellipse(g, cx, cy, 7.2 + pulse * 0.5, 7.0 + pulse * 0.5, "ball")
  P.ellipse(g, cx - 2.5, cy - 2.0, 3.2, 3.0, "ball")
  P.ellipse(g, cx + 3.0, cy + 2.5, 2.6, 2.6, "ball")
  -- Keimöffnung/Glut
  P.ellipse(g, cx + 0.5, cy + 0.5, 2.8 + pulse * 0.4, 2.6 + pulse * 0.4, "glow")

  P.render(img, g, {
    regions = {
      ball = R_(R.bio, 0.58, { bulge = 1.2 }),
      tent = R_(R.bio_dark, 0.56, { bulge = 1.0, dither = false }),
      glow = R_(R.violet, 0.80, { bulge = 0.6, alpha = 240, dither = false }),
    },
  })
  -- Warzenstruktur (keine Rauschtextur: regelmäßiges Wabenmuster)
  P.paintIn(img, g, "ball", function(x, y, u, v, cur)
    local dx, dy = x - cx, y - cy
    local gx = (dx % 4)
    local gy = ((y + floor(dx / 2)) % 4)
    if gx == 0 and gy == 0 and (dx * dx + dy * dy) < 52 then return P.mul(cur, 0.72) end
    if dx * dx + dy * dy < 20 then return P.mul(cur, 0.88) end
    return nil
  end)
  -- Glutkern
  S.orb(img, cx + 0.5, cy + 0.5, 2.4 + pulse * 0.5,
    { P.c(0xffffff), P.c(0xe8d0ff), P.c(0xa87ae8), P.c(0x4a2e7a) }, { hard = true })
  -- Sporenstaub (geordnet, nicht zufällig)
  for k = 0, 3 do
    local a = ph + k * pi / 2
    img:drawPixel(floor(cx + cos(a) * 11), floor(cy + sin(a) * 10), P.c(0xc8b0ff))
  end
end
emit({ name = "spore", w = 32, h = 32, frames = 4, fps = 8, draw = drawSpore })

-- ------------------------------------------------------------- MUSHROOM 40x36
local function drawMushroom(img, f)
  local N, W, H = 3, 40, 36
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local bob = floor(sin(ph) * 1.2 + 0.5)
  local sway = sin(ph)
  local g = P.grid(W, H)
  local cx, cy = 21.0, 15.0 + bob

  -- Wurzelbeine
  P.chain(g, { { 18, 26 }, { 14 + sway, 31 }, { 12, 33 } }, 1.2, "root")
  P.chain(g, { { 22, 26 }, { 23 - sway, 31 }, { 25, 33 } }, 1.2, "root")
  -- Stiel
  P.ellipse(g, cx, 24.0 + bob * 0.5, 4.6, 7.0, "stalk")
  -- Hut
  P.ellipse(g, cx, cy, 15.0, 8.4, "cap")
  P.rect(g, cx - 15, cy, 30, 3, "cap")
  -- Lamellen unter dem Hut
  P.ellipse(g, cx, cy + 3.2, 12.0, 3.2, "gills")
  -- Augen am Stiel (Kreatur!)
  P.eye(img, g, cx - 2.5, 22.0 + bob, 2.2, 2.2, { label = "stalk", core = P.c(0x1a1018),
    mid = P.c(0x6a4a2a), rim = P.c(0xa87a3a) })
  P.eye(img, g, cx + 2.5, 22.0 + bob, 2.2, 2.2, { label = "stalk", core = P.c(0x1a1018),
    mid = P.c(0x6a4a2a), rim = P.c(0xa87a3a) })

  P.render(img, g, {
    regions = {
      cap = R_(P.ramp(0xb03a2a, 5), 0.60, { bulge = 1.2 }),
      gills = R_(P.ramp(0xe8dcc0, 4), 0.62, { bulge = 0.7 }),
      stalk = R_(P.ramp(0xe0d2b0, 4), 0.66, { bulge = 1.0 }),
      root = R_(P.ramp(0xb8a888, 4), 0.56, { bulge = 0.8, dither = false }),
    },
  })
  -- Hut: Flecken + Kante
  spots(img, g, "cap", { { 14, 12 + bob, 2.0 }, { 22, 10 + bob, 1.7 }, { 28, 14 + bob, 1.5 },
    { 18, 16 + bob, 1.3 }, { 25, 17 + bob, 1.2 } }, P.c(0xf4e8cc))
  P.paintIn(img, g, "cap", function(x, y, u, v, cur)
    if v > 0.78 then return P.mul(cur, 0.72) end
    if v < 0.16 then return P.mix(cur, P.c(0xff9a80), 0.45) end
    return nil
  end)
  -- Lamellenlinien
  P.paintIn(img, g, "gills", function(x, y, u, v, cur)
    if (x % 2 == 0) then return P.mul(cur, 0.78) end
    return nil
  end)
  -- Glanz / Sporenwölkchen
  P.glint(img, floor(cx - 6), floor(cy - 4), P.c(0xfff0e0), 2)
  for k = 0, 2 do
    local px = cx - 12 + k * 12 + sin(ph + k) * 1.5
    img:drawPixel(floor(px), floor(30 + k % 2), P.c(0xd8c8a8))
  end
end
emit({ name = "mushroom", w = 40, h = 36, frames = 3, fps = 8, draw = drawMushroom })

-- ----------------------------------------------------------------- VINE 32x40
local function drawVine(img, f)
  local N, W, H = 4, 32, 40
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local sway = sin(ph)
  local g = P.grid(W, H)

  -- Hauptranke von unten nach oben, Peitsche oben gekrümmt
  local pts = {
    { 16, 40 }, { 15, 33 }, { 17, 27 }, { 15.5, 21 }, { 18, 15 },
    { 21 + sway * 2, 9 }, { 17 + sway * 3.4, 4 }, { 10 + sway * 2.4, 3 },
  }
  P.chain(g, pts, 2.0, "vine", 0.55)
  -- Dornen
  local thorns = { { 15, 33 }, { 17, 27 }, { 15.5, 21 }, { 18, 15 }, { 20, 10 } }
  for i, p in ipairs(thorns) do
    local dir = (i % 2 == 0) and 1 or -1
    S.spike(g, p[1], p[2], p[1] + dir * 4.4, p[2] - 2.6, 1.3, "thorn")
  end
  -- Blätter
  S.leaf(g, { x0 = 16.0, y0 = 26.0, x1 = 27.0 + sway, y1 = 22.0, cx = 23.0, cy = 27.0,
              w = 3.6, label = "leaf", points = 16, root = 0.4, tip = 0.3 })
  S.leaf(g, { x0 = 16.5, y0 = 18.0, x1 = 6.0 - sway, y1 = 12.0, cx = 9.0, cy = 19.0,
              w = 3.2, label = "leaf", points = 16, root = 0.4, tip = 0.3 })
  -- Knospe oben
  P.ellipse(g, 10 + sway * 2.4, 2.5, 2.6, 2.4, "bud")

  P.render(img, g, {
    regions = {
      vine = R_(R.leaf_dark, 0.58, { bulge = 1.15 }),
      thorn = R_(R.chitin, 0.56, { bulge = 0.7, dither = false }),
      leaf = R_(R.leaf, 0.64, { bulge = 0.9 }),
      bud = R_(R.petal_pink, 0.70, { bulge = 1.0 }),
    },
  })
  -- Rankenstruktur: Windungen + helle Kante
  P.paintIn(img, g, "vine", function(x, y, u, v, cur)
    if (y % 4 == 0) then return P.mul(cur, 0.78) end
    if P.getp(g, x - 1, y) ~= "vine" then return P.mix(cur, P.c(0xb8e07a), 0.35) end
    return nil
  end)
  P.paintIn(img, g, "leaf", function(x, y, u, v, cur)
    if v < 0.30 then return P.mix(cur, P.c(0xd8f890), 0.35) end
    return nil
  end)
  P.glint(img, 14, 6, P.c(0xe8ffb0), 1)
end
emit({ name = "vine", w = 32, h = 40, frames = 4, fps = 8, draw = drawVine })

-- --------------------------------------------------------------- MANTIS 44x40
local function drawMantis(img, f)
  local N, W, H = 3, 44, 40
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local sway = sin(ph)
  local g = P.grid(W, H)

  -- Hinterbeine
  S.leg(g, { { 30, 28 }, { 35, 33 }, { 33, 38 + sway } }, 1.2, "leg")
  S.leg(g, { { 26, 28 }, { 27, 34 }, { 24 + sway, 38 } }, 1.2, "leg")
  -- Hinterleib (schräg nach hinten oben)
  P.ellipse(g, 33.0, 25.0, 9.0, 5.2, "abdomen")
  P.ellipse(g, 39.5, 22.0, 4.0, 3.6, "abdomen")
  -- Flügeldecken (über dem Hinterleib)
  S.leaf(g, { x0 = 27.0, y0 = 22.0, x1 = 41.0, y1 = 19.5, cx = 34.0, cy = 18.0,
              w = 3.2, label = "wing", points = 16, root = 0.6, tip = 0.35 })
  -- Brustabschnitt (schmal, aufrecht)
  P.ellipse(g, 24.0, 21.0, 4.6, 7.6, "thorax")
  -- Kopf (Dreieck, oben links)
  P.poly(g, { { 16.5, 8.5 }, { 26.0, 9.5 }, { 24.0, 16.0 }, { 18.0, 15.5 } }, "head")
  -- Fühler
  P.chain(g, { { 19.0, 8.5 }, { 15.5, 3.0 }, { 10.5, 1.5 } }, 0.65, "leg")
  P.chain(g, { { 22.5, 8.5 }, { 22.0, 2.5 }, { 18.0, 0.9 } }, 0.65, "leg")
  -- Fangarme (Sicheln), bewegen sich mit dem Frame
  local reach = sway * 2.2
  S.claw(g, 21.0, 16.5, 7.5 - reach, 8.0, 9.0, 15.0, 2.2, "arm", 16)
  S.claw(g, 20.0, 18.5, 9.0 - reach, 14.0, 11.0, 20.0, 1.9, "arm", 16)
  -- Dornen an den Sicheln
  S.spike(g, 12.0, 11.5, 9.0, 8.5, 0.8, "arm")
  S.spike(g, 14.5, 15.5, 11.0, 12.5, 0.8, "arm")
  P.chain(g, { { 18.0, 15.0 }, { 15.0, 19.0 }, { 13.5, 22.0 } }, 0.9, "leg")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.leaf_dark, 0.62, { bulge = 1.15 }),
      thorax = R_(R.leaf, 0.64, { bulge = 1.0 }),
      head = R_(R.grass, 0.70, { bulge = 1.05 }),
      wing = R_(P.ramp(0x3f6a2a, 4), 0.54, { bulge = 0.55 }),
      arm = R_(R.grass, 0.68, { bulge = 0.85 }),
      leg = R_(R.leaf_dark, 0.54, { dither = false }),
    },
  })
  -- Panzerstruktur
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if (x % 4 == 0) and x > 27 then return P.mul(cur, 0.74) end
    if v < 0.26 then return P.mix(cur, P.c(0xa8d860), 0.35) end
    return nil
  end)
  P.paintIn(img, g, "wing", function(x, y, u, v, cur)
    if (x + y) % 5 == 0 then return P.mix(cur, P.c(0x8ac040), 0.35) end
    return nil
  end)
  -- Facettenaugen (groß, oben auf dem Kopf)
  P.eye(img, g, 19.5, 11.0, 2.7, 2.7, { label = "head", core = P.c(0x2a1a10),
    mid = P.c(0x9a5a1a), rim = P.c(0xe0a04a) })
  P.eye(img, g, 24.0, 11.0, 2.3, 2.4, { label = "head", core = P.c(0x2a1a10),
    mid = P.c(0x9a5a1a), rim = P.c(0xe0a04a) })
  -- Mundwerkzeuge
  img:drawPixel(19, 14, P.c(0x2a1a10)); img:drawPixel(20, 14, P.c(0x2a1a10))
  img:drawPixel(21, 14, P.c(0x2a1a10))
  P.glint(img, 31, 20, P.c(0xd8f890), 1)
end
emit({ name = "mantis", w = 44, h = 40, frames = 3, fps = 8, draw = drawMantis })


-- ----------------------------------------------------------- GLASSDRONE 36x28
local function drawGlassDrone(img, f)
  local N, W, H = 3, 36, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local hover = floor(sin(ph) * 1.2 + 0.5)
  local g = P.grid(W, H)
  local cx, cy = 17.0, 13.0 + hover

  -- Untere Trägerstruktur + Düsen
  P.rrect(g, cx - 9, cy + 5, 18, 5, 2, "frame")
  P.rrect(g, cx - 4, cy + 9, 8, 3, 1.5, "frame")

  -- Glaskuppel
  P.ellipse(g, cx, cy - 1.0, 8.6, 8.0, "dome")
  -- Rahmenring
  S.ring(g, cx, cy - 1.0, 9.4, 8.8, 8.2, 7.4, "ring")
  -- Kern im Inneren
  P.ellipse(g, cx, cy, 3.4, 3.2, "core")
  -- Antenne
  P.capsule(g, cx + 4.0, cy - 8.0, cx + 7.5, cy - 12.5, 0.6, "frame")
  -- Greifer links
  P.chain(g, { { cx - 8, cy + 2 }, { cx - 13, cy + 1 }, { cx - 15.5, cy + 4 } }, 1.1, "frame")
  P.chain(g, { { cx - 8, cy + 3.5 }, { cx - 12.5, cy + 5 }, { cx - 15, cy + 7.5 } }, 1.1, "frame")

  P.render(img, g, {
    regions = {
      frame = R_(R.gunmetal, 0.58, { bulge = 0.9 }),
      ring = R_(R.steel, 0.66, { bulge = 0.7 }),
      dome = R_(R.glass, 0.72, { bulge = 0.9, alpha = 190, dither = false }),
      core = R_(R.energy_orange, 0.78, { bulge = 0.8, dither = false }),
    },
  })
  -- Glaskuppel: Reflexe + Innenleben
  P.paintIn(img, g, "dome", function(x, y, u, v, cur)
    local dx, dy = (x - cx) / 8.6, (y - (cy - 1.0)) / 8.0
    local q = dx * dx + dy * dy
    if q > 0.90 then return P.mix(cur, P.c(0xd8f0ff), 0.5) end
    if q < 0.42 then return P.mix(cur, P.c(0x2a4a6a), 0.55) end
    return nil
  end)
  -- Glanzkante der Kuppel
  P.paintIn(img, g, "dome", function(x, y, u, v, cur)
    if v < 0.22 and u < 0.42 then return P.rgba(240, 252, 255, 235) end
    return nil
  end)
  -- Energiekern mit Puls
  S.orb(img, cx, cy, 2.6 + (f == 2 and 0.5 or 0),
    { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) }, { hard = true })
  -- Triebwerksglut unter dem Rahmen
  S.orb(img, cx - 3.0, cy + 11.5, 1.7, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true, squash = 1.3 })
  S.orb(img, cx + 3.0, cy + 11.5, 1.7, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true, squash = 1.3 })
  -- Rahmen: Nieten + Statuslicht
  S.rivets(img, g, "ring", floor(cx - 6), floor(cx + 6), floor(cy - 8.5), P.c(0xbfd0e0))
  img:drawPixel(floor(cx + 7), floor(cy - 12.5), P.c(0xff5aa8))
  img:drawPixel(floor(cx - 7), floor(cy + 6), P.c(0x8fe04a))
  P.glint(img, floor(cx - 5), floor(cy - 5), C.hot_white, 2)
end
emit({ name = "glassdrone", w = 36, h = 28, frames = 3, fps = 10, draw = drawGlassDrone })

-- ------------------------------------------------------------ MIRRORORB 32x32
local function drawMirrorOrb(img, f)
  local N, W, H = 4, 32, 32
  local t = (f - 1) / N
  local g = P.grid(W, H)
  local cx, cy = 16.0, 16.0

  -- Kugel
  P.ellipse(g, cx, cy, 10.0, 10.0, "ball")
  -- Äquatorring (Metallband, klar abgesetzt)
  S.ring(g, cx, cy, 11.4, 5.2, 9.0, 2.6, "ring")
  -- Scharnierbacken an den Seiten
  P.ellipse(g, cx - 10.5, cy, 1.8, 3.0, "ring")
  P.ellipse(g, cx + 10.5, cy, 1.8, 3.0, "ring")

  P.render(img, g, {
    regions = {
      ball = R_(R.mirror, 0.66, { bulge = 1.25 }),
      ring = R_(R.chrome, 0.62, { bulge = 0.6 }),
    },
  })
  -- Spiegelreflexe: wandernde Bänder (rotieren mit dem Frame)
  local shift = f * 2
  P.paintIn(img, g, "ball", function(x, y, u, v, cur)
    local dx, dy = (x - cx) / 10.0, (y - cy) / 10.0
    local q = dx * dx + dy * dy
    if q > 0.94 then return P.mix(cur, P.c(0xe8f4ff), 0.55) end
    local band = ((x + y + shift) % 11)
    if band < 3 and y < cy + 2 and dx < 0.55 then return P.mix(cur, P.c(0xffffff), 0.60) end
    if band >= 7 and band < 8 then return P.mix(cur, P.c(0x2a4a6a), 0.40) end
    if dx > 0.42 and dy > 0.30 then return P.mix(cur, P.c(0x35506e), 0.30) end
    if dy > 0.62 then return P.mix(cur, P.c(0x1e3048), 0.30) end
    return nil
  end)
  -- Ring: Nieten und Licht
  S.rivets(img, g, "ring", floor(cx - 9), floor(cx + 9), floor(cy - 4.4), P.c(0xe8f4ff))
  P.paintIn(img, g, "ring", function(x, y, u, v, cur)
    if y <= floor(cy - 4) then return P.mix(cur, P.c(0xffffff), 0.35) end
    return nil
  end)
  P.glint(img, floor(cx - 4), floor(cy - 6), C.hot_white, 2)
  -- Warnlicht
  img:drawPixel(floor(cx), floor(cy - 10), P.c(0xef2f8e))
  img:drawPixel(floor(cx), floor(cy + 10), P.c(0xef2f8e))
end
emit({ name = "mirrororb", w = 32, h = 32, frames = 4, fps = 10, draw = drawMirrorOrb })

-- ------------------------------------------------------------- CRAWLER 44x32
local function drawCrawler(img, f)
  local N, W, H = 3, 44, 32
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local stride = sin(ph) * 2.0
  local g = P.grid(W, H)
  local cy = 14.0

  -- Sechs Spinnenbeine (Tripod-Gang)
  local hips = { { 14, cy + 5 }, { 20, cy + 6 }, { 26, cy + 5 } }
  for i, hp in ipairs(hips) do
    local sgn = (i % 2 == 0) and 1 or -1
    local off = stride * sgn
    S.leg(g, { hp, { hp[1] - 5 - off, hp[2] + 6 }, { hp[1] - 8 - off * 1.4, hp[2] + 11 } }, 1.0, "leg")
    S.leg(g, { hp, { hp[1] + 5 + off, hp[2] + 6 }, { hp[1] + 8 + off * 1.4, hp[2] + 11 } }, 1.0, "leg")
  end
  -- Rumpf (Panzerwanne)
  P.rrect(g, 8.0, cy - 6.0, 30.0, 12.0, 4.0, "hull")
  P.rrect(g, 12.0, cy - 9.0, 18.0, 6.0, 3.0, "turret")
  -- Kanone nach links
  P.rrect(g, 1.0, cy - 2.0, 9.0, 4.0, 1.0, "barrel")
  P.rect(g, 0.0, cy - 1.0, 2.0, 2.0, "barrel")
  -- Auspuff hinten
  P.rrect(g, 37.0, cy - 4.0, 5.0, 3.0, 1.0, "turret")

  P.render(img, g, {
    regions = {
      hull = R_(R.rust, 0.58, { bulge = 0.75 }),
      turret = R_(R.iron, 0.60, { bulge = 0.85 }),
      barrel = R_(R.steel_dark, 0.60, { bulge = 0.6 }),
      leg = R_(R.iron, 0.52, { bulge = 0.8, dither = false }),
    },
  })
  -- Panzerplatten + Nieten + Warnstreifen
  S.plates(img, g, "hull", floor(cy - 4), floor(cy + 5), P.c(0x3a2418), P.c(0xd8b890), 4)
  S.rivets(img, g, "hull", 10, 36, floor(cy - 5), P.c(0xb8c4d0))
  S.rivets(img, g, "turret", 14, 28, floor(cy - 8), P.c(0xb8c4d0))
  P.paintIn(img, g, "hull", function(x, y, u, v, cur)
    if x > 30 and x < 35 and (x + y) % 3 == 0 then return P.mix(cur, P.c(0xe2c024), 0.55) end
    return nil
  end)
  -- Sensorauge + Lauf Glut
  S.orb(img, 24.0, cy - 6.0, 2.0, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true })
  img:drawPixel(1, floor(cy), P.c(0xffd08a))
  -- Rauchfahne (deterministisch)
  img:drawPixel(41, floor(cy - 5), P.c(0x6a6060))
  img:drawPixel(42, floor(cy - 7), P.c(0x4a4448))
  P.glint(img, 12, floor(cy - 8), P.c(0xd8e4f0), 1)
end
emit({ name = "crawler", w = 44, h = 32, frames = 3, fps = 9, draw = drawCrawler })

-- --------------------------------------------------------------- SLUDGE 40x32
local function drawSludge(img, f)
  local N, W, H = 4, 40, 32
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local g = P.grid(W, H)
  local cx, cy = 20.0, 22.0

  -- Gelatinehaufen: breite Basis + wabernde Kuppe
  P.ellipse(g, cx, cy, 15.0, 7.4, "goo")
  for k = 0, 4 do
    local a = -pi * 0.85 + k * (pi * 0.42)
    local wob = sin(ph + k * 1.2) * 1.4
    P.ellipse(g, cx + cos(a) * 9.0, cy - 4.0 + sin(a) * 3.0 + wob, 4.2, 3.8, "goo")
  end
  -- Tropfen (hängen, per Frame versetzt)
  P.ellipse(g, cx - 13.0, cy + 7.0 + (f % 2), 1.9, 2.6, "drop")
  P.ellipse(g, cx + 12.0, cy + 6.5 + ((f + 1) % 2), 1.7, 2.3, "drop")
  P.chain(g, { { cx + 3.0, cy - 8.0 }, { cx + 3.5, cy - 11.0 - (f % 3) } }, 1.0, "drop")
  P.chain(g, { { cx - 6.0, cy - 8.5 }, { cx - 7.0, cy - 10.5 - ((f + 2) % 3) } }, 0.9, "drop")

  P.render(img, g, {
    regions = {
      goo = R_(R.sludge, 0.58, { bulge = 1.3 }),
      drop = R_(R.sludge, 0.56, { bulge = 1.1, dither = false }),
    },
  })
  -- Innere Blasen (klar umrissen, nicht zufällig)
  spots(img, g, "goo", { { 25, 20, 2.2 }, { 14, 24, 1.7 }, { 29, 25, 1.3 }, { 9, 20, 1.2 } },
    P.mix(P.c(0x9fc060), P.c(0xe8ffb0), 0.6))
  spots(img, g, "goo", { { 25, 20, 1.0 }, { 14, 24, 0.8 } }, P.c(0x3f5a1e))
  -- Glibberrand: heller Saum oben, dunkler unten
  P.paintIn(img, g, "goo", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "goo" then return P.mix(cur, P.c(0xe8ffb0), 0.55) end
    if P.getp(g, x, y + 1) ~= "goo" then return P.mul(cur, 0.70) end
    return nil
  end)
  -- Augen: helle Linsen mit dunkler Pupille (klar lesbar)
  for _, e in ipairs({ { cx - 7.0, cy - 3.0 }, { cx - 1.5, cy - 4.5 } }) do
    P.eye(img, g, e[1], e[2], 2.4, 2.6, { label = "goo", core = P.c(0x1a1a08),
      mid = P.c(0xf0f0a0), rim = P.c(0xffffe0), glint = P.c(0xffffff) })
  end
  -- Mundschlitz
  img:drawPixel(floor(cx + 3), floor(cy + 1), P.c(0x2a3a10))
  img:drawPixel(floor(cx + 4), floor(cy + 1), P.c(0x2a3a10))
  img:drawPixel(floor(cx + 5), floor(cy + 2), P.c(0x2a3a10))
  P.glint(img, floor(cx + 6), floor(cy - 6), P.c(0xf0ffc0), 2)
end
emit({ name = "sludge", w = 40, h = 32, frames = 4, fps = 8, draw = drawSludge })


-- --------------------------------------------------------------- PISTON 40x32
local function drawPiston(img, f)
  local N, W, H = 3, 40, 32
  local ext = ({ 0.0, 5.0, 1.5 })[f]         -- Kolbenhub je Frame
  local g = P.grid(W, H)
  local cy = 16.0

  -- Kolbenstange (fährt nach links aus): Stange + Stahlkappe
  P.rrect(g, 13.0 - ext, cy - 3.5, 13.0, 7.0, 1.0, "rod")
  P.rrect(g, 2.0 - ext, cy - 7.0, 10.0, 14.0, 1.5, "ram")
  P.rrect(g, 0.5 - ext, cy - 5.0, 2.5, 10.0, 0.8, "ram")
  -- Zylinderkörper
  P.rrect(g, 20.0, cy - 9.0, 18.0, 18.0, 3.0, "body")
  -- Anschlüsse
  P.rrect(g, 14.0, cy - 9.5, 7.0, 4.0, 1.5, "body")
  P.rrect(g, 14.0, cy + 5.5, 7.0, 4.0, 1.5, "body")
  -- Rohre hinten
  P.chain(g, { { 37, cy - 5 }, { 39.5, cy - 7 }, { 38.5, cy - 11 } }, 1.4, "pipe")
  P.chain(g, { { 37, cy + 5 }, { 39.5, cy + 8 } }, 1.4, "pipe")

  P.render(img, g, {
    regions = {
      body = R_(R.iron, 0.58, { bulge = 0.8 }),
      rod = R_(R.steel, 0.66, { bulge = 0.6 }),
      ram = R_(R.steel, 0.58, { bulge = 0.75 }),
      pipe = R_(R.brass, 0.60, { bulge = 0.7 }),
    },
  })
  -- Kolbenringe, Bolzen, Warnband
  P.paintIn(img, g, "rod", function(x, y, u, v, cur)
    if (x % 4 == 0) then return P.mul(cur, 0.7) end
    if y <= floor(cy - 2) then return P.mix(cur, P.c(0xffffff), 0.4) end
    return nil
  end)
  P.paintIn(img, g, "ram", function(x, y, u, v, cur)
    if v > 0.74 then return P.mul(cur, 0.66) end
    if v < 0.24 then return P.mix(cur, P.c(0xd8e8f8), 0.45) end
    if (y + floor(cy)) % 4 == 0 and u > 0.3 then return P.mul(cur, 0.8) end
    return nil
  end)
  -- Warnstreifen auf der Ramme
  P.paintIn(img, g, "ram", function(x, y, u, v, cur)
    if v > 0.40 and v < 0.60 and ((x + y) % 4 < 2) then return P.mix(cur, P.c(0xe2c024), 0.6) end
    return nil
  end)
  S.rivets(img, g, "body", 22, 36, floor(cy - 7.5), P.c(0xd8e4f0))
  S.rivets(img, g, "body", 22, 36, floor(cy + 7.5), P.c(0xd8e4f0))
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if x >= 30 and x <= 36 and ((x + y) % 4 < 2) then return P.mix(cur, P.c(0xe2c024), 0.5) end
    return nil
  end)
  -- Druckanzeige
  S.orb(img, 30.0, cy - 2.5, 1.8, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true })
  P.glint(img, 24, floor(cy - 6), P.c(0xe8f0f8), 1)
  -- Funken an der Stange
  img:drawPixel(floor(10 - ext), floor(cy + 4), P.c(0xffd08a))
end
emit({ name = "piston", w = 40, h = 32, frames = 3, fps = 10, draw = drawPiston })

-- ------------------------------------------------------------ GENERATOR 40x44
local function drawGenerator(img, f)
  local N, W, H = 4, 40, 44
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local g = P.grid(W, H)
  local cx = 20.0

  -- Sockel
  P.rrect(g, 6.0, 36.0, 28.0, 7.0, 2.0, "base")
  -- Säule
  P.rrect(g, 11.0, 10.0, 18.0, 27.0, 3.0, "tower")
  -- Spulen (drei Ringe)
  for k = 0, 2 do
    local y = 14.0 + k * 7.0
    P.rrect(g, 8.0, y, 24.0, 4.0, 1.5, "coil")
  end
  -- Kuppel/Kern oben
  P.ellipse(g, cx, 9.0, 7.0, 6.0, "dome")
  -- Kabel seitlich
  P.chain(g, { { 11, 36 }, { 4, 30 }, { 6, 24 } }, 1.1, "cable")
  P.chain(g, { { 29, 36 }, { 36, 30 }, { 34, 23 } }, 1.1, "cable")

  P.render(img, g, {
    regions = {
      base = R_(R.steel_dark, 0.56, { bulge = 0.7 }),
      tower = R_(R.gunmetal, 0.58, { bulge = 0.85 }),
      coil = R_(R.copper, 0.62, { bulge = 0.75 }),
      dome = R_(R.glass, 0.72, { bulge = 1.0, alpha = 220 }),
      cable = R_(R.rust_dark, 0.54, { bulge = 0.7, dither = false }),
    },
  })
  -- Spulenrillen
  P.paintIn(img, g, "coil", function(x, y, u, v, cur)
    if (x % 2 == 0) then return P.mul(cur, 0.8) end
    return nil
  end)
  -- Energiekern (pulsiert)
  local pr = 3.4 + sin(ph) * 0.7
  S.orb(img, cx, 9.0, pr, { P.c(0xffffff), P.c(0xcff8ff), P.c(0x3fd8f0), P.c(0x1a6a8a) }, { hard = true })
  -- Leuchtschienen an der Säule
  P.paintIn(img, g, "tower", function(x, y, u, v, cur)
    if (x == 15 or x == 25) and y > 12 and y < 36 then
      local on = ((y + f * 3) % 6) < 3
      if on then return P.c(0x8fe8ff) end
      return P.c(0x2a5a72)
    end
    return nil
  end)
  -- Funken (deterministisch nach Frame)
  local sparks = { { 4, 6 }, { 34, 12 }, { 8, 20 }, { 31, 3 } }
  for i, sp in ipairs(sparks) do
    if (i + f) % 2 == 0 then
      img:drawPixel(sp[1], sp[2] + (f % 3), P.c(0xd8f8ff))
      img:drawPixel(sp[1] + 1, sp[2] + (f % 3), P.c(0x8fe8ff))
    end
  end
  S.rivets(img, g, "base", 8, 32, 38, P.c(0xb8c4d0))
  P.glint(img, 17, 4, C.hot_white, 1)
end
emit({ name = "generator", w = 40, h = 44, frames = 4, fps = 8, draw = drawGenerator })

-- ------------------------------------------------------------- HIVEGUARD 44x36
local function drawHiveguard(img, f)
  local N, W, H = 3, 44, 36
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local flap = sin(ph)
  local flat = 0.5 + 0.5 * abs(cos(ph + 0.3))
  local bob = floor(sin(ph + 0.6) * 0.8 + 0.5)
  local g = P.grid(W, H)

  local tx, ty = 24.0, 18.0 + bob
  -- Flügel
  local w1 = { x0 = tx + 1, y0 = ty - 4, x1 = tx + 8 + flap * 2, y1 = 1.5 + bob,
               cx = tx + 9, cy = 7.0, w = 3.0 * flat, label = "wing_f", points = 16, root = 0.5, tip = 0.25 }
  S.leaf(g, w1)
  -- Beine
  S.legSet(g, { tx - 2, ty + 6 }, {
    { { -2, 2 }, { -4, 6 }, { -5.5, 8.5 } },
    { { 2, 2.5 }, { 2, 7 }, { 1, 9.5 } },
    { { 6, 2 }, { 8, 6 }, { 8, 8.5 } },
  }, 1.0, "leg")
  -- Körper: Hinterleib + Brust + Kopf
  P.ellipse(g, 33.0, ty + 3.0, 8.0, 5.6, "abdomen")
  P.ellipse(g, tx, ty, 6.0, 5.6, "thorax")
  P.ellipse(g, 15.5, ty - 1.0, 4.6, 4.4, "head")
  -- Helm (goldener Kamm)
  P.ellipse(g, 15.5, ty - 4.6, 4.2, 2.6, "helm")
  S.spike(g, 14.0, ty - 6.0, 11.0, ty - 11.0, 1.4, "helm")
  S.spike(g, 17.0, ty - 6.0, 18.5, ty - 11.5, 1.4, "helm")
  -- Schild (Wabe) vor dem Körper
  P.rrect(g, 1.0, ty - 8.0, 9.0, 16.0, 3.0, "shield")
  S.spike(g, 5.0, ty - 9.0, 5.0, ty - 11.5, 2.2, "shield")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.hive, 0.62, { bulge = 1.1 }),
      thorax = R_(R.chitin, 0.60, { bulge = 1.05 }),
      head = R_(R.black_chitin, 0.58, { bulge = 1.0 }),
      helm = R_(R.royal, 0.70, { bulge = 0.9 }),
      shield = R_(R.hive_dark, 0.60, { bulge = 0.7 }),
      leg = R_(R.chitin_dark, 0.52, { dither = false }),
      wing_f = R_(R.wing_amber, 0.80, { bulge = 0.25, alpha = 150, sep = false, dither = false }),
    },
  })
  -- Schild: Wabenmuster + Kante
  P.paintIn(img, g, "shield", function(x, y, u, v, cur)
    local gx, gy = x % 4, (y + floor(x / 2)) % 4
    if gx == 0 or gy == 0 then return P.mul(cur, 0.68) end
    if v < 0.12 then return P.mix(cur, P.c(0xfff0b0), 0.40) end
    return nil
  end)
  -- Hinterleibsbinden
  P.bands(img, g, "abdomen", P.c(0x241a22), { period = 5, thick = 2, offset = -6 })
  -- Rüstungsplatten auf der Brust
  P.paintIn(img, g, "thorax", function(x, y, u, v, cur)
    if (y % 4 == 0) then return P.mul(cur, 0.72) end
    if v < 0.2 then return P.mix(cur, P.c(0xffe0a0), 0.35) end
    return nil
  end)
  -- Augen (rot/orange, bedrohlich)
  P.eye(img, g, 14.5, ty - 0.5, 2.6, 2.6, { label = "head", core = P.c(0x2a0a08),
    mid = P.c(0xc04a1a), rim = P.c(0xffa04a) })
  -- Stachel
  S.spike(g, 40.5, ty + 3.0, 43.5, ty + 3.5, 1.5, "abdomen")
  S.wingDetail(img, g, "wing_f", w1, { count = 2, veins = P.rgba(180, 150, 90, 200) })
  P.glint(img, 22, floor(ty - 3), P.c(0xfff6c0), 2)
  img:drawPixel(3, floor(ty - 6), P.c(0xffd08a))
end
emit({ name = "hiveguard", w = 44, h = 36, frames = 3, fps = 10, draw = drawHiveguard })

-- -------------------------------------------------------------- ACOLYTE 36x32
local function drawAcolyte(img, f)
  local N, W, H = 4, 36, 32
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local sway = sin(ph)
  local g = P.grid(W, H)
  local cx = 18.0

  -- Kutte (nach unten breiter werdend, Zipfel flattern)
  P.poly(g, { { cx - 5.0, 8.0 }, { cx + 5.0, 8.0 }, { cx + 11.0, 28.0 },
              { cx + 7.0 + sway, 30.0 }, { cx, 28.5 }, { cx - 7.0 + sway, 30.0 },
              { cx - 11.0, 28.0 } }, "robe")
  -- Kapuze
  P.ellipse(g, cx, 9.0, 6.0, 6.6, "hood")
  -- Gesicht im Schatten
  P.ellipse(g, cx, 10.0, 3.6, 3.4, "face")
  -- Insektenbeine unter der Kutte
  P.chain(g, { { cx - 4, 29 }, { cx - 7, 31 }, { cx - 9.5, 30.5 } }, 0.8, "leg")
  P.chain(g, { { cx + 3, 29 }, { cx + 6.5, 31 }, { cx + 9, 30.5 } }, 0.8, "leg")
  -- Laterne am Stab (links)
  P.capsule(g, cx - 9.0, 12.0, cx - 11.0, 27.0, 0.9, "staff")
  P.rrect(g, cx - 14.0, 8.0, 6.0, 6.0, 1.5, "lantern")
  -- Fühler
  P.chain(g, { { cx - 2.0, 4.0 }, { cx - 5.0, 0.8 } }, 0.6, "leg")
  P.chain(g, { { cx + 2.0, 4.0 }, { cx + 5.0, 0.8 } }, 0.6, "leg")

  P.render(img, g, {
    regions = {
      robe = R_(R.violet_dark, 0.52, { bulge = 1.15 }),
      hood = R_(R.violet, 0.56, { bulge = 1.1 }),
      face = R_(P.ramp(0x1a1020, 3), 0.50, { bulge = 0.9 }),
      staff = R_(R.chitin_dark, 0.56, { bulge = 0.6, dither = false }),
      lantern = R_(R.brass, 0.62, { bulge = 0.8 }),
      leg = R_(R.chitin_dark, 0.50, { dither = false }),
    },
  })
  -- Kuttenfalten (regelmäßig, kein Rauschen)
  P.paintIn(img, g, "robe", function(x, y, u, v, cur)
    if (x + floor(y / 3) * 2) % 5 == 0 then return P.mul(cur, 0.76) end
    if x < cx - 6 or x > cx + 6 then return P.mix(cur, P.c(0x8a5ad0), 0.22) end
    return nil
  end)
  -- goldenes Zierband
  P.paintIn(img, g, "robe", function(x, y, u, v, cur)
    if y == 16 or y == 17 then return P.c(0xc8a03a) end
    return nil
  end)
  -- glühende Augen + Laternenlicht
  local pulse = (f % 2 == 0) and 1 or 0
  img:drawPixel(floor(cx - 1.5), 10, P.c(0xff6a2a))
  img:drawPixel(floor(cx + 1.5), 10, P.c(0xff6a2a))
  if pulse == 1 then img:drawPixel(floor(cx - 1.5), 9, P.c(0xffb060)) end
  S.orb(img, cx - 11.0, 11.0, 1.8 + pulse * 0.4,
    { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) }, { hard = true })
  P.glint(img, floor(cx + 2), 5, P.c(0xd8b0ff), 1)
end
emit({ name = "acolyte", w = 36, h = 32, frames = 4, fps = 9, draw = drawAcolyte })

-- ---------------------------------------------------------------- SHARD 28x28
local function drawShard(img, f)
  local N, W, H = 4, 28, 28
  local t = (f - 1) / N
  local ph = t * 2 * pi
  local g = P.grid(W, H)
  local cx, cy = 14.0, 14.0
  local w = 4.0 + sin(ph) * 0.8

  -- Hauptkristall (länglich, facettiert)
  P.poly(g, { { cx, 1.0 }, { cx + w, cy - 2 }, { cx + w * 0.6, cy + 11 },
              { cx, 13.0 }, { cx - w * 0.6, cy + 11 }, { cx - w, cy - 2 } }, "crystal")
  -- NebenSplitter (kreisen mit dem Frame)
  for k = 0, 2 do
    local a = ph + k * 2 * pi / 3
    local d = 9.5
    local px, py = cx + cos(a) * d, cy + sin(a) * d * 0.85
    P.poly(g, { { px, py - 2.6 }, { px + 1.6, py }, { px, py + 2.6 }, { px - 1.6, py } }, "chip")
  end

  P.render(img, g, {
    regions = {
      crystal = R_(R.crystal, 0.72, { bulge = 0.9, alpha = 235 }),
      chip = R_(R.crystal, 0.66, { bulge = 0.8, alpha = 220 }),
    },
  })
  -- Facetten: klare Kanten (Mittellinie + Schrägen)
  P.paintIn(img, g, "crystal", function(x, y, u, v, cur)
    if x == floor(cx) then return P.mix(cur, P.c(0xffffff), 0.55) end
    if u < 0.34 then return P.mul(cur, 0.80) end
    if u > 0.66 then return P.mix(cur, P.c(0xe8fbff), 0.35) end
    if (u + v) > 1.2 then return P.mul(cur, 0.86) end
    return nil
  end)
  -- Kern (pulsierend)
  S.orb(img, cx, cy - 1.0, 2.6 + (f == 2 and 0.5 or 0),
    { P.c(0xffffff), P.c(0xcff8ff), P.c(0x5ad0f0), P.c(0x1a5a7a) }, { hard = true })
  P.glint(img, floor(cx - 1), 4, C.hot_white, 1)
  -- Funken an den Splittern
  img:drawPixel(floor(cx + 9), floor(cy), P.c(0xffffff))
end
emit({ name = "shard", w = 28, h = 28, frames = 4, fps = 10, draw = drawShard })

--------------------------------------------------------------------------------
-- 6) BOSSE  (2 Frames, Puls; jeder mit klar leuchtendem Schwachpunkt-Kern)
--------------------------------------------------------------------------------
-- Leuchtkern als Schwachpunkt: Armatur-Ring + pulsierender Kern
local function weakCore(img, cx, cy, r, hue, pulse, opts)
  opts = opts or {}
  local G = PAL.glow(hue)
  -- dunkle Fassung (Kontrast zum Leuchten)
  S.ringWave(img, cx, cy, r + 2.6, 2.6, { P.c(0x1a1420), P.c(0x241a2a), P.c(0x0e0a12), P.c(0x0e0a12) },
    { squash = opts.squash or 1.0 })
  S.orb(img, cx, cy, r + pulse * 1.2, { G.C4, G.C3, G.C2, G.C1 }, { hard = true, squash = opts.squash })
  -- Strahlen/Glanz
  img:drawPixel(floor(cx - r * 0.35), floor(cy - r * 0.35), P.c(0xffffff))
  if opts.brackets ~= false then
    for k = 0, 3 do
      local a = k * pi / 2 + pi / 4
      local x1 = cx + cos(a) * (r + 3.2)
      local y1 = cy + sin(a) * (r + 3.2)
      local x2 = cx + cos(a) * (r + 7.0)
      local y2 = cy + sin(a) * (r + 7.0)
      P.line(img, floor(x1), floor(y1), floor(x2), floor(y2), P.mul(G.C1, 1.5))
    end
  end
end

-- Panzerplatte mit Kante, Nieten und Glanz (Technik-Detail)
local function armorPlate(img, g, label, x0, y0, w, h, ramp, opts)
  P.panel(img, g, label, x0, y0, w, h, ramp, opts)
end

-- ------------------------------------------------------------ BOSS_BEETLE 176x128
local function drawBossBeetle(img, f)
  local W, H = 176, 128
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 70.0
  -- Beine: 3 Paar, kräftig mit Knie und Klaue
  for k = 0, 2 do
    local hx = 74.0 + k * 24.0
    local sw = (k % 2 == 0) and pulse * 3.0 or -pulse * 3.0
    S.leg(g, { { hx, cy + 26 }, { hx - 14 - sw, cy + 44 }, { hx - 4 - sw, cy + 56 } }, 4.6, "leg")
    S.leg(g, { { hx + 8, cy + 26 }, { hx + 24 + sw, cy + 42 }, { hx + 36 + sw, cy + 54 } }, 4.6, "leg")
  end
  -- Kopf (groß, mit Wangen)
  P.ellipse(g, 40.0, cy - 2.0, 28.0, 26.0, "head")
  -- Mandibeln (dick, gezahnt)
  S.claw(g, 22.0, cy - 18.0, 2.0, cy - 46.0, 8.0, cy - 40.0, 9.0, "mand", 22)
  S.claw(g, 22.0, cy + 16.0, 2.0, cy + 44.0, 8.0, cy + 38.0, 9.0, "mand", 22)
  for k = 0, 3 do
    S.spike(g, 12.0 + k * 4.0, cy - 28.0 - k * 3.5, 8.0 + k * 4.0, cy - 23.0 - k * 3.5, 2.6, "mand")
    S.spike(g, 12.0 + k * 4.0, cy + 28.0 + k * 3.5, 8.0 + k * 4.0, cy + 23.0 + k * 3.5, 2.6, "mand")
  end
  -- Pronotum (Halsschild) + Flügeldecken
  P.ellipse(g, 68.0, cy - 2.0, 28.0, 32.0, "pronotum")
  P.ellipse(g, 118.0, cy, 50.0, 38.0, "shell")
  -- Fühler (gekniet)
  P.chain(g, { { 30, cy - 24 }, { 14, cy - 36 }, { 4, cy - 32 } }, 2.4, "leg")

  P.render(img, g, {
    regions = {
      shell = R_(P.ramp(0x5a3a1e, 6), 0.58, { bulge = 1.25, dither = false }),
      pronotum = R_(P.ramp(0x7a5230, 6), 0.62, { bulge = 1.1, dither = false }),
      head = R_(R.black_chitin, 0.56, { bulge = 1.05, dither = false }),
      mand = R_(R.black_chitin, 0.54, { bulge = 0.9, dither = false }),
      leg = R_(R.chitin_dark, 0.50, { bulge = 0.85, dither = false }),
    },
  })
  -- Panzerplatten: drei überlappende Schilde mit dunklen Fugen
  P.paintIn(img, g, "shell", function(x, y, u, v, cur)
    local arc = ((x - 118) ^ 2) / 2500 + ((y - cy) ^ 2) / 1444
    local band = floor(arc * 3.0)
    if arc > 1.0 then band = 3 end
    -- Fugen zwischen den Platten
    local d = (arc * 3.0) % 1.0
    if d < 0.055 and arc < 1.0 then return P.mul(cur, 0.52) end
    if v > 0.92 then return P.mul(cur, 0.60) end
    if v < 0.10 then return P.mix(cur, P.c(0xd8a86a), 0.45) end
    return nil
  end)
  -- Pronotum: Kante + Punktmuster
  P.paintIn(img, g, "pronotum", function(x, y, u, v, cur)
    if v < 0.16 then return P.mix(cur, P.c(0xe0b87a), 0.40) end
    if v > 0.88 then return P.mul(cur, 0.68) end
    if ((x - 68) % 8 == 0) and ((y - cy) % 8 == 0) then return P.mul(cur, 0.80) end
    return nil
  end)
  -- Kopf: Facettenaugen, Kauwerkzeuge
  P.eye(img, g, 44.0, cy - 10.0, 8.0, 8.0, { label = "head", core = P.c(0x2a0810),
    mid = P.c(0x8a1a2a), rim = P.c(0xe04a4a) })
  P.eye(img, g, 44.0, cy + 8.0, 7.0, 7.0, { label = "head", core = P.c(0x2a0810),
    mid = P.c(0x8a1a2a), rim = P.c(0xe04a4a) })
  P.paintIn(img, g, "head", function(x, y, u, v, cur)
    if v < 0.12 then return P.mix(cur, P.c(0x8a6a4a), 0.45) end
    return nil
  end)
  -- Schwachpunkt zwischen Halsschild und Panzer
  weakCore(img, 92.0, cy + 2.0, 12.0, "orange", pulse * 1.4)
  P.glint(img, 100, cy - 26, P.c(0xfff0d0), 5)
  spots(img, g, "shell", { { 136, cy - 16, 4.2 }, { 148, cy + 10, 3.4 } }, P.mul(P.c(0x2a1a12), 0.9))
end
emit({ name = "boss_beetle", w = 176, h = 128, frames = 2, fps = 6, draw = drawBossBeetle })


-- ------------------------------------------------------------- BOSS_LARVA 176x120
local function drawBossLarva(img, f)
  local W, H = 176, 120
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 60.0
  -- Körper als EINE Silhouette (keine Zackenkante), Furchen werden eingemalt
  local wob0 = (f == 2) and 1.5 or 0.0
  P.ellipse(g, 104.0, cy + wob0, 72.0, 36.0, "body")
  P.ellipse(g, 52.0, cy - wob0, 30.0, 34.0, "body")
  P.ellipse(g, 148.0, cy + wob0 * 1.4, 26.0, 26.0, "body")
  P.ellipse(g, 168.0, cy, 12.0, 14.0, "body")
  -- Körperfortsätze (kurze, dunkle Borsten)
  for k = 0, 7 do
    local x = 62.0 + k * 13.5
    S.spike(g, x, cy - 34.0, x + 3.0, cy - 39.0, 1.8, "bristle")
  end
  -- Kopf mit Schlund
  P.ellipse(g, 32.0, cy, 25.0, 25.0, "head")
  P.ellipse(g, 22.0, cy, 14.0, 15.0, "maw")
  for k = 0, 11 do
    local a = k * 2 * pi / 12
    S.spike(g, 22.0 + cos(a) * 8.0, cy + sin(a) * 9.0,
            22.0 + cos(a) * 14.0, cy + sin(a) * 15.0, 2.4, "tooth")
  end

  P.render(img, g, {
    regions = {
      body = R_(P.ramp(0xc2ab84, 6), 0.54, { bulge = 1.30, dither = false }),
      head = R_(P.ramp(0xa8825a, 5), 0.60, { bulge = 1.1, dither = false }),
      maw = R_(P.ramp(0x4a1a20, 4), 0.50, { bulge = 1.0, dither = false }),
      tooth = R_(P.ramp(0xf0e8d0, 4), 0.78, { bulge = 0.5, dither = false }),
      bristle = R_(P.ramp(0x5a3a22, 3), 0.44, { bulge = 0.5, dither = false }),
    },
  })
  -- Segmentfurchen: schmale, dunkle Täler zwischen den Ringen
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    local m = (x - 44) % 10.5
    if m < 2.4 and x > 46 then return P.mul(cur, 0.58) end
    if m < 3.6 and x > 46 then return P.mul(cur, 0.82) end
    if v < 0.13 then return P.mix(cur, P.c(0xf8eede), 0.45) end
    if v > 0.86 then return P.mul(cur, 0.62) end
    if v > 0.74 and ((x + y) % 9 == 0) then return P.mul(cur, 0.88) end
    return nil
  end)
  -- durchscheinender Kern (leuchtet durch die Haut)
  weakCore(img, 100.0, cy, 11.0, "magenta", pulse * 1.2)
  -- Schlundtiefe + Rachen-Glut
  P.paintIn(img, g, "maw", function(x, y, u, v, cur)
    local d = sqrt((x - 22) ^ 2 + (y - cy) ^ 2)
    if d < 5 then return P.c(0x1a0810) end
    if d < 9 then return P.c(0x3a1420) end
    return nil
  end)
  S.orb(img, 22.0, cy, 4.2, { P.c(0xffffff), P.c(0xffb0c0), P.c(0xef2f8e), P.c(0x5a0a2a) },
    { hard = true })
  -- Kopf-Auge
  P.eye(img, g, 40.0, cy - 12.0, 5.5, 5.5, { label = "head", core = P.c(0x2a1010),
    mid = P.c(0x8a3a20), rim = P.c(0xe08a4a) })
  P.glint(img, 128, cy - 20, P.c(0xfffdf0), 4)
end
emit({ name = "boss_larva", w = 176, h = 120, frames = 2, fps = 6, draw = drawBossLarva })


-- -------------------------------------------------------------- BOSS_PIKE 192x112
local function drawBossPike(img, f)
  local W, H = 192, 112
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 56.0
  -- Schwanzflosse
  P.poly(g, { { 148.0, cy }, { 190.0, cy - 34.0 }, { 172.0, cy }, { 190.0, cy + 34.0 } }, "fin")
  -- Rückenflosse
  P.poly(g, { { 100.0, cy - 20.0 }, { 136.0, cy - 42.0 }, { 148.0, cy - 16.0 } }, "fin")
  -- Bauchflosse
  P.poly(g, { { 92.0, cy + 18.0 }, { 112.0, cy + 40.0 }, { 122.0, cy + 16.0 } }, "fin2")
  -- Körper
  P.ellipse(g, 92.0, cy, 62.0, 26.0, "body")
  P.ellipse(g, 142.0, cy, 22.0, 13.0, "body")
  -- Kopf mit Raubtierkiefer
  P.ellipse(g, 32.0, cy - 2.0, 28.0, 24.0, "head")
  P.poly(g, { { 30.0, cy + 2.0 }, { 1.0, cy - 4.0 }, { 28.0, cy + 22.0 } }, "jaw")
  -- Zähne (Reihen)
  for k = 0, 7 do
    local x = 6.0 + k * 4.0
    local y = cy - 1.0 + k * 2.4
    S.spike(g, x, y, x + 3.0, y + 3.4, 1.6, "tooth")
  end
  for k = 0, 5 do
    local x = 12.0 + k * 4.0
    local y = cy - 16.0 + k * 1.2
    S.spike(g, x, y, x + 2.6, y + 3.2, 1.5, "tooth")
  end
  -- Kiemenplatte
  P.ellipse(g, 62.0, cy - 4.0, 10.0, 16.0, "gill")

  P.render(img, g, {
    regions = {
      body = R_(P.ramp(0x8fa8b8, 6), 0.62, { bulge = 1.2 }),
      head = R_(P.ramp(0x6f8898, 5), 0.62, { bulge = 1.05 }),
      jaw = R_(P.ramp(0xc0ccd4, 5), 0.66, { bulge = 0.9 }),
      fin = R_(P.ramp(0x4a8a7a, 5), 0.58, { bulge = 0.7 }),
      fin2 = R_(P.ramp(0x3f7a6a, 4), 0.54, { bulge = 0.7 }),
      tooth = R_(P.ramp(0xf4f0e0, 4), 0.80, { bulge = 0.5, dither = false }),
      gill = R_(P.ramp(0x9fb8c8, 4), 0.60, { bulge = 0.9 }),
    },
  })
  -- Schuppenmuster (Reihen, kein Rauschen)
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    local row = floor(y / 5)
    local ox = (row % 2) * 3
    if (x + ox) % 6 == 0 then return P.mul(cur, 0.86) end
    if v > 0.36 and v < 0.42 then return P.mix(cur, P.c(0xe8f4ff), 0.45) end
    if v < 0.16 then return P.mix(cur, P.c(0xd8e8f0), 0.35) end
    return nil
  end)
  -- Kiemenplatte: Rillen + leuchtender Kern
  P.paintIn(img, g, "gill", function(x, y, u, v, cur)
    if (y % 4 == 0) then return P.mul(cur, 0.72) end
    return nil
  end)
  weakCore(img, 62.0, cy - 4.0, 6.0, "cyan", pulse * 1.0)
  -- Auge
  P.eye(img, g, 30.0, cy - 10.0, 7.0, 7.0, { label = "head", core = P.c(0x0a0a10),
    mid = P.c(0x9a8a20), rim = P.c(0xe8d060) })
  P.glint(img, 96, cy - 16, P.c(0xffffff), 4)
end
emit({ name = "boss_pike", w = 192, h = 112, frames = 2, fps = 6, draw = drawBossPike })

-- ------------------------------------------------------------ BOSS_FUNGUS 176x144
local function drawBossFungus(img, f)
  local W, H = 176, 144
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cx = 88.0
  local lift = pulse * 1.5
  -- Wurzelbeine (am Stiel ansetzend)
  for k = 0, 3 do
    local x = 60.0 + k * 20.0
    P.chain(g, { { x, 112.0 }, { x - 14 + k * 9, 126.0 }, { x - 20 + k * 12, 139.0 } }, 4.6, "root")
  end
  -- Stiel (massiv, konisch)
  P.poly(g, { { cx - 20, 66.0 }, { cx + 20, 66.0 }, { cx + 26, 118.0 }, { cx - 26, 118.0 } }, "stalk")
  P.ellipse(g, cx, 116.0, 26.0, 10.0, "stalk")
  -- Lamellen (frei sichtbar unter dem Hut)
  P.ellipse(g, cx, 62.0 - lift, 60.0, 13.0, "gills")
  -- Hut
  P.ellipse(g, cx, 40.0 - lift, 76.0, 36.0, "cap")
  P.rect(g, cx - 76, 40 - lift, 152, 20, "cap")
  for k = 0, 9 do
    local x = cx - 70 + k * 15.5
    P.ellipse(g, x, 58.0 - lift + sin(k * 1.3) * 2.0, 8.5, 6.0, "cap")
  end

  P.render(img, g, {
    regions = {
      cap = R_(P.ramp(0x9a2a3a, 6), 0.58, { bulge = 1.3, dither = false }),
      gills = R_(P.ramp(0xe8dcc0, 5), 0.60, { bulge = 0.85, dither = false }),
      stalk = R_(P.ramp(0xd8c8a0, 6), 0.64, { bulge = 1.15, dither = false }),
      root = R_(P.ramp(0xa8967a, 5), 0.54, { bulge = 0.9, dither = false }),
    },
  })
  spots(img, g, "cap", { { 50, 28 - lift, 8 }, { 86, 18 - lift, 6 }, { 122, 32 - lift, 7 },
    { 70, 44 - lift, 5 }, { 106, 46 - lift, 4 }, { 34, 46 - lift, 5 } }, P.c(0xf4e8cc))
  P.paintIn(img, g, "cap", function(x, y, u, v, cur)
    if v > 0.80 then return P.mul(cur, 0.70) end
    if v < 0.13 then return P.mix(cur, P.c(0xff9a80), 0.40) end
    return nil
  end)
  -- Lamellen: radial wirkende Rillen
  P.paintIn(img, g, "gills", function(x, y, u, v, cur)
    if ((x - cx) % 5 == 0) then return P.mul(cur, 0.72) end
    if v > 0.75 then return P.mul(cur, 0.85) end
    return nil
  end)
  -- Stiel: Manschette + Adern
  P.paintIn(img, g, "stalk", function(x, y, u, v, cur)
    if y >= 74 and y <= 79 then return P.mul(cur, 0.64) end
    if y >= 80 and y <= 81 then return P.mix(cur, P.c(0xfff0d0), 0.35) end
    if u < 0.22 then return P.mix(cur, P.c(0xfff6e0), 0.35) end
    if u > 0.80 then return P.mul(cur, 0.80) end
    return nil
  end)
  -- Schwachpunkt im Stiel
  weakCore(img, cx, 92.0, 13.0, "green", pulse * 1.5)
  -- Augen
  P.eye(img, g, cx - 14.0, 106.0, 4.6, 4.6, { label = "stalk", core = P.c(0x1a1008),
    mid = P.c(0x8a5a2a), rim = P.c(0xd8a860) })
  P.eye(img, g, cx + 14.0, 106.0, 4.6, 4.6, { label = "stalk", core = P.c(0x1a1008),
    mid = P.c(0x8a5a2a), rim = P.c(0xd8a860) })
  -- Sporen
  for k = 0, 5 do
    local x = 24.0 + k * 26.0
    local y = 128.0 - (k % 3) * 6
    S.orb(img, x, y, 2.2 + pulse * 0.4, { P.c(0xffffff), P.c(0xfff2d0), P.c(0xd8c8a0), P.c(0x8a7a60) },
      { hard = true })
  end
  P.glint(img, 46, 14 - lift, P.c(0xfff0e0), 5)
end
emit({ name = "boss_fungus", w = 176, h = 144, frames = 2, fps = 6, draw = drawBossFungus })


-- ------------------------------------------------------------ BOSS_MANTIS 192x128
local function drawBossMantis(img, f)
  local W, H = 192, 128
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 66.0
  -- Hinterbeine
  S.leg(g, { { 118, cy + 22 }, { 140, cy + 44 }, { 132, cy + 60 } }, 5.0, "leg")
  S.leg(g, { { 100, cy + 22 }, { 104, cy + 46 }, { 92, cy + 60 } }, 5.0, "leg")
  -- Hinterleib
  P.ellipse(g, 136.0, cy + 4.0, 34.0, 22.0, "abdomen")
  P.ellipse(g, 168.0, cy - 2.0, 16.0, 13.0, "abdomen")
  -- Flügeldecken
  S.leaf(g, { x0 = 110.0, y0 = cy - 14.0, x1 = 172.0, y1 = cy - 22.0, cx = 140.0, cy = cy - 32.0,
              w = 12.0, label = "wing", points = 24, root = 0.6, tip = 0.35 })
  -- Thorax (aufrecht)
  P.ellipse(g, 86.0, cy - 6.0, 20.0, 30.0, "thorax")
  -- Kopf (Trapez mit gerundeter Stirn)
  P.ellipse(g, 58.0, cy - 34.0, 19.0, 17.0, "head")
  P.poly(g, { { 40.0, cy - 44.0 }, { 76.0, cy - 42.0 }, { 74.0, cy - 20.0 }, { 42.0, cy - 24.0 } }, "head")
  -- Fühler
  P.chain(g, { { 50, cy - 50 }, { 40, cy - 64 }, { 16, cy - 66 } }, 1.9, "leg")
  P.chain(g, { { 66, cy - 50 }, { 66, cy - 68 }, { 44, cy - 78 } }, 1.9, "leg")
  -- Fangarme: zwei nach vorn gestreckte Sicheln mit Schneide
  local reach = pulse * 3.0
  P.poly(g, { { 72.0, cy - 12.0 }, { 50.0, cy - 42.0 }, { 18.0 - reach, cy - 44.0 },
              { 4.0 - reach, cy - 30.0 }, { 24.0 - reach, cy - 30.0 }, { 48.0, cy - 24.0 } }, "arm")
  P.poly(g, { { 68.0, cy + 6.0 }, { 46.0, cy + 20.0 }, { 16.0 - reach, cy + 14.0 },
              { 4.0 - reach, cy + 2.0 }, { 26.0 - reach, cy + 4.0 }, { 50.0, cy + 8.0 } }, "arm")
  -- Barbs an den Sicheln
  for k = 0, 2 do
    local bx = 26.0 - reach + k * 9.0
    local by = cy - 40.0 + k * 2.0
    S.spike(g, bx, by, bx - 3.0, by - 6.0, 2.0, "arm")
  end
  for k = 0, 1 do
    local bx = 22.0 - reach + k * 11.0
    S.spike(g, bx, cy + 12.0, bx - 4.0, cy + 17.0, 2.0, "arm")
  end
  -- Mittelbeine
  P.chain(g, { { 92, cy + 20 }, { 80, cy + 44 }, { 84, cy + 58 } }, 3.2, "leg")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.leaf_dark, 0.62, { bulge = 1.2 }),
      thorax = R_(R.leaf, 0.64, { bulge = 1.1 }),
      head = R_(R.grass, 0.70, { bulge = 1.05 }),
      wing = R_(P.ramp(0x3f6a2a, 5), 0.54, { bulge = 0.7 }),
      arm = R_(R.grass, 0.68, { bulge = 0.9 }),
      leg = R_(R.leaf_dark, 0.52, { bulge = 0.9, dither = false }),
    },
  })
  -- Struktur
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if (x % 11 >= 8) and x > 120 then return P.mul(cur, 0.74) end
    if v < 0.18 then return P.mix(cur, P.c(0xa8d860), 0.35) end
    return nil
  end)
  P.paintIn(img, g, "wing", function(x, y, u, v, cur)
    if (x + y) % 7 <= 1 then return P.mix(cur, P.c(0x8ac040), 0.40) end
    if v < 0.25 then return P.mix(cur, P.c(0xd8f890), 0.40) end
    return nil
  end)
  -- Facettenaugen
  P.eye(img, g, 49.0, cy - 36.0, 7.0, 7.5, { label = "head", core = P.c(0x2a1a10),
    mid = P.c(0x9a5a1a), rim = P.c(0xe0a04a) })
  P.eye(img, g, 67.0, cy - 35.0, 6.4, 7.0, { label = "head", core = P.c(0x2a1a10),
    mid = P.c(0x9a5a1a), rim = P.c(0xe0a04a) })
  -- Mundwerkzeuge
  for k = 0, 5 do img:drawPixel(50 + k, floor(cy - 15), P.c(0x2a1a10)) end
  img:drawPixel(52, floor(cy - 14), P.c(0x6a4a20))
  img:drawPixel(55, floor(cy - 14), P.c(0x6a4a20))
  -- Schneide der Sicheln hell
  P.paintIn(img, g, "arm", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "arm" and y < cy then return P.mix(cur, P.c(0xe8ffb0), 0.55) end
    if P.getp(g, x, y + 1) ~= "arm" and y > cy then return P.mix(cur, P.c(0xe8ffb0), 0.55) end
    if v < 0.25 then return P.mix(cur, P.c(0xd8f890), 0.35) end
    return nil
  end)
  -- Schwachpunkt im Thorax
  weakCore(img, 86.0, cy - 2.0, 8.0, "yellow", pulse * 1.3)
  P.glint(img, 130, cy - 12, P.c(0xd8f890), 4)
end
emit({ name = "boss_mantis", w = 192, h = 128, frames = 2, fps = 6, draw = drawBossMantis })

-- -------------------------------------------------------- BOSS_POLLINATOR 176x120
local function drawBossPollinator(img, f)
  local W, H = 176, 120
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 64.0
  -- mechanische Beine
  for k = 0, 2 do
    local x = 70.0 + k * 22.0
    P.chain(g, { { x, cy + 26 }, { x - 6, cy + 40 }, { x + 2, cy + 50 } }, 3.6, "leg")
  end
  -- Hinterleib: segmentierter Panzer mit Honigtank
  P.ellipse(g, 116.0, cy + 4.0, 44.0, 30.0, "abdomen")
  for k = 0, 3 do
    P.ellipse(g, 96.0 + k * 14.0, cy + 4.0, 7.0, 30.0 - k * 4.0, "band")
  end
  -- Flügel (Energie-Klingen)
  P.poly(g, { { 62.0, cy - 18.0 }, { 96.0, cy - 54.0 }, { 112.0, cy - 50.0 }, { 74.0, cy - 16.0 } }, "wing")
  P.poly(g, { { 54.0, cy - 16.0 }, { 74.0, cy - 50.0 }, { 88.0, cy - 48.0 }, { 64.0, cy - 14.0 } }, "wing")
  -- Thorax mit Rüstung
  P.ellipse(g, 62.0, cy, 28.0, 27.0, "thorax")
  P.rrect(g, 44.0, cy - 18.0, 30.0, 12.0, 3.0, "plate")
  -- Kopf mit Visor
  P.ellipse(g, 26.0, cy - 4.0, 21.0, 19.0, "head")
  P.rrect(g, 6.0, cy - 8.0, 18.0, 8.0, 2.0, "visor")
  -- Kiefer
  S.spike(g, 16.0, cy + 8.0, 8.0, cy + 16.0, 2.6, "mand")
  S.spike(g, 26.0, cy + 10.0, 20.0, cy + 18.0, 2.4, "mand")
  -- Kanone unter dem Thorax
  P.rrect(g, 20.0, cy + 16.0, 26.0, 8.0, 2.0, "cannon")
  -- Auspuffrohre
  P.chain(g, { { 150.0, cy - 12.0 }, { 162.0, cy - 18.0 } }, 3.0, "pipe")
  P.chain(g, { { 150.0, cy + 12.0 }, { 162.0, cy + 18.0 } }, 3.0, "pipe")

  P.render(img, g, {
    regions = {
      abdomen = R_(P.ramp(0x8a6a2a, 6), 0.58, { bulge = 1.25, dither = false }),
      band = R_(R.hive, 0.62, { bulge = 0.95, dither = false }),
      thorax = R_(R.iron, 0.58, { bulge = 1.1, dither = false }),
      plate = R_(R.steel, 0.62, { bulge = 0.8, dither = false }),
      head = R_(R.gunmetal, 0.56, { bulge = 1.05, dither = false }),
      visor = R_(R.energy_orange, 0.82, { bulge = 0.7, dither = false }),
      mand = R_(R.steel_dark, 0.56, { bulge = 0.7, dither = false }),
      cannon = R_(R.steel_dark, 0.58, { bulge = 0.7, dither = false }),
      pipe = R_(R.copper, 0.60, { bulge = 0.7, dither = false }),
      leg = R_(R.steel_dark, 0.54, { bulge = 0.8, dither = false }),
      wing = R_(R.energy_cyan, 0.72, { bulge = 0.4, alpha = 170, dither = false }),
    },
  })
  -- Panzerdetails: Segmentfugen, Nieten, Honigfenster
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if (x % 10 == 0) and x > 82 then return P.mul(cur, 0.55) end
    if v < 0.12 then return P.mix(cur, P.c(0xffe0a0), 0.40) end
    if v > 0.90 then return P.mul(cur, 0.62) end
    return nil
  end)
  S.rivets(img, g, "thorax", 40, 84, floor(cy + 10), P.c(0xd8e4f0))
  S.rivets(img, g, "plate", 48, 70, floor(cy - 14), P.c(0xd8e4f0))
  P.paintIn(img, g, "band", function(x, y, u, v, cur)
    if v > 0.55 and v < 0.78 then return P.mix(cur, P.c(0xffe07a), 0.55) end
    return nil
  end)
  -- Visor leuchtet
  P.paintIn(img, g, "visor", function(x, y, u, v, cur)
    if v > 0.45 and v < 0.62 then return P.c(0xfff6d0) end
    return nil
  end)
  -- Schwachpunkt im Thorax
  weakCore(img, 66.0, cy + 2.0, 10.0, "magenta", pulse * 1.3)
  -- Kanal-/Rohrdetails
  P.paintIn(img, g, "pipe", function(x, y, u, v, cur)
    if (x + y) % 4 == 0 then return P.mul(cur, 0.72) end
    return nil
  end)
  P.glint(img, 104, cy - 18, P.c(0xfff0d0), 4)
  -- Triebwerksglut
  S.orb(img, 163.0, cy - 20.0, 2.6, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true })
  S.orb(img, 163.0, cy + 20.0, 2.6, { P.c(0xffffff), P.c(0xffe0a0), P.c(0xff8a2a), P.c(0x8a3a10) },
    { hard = true })
end
emit({ name = "boss_pollinator", w = 176, h = 120, frames = 2, fps = 6, draw = drawBossPollinator })

-- ----------------------------------------------------------- BOSS_SKATER 192x120
local function drawBossSkater(img, f)
  local W, H = 192, 120
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 62.0
  -- Vier lange, gespreizte Beine mit Gelenken
  local legs = {
    { { 70, cy + 6 }, { 44, cy - 18 }, { 6, cy - 30 }, { 2, cy + 4 } },
    { { 78, cy + 6 }, { 62, cy - 20 }, { 34, cy - 44 }, { 22, cy - 52 } },
    { { 78, cy + 8 }, { 64, cy + 26 }, { 40, cy + 46 }, { 20, cy + 54 } },
    { { 70, cy + 8 }, { 46, cy + 22 }, { 18, cy + 34 }, { 2, cy + 40 } },
  }
  for _, l in ipairs(legs) do
    P.chain(g, l, 3.4, "leg", 0.55)
  end
  -- Körper: schlank, langgestreckt
  P.ellipse(g, 104.0, cy, 54.0, 15.0, "body")
  P.ellipse(g, 150.0, cy - 1.0, 22.0, 9.0, "body")
  -- Kopf
  P.ellipse(g, 44.0, cy - 2.0, 15.0, 13.0, "head")
  -- Antennen
  P.chain(g, { { 36, cy - 10 }, { 22, cy - 20 }, { 4, cy - 22 } }, 1.8, "leg")
  P.chain(g, { { 40, cy - 12 }, { 34, cy - 24 }, { 16, cy - 30 } }, 1.8, "leg")
  -- Rückenplatten
  for k = 0, 3 do
    P.ellipse(g, 74.0 + k * 22.0, cy - 6.0, 10.0, 7.0, "plate")
  end

  P.render(img, g, {
    regions = {
      body = R_(P.ramp(0x5a6a7a, 6), 0.58, { bulge = 1.2, dither = false }),
      plate = R_(P.ramp(0x8a9aaa, 5), 0.64, { bulge = 0.85, dither = false }),
      head = R_(P.ramp(0x4a5a6a, 5), 0.58, { bulge = 1.05, dither = false }),
      leg = R_(P.ramp(0x4a4a52, 5), 0.54, { bulge = 0.85, dither = false }),
    },
  })
  -- Körper: Segmentierung + Wasserlinie
  P.paintIn(img, g, "body", function(x, y, u, v, cur)
    if (x % 12 == 0) and x > 60 then return P.mul(cur, 0.72) end
    if v > 0.36 and v < 0.42 then return P.mix(cur, P.c(0xcfe8ff), 0.55) end
    if v < 0.14 then return P.mix(cur, P.c(0xa8c8e0), 0.40) end
    return nil
  end)
  P.paintIn(img, g, "plate", function(x, y, u, v, cur)
    if v < 0.22 then return P.mix(cur, P.c(0xd8e8f8), 0.45) end
    if (x + y) % 7 == 0 then return P.mul(cur, 0.86) end
    return nil
  end)
  -- Augen
  P.eye(img, g, 46.0, cy - 6.0, 5.0, 5.0, { label = "head", core = P.c(0x081018),
    mid = P.c(0x2a7a9a), rim = P.c(0x6ad0e8) })
  P.eye(img, g, 40.0, cy + 2.0, 4.0, 4.0, { label = "head", core = P.c(0x081018),
    mid = P.c(0x2a7a9a), rim = P.c(0x6ad0e8) })
  -- Schwachpunkt
  weakCore(img, 116.0, cy, 9.0, "cyan", pulse * 1.3)
  -- Wellenlinien unter dem Körper (Wasseroberfläche)
  for k = 0, 12 do
    local x = 20 + k * 13
    local y = 86 + (k % 3) * 2
    img:drawPixel(x, y, P.rgba(180, 220, 245, 150))
    img:drawPixel(x + 1, y, P.rgba(140, 190, 225, 110))
  end
  P.glint(img, 100, cy - 8, P.c(0xe8f8ff), 3)
end
emit({ name = "boss_skater", w = 192, h = 120, frames = 2, fps = 6, draw = drawBossSkater })

-- -------------------------------------------------------- BOSS_HARVESTER 184x128
local function drawBossHarvester(img, f)
  local W, H = 184, 128
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 66.0
  -- Raupenkette unten
  P.rrect(g, 20.0, 96.0, 150.0, 20.0, 8.0, "track")
  for k = 0, 6 do
    P.ellipse(g, 32.0 + k * 21.0, 106.0, 8.0, 8.0, "wheel")
  end
  -- Rumpf
  P.rrect(g, 24.0, 30.0, 148.0, 68.0, 8.0, "hull")
  -- Fronttrommel mit Messern (links)
  P.ellipse(g, 30.0, cy + 6.0, 22.0, 26.0, "drum")
  for k = 0, 7 do
    local a = k * pi / 4 + pulse * 0.2
    S.spike(g, 30.0 + cos(a) * 16.0, cy + 6.0 + sin(a) * 20.0,
            30.0 + cos(a) * 30.0, cy + 6.0 + sin(a) * 34.0, 3.4, "blade")
  end
  -- Schornstein + Rohre
  P.rrect(g, 130.0, 10.0, 14.0, 26.0, 3.0, "stack")
  P.rrect(g, 118.0, 40.0, 34.0, 8.0, 3.0, "pipe")
  -- Kessel/Ausrüstung
  P.ellipse(g, 96.0, cy + 2.0, 30.0, 26.0, "boiler")
  -- Luken und Leitern
  P.rrect(g, 60.0, 44.0, 16.0, 14.0, 2.0, "hatch")

  P.render(img, g, {
    regions = {
      hull = R_(R.rust, 0.56, { bulge = 0.8, dither = false }),
      track = R_(P.ramp(0x3a3a42, 5), 0.52, { bulge = 0.7, dither = false }),
      wheel = R_(R.steel_dark, 0.56, { bulge = 0.9, dither = false }),
      drum = R_(R.iron, 0.56, { bulge = 1.0, dither = false }),
      blade = R_(R.chrome, 0.70, { bulge = 0.5, dither = false }),
      stack = R_(R.steel_dark, 0.54, { bulge = 0.8, dither = false }),
      pipe = R_(R.copper, 0.58, { bulge = 0.75, dither = false }),
      boiler = R_(R.brass, 0.60, { bulge = 1.15, dither = false }),
      hatch = R_(R.steel, 0.58, { bulge = 0.7, dither = false }),
    },
  })
  -- Panzerplatten, Nieten, Warnstreifen
  S.plates(img, g, "hull", 34, 90, P.c(0x2a1a12), P.c(0xd8b890), 5)
  S.rivets(img, g, "hull", 30, 166, 36, P.c(0xc8d4e0))
  P.paintIn(img, g, "hull", function(x, y, u, v, cur)
    if x > 146 and x < 160 and ((x + y) % 4 < 2) then return P.mix(cur, P.c(0xe2c024), 0.55) end
    if v > 0.88 then return P.mul(cur, 0.66) end
    return nil
  end)
  -- Kessel: Rippen + Glut im Schauloch
  P.paintIn(img, g, "boiler", function(x, y, u, v, cur)
    if (x % 5 == 0) then return P.mul(cur, 0.78) end
    return nil
  end)
  P.paintIn(img, g, "track", function(x, y, u, v, cur)
    if (x % 8 < 3) then return P.mul(cur, 0.66) end
    return nil
  end)
  S.rivets(img, g, "wheel", 30, 160, 100, P.c(0xb8c4d0))
  -- Schwachpunkt: Ofen im Rumpf
  weakCore(img, 96.0, cy + 2.0, 12.0, "orange", pulse * 1.4)
  -- Rauch
  local sm = pulse * 3
  for k = 0, 2 do
    S.orb(img, 137.0 + k * 4, 6.0 - k * 6 - sm, 4.0 - k * 0.8,
      { P.c(0x9a9490), P.c(0x7a7470), P.c(0x5a5450), P.c(0x3a3438) }, { hard = false })
  end
  P.glint(img, 60, 40, P.c(0xe8d8c0), 3)
  img:drawPixel(1, floor(cy + 6), P.c(0xfff0c0))
end
emit({ name = "boss_harvester", w = 184, h = 128, frames = 2, fps = 6, draw = drawBossHarvester })

-- ------------------------------------------------------------ BOSS_QUEEN 176x136
local function drawBossQueen(img, f)
  local W, H = 176, 136
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cy = 74.0
  -- Flügel (zwei Paare, halbtransparent)
  local wings = {
    { x0 = 54.0, y0 = cy - 18.0, x1 = 30.0, y1 = 4.0, cx = 16.0, cy = 24.0, w = 16.0, label = "wing_b" },
    { x0 = 66.0, y0 = cy - 20.0, x1 = 74.0, y1 = 2.0, cx = 48.0, cy = 18.0, w = 18.0, label = "wing_f" },
  }
  for _, w in ipairs(wings) do
    w.points = 26; w.root = 0.55; w.tip = 0.3
    S.leaf(g, w)
  end
  -- Beine
  for k = 0, 2 do
    local x = 56.0 + k * 20.0
    P.chain(g, { { x, cy + 26 }, { x - 4, cy + 42 }, { x + 4, cy + 52 } }, 3.4, "leg")
  end
  -- Hinterleib (groß, gestreift)
  P.ellipse(g, 106.0, cy + 14.0, 48.0, 34.0, "abdomen")
  -- Brust mit königlicher Rüstung
  P.ellipse(g, 62.0, cy - 2.0, 27.0, 26.0, "thorax")
  P.rrect(g, 44.0, cy - 20.0, 34.0, 14.0, 4.0, "royal")
  -- Kopf
  P.ellipse(g, 30.0, cy - 12.0, 19.0, 17.0, "head")
  -- Krone (Goldzacken)
  for k = 0, 4 do
    local x = 14.0 + k * 8.0
    S.spike(g, x, cy - 24.0, x + 2.0, cy - 38.0 - (k % 2) * 3.0, 3.0, "crown")
  end
  P.rrect(g, 12.0, cy - 27.0, 34.0, 5.0, 2.0, "crown")
  -- Zepter/Zange
  S.spike(g, 18.0, cy + 4.0, 4.0, cy + 12.0, 2.8, "mand")

  P.render(img, g, {
    regions = {
      abdomen = R_(R.hive, 0.62, { bulge = 1.25, dither = false }),
      thorax = R_(R.chitin, 0.58, { bulge = 1.1, dither = false }),
      royal = R_(R.royal, 0.70, { bulge = 0.85, dither = false }),
      head = R_(R.black_chitin, 0.56, { bulge = 1.05, dither = false }),
      crown = R_(R.gold_trim, 0.74, { bulge = 0.7, dither = false }),
      mand = R_(R.black_chitin, 0.54, { bulge = 0.7, dither = false }),
      leg = R_(R.chitin_dark, 0.52, { bulge = 0.8, dither = false }),
      wing_f = R_(R.wing_amber, 0.82, { bulge = 0.25, alpha = 165, sep = false, dither = false }),
      wing_b = R_(R.wing_amber, 0.70, { bulge = 0.25, alpha = 140, sep = false, dither = false }),
    },
  })
  -- Hinterleibsbinden
  P.bands(img, g, "abdomen", P.c(0x2a1a20), { period = 11, thick = 4, offset = -10 })
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if v < 0.14 then return P.mix(cur, P.c(0xfff0c0), 0.45) end
    if v > 0.90 then return P.mul(cur, 0.66) end
    return nil
  end)
  -- Rüstung: Waben + Kante
  P.paintIn(img, g, "royal", function(x, y, u, v, cur)
    local gx, gy = x % 4, (y + floor(x / 2)) % 4
    if gx == 0 or gy == 0 then return P.mul(cur, 0.72) end
    if v < 0.2 then return P.mix(cur, P.c(0xfff0b0), 0.4) end
    return nil
  end)
  -- Thoraxplatten
  P.paintIn(img, g, "thorax", function(x, y, u, v, cur)
    if (y % 6 == 0) then return P.mul(cur, 0.76) end
    return nil
  end)
  -- Krone glänzt
  P.paintIn(img, g, "crown", function(x, y, u, v, cur)
    if (x + y) % 5 == 0 then return P.c(0xfff6c0) end
    return nil
  end)
  -- Augen + Schwachpunkt
  P.eye(img, g, 32.0, cy - 14.0, 6.0, 6.5, { label = "head", core = P.c(0x2a0a10),
    mid = P.c(0x8a1a2a), rim = P.c(0xe04a4a) })
  weakCore(img, 62.0, cy + 0.0, 9.0, "yellow", pulse * 1.3)
  S.wingDetail(img, g, "wing_f", wings[2], { count = 3, veins = P.rgba(190, 160, 100, 200) })
  S.wingDetail(img, g, "wing_b", wings[1], { count = 3, veins = P.rgba(190, 160, 100, 190) })
  P.glint(img, 96, cy - 6, P.c(0xfff6c0), 4)
  img:drawPixel(19, floor(cy - 40), P.c(0xfff6c0))
end
emit({ name = "boss_queen", w = 176, h = 136, frames = 2, fps = 6, draw = drawBossQueen })

-- ------------------------------------------------------------- BOSS_CORE 176x144
local function drawBossCore(img, f)
  local W, H = 176, 144
  local pulse = (f == 2) and 1 or 0
  local g = P.grid(W, H)
  local cx, cy = 88.0, 72.0
  -- Sechseck-Rahmen
  local hex = {}
  for k = 0, 5 do
    local a = k * pi / 3 + pi / 6
    hex[#hex + 1] = { cx + cos(a) * 62.0, cy + sin(a) * 58.0 }
  end
  P.poly(g, hex, "frame")
  -- Pylonen an den Ecken
  for k = 0, 5 do
    local a = k * pi / 3 + pi / 6
    P.rrect(g, cx + cos(a) * 60.0 - 7.0, cy + sin(a) * 56.0 - 7.0, 14.0, 14.0, 3.0, "pylon")
  end
  -- Kugel
  P.ellipse(g, cx, cy, 40.0, 40.0, "ball")
  -- Ringe (schräg)
  S.ring(g, cx, cy, 52.0, 20.0, 46.0, 14.0, "ring")
  S.ring(g, cx, cy, 22.0, 52.0, 15.0, 44.0, "ring")
  -- Zentralauge
  P.ellipse(g, cx - 4.0, cy, 22.0, 24.0, "lens")

  P.render(img, g, {
    regions = {
      frame = R_(R.gunmetal, 0.54, { bulge = 0.8, dither = false }),
      pylon = R_(R.iron, 0.58, { bulge = 0.9, dither = false }),
      ball = R_(P.ramp(0x6a2a7a, 6), 0.56, { bulge = 1.25, dither = false }),
      ring = R_(R.steel, 0.60, { bulge = 0.6, dither = false }),
      lens = R_(P.ramp(0x3a1030, 5), 0.50, { bulge = 0.9, dither = false }),
    },
  })
  -- Rahmendetails: Panels, Nieten, Kabel
  S.plates(img, g, "frame", 30, 114, P.c(0x1a1a22), P.c(0x9aa8b8), 6)
  S.rivets(img, g, "pylon", 20, 150, 20, P.c(0xc8d4e0))
  P.paintIn(img, g, "frame", function(x, y, u, v, cur)
    if (x % 14 == 0) and y > 24 then return P.mul(cur, 0.7) end
    return nil
  end)
  -- Kugel: Energieadern pulsierend
  P.paintIn(img, g, "ball", function(x, y, u, v, cur)
    local dx, dy = (x - cx) / 40.0, (y - cy) / 40.0
    if dx * dx + dy * dy > 0.92 then return P.mix(cur, P.c(0xc85ae8), 0.45) end
    local q = ((x * 2 + y * 3 + pulse * 3) % 17)
    if q < 3 and dx * dx + dy * dy > 0.35 then return P.mix(cur, P.c(0xef7aff), 0.55) end
    if v < 0.2 then return P.mix(cur, P.c(0xd0a0f0), 0.35) end
    return nil
  end)
  -- Ringe: Lichtkanten
  P.paintIn(img, g, "ring", function(x, y, u, v, cur)
    if v < 0.22 then return P.mix(cur, P.c(0xe8f4ff), 0.40) end
    if v > 0.84 then return P.mul(cur, 0.62) end
    return nil
  end)
  -- Auge / Schwachpunkt
  weakCore(img, cx - 4.0, cy, 14.0, "magenta", pulse * 1.6, { brackets = false })
  -- Iris-Ring
  S.ringWave(img, cx - 4.0, cy, 20.0 + pulse, 2.4,
    { P.c(0xffffff), P.c(0xffd0f0), P.c(0xef2f8e), P.c(0x5a0a2a) }, {})
  -- Kabel zur Rahmenseite
  P.chain(g, { { cx - 30, cy + 30 }, { cx - 52, cy + 40 }, { cx - 60, cy + 24 } }, 2.4, "cable")
  P.chain(g, { { cx + 30, cy + 30 }, { cx + 52, cy + 42 }, { cx + 58, cy + 26 } }, 2.4, "cable")
  P.paintIn(img, g, "cable", function(x, y, u, v, cur)
    if (x + y) % 4 == 0 then return P.mul(cur, 0.7) end
    return nil
  end)
  P.glint(img, 62, 42, P.c(0xfff0ff), 5)
end
emit({ name = "boss_core", w = 176, h = 144, frames = 2, fps = 6, draw = drawBossCore })

--------------------------------------------------------------------------------
-- 7) UI-ICONS (24x24 und 16x16)
--------------------------------------------------------------------------------
local ICON_OUT = P.c(0x141018)
local ICON_GOLD = R.gold_trim
local ICON_AMBER = R.honey

-- Gemeinsamer Abschluss: dunkle Kontur um die gezeichnete Form
local function finishIcon(img, w, h, frameCol)
  local solid = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if P.pix(img, x, y).alpha > 40 then solid[y * w + x] = true end
    end
  end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if not solid[y * w + x] then
        local near = false
        for dy = -1, 1 do
          for dx = -1, 1 do
            local nx, ny = x + dx, y + dy
            if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] then near = true end
          end
        end
        if near then img:drawPixel(x, y, ICON_OUT) end
      end
    end
  end
  if frameCol then
    -- dünner Rahmen (nur Ecken betont), damit Icons im HUD sitzen
    for x = 1, w - 2 do
      img:drawPixel(x, 0, P.rgba(frameCol.red, frameCol.green, frameCol.blue, 110))
    end
  end
end

-- ---------------------------------------------------------- 24x24 Waffen-Icons
local function drawIconBase(img)
  local g = P.grid(24, 24)
  -- diagonaler Energiebolzen
  P.poly(g, { { 2.0, 18.0 }, { 14.0, 4.0 }, { 21.0, 6.0 }, { 21.0, 10.0 }, { 8.0, 20.0 } }, "bolt")
  P.poly(g, { { 15.0, 12.0 }, { 22.0, 12.0 }, { 22.0, 16.0 }, { 13.0, 15.0 } }, "bolt")
  P.render(img, g, { regions = { bolt = R_(ICON_GOLD, 0.66, { bulge = 0.6, outline = ICON_OUT }) } })
  P.paintIn(img, g, "bolt", function(x, y, u, v, cur)
    local d = abs((x) - (y + 2))
    if d < 2 then return P.c(0xfffdf0) end
    if d < 4 then return P.c(0xffd85a) end
    return nil
  end)
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_base", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconBase })

local function drawIconFan(img)
  local g = P.grid(24, 24)
  -- drei Bolzen fächern von links unten
  for k = -1, 1 do
    local a = k * 0.42
    local x0, y0 = 3.0, 20.0
    local x1, y1 = 3.0 + cos(a) * 17.0, 20.0 + sin(a) * 17.0
    S.leaf(g, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, cx = (x0 + x1) / 2 + 2, cy = (y0 + y1) / 2 - 2,
                w = 2.6, label = "b", points = 14, root = 0.6, tip = 0.15 })
  end
  P.render(img, g, { regions = { b = R_(ICON_GOLD, 0.66, { bulge = 0.5, outline = ICON_OUT }) } })
  P.paintIn(img, g, "b", function(x, y, u, v, cur)
    if v > 0.35 and v < 0.72 then return P.c(0xfff6c0) end
    if v <= 0.35 then return P.c(0xffd85a) end
    return nil
  end)
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_fan", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconFan })

local function drawIconLightning(img)
  local g = P.grid(24, 24)
  P.poly(g, { { 14.0, 1.0 }, { 6.0, 13.0 }, { 11.0, 13.0 }, { 8.0, 23.0 },
              { 19.0, 9.0 }, { 13.0, 9.0 }, { 18.0, 1.0 } }, "z")
  P.render(img, g, { regions = { z = R_(P.ramp(0x8fc8f0, 4), 0.72, { bulge = 0.45, outline = ICON_OUT }) } })
  P.paintIn(img, g, "z", function(x, y, u, v, cur)
    if u < 0.42 then return P.c(0xfffdf0) end
    if u < 0.62 then return P.c(0xd8f0ff) end
    return P.c(0x6aa8d8)
  end)
  -- kleiner Funke
  img:drawPixel(19, 17, P.c(0xf0faff))
  img:drawPixel(6, 4, P.c(0xf0faff))
  finishIcon(img, 24, 24, P.c(0x6aa8d8))
end
emit({ name = "icon_lightning", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconLightning })

local function drawIconPlasma(img)
  local g = P.grid(24, 24)
  P.ellipse(g, 12.0, 12.0, 7.6, 7.6, "orb")
  P.render(img, g, { regions = { orb = R_(P.ramp(0x7a4ae0, 5), 0.66, { bulge = 1.1, outline = ICON_OUT }) } })
  -- Plasmakern + Ring
  S.orb(img, 12.0, 12.0, 5.4, { P.c(0xffffff), P.c(0xe8d0ff), P.c(0xa87ae8), P.c(0x4a2e7a) }, { hard = true })
  S.ringWave(img, 12.0, 12.0, 9.6, 1.6, { P.c(0xffffff), P.c(0xd0b0ff), P.c(0x8a5ae0), P.c(0x3a2060) },
    { squash = 1.0 })
  img:drawPixel(8, 8, P.c(0xffffff))
  finishIcon(img, 24, 24, P.c(0x8a5ae0))
end
emit({ name = "icon_plasma", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconPlasma })

local function drawIconCompanion(img)
  local g = P.grid(24, 24)
  -- kleine Biene (Begleiter)
  local wings = {
    { x0 = 11.0, y0 = 9.0, x1 = 5.0, y1 = 2.0, cx = 3.0, cy = 5.0, w = 3.4, label = "w" },
    { x0 = 13.0, y0 = 9.0, x1 = 19.0, y1 = 2.0, cx = 21.0, cy = 5.0, w = 3.4, label = "w" },
  }
  for _, w in ipairs(wings) do
    w.points = 14; w.root = 0.5; w.tip = 0.2
    S.leaf(g, w)
  end
  P.ellipse(g, 12.0, 15.0, 5.4, 4.6, "body")
  P.ellipse(g, 12.0, 9.0, 3.2, 2.8, "head")
  P.render(img, g, {
    regions = {
      body = R_(ICON_AMBER, 0.66, { bulge = 1.1, outline = ICON_OUT }),
      head = R_(R.black_chitin, 0.60, { outline = ICON_OUT }),
      w = R_(R.wing_amber, 0.86, { bulge = 0.25, alpha = 200, sep = false, outline = P.c(0xd8c8a0) }),
    },
  })
  P.bands(img, g, "body", P.c(0x241a22), { period = 3, thick = 1, offset = -2 })
  P.eye(img, g, 13.0, 8.6, 1.8, 1.8, { label = "head", core = P.c(0x2a1020),
    mid = P.c(0x8a4ae0), rim = P.c(0xc8a0ff), glint = P.c(0xffffff) })
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_companion", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconCompanion })

local function drawIconBombs(img)
  local g = P.grid(24, 24)
  P.ellipse(g, 11.0, 15.0, 7.0, 6.6, "bomb")
  P.rect(g, 9, 7, 4, 3, "cap")
  P.chain(g, { { 12.0, 7.0 }, { 15.0, 4.0 }, { 19.0, 5.0 } }, 0.9, "fuse")
  P.render(img, g, {
    regions = {
      bomb = R_(P.ramp(0x3a3a48, 5), 0.62, { bulge = 1.15, outline = ICON_OUT }),
      cap = R_(ICON_GOLD, 0.66, { outline = ICON_OUT }),
      fuse = R_(R.brass, 0.60, { outline = ICON_OUT, dither = false }),
    },
  })
  P.glint(img, 8, 12, C.hot_white, 2)
  img:drawPixel(15, 14, P.mix(P.c(0xfff2a8), C.hot_white, 0.5))
  S.orb(img, 19.5, 4.6, 2.4, { P.c(0xffffff), P.c(0xffe08a), P.c(0xff9a2a), P.c(0x8a3a10) }, { hard = true })
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_bombs", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconBombs })

local function drawIconShield(img)
  local g = P.grid(24, 24)
  P.poly(g, { { 12.0, 1.5 }, { 21.5, 6.0 }, { 21.5, 13.0 }, { 12.0, 22.5 },
              { 2.5, 13.0 }, { 2.5, 6.0 } }, "sh")
  P.render(img, g, { regions = { sh = R_(P.ramp(0x3a7ab0, 5), 0.62, { bulge = 1.0, outline = ICON_OUT }) } })
  -- Wappen + Kante
  P.paintIn(img, g, "sh", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "sh" then return P.mix(cur, P.c(0xd8f0ff), 0.45) end
    if v > 0.86 then return P.mul(cur, 0.7) end
    return nil
  end)
  S.orb(img, 12.0, 11.0, 4.4, { P.c(0xffffff), P.c(0xd8f0ff), P.c(0x4ab0e0), P.c(0x1a4a72) }, { hard = true })
  img:drawPixel(10, 9, P.c(0xffffff))
  finishIcon(img, 24, 24, P.c(0x4ab0e0))
end
emit({ name = "icon_shield", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconShield })

local function drawIconSpeed(img)
  local g = P.grid(24, 24)
  -- drei Winkel-Pfeile (Chevrons) + Flügel
  for k = 0, 2 do
    local x = 1.0 + k * 6.5
    P.poly(g, { { x, 6.0 }, { x + 6.0, 6.0 }, { x + 6.0, 10.5 }, { x + 3.2, 12.0 },
                { x + 6.0, 13.5 }, { x + 6.0, 18.0 }, { x, 18.0 } }, "ar")
  end
  S.leaf(g, { x0 = 15.0, y0 = 13.0, x1 = 22.5, y1 = 4.0, cx = 18.0, cy = 4.5, w = 2.4,
              label = "wg", points = 12, root = 0.5, tip = 0.2 })
  P.render(img, g, {
    regions = {
      ar = R_(ICON_GOLD, 0.66, { bulge = 0.45, outline = ICON_OUT }),
      wg = R_(R.wing_amber, 0.88, { bulge = 0.2, alpha = 220, sep = false, outline = P.c(0xd8c8a0) }),
    },
  })
  P.paintIn(img, g, "ar", function(x, y, u, v, cur)
    if v < 0.28 then return P.c(0xfff6c0) end
    if v > 0.74 then return P.c(0xa87a12) end
    return nil
  end)
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_speed", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconSpeed })

local function drawIconRepair(img)
  local g = P.grid(24, 24)
  -- Schraubenschlüssel
  P.chain(g, { { 6.0, 19.0 }, { 13.0, 11.0 }, { 17.0, 7.0 } }, 2.8, "wr", 0.7)
  P.ellipse(g, 17.5, 6.5, 4.2, 4.2, "wr")
  P.ellipse(g, 17.5, 6.5, 1.8, 1.8, "hole")
  -- Honigtropfen daneben (Reparatur = Heilung)
  P.ellipse(g, 8.5, 6.0, 3.0, 3.2, "drop")
  S.spike(g, 8.5, 1.6, 8.5, 4.0, 1.6, "drop")
  P.render(img, g, {
    regions = {
      wr = R_(R.steel, 0.62, { bulge = 0.7, outline = ICON_OUT }),
      hole = R_(P.ramp(0x141018, 2), 0.4, { bulge = 0.5, outline = ICON_OUT, dither = false }),
      drop = R_(ICON_AMBER, 0.70, { bulge = 1.1, outline = ICON_OUT }),
    },
  })
  P.paintIn(img, g, "wr", function(x, y, u, v, cur)
    if u < 0.35 then return P.mix(cur, P.c(0xe8f4ff), 0.45) end
    return nil
  end)
  P.glint(img, 7, 5, C.hot_white, 1)
  finishIcon(img, 24, 24, ICON_GOLD[4])
end
emit({ name = "icon_repair", w = 24, h = 24, frames = 1, fps = 8, draw = drawIconRepair })

-- ---------------------------------------------------------- 16x16 HUD-Icons
local function drawIconHP(img)
  local g = P.grid(16, 16)
  P.ellipse(g, 5.4, 6.0, 4.0, 3.6, "h")
  P.ellipse(g, 10.6, 6.0, 4.0, 3.6, "h")
  P.poly(g, { { 1.4, 7.0 }, { 14.6, 7.0 }, { 8.0, 14.6 } }, "h")
  P.render(img, g, { regions = { h = R_(P.ramp(0xe83a5a, 5), 0.66, { bulge = 1.1, outline = ICON_OUT }) } })
  img:drawPixel(5, 5, C.hot_white); img:drawPixel(6, 5, P.c(0xffd0d8))
  img:drawPixel(4, 6, P.c(0xffb0c0))
  finishIcon(img, 16, 16, P.c(0xe83a5a))
end
emit({ name = "icon_hp", w = 16, h = 16, frames = 1, fps = 8, draw = drawIconHP })

local function drawIconNectar(img)
  local g = P.grid(16, 16)
  P.ellipse(g, 8.0, 9.6, 5.0, 4.8, "d")
  S.spike(g, 8.0, 1.4, 8.0, 6.0, 2.4, "d")
  P.render(img, g, { regions = { d = R_(ICON_AMBER, 0.70, { bulge = 1.15, outline = ICON_OUT }) } })
  img:drawPixel(5, 8, C.hot_white); img:drawPixel(6, 8, P.c(0xfff6c0))
  img:drawPixel(5, 9, P.c(0xffe08a))
  finishIcon(img, 16, 16, ICON_GOLD[4])
end
emit({ name = "icon_nectar", w = 16, h = 16, frames = 1, fps = 8, draw = drawIconNectar })

local function drawIconShieldBar(img)
  local g = P.grid(16, 16)
  P.poly(g, { { 8.0, 1.0 }, { 14.4, 4.4 }, { 14.4, 9.0 }, { 8.0, 15.0 },
              { 1.6, 9.0 }, { 1.6, 4.4 } }, "sh")
  P.render(img, g, { regions = { sh = R_(P.ramp(0x3a7ab0, 4), 0.62, { bulge = 1.0, outline = ICON_OUT }) } })
  P.paintIn(img, g, "sh", function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= "sh" then return P.mix(cur, P.c(0xd8f0ff), 0.5) end
    return nil
  end)
  -- Füllstands-Balken
  for y = 5, 12 do
    for x = 4, 12 do
      if P.getp(g, x, y) == "sh" then
        img:drawPixel(x, y, (y <= 8) and P.c(0x8fe0ff) or P.c(0x1a4a72))
      end
    end
  end
  finishIcon(img, 16, 16, P.c(0x4ab0e0))
end
emit({ name = "icon_shieldbar", w = 16, h = 16, frames = 1, fps = 8, draw = drawIconShieldBar })

local function drawIconAutofire(img)
  local g = P.grid(16, 16)
  -- zwei Geschosse + Pfeilschleife
  S.leaf(g, { x0 = 3.0, y0 = 11.0, x1 = 13.0, y1 = 11.0, cx = 8.0, cy = 9.0, w = 2.2,
              label = "b", points = 12, root = 0.6, tip = 0.3 })
  S.leaf(g, { x0 = 3.0, y0 = 7.0, x1 = 11.0, y1 = 7.0, cx = 7.0, cy = 5.0, w = 1.8,
              label = "b", points = 12, root = 0.6, tip = 0.3 })
  P.chain(g, { { 13.0, 2.6 }, { 15.0, 6.0 }, { 12.0, 8.5 } }, 1.0, "ar")
  P.render(img, g, {
    regions = {
      b = R_(ICON_GOLD, 0.70, { bulge = 0.5, outline = ICON_OUT }),
      ar = R_(P.ramp(0x9ad8f0, 3), 0.70, { bulge = 0.4, outline = ICON_OUT, dither = false }),
    },
  })
  P.paintIn(img, g, "b", function(x, y, u, v, cur)
    if v > 0.42 and v < 0.72 then return P.c(0xfffdf0) end
    return nil
  end)
  finishIcon(img, 16, 16, ICON_GOLD[4])
end
emit({ name = "icon_autofire", w = 16, h = 16, frames = 1, fps = 8, draw = drawIconAutofire })

--------------------------------------------------------------------------------
-- 8) LOGO (480x120, Pixel-Schrift) und SPIEL-ICON (128x128)
--------------------------------------------------------------------------------
-- 5x7-Pixelschrift für die benötigten Buchstaben
local GLY = {
  A = { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
  P = { "####.", "#...#", "#...#", "####.", "#....", "#....", "#...." },
  I = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####" },
  D = { "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." },
  Y = { "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.." },
  R = { "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#" },
  E = { "#####", "#....", "#....", "####.", "#....", "#....", "#####" },
  M = { "#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#" },
  G = { ".###.", "#...#", "#....", "#..##", "#...#", "#...#", ".###." },
  N = { "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#" },
  [" "] = { ".....", ".....", ".....", ".....", ".....", ".....", "....." },
}

local function stampText(mask, W, H, text, scale, x0, y0)
  for i = 1, #text do
    local rows = GLY[text:sub(i, i)]
    if rows then
      local gx = x0 + (i - 1) * 6 * scale
      for r = 1, 7 do
        local line = rows[r]
        for c = 1, 5 do
          if line:sub(c, c) == "#" then
            for dy = 0, scale - 1 do
              for dx = 0, scale - 1 do
                local px, py = gx + (c - 1) * scale + dx, y0 + (r - 1) * scale + dy
                if px >= 0 and py >= 0 and px < W and py < H then mask[py * W + px] = true end
              end
            end
          end
        end
      end
    end
  end
end

local function textWidth(text, scale)
  return (#text * 6 - 1) * scale
end

local function drawLogo(img)
  local W, H = 480, 120
  local mask = {}
  local s1, s2 = 8, 5
  local t1, t2 = "APIDYA", "REIMAGINED"
  local w1, w2 = textWidth(t1, s1), textWidth(t2, s2)
  local x1 = floor((W - w1) / 2)
  local x2 = floor((W - w2) / 2)
  stampText(mask, W, H, t1, s1, x1, 8)
  stampText(mask, W, H, t2, s2, x2, 76)

  local function solid(x, y)
    if x < 0 or y < 0 or x >= W or y >= H then return false end
    return mask[y * W + x] == true
  end

  -- Schlagschatten (3px versetzt)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if solid(x - 3, y - 3) and not solid(x, y) then
        img:drawPixel(x, y, P.rgba(8, 5, 10, 165))
      end
    end
  end
  -- dunkle Kontur (3..1 px)
  for d = 3, 1, -1 do
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        if not solid(x, y) then
          local near = false
          for dy = -d, d do
            for dx = -d, d do
              if solid(x + dx, y + dy) then near = true end
            end
          end
          if near then
            img:drawPixel(x, y, (d == 1) and P.c(0x2e1c10) or P.c(0x1a0e10))
          end
        end
      end
    end
  end
  -- Füllung: Honig-Gold mit hellem Oberlicht und sattem Fuß
  local ramp = P.ramp(0xffc926, 6)
  for y = 0, H - 1 do
    -- Verlauf unabhängig pro Zeile: innerhalb der Zeile oben hell
    for x = 0, W - 1 do
      if solid(x, y) then
        -- Verlauf über die gesamte Wortzeile (oben hell, unten satt)
        local t = (y <= 64) and ((y - 8) / 56.0) or ((y - 76) / 34.0)
        local idx = 6 - floor(t * 4.0)
        if idx < 2 then idx = 2 elseif idx > 6 then idx = 6 end
        local col = ramp[idx]
        if not solid(x, y + 1) then col = P.mul(col, 0.55) end
        if not solid(x - 1, y) then col = P.mul(col, 0.86) end
        img:drawPixel(x, y, col)
      end
    end
  end
  -- Trennlinie zwischen Titel und Untertitel
  local yl = 70
  for x = x2, x2 + w2 - 1 do
    if x % 3 ~= 0 then
      img:drawPixel(x, yl, P.c(0xc8a03a))
      img:drawPixel(x, yl + 1, P.c(0x6a4a10))
    end
  end
  -- Zierpunkte (Bienen-Glut) an den Enden
  S.orb(img, x2 - 6, yl, 3.0, { P.c(0xffffff), P.c(0xffe08a), P.c(0xf2b81c), P.c(0x8a5a10) }, { hard = true })
  S.orb(img, x2 + w2 + 5, yl, 3.0, { P.c(0xffffff), P.c(0xffe08a), P.c(0xf2b81c), P.c(0x8a5a10) }, { hard = true })
end
emit({ name = "logo", w = 480, h = 120, frames = 1, fps = 8, draw = drawLogo })

local function drawGameIcon(img)
  local W, H = 128, 128
  local cx, cy = 64.0, 64.0
  -- Hintergrund: runde Honigwabe mit dunklem Rand
  local g = P.grid(W, H)
  P.ellipse(g, cx, cy, 62.0, 62.0, "bg")
  P.render(img, g, { regions = { bg = R_(P.ramp(0x8a5a10, 6), 0.55, { bulge = 1.4, outline = P.c(0x140c08) }) } })
  -- Wabenmuster im Hintergrund
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local dx, dy = (x - cx) / 62.0, (y - cy) / 62.0
      if dx * dx + dy * dy < 0.94 then
        local hx = (x + floor(y / 2) * 1) % 18
        if hx < 1 or (y % 16 < 1) then
          img:drawPixel(x, y, P.rgba(255, 216, 120, 42))
        end
      end
    end
  end
  -- Flügel (eigene Maske, damit der Hintergrund nicht neu gerendert wird)
  local g2 = P.grid(W, H)
  g = g2
  local wings = {
    { x0 = 60.0, y0 = 52.0, x1 = 12.0, y1 = 12.0, cx = 14.0, cy = 30.0, w = 15.0, label = "w" },
    { x0 = 68.0, y0 = 52.0, x1 = 116.0, y1 = 12.0, cx = 114.0, cy = 30.0, w = 15.0, label = "w" },
  }
  for _, w in ipairs(wings) do
    w.points = 22; w.root = 0.5; w.tip = 0.25
    S.leaf(g, w)
  end
  -- Körper: Hinterleib, Brust, Kopf
  P.ellipse(g, 64.0, 86.0, 27.0, 25.0, "abdomen")
  P.ellipse(g, 64.0, 56.0, 21.0, 19.0, "thorax")
  P.ellipse(g, 64.0, 32.0, 15.0, 14.0, "head")
  -- Beine
  for k = 0, 1 do
    P.chain(g, { { 46.0 + k * 6, 62.0 }, { 36.0 + k * 4, 76.0 }, { 40.0 + k * 6, 88.0 } }, 3.0, "leg")
    P.chain(g, { { 82.0 - k * 6, 62.0 }, { 92.0 - k * 4, 76.0 }, { 88.0 - k * 6, 88.0 } }, 3.0, "leg")
  end
  -- Fühler
  P.chain(g, { { 58.0, 22.0 }, { 50.0, 8.0 }, { 40.0, 6.0 } }, 1.8, "leg")
  P.chain(g, { { 70.0, 22.0 }, { 78.0, 8.0 }, { 88.0, 6.0 } }, 1.8, "leg")
  -- Fühlerspitzen
  P.setp(g, 39, 6, "leg"); P.setp(g, 89, 6, "leg")

  P.render(img, g, {
    regions = {
      w = R_(R.wing_amber, 0.86, { bulge = 0.25, alpha = 205, sep = false, outline = P.c(0xd8b060) }),
      abdomen = R_(R.amber5, 0.64, { bulge = 1.2, outline = P.c(0x140c08) }),
      thorax = R_(R.chitin, 0.60, { bulge = 1.1, outline = P.c(0x140c08) }),
      head = R_(R.chitin, 0.60, { bulge = 1.05, outline = P.c(0x140c08) }),
      leg = R_(R.chitin_dark, 0.52, { bulge = 0.8, outline = P.c(0x140c08), dither = false }),
    },
  })
  -- Streifen, Augen, Details
  P.bands(img, g, "abdomen", P.c(0x201620), { period = 9, thick = 4, offset = -6 })
  P.paintIn(img, g, "abdomen", function(x, y, u, v, cur)
    if v < 0.16 then return P.mix(cur, P.c(0xfff0b0), 0.45) end
    if v > 0.88 then return P.mul(cur, 0.62) end
    return nil
  end)
  P.paintIn(img, g, "thorax", function(x, y, u, v, cur)
    if v < 0.2 then return P.mix(cur, P.c(0xe8c890), 0.35) end
    return nil
  end)
  P.eye(img, g, 57.0, 31.0, 5.6, 6.0, { label = "head", core = P.c(0x2a0a20),
    mid = P.c(0x7a3ae0), rim = P.c(0xc8a0ff) })
  P.eye(img, g, 71.0, 31.0, 5.6, 6.0, { label = "head", core = P.c(0x2a0a20),
    mid = P.c(0x7a3ae0), rim = P.c(0xc8a0ff) })
  S.wingDetail(img, g, "w", wings[1], { count = 4, veins = P.rgba(150, 120, 70, 190) })
  S.wingDetail(img, g, "w", wings[2], { count = 4, veins = P.rgba(150, 120, 70, 190) })
  P.glint(img, 54, 44, P.c(0xfff6d0), 4)
  -- Stachel
  S.spike(g, 64.0, 108.0, 64.0, 118.0, 3.4, "abdomen")
  -- Randglanz des Wappens
  S.ringWave(img, cx, cy, 60.0, 2.6, { P.c(0xffe89a), P.c(0xffc04a), P.c(0xa87a12), P.c(0x5a3a0a) }, {})
end
emit({ name = "icon", w = 128, h = 128, frames = 1, fps = 8, draw = drawGameIcon })

--------------------------------------------------------------------------------
-- Manifest
--------------------------------------------------------------------------------
local function writeManifest()
  local names = {}
  for k in pairs(MANIFEST) do names[#names + 1] = k end
  table.sort(names)
  local out = { "{" }
  for i, name in ipairs(names) do
    local m = MANIFEST[name]
    out[#out + 1] = string.format('  "%s": { "w": %d, "h": %d, "frames": %d, "fps": %d }%s',
      name, m.w, m.h, m.frames, m.fps, (i < #names) and "," or "")
  end
  out[#out + 1] = "}"
  local fh = io.open(ROOT .. "assets/sprites/manifest.json", "w")
  fh:write(table.concat(out, "\n") .. "\n")
  fh:close()
end

-- Reihenfolge für den Kontaktbogen merken
local function writeOrder()
  local fh = io.open(ROOT .. "assets/sprites/_order.txt", "w")
  for _, n in ipairs(ORDER) do fh:write(n .. "\n") end
  fh:close()
end

if ONLY == nil or ONLY == "" then
  writeManifest()
  writeOrder()
  print(string.format("Manifest: %d Sprites", #ORDER))
end
