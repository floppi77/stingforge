"""levels.py -- Komposition der drei Parallax-Ebenen pro Level.

Aufbau jeder Ebene (Kamera orthogonal, 1 Einheit = 1 px, Bild-y = 270 - z):
  far  : opak, Himmelverlauf + 2-3 Atmosphaeren-Silhouetten, niedriger Kontrast
  mid  : transparent, 2-3 Gelaendebaender mit Wertabstufung + Hauptmotive
  near : transparent, wenige grosse dunkle Silhouetten an den Raendern
"""

import math

import bg_lib as L
import motifs as M
import palettes as P
from bg_lib import (HALF_H, HALF_W, HORIZON_Z, TILE_W, Z_BOT, add_ground,
                    add_mesh, add_sky, blend_hex, circle_profile,
                    emission_mat, g_box, g_cyl, g_sweep, mat, new_collection,
                    periodic_curve, relief_waves, use_collection)


# --------------------------------------------------------------------------
# Hilfen
# --------------------------------------------------------------------------
def C(lvl, ramp, idx):
    return P.col(lvl, ramp, idx)


def haze(level, color, amount):
    """Luftperspektive: Farbe Richtung Himmelsfarbe entsaettigen."""
    ramps = P.BY_ID[level]["ramps"]
    sky = ramps.get("sky") or ramps.get("glow")
    return blend_hex(color, sky[-1], amount)


def sil(name, curve, bottom_z, material, y, smooth=False):
    """Silhouette aus periodischer Oberkante als geschlossenes Band.

    Ein Faecher von einem fernen Mittelpunkt aus erzeugte grosse, schief
    beleuchtete Dreiecke (V-foermige Schattierung); ein gleichmaessiges
    Vertikalband ist gleichmaessig beleuchtet.
    """
    n = len(curve)
    verts = [(x, y, z) for (x, z) in curve]
    verts += [(x, y, bottom_z) for (x, z) in curve]
    faces = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    return add_mesh(name, verts, faces, material, smooth=smooth, shade_flat=True)


def band(level, z_base, specs, n=72, haze_amt=0.0, ramp="sky", idx=0,
         name="band", bottom_z=-460.0, y=120.0):
    curve = periodic_curve(specs, n, base=z_base)
    col = haze(level, C(level, ramp, idx), haze_amt)
    return sil(name, curve, bottom_z, emission_mat(col, 1.0), y)


def flat_poly(name, points, material, y, depth=2.0):
    n = len(points)
    verts = [(p[0], y, p[1]) for p in points]
    faces = [tuple(range(n - 1, -1, -1))]
    return add_mesh(name, verts, faces, material, smooth=False, shade_flat=True)


def ridge(specs, base, n=96):
    return periodic_curve(specs, n, base=base)


def sil_top(name, curve, top_z, material, y):
    """Silhouette, die von der Oberkante haengt (Hoehle, Baldachin)."""
    n = len(curve)
    verts = [(x, y, z) for (x, z) in curve]
    verts += [(x, y, top_z) for (x, z) in curve]
    faces = [(i + 1, i, n + i, n + i + 1) for i in range(n - 1)]
    return add_mesh(name, verts, faces, material, shade_flat=True)


def rect(name, xa, xb, za, zb, material, y, wrap=True):
    verts = [(xa, y, za), (xb, y, za), (xb, y, zb), (xa, y, zb)]
    faces = [(0, 1, 2, 3)]
    return add_mesh(name, verts, faces, material, shade_flat=True, wrap=wrap)


def glow(x, z, y, radius, c_core, c_mid, c_edge, squash=1.0, name="glow",
         power=1.0):
    """Weicher radialer Lichtschein (statt harter Kreisscheiben)."""
    m = L.mat_radial(c_core, c_edge, power=power, mid=c_mid, mid_pos=0.46)
    return M.soft_glow(x, z, y, radius, m, name=name, squash=squash)


def near_base(scene, level, specs=None, top_z=-400.0, y=-72.0, name="nearbase",
              lit=2, rim=0.30):
    """Dunkles Vordergrundband am unteren Bildrand (Parallax-Unterseite)."""
    curve = ridge(specs, top_z, n=200)
    m = L.mat_grad(C(level, "dark", 0), C(level, "dark", lit), rough=0.92)
    sil(name, curve, Z_BOT, m, y)
    ridge_light(curve, blend_hex(C(level, "dark", lit), C(level, "dark", 0),
                                 1.0 - rim), y - 0.6, drop=2.2,
                name=name + "_rim")


def cloud_bank(level, z0, specs, col_top, col_bot, y, n=120, thickness=18.0,
               name="cloudbank"):
    """Wolkenband: geschwungene Oberkante, flacher Bauch, zwei Toene."""
    top = periodic_curve(specs, n, base=z0)
    sil(name, top, z0 - thickness, emission_mat(col_top, 1.0), y)
    low = [(x, z - thickness * 0.45) for (x, z) in top]
    sil(name + "_b", low, z0 - thickness * 1.05, emission_mat(col_bot, 1.0),
        y - 0.4)


def ridge_light(curve, color, y, drop=5.0, name="rim"):
    """Helle Kante entlang einer Gelaendelinie (Pixel-Art-Highlight)."""
    top = [(x, z) for (x, z) in curve]
    bot = [(x, z - drop) for (x, z) in curve][::-1]
    verts = [(p[0], y, p[1]) for p in top + bot]
    n = len(top)
    faces = []
    for i in range(n - 1):
        faces.append((i, i + 1, n + i + 1, n + i))
    return add_mesh(name, verts, faces, emission_mat(color, 1.0), smooth=False,
                    shade_flat=True)


# --------------------------------------------------------------------------
# Level 1 -- Bluetenmeer (rosa Himmel, gruene Wiese, riesige Blueten)
# --------------------------------------------------------------------------
def l01_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [
        (0.00, "#cf7ba0"),
        (0.12, "#dd90b0"),
        (0.26, "#eeabc2"),
        (0.40, "#fbc4d2"),
        (0.50, "#ffd9de"),
        (0.56, "#ffe9e4"),
        (0.62, "#ffeedd"),
        (1.00, "#ffe0c6"),
    ],
                    glows=[
                    (0.7354, 0.7333, 0.36, "#f7a8b8", 0.85),
                    (0.7354, 0.7333, 0.13, "#fffaf0", 0.95),
                    ])
    # Sonne: Kern + zwei Hoefe (flach gestempelt)
    use_collection(new_collection(scene, "sun"))

    # Wolkenbaenke (wenige grosse Formen, zwei Toene)
    use_collection(new_collection(scene, "clouds"))
    cloud_bank(1, 200.0, [(18.0, 960.0, 0.7), (12.0, 480.0, 2.1),
                          (7.0, 320.0, 4.4)], "#fbd3da", "#eeb4c6",
               158.0, thickness=46.0, name="cb1")
    cloud_bank(1, 240.0, [(14.0, 1920.0, 2.6), (10.0, 640.0, 0.4),
                          (6.0, 240.0, 3.1)], "#ffe4e0", "#f4c2ce",
               157.6, thickness=26.0, name="cb2")

    # Drei Huegelbaender: weiter hinten = heller und verwaeschter
    use_collection(new_collection(scene, "hills"))
    band(1, HORIZON_Z + 62.0,
         [(16.0, 1920.0, 0.4), (11.0, 640.0, 1.1), (7.0, 320.0, 2.2),
          (4.0, 160.0, 0.7)], haze_amt=0.66, idx=4, name="hill1", y=136.0)
    band(1, HORIZON_Z + 34.0,
         [(18.0, 960.0, 2.3), (12.0, 480.0, 0.5), (7.0, 240.0, 3.4)],
         haze_amt=0.44, idx=3, name="hill2", y=133.0)
    band(1, HORIZON_Z + 4.0,
         [(15.0, 640.0, 4.6), (10.0, 320.0, 1.7), (6.0, 160.0, 5.1)],
         haze_amt=0.20, idx=2, name="hill3", y=130.0)


