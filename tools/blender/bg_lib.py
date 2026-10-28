"""bg_lib.py -- Geometrie-, Material- und Renderbausteine fuer die
Parallax-Hintergruende von "Apidya Reimagined".

Konventionen
------------
* 1 Blender-Welt-Einheit == 1 Bildpixel.
* Bildraum: x in [-960, +960], z in [-270, +270] (Kamera orthogonal, Blick +Y).
  Bild-y (von oben) = 270 - z  ->  Horizont y=300 entspricht z=-30.
* Tiefe: groessere y-Werte liegen weiter hinten (weiter von der Kamera weg).
* Kachelbreite exakt 1920 px. Alle Motive werden fuer die Nahtlosigkeit mit
  Wrap-Duplikaten bei x = +-1920 gebaut.
"""

import math

import bpy
from mathutils import Euler, Matrix, Vector

TILE_W = 1920.0     # Weltbreite einer Kachel (= 2 x Bildbreite)
TILE_H = 540.0      # Bildhoehe in Pixeln
IMG_SCALE = 0.5     # Weltbezug pro Bildpixel (1 px = 2 Welteinheiten)
OUT_W = int(TILE_W * IMG_SCALE)   # 960
OUT_H = int(TILE_H)               # 540
HALF_W = TILE_W * 0.5
# Reichweite, in der randnahe Objekte zusaetzlich gespiegelt werden: ihr
# Schattenwurf reicht ueber die Kachelkante hinaus und muss auf der anderen
# Seite wieder auftauchen, sonst entsteht eine sichtbare Naht.
SHADOW_MARGIN = 320.0
# Oberkante des Bildes in Welteinheiten (z = +HALF_H ist der obere Rand).
HALF_H = TILE_H * 0.5 / IMG_SCALE      # 540
# Unterkante des Bildes in Welteinheiten (z = -HALF_H = -540).
# Z_BOT liegt darunter, damit Boden und Vordergrundbuen buendig abschliessen.
Z_BOT = -620.0
HORIZON_Z = 270.0 - 300.0  # -30.0

_COLL = None


# --------------------------------------------------------------------------
# Farben
# --------------------------------------------------------------------------
def _srgb_to_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def hx(value):
    """'#rrggbb' -> linearer RGB-Tripel (Blender-Basisfarbe)."""
    h = value.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (_srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b))


def blend_hex(a, b, t):
    """Lineare Mischung zweier '#rrggbb' (t=0 -> a, t=1 -> b) als Hex."""
    ca, cb = hx(a), hx(b)
    out = [ca[i] * (1.0 - t) + cb[i] * t for i in range(3)]
    def enc(v):
        v = max(0.0, min(1.0, v))
        v = 1.055 * (v ** (1 / 2.4)) - 0.055 if v > 0.0031308 else v * 12.92
        return int(round(v * 255.0))
    return "#%02x%02x%02x" % tuple(enc(v) for v in out)


# --------------------------------------------------------------------------
# Szene / Kamera / Licht
# --------------------------------------------------------------------------
def reset_file():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def make_scene(name, transparent, samples=20):
    scene = bpy.data.scenes.new(name)
    r = scene.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x = OUT_W
    r.resolution_y = OUT_H
    r.resolution_percentage = 100
    r.film_transparent = transparent
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA" if transparent else "RGB"
    r.image_settings.color_depth = "8"
    r.image_settings.compression = 20
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    ee = scene.eevee
    ee.taa_render_samples = samples
    ee.use_shadows = True
    ee.shadow_ray_count = 2
    ee.shadow_step_count = 6
    ee.shadow_resolution_scale = 0.5
    r.use_motion_blur = False

    cam = bpy.data.cameras.new("Cam_" + name)
    cam.type = "ORTHO"
    cam.ortho_scale = TILE_W
    cam.clip_start = 1.0
    cam.clip_end = 6000.0
    ob = bpy.data.objects.new("Cam_" + name, cam)
    scene.collection.objects.link(ob)
    ob.location = (0.0, -900.0, 0.0)
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = ob
    return scene


