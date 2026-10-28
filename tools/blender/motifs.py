"""motifs.py -- Wiederverwendbare Einzelmotive (Blumen, Wurzeln, Pilze, Roehren,
Zahnraeder, Waben, Kristalle ...), gebaut aus den Primitiven von bg_lib.

Alle Funktionen platzieren ihre Objekte in der aktuellen Collection
(siehe bg_lib.use_collection) und liefern die erzeugten Objekte zurueck.
"""

import math

import bg_lib as L
from bg_lib import (add_mesh, circle_profile, flat_profile, g_box, g_cyl,
                    g_prism, g_sphere, g_sweep, mat)


# --------------------------------------------------------------------------
# Organische Grundformen
# --------------------------------------------------------------------------
def blade(x, z, y, height, width, lean=0.0, curl=0.0, rot=0.0, material=None,
          segs=9, twist=0.0, name="blade"):
    """Ein einzelnes Blatt/Grashalm: Band mit breiter Basis und spitzer Spitze."""
    pts, profs = [], []
    for i in range(segs):
        t = i / (segs - 1)
        px = x + lean * height * (t ** 1.7) + curl * height * 0.16 * math.sin(t * math.pi)
        pz = z + height * t * (1.0 - 0.10 * abs(curl))
        pts.append((px, y + twist * t, pz))
        halfw = 0.5 * width * (1.0 - t) ** 0.62 + 0.12
        th = max(0.55 * (1.0 - t) + 0.18, 0.2)
        profs.append(flat_profile(halfw, th))
    verts, faces = g_sweep(pts, profs)
    return [add_mesh(name, verts, faces, material, rot=(0.0, rot, 0.0),
                     smooth=True)]


def tuft(x, z, y, count, height, spread, rnd, material, lean_range=(-0.45, 0.45),
         width=3.4, name="tuft", z_jitter=0.0):
    obs = []
    for i in range(count):
        h = height * rnd.uniform(0.62, 1.25)
        bx = x + rnd.uniform(-spread, spread)
        bz = z + rnd.uniform(-z_jitter, z_jitter)
        lean = rnd.uniform(*lean_range)
        obs += blade(bx, bz, y + rnd.uniform(-4.0, 4.0), h,
                     width * rnd.uniform(0.7, 1.3), lean=lean,
                     curl=rnd.uniform(-0.5, 0.7), rot=rnd.uniform(-0.25, 0.25),
                     material=material, name=name)
    return obs


def leaf(x, z, y, length, width, angle_deg, material, bend=0.42,
         curl=0.0, name="leaf", segs=9):
    """Ein breites Blatt, um 'angle_deg' in der Bildebene gedreht (0 = nach
    rechts, 90 = nach unten, -90 = nach oben)."""
    pts, profs = [], []
    for i in range(segs):
        t = i / (segs - 1)
        px = length * t
        pz = bend * length * (t ** 1.9) + curl * length * 0.18 * math.sin(t * math.pi)
        pts.append((x + px, y, z + pz))
        halfw = 0.5 * width * math.sin(min(t, 1.0) * math.pi) ** 0.62 + 0.1
        th = max(1.1 * (1.0 - t) + 0.25, 0.25)
        profs.append(flat_profile(halfw, th))
    verts, faces = g_sweep(pts, profs)
    # Rotation um Y (in der Bildebene) um den Fusspunkt (x, y, z)
    ang = math.radians(angle_deg)
    ca, sa = math.cos(ang), math.sin(ang)
    rv = []
    for (vx, vy, vz) in verts:
        px, pz = vx - x, vz - z
        rv.append((x + px * ca + pz * sa, vy, z - px * sa + pz * ca))
    return [add_mesh(name, rv, faces, material, smooth=True)]


def leaf_cluster(x, z, y, count, length, width, rnd, material,
                 angle_lo=55.0, angle_hi=120.0, name="lcluster", bend=0.5,
                 length_var=0.35, fan_out=True):
    """Buendel grosser Blaetter (fuer kraeftige Vordergrund-Silhouetten)."""
    obs = []
    for i in range(count):
        t = i / max(count - 1, 1)
        ang = angle_lo + (angle_hi - angle_lo) * t + rnd.uniform(-6.0, 6.0)
        ln = length * rnd.uniform(1.0 - length_var, 1.0 + length_var * 0.4)
        wd = width * rnd.uniform(0.82, 1.12)
        bd = bend * (1.0 if fan_out else 0.7) * rnd.uniform(0.85, 1.15)
        obs += leaf(x + rnd.uniform(-length * 0.05, length * 0.05), z,
                    y + rnd.uniform(-5.0, 5.0), ln, wd, ang, material,
                    bend=bd, name=name)
    return obs