def l01_mid(scene, rnd):
    # ---- hinteres Feld ------------------------------------------------
    use_collection(new_collection(scene, "field_back"))
    top = ridge([(20.0, 1920.0, 1.4), (12.0, 960.0, 4.0), (7.0, 480.0, 2.2),
                 (3.2, 160.0, 0.8), (1.8, 80.0, 3.3)], HORIZON_Z - 8.0, n=160)
    g_back = L.mat_grad(C(1, "ground", 1), C(1, "ground", 5), rough=0.95,
                        mid=C(1, "ground", 4), mid_pos=0.55)
    add_ground("field_back", top, g_back, y_back=120.0, y_front=24.0,
               z_bottom=-620.0,
               relief=relief_waves([(13.0, 960.0, 0.6, 0.1),
                                    (7.0, 320.0, 2.4, 0.45),
                                    (4.0, 160.0, 4.0, 0.8)]), nd=8)
    # ---- vorderes Feld / Boeschung ------------------------------------
    use_collection(new_collection(scene, "field_front"))
    top2 = ridge([(16.0, 1920.0, 3.9), (10.0, 640.0, 1.2), (6.0, 320.0, 5.0),
                  (2.6, 120.0, 1.7)], -168.0, n=160)
    g_front = L.mat_grad(C(1, "ground", 0), C(1, "ground", 2), rough=0.95,
                         mid=C(1, "ground", 1), mid_pos=0.6)
    add_ground("field_front", top2, g_front, y_back=22.0, y_front=-52.0,
               z_bottom=-620.0,
               relief=relief_waves([(10.0, 640.0, 2.1, 0.2),
                                    (6.0, 240.0, 0.3, 0.6)]), nd=7)

    # ---- grosse Blueten (Hauptsilhouetten) ----------------------------
    use_collection(new_collection(scene, "flowers"))
    stem_m = mat(haze(1, C(1, "leaf", 0), 0.18), rough=0.85)
    leaf_m = mat(haze(1, C(1, "leaf", 1), 0.12), rough=0.8)
    petal_a = mat(C(1, "flower", 2), rough=0.5, sss=0.45, spec=0.5)
    petal_b = mat(C(1, "flower", 1), rough=0.55, sss=0.4, spec=0.5)
    core_m = mat(C(1, "accent", 1), rough=0.65, emis=C(1, "accent", 1),
                 emis_str=0.30)

    flowers = [
        (-742.0, 96.0, 104.0, 46.0, 24.0),
        (-330.0, 34.0, 72.0, 30.0, -18.0),
        (96.0, 118.0, 88.0, 44.0, 30.0),
        (470.0, 22.0, 64.0, 22.0, -22.0),
        (742.0, 104.0, 96.0, 40.0, -28.0),
        (1042.0, 60.0, 80.0, 34.0, 20.0),
    ]
    for i, (x, ztop, br, dy, bend) in enumerate(flowers):
        zbase = -56.0
        pts, profs = [], []
        segs = 9
        for s in range(segs):
            t = s / (segs - 1)
            pts.append((x + bend * (t ** 2.0), dy, zbase + (ztop - zbase) * t))
            r = 6.2 - 2.6 * t
            profs.append(circle_profile(8, r, r))
        v, f = g_sweep(pts, profs)
        add_mesh("stem%d" % i, v, f, stem_m, smooth=True)
        for k in range(2):
            t = 0.34 + 0.24 * k
            M.leaf(x + bend * (t ** 2.0), zbase + (ztop - zbase) * t, dy - 5.0,
                   96.0 - 16.0 * k, 34.0,
                   (28.0 if k % 2 == 0 else -26.0) + rnd.uniform(-10.0, 10.0),
                   leaf_m, bend=0.28)
        M.flower(x + bend, ztop, dy - 9.0, br, petal_a, petal_b, core_m, rnd,
                 petals=8, layers=2, cup=0.24)

    # ---- Gras auf dem hinteren Grat (in Gruppen) ----------------------
    use_collection(new_collection(scene, "grass_back"))
    g_grass = mat(haze(1, C(1, "leaf", 0), 0.22), rough=0.9)
    ridge_light(top, blend_hex(C(1, "ground", 5), C(1, "ground", 4), 0.4),
                25.0, drop=2.5, name="ridge_hi")
    for i in range(9):
        cx = -900.0 + i * 214.0 + rnd.uniform(-30.0, 30.0)
        zc = HORIZON_Z - 8.0 + 20.0 * math.sin(cx / 306.0)
        for k in range(3):
            M.tuft(cx + rnd.uniform(-34.0, 34.0), zc - 6.0, 30.0, 5,
                   rnd.uniform(26.0, 48.0), 10.0, rnd, g_grass,
                   width=8.0, name="gras_b", z_jitter=5.0)

    # ---- Mittelgrund: Bueschel und kleine Blueten ---------------------
    use_collection(new_collection(scene, "bushes"))
    bush_m = mat(C(1, "leaf", 0), rough=0.9)
    for i in range(9):
        x = -880.0 + i * 214.0 + rnd.uniform(-30.0, 30.0)
        z = -172.0 + 16.0 * math.sin(x / 214.0)
        for k in range(4):
            M.leaf(x + rnd.uniform(-26.0, 26.0), z, -10.0,
                   rnd.uniform(70.0, 108.0), rnd.uniform(30.0, 42.0),
                   rnd.uniform(52.0, 128.0), bush_m, bend=0.55)
    pm = mat(C(1, "flower", 3), rough=0.55, sss=0.4)
    pm2 = mat(C(1, "flower", 2), rough=0.55, sss=0.35)
    for i in range(14):
        x = rnd.uniform(-930.0, 930.0)
        z = rnd.uniform(-210.0, -168.0)
        M.flower(x, z, -8.0, rnd.uniform(15.0, 26.0), pm, pm2, core_m, rnd,
                 petals=6, layers=1, cup=0.2)


def l01_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 1, [(34.0, 960.0, 1.4), (20.0, 320.0, 3.7), (10.0, 160.0, 0.6)], top_z=-420.0)
    dark = mat(C(1, "dark", 1), rough=0.95)
    darker = mat(C(1, "dark", 0), rough=0.95)
    dark2 = mat(C(1, "dark", 2), rough=0.9)

    # --- unterer Rand: Blattbueschel, nur in den aeusseren Dritteln ---
    clusters = [(-905.0, 205.0, 96.0, -124.0, -66.0),
                (-590.0, 150.0, 70.0, -108.0, -62.0),
                (556.0, 158.0, 74.0, -74.0, -56.0),
                (900.0, 215.0, 100.0, -116.0, -60.0)]
    for (x, ln, wd, ang_lo, ang_hi) in clusters:
        base_z = -286.0
        for k in range(6):
            t = k / 5.0
            ang = ang_lo + (ang_hi - ang_lo) * t + rnd.uniform(-6.0, 6.0)
            m = dark if k % 3 else darker
            M.leaf(x + rnd.uniform(-40.0, 40.0),
                   base_z + rnd.uniform(-12.0, 8.0),
                   -60.0 + rnd.uniform(-8.0, 8.0),
                   ln * rnd.uniform(0.86, 1.14), wd * rnd.uniform(0.85, 1.12),
                   ang, m, bend=rnd.uniform(0.44, 0.62))
        M.tuft(x, base_z + 60.0, -58.0, 5, rnd.uniform(120.0, 170.0), 26.0,
               rnd, dark2, width=9.0, name="near_halm", z_jitter=8.0)

    # --- oberer Rand: haengende Blaetter, links und rechts ---
    for x, ln, wd, a0, a1 in [(-760.0, 150.0, 66.0, 62.0, 122.0),
                              (820.0, 160.0, 70.0, 58.0, 118.0)]:
        for k in range(5):
            t = k / 4.0
            ang = a0 + (a1 - a0) * t + rnd.uniform(-6.0, 6.0)
            M.leaf(x + rnd.uniform(-54.0, 54.0), HALF_H + 30.0,
                   -60.0 + rnd.uniform(-8.0, 8.0),
                   ln * rnd.uniform(0.85, 1.12), wd * rnd.uniform(0.85, 1.1),
                   ang, dark if k % 2 else darker, bend=0.34)


# --------------------------------------------------------------------------
# Level 2 -- Wurzelreich (dunkles Braun/Ocker, Erdhoehlen, dicke Wurzeln)
# --------------------------------------------------------------------------
def l02_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#150d06"), (0.18, "#22160c"), (0.38, "#33230f"),
                    (0.52, "#4a3318"), (0.60, "#63441f"), (1.00, "#7a5527")],
                    glows=[
                    (0.4271, 0.4444, 0.7, "#a87a3c", 0.55),
                    (0.4271, 0.4444, 0.28, "#c79a52", 0.35),
                    ])
    use_collection(new_collection(scene, "glow"))
    use_collection(new_collection(scene, "walls"))
    band(2, HORIZON_Z + 58.0, [(26.0, 960.0, 0.6), (14.0, 480.0, 2.4),
                               (8.0, 240.0, 4.1)],
         haze_amt=0.58, ramp="root", idx=4, name="wall1", y=136.0)
    band(2, HORIZON_Z + 18.0, [(20.0, 640.0, 3.2), (12.0, 320.0, 0.9),
                               (7.0, 160.0, 5.3)],
         haze_amt=0.32, ramp="root", idx=2, name="wall2", y=132.0)
    band(2, HORIZON_Z - 16.0, [(15.0, 480.0, 1.5), (9.0, 240.0, 3.8),
                               (5.0, 120.0, 0.4)],
         haze_amt=0.10, ramp="root", idx=1, name="wall3", y=129.0)
    ceil = ridge([(26.0, 960.0, 2.1), (15.0, 320.0, 4.6), (8.0, 160.0, 1.1),
                  (5.0, 80.0, 3.0)], HALF_H - 52.0, n=140)
    sil_top("ceiling", ceil, HALF_H + 60.0,
            emission_mat(haze(2, C(2, "root", 0), 0.10), 1.0), 127.0)


