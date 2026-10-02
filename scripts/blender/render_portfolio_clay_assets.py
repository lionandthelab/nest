"""
Nest 3D Claymorphism Asset Generator via Blender Headless
Calibrated studio lighting & AgX color management for rich pastel clay textures.
"""

import os
import math
import bpy

ASSET_OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), '../../frontend/assets/3d')
)
os.makedirs(ASSET_OUTPUT_DIR, exist_ok=True)

# Directly calibrated linear RGB for rich clay colors
COLORS = {
    'coral_rose': (0.95, 0.45, 0.38, 1.0),
    'mint_sage': (0.35, 0.75, 0.55, 1.0),
    'creamy_white': (0.96, 0.94, 0.90, 1.0),
    'butter_gold': (0.98, 0.70, 0.15, 1.0),
    'deep_wood': (0.26, 0.18, 0.14, 1.0),
    'pastel_sky': (0.42, 0.70, 0.92, 1.0),
    'pastel_lavender': (0.75, 0.62, 0.90, 1.0),
    'soft_silver': (0.78, 0.80, 0.82, 1.0),
    'lens_dark': (0.08, 0.10, 0.12, 1.0),
}

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not bpy.data.scenes:
        bpy.data.scenes.new(name="Scene")

def setup_render_engine(res=512):
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    if 'CYCLES' in engines:
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 64
        scene.cycles.adaptive_threshold = 0.04
    elif 'BLENDER_EEVEE_NEXT' in engines:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    else:
        scene.render.engine = 'BLENDER_EEVEE'

    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    
    # Modern AgX or Filmic
    try:
        scene.view_settings.view_transform = 'AgX'
        scene.view_settings.look = 'High Contrast'
    except Exception:
        scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.exposure = 0.0

def create_clay_material(name, color_rgba, roughness=0.38, sss_weight=0.20):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = color_rgba
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if "Subsurface Weight" in bsdf.inputs:
            bsdf.inputs["Subsurface Weight"].default_value = sss_weight
        elif "Subsurface" in bsdf.inputs:
            bsdf.inputs["Subsurface"].default_value = sss_weight
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.5
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = 0.5
    return mat

def setup_lighting_and_camera():
    scene = bpy.context.scene

    # Ambient World
    world = bpy.data.worlds.new(name="ClayWorld")
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.9, 0.9, 0.95, 1.0)
        bg.inputs["Strength"].default_value = 0.35
    scene.world = world

    # Key Light (Warm soft studio)
    key = bpy.data.lights.new(name="KeyLight", type='AREA')
    key.energy = 42.0
    key.size = 3.0
    key.color = (1.0, 0.96, 0.90)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key)
    key_obj.location = (2.6, -3.5, 4.0)
    key_obj.rotation_euler = (math.radians(45), math.radians(10), math.radians(30))
    scene.collection.objects.link(key_obj)

    # Fill Light (Cool sky)
    fill = bpy.data.lights.new(name="FillLight", type='AREA')
    fill.energy = 22.0
    fill.size = 4.0
    fill.color = (0.85, 0.92, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill)
    fill_obj.location = (-3.2, -2.5, 2.8)
    fill_obj.rotation_euler = (math.radians(45), math.radians(-15), math.radians(-45))
    scene.collection.objects.link(fill_obj)

    # Rim Light (Top edge)
    rim = bpy.data.lights.new(name="RimLight", type='AREA')
    rim.energy = 28.0
    rim.size = 2.2
    rim.color = (1.0, 1.0, 1.0)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim)
    rim_obj.location = (0.2, 3.2, 3.8)
    rim_obj.rotation_euler = (math.radians(-50), 0, 0)
    scene.collection.objects.link(rim_obj)

    # Camera
    cam_data = bpy.data.cameras.new(name="Camera")
    cam_data.type = 'PERSP'
    cam_data.lens = 78
    cam = bpy.data.objects.new(name="Camera", object_data=cam_data)
    cam.location = (2.6, -4.6, 2.5)
    cam.rotation_euler = (math.radians(66), 0, math.radians(28))
    scene.collection.objects.link(cam)
    scene.camera = cam


