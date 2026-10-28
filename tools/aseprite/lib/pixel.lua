--[[
  pixel.lua -- Zeichen-Engine fuer "Apidya Reimagined"
  -----------------------------------------------
  Erzeugt volumetrisch schattierte Pixelart ohne Rauschtexturen:
    1. Silhouette wird als Label-Grid (Masken) aufgebaut (Ellipsen, Kapseln, Polygone).
    2. Pro Label wird ein Distanzfeld berechnet -> Kanten-/Woelbungsschattierung
       (Normalen aus dem Gradienten, Licht oben links, Hue-Shift-Rampe).
    3. Details (Streifen, Augen, Panels, Glanzpunkte) werden maskiert aufgetragen.
    4. Aussenkontur wird 1px um die Silhouette in die Transparenz gezeichnet.

  Alle Funktionen sind rein deterministisch (kein math.random ohne Seed).
]]

local P = {}

--------------------------------------------------------------------------------
-- Basis-Helfer
--------------------------------------------------------------------------------
local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt

function P.clamp(v, a, b)
  if v < a then return a elseif v > b then return b else return v end
end

local function lerp(a, b, t) return a + (b - a) * t end
P.lerp = lerp

function P.smoothstep(e0, e1, x)
  local t = P.clamp((x - e0) / (e1 - e0), 0, 1)
  return t * t * (3 - 2 * t)
end

--------------------------------------------------------------------------------
-- Farbe
--------------------------------------------------------------------------------
function P.hex(h)
  if type(h) == "number" then
    -- 0xRRGGBB als Zahl erlaubt (haeufigste Schreibweise in den Definitionen)
    h = string.format("%06X", h % 0x1000000)
  end
  h = tostring(h):gsub("#", "")
  local r = tonumber(h:sub(1, 2), 16) or 0
  local g = tonumber(h:sub(3, 4), 16) or 0
  local b = tonumber(h:sub(5, 6), 16) or 0
  local a = 255
  if #h >= 8 then a = tonumber(h:sub(7, 8), 16) or 255 end
  return r, g, b, a
end

function P.c(h, alpha)
  local r, g, b, a = P.hex(h)
  return Color(r, g, b, alpha or a)
end

function P.rgba(r, g, b, a)
  return Color(
    P.clamp(floor(r + 0.5), 0, 255),
    P.clamp(floor(g + 0.5), 0, 255),
    P.clamp(floor(b + 0.5), 0, 255),
    P.clamp(floor((a == nil) and 255 or a + 0.5), 0, 255))
end