def l02_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(18.0, 1920.0, 2.2), (11.0, 640.0, 4.9), (7.0, 320.0, 1.3),
                 (3.5, 120.0, 3.6)], -58.0, n=160)
    g = L.mat_grad(C(2, "ground", 0), C(2, "ground", 4),
                   mid=C(2, "ground", 2), mid_pos=0.45, rough=0.95)
    add_ground("dirt", top, g, 120.0, -40.0, -620.0,
               relief=relief_waves([(16.0, 640.0, 1.7, 0.15),
                                    (9.0, 240.0, 3.2, 0.5),
                                    (4.0, 120.0, 0.7, 0.85)]), nd=18)

    # dicke Wurzeln, die aus dem Boden wachsen
    use_collection(new_collection(scene, "roots"))
    root_m = mat(C(2, "root", 2), rough=0.95)
    root_d = mat(C(2, "root", 1), rough=0.95)
    for i, (x, ln, rad, ang, y) in enumerate([
            (-820.0, 620.0, 34.0, 24.0, 40.0),
            (-260.0, 520.0, 26.0, 156.0, 30.0),
            (180.0, 700.0, 38.0, 18.0, 46.0),
            (620.0, 480.0, 24.0, 168.0, 26.0),
            (980.0, 560.0, 30.0, 158.0, 34.0)]):
        M.root(x, -52.0, y, ln, rad, root_m if i % 2 == 0 else root_d, rnd,
               angle_deg=ang, wiggle=0.5, taper=0.35, branches=2)

    # Wurzelboegen ueber dem Boden
    use_collection(new_collection(scene, "arches"))
    for x, r, t, y in [(-520.0, 150.0, 26.0, 20.0), (320.0, 190.0, 30.0, 18.0)]:
        M.arch(x, -60.0, r, t, root_d, span=170.0, z_scale=0.9, name="rootarch")

    # Erloecher mit hellem Rand
    use_collection(new_collection(scene, "holes"))
    hole_m = emission_mat("#120b06", 1.0)
    for x, r in [(-640.0, 58.0), (40.0, 74.0), (700.0, 50.0)]:
        M.pyxis(x, -96.0, 12.0, r, hole_m, squash=1.15)
        M.arch(x, -96.0 + r * 0.15, r * 1.02, 3.2,
               emission_mat(C(2, "accent", 2), 1.0), span=170.0, segs=10,
               name="holerim")

    # kleine Pilze und Gluehpunkte
    use_collection(new_collection(scene, "detail"))
    glow_m = emission_mat(C(2, "accent", 2), 1.0)
    stem_m = mat(C(2, "root", 4), rough=0.9)
    cap_m = mat(C(2, "accent", 0), rough=0.7, emis=C(2, "accent", 1),
                emis_str=0.5)
    for i in range(9):
        x = rnd.uniform(-930.0, 930.0)
        M.mushroom(x, rnd.uniform(-150.0, -80.0), 4.0,
                   rnd.uniform(16.0, 30.0), rnd.uniform(8.0, 15.0),
                   stem_m, cap_m, rnd=rnd, name="pilz")
    for i in range(16):
        M.glow_dot(rnd.uniform(-930.0, 930.0), rnd.uniform(-170.0, -40.0),
                   -4.0, rnd.uniform(1.6, 3.2), glow_m, name="spore")


def l02_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 2, [(40.0, 960.0, 2.6), (22.0, 320.0, 0.9), (12.0, 160.0, 4.2)], top_z=-430.0)
    dark = mat(C(2, "dark", 1), rough=0.95)
    darker = mat(C(2, "dark", 0), rough=0.95)
    # Wurzeln, die den unteren Rand queren
    M.root(-940.0, -300.0, -62.0, 1250.0, 46.0, dark, rnd, angle_deg=13.0,
           wiggle=0.6, taper=0.25, name="nroot")
    M.root(-380.0, -300.0, -58.0, 900.0, 34.0, darker, rnd, angle_deg=20.0,
           wiggle=0.8, taper=0.3, name="nroot")
    M.root(420.0, -300.0, -60.0, 1000.0, 40.0, dark, rnd, angle_deg=9.0,
           wiggle=0.5, taper=0.3, name="nroot")
    # Wurzelspitzen von oben
    for x, ln in [(-780.0, 300.0), (-120.0, 240.0), (520.0, 280.0),
                  (1010.0, 210.0)]:
        M.root(x, HALF_H + 30.0, -64.0, ln, 26.0, darker, rnd,
               angle_deg=rnd.uniform(255.0, 290.0), wiggle=0.7, taper=0.75,
               name="nroot_top")
    # dunkle Erdklumpen am unteren Rand
    for x in (-700.0, -30.0, 700.0):
        M.rock(x, -520.0, -56.0, rnd.uniform(90.0, 140.0), dark, rnd,
               name="clod", squash=0.7)


# --------------------------------------------------------------------------
# Level 3 -- Schilf und Teich (hellblau/tuerkis, Wasser, Schilf, Seerosen)
# --------------------------------------------------------------------------
def l03_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#4c9fb4"), (0.16, "#6fc0cc"), (0.32, "#96dce0"),
                    (0.46, "#c8f2ef"), (0.54, "#eafff8"), (0.57, "#d6f4ee"),
                    (0.66, "#8fd8d0"), (0.82, "#4fb0b8"), (1.00, "#2a8a96")],
                    glows=[
                    (0.3021, 0.6778, 0.34, "#ffffff", 0.85),
                    (0.3021, 0.6778, 0.12, "#ffffff", 0.95),
                    ])
    use_collection(new_collection(scene, "sun"))
    use_collection(new_collection(scene, "clouds"))
    cloud_bank(3, 176.0, [(14.0, 960.0, 1.1), (9.0, 480.0, 3.6),
                          (6.0, 240.0, 0.2)], "#f2fffb", "#cdeef0",
               158.0, thickness=34.0, name="cb1")
    cloud_bank(3, 118.0, [(9.0, 640.0, 2.7), (6.0, 320.0, 5.2)],
               "#e8fbf8", "#c6e9ee", 157.6, thickness=20.0, name="cb2")
    # Ferne Ufer / Huegel
    use_collection(new_collection(scene, "hills"))
    band(3, HORIZON_Z + 40.0, [(14.0, 960.0, 0.9), (9.0, 320.0, 2.8),
                               (5.0, 160.0, 4.4)],
         haze_amt=0.62, ramp="water", idx=2, name="h1", y=134.0)
    band(3, HORIZON_Z + 12.0, [(11.0, 640.0, 3.5), (8.0, 240.0, 1.2),
                               (4.0, 120.0, 5.0)],
         haze_amt=0.38, ramp="water", idx=1, name="h2", y=131.0)
    # Lichtreflexe auf dem Wasser
    use_collection(new_collection(scene, "shimmer"))
    sh = emission_mat("#d8f7ef", 1.0)
    for i in range(16):
        z = HORIZON_Z - 6.0 - i * 6.4 - rnd.uniform(0.0, 3.0)
        x = rnd.uniform(-940.0, 940.0)
        w = rnd.uniform(60.0, 220.0) * (1.0 + i * 0.04)
        rect("shimmer", x, x + w, z + 1.6, z, sh, 128.0)


def l03_mid(scene, rnd):
    use_collection(new_collection(scene, "water"))
    top = ridge([(3.0, 1920.0, 1.0), (2.0, 480.0, 3.0)], HORIZON_Z + 2.0, n=120)
    g = L.mat_grad(C(3, "water", 0), C(3, "water", 3),
                   mid=C(3, "water", 1), mid_pos=0.5, rough=0.25,
                   name="water")
    add_ground("water", top, g, 110.0, -30.0, -620.0,
               relief=relief_waves([(4.0, 320.0, 1.2, 0.2),
                                    (2.4, 120.0, 3.4, 0.6)]), nd=14)
    # Wellenlinien
    use_collection(new_collection(scene, "waves"))
    wav = emission_mat(C(3, "accent", 1), 1.0)
    for i in range(11):
        z = -34.0 - i * 22.0
        x = rnd.uniform(-940.0, 700.0)
        w = rnd.uniform(120.0, 320.0)
        rect("wave", x, x + w, z + 1.4, z, wav, 20.0)
    # Schilf
    use_collection(new_collection(scene, "reeds"))
    reed_m = mat(C(3, "reed", 1), rough=0.85)
    head_m = mat(C(3, "reed", 3), rough=0.8, sss=0.2)
    for i in range(26):
        x = -940.0 + i * 76.0 + rnd.uniform(-30.0, 30.0)
        z = rnd.uniform(-250.0, -90.0)
        M.reed(x, z, rnd.uniform(-20.0, 60.0), rnd.uniform(150.0, 300.0), rnd,
               reed_m, head_m if rnd.random() < 0.55 else None,
               lean=rnd.uniform(-0.10, 0.10), width=rnd.uniform(2.0, 3.4))
    # grosse Blaetter (Iris)
    use_collection(new_collection(scene, "leaves"))
    leaf_m = mat(C(3, "reed", 2), rough=0.85)
    for i in range(7):
        x = -900.0 + i * 300.0 + rnd.uniform(-60.0, 60.0)
        for k in range(4):
            M.leaf(x + rnd.uniform(-30.0, 30.0), rnd.uniform(-220.0, -120.0),
                   rnd.uniform(-6.0, 20.0), rnd.uniform(110.0, 170.0),
                   rnd.uniform(24.0, 34.0), rnd.uniform(-124.0, -50.0),
                   leaf_m, bend=0.5)
    # Seerosen
    use_collection(new_collection(scene, "pads"))
    pad_m = mat(C(3, "reed", 3), rough=0.6)
    fl_m = mat(C(3, "flower", 2), rough=0.55, sss=0.4)
    fl_m2 = mat(C(3, "flower", 1), rough=0.55, sss=0.4)
    core = mat(C(3, "accent", 1), rough=0.6, emis=C(3, "accent", 1),
               emis_str=0.2)
    for i in range(6):
        x = rnd.uniform(-900.0, 900.0)
        z = rnd.uniform(-250.0, -120.0)
        r = rnd.uniform(40.0, 70.0)
        M.lily_pad(x, z, -6.0, r, pad_m, rnd=rnd, name="pad")
        if i % 2 == 0:
            M.flower(x + rnd.uniform(-10.0, 10.0), z + r * 0.35, -12.0,
                     rnd.uniform(14.0, 22.0), fl_m, fl_m2, core, rnd,
                     petals=7, layers=1, cup=0.3)


