--[[
  shapes.lua -- wiederverwendbare Form-Bausteine für die Apidya-Sprites
  Ergänzt pixel.lua um organische und technische Grundformen.
]]

local P = dofile("/home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/aseprite/lib/pixel.lua")
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi

local S = {}

-- Blatt/Flügel/Flosse: getaperte Blattform entlang einer quadratischen Bezier-Kurve
--[[ spec = { x0,y0 (Wurzel), x1,y1 (Spitze), cx,cy (Kontrollpunkt),
             w = maximale Halbbreite, points = Stützpunkte, label,
             root = Breitenfaktor an der Wurzel (0..1), tip = Breitenfaktor an der Spitze } ]]
function S.leaf(g, spec)
  local n = spec.points or 22
  local left, right = {}, {}
  for i = 0, n do
    local t = i / n
    local bx = (1 - t) ^ 2 * spec.x0 + 2 * (1 - t) * t * spec.cx + t * t * spec.x1
    local by = (1 - t) ^ 2 * spec.y0 + 2 * (1 - t) * t * spec.cy + t * t * spec.y1
    local dx = 2 * (1 - t) * (spec.cx - spec.x0) + 2 * t * (spec.x1 - spec.cx)
    local dy = 2 * (1 - t) * (spec.cy - spec.y0) + 2 * t * (spec.y1 - spec.cy)
    local len = sqrt(dx * dx + dy * dy)
    if len < 0.0001 then dx, dy, len = 1, 0, 1 end
    local nx, ny = -dy / len, dx / len
    -- Breitenprofil: Wurzel schmal..breit..Spitze spitz
    local prof = sin(pi * P.clamp(0.10 + 0.90 * t, 0, 1)) ^ 0.72
    local w = spec.w * prof
    if t < 0.22 and spec.root then
      w = w * (spec.root + (1 - spec.root) * (t / 0.22))
    end
    if t > 0.80 and spec.tip then
      w = w * (1 - (1 - spec.tip) * ((t - 0.80) / 0.20))
    end
    left[#left + 1] = { bx - nx * w, by - ny * w }
    right[#right + 1] = { bx + nx * w, by + ny * w }
  end
  local pts = {}
  for i = 1, #left do pts[#pts + 1] = left[i] end
  for i = #right, 1, -1 do pts[#pts + 1] = right[i] end
  P.poly(g, pts, spec.label)
  return pts
end

-- Feldkoordinaten einer Blattform: fn(x,y) -> t (0 Wurzel..1 Spitze), side (-1..1 quer)
-- Damit lassen sich Adern parallel zur Spindel zeichnen statt als Querstreifen.
function S.spineField(spec)
  local n = 48
  local px, py, pxr = {}, {}, {}
  for i = 0, n do
    local t = i / n
    local bx = (1 - t) ^ 2 * spec.x0 + 2 * (1 - t) * t * spec.cx + t * t * spec.x1
    local by = (1 - t) ^ 2 * spec.y0 + 2 * (1 - t) * t * spec.cy + t * t * spec.y1
    local dx = 2 * (1 - t) * (spec.cx - spec.x0) + 2 * t * (spec.x1 - spec.cx)
    local dy = 2 * (1 - t) * (spec.cy - spec.y0) + 2 * t * (spec.y1 - spec.cy)
    local len = sqrt(dx * dx + dy * dy)
    if len < 1e-4 then dx, dy, len = 1, 0, 1 end
    px[i + 1], py[i + 1] = bx, by
    pxr[i + 1] = { -dy / len, dx / len, len }
  end
  return function(x, y)
    local best, bt = 1e9, 0
    local cx2, cy2 = x + 0.5, y + 0.5
    for i = 1, n + 1 do
      local dx, dy = cx2 - px[i], cy2 - py[i]
      local q = dx * dx + dy * dy
      if q < best then best, bt, bnx, bny = q, (i - 1) / n, pxr[i][1], pxr[i][2] end
    end
    local side = ((cx2 - px[math.floor(bt * n) + 1]) * bnx + (cy2 - py[math.floor(bt * n) + 1]) * bny)
    local prof = sin(pi * P.clamp(0.10 + 0.90 * bt, 0, 1)) ^ 0.72
    local lw = spec.w * prof
    if lw < 0.001 then lw = 0.001 end
    return bt, P.clamp(side / lw, -1.2, 1.2)
  end
end

-- Linie, die nur innerhalb eines Labels zeichnet (Adern, Panelfugen)
function S.clipLine(img, g, label, x1, y1, x2, y2, col, thick)
  thick = thick or 0
  local dx, dy = abs(x2 - x1), -abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx + dy
  local guard = 0
  while guard < 4000 do
    guard = guard + 1
    for oy = -thick, thick do
      for ox = -thick, thick do
        local px, py = x1 + ox, y1 + oy
        if P.getp(g, px, py) == label then img:drawPixel(px, py, col) end
      end
    end
    if x1 == x2 and y1 == y2 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x1 = x1 + sx end
    if e2 <= dx then err = err + dx; y1 = y1 + sy end
  end
end

-- Flügel-Detailpass: Längsadern, helle Oberkante, warme Wurzel, blasse Spitze
--[[ spec = {x0,y0,x1,y1,cx,cy,w,label}; opts = { veins, edge, count, spread } ]]
function S.wingDetail(img, g, label, spec, opts)
  opts = opts or {}
  local veins = opts.veins or P.rgba(108, 146, 182, 210)
  local count = opts.count or 3
  local spread = opts.spread or (spec.w * 0.75)
  local x0, y0, x1, y1 = spec.x0, spec.y0, spec.x1, spec.y1
  -- Tangente an der Wurzel für die laterale Richtung
  local tx, ty = spec.cx - x0, spec.cy - y0
  local tl = sqrt(tx * tx + ty * ty)
  if tl < 1e-4 then tx, ty, tl = 1, 0, 1 end
  local nx, ny = -ty / tl, tx / tl
  -- Längsadern: von der Wurzel gefächert zur Spitze
  for k = 1, count do
    local f = k / (count + 1)                 -- 0..1 über die Flügelbreite
    local lat = (f - 0.5) * 2 * spread
    local ex = x0 + (x1 - x0) * 0.90 + nx * lat
    local ey = y0 + (y1 - y0) * 0.90 + ny * lat
    local mx = x0 + (x1 - x0) * 0.45 + nx * lat * 0.45
    local my = y0 + (y1 - y0) * 0.45 + ny * lat * 0.45
    S.clipLine(img, g, label, floor(x0 + (x1 - x0) * 0.10), floor(y0 + (y1 - y0) * 0.10),
               floor(mx), floor(my), veins)
    S.clipLine(img, g, label, floor(mx), floor(my), floor(ex), floor(ey), veins)
  end
  -- Querader
  local qx = x0 + (x1 - x0) * 0.62
  local qy = y0 + (y1 - y0) * 0.62
  S.clipLine(img, g, label, floor(qx - nx * spread * 0.8), floor(qy - ny * spread * 0.8),
             floor(qx + nx * spread * 0.8), floor(qy + ny * spread * 0.8), veins)
  -- Helle Oberkante (Lichtseite), blasse Spitze, warme Wurzel
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    if P.getp(g, x, y - 1) ~= label and P.getp(g, x, y - 2) ~= label then
      return opts.edge or P.rgba(236, 246, 254, 225)
    end
    return nil
  end)
end

-- Sichel/Klaue/Bogen: getaperter Bogen (Mandibeln, Sensen, Ranken)
function S.claw(g, x0, y0, x1, y1, cx, cy, w, label, n)
  return S.leaf(g, { x0 = x0, y0 = y0, x1 = x1, y1 = y1, cx = cx, cy = cy,
                     w = w, label = label, points = n or 14, root = 1.0, tip = 0.25 })
end

-- Segmentierter Schwanz/Abdomen aus mehreren Ellipsen entlang einer Kurve
function S.segments(g, pts, radii, label)
  for i = 1, #pts do
    local r = radii[i] or radii[#radii]
    P.ellipse(g, pts[i][1], pts[i][2], r, r * (radii.ry or 1), label)
  end
end

-- Bein: Kapselkette mit Gelenkknoten
function S.leg(g, pts, r, label)
  P.chain(g, pts, r, label)
  for i = 2, #pts - 1 do
    P.ellipse(g, pts[i][1], pts[i][2], r * 1.15, r * 1.15, label)
  end
end

-- Mehrere Beine (Spiegel um cy), spec = Liste von {x,y (Hüfte), Punkte relativ}
function S.legSet(g, hip, legs, r, label)
  for _, L in ipairs(legs) do
    local pts = { { hip[1] + L[1][1], hip[2] + L[1][2] } }
    for i = 2, #L do pts[#pts + 1] = { hip[1] + L[i][1], hip[2] + L[i][2] } end
    S.leg(g, pts, r, label)
  end
end

-- Stachel/Dorn: Dreieck mit leichter Krümmung
function S.spike(g, x0, y0, x1, y1, w, label)
  local dx, dy = x1 - x0, y1 - y0
  local len = sqrt(dx * dx + dy * dy)
  if len < 0.001 then return end
  local nx, ny = -dy / len * w, dx / len * w
  P.poly(g, { { x0 + nx, y0 + ny }, { x1, y1 }, { x0 - nx, y0 - ny } }, label)
end

-- Zackenkranz / Zahnradzähne (Technik)
function S.gearTeeth(g, cx, cy, rx, ry, count, depth, label, phase)
  phase = phase or 0
  for i = 0, count - 1 do
    local a = phase + i * 2 * pi / count
    local a1 = a - 0.55 * pi / count
    local a2 = a + 0.55 * pi / count
    P.poly(g, {
      { cx + cos(a1) * rx, cy + sin(a1) * ry },
      { cx + cos(a) * (rx + depth), cy + sin(a) * (ry + depth) },
      { cx + cos(a2) * rx, cy + sin(a2) * ry },
    }, label)
  end
end

-- Ring (Reifen, Düsen, Aura) als Ringpolygon
function S.ring(g, cx, cy, rxo, ryo, rxi, ryi, label)
  local n = 40
  local outer, inner = {}, {}
  for i = 0, n do
    local a = i * 2 * pi / n
    outer[#outer + 1] = { cx + cos(a) * rxo, cy + sin(a) * ryo }
    inner[#inner + 1] = { cx + cos(a) * rxi, cy + sin(a) * ryi }
  end
  local pts = {}
  for i = 1, #outer do pts[#pts + 1] = outer[i] end
  for i = #inner, 1, -1 do pts[#pts + 1] = inner[i] end
  P.poly(g, pts, label)
end

------------------------------------------------------------------------------
-- Zeichen-Helfer auf dem fertigen Bild
------------------------------------------------------------------------------

-- Ader/Nerv-Linie in einem Flügel (dunkler, leicht transparent)
function S.veins(img, g, label, from, to, col, count, spread)
  count = count or 3
  for i = 0, count - 1 do
    local t = count == 1 and 0.5 or i / (count - 1)
    local ex = from[1] + (to[1] - from[1]) * 0.85
    local ey = from[2] + (to[2] - from[2]) * 0.85
    local mx = ex + (to[1] - from[1]) * 0.1 + (spread or 6) * (t - 0.5)
    local my = ey + (to[2] - from[2]) * 0.1 + (spread or 6) * (t - 0.5) * 0.6
    P.paintIn(img, g, label, function(x, y)
      return nil
    end)
    -- Linie in drei Abschnitten (bogenförmig)
    local x1 = from[1] + (mx - from[1]) * 0.5
    local y1 = from[2] + (my - from[2]) * 0.5
    P.line(img, floor(from[1]), floor(from[2]), floor(x1), floor(y1), col)
    P.line(img, floor(x1), floor(y1), floor(mx), floor(my), col)
  end
end

-- Facettenmuster für große Augen (Waben), bleibt in der Silhouette
function S.facets(img, g, label, cx, cy, rx, ry, base, light)
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    local dx, dy = (x - cx), (y - cy)
    local q = (dx / rx) ^ 2 + (dy / ry) ^ 2
    if q > 1 then return nil end
    local gx = (dx % 3)
    local gy = ((y + floor(dx / 3)) % 3)
    if gx == 0 or gy == 0 then return base end
    if q < 0.35 and (gx + gy) % 2 == 0 then return light end
    return nil
  end)
end

-- Panzerplatten über einem Label: horizontale Segmentfugen + Kante
function S.plates(img, g, label, y0, y1, colDark, colLight, step)
  step = step or 4
  P.paintIn(img, g, label, function(x, y, u, v, cur)
    if y >= y0 and y <= y1 and (y - y0) % step == 0 then return colDark end
    if y >= y0 and y <= y1 and (y - y0) % step == 1 then return P.mix(cur, colLight, 0.25) end
    return nil
  end)
end

-- Leuchtkugel mit gebändertem, gedithertem Falloff (Geschosse, Effekte)
-- cols = {weiss, hell, mittel, dunkel}; opts.squash = y-Stauchung, opts.hard = harte Kante
function S.orb(img, cx, cy, r, cols, opts)
  opts = opts or {}
  local sq = opts.squash or 1.0
  local hard = opts.hard
  for y = floor(cy - r * sq - 1), floor(cy + r * sq + 1) do
    for x = floor(cx - r - 1), floor(cx + r + 1) do
      local dx, dy = (x + 0.5 - cx), (y + 0.5 - cy) / sq
      local q = sqrt(dx * dx + dy * dy) / max(0.001, r)
      local c
      if q <= 0.32 then c = cols[1]
      elseif q <= 0.62 then c = cols[2]
      elseif q <= 0.88 then c = cols[3]
      elseif q <= 1.0 then c = cols[4]
      elseif q <= 1.28 and not hard then
        -- äußerer Glimmsaum, gedithert
        if P.bayer(x, y) < (1.28 - q) / 0.28 then c = cols[4] end
      end
      if c then img:drawPixel(x, y, c) end
    end
  end
end

-- Ringwelle (Schockwelle): Ring mit weicher Innen-/Außenkante
function S.ringWave(img, cx, cy, r, thick, cols, opts)
  opts = opts or {}
  local sq = opts.squash or 1.0
  for y = floor(cy - r * sq - thick - 2), floor(cy + r * sq + thick + 2) do
    for x = floor(cx - r - thick - 2), floor(cx + r + thick + 2) do
      local dx, dy = (x + 0.5 - cx), (y + 0.5 - cy) / sq
      local d = sqrt(dx * dx + dy * dy)
      local off = abs(d - r)
      local c
      if off <= thick * 0.35 then c = cols[1]
      elseif off <= thick * 0.7 then c = cols[2]
      elseif off <= thick then c = cols[3]
      elseif off <= thick * 1.5 then
        if P.bayer(x, y) < (thick * 1.5 - off) / (thick * 0.5) then c = cols[3] end
      end
      if c then img:drawPixel(x, y, c) end
    end
  end
end

-- Flamme/Tropfen (Triebwerk, Feuer): Basis unten, Spitze oben
function S.flame(img, cx, cy, w, h, cols, opts)
  opts = opts or {}
  local wob = opts.wobble or 0
  for y = floor(cy - h), floor(cy) do
    local t = (cy - y) / max(0.001, h)    -- 0 Basis .. 1 Spitze
    local halfw = w * (1 - t) ^ 0.8 * (1 + 0.18 * sin(6 * t + wob))
    local inner = halfw * 0.45
    for x = floor(cx - halfw - 1), floor(cx + halfw + 1) do
      local dx = abs(x + 0.5 - cx)
      local c
      if dx <= inner then c = cols[1]
      elseif dx <= inner * 1.8 then c = cols[2]
      elseif dx <= halfw then c = cols[3]
      elseif dx <= halfw + 1 and P.bayer(x, y) < 0.4 then c = cols[3] end
      if c and t < 0.98 then img:drawPixel(x, y, c) end
    end
  end
end

-- Energie/Adern: leuchtende Linien entlang einer Kurve
function S.energyLine(img, pts, col, core)
  for i = 1, #pts - 1 do
    P.line(img, floor(pts[i][1]), floor(pts[i][2]), floor(pts[i + 1][1]), floor(pts[i + 1][2]), col)
  end
  if core then
    for i = 2, #pts - 1 do
      img:drawPixel(floor(pts[i][1]), floor(pts[i][2]), core)
    end
  end
end

-- Nietenreihe
function S.rivets(img, g, label, x0, x1, y, col)
  for x = x0, x1, 3 do
    if P.getp(g, x, y) == label then img:drawPixel(x, y, col) end
  end
end

-- Treibwerksdüse mit Glut
function S.thruster(img, cx, cy, r, hot, mid, glow)
  P.core(img, cx, cy, r, hot, mid, glow, { glint = false })
end

return S