# ────────────────────────────────────────────────────────────────
# 1. 3D Clay Portfolio Binder (`portfolio_binder_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_portfolio_binder():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()
    scene = bpy.context.scene

    mat_cover = create_clay_material("MatCover", COLORS['coral_rose'], roughness=0.36)
    mat_paper = create_clay_material("MatPaper", COLORS['creamy_white'], roughness=0.45)
    mat_ring = create_clay_material("MatRing", COLORS['soft_silver'], roughness=0.22)
    mat_star = create_clay_material("MatStar", COLORS['butter_gold'], roughness=0.28)
    mat_tab1 = create_clay_material("MatTab1", COLORS['mint_sage'], roughness=0.36)
    mat_tab2 = create_clay_material("MatTab2", COLORS['butter_gold'], roughness=0.36)
    mat_tab3 = create_clay_material("MatTab3", COLORS['pastel_sky'], roughness=0.36)

    # Back cover
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.06))
    back = bpy.context.active_object
    back.scale = (2.3, 2.8, 0.12)
    back.data.materials.append(mat_cover)
    bev = back.modifiers.new("Bevel", 'BEVEL')
    bev.width = 0.12
    bev.segments = 4

    # Pages stack
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.04, 0, 0.08))
    pages = bpy.context.active_object
    pages.scale = (2.12, 2.68, 0.20)
    pages.data.materials.append(mat_paper)
    bev2 = pages.modifiers.new("Bevel", 'BEVEL')
    bev2.width = 0.06
    bev2.segments = 3

    # Front cover
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.04, 0, 0.24))
    front = bpy.context.active_object
    front.scale = (2.26, 2.76, 0.10)
    front.rotation_euler = (0, math.radians(-5), 0)
    front.data.materials.append(mat_cover)
    bev3 = front.modifiers.new("Bevel", 'BEVEL')
    bev3.width = 0.10
    bev3.segments = 4

    # Spiral rings
    for y_pos in [-0.95, -0.48, 0.0, 0.48, 0.95]:
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.18,
            minor_radius=0.045,
            location=(-1.12, y_pos, 0.12),
            rotation=(0, math.radians(90), 0)
        )
        ring = bpy.context.active_object
        ring.data.materials.append(mat_ring)

    # Index tabs
    tabs_data = [(0.65, mat_tab1), (0.15, mat_tab2), (-0.35, mat_tab3)]
    for y_pos, tab_mat in tabs_data:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.18, y_pos, 0.06))
        tab = bpy.context.active_object
        tab.scale = (0.24, 0.38, 0.04)
        tab.data.materials.append(tab_mat)
        bev_t = tab.modifiers.new("Bevel", 'BEVEL')
        bev_t.width = 0.03
        bev_t.segments = 2

    # Star emblem
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=5,
        radius=0.38,
        depth=0.12,
        location=(0.15, 0.35, 0.34),
        rotation=(0, math.radians(-5), math.radians(18))
    )
    star = bpy.context.active_object
    star.data.materials.append(mat_star)
    bev_s = star.modifiers.new("Bevel", 'BEVEL')
    bev_s.width = 0.05
    bev_s.segments = 3

    out_path = os.path.join(ASSET_OUTPUT_DIR, 'portfolio_binder_3d.png')
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"[Blender] Rendered: {out_path}")


# ────────────────────────────────────────────────────────────────
# 2. 3D Clay Retro Camera (`camera_memory_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_retro_camera():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()
    scene = bpy.context.scene

    mat_mint = create_clay_material("MatMint", COLORS['mint_sage'], roughness=0.34)
    mat_rose = create_clay_material("MatRose", COLORS['coral_rose'], roughness=0.34)
    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.28)
    mat_white = create_clay_material("MatWhite", COLORS['creamy_white'], roughness=0.32)
    mat_lens = create_clay_material("MatLens", COLORS['lens_dark'], roughness=0.15)

    # Camera body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    body = bpy.context.active_object
    body.scale = (2.4, 1.4, 1.7)
    body.data.materials.append(mat_mint)
    bev = body.modifiers.new("Bevel", 'BEVEL')
    bev.width = 0.18
    bev.segments = 4

    # Top shutter button
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.22,
        depth=0.25,
        location=(-0.65, 0, 0.95),
    )
    shutter = bpy.context.active_object
    shutter.data.materials.append(mat_rose)
    bev_s = shutter.modifiers.new("Bevel", 'BEVEL')
    bev_s.width = 0.04
    bev_s.segments = 3

    # Flash module
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.65, -0.68, 0.45))
    flash = bpy.context.active_object
    flash.scale = (0.42, 0.12, 0.32)
    flash.data.materials.append(mat_gold)
    bev_f = flash.modifiers.new("Bevel", 'BEVEL')
    bev_f.width = 0.04
    bev_f.segments = 2

    # Lens barrel
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.62,
        depth=0.45,
        location=(-0.1, -0.85, 0),
        rotation=(math.radians(90), 0, 0)
    )
    lens_barrel = bpy.context.active_object
    lens_barrel.data.materials.append(mat_white)
    bev_l = lens_barrel.modifiers.new("Bevel", 'BEVEL')
    bev_l.width = 0.06
    bev_l.segments = 3

    # Lens glass
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.45,
        depth=0.48,
        location=(-0.1, -0.86, 0),
        rotation=(math.radians(90), 0, 0)
    )
    lens_glass = bpy.context.active_object
    lens_glass.data.materials.append(mat_lens)

    # Photo popping out
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.25, 0, 1.4))
    photo = bpy.context.active_object
    photo.scale = (1.1, 0.06, 0.95)
    photo.rotation_euler = (math.radians(-8), math.radians(6), 0)
    photo.data.materials.append(mat_white)
    bev_p = photo.modifiers.new("Bevel", 'BEVEL')
    bev_p.width = 0.03
    bev_p.segments = 2

    out_path = os.path.join(ASSET_OUTPUT_DIR, 'camera_memory_3d.png')
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"[Blender] Rendered: {out_path}")