def l03_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 3, [(18.0, 960.0, 1.9), (12.0, 320.0, 4.4), (6.0, 160.0, 1.1)])
    dark = mat(C(3, "dark", 1), rough=0.95)
    darker = mat(C(3, "dark", 0), rough=0.95)
    # Schilfbueschel am unteren Rand
    for x, h in [(-900.0, 210.0), (-640.0, 160.0), (520.0, 175.0),
                 (880.0, 220.0)]:
        for k in range(7):
            M.reed(x + rnd.uniform(-46.0, 46.0), -286.0, -60.0,
                   h * rnd.uniform(0.7, 1.15), rnd, dark if k % 2 else darker,
                   None, lean=rnd.uniform(-0.06, 0.06),
                   width=rnd.uniform(4.0, 6.0), name="nreed")
        M.tuft(x, -286.0, -58.0, 5, h * 0.8, 30.0, rnd, darker, width=9.0,
               name="nreed_t")
    # dunkle Blaetter oben
    for x, ln in [(-820.0, 190.0), (300.0, 210.0), (960.0, 170.0)]:
        for k in range(4):
            M.leaf(x + rnd.uniform(-50.0, 50.0), HALF_H + 24.0, -62.0, ln,
                   56.0, rnd.uniform(58.0, 118.0), dark if k % 2 else darker,
                   bend=0.4)


# --------------------------------------------------------------------------
# Level 4 -- Pilzwald (dunkles Blau/Violett, biolumineszente Pilze)
# --------------------------------------------------------------------------
def l04_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#0a0816"), (0.24, "#14122c"), (0.44, "#1d1b3c"),
                    (0.58, "#2a2450"), (1.00, "#191430")],
                    glows=[
                    (0.3646, 0.463, 0.72, "#2f7f96", 0.5),
                    (0.7188, 0.4444, 0.52, "#2a7f8a", 0.4),
                    ])
    use_collection(new_collection(scene, "glow"))
    # ferne Pilzsilhouetten
    use_collection(new_collection(scene, "far_mush"))
    fm = emission_mat(haze(4, C(4, "cap", 0), 0.55), 1.0)
    for i in range(9):
        x = -900.0 + i * 210.0 + rnd.uniform(-40.0, 40.0)
        h = rnd.uniform(70.0, 150.0)
        r = rnd.uniform(34.0, 70.0)
        v, f = g_sweep([(x, 138.0, HORIZON_Z + 10.0),
                        (x, 138.0, HORIZON_Z + 10.0 + h)],
                       [circle_profile(10, r * 0.16, r * 0.16),
                        circle_profile(10, r * 0.13, r * 0.13)])
        add_mesh("fstem", v, f, fm, smooth=True)
        M.glow_dot(x, HORIZON_Z + 10.0 + h, 138.0, r, fm, name="fcap",
                   squash=0.7)
    # Dunstbaender
    use_collection(new_collection(scene, "fog"))
    cloud_bank(4, HORIZON_Z + 30.0, [(7.0, 960.0, 0.4), (5.0, 320.0, 2.6)],
               "#2b2650", "#211d3c", 136.0, thickness=18.0, name="fog1")


def l04_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(16.0, 1920.0, 2.8), (10.0, 640.0, 0.7), (6.0, 320.0, 4.2),
                 (3.0, 120.0, 1.9)], -50.0, n=160)
    g = L.mat_grad(C(4, "ground", 0), C(4, "ground", 3),
                   mid=C(4, "ground", 1), mid_pos=0.5, rough=0.95)
    add_ground("moss", top, g, 118.0, -38.0, -620.0,
               relief=relief_waves([(14.0, 480.0, 2.2, 0.15),
                                    (7.0, 160.0, 4.6, 0.6)]), nd=16)

    use_collection(new_collection(scene, "mushrooms"))
    stem_m = mat(C(4, "cap", 0), rough=0.9)
    stem_m2 = mat(C(4, "ground", 2), rough=0.9)
    cap_m = mat(C(4, "cap", 2), rough=0.45, sss=0.4, spec=0.6,
                emis=C(4, "glow", 1), emis_str=0.18)
    cap_m2 = mat(C(4, "cap", 1), rough=0.5, sss=0.35,
                 emis=C(4, "glow", 0), emis_str=0.12)
    gill = emission_mat(C(4, "glow", 2), 1.0)
    big = [(-820.0, 250.0, 92.0, 44.0), (-330.0, 190.0, 70.0, 30.0),
           (120.0, 300.0, 108.0, 50.0), (560.0, 210.0, 78.0, 34.0),
           (900.0, 260.0, 96.0, 42.0)]
    for i, (x, h, r, y) in enumerate(big):
        M.mushroom(x, -58.0, y, h, r, stem_m if i % 2 == 0 else stem_m2,
                   cap_m if i % 2 == 0 else cap_m2, gill, rnd=rnd,
                   lean=rnd.uniform(-0.10, 0.10), name="gmush")
    use_collection(new_collection(scene, "small"))
    for i in range(14):
        x = rnd.uniform(-930.0, 930.0)
        M.mushroom(x, rnd.uniform(-190.0, -70.0), rnd.uniform(-10.0, 30.0),
                   rnd.uniform(26.0, 56.0), rnd.uniform(14.0, 28.0), stem_m2,
                   cap_m2, gill if i % 3 == 0 else None, rnd=rnd,
                   name="smush")
    # Leuchtsporen
    use_collection(new_collection(scene, "spores"))
    sp = emission_mat(C(4, "glow", 2), 1.0)
    for i in range(26):
        M.glow_dot(rnd.uniform(-940.0, 940.0), rnd.uniform(-200.0, 150.0),
                   rnd.uniform(-30.0, 20.0), rnd.uniform(1.4, 3.4), sp,
                   name="spore")


def l04_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 4, [(30.0, 960.0, 0.8), (18.0, 320.0, 3.2), (10.0, 160.0, 5.5)])
    dark = mat(C(4, "dark", 1), rough=0.95)
    darker = mat(C(4, "dark", 0), rough=0.95)
    # dunkle Pilze / Stiele am unteren Rand
    for x, h, r in [(-880.0, 230.0, 88.0), (-260.0, 170.0, 62.0),
                    (560.0, 190.0, 70.0), (930.0, 240.0, 92.0)]:
        M.mushroom(x, -520.0, -62.0, h, r, darker, dark, None, rnd=rnd,
                   name="nmush", lean=rnd.uniform(-0.12, 0.12))
    for x in (-620.0, 40.0, 760.0):
        M.tuft(x, -520.0, -60.0, 7, rnd.uniform(110.0, 170.0), 40.0, rnd,
               darker, width=11.0, name="ngras")
    # haengende Ranken oben
    for x, ln in [(-700.0, 260.0), (180.0, 300.0), (1000.0, 220.0)]:
        M.vine(x, HALF_H + 20.0, -64.0, ln, darker, rnd, angle_deg=-90.0,
               wiggle=0.7, radius=7.0, name="nvine")


# --------------------------------------------------------------------------
# Level 5 -- Dornen im Sturm (violett/grau, Sturmwolken, Dornenranken)
# --------------------------------------------------------------------------
def l05_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#241f2e"), (0.16, "#332d42"), (0.34, "#4a4460"),
                    (0.48, "#6d6585"), (0.58, "#8f87a8"), (1.00, "#5e5873")],
                    glows=[
                    (0.6771, 0.6111, 0.5, "#cfc0ff", 0.5),
                    ])
    use_collection(new_collection(scene, "clouds"))
    cloud_bank(5, 150.0, [(26.0, 1920.0, 1.0), (18.0, 640.0, 3.3),
                          (11.0, 320.0, 0.4), (6.0, 160.0, 5.1)],
               "#57516c", "#3e3950", 156.0, thickness=64.0, name="cb1")
    cloud_bank(5, 210.0, [(20.0, 960.0, 2.4), (13.0, 480.0, 5.6),
                          (7.0, 240.0, 1.3)], "#6a6382", "#4c4660",
               155.6, thickness=48.0, name="cb2")
    cloud_bank(5, 96.0, [(14.0, 640.0, 4.2), (9.0, 320.0, 0.8),
                         (5.0, 160.0, 2.9)], "#453f58", "#332e44",
               155.2, thickness=40.0, name="cb3")
    # fahles Leuchten im Sturm
    use_collection(new_collection(scene, "light"))
    # ferne Baumreihe
    use_collection(new_collection(scene, "trees"))
    tm = emission_mat(haze(5, C(5, "thorn", 2), 0.45), 1.0)
    for i in range(7):
        x = -900.0 + i * 300.0 + rnd.uniform(-50.0, 50.0)
        h = rnd.uniform(90.0, 170.0)
        M.root(x, HORIZON_Z + 4.0, 133.0, h, 13.0, None, rnd,
               angle_deg=88.0, wiggle=0.9, taper=0.7, name="ftree")
    for i in range(6):
        x = -880.0 + i * 340.0
        M.root(x, HORIZON_Z + 4.0, 133.0, 60.0, 8.0, tm, rnd,
               angle_deg=52.0, wiggle=0.6, taper=0.8, name="fbranch")