def set_world(scene, color_hex, strength=0.55):
    """Weltfarbe = Umgebungslicht (weiches Fülllicht, horizontal konstant)."""
    world = bpy.data.worlds.new("W_" + scene.name)
    try:
        world.use_nodes = True
    except AttributeError:
        pass
    bg = world.node_tree.nodes.get("Background")
    col = hx(color_hex)
    bg.inputs[0].default_value = (col[0], col[1], col[2], 1.0)
    bg.inputs[1].default_value = strength
    scene.world = world
    return world


def add_sun(scene, energy=3.0, rot_deg=(52.0, 0.0, 26.0), angle_deg=2.5,
            color_hex="#fff3e0"):
    light = bpy.data.lights.new("Sun_" + scene.name, type="SUN")
    light.energy = energy
    light.angle = math.radians(angle_deg)
    light.color = hx(color_hex)
    ob = bpy.data.objects.new("Sun_" + scene.name, light)
    scene.collection.objects.link(ob)
    ob.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    return ob


def add_area(scene, name, loc, size, energy, color_hex, rot_deg=(90.0, 0.0, 0.0),
             shape="RECTANGLE", size_y=None):
    light = bpy.data.lights.new(name, type="AREA")
    light.energy = energy
    light.color = hx(color_hex)
    light.shape = shape
    light.size = size
    if size_y is not None:
        light.size_y = size_y
    ob = bpy.data.objects.new(name, light)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    return ob


# --------------------------------------------------------------------------
# Materialien
# --------------------------------------------------------------------------
_MATS = {}


def mat(base, rough=0.55, metal=0.0, emis=None, emis_str=0.0, alpha=1.0,
        sss=0.0, spec=0.35, coat=0.0, transmission=0.0, sheen=0.0, name=None):
    key = (base, round(rough, 3), metal, emis, emis_str, alpha, sss, spec,
           coat, transmission, sheen)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name or "M_%d" % (len(_MATS),))
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    links.new(bsdf.outputs[0], out.inputs[0])

    def setv(name_, value):
        if name_ in bsdf.inputs:
            bsdf.inputs[name_].default_value = value

    c = hx(base)
    setv("Base Color", (c[0], c[1], c[2], 1.0))
    setv("Roughness", rough)
    setv("Metallic", metal)
    setv("Specular IOR Level", spec)
    setv("Subsurface Weight", sss)
    if sss > 0:
        cr = hx(base)
        setv("Subsurface Radius", (cr[0] * 2.0 + 0.2, cr[1] * 1.2 + 0.1, cr[2] + 0.1))
        setv("Subsurface Scale", 0.25)
    if coat > 0:
        setv("Coat Weight", coat)
        setv("Coat Roughness", 0.08)
    if transmission > 0:
        setv("Transmission Weight", transmission)
        setv("IOR", 1.45)
    if sheen > 0:
        setv("Sheen Weight", sheen)
    if emis is not None:
        e = hx(emis)
        setv("Emission Color", (e[0], e[1], e[2], 1.0))
        setv("Emission Strength", emis_str)
    if alpha < 1.0:
        setv("Alpha", alpha)
        m.surface_render_method = "BLENDED" if alpha < 0.98 else "DITHERED"
        m.use_backface_culling = False
    _MATS[key] = m
    return m