def fern(x, z, y, length, width, angle_deg, material, rnd, pairs=6,
         name="fern"):
    """Farnwedel: Mittelrippe mit gegenstaendigen Fiedern."""
    obs = []
    rad = math.radians(angle_deg)
    dx, dz = math.cos(rad), math.sin(rad)
    nx, nz = -dz, dx
    for i in range(pairs):
        t = 0.18 + 0.78 * (i / max(pairs - 1, 1))
        cx = x + dx * length * t
        cz = z + dz * length * t - 0.10 * length * (t ** 2)
        leaf_len = width * (1.0 - t) * 1.15
        for side in (-1.0, 1.0):
            a = angle_deg + side * (58.0 - 18.0 * t)
            obs += leaf(cx, cz, y + side * 2.0, leaf_len, leaf_len * 0.42, a,
                        material, bend=0.35, name=name + "_l")
        v, f = g_sweep([(cx, y, cz), (cx + dx * 4.0, y, cz + dz * 4.0)],
                       [circle_profile(6, 2.2, 2.2), circle_profile(6, 1.6, 1.6)])
        obs.append(add_mesh(name + "_s", v, f, material, smooth=True))
    return obs


def flower(x, z, y, size, petal_mat, petal_mat2, core_mat, rnd,
           petals=8, layers=2, name="flower", cup=0.30):
    """Bluete: zwei Petalringe + Kern, leicht in die Tiefe gestaffelt."""
    obs = []
    for li in range(layers):
        n = petals if li == 0 else max(4, petals - 2)
        off = 0.0 if li == 0 else math.pi / n
        plen = size * (1.0 if li == 0 else 0.74)
        pwid = size * (0.52 if li == 0 else 0.42)
        pmat = petal_mat if li == 0 else petal_mat2
        yy = y - li * 3.0
        for i in range(n):
            ang = 2.0 * math.pi * i / n + off + rnd.uniform(-0.05, 0.05)
            segs = 6
            pts, profs = [], []
            jitter = rnd.uniform(0.92, 1.08)
            for s in range(segs):
                t = s / (segs - 1)
                px = plen * jitter * t
                pz = cup * plen * (t ** 2.0) * jitter
                pts.append((px, 0.0, pz))
                w = pwid * math.sin(min(t * 1.03, 1.0) * math.pi) ** 0.6
                w = max(w, 0.2)
                th = max(pwid * 0.16 * (1.0 - t) ** 0.5, 0.25)
                profs.append(flat_profile(w * 0.5, th))
            verts, faces = g_sweep(pts, profs)
            ob = add_mesh(name + "_p", verts, faces, pmat,
                          loc=(x, yy, z),
                          rot=(0.0, ang, 0.0), smooth=True)
            obs.append(ob)
    # Kern
    v, f = g_sphere(1.0, 16, 8)
    obs.append(add_mesh(name + "_core", v, f, core_mat,
                        loc=(x, y - 6.0, z),
                        scale=(size * 0.30, size * 0.22, size * 0.30),
                        smooth=True))
    return obs


def mushroom(x, z, y, height, cap_r, stem_mat, cap_mat, gill_mat=None,
             rnd=None, name="mush", lean=0.0, cap_h=None):
    """Pilz: Stiel + gewoelbte Kappe + Lamellen."""
    obs = []
    cap_h = cap_h or cap_r * 0.62
    # Stiel (leicht gebogen)
    pts, profs = [], []
    segs = 6
    for i in range(segs):
        t = i / (segs - 1)
        px = x + lean * height * (t ** 1.6)
        pz = z + height * t
        r = cap_r * (0.26 if t < 0.2 else 0.20) * (1.0 - 0.25 * t)
        profs.append(circle_profile(10, r, r))
        pts.append((px, y, pz))
    v, f = g_sweep(pts, profs)
    obs.append(add_mesh(name + "_stem", v, f, stem_mat, smooth=True))
    # Kappe als Rotationskoerper (Halbkugel mit ueberhaengendem Rand)
    rings = 7
    prof = []
    for i in range(rings + 1):
        t = i / rings
        rr = cap_r * math.sin(t * math.pi * 0.5) ** 0.75
        zz = cap_h * math.cos(t * math.pi * 0.5) ** 0.85
        prof.append((rr, zz))
    pts, profs = [], []
    for (rr, zz) in prof:
        pts.append((x + lean * height, y, z + height + zz * 0.9))
        profs.append(circle_profile(18, rr, rr))
    v, f = g_sweep(pts, profs, cap_start=True, cap_end=True)
    obs.append(add_mesh(name + "_cap", v, f, cap_mat, smooth=True))
    if gill_mat is not None:
        v, f = g_cyl(cap_r * 0.92, cap_r * 0.92, 2.0, 18, caps=True)
        obs.append(add_mesh(name + "_gill", v, f, gill_mat,
                            loc=(x + lean * height, y, z + height - 1.0),
                            smooth=False))
    return obs