def l05_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(18.0, 1920.0, 0.6), (11.0, 640.0, 3.1), (6.0, 320.0, 5.2),
                 (3.0, 120.0, 2.0)], HORIZON_Z - 6.0, n=160)
    g = L.mat_grad(C(5, "grass", 0), C(5, "grass", 3),
                   mid=C(5, "grass", 1), mid_pos=0.5, rough=0.95)
    add_ground("ground", top, g, 116.0, -40.0, -620.0,
               relief=relief_waves([(16.0, 960.0, 1.4, 0.15),
                                    (8.0, 240.0, 3.9, 0.6)]), nd=16)
    # Windgebeugtes Gras
    use_collection(new_collection(scene, "grass"))
    gm = mat(C(5, "grass", 1), rough=0.9)
    gm2 = mat(C(5, "grass", 0), rough=0.9)
    for i in range(15):
        x = -930.0 + i * 130.0 + rnd.uniform(-40.0, 40.0)
        z = HORIZON_Z - 10.0 + 22.0 * math.sin(x / 306.0)
        M.tuft(x, z, 20.0, 6, rnd.uniform(40.0, 80.0), 16.0, rnd,
               gm if i % 2 else gm2, lean_range=(0.05, 0.30), width=8.0,
               name="wgrass")
    # kahle, verdrehte Baeume
    use_collection(new_collection(scene, "trees"))
    trunk = mat(C(5, "thorn", 3), rough=0.92)
    trunk2 = mat(C(5, "thorn", 2), rough=0.92)
    for i, (x, h, y) in enumerate([(-700.0, 260.0, 34.0), (-80.0, 200.0, 26.0),
                                   (520.0, 280.0, 40.0), (980.0, 210.0, 24.0)]):
        M.root(x, -40.0, y, h, 20.0, trunk if i % 2 == 0 else trunk2, rnd,
               angle_deg=rnd.uniform(76.0, 96.0), wiggle=0.85, taper=0.55,
               branches=3, name="tree")
    # Dornenranken
    use_collection(new_collection(scene, "thorns"))
    vine_m = mat(C(5, "thorn", 2), rough=0.9)
    thorn_m = mat(C(5, "thorn", 1), rough=0.85)
    for x, z, ln, ang in [(-520.0, -170.0, 420.0, 22.0),
                          (240.0, -180.0, 380.0, 158.0),
                          (760.0, -140.0, 320.0, 18.0)]:
        M.vine(x, z, 6.0, ln, vine_m, rnd, angle_deg=ang, wiggle=0.9,
               radius=9.0, thorns=7, thorn_mat=thorn_m, name="vine")
    # lose Blaetter im Wind
    use_collection(new_collection(scene, "leaves"))
    lm = mat(C(5, "grass", 1), rough=0.9)
    for i in range(18):
        M.leaf(rnd.uniform(-930.0, 930.0), rnd.uniform(-210.0, 120.0), 6.0,
               rnd.uniform(14.0, 26.0), rnd.uniform(7.0, 12.0),
               rnd.uniform(-180.0, 180.0), lm, bend=0.2)


def l05_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 5, [(36.0, 960.0, 3.4), (20.0, 320.0, 1.2), (12.0, 160.0, 4.8)])
    dark = mat(C(5, "dark", 1), rough=0.95)
    darker = mat(C(5, "dark", 0), rough=0.95)
    for x, ln, ang in [(-880.0, 620.0, -8.0), (700.0, 640.0, 188.0)]:
        M.vine(x, -470.0, -60.0, ln, dark, rnd, angle_deg=ang, wiggle=0.85,
               radius=22.0, thorns=7, thorn_mat=darker, name="nv")
    for x in (-520.0, 140.0, 860.0):
        M.tuft(x, -455.0, -58.0, 7, rnd.uniform(200.0, 300.0), 52.0, rnd,
               darker, lean_range=(0.08, 0.34), width=16.0, name="ngras")
    # Dornenzweig oben
    M.vine(-180.0, HALF_H + 10.0, -62.0, 400.0, darker, rnd,
           angle_deg=-96.0, wiggle=0.7, radius=13.0, thorns=5, thorn_mat=dark,
           name="nvtop")
    M.vine(700.0, HALF_H + 10.0, -62.0, 330.0, dark, rnd, angle_deg=-104.0,
           wiggle=0.6, radius=11.0, thorns=4, thorn_mat=darker, name="nvtop")


# --------------------------------------------------------------------------
# Level 6 -- Glaesernes Gewaechshaus (helles Zyan/Weiss, Glasstreben)
# --------------------------------------------------------------------------
def l06_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#7fc8dc"), (0.22, "#a6e0ee"), (0.42, "#d8f7fb"),
                    (0.54, "#f2ffff"), (1.00, "#e2f7fb")],
                    glows=[
                    (0.3438, 0.6667, 0.6, "#ffffff", 0.8),
                    (0.3438, 0.6667, 0.18, "#ffffff", 0.9),
                    ])
    use_collection(new_collection(scene, "light"))
    # riesige Glaswand mit Sprossen
    use_collection(new_collection(scene, "glasswall"))
    mull = emission_mat(haze(6, C(6, "frame", 2), 0.78), 1.0)
    pane = emission_mat(haze(6, C(6, "sky", 3), 0.72), 1.0)
    for i in range(9):
        x = -960.0 + i * 240.0
        rect("pane", x + 4.0, x + 236.0, HORIZON_Z + 260.0, HORIZON_Z - 4.0,
             pane, 140.0)
    for i in range(9):
        x = -960.0 + i * 240.0
        w = 5.0
        rect("mull", x - w, x + w, HALF_H + 40.0, HORIZON_Z - 4.0, mull, 139.0)
    for k in range(4):
        z = HORIZON_Z + 40.0 + k * 62.0
        rect("mullh", -960.0, 960.0, z + 3.0, z, mull, 139.2)
    # Bogen oben
    for i in range(9):
        x = -960.0 + i * 240.0 + 120.0
        M.arch(x, HORIZON_Z + 250.0, 118.0, 5.0, mull, span=180.0, segs=12,
               z_scale=0.55, name="arc")
    # draussen: ferne Vegetation
    use_collection(new_collection(scene, "outside"))
    veg = emission_mat(haze(6, C(6, "plant", 1), 0.55), 1.0)
    for i in range(8):
        x = -900.0 + i * 250.0 + rnd.uniform(-40.0, 40.0)
        M.cloud(x, HORIZON_Z + 20.0, 137.0, rnd.uniform(160.0, 280.0),
                rnd.uniform(40.0, 70.0), veg, rnd, puffs=4, name="bush")
    # Lichtreflexe
    use_collection(new_collection(scene, "glints"))
    gl = emission_mat("#ffffff", 1.0)
    for i in range(10):
        x = rnd.uniform(-940.0, 900.0)
        z = rnd.uniform(HORIZON_Z + 20.0, 240.0)
        rect("glint", x, x + rnd.uniform(50.0, 140.0), z + 2.0, z, gl, 138.6)


def l06_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(10.0, 1920.0, 2.0), (6.0, 480.0, 4.4), (3.0, 160.0, 0.9)],
                HORIZON_Z - 10.0, n=120)
    g = L.mat_grad(C(6, "frame", 3), C(6, "glass", 2),
                   mid=C(6, "glass", 0), mid_pos=0.5, rough=0.4)
    add_ground("floor", top, g, 118.0, -40.0, -620.0,
               relief=relief_waves([(8.0, 960.0, 1.0, 0.2),
                                    (4.0, 240.0, 3.7, 0.6)]), nd=14)
    # grosse Bogenrahmen im Raum
    use_collection(new_collection(scene, "frames"))
    beam_m = mat(C(6, "frame", 2), rough=0.5, metal=0.2, spec=0.6)
    beam_d = mat(C(6, "frame", 1), rough=0.55, metal=0.2)
    for i, x in enumerate([-820.0, -380.0, 60.0, 500.0, 940.0]):
        M.arch(x, -60.0, 250.0, 9.0, beam_m, span=180.0, segs=16,
               z_scale=1.0, name="bigarch")
        M.bar((x - 250.0, 30.0, -60.0), (x - 250.0, 30.0, -62.0), 8.0,
              beam_d, name="col")
        M.bar((x + 250.0, 30.0, -60.0), (x + 250.0, 30.0, -62.0), 8.0,
              beam_d, name="col")
    # horizontale Traversen
    use_collection(new_collection(scene, "trusses"))
    for z, y in [(120.0, 26.0), (-30.0, 20.0)]:
        for i in range(6):
            x = -900.0 + i * 320.0
            M.bar((x, y, z), (x + 320.0, y, z), 6.0, beam_d, sides=4,
                  name="traverse")
    # Pflanzbeete mit Gewaechsen
    use_collection(new_collection(scene, "plants"))
    pot_m = mat(C(6, "frame", 3), rough=0.8)
    pl_m = mat(C(6, "plant", 2), rough=0.8)
    pl_m2 = mat(C(6, "plant", 1), rough=0.8)
    for i in range(6):
        x = -880.0 + i * 340.0 + rnd.uniform(-30.0, 30.0)
        v, f = g_cyl(40.0, 46.0, 46.0, 14, caps=True)
        add_mesh("pot", v, f, pot_m, loc=(x, 0.0, -196.0), smooth=True)
        for k in range(5):
            M.leaf(x + rnd.uniform(-16.0, 16.0), -176.0, -6.0,
                   rnd.uniform(70.0, 130.0), rnd.uniform(26.0, 40.0),
                   rnd.uniform(-126.0, -54.0), pl_m if k % 2 else pl_m2,
                   bend=0.45)
    # Lichtstreifen
    use_collection(new_collection(scene, "shafts"))
    sh = emission_mat(haze(6, C(6, "glass", 1), 0.5), 0.85)
    for i in range(5):
        x = rnd.uniform(-880.0, 820.0)
        rect("shaft", x, x + rnd.uniform(90.0, 190.0),
             HORIZON_Z + 250.0, HORIZON_Z - 20.0, sh, 12.0)