def mat_grad(c_bottom, c_top, rough=0.9, axis="Z", mid=None, mid_pos=0.5,
             name=None, emis=None, emis_str=0.0, sss=0.0, metal=0.0,
             spec=0.3):
    """Principled-Material mit vertikalem Farbverlauf (Generated-Koordinaten).

    So bekommen grosse Flaechen (Wiese, Waende) echte Wertabstufung, die beim
    Quantisieren zu Pixel-Baendern wird.
    """
    key = ("grad", c_bottom, c_top, round(rough, 3), axis, mid, mid_pos, emis,
           emis_str, sss, metal, spec)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name or "G_%d" % len(_MATS))
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    links.new(tc.outputs["Generated"], sep.inputs[0])
    links.new(sep.outputs[axis], ramp.inputs[0])
    els = ramp.color_ramp.elements
    els[0].position = 0.0
    els[0].color = (*hx(c_bottom), 1.0)
    els[1].position = 1.0
    els[1].color = (*hx(c_top), 1.0)
    if mid is not None:
        e = els.new(mid_pos)
        e.color = (*hx(mid), 1.0)
    links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    if sss > 0 and "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = sss
    if emis is not None:
        e2 = hx(emis)
        bsdf.inputs["Emission Color"].default_value = (e2[0], e2[1], e2[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emis_str
    links.new(bsdf.outputs[0], out.inputs[0])
    if emis is not None and emis_str > 0.5:
        m["emissive"] = 1
    _MATS[key] = m
    return m


def mat_radial(c_center, c_edge, power=1.0, mid=None, mid_pos=0.45,
               name=None):
    """Radialer Verlauf ueber Generated-Koordinaten (weicher Lichtschein)."""
    key = ("rad", c_center, c_edge, round(power, 3), mid, mid_pos)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name or "R_%d" % len(_MATS))
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    em = nodes.new("ShaderNodeEmission")
    tc = nodes.new("ShaderNodeTexCoord")
    sub = nodes.new("ShaderNodeVectorMath")
    sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = (0.5, 0.5, 0.5)
    ln = nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 1.4142
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position = 0.0
    els[0].color = (*hx(c_center), 1.0)
    els[1].position = 1.0 / max(power, 0.05)
    els[1].color = (*hx(c_edge), 1.0)
    if mid is not None:
        e = els.new(mid_pos / max(power, 0.05))
        e.color = (*hx(mid), 1.0)
    links.new(tc.outputs["Generated"], sub.inputs[0])
    links.new(sub.outputs[0], ln.inputs[0])
    links.new(ln.outputs["Value"], mul.inputs[0])
    links.new(mul.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs[0], em.inputs[0])
    em.inputs[1].default_value = 1.0
    links.new(em.outputs[0], out.inputs[0])
    m["emissive"] = 1
    _MATS[key] = m
    return m


def emission_mat(color_hex, strength=1.0):
    """Reines Emissionsmaterial: Farbe kommt exakt wie angegeben heraus."""
    key = ("emit", color_hex, strength)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("E_%d" % len(_MATS))
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    em = nodes.new("ShaderNodeEmission")
    c = hx(color_hex)
    em.inputs[0].default_value = (c[0], c[1], c[2], 1.0)
    em.inputs[1].default_value = strength
    links.new(em.outputs[0], out.inputs[0])
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    m["emissive"] = 1
    _MATS[key] = m
    return m


# --------------------------------------------------------------------------
# Mesh-Erzeuger (reine Python-Geometrie, deterministisch)
# --------------------------------------------------------------------------
def g_sphere(r=1.0, segs=20, rings=10):
    verts = [(0.0, 0.0, r)]
    for i in range(1, rings):
        phi = math.pi * i / rings
        z = r * math.cos(phi)
        rr = r * math.sin(phi)
        for j in range(segs):
            th = 2.0 * math.pi * j / segs
            verts.append((rr * math.cos(th), rr * math.sin(th), z))
    verts.append((0.0, 0.0, -r))
    faces = []
    top = 0
    bottom = len(verts) - 1
    for j in range(segs):
        faces.append((top, 1 + (j + 1) % segs, 1 + j))
    for i in range(rings - 2):
        a = 1 + i * segs
        b = 1 + (i + 1) * segs
        for j in range(segs):
            j2 = (j + 1) % segs
            faces.append((a + j, a + j2, b + j2, b + j))
    a = 1 + (rings - 2) * segs
    for j in range(segs):
        j2 = (j + 1) % segs
        faces.append((a + j, a + j2, bottom))
    return verts, faces


def g_box(sx, sy, sz):
    x, y, z = sx * 0.5, sy * 0.5, sz * 0.5
    verts = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
             (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return verts, faces


def g_cyl(r1, r2, h, segs=16, caps=True):
    """Zylinder/Kegelstumpf entlang +Z, Zentrum in der Hoehe 0."""
    verts = []
    for j in range(segs):
        th = 2.0 * math.pi * j / segs
        verts.append((r1 * math.cos(th), r1 * math.sin(th), -h * 0.5))
    for j in range(segs):
        th = 2.0 * math.pi * j / segs
        verts.append((r2 * math.cos(th), r2 * math.sin(th), h * 0.5))
    faces = []
    for j in range(segs):
        j2 = (j + 1) % segs
        faces.append((j, j2, segs + j2, segs + j))
    if caps:
        faces.append(tuple(range(segs - 1, -1, -1)))
        faces.append(tuple(range(segs, segs * 2)))
    return verts, faces


def g_prism(poly2d, depth):
    """Polygon in der XZ-Ebene, entlang Y extrudiert (Tiefe zentriert)."""
    n = len(poly2d)
    verts = [(p[0], -depth * 0.5, p[1]) for p in poly2d]
    verts += [(p[0], depth * 0.5, p[1]) for p in poly2d]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        i2 = (i + 1) % n
        faces.append((i, i2, n + i2, n + i))
    return verts, faces


def _frames(points):
    """Tangenten-/Restframes fuer eine Polylinie in der XZ-Ebene."""
    pts = [Vector(p) for p in points]
    out = []
    n = len(pts)
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        if t.length < 1e-9:
            t = Vector((1.0, 0.0, 0.0))
        t.normalize()
        up_w = Vector((0.0, 1.0, 0.0))
        right = up_w.cross(t)
        if right.length < 1e-6:
            right = Vector((1.0, 0.0, 0.0))
        right.normalize()
        up = t.cross(right).normalized()
        out.append((pts[i], right, up))
    return out


def g_sweep(points, profiles, cap_start=True, cap_end=True):
    """Rohr-/Bandkoerper: profiles[i] = Liste (u,v) in der Ebene (right, up)."""
    frames = _frames(points)
    n = len(profiles[0])
    verts = []
    for (c, right, up), prof in zip(frames, profiles):
        for (u, v) in prof:
            p = c + right * u + up * v
            verts.append((p.x, p.y, p.z))
    faces = []
    rings = len(frames)
    for i in range(rings - 1):
        a = i * n
        b = (i + 1) * n
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((a + j, a + j2, b + j2, b + j))
    if cap_start:
        faces.append(tuple(range(n - 1, -1, -1)))
    if cap_end:
        base = (rings - 1) * n
        faces.append(tuple(base + j for j in range(n)))
    return verts, faces


def circle_profile(segs=10, rx=1.0, ry=1.0):
    return [(rx * math.cos(2.0 * math.pi * j / segs),
             ry * math.sin(2.0 * math.pi * j / segs)) for j in range(segs)]


def flat_profile(half_w, half_t, round_edges=True):
    """Flacher Querschnitt fuer Blaetter/Bluetenblaetter (Breite=u, Dicke=v)."""
    if round_edges:
        k = 0.42
        return [(-half_w, 0.0), (-half_w * k, half_t), (half_w * k, half_t),
                (half_w, 0.0), (half_w * k, -half_t), (-half_w * k, -half_t)]
    return [(-half_w, half_t), (half_w, half_t), (half_w, -half_t),
            (-half_w, -half_t)]


# --------------------------------------------------------------------------
# Objekt-Erzeugung mit Wrap-Duplikaten
# --------------------------------------------------------------------------
def use_collection(coll):
    global _COLL
    _COLL = coll


def new_collection(scene, name):
    coll = bpy.data.collections.new(name)
    scene.collection.children.link(coll)
    return coll


def _tile_geometry(verts, faces, rot, scale, loc):
    """Erweitert die Geometrie um Kopien, die eine Kachelbreite versetzt sind.

    Das geschieht auf Vertex-Ebene (nicht ueber Objektkopien), weil
    Weltmatrizen frisch erzeugter Objekte erst nach einer Depsgraph-
    Aktualisierung stimmen und Objektkopien dadurch an der falschen Stelle
    landen koennen. Ein Mesh mit bereits versetzten Vertices ist dagegen
    immer korrekt -- daraus entstehen die nahtlosen Kacheln.
    """
    M = Euler(rot, "XYZ").to_matrix() @ Matrix.Diagonal(Vector(scale))
    wxs = [(M @ Vector(v)).x + loc[0] for v in verts]
    lo, hi = min(wxs), max(wxs)
    # Objekte, die die Kachel schon voll ausfuellen, sind von sich aus
    # periodisch (Himmel, Bodenband, Silhouettenbaender) und werden nicht
    # verdoppelt.
    if lo <= -HALF_W + 1.0 and hi >= HALF_W - 1.0:
        return verts, faces
    # Randnahe Objekte werden mitkopiert: ihr Schattenwurf reicht ueber die
    # Kachelkante hinaus und muss auf der anderen Seite wieder auftauchen.
    shifts = []
    if hi > HALF_W - SHADOW_MARGIN:
        shifts.append(-TILE_W)   # ragt rechts heraus -> Kopie links
    if lo < -HALF_W + SHADOW_MARGIN:
        shifts.append(TILE_W)    # ragt links heraus  -> Kopie rechts
    if not shifts:
        return verts, faces
    try:
        Minv = M.inverted()
    except ValueError:
        return verts, faces
    nv, nf = list(verts), list(faces)
    n = len(verts)
    for sh in shifts:
        dv = Minv @ Vector((sh, 0.0, 0.0))
        nv += [(v[0] + dv.x, v[1] + dv.y, v[2] + dv.z) for v in verts]
        nf += [tuple(i + n for i in f) for f in faces]
        n *= 2
    return nv, nf


def add_mesh(name, verts, faces, material, loc=(0.0, 0.0, 0.0),
             rot=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0), smooth=True,
             wrap=True, shade_flat=False):
    if wrap and verts:
        verts, faces = _tile_geometry(verts, faces, rot, scale, loc)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate(verbose=False)
    for p in me.polygons:
        p.use_smooth = smooth and not shade_flat
    if material is not None:
        me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    if material is not None and material.get("emissive"):
        ob.visible_shadow = False
    _COLL.objects.link(ob)
    return ob


def add_sky(scene, stops, y=400.0, name="Sky", glows=None, aspect=1920.0 / 540.0):
    """Farbverlauf von oben (t=0) nach unten (t=1) ueber den ganzen Frame.

    stops: [(t, '#hex'), ...] -- Emissionsmaterial, dadurch exakte Farben.
    glows: [(x, y, radius, '#hex', strength), ...] in Fensterkoordinaten
           (0..1, y von unten). Wird direkt in den Himmel gerechnet, damit
           keine harten Scheibenraender entstehen.
    """
    coll = new_collection(scene, "Sky")
    verts, faces = g_box(4000.0, 10.0, 1400.0)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate(verbose=False)
    ob = bpy.data.objects.new(name, me)
    ob.location = (0.0, y, 0.0)
    coll.objects.link(ob)

    m = bpy.data.materials.new("M_Sky_" + scene.name)
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    for n in list(nodes):
        if n.type != "OUTPUT_MATERIAL":
            nodes.remove(n)
    out = nodes.get("Material Output")
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    em = nodes.new("ShaderNodeEmission")
    adds = nodes.new("ShaderNodeMath")
    adds.operation = "MULTIPLY_ADD"
    adds.inputs[1].default_value = -1.0
    adds.inputs[2].default_value = 1.0
    # Window-Y: 0 unten, 1 oben  ->  t = 1 - y
    links.new(tc.outputs["Window"], sep.inputs[0])
    links.new(sep.outputs["Y"], adds.inputs[0])
    links.new(adds.outputs[0], ramp.inputs[0])
    col_out = ramp.outputs[0]
    for (gx, gy, gr, gcol, gstr) in (glows or []):
        sepw = nodes.new("ShaderNodeSeparateXYZ")
        links.new(tc.outputs["Window"], sepw.inputs[0])
        dx = nodes.new("ShaderNodeMath")
        dx.operation = "SUBTRACT"
        dx.inputs[1].default_value = gx
        links.new(sepw.outputs["X"], dx.inputs[0])
        dxs = nodes.new("ShaderNodeMath")
        dxs.operation = "MULTIPLY"
        dxs.inputs[1].default_value = aspect
        links.new(dx.outputs[0], dxs.inputs[0])
        dy = nodes.new("ShaderNodeMath")
        dy.operation = "SUBTRACT"
        dy.inputs[1].default_value = gy
        links.new(sepw.outputs["Y"], dy.inputs[0])
        comb = nodes.new("ShaderNodeCombineXYZ")
        links.new(dxs.outputs[0], comb.inputs["X"])
        links.new(dy.outputs[0], comb.inputs["Y"])
        ln = nodes.new("ShaderNodeVectorMath")
        ln.operation = "LENGTH"
        links.new(comb.outputs[0], ln.inputs[0])
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.0
        mr.inputs["From Max"].default_value = max(gr, 1e-4)
        mr.inputs["To Min"].default_value = float(gstr)
        mr.inputs["To Max"].default_value = 0.0
        mr.clamp = True
        links.new(ln.outputs["Value"], mr.inputs["Value"])
        # weiche Kurve: Wert quadrieren wirkt wie ein Glow-Falloff
        pw = nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        pw.inputs[1].default_value = 1.6
        links.new(mr.outputs[0], pw.inputs[0])
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MIX"
        links.new(pw.outputs[0], mix.inputs["Factor"])
        links.new(col_out, mix.inputs[6])
        c = hx(gcol)
        mix.inputs[7].default_value = (c[0], c[1], c[2], 1.0)
        col_out = mix.outputs[2]
    links.new(col_out, em.inputs[0])
    em.inputs[1].default_value = 1.0
    links.new(em.outputs[0], out.inputs[0])

    els = ramp.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position = min(max(stops[0][0], 0.0), 1.0)
    els[0].color = (*hx(stops[0][1]), 1.0)
    for t, col in stops[1:]:
        e = els.new(min(max(t, 0.0), 1.0))
        e.color = (*hx(col), 1.0)
    me.materials.append(m)
    return ob


def add_flat(name, poly2d, depth, material, y, loc_z=0.0, smooth=False,
             wrap=True):
    """2D-Polygon (XZ) als flache Platte in Tiefe y -- fuer Silhouetten."""
    verts, faces = g_prism(poly2d, depth)
    return add_mesh(name, verts, faces, material, loc=(0.0, y, loc_z),
                    smooth=smooth, wrap=wrap, shade_flat=True)


# --------------------------------------------------------------------------
# Periodische Kurven (fuer nahtlose Gelaendekanten)
# --------------------------------------------------------------------------
def periodic_curve(specs, n, x0=-HALF_W, x1=HALF_W, base=0.0):
    """specs: [(amplitude, wavelength, phase), ...]; Wellenlaengen muessen
    TILE_W teilen, damit die Kante exakt passt."""
    xs = [x0 + (x1 - x0) * i / (n - 1) for i in range(n)]
    out = []
    for x in xs:
        z = base
        for amp, wl, phase in specs:
            z += amp * math.sin(2.0 * math.pi * (x / wl) + phase)
        out.append((x, z))
    return out


def add_ground(name, top_curve, material, y_back, y_front, z_bottom,
               relief=None, nd=9, smooth=True, wrap=False, shade_flat=False):
    """Gelaendeband mit Relief: Zeilen von hinten (y_back) nach vorne (y_front),
    z faellt von der Oberkante zum unteren Rand ab, 'relief(x, t)' erzeugt
    Wellen (t=0 hinten, t=1 vorne) -> echte Normalenvariation = Lichtbaender.
    """
    n = len(top_curve)
    verts = []
    for i in range(nd):
        t = i / (nd - 1)
        y = y_back + (y_front - y_back) * t
        for (x, ztop) in top_curve:
            z = ztop + (z_bottom - ztop) * (t ** 1.45)
            if relief is not None:
                z += relief(x, t)
            verts.append((x, y, z))
    faces = []
    for i in range(nd - 1):
        a = i * n
        b = (i + 1) * n
        for j in range(n - 1):
            faces.append((a + j, a + j + 1, b + j + 1, b + j))
    return add_mesh(name, verts, faces, material, smooth=smooth, wrap=wrap,
                    shade_flat=shade_flat)


def relief_waves(specs):
    """specs: [(amp, wavelength, phase, depth_gain), ...] -> relief(x, t)."""
    def fn(x, t):
        z = 0.0
        for amp, wl, phase, gain in specs:
            z += amp * math.sin(2.0 * math.pi * x / wl + phase) * \
                (gain + (1.0 - gain) * t)
        return z
    return fn


def add_terrain(name, curve, material, y_back, y_front, z_bottom, smooth=True,
                depth=0.0, wrap=True):
    """Kompatibilitaets-Wrapper (ohne Relief)."""
    return add_ground(name, curve, material, y_back, y_front, z_bottom,
                      smooth=smooth)