def reed(x, z, y, height, rnd, stem_mat, head_mat=None, lean=0.0, name="reed",
         width=2.0):
    pts, profs = [], []
    segs = 8
    for i in range(segs):
        t = i / (segs - 1)
        px = x + lean * height * (t ** 1.8)
        pz = z + height * t
        pts.append((px, y, pz))
        r = width * (1.0 - 0.25 * t)
        profs.append(circle_profile(8, r, r))
    v, f = g_sweep(pts, profs)
    obs = [add_mesh(name, v, f, stem_mat, smooth=True)]
    if head_mat is not None:
        hh = height * 0.22
        v, f = g_cyl(width * 1.6, width * 1.6, hh, 12, caps=True)
        tipx = x + lean * height * ((1.0 - 0.05) ** 1.8)
        obs.append(add_mesh(name + "_head", v, f, head_mat,
                            loc=(tipx, y, z + height * 0.86), smooth=True))
    return obs


def lily_pad(x, z, y, radius, material, notch_mat=None, rnd=None, notch=0.30,
             name="pad", lobes=0):
    """Seerosenblatt: Scheibe mit Kerbe, leicht gewellt."""
    n = 34
    a0 = notch * math.pi
    verts = [(x, y, z)]
    faces = []
    ring = []
    for i in range(n + 1):
        t = i / n
        ang = a0 + (2.0 * math.pi - 2.0 * a0) * t
        rr = radius * (1.0 + 0.06 * math.sin(t * math.pi * 8.0 + (rnd.uniform(0, 6) if rnd else 0)))
        ring.append((x + rr * math.cos(ang), y + 1.6 * math.sin(ang * 3.0),
                     z + rr * math.sin(ang) * 0.35))
    for i in range(n):
        verts.append(ring[i])
        faces.append((0, i + 1, i + 2))
    verts.append(ring[n])
    v = [(p[0], p[1], p[2]) for p in verts]
    return [add_mesh(name, v, faces, material, smooth=False, shade_flat=True)]


# --------------------------------------------------------------------------
# Wurzeln, Ranken, Dornen
# --------------------------------------------------------------------------
def root(x, z, y, length, radius, material, rnd, angle_deg=0.0, wiggle=0.35,
         taper=0.45, segs=14, name="root", branches=0):
    obs = []
    pts, profs = [], []
    for i in range(segs):
        t = i / (segs - 1)
        px = length * t
        pz = wiggle * length * 0.14 * math.sin(t * 5.2 + (rnd.uniform(0, 0.2))) - \
            taper * length * 0.55 * (t ** 2.2)
        r = radius * (1.0 - taper * t) * (1.0 + 0.10 * math.sin(t * 9.0))
        pts.append((px, y + 3.0 * math.sin(t * 2.0), pz))
        profs.append(circle_profile(12, max(r, 0.4), max(r, 0.4)))
    v, f = g_sweep(pts, profs)
    obs.append(add_mesh(name, v, f, material, loc=(x, 0.0, z),
                        rot=(0.0, math.radians(angle_deg), 0.0), smooth=True))
    for b in range(branches):
        t0 = rnd.uniform(0.25, 0.75)
        bl = length * rnd.uniform(0.28, 0.5)
        ang = angle_deg + rnd.uniform(-55.0, 55.0)
        bx = x + math.cos(math.radians(angle_deg)) * length * t0
        bz = z + math.sin(math.radians(angle_deg)) * length * t0 * 0.0
        obs += root(bx, bz - length * taper * 0.4 * (t0 ** 2.2), y - 4.0, bl,
                    radius * 0.55, material, rnd, angle_deg=ang, taper=0.7,
                    segs=8, name=name + "_b", branches=0)
    return obs