def l06_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 6, [(24.0, 960.0, 2.2), (16.0, 320.0, 0.5), (8.0, 160.0, 3.3)])
    dark = mat(C(6, "dark", 1), rough=0.8, metal=0.3)
    darker = mat(C(6, "dark", 0), rough=0.8, metal=0.3)
    # Fachwerk oben
    for x, dx, z2 in [(-960.0, 330.0, 250.0), (300.0, 380.0, 300.0)]:
        M.bar((x, -62.0, HALF_H + 20.0), (x + dx, -62.0, z2), 9.0,
              dark, sides=4, name="ntruss")
    for x in (-140.0, 760.0):
        M.bar((x, -62.0, HALF_H + 20.0), (x, -62.0, 330.0), 10.0,
              darker, sides=4, name="npost_top")
    # Stuetzen unten
    for x in (-940.0, 900.0):
        M.bar((x, -60.0, -520.0), (x + rnd.uniform(-30.0, 30.0), -60.0, -150.0),
              30.0, dark, sides=4, name="npost")
    # Topfpflanze im Vordergrund
    M.leaf(-620.0, -520.0, -58.0, 250.0, 90.0, -78.0, darker, bend=0.5)
    M.leaf(-680.0, -520.0, -58.0, 210.0, 76.0, -112.0, dark, bend=0.5)
    M.leaf(820.0, -520.0, -58.0, 230.0, 84.0, -96.0, darker, bend=0.5)
    M.leaf(880.0, -520.0, -58.0, 190.0, 70.0, -66.0, dark, bend=0.5)


# --------------------------------------------------------------------------
# Level 7 -- Verlorene Kanalisation (dunkles Gruen/Grau, Backstein, Rohre)
# --------------------------------------------------------------------------
def l07_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#101814"), (0.22, "#1c241f"), (0.42, "#2a352e"),
                    (0.56, "#38463e"), (1.00, "#1e2a24")],
                    glows=[
                    (0.5938, 0.4444, 0.5, "#6aa87a", 0.55),
                    (0.5938, 0.4444, 0.18, "#8fd0a2", 0.45),
                    ])
    # ferner Tunnelbogen mit Licht am Ende
    use_collection(new_collection(scene, "tunnel"))
    glow_m = emission_mat("#4f7a5e", 1.0)
    wall = emission_mat("#16211c", 1.0)
    rim = emission_mat(haze(7, C(7, "brick", 3), 0.30), 1.0)
    for i in range(4):
        x = -720.0 + i * 480.0
        M.arch(x, -40.0, 180.0, 16.0, wall, span=180.0, segs=16,
               z_scale=1.1, name="arch")
        M.arch(x, -40.0, 168.0, 5.0, rim, span=180.0, segs=16, z_scale=1.1,
               name="archrim")
    # Wasser im Hintergrund
    use_collection(new_collection(scene, "water"))
    wcol = emission_mat("#22463a", 1.0)
    rect("farwater", -960.0, 960.0, HORIZON_Z - 2.0, -270.0, wcol, 166.0)
    # Backsteinreihen andeuten
    use_collection(new_collection(scene, "bricks"))
    bm = emission_mat(haze(7, C(7, "brick", 2), 0.35), 1.0)
    for r in range(4):
        for c in range(10):
            bx = -960.0 + c * 200.0 + (100.0 if r % 2 else 0.0)
            rect("fbrick", bx, bx + 180.0, 150.0 - r * 40.0,
                 118.0 - r * 40.0, bm, 165.0)


def l07_mid(scene, rnd):
    use_collection(new_collection(scene, "wall"))
    top = ridge([(8.0, 1920.0, 1.5), (5.0, 480.0, 3.9), (3.0, 160.0, 0.6)],
                HORIZON_Z - 4.0, n=120)
    g = L.mat_grad(C(7, "brick", 1), C(7, "brick", 4),
                   mid=C(7, "brick", 2), mid_pos=0.55, rough=0.95)
    add_ground("backwall", top, g, 116.0, -20.0, -620.0,
               relief=relief_waves([(6.0, 960.0, 2.0, 0.2)]), nd=12)
    # Ziegelmauer
    use_collection(new_collection(scene, "bricks"))
    ba = mat(C(7, "brick", 3), rough=0.95)
    bb = mat(C(7, "brick", 2), rough=0.95)
    M.brick_wall(-960.0, HORIZON_Z - 20.0, 40.0, 13, 6, 148.0, 40.0, ba, bb,
                 rnd, name="brick")
    # Bogenoeffnungen mit dunklem Inneren
    use_collection(new_collection(scene, "arches"))
    dark_in = emission_mat("#0a120e", 1.0)
    a_m = mat(C(7, "brick", 4), rough=0.9)
    for x in (-620.0, 120.0, 820.0):
        v, f = g_sweep([(x, 44.0, HORIZON_Z - 22.0)] * 2,
                       [circle_profile(16, 62.0, 92.0)] * 2)
        add_mesh("hole", v, f, dark_in, smooth=False, shade_flat=True)
        M.arch(x, HORIZON_Z - 22.0, 66.0, 7.0, a_m, span=180.0, segs=14,
               name="archrim")
    # Rohre
    use_collection(new_collection(scene, "pipes"))
    pipe_m = mat(C(7, "pipe", 2), rough=0.6, metal=0.35)
    pipe_d = mat(C(7, "pipe", 1), rough=0.65, metal=0.3)
    flange = mat(C(7, "pipe", 3), rough=0.55, metal=0.4)
    for i, (x, z, ln, r) in enumerate([(-900.0, 60.0, 1900.0, 15.0),
                                       (-900.0, -90.0, 760.0, 12.0),
                                       (120.0, -120.0, 900.0, 10.0)]):
        M.pipe(x, z, 30.0 - i * 4.0, ln, r, pipe_m if i % 2 == 0 else pipe_d,
               flange, flanges=6, name="pipe")
    # Schleuse mit Gitterstaben
    use_collection(new_collection(scene, "sluice"))
    gate_m = mat(C(7, "pipe", 2), rough=0.5, metal=0.5)
    for i in range(9):
        x = -180.0 + i * 34.0
        M.bar((x, 12.0, -30.0), (x, 12.0, -220.0), 5.0, gate_m, sides=4,
              name="bar")
    M.bar((-220.0, 12.0, -26.0), (140.0, 12.0, -26.0), 8.0, gate_m, sides=4,
          name="barh")
    M.bar((-220.0, 12.0, -224.0), (140.0, 12.0, -224.0), 8.0, gate_m,
          sides=4, name="barh")
    # Wasser vorne
    use_collection(new_collection(scene, "water"))
    wg = L.mat_grad(C(7, "water", 0), C(7, "water", 2), mid=C(7, "water", 1),
                    mid_pos=0.5, rough=0.2)
    wtop = ridge([(4.0, 1920.0, 0.4), (2.5, 320.0, 2.8)], -226.0, n=140)
    add_ground("water", wtop, wg, 16.0, -50.0, -620.0,
               relief=relief_waves([(2.5, 240.0, 1.1, 0.3)]), nd=8)
    # Algen und Gluehpunkte
    use_collection(new_collection(scene, "detail"))
    glow_m = emission_mat(C(7, "glow", 1), 1.0)
    moss = mat(C(7, "glow", 0), rough=0.9)
    for i in range(10):
        M.tuft(rnd.uniform(-930.0, 930.0), -226.0 + rnd.uniform(-8.0, 10.0),
               8.0, 4, rnd.uniform(30.0, 70.0), 14.0, rnd, moss, width=6.0,
               name="algae")
    for i in range(14):
        M.glow_dot(rnd.uniform(-940.0, 940.0), rnd.uniform(-230.0, -60.0),
                   6.0, rnd.uniform(1.4, 3.0), glow_m, name="glow")


def l07_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 7, [(30.0, 960.0, 1.1), (18.0, 320.0, 3.8), (10.0, 160.0, 0.2)], top_z=-450.0)
    dark = mat(C(7, "dark", 1), rough=0.85, metal=0.25)
    darker = mat(C(7, "dark", 0), rough=0.85, metal=0.25)
    # dickes Rohr im Vordergrund
    M.pipe(-960.0, -300.0, -62.0, 2000.0, 46.0, dark, None, angle_deg=0.0,
           name="npipe", flanges=0)
    M.pipe(-960.0, -300.0, -62.0, 2000.0, 40.0, darker, None, angle_deg=0.0,
           name="npipe2", flanges=0)
    # Gitterstabe oben
    for i in range(7):
        x = -960.0 + i * 320.0 + rnd.uniform(-40.0, 40.0)
        M.bar((x, -64.0, HALF_H + 20.0), (x + 60.0, -64.0, 120.0), 11.0,
              darker, sides=4, name="nbar")
    # Rohrbogen oben rechts
    M.arch(700.0, 190.0, 150.0, 26.0, dark, span=180.0, segs=14, name="nelbow")
    # Wassertropfen / Sumpfpflanzen am unteren Rand
    for x in (-700.0, -150.0, 480.0, 900.0):
        M.tuft(x, -160.0, -60.0, 5, rnd.uniform(80.0, 130.0), 26.0, rnd,
               darker, width=8.0, name="nreed")