# ────────────────────────────────────────────────────────────────
# 3. 3D Clay Approval Ribbon Badge (`ribbon_badge_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_ribbon_badge():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()
    scene = bpy.context.scene

    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.28)
    mat_rose = create_clay_material("MatRose", COLORS['coral_rose'], roughness=0.34)
    mat_white = create_clay_material("MatWhite", COLORS['creamy_white'], roughness=0.35)

    # Medal body
    bpy.ops.mesh.primitive_cylinder_add(
        radius=1.2,
        depth=0.25,
        location=(0, 0, 0.35),
        rotation=(math.radians(20), math.radians(-12), 0)
    )
    medal = bpy.context.active_object
    medal.data.materials.append(mat_gold)
    bev_m = medal.modifiers.new("Bevel", 'BEVEL')
    bev_m.width = 0.10
    bev_m.segments = 4

    # Inner embossed circle
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.92,
        depth=0.30,
        location=(0, -0.02, 0.37),
        rotation=(math.radians(20), math.radians(-12), 0)
    )
    inner = bpy.context.active_object
    inner.data.materials.append(mat_white)
    bev_i = inner.modifiers.new("Bevel", 'BEVEL')
    bev_i.width = 0.05
    bev_i.segments = 3

    # Star in center
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=5,
        radius=0.45,
        depth=0.38,
        location=(0, -0.04, 0.38),
        rotation=(math.radians(20), math.radians(-12), math.radians(18))
    )
    star = bpy.context.active_object
    star.data.materials.append(mat_gold)
    bev_s = star.modifiers.new("Bevel", 'BEVEL')
    bev_s.width = 0.04
    bev_s.segments = 2

    # Ribbons hanging down
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.35, -0.05, -0.85))
    ribbon_l = bpy.context.active_object
    ribbon_l.scale = (0.48, 0.06, 1.4)
    ribbon_l.rotation_euler = (math.radians(15), math.radians(-12), math.radians(-15))
    ribbon_l.data.materials.append(mat_rose)
    bev_rl = ribbon_l.modifiers.new("Bevel", 'BEVEL')
    bev_rl.width = 0.04
    bev_rl.segments = 2

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.35, -0.05, -0.85))
    ribbon_r = bpy.context.active_object
    ribbon_r.scale = (0.48, 0.06, 1.4)
    ribbon_r.rotation_euler = (math.radians(15), math.radians(12), math.radians(15))
    ribbon_r.data.materials.append(mat_rose)
    bev_rr = ribbon_r.modifiers.new("Bevel", 'BEVEL')
    bev_rr.width = 0.04
    bev_rr.segments = 2

    out_path = os.path.join(ASSET_OUTPUT_DIR, 'ribbon_badge_3d.png')
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"[Blender] Rendered: {out_path}")


if __name__ == '__main__':
    print("=== Starting Blender 3D Claymorphism Asset Generation (Cycles AgX) ===")
    build_portfolio_binder()
    build_retro_camera()
    build_ribbon_badge()
    print("=== Blender 3D Claymorphism Generation Completed Successfully! ===")