def vine(x, z, y, length, material, rnd, angle_deg=90.0, wiggle=0.5, radius=3.0,
         thorns=0.0, thorn_mat=None, name="vine"):
    """Ranke (Rohrkoerper) optional mit Dornen."""
    obs = []
    pts, profs = [], []
    segs = 18
    ph = rnd.uniform(0.0, 6.28)
    for i in range(segs):
        t = i / (segs - 1)
        along = length * t
        wob = wiggle * length * 0.10 * math.sin(t * 7.0 + ph)
        px = x + math.cos(math.radians(angle_deg)) * along - \
            math.sin(math.radians(angle_deg)) * wob
        pz = z + math.sin(math.radians(angle_deg)) * along + \
            math.cos(math.radians(angle_deg)) * wob
        r = radius * (1.0 - 0.45 * t)
        pts.append((px, y, pz))
        profs.append(circle_profile(9, max(r, 0.4), max(r, 0.4)))
    v, f = g_sweep(pts, profs)
    obs.append(add_mesh(name, v, f, material, smooth=True))
    if thorns > 0 and thorn_mat is not None:
        k = int(thorns)
        for i in range(k):
            t = (i + 0.5) / k
            idx = min(int(t * (segs - 1)), segs - 2)
            base = pts[idx]
            nxt = pts[idx + 1]
            dx, dz = nxt[0] - base[0], nxt[2] - base[2]
            dl = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / dl, dx / dl
            side = 1 if i % 2 == 0 else -1
            tl = radius * 3.2
            v, f = g_cyl(radius * 0.85, 0.1, tl, 6, caps=True)
            ob = add_mesh(name + "_thorn", v, f, thorn_mat,
                          loc=(base[0] + nx * side * radius * 0.6, y,
                               base[2] + nz * side * radius * 0.6),
                          rot=(0.0, math.atan2(nx * side, nz * side), 0.0),
                          smooth=True)
            # Zylinder zeigt nach +Z; Rotation bringt ihn in Richtung (nx,nz)
            ob.rotation_euler = (0.0, math.atan2(nx * side, nz * side), 0.0)
            obs.append(ob)
    return obs


# --------------------------------------------------------------------------
# Technik: Zahnraeder, Waben, Rohre, Backstein, Gitter
# --------------------------------------------------------------------------
def gear(x, z, y, r_out, teeth, thickness, material, hub_mat=None, hub_r=None,
         spokes=0, name="gear", depth_scale=1.0, tooth_h=None):
    """Zahnrad als stilisierte Scheibe mit rechteckigen Zaehnen."""
    tooth_h = tooth_h or r_out * 0.20
    r_in = r_out - tooth_h
    pts = []
    n = teeth * 4
    for i in range(n):
        t = i / n
        ang = 2.0 * math.pi * t
        q = (i % 4)
        if q in (1, 2):
            rr = r_out
        else:
            rr = r_in
        pts.append((rr * math.cos(ang), rr * math.sin(ang)))
    verts, faces = g_prism([(p[0], p[1]) for p in pts], thickness)
    ob = add_mesh(name, verts, faces, material,
                  loc=(x, y, z), smooth=False, shade_flat=True)
    obs = [ob]
    if hub_r:
        v, f = g_cyl(hub_r, hub_r, thickness * 2.0, 16, caps=True)
        obs.append(add_mesh(name + "_hub", v, f, hub_mat or material,
                            loc=(x, y - 3.0, z),
                            rot=(math.radians(90.0), 0.0, 0.0), smooth=True))
    if spokes:
        for i in range(spokes):
            ang = 2.0 * math.pi * i / spokes + 0.2
            v, f = g_box(r_in * 1.75, thickness * 0.7, r_out * 0.14)
            obs.append(add_mesh(name + "_spoke", v, f, hub_mat or material,
                                loc=(x, y - 2.0, z),
                                rot=(0.0, ang, 0.0), smooth=False,
                                shade_flat=True))
    return obs


def hex_poly(r, seg=6, rot=0.0):
    return [(r * math.cos(2.0 * math.pi * i / seg + rot),
             r * math.sin(2.0 * math.pi * i / seg + rot)) for i in range(seg)]