# --------------------------------------------------------------------------
# Level 8 -- Maschinenherz (dunkles Rot/Braun, Zahnraeder, Pressen)
# --------------------------------------------------------------------------
def l08_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#1e0c0a"), (0.20, "#2a1210"), (0.40, "#3a1a18"),
                    (0.55, "#521f1c"), (1.00, "#421a14")],
                    glows=[
                    (0.3333, 0.4074, 0.56, "#a84428", 0.55),
                    (0.7708, 0.4074, 0.46, "#93361f", 0.45),
                    ])
    use_collection(new_collection(scene, "furnace"))
    # ferne Zahnraeder
    use_collection(new_collection(scene, "gears"))
    gm = emission_mat(haze(8, C(8, "metal", 1), 0.35), 1.0)
    for x, z, r, t in [(-700.0, 40.0, 150.0, 16), (-160.0, 90.0, 110.0, 12),
                       (300.0, 20.0, 190.0, 20), (860.0, 80.0, 130.0, 14)]:
        M.gear(x, z, 168.0, r, t, 8.0, gm, name="fgear")
    # Schornsteine / Silos
    use_collection(new_collection(scene, "silos"))
    sm = emission_mat(haze(8, C(8, "rust", 0), 0.30), 1.0)
    for x, w, h in [(-880.0, 70.0, 200.0), (-420.0, 54.0, 150.0),
                    (120.0, 80.0, 230.0), (700.0, 60.0, 170.0)]:
        rect("silo", x, x + w, HORIZON_Z + h, HORIZON_Z - 10.0, sm, 166.0)
    # Rauch
    use_collection(new_collection(scene, "smoke"))
    cloud_bank(8, 236.0, [(10.0, 960.0, 1.2), (7.0, 320.0, 3.9)],
               "#3a2420", "#2a1815", 165.0, thickness=26.0, name="smoke")


def l08_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(12.0, 1920.0, 2.4), (7.0, 640.0, 4.9), (4.0, 240.0, 1.1)],
                HORIZON_Z - 12.0, n=140)
    g = L.mat_grad(C(8, "metal", 0), C(8, "metal", 3),
                   mid=C(8, "metal", 1), mid_pos=0.5, rough=0.55, metal=0.3)
    add_ground("deck", top, g, 116.0, -40.0, -620.0,
               relief=relief_waves([(8.0, 960.0, 1.6, 0.2),
                                    (4.0, 240.0, 3.4, 0.5)]), nd=14)
    # Zahnraeder
    use_collection(new_collection(scene, "gears"))
    metal_m = mat(C(8, "metal", 3), rough=0.45, metal=0.6)
    metal_d = mat(C(8, "metal", 2), rough=0.5, metal=0.55)
    hub_m = mat(C(8, "rust", 1), rough=0.6, metal=0.35)
    for x, z, r, t, m, sp in [(-760.0, 30.0, 210.0, 22, metal_m, 5),
                              (-300.0, -110.0, 130.0, 14, metal_d, 4),
                              (200.0, 60.0, 175.0, 18, metal_m, 6),
                              (660.0, -90.0, 120.0, 14, metal_d, 4),
                              (960.0, 70.0, 150.0, 16, metal_m, 0)]:
        M.gear(x, z, 30.0, r, t, 16.0, m, hub_m, hub_r=r * 0.26, spokes=sp,
               name="gear")
    # Presse
    use_collection(new_collection(scene, "press"))
    block_m = mat(C(8, "metal", 2), rough=0.5, metal=0.5)
    for x in (-420.0, 520.0):
        v, f = g_box(150.0, 40.0, 90.0)
        add_mesh("press", v, f, block_m, loc=(x, 10.0, -150.0), shade_flat=True)
        v, f = g_cyl(26.0, 26.0, 130.0, 14, caps=True)
        add_mesh("ram", v, f, metal_d, loc=(x, 10.0, -60.0),
                 rot=(0.0, 0.0, 0.0), smooth=True)
        v, f = g_box(120.0, 30.0, 16.0)
        add_mesh("platen", v, f, metal_m, loc=(x, 10.0, -4.0), shade_flat=True)
    # Rohre und Kessel
    use_collection(new_collection(scene, "pipes"))
    pipe_m = mat(C(8, "metal", 4), rough=0.4, metal=0.7)
    M.pipe(-960.0, 120.0, 24.0, 1920.0, 12.0, pipe_m, hub_m, flanges=8,
           name="bigpipe")
    for x in (-120.0, 780.0):
        v, f = g_cyl(50.0, 50.0, 120.0, 16, caps=True)
        add_mesh("boiler", v, f, metal_d, loc=(x, 0.0, -120.0), smooth=True)
    # Glut
    use_collection(new_collection(scene, "glow"))
    glow_m = emission_mat(C(8, "glow", 1), 1.0)
    for i in range(12):
        M.glow_dot(rnd.uniform(-940.0, 940.0), rnd.uniform(-200.0, 60.0),
                   14.0, rnd.uniform(2.0, 4.0), glow_m, name="emb")


def l08_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 8, [(42.0, 960.0, 2.9), (24.0, 320.0, 0.6), (14.0, 160.0, 4.1)], top_z=-465.0)
    dark = mat(C(8, "dark", 1), rough=0.5, metal=0.5)
    darker = mat(C(8, "dark", 0), rough=0.5, metal=0.5)
    # riesiges Zahnrad als Silhouette am unteren Rand
    M.gear(180.0, -330.0, -62.0, 300.0, 22, 60.0, dark, hub_r=None,
           name="ngear")
    M.gear(-720.0, -300.0, -60.0, 200.0, 16, 40.0, darker, hub_r=None,
           name="ngear2")
    # Traeger oben
    for i in range(4):
        x = -960.0 + i * 520.0
        M.bar((x, -66.0, HALF_H + 30.0), (x + 260.0, -66.0, 140.0), 18.0,
              darker, sides=4, name="ngirder")
    M.bar((-960.0, -66.0, 210.0), (960.0, -66.0, 210.0), 22.0, dark, sides=4,
          name="nbeam")
    # Kolbenstangen unten
    for x in (-380.0, 740.0):
        v, f = g_cyl(34.0, 34.0, 200.0, 14, caps=True)
        add_mesh("nram", v, f, dark, loc=(x, -64.0, -230.0),
                 rot=(math.radians(90.0), 0.0, 0.0), smooth=True)


# --------------------------------------------------------------------------
# Level 9 -- Biomechanischer Schwarmstock (Violett/Gold, Waben, Adern)
# --------------------------------------------------------------------------
def l09_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#160c20"), (0.22, "#1c1028"), (0.42, "#2c1a3c"),
                    (0.56, "#3f2350"), (1.00, "#2a1a38")],
                    glows=[
                    (0.3646, 0.4259, 0.62, "#6a4568", 0.5),
                    (0.7083, 0.4259, 0.5, "#7a4a68", 0.4),
                    ])
    use_collection(new_collection(scene, "goldhaze"))
    # ferne Wabentuerme
    use_collection(new_collection(scene, "towers"))
    tm = emission_mat(haze(9, C(9, "hive", 3), 0.45), 1.0)
    for i in range(5):
        x = -880.0 + i * 440.0 + rnd.uniform(-50.0, 50.0)
        w = rnd.uniform(110.0, 190.0)
        h = rnd.uniform(120.0, 220.0)
        rect("tower", x, x + w, HORIZON_Z + h, HORIZON_Z - 20.0, tm, 166.0)
        M.arch(x + w * 0.5, HORIZON_Z + h, w * 0.5, 8.0, tm, span=180.0,
               segs=12, z_scale=0.7, name="towercap")
    # goldene Adern im Himmel
    use_collection(new_collection(scene, "veins"))
    vm = emission_mat(C(9, "gold", 3), 1.0)
    for i in range(7):
        x0 = -900.0 + i * 280.0
        z0 = rnd.uniform(60.0, 230.0)
        M.bar((x0, 172.0, z0), (x0 + rnd.uniform(160.0, 300.0), 172.0,
                                z0 - rnd.uniform(20.0, 90.0)), 2.2, vm,
              sides=4, name="fvein")


def l09_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(12.0, 1920.0, 1.8), (7.0, 480.0, 4.2), (4.0, 160.0, 0.7)],
                HORIZON_Z - 16.0, n=140)
    g = L.mat_grad(C(9, "dark", 1), C(9, "hive", 2),
                   mid=C(9, "hive", 1), mid_pos=0.45, rough=0.8)
    add_ground("organ", top, g, 116.0, -40.0, -620.0,
               relief=relief_waves([(10.0, 960.0, 2.2, 0.2),
                                    (5.0, 240.0, 4.6, 0.6)]), nd=14)
    # Wabenwand
    use_collection(new_collection(scene, "hive"))
    frame_m = mat(C(9, "hive", 2), rough=0.5, metal=0.25, coat=0.3)
    fill_m = mat(C(9, "gold", 2), rough=0.4, metal=0.3,
                 emis=C(9, "gold", 3), emis_str=0.25)
    size = 62.0
    for row in range(3):
        for col in range(-8, 9):
            x = col * size * 1.74 + (size * 0.87 if row % 2 else 0.0)
            z = HORIZON_Z + 34.0 + row * size * 1.52
            if z > 210.0:
                continue
            M.hex_honey(x, z, 40.0 - row * 6.0, size, 8.0, 18.0, frame_m,
                        fill_m if (row + col) % 3 else None, rnd,
                        name="hex")
    # Adern und Kabel
    use_collection(new_collection(scene, "veins"))
    vein_m = mat(C(9, "vein", 1), rough=0.4, emis=C(9, "vein", 2),
                 emis_str=0.35)
    cable_m = mat(C(9, "dark", 1), rough=0.5, metal=0.4)
    for i in range(3):
        x = -820.0 + i * 640.0 + rnd.uniform(-40.0, 40.0)
        M.vine(x + 60.0, 210.0, 32.0, rnd.uniform(300.0, 400.0), cable_m, rnd,
               angle_deg=-88.0, wiggle=0.55, radius=11.0, name="cable")
        M.vine(x, 200.0, 34.0, rnd.uniform(200.0, 280.0), vein_m, rnd,
               angle_deg=-84.0, wiggle=0.6, radius=5.0, name="vein")
    # Kokons
    use_collection(new_collection(scene, "pods"))
    pod_m = mat(C(9, "vein", 0), rough=0.45, sss=0.35, coat=0.4)
    for x, z, r in [(-700.0, -140.0, 46.0), (-120.0, -190.0, 34.0),
                    (480.0, -150.0, 52.0), (900.0, -200.0, 38.0)]:
        M.pyxis(x, z, 4.0, r, pod_m, squash=1.5)
    # Goldglanz
    use_collection(new_collection(scene, "glow"))
    gm = emission_mat(C(9, "gold", 3), 1.0)
    for i in range(14):
        M.glow_dot(rnd.uniform(-940.0, 940.0), rnd.uniform(-200.0, 180.0),
                   12.0, rnd.uniform(1.6, 3.4), gm, name="spark")