function P.rgb2hsv(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = max(r, g, b), min(r, g, b)
  local h, s, v = 0, 0, mx
  local d = mx - mn
  if mx > 0 then s = d / mx end
  if d > 0 then
    if mx == r then h = ((g - b) / d) % 6
    elseif mx == g then h = ((b - r) / d) + 2
    else h = ((r - g) / d) + 4 end
    h = h / 6
  end
  return h, s, v
end

function P.hsv2rgb(h, s, v)
  h = h % 1
  local i = floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local r, g, b
  i = i % 6
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return r * 255, g * 255, b * 255
end

function P.mix(c1, c2, t)
  return P.rgba(c1.red + (c2.red - c1.red) * t,
                c1.green + (c2.green - c1.green) * t,
                c1.blue + (c2.blue - c1.blue) * t,
                c1.alpha + (c2.alpha - c1.alpha) * t)
end

function P.mul(c, k)
  return P.rgba(c.red * k, c.green * k, c.blue * k, c.alpha)
end

-- Pixel lesen und als Color zurueckgeben (Aseprite liefert je nach Version
-- ein gepacktes Integer 0xAABBGGRR statt eines Color-Objekts).
function P.pix(img, x, y)
  local v = img:getPixel(x, y)
  if type(v) == "number" then
    local r = v & 0xFF
    local g = (v >> 8) & 0xFF
    local b = (v >> 16) & 0xFF
    local a = (v >> 24) & 0xFF
    return P.rgba(r, g, b, a)
  end
  return v
end

function P.shade(c, k, huecool)
  -- k<1 dunkler; optional kuehlen (blau Richtung)
  local r, g, b = c.red * k, c.green * k, c.blue * k
  if huecool then
    local h, s, v = P.rgb2hsv(r, g, b)
    h = (h + 0.008) % 1
    r, g, b = P.hsv2rgb(h, min(1, s + 0.12), v)
  end
  return P.rgba(r, g, b, c.alpha)
end

--[[ Rampe: n Stufen von dunkel (1) nach hell (n).
     Schatten kuehlen + saettigen, Lichter waermen. Index-Mitte == Grundfarbe. ]]
function P.ramp(basehex, n, opt)
  opt = opt or {}
  n = n or 4
  local r, g, b = P.hex(basehex)
  local h, s, v = P.rgb2hsv(r, g, b)
  local lo = opt.lo or 0.30
  local hi = opt.hi or 0.26
  local sh = opt.shadow_hue or 0.035   -- Hue-Rotation kuehl (Anteil des Farbkreises)
  local lh = opt.light_hue or 0.030    -- Hue-Rotation warm
  local ss = opt.sat_shadow or 0.22
  local sl = opt.sat_light or -0.10
  local out = {}
  for i = 1, n do
    local t = (n == 1) and 0.5 or (i - 1) / (n - 1) -- 0 dunkel .. 1 hell
    local vv = P.clamp(v - lo * (1 - t) + hi * t, 0.03, 1.0)
    local hh, sss
    if t < 0.5 then
      local k = 1 - t * 2
      hh = h - sh * k
      sss = P.clamp(s + ss * k, 0, 1)
    else
      local k = (t - 0.5) * 2
      hh = h + lh * k
      sss = P.clamp(s + sl * k, 0, 1)
    end
    local rr, gg, bb = P.hsv2rgb(hh % 1, sss, vv)
    out[i] = P.rgba(rr, gg, bb)
  end
  return out
end

-- Eine Rampe kuenstlich aufhellen/abdunkeln (fuer Konturvarianten)
function P.rampScale(ramp, k)
  local out = {}
  for i = 1, #ramp do out[i] = P.mul(ramp[i], k) end
  return out
end

--------------------------------------------------------------------------------
-- Grid / Masken
--------------------------------------------------------------------------------
function P.grid(w, h)
  return { w = w, h = h, d = {} }
end

function P.setp(g, x, y, label)
  x, y = floor(x), floor(y)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
  g.d[y * g.w + x + 1] = label
end

function P.getp(g, x, y)
  x, y = floor(x), floor(y)
  if x < 0 or y < 0 or x >= g.w or y >= g.h then return nil end
  return g.d[y * g.w + x + 1]
end

function P.clearLabel(g, label)
  for i = 1, g.w * g.h do
    if g.d[i] == label then g.d[i] = nil end
  end
end

function P.ellipse(g, cx, cy, rx, ry, label)
  cx, cy = cx + 0.5, cy + 0.5
  rx, ry = max(0.5, rx), max(0.5, ry)
  for y = floor(cy - ry) - 1, floor(cy + ry) + 1 do
    for x = floor(cx - rx) - 1, floor(cx + rx) + 1 do
      local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if dx * dx + dy * dy <= 1.0 then P.setp(g, x, y, label) end
    end
  end
end

function P.rect(g, x0, y0, w, h, label)
  for y = floor(y0), floor(y0 + h - 1) do
    for x = floor(x0), floor(x0 + w - 1) do P.setp(g, x, y, label) end
  end
end

function P.rrect(g, x0, y0, w, h, r, label)
  -- abgerundetes Rechteck ueber Distanz zum Innenrechteck
  local cx0, cy0 = x0 + r, y0 + r
  local cx1, cy1 = x0 + w - 1 - r, y0 + h - 1 - r
  for y = floor(y0), floor(y0 + h - 1) do
    for x = floor(x0), floor(x0 + w - 1) do
      local qx = (x < cx0) and (cx0 - x) or ((x > cx1) and (x - cx1) or 0)
      local qy = (y < cy0) and (cy0 - y) or ((y > cy1) and (y - cy1) or 0)
      if qx * qx + qy * qy <= r * r + 0.001 then P.setp(g, x, y, label) end
    end
  end
end

local function segDist(px, py, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local l2 = dx * dx + dy * dy
  local t = 0
  if l2 > 0 then t = P.clamp(((px - x1) * dx + (py - y1) * dy) / l2, 0, 1) end
  local qx, qy = x1 + t * dx - px, y1 + t * dy - py
  return sqrt(qx * qx + qy * qy), t
end
P.segDist = segDist

-- Kapsel/Knochen: dicker Strich mit runden Enden (Beine, Fuehler, Rohre)
function P.capsule(g, x1, y1, x2, y2, r, label)
  local x0 = floor(min(x1, x2) - r - 1); local x3 = floor(max(x1, x2) + r + 1)
  local y0 = floor(min(y1, y2) - r - 1); local y3 = floor(max(y1, y2) + r + 1)
  for y = y0, y3 do
    for x = x0, x3 do
      local d = segDist(x + 0.5, y + 0.5, x1 + 0.5, y1 + 0.5, x2 + 0.5, y2 + 0.5)
      if d <= r then P.setp(g, x, y, label) end
    end
  end
end

-- Polylinie aus Kapseln (Gliedmassen, Ranken)
function P.chain(g, pts, r, label, taper)
  local n = #pts
  for i = 1, n - 1 do
    local a, b = pts[i], pts[i + 1]
    local rr = r
    if taper then rr = r * (1 - taper * (i - 1) / max(1, n - 1)) end
    P.capsule(g, a[1], a[2], b[1], b[2], max(0.6, rr), label)
  end
end

-- Polygon (even-odd scanline), pts = {{x,y},...}
function P.poly(g, pts, label)
  local n = #pts
  local ymin, ymax = 1e9, -1e9
  for i = 1, n do
    ymin = min(ymin, pts[i][2]); ymax = max(ymax, pts[i][2])
  end
  for y = floor(ymin), floor(ymax) do
    local yc = y + 0.5
    local xs = {}
    for i = 1, n do
      local a, b = pts[i], pts[(i % n) + 1]
      local ay, by = a[2] + 0.5, b[2] + 0.5
      if (ay <= yc and by > yc) or (by <= yc and ay > yc) then
        local t = (yc - ay) / (by - ay)
        xs[#xs + 1] = a[1] + 0.5 + t * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = floor(xs[i] + 0.5), floor(xs[i + 1] - 0.5) do P.setp(g, x, y, label) end
    end
  end
end

-- Spiegelung: alles was links von axisX liegt nach rechts gespiegelt hinzufuegen
function P.mirror(g, axisX, label)
  for y = 0, g.h - 1 do
    for x = 0, floor(axisX) do
      local l = P.getp(g, x, y)
      if l == label then
        local mx = floor(2 * axisX - x)
        if P.getp(g, mx, y) == nil or P.getp(g, mx, y) == label then
          P.setp(g, mx, y, label)
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Distanzfeld (Chamfer 3-4)
--------------------------------------------------------------------------------
local function distfield(g, pred)
  local w, h = g.w, g.h
  local d = {}
  local INF = 1e9
  for i = 1, w * h do d[i] = pred(i) and INF or 0 end
  local D1, D2 = 1.0, 1.41421356
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local i = y * w + x + 1
      if d[i] > 0 then
        local v = d[i]
        if x > 0 then v = min(v, d[i - 1] + D1) end
        if y > 0 then
          v = min(v, d[i - w] + D1)
          if x > 0 then v = min(v, d[i - w - 1] + D2) end
          if x < w - 1 then v = min(v, d[i - w + 1] + D2) end
        end
        d[i] = v
      end
    end
  end
  for y = h - 1, 0, -1 do
    for x = w - 1, 0, -1 do
      local i = y * w + x + 1
      if d[i] > 0 then
        local v = d[i]
        if x < w - 1 then v = min(v, d[i + 1] + D1) end
        if y < h - 1 then
          v = min(v, d[i + w] + D1)
          if x < w - 1 then v = min(v, d[i + w + 1] + D2) end
          if x > 0 then v = min(v, d[i + w - 1] + D2) end
        end
        d[i] = v
      end
    end
  end
  return d
end

--------------------------------------------------------------------------------
-- Bayer-Dither (4x4)
--------------------------------------------------------------------------------
local BAYER4 = {
  { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 }
}
local function bayer(x, y)
  return (BAYER4[y % 4 + 1][x % 4 + 1] + 0.5) / 16
end
P.bayer = bayer

--------------------------------------------------------------------------------
-- Haupt-Renderer
--------------------------------------------------------------------------------
--[[ cfg = {
      regions = { [label] = {
          ramp      = Rampe (dunkel->hell),
          light     = {lx, ly},    optional, Standard {-0.55,-0.83}
          bulge     = 1.0,         Wie stark die Woelbung die Kante moduliert
          base_light= 0.60,        Grundhelligkeit der Flaechenmitte
          outline   = Farbe,       Standard: ramp[1] abgedunkelt
          dither    = true,        Bayer-Dither an Bandgrenzen
          sep       = true,        dunkle Trennlinie zu anderen Regionen
          flat      = false,       keine Woelbung (z.B. Metallplatte flach)
          grad      = 0.10,        vertikaler Verlauf
          alpha     = 255,
      }, ...}
   } ]]
function P.render(img, g, cfg)
  local w, h = g.w, g.h
  local regions = cfg.regions
  local DEFAULT_LIGHT = { -0.58, -0.81 }

  -- Labels einsammeln
  local labels, labIdx = {}, {}
  for i = 1, w * h do
    local l = g.d[i]
    if l ~= nil and labIdx[l] == nil then
      labIdx[l] = #labels + 1
      labels[#labels + 1] = l
    end
  end

  -- Distanzfelder + Gradienten pro Label
  local field = {}
  for _, l in ipairs(labels) do
    local pred = function(i) return g.d[i] == l end
    local d = distfield(g, pred)
    local maxd = 0
    for i = 1, w * h do if g.d[i] == l and d[i] > maxd then maxd = d[i] end end
    field[l] = { d = d, maxd = max(1.0, maxd) }
  end

  local function dAt(l, x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return 0 end
    local i = y * w + x + 1
    if g.d[i] ~= l then return 0 end
    return field[l].d[i]
  end

  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local i = y * w + x + 1
      local l = g.d[i]
      if l ~= nil then
        local rc = regions[l]
        assert(rc, "region missing for label " .. tostring(l))
        local ramp = rc.ramp
        if ramp == nil then error("region '" .. tostring(l) .. "' has no ramp") end
        local n = #ramp
        local L = rc.light or DEFAULT_LIGHT
        local ll = sqrt(L[1] * L[1] + L[2] * L[2])
        if ll == 0 then ll = 1 end
        local lx, ly = L[1] / ll, L[2] / ll

        local d = field[l].d[i]
        local dmax = field[l].maxd
        -- Normierte Tiefe (0 Rand .. 1 Mitte)
        local dn = P.clamp(d / max(1.0, dmax * 0.92), 0, 1)

        -- 2D-Normale aus Gradient des Distanzfeldes (zeigt nach aussen)
        local gx = (dAt(l, x + 1, y) - dAt(l, x - 1, y)) * 0.5
        local gy = (dAt(l, x, y + 1) - dAt(l, x, y - 1)) * 0.5
        local gn = sqrt(gx * gx + gy * gy)
        local nx, ny = 0, 0
        if gn > 0.0001 then nx, ny = -gx / gn, -gy / gn end
        local ndotl = nx * lx + ny * ly

        local bulge = rc.bulge or 1.0
        local edgew = 1 - P.smoothstep(0.0, 0.85, dn)   -- 1 am Rand, 0 im Inneren
        local baseLight = rc.base_light or 0.60
        local inten = baseLight + edgew * ndotl * 0.55 * bulge
        -- globaler Vertikalverlauf (oben heller)
        inten = inten + ((0.5 - (y + 0.5) / h)) * (rc.grad or 0.10)
        -- Woelbung: Mitte leicht aufgehellt (Rundung faengt Licht)
        inten = inten + (rc.flat and 0 or (dn * 0.10))

        -- Rampenindex bestimmen
        local t = P.clamp((inten - 0.22) / 0.62, 0, 1)
        local pos = 1 + t * (n - 1)
        local idx = floor(pos)
        local frac = pos - idx
        if (rc.dither ~= false) and frac > 0.30 and frac < 0.72 then
          if bayer(x, y) < (frac - 0.30) / 0.42 then idx = idx + 1 end
        elseif frac >= 0.72 then
          idx = idx + 1
        end
        idx = P.clamp(idx, 1, n)

        local col = ramp[idx]

        -- Rim-Light: heller Rand auf der Lichtseite
        if (rc.rim ~= false) and dn < 0.30 and ndotl > 0.45 then
          col = ramp[min(n, idx + 1)]
        end

        -- Abgrenzung zu anderen Regionen: dunkle Trennlinie
        if rc.sep ~= false then
          local dif = false
          local nb = { { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
          for k = 1, 4 do
            local q = P.getp(g, nb[k][1], nb[k][2])
            if q ~= nil and q ~= l then dif = true end
          end
          if dif then col = ramp[1] end
        end

        col = P.rgba(col.red, col.green, col.blue, rc.alpha or 255)
        img:drawPixel(x, y, col)
      end
    end
  end

  -- Aussenkontur in die Transparenz (4-Nachbarschaft)
  if cfg.outline ~= false then
    local add = {}
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        if g.d[y * w + x + 1] == nil then
          local nbl, best = nil, 1e9
          local nb = { { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
          for k = 1, 4 do
            local q = P.getp(g, nb[k][1], nb[k][2])
            if q ~= nil then
              local rc = regions[q]
              if rc then
                local oc = rc.outline or ((cfg.globalOutline) and cfg.globalOutline) or P.mul(rc.ramp[1], 0.62)
                -- Prioritaet: der Koerper, der "vorne" liegt (hoehere prio)
                local pr = rc.prio or 0
                if pr < best then best = pr; nbl = oc end
              end
            end
          end
          if nbl then add[#add + 1] = { x, y, nbl } end
        end
      end
    end
    for _, p in ipairs(add) do img:drawPixel(p[1], p[2], p[3]) end
  end
  return img
end

--------------------------------------------------------------------------------
-- Detail-Helfer (arbeiten auf dem fertigen Bild, maskiert per Grid-Label)
--------------------------------------------------------------------------------
-- fn(x, y, u, v) -> Color|nil ; u,v = normalisierte Koordinaten im Label-Bounding-Box
function P.paintIn(img, g, label, fn)
  local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if P.getp(g, x, y) == label then
        x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y)
      end
    end
  end
  if x0 > x1 then return end
  for y = y0, y1 do
    for x = x0, x1 do
      if P.getp(g, x, y) == label then
        local u = (x - x0) / max(1, (x1 - x0))
        local v = (y - y0) / max(1, (y1 - y0))
        local col = fn(x, y, u, v, P.pix(img, x, y))
        if col then img:drawPixel(x, y, col) end
      end
    end
  end
end

-- Diagonale/vertikale Streifen ueber ein Label (Bienenstreifen, Panels, Rippen)
function P.stripes(img, g, label, color, opts)
  opts = opts or {}
  local period = opts.period or 4
  local thick = opts.thick or 2
  local angle = opts.angle or 0        -- Radiant, 0 = vertikal
  local offset = opts.offset or 0
  local ax, ay = math.cos(angle), math.sin(angle)
  local edgeDark = opts.edgeDark
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    local s = (x * ax + y * ay) + offset
    local m = (s % period)
    if m < 0 then m = m + period end
    if m < thick then return color end
    if edgeDark and m >= thick and m < thick + 1 then return P.mul(cur, 0.85) end
    return nil
  end)
end

-- Gelb-schwarze Bienenbinde: dunkle Binde mit weicher Kante (2 Stufen)
function P.bands(img, g, label, dark, opts)
  opts = opts or {}
  local period = opts.period or 6
  local thick = opts.thick or 3
  local angle = opts.angle or 0
  local offset = opts.offset or 0
  local axis = opts.ellipse -- {cx,cy,rx,ry} fuer gekruemmte Binden
  local ax, ay = math.cos(angle), math.sin(angle)
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    local s
    if axis then
      -- Binden kruemmen sich um die Laengsachse -> Ellipsenabstand
      local dx, dy = (x - axis[1]) / axis[3], (y - axis[2]) / axis[4]
      s = dx * ax + dy * ay
      s = s * 12
    else
      s = (x * ax + y * ay)
    end
    s = s + offset
    local m = s % period
    if m < 0 then m = m + period end
    if m < thick then
      -- Kante: untere Kante dunkler (Schatten), obere leicht heller
      return dark
    end
    return nil
  end)
end

-- Auge (Facettenauge): dunkle Basis, heller Ring, Glanzpunkte
function P.eye(img, g, cx, cy, rx, ry, opts)
  opts = opts or {}
  local core = opts.core or P.c(0x1a1030)
  local mid = opts.mid or P.c(0x5a2a6a)
  local rim = opts.rim or P.c(0x8f5aa8)
  local clipLabel = opts.label
  for y = floor(cy - ry - 1), floor(cy + ry + 1) do
    for x = floor(cx - rx - 1), floor(cx + rx + 1) do
      local ok = (clipLabel == nil) or (P.getp(g, x, y) == clipLabel)
      local dx, dy = (x + 0.5 - cx - 0.5) / rx, (y + 0.5 - cy - 0.5) / ry
      local q = dx * dx + dy * dy
      if q <= 1 and ok then
        local col = core
        if q > 0.55 then col = mid end
        if q > 0.84 then col = rim end
        -- Facetten: 2x2-Raster leicht variieren
        if q <= 0.55 then
          local fx, fy = (x % 2), (y % 2)
          if fx == 0 and fy == 0 then col = P.mix(core, mid, 0.45) end
        end
        img:drawPixel(x, y, col)
      end
    end
  end
  -- Glanzpunkte (nur innerhalb der Maske)
  local hx, hy = floor(cx - rx * 0.45), floor(cy - ry * 0.45)
  if clipLabel == nil or P.getp(g, hx, hy) == clipLabel then
    img:drawPixel(hx, hy, opts.glint or P.c(0xffffff))
    if rx >= 3 and (clipLabel == nil or P.getp(g, hx + 1, hy) == clipLabel) then
      img:drawPixel(hx + 1, hy, P.c(0xdfe8ff))
    end
    if ry >= 4 and (clipLabel == nil or P.getp(g, hx, hy + 1) == clipLabel) then
      img:drawPixel(hx, hy + 1, P.c(0xc8d4f0))
    end
  end
end

-- Glanzpunkt / Specular (klein, kompakt)
function P.glint(img, x, y, col, size)
  col = col or P.c(0xffffff)
  size = size or 1
  if size <= 1 then
    img:drawPixel(x, y, col)
    return
  end
  img:drawPixel(x, y, col)
  img:drawPixel(x + 1, y, P.mul(col, 0.9))
  img:drawPixel(x, y + 1, P.mul(col, 0.82))
  if size >= 3 then img:drawPixel(x + 1, y + 1, P.mul(col, 0.7)) end
end

-- Linie (Bresenham) direkt aufs Bild, mit optionaler Abdunklung
function P.line(img, x1, y1, x2, y2, col)
  local dx, dy = abs(x2 - x1), -abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  while true do
    img:drawPixel(x1, y1, col)
    if x1 == x2 and y1 == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x1 = x1 + sx end
    if e2 <= dx then err = err + dx; y1 = y1 + sy end
  end
end

-- Metallplatte mit Nieten und Panelkante
function P.panel(img, g, label, x0, y0, w, h, ramp, opts)
  opts = opts or {}
  for y = y0, y0 + h - 1 do
    for x = x0, x0 + w - 1 do
      if P.getp(g, x, y) == label then
        local edge = (x == x0 or y == y0 or x == x0 + w - 1 or y == y0 + h - 1)
        local c = ramp[#ramp - 1]
        if y == y0 then c = ramp[#ramp]
        elseif y >= y0 + h - 2 or x >= x0 + w - 2 then c = ramp[1]
        elseif edge then c = ramp[2] end
        -- feine diagonale Schraffur fuer Metall
        if not edge and ((x + y) % 6 == 0) then c = P.mul(c, 0.92) end
        img:drawPixel(x, y, c)
      end
    end
  end
  if opts.rivets ~= false then
    local step = opts.rivetStep or 5
    for x = x0 + 1, x0 + w - 2, step do
      if P.getp(g, x, y0 + 1) == label then
        img:drawPixel(x, y0 + 1, ramp[#ramp])
        img:drawPixel(x, y0 + 2, P.mul(ramp[1], 1.15))
      end
      if P.getp(g, x, y0 + h - 2) == label then
        img:drawPixel(x, y0 + h - 2, ramp[2])
      end
    end
  end
end

-- Leuchtkern (Schwachpunkt, Energiekern): radial, ohne Rauschen
function P.core(img, cx, cy, r, hot, mid, edge, opts)
  opts = opts or {}
  for y = floor(cy - r - 1), floor(cy + r + 1) do
    for x = floor(cx - r - 1), floor(cx + r + 1) do
      local q = sqrt((x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2) / max(0.001, r)
      if q <= 1.0 then
        local col
        if q < 0.34 then col = hot
        elseif q < 0.62 then col = mid
        elseif q < 0.86 then col = edge
        else col = P.mix(edge, P.c(0x000000), 0.35) end
        img:drawPixel(x, y, col)
      end
    end
  end
  if opts.ring then
    for a = 0, 359, 12 do
      local rad = math.rad(a)
      local x = floor(cx + math.cos(rad) * (r + 1.2) - 0.5)
      local y = floor(cy + math.sin(rad) * (r + 1.2) - 0.5)
      if opts.ringLabel == nil or true then img:drawPixel(x, y, opts.ring) end
    end
  end
  if opts.glint ~= false then
    img:drawPixel(floor(cx - r * 0.3 - 0.5), floor(cy - r * 0.3 - 0.5), P.c(0xffffff))
  end
end

-- Transluzenz: Pixel im Label mit Alpha (Fluegel)
function P.alpha(img, g, label, a)
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    return P.rgba(cur.red, cur.green, cur.blue, a or 170)
  end)
end

-- Diagonal-Schraffur (dunkle Linien) fuer Textur
function P.hatch(img, g, label, col, period, k)
  k = k or 0.88
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    if ((x + y) % (period or 3)) == 0 then return P.mul(cur, k) end
    return nil
  end)
end

--------------------------------------------------------------------------------
-- Sprite-Aufbau: Frames, Quelle, Strip
--------------------------------------------------------------------------------
--[[ spec = { name, w, h, fps, frames = n, tags = {{name,f1,f2}}, root, spritedir, asedir,
             draw = function(img, frame, s) ... end } ]]
function P.buildSprite(spec)
  local n = spec.frames or 1
  local spr = Sprite(spec.w, spec.h, ColorMode.RGB)
  spr.filename = spec.asePath
  if n > 1 then
    for _ = 2, n do spr:newFrame(#spr.frames) end
  end
  spr.layers[1].name = "art"
  local dur = 1 / (spec.fps or 12)
  for f = 1, n do
    spr.frames[f].duration = dur
    local cel = spr.layers[1]:cel(f)
    local img = cel.image
    img:clear()
    spec.draw(img, f, spec)
  end
  if n > 1 then
    local tag = spr:newTag(1, n)
    tag.name = spec.tagName or "play"
    tag.aniDir = AniDir.FORWARD
  end
  app.activeSprite = spr
  spr:saveAs(spec.asePath)
  return spr
end

-- Strip-PNG (horizontale Frames) aus dem Multi-Frame-Sprite erzeugen
function P.exportStrip(spr, w, h, n, outPath)
  local strip = Sprite(w * n, h, ColorMode.RGB)
  strip.filename = outPath
  local img = strip.cels[1].image
  img:clear()
  for f = 1, n do
    local cel = spr.layers[1]:cel(f)
    img:drawImage(cel.image, Point((f - 1) * w, 0))
  end
  strip:saveCopyAs(outPath)
  strip:close()
end

return P