def hex_frame(x, z, y, size, wall, depth, material, name="hex", rot=0.0):
    """Sechseckiger Rahmen (Wabenzelle) als Ringflaeche mit Tiefe."""
    outer = hex_poly(size, 6, rot)
    inner = hex_poly(size - wall, 6, rot)
    verts = [(p[0], -depth * 0.5, p[1]) for p in outer]
    verts += [(p[0], depth * 0.5, p[1]) for p in outer]
    verts += [(p[0], -depth * 0.5, p[1]) for p in inner]
    verts += [(p[0], depth * 0.5, p[1]) for p in inner]
    faces = []
    for i in range(6):
        j = (i + 1) % 6
        faces.append((i, j, 6 + j, 6 + i))                    # Aussenwand
        faces.append((12 + j, 12 + i, 18 + i, 18 + j))        # Innenwand
        faces.append((i, 12 + i, 12 + j, j))                  # Frontring
        faces.append((6 + j, 18 + j, 18 + i, 6 + i))          # Rueckring
    return [add_mesh(name, verts, faces, material, loc=(x, y, z),
                     smooth=False, shade_flat=True)]


def hex_honey(x, z, y, size, wall, depth, frame_mat, fill_mat, rnd,
              name="honey", glow=0.0):
    obs = hex_frame(x, z, y, size, wall, depth, frame_mat, name=name)
    if fill_mat is not None:
        v, f = g_prism(hex_poly(size - wall, 6), depth * 0.35)
        obs.append(add_mesh(name + "_fill", v, f, fill_mat,
                            loc=(x, y + depth * 0.3, z), smooth=False,
                            shade_flat=True))
    return obs


def pipe(x, z, y, length, radius, material, flange_mat=None, angle_deg=0.0,
         name="pipe", flanges=3):
    pts, profs = [], []
    segs = 10
    obs = []
    for i in range(segs):
        t = i / (segs - 1)
        pts.append((length * t, 0.0, 0.0))
        profs.append(circle_profile(14, radius, radius))
    v, f = g_sweep(pts, profs)
    obs.append(add_mesh(name, v, f, material, loc=(x, y, z),
                        rot=(0.0, math.radians(angle_deg), 0.0), smooth=True))
    if flange_mat is not None:
        for i in range(flanges):
            t = (i + 0.5) / flanges
            px = x + math.cos(math.radians(angle_deg)) * length * t
            pz = z + math.sin(math.radians(angle_deg)) * length * t
            v, f = g_cyl(radius * 1.28, radius * 1.28, radius * 0.55, 14,
                         caps=True)
            obs.append(add_mesh(name + "_fl", v, f, flange_mat,
                                loc=(px, y, pz),
                                rot=(0.0, math.radians(angle_deg) + math.pi * 0.5,
                                     0.0),
                                smooth=True))
    return obs


def brick_wall(x0, z0, y, cols, rows, w, h, mat_a, mat_b, rnd,
               name="brick", gap=1.2):
    obs = []
    for r in range(rows):
        offs = (w * 0.5 if r % 2 else 0.0)
        for c in range(cols):
            bx = x0 + c * w + offs
            bz = z0 + r * h
            m = mat_a if rnd.random() < 0.55 else mat_b
            jx = rnd.uniform(-1.0, 1.0)
            jz = rnd.uniform(-1.0, 1.0)
            v, f = g_box(w - gap, 6.0, h - gap)
            obs.append(add_mesh(name, v, f, m,
                                loc=(bx, y + rnd.uniform(-2.0, 2.0), bz + jz),
                                rot=(0.0, 0.0, math.radians(jx * 0.5)),
                                smooth=False, shade_flat=True))
    return obs


def crystal(x, z, y, height, radius, body_mat, tip_mat, rnd, facets=6,
            lean=0.0, name="crystal"):
    """Organischer Kristall: mehrere konische Saeulen mit Spitze."""
    obs = []
    pts, profs = [], []
    segs = 7
    for i in range(segs):
        t = i / (segs - 1)
        px = x + lean * height * (t ** 1.7)
        pz = z + height * t
        r = radius * (1.0 - 0.55 * t) * (1.0 - 0.9 * max(0.0, t - 0.72) / 0.28)
        pts.append((px, y, pz))
        profs.append(circle_profile(facets, max(r, 0.15), max(r, 0.15) * 0.7))
    v, f = g_sweep(pts, profs)
    obs.append(add_mesh(name, v, f, body_mat, smooth=False, shade_flat=True))
    if tip_mat is not None:
        v, f = g_sweep(pts[3:], profs[3:])
        obs.append(add_mesh(name + "_tip", v, f, tip_mat, smooth=False,
                            shade_flat=True))
    return obs