def l09_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 9, [(34.0, 960.0, 1.7), (20.0, 320.0, 4.0), (12.0, 160.0, 2.5)])
    dark = mat(C(9, "dark", 1), rough=0.55, metal=0.3)
    darker = mat(C(9, "dark", 0), rough=0.55, metal=0.3)
    # dunkle Wabenrahmen an den Raendern
    for x, z, r in [(-900.0, -230.0, 150.0), (-560.0, -290.0, 120.0),
                    (620.0, -280.0, 130.0), (960.0, -220.0, 160.0)]:
        M.hex_frame(x, z, -62.0, r, 26.0, 30.0, dark, name="nhex")
    for x, z, r in [(-720.0, 300.0, 120.0), (280.0, 320.0, 140.0),
                    (1000.0, 290.0, 110.0)]:
        M.hex_frame(x, z, -64.0, r, 24.0, 26.0, darker, name="nhextop")
    # Kabel
    for x, ln in [(-420.0, 260.0), (760.0, 300.0)]:
        M.vine(x, HALF_H + 20.0, -64.0, ln, darker, rnd, angle_deg=-88.0,
               wiggle=0.6, radius=10.0, name="ncable")


# --------------------------------------------------------------------------
# Level 10 -- Kern der Verwandlung (fast schwarz, Magenta-Glut, Kristalle)
# --------------------------------------------------------------------------
def l10_far(scene, rnd):
    use_collection(new_collection(scene, "sky"))
    add_sky(scene, [(0.00, "#040206"), (0.26, "#0b0610"), (0.44, "#14101a"),
                    (0.56, "#1c1226"), (1.00, "#0a0610")],
                    glows=[
                    (0.5208, 0.4556, 0.66, "#8a2058", 0.55),
                    (0.5208, 0.4556, 0.22, "#c22a72", 0.45),
                    ])
    use_collection(new_collection(scene, "core"))
    # ferne Kristallsilhouetten
    use_collection(new_collection(scene, "spires"))
    sm = emission_mat(haze(10, C(10, "crystal", 3), 0.30), 1.0)
    for i in range(9):
        x = -900.0 + i * 220.0 + rnd.uniform(-40.0, 40.0)
        h = rnd.uniform(90.0, 220.0)
        prof = [(x, 168.0, HORIZON_Z - 30.0), (x, 168.0, HORIZON_Z + h)]
        v, f = g_sweep(prof, [circle_profile(5, rnd.uniform(14.0, 30.0), 12.0),
                              circle_profile(5, 1.2, 1.0)])
        add_mesh("fspire", v, f, sm, smooth=False, shade_flat=True)
    # Glutadern
    use_collection(new_collection(scene, "veins"))
    vm = emission_mat("#8a2058", 1.0)
    for i in range(6):
        x0 = -900.0 + i * 320.0
        z0 = rnd.uniform(-20.0, 120.0)
        M.bar((x0, 170.0, z0), (x0 + 260.0, 170.0, z0 + rnd.uniform(-40.0, 40.0)),
              2.6, vm, sides=4, name="fvein")


def l10_mid(scene, rnd):
    use_collection(new_collection(scene, "floor"))
    top = ridge([(14.0, 1920.0, 1.2), (8.0, 480.0, 3.6), (4.0, 160.0, 5.4)],
                HORIZON_Z - 20.0, n=150)
    g = L.mat_grad(C(10, "dark", 0), C(10, "crystal", 3),
                   mid=C(10, "crystal", 1), mid_pos=0.4, rough=0.7, sss=0.2)
    add_ground("core", top, g, 116.0, -40.0, -620.0,
               relief=relief_waves([(12.0, 960.0, 2.6, 0.2),
                                    (6.0, 240.0, 0.8, 0.6)]), nd=16)
    # Kristallgrat
    use_collection(new_collection(scene, "crystals"))
    body_m = mat(C(10, "crystal", 2), rough=0.35, spec=0.7, sss=0.25)
    body_d = mat(C(10, "crystal", 1), rough=0.4, spec=0.6)
    tip_m = mat(C(10, "glow", 2), rough=0.3, emis=C(10, "glow", 1),
                emis_str=0.55)
    for i, (x, h, r, y) in enumerate([(-800.0, 260.0, 40.0, 40.0),
                                      (-380.0, 170.0, 26.0, 28.0),
                                      (-40.0, 320.0, 48.0, 46.0),
                                      (380.0, 200.0, 30.0, 30.0),
                                      (760.0, 280.0, 44.0, 42.0),
                                      (1010.0, 190.0, 28.0, 26.0)]):
        M.crystal(x, -70.0, y, h, r, body_m if i % 2 == 0 else body_d, tip_m,
                  rnd, lean=rnd.uniform(-0.10, 0.10), name="crys")
        M.crystal(x + rnd.uniform(-40.0, 40.0), -90.0, y - 6.0, h * 0.5,
                  r * 0.55, body_d, None, rnd, lean=rnd.uniform(-0.2, 0.2),
                  name="crys")
    # organische Membranen
    use_collection(new_collection(scene, "membranes"))
    mem_m = mat(C(10, "crystal", 2), rough=0.3, spec=0.8, sss=0.5,
                emis=C(10, "vein", 0), emis_str=0.25)
    for x, z, w, h in [(-560.0, -180.0, 220.0, 60.0), (240.0, -210.0, 260.0, 70.0),
                       (860.0, -170.0, 180.0, 50.0)]:
        M.membrane(x, z, 6.0, w, h, mem_m, rnd, blobs=5, name="mem")
    # Glutadern und Puls
    use_collection(new_collection(scene, "veins"))
    vein_m = mat(C(10, "vein", 2), rough=0.3, emis=C(10, "glow", 1),
                 emis_str=0.6)
    for i in range(5):
        x = -880.0 + i * 400.0 + rnd.uniform(-40.0, 40.0)
        M.vine(x, -80.0, 8.0, rnd.uniform(180.0, 300.0), vein_m, rnd,
               angle_deg=rnd.uniform(-80.0, -40.0), wiggle=0.8, radius=5.0,
               name="vein")
    use_collection(new_collection(scene, "glow"))
    gm = emission_mat(C(10, "glow", 2), 1.0)
    for i in range(16):
        M.glow_dot(rnd.uniform(-940.0, 940.0), rnd.uniform(-200.0, 60.0),
                   10.0, rnd.uniform(1.4, 3.2), gm, name="spark")


def l10_near(scene, rnd):
    use_collection(new_collection(scene, "near"))
    near_base(scene, 10, [(44.0, 960.0, 0.3), (26.0, 320.0, 2.7), (14.0, 160.0, 5.0)])
    dark = mat(C(10, "dark", 1), rough=0.4, spec=0.6)
    darker = mat(C(10, "dark", 0), rough=0.4, spec=0.6)
    # dunkle Kristallsplitter am unteren Rand
    for x, h, r, lean in [(-880.0, 300.0, 60.0, 0.16), (-520.0, 210.0, 44.0, -0.10),
                          (560.0, 240.0, 48.0, 0.12), (900.0, 290.0, 58.0, -0.14)]:
        M.crystal(x, -520.0, -62.0, h, r, dark if h > 250 else darker, None,
                  rnd, lean=lean, name="nshard")
    # haengende Kristallspitzen
    for x, h, r in [(-700.0, 200.0, 40.0), (60.0, 260.0, 48.0),
                    (820.0, 180.0, 36.0)]:
        M.crystal(x, HALF_H + 30.0, -60.0, h, r, darker, None, rnd,
                  lean=rnd.uniform(-0.1, 0.1), name="ntip")
    # Membranwulst oben
    M.membrane(-300.0, 300.0, -62.0, 420.0, 60.0, dark, rnd, blobs=5,
               name="nmem")


# --------------------------------------------------------------------------
# Registry
# --------------------------------------------------------------------------
LEVEL_BUILDERS = {
    1: dict(far=l01_far, mid=l01_mid, near=l01_near),
    2: dict(far=l02_far, mid=l02_mid, near=l02_near),
    3: dict(far=l03_far, mid=l03_mid, near=l03_near),
    4: dict(far=l04_far, mid=l04_mid, near=l04_near),
    5: dict(far=l05_far, mid=l05_mid, near=l05_near),
    6: dict(far=l06_far, mid=l06_mid, near=l06_near),
    7: dict(far=l07_far, mid=l07_mid, near=l07_near),
    8: dict(far=l08_far, mid=l08_mid, near=l08_near),
    9: dict(far=l09_far, mid=l09_mid, near=l09_near),
    10: dict(far=l10_far, mid=l10_mid, near=l10_near),
}