def rock(x, z, y, radius, material, rnd, name="rock", squash=0.62, segs=14):
    v, f = g_sphere(1.0, segs, max(6, segs // 2))
    verts = []
    for (vx, vy, vz) in v:
        k = 1.0 + 0.18 * math.sin(vx * 4.1 + rnd.random() * 0.0) + \
            0.12 * math.cos(vy * 5.3)
        verts.append((vx * radius * k, vy * radius * k * 0.55,
                      vz * radius * k * squash))
    return [add_mesh(name, verts, f, material, loc=(x, y, z), smooth=True)]


def cloud(x, z, y, w, h, material, rnd, puffs=5, name="cloud"):
    obs = []
    for i in range(puffs):
        t = i / max(puffs - 1, 1)
        px = x + (t - 0.5) * w * 0.9
        pz = z + math.sin(t * math.pi) * h * 0.35 + rnd.uniform(-h, h) * 0.12
        rr = h * (0.5 + 0.5 * math.sin(t * math.pi)) * rnd.uniform(0.8, 1.15)
        v, f = g_sphere(1.0, 18, 9)
        obs.append(add_mesh(name, v, f, material, loc=(px, y, pz),
                            scale=(rr * 1.5, rr * 0.6, rr), smooth=True))
    return obs


def glow_dot(x, z, y, r, material, name="dot", squash=1.0):
    v, f = g_sphere(1.0, 12, 7)
    return [add_mesh(name, v, f, material, loc=(x, y, z),
                     scale=(r, r * 0.35, r * squash), smooth=True)]


def bar(p0, p1, r, material, name="bar", segs=5, sides=4, taper=0.0):
    """Gerades Rohr/Stab zwischen zwei Punkten (Kabel, Strebe, Rohr)."""
    pts, profs = [], []
    for i in range(segs):
        t = i / (segs - 1)
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t,
                    p0[2] + (p1[2] - p0[2]) * t))
        rr = r * (1.0 - taper * t)
        if sides == 4:
            profs.append([(-rr, -rr), (rr, -rr), (rr, rr), (-rr, rr)])
        else:
            profs.append(circle_profile(sides, rr, rr))
    v, f = g_sweep(pts, profs)
    return [add_mesh(name, v, f, material, smooth=(sides > 4))]


def arch(x, z, radius, tube_r, material, rnd=None, span=180.0, segs=14,
         z_scale=1.0, name="arch", thick=1.0):
    """Bogen (Halbkreis) aus einem Rohr -- Gewoelbe, Wurzelboegen, Streben."""
    pts, profs = [], []
    a0 = math.radians(-span * 0.5)
    a1 = math.radians(span * 0.5)
    for i in range(segs):
        t = i / (segs - 1)
        a = a0 + (a1 - a0) * t
        pts.append((x + radius * math.sin(a), 0.0,
                    z + radius * math.cos(a) * z_scale))
        rr = tube_r * thick
        profs.append(circle_profile(8, rr, rr))
    v, f = g_sweep(pts, profs)
    return [add_mesh(name, v, f, material, smooth=True)]


def membrane(x, z, y, w, h, material, rnd, blobs=4, name="membrane"):
    """Weicher organischer Klumpen aus mehreren Kugeln."""
    obs = []
    for i in range(blobs):
        t = i / max(blobs - 1, 1)
        ox = (t - 0.5) * w * 0.85
        oz = math.sin(t * math.pi) * h * 0.28
        r = h * (0.45 + 0.3 * math.sin(t * math.pi)) * rnd.uniform(0.85, 1.1)
        v, f = g_sphere(1.0, 16, 9)
        obs.append(add_mesh(name, v, f, material,
                            loc=(x + ox, y, z + oz),
                            scale=(r * 1.25, r * 0.8, r), smooth=True))
    return obs


def soft_glow(x, z, y, radius, material, name="glow", squash=1.0):
    """Weicher Lichtschein als Flaeche mit radialem Verlauf."""
    r = radius
    verts = [(-1.0, 0.0, 1.0), (1.0, 0.0, 1.0), (1.0, 0.0, -1.0),
             (-1.0, 0.0, -1.0)]
    return [add_mesh(name, verts, [(0, 1, 2, 3)], material,
                     loc=(x, y, z), scale=(r, 1.0, r * squash),
                     shade_flat=True, wrap=False)]


def pyxis(x, z, y, radius, material, name="pod", squash=1.3):
    """Eifoermige Kapsel (Samen, Kokon, Organ)."""
    v, f = g_sphere(1.0, 16, 10)
    return [add_mesh(name, v, f, material, loc=(x, y, z),
                     scale=(radius * 0.8, radius * 0.7, radius * squash),
                     smooth=True)]
