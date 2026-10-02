"""
Nest Comprehensive 3D Claymorphism Asset Generator via Blender Headless
Fully calibrated geometry, framing, and smoothing for all 11 assets.
"""

import os
import math
import bpy

ASSET_OUTPUT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), '../../frontend/assets/3d')
)
os.makedirs(ASSET_OUTPUT_DIR, exist_ok=True)

COLORS = {
    'coral_rose': (0.96, 0.48, 0.42, 1.0),
    'coral_light': (0.98, 0.68, 0.62, 1.0),
    'mint_sage': (0.35, 0.78, 0.65, 1.0),
    'mint_light': (0.58, 0.88, 0.78, 1.0),
    'creamy_white': (0.98, 0.96, 0.92, 1.0),
    'butter_gold': (0.99, 0.74, 0.18, 1.0),
    'deep_wood': (0.28, 0.18, 0.14, 1.0),
    'warm_wood': (0.76, 0.56, 0.38, 1.0),
    'natural_wood': (0.90, 0.78, 0.62, 1.0),
    'pastel_sky': (0.42, 0.74, 0.94, 1.0),
    'pastel_lavender': (0.76, 0.64, 0.92, 1.0),
    'soft_silver': (0.82, 0.85, 0.88, 1.0),
    'dark_graphite': (0.16, 0.17, 0.20, 1.0),
    'navy_slate': (0.22, 0.28, 0.38, 1.0),
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
        scene.cycles.samples = 48
        scene.cycles.adaptive_threshold = 0.03
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

    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = 0.1


def create_clay_material(name, color_rgba, roughness=0.28, sss_weight=0.08):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
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
            bsdf.inputs["Specular IOR Level"].default_value = 0.6
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = 0.6

        noise = nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 22.0
        noise.inputs['Detail'].default_value = 2.0
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.035
        links.new(noise.outputs['Fac'], bump.inputs['Height'])
        links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    return mat


def setup_lighting_and_camera(cam_loc=(0.7, -5.2, 1.8), cam_rot=(72, 0, 8), lens=65):
    scene = bpy.context.scene

    world = bpy.data.worlds.new(name="ClayWorld")
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        bg.inputs["Strength"].default_value = 0.50
    scene.world = world

    key = bpy.data.lights.new(name="KeyLight", type='AREA')
    key.energy = 160.0
    key.size = 3.5
    key.color = (1.0, 0.98, 0.94)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key)
    key_obj.location = (2.2, -3.2, 3.8)
    key_obj.rotation_euler = (math.radians(45), math.radians(10), math.radians(30))
    scene.collection.objects.link(key_obj)

    fill = bpy.data.lights.new(name="FillLight", type='AREA')
    fill.energy = 85.0
    fill.size = 4.0
    fill.color = (0.90, 0.95, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill)
    fill_obj.location = (-2.8, -2.5, 2.5)
    fill_obj.rotation_euler = (math.radians(45), math.radians(-15), math.radians(-45))
    scene.collection.objects.link(fill_obj)

    rim = bpy.data.lights.new(name="RimLight", type='AREA')
    rim.energy = 95.0
    rim.size = 2.5
    rim.color = (1.0, 1.0, 1.0)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim)
    rim_obj.location = (0, 3.0, 3.5)
    rim_obj.rotation_euler = (math.radians(-50), 0, 0)
    scene.collection.objects.link(rim_obj)

    cam_data = bpy.data.cameras.new(name="Camera")
    cam_data.type = 'PERSP'
    cam_data.lens = lens
    cam = bpy.data.objects.new(name="Camera", object_data=cam_data)
    cam.location = cam_loc
    cam.rotation_euler = (
        math.radians(cam_rot[0]),
        math.radians(cam_rot[1]),
        math.radians(cam_rot[2]),
    )
    scene.collection.objects.link(cam)
    scene.camera = cam


def add_bevel(obj, width=0.04, segments=3):
    bev = obj.modifiers.new(name="Bevel", type='BEVEL')
    bev.width = width
    bev.segments = segments
    bev.limit_method = 'ANGLE'
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()


def smooth(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()


def save_render(filename):
    scene = bpy.context.scene
    out_path = os.path.join(ASSET_OUTPUT_DIR, filename)
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {out_path} ({os.path.getsize(out_path)} bytes)")


# ────────────────────────────────────────────────────────────────
# 1. Warm Home Birdhouse (`home_nest_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_home_nest():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_wall = create_clay_material("MatWall", COLORS['creamy_white'], roughness=0.32)
    mat_roof = create_clay_material("MatRoof", COLORS['coral_rose'], roughness=0.28)
    mat_hole = create_clay_material("MatHole", COLORS['deep_wood'], roughness=0.45)
    mat_perch = create_clay_material("MatPerch", COLORS['warm_wood'], roughness=0.35)
    mat_leaf = create_clay_material("MatLeaf", COLORS['mint_sage'], roughness=0.28)

    # Wall Body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.22))
    wall = bpy.context.active_object
    wall.scale = (1.1, 1.0, 1.0)
    wall.data.materials.append(mat_wall)
    add_bevel(wall, width=0.10, segments=4)

    # Gable Roof - Left & Right meeting at apex
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.36, 0, 0.52))
    roof_l = bpy.context.active_object
    roof_l.scale = (0.75, 1.25, 0.12)
    roof_l.rotation_euler = (0, math.radians(-38), 0)
    roof_l.data.materials.append(mat_roof)
    add_bevel(roof_l, width=0.04, segments=3)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.36, 0, 0.52))
    roof_r = bpy.context.active_object
    roof_r.scale = (0.75, 1.25, 0.12)
    roof_r.rotation_euler = (0, math.radians(38), 0)
    roof_r.data.materials.append(mat_roof)
    add_bevel(roof_r, width=0.04, segments=3)

    # Ridge Beam on Apex
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=1.26, location=(0, 0, 0.76))
    ridge = bpy.context.active_object
    ridge.rotation_euler = (math.radians(90), 0, 0)
    ridge.data.materials.append(mat_roof)
    add_bevel(ridge, width=0.02, segments=2)

    # Entrance Hole
    bpy.ops.mesh.primitive_cylinder_add(radius=0.30, depth=0.10, location=(0, -0.52, -0.10))
    hole = bpy.context.active_object
    hole.rotation_euler = (math.radians(90), 0, 0)
    hole.data.materials.append(mat_hole)
    add_bevel(hole, width=0.03, segments=3)

    # Wooden Perch
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.45, location=(0, -0.70, -0.42))
    perch = bpy.context.active_object
    perch.rotation_euler = (math.radians(90), 0, 0)
    perch.data.materials.append(mat_perch)
    add_bevel(perch, width=0.02, segments=2)

    # Sprout Leaves on Apex
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(-0.07, -0.06, 0.98))
    leaf1 = bpy.context.active_object
    leaf1.scale = (0.6, 1.3, 0.4)
    leaf1.rotation_euler = (math.radians(25), math.radians(-28), math.radians(15))
    leaf1.data.materials.append(mat_leaf)
    smooth(leaf1)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0.08, -0.06, 0.95))
    leaf2 = bpy.context.active_object
    leaf2.scale = (0.5, 1.2, 0.35)
    leaf2.rotation_euler = (math.radians(20), math.radians(30), math.radians(-10))
    leaf2.data.materials.append(mat_leaf)
    smooth(leaf2)

    save_render("home_nest_3d.png")


# ────────────────────────────────────────────────────────────────
# 2. Puffy Clay Speech Bubbles (`community_chat_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_community_chat():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_coral = create_clay_material("MatCoral", COLORS['coral_rose'], roughness=0.28)
    mat_mint = create_clay_material("MatMint", COLORS['mint_sage'], roughness=0.28)
    mat_white = create_clay_material("MatWhite", COLORS['creamy_white'], roughness=0.30)

    # Back Bubble (Mint Sage)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.35, 0.20, 0.30))
    b1 = bpy.context.active_object
    b1.scale = (1.10, 0.32, 0.85)
    b1.data.materials.append(mat_mint)
    add_bevel(b1, width=0.20, segments=5)

    bpy.ops.mesh.primitive_cone_add(radius1=0.20, radius2=0.02, depth=0.38, location=(0.95, 0.20, -0.15))
    t1 = bpy.context.active_object
    t1.rotation_euler = (0, math.radians(45), 0)
    t1.data.materials.append(mat_mint)
    add_bevel(t1, width=0.03, segments=2)

    for x in [-0.26, 0.0, 0.26]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.085, location=(0.35 + x, 0.03, 0.32))
        dot = bpy.context.active_object
        dot.scale = (1.0, 0.35, 1.0)
        dot.data.materials.append(mat_white)
        smooth(dot)

    # Front Bubble (Coral Rose)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.30, -0.20, -0.15))
    b2 = bpy.context.active_object
    b2.scale = (1.20, 0.34, 0.90)
    b2.data.materials.append(mat_coral)
    add_bevel(b2, width=0.20, segments=5)

    bpy.ops.mesh.primitive_cone_add(radius1=0.22, radius2=0.02, depth=0.42, location=(-0.85, -0.20, -0.68))
    t2 = bpy.context.active_object
    t2.rotation_euler = (0, math.radians(-50), 0)
    t2.data.materials.append(mat_coral)
    add_bevel(t2, width=0.03, segments=2)

    # Embossed Heart
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(-0.38, -0.38, -0.12))
    hl = bpy.context.active_object
    hl.data.materials.append(mat_white)
    smooth(hl)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(-0.22, -0.38, -0.12))
    hr = bpy.context.active_object
    hr.data.materials.append(mat_white)
    smooth(hr)

    bpy.ops.mesh.primitive_cone_add(radius1=0.18, radius2=0.02, depth=0.28, location=(-0.30, -0.38, -0.25))
    hb = bpy.context.active_object
    hb.rotation_euler = (math.radians(180), 0, 0)
    hb.data.materials.append(mat_white)
    smooth(hb)

    save_render("community_chat_3d.png")


# ────────────────────────────────────────────────────────────────
# 3. Modular Clay School Blocks (`term_setup_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_term_setup():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_mint = create_clay_material("MatMint", COLORS['mint_sage'], roughness=0.28)
    mat_coral = create_clay_material("MatCoral", COLORS['coral_rose'], roughness=0.28)
    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.26)
    mat_white = create_clay_material("MatWhite", COLORS['creamy_white'], roughness=0.30)

    # Block 1 (Mint)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.42, -0.10, -0.35))
    b1 = bpy.context.active_object
    b1.scale = (0.78, 0.78, 0.65)
    b1.rotation_euler = (0, 0, math.radians(-10))
    b1.data.materials.append(mat_mint)
    add_bevel(b1, width=0.08, segments=4)

    # Block 2 (Coral)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.42, 0.10, -0.35))
    b2 = bpy.context.active_object
    b2.scale = (0.78, 0.78, 0.65)
    b2.rotation_euler = (0, 0, math.radians(12))
    b2.data.materials.append(mat_coral)
    add_bevel(b2, width=0.08, segments=4)

    # Block 3 (Gold)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.30))
    b3 = bpy.context.active_object
    b3.scale = (0.78, 0.78, 0.65)
    b3.rotation_euler = (0, 0, math.radians(4))
    b3.data.materials.append(mat_gold)
    add_bevel(b3, width=0.08, segments=4)

    # Triangular Pyramid Roof on Top Block
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.60, radius2=0.0, depth=0.48, location=(0.0, 0.0, 0.88))
    roof = bpy.context.active_object
    roof.rotation_euler = (0, 0, math.radians(49))
    roof.data.materials.append(mat_white)
    add_bevel(roof, width=0.04, segments=3)

    # Studs
    for loc in [(-0.42, -0.10, 0.02), (0.42, 0.10, 0.02)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.12, location=loc)
        stud = bpy.context.active_object
        stud.data.materials.append(mat_white)
        add_bevel(stud, width=0.02, segments=2)

    save_render("term_setup_3d.png")


# ────────────────────────────────────────────────────────────────
# 4. Interlocking Clay Gears & Dial (`system_gear_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_system_gear():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_mint = create_clay_material("MatMint", COLORS['mint_sage'], roughness=0.28)
    mat_coral = create_clay_material("MatCoral", COLORS['coral_rose'], roughness=0.28)
    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.26)
    mat_silver = create_clay_material("MatSilver", COLORS['soft_silver'], roughness=0.35)

    rot_gears = (math.radians(35), math.radians(-10), math.radians(15))

    # Main Gear (Mint Sage)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.68, depth=0.22, location=(-0.18, -0.05, -0.10))
    gear1 = bpy.context.active_object
    gear1.rotation_euler = rot_gears
    gear1.data.materials.append(mat_mint)
    add_bevel(gear1, width=0.05, segments=3)

    for i in range(8):
        angle = i * (math.pi / 4)
        gx = -0.18 + math.cos(angle) * 0.76
        gy = -0.05 + math.sin(angle) * 0.76
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.22, location=(gx, gy, -0.10))
        t = bpy.context.active_object
        t.rotation_euler = rot_gears
        t.data.materials.append(mat_mint)
        smooth(t)

    # Center Hub (Silver)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.28, location=(-0.18, -0.05, -0.08))
    hub = bpy.context.active_object
    hub.rotation_euler = rot_gears
    hub.data.materials.append(mat_silver)
    add_bevel(hub, width=0.03, segments=2)

    # Dial Toggle Knob (Gold)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.16, location=(-0.18, -0.10, 0.10))
    knob = bpy.context.active_object
    knob.rotation_euler = rot_gears
    knob.data.materials.append(mat_gold)
    add_bevel(knob, width=0.03, segments=2)

    # Secondary Gear (Coral Rose)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.20, location=(0.62, 0.18, 0.40))
    gear2 = bpy.context.active_object
    gear2.rotation_euler = rot_gears
    gear2.data.materials.append(mat_coral)
    add_bevel(gear2, width=0.04, segments=3)

    for i in range(6):
        angle = i * (math.pi / 3) + math.pi / 6
        gx = 0.62 + math.cos(angle) * 0.52
        gy = 0.18 + math.sin(angle) * 0.52
        bpy.ops.mesh.primitive_cylinder_add(radius=0.10, depth=0.20, location=(gx, gy, 0.40))
        t2 = bpy.context.active_object
        t2.rotation_euler = rot_gears
        t2.data.materials.append(mat_coral)
        smooth(t2)

    save_render("system_gear_3d.png")


# ────────────────────────────────────────────────────────────────
# 5. Teacher Mortarboard Cap & Scroll (`teacher_cap_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_teacher_cap():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_cap = create_clay_material("MatCap", COLORS['navy_slate'], roughness=0.30)
    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.25)
    mat_paper = create_clay_material("MatPaper", COLORS['creamy_white'], roughness=0.32)
    mat_ribbon = create_clay_material("MatRibbon", COLORS['coral_rose'], roughness=0.28)

    # Skullcap
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.48, location=(-0.05, 0.0, 0.10))
    skull = bpy.context.active_object
    skull.scale = (1.0, 1.0, 0.55)
    skull.data.materials.append(mat_cap)
    smooth(skull)

    # Diamond Mortarboard Top Slab
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.05, 0.0, 0.38))
    top = bpy.context.active_object
    top.scale = (1.35, 1.35, 0.08)
    top.rotation_euler = (math.radians(16), math.radians(-10), math.radians(45))
    top.data.materials.append(mat_cap)
    add_bevel(top, width=0.04, segments=3)

    # Gold Center Button
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(-0.05, 0.0, 0.50))
    btn = bpy.context.active_object
    btn.data.materials.append(mat_gold)
    smooth(btn)

    # Hanging Tassel Cord
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.55, location=(0.42, -0.28, 0.22))
    cord = bpy.context.active_object
    cord.rotation_euler = (math.radians(25), math.radians(45), 0)
    cord.data.materials.append(mat_gold)
    add_bevel(cord, width=0.01, segments=2)

    # Tassel Brush
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.24, location=(0.58, -0.46, 0.02))
    brush = bpy.context.active_object
    brush.data.materials.append(mat_gold)
    add_bevel(brush, width=0.03, segments=2)

    # Diploma Scroll
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=1.25, location=(-0.05, 0.25, -0.40))
    scroll = bpy.context.active_object
    scroll.rotation_euler = (math.radians(15), math.radians(80), math.radians(-30))
    scroll.data.materials.append(mat_paper)
    add_bevel(scroll, width=0.03, segments=3)

    # Ribbon Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.19, minor_radius=0.04, location=(-0.05, 0.25, -0.40))
    ribbon = bpy.context.active_object
    ribbon.rotation_euler = (math.radians(15), math.radians(80), math.radians(-30))
    ribbon.data.materials.append(mat_ribbon)
    smooth(ribbon)

    save_render("teacher_cap_3d.png")


# ────────────────────────────────────────────────────────────────
# 6. Student Backpack with Star (`student_backpack_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_student_backpack():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_bag = create_clay_material("MatBag", COLORS['pastel_sky'], roughness=0.28)
    mat_pocket = create_clay_material("MatPocket", COLORS['creamy_white'], roughness=0.30)
    mat_strap = create_clay_material("MatStrap", COLORS['coral_rose'], roughness=0.28)
    mat_star = create_clay_material("MatStar", COLORS['butter_gold'], roughness=0.25)

    # Main Bag Body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.10))
    body = bpy.context.active_object
    body.scale = (0.90, 0.70, 1.10)
    body.data.materials.append(mat_bag)
    add_bevel(body, width=0.18, segments=5)

    # Front Pocket
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.38, -0.25))
    pocket = bpy.context.active_object
    pocket.scale = (0.70, 0.22, 0.50)
    pocket.data.materials.append(mat_pocket)
    add_bevel(pocket, width=0.10, segments=4)

    # Zipper Strip
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.50, -0.05))
    zip_obj = bpy.context.active_object
    zip_obj.scale = (0.60, 0.03, 0.04)
    zip_obj.data.materials.append(mat_strap)

    # Top Carry Handle
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.045, location=(0, 0, 0.52))
    handle = bpy.context.active_object
    handle.rotation_euler = (math.radians(90), 0, 0)
    handle.data.materials.append(mat_strap)
    smooth(handle)

    # Dangling Gold Star Charm
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.16, depth=0.07, location=(0.46, -0.38, 0.0))
    star = bpy.context.active_object
    star.rotation_euler = (math.radians(80), math.radians(20), 0)
    star.data.materials.append(mat_star)
    add_bevel(star, width=0.02, segments=2)

    save_render("student_backpack_3d.png")


# ────────────────────────────────────────────────────────────────
# 7. Family Clay Nest with 3 Eggs (`family_nest_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_family_nest():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_nest = create_clay_material("MatNest", COLORS['warm_wood'], roughness=0.38)
    mat_egg_coral = create_clay_material("MatEggCoral", COLORS['coral_rose'], roughness=0.26)
    mat_egg_mint = create_clay_material("MatEggMint", COLORS['mint_sage'], roughness=0.26)
    mat_egg_gold = create_clay_material("MatEggGold", COLORS['butter_gold'], roughness=0.26)
    mat_heart = create_clay_material("MatHeart", COLORS['coral_light'], roughness=0.25)

    rot_nest = (math.radians(22), 0, 0)

    # Woven Nest Bowl
    bpy.ops.mesh.primitive_torus_add(major_radius=0.78, minor_radius=0.25, location=(0, 0, -0.20))
    ring1 = bpy.context.active_object
    ring1.rotation_euler = rot_nest
    ring1.scale = (1.05, 0.95, 0.65)
    ring1.data.materials.append(mat_nest)
    add_bevel(ring1, width=0.05, segments=3)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.72, location=(0, 0, -0.35))
    base = bpy.context.active_object
    base.rotation_euler = rot_nest
    base.scale = (1.05, 0.95, 0.45)
    base.data.materials.append(mat_nest)
    smooth(base)

    # 3 Snuggled Pastel Eggs
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(-0.28, -0.10, 0.05))
    e1 = bpy.context.active_object
    e1.scale = (0.85, 0.85, 1.25)
    e1.rotation_euler = (math.radians(5), math.radians(18), 0)
    e1.data.materials.append(mat_egg_coral)
    smooth(e1)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0.28, -0.06, 0.05))
    e2 = bpy.context.active_object
    e2.scale = (0.85, 0.85, 1.25)
    e2.rotation_euler = (math.radians(10), math.radians(-20), 0)
    e2.data.materials.append(mat_egg_mint)
    smooth(e2)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0.0, -0.28, 0.0))
    e3 = bpy.context.active_object
    e3.scale = (0.85, 0.85, 1.20)
    e3.rotation_euler = (math.radians(35), 0, 0)
    e3.data.materials.append(mat_egg_gold)
    smooth(e3)

    # Floating Soft Clay Heart
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(-0.05, 0.25, 0.35))
    h = bpy.context.active_object
    h.scale = (1.0, 0.55, 1.0)
    h.data.materials.append(mat_heart)
    smooth(h)

    save_render("family_nest_3d.png")


# ────────────────────────────────────────────────────────────────
# 8. Golden Clay Chime Bell with Waves (`notification_bell_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_notification_bell():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_gold = create_clay_material("MatGold", COLORS['butter_gold'], roughness=0.22)
    mat_coral = create_clay_material("MatCoral", COLORS['coral_rose'], roughness=0.26)
    mat_white = create_clay_material("MatWhite", COLORS['creamy_white'], roughness=0.30)

    # Flared Bell Body
    bpy.ops.mesh.primitive_cone_add(radius1=0.66, radius2=0.46, depth=0.58, location=(0, 0, -0.05))
    bell = bpy.context.active_object
    bell.data.materials.append(mat_gold)
    add_bevel(bell, width=0.08, segments=3)

    # Dome Top
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.46, location=(0, 0, 0.22))
    dome = bpy.context.active_object
    dome.scale = (1.0, 1.0, 0.65)
    dome.data.materials.append(mat_gold)
    smooth(dome)

    # Flared Lip Rim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.68, minor_radius=0.07, location=(0, 0, -0.34))
    lip = bpy.context.active_object
    lip.data.materials.append(mat_gold)
    smooth(lip)

    # Clapper Ball
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.18, location=(0, 0, -0.42))
    clapper = bpy.context.active_object
    clapper.data.materials.append(mat_coral)
    smooth(clapper)

    # Ribbon Bow on Top
    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.05, location=(-0.16, 0, 0.65))
    bl = bpy.context.active_object
    bl.rotation_euler = (0, math.radians(45), 0)
    bl.data.materials.append(mat_coral)
    smooth(bl)

    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.05, location=(0.16, 0, 0.65))
    br = bpy.context.active_object
    br.rotation_euler = (0, math.radians(-45), 0)
    br.data.materials.append(mat_coral)
    smooth(br)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, -0.03, 0.65))
    knot = bpy.context.active_object
    knot.data.materials.append(mat_coral)
    smooth(knot)

    # Sound Waves
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.03, location=(side * 0.95, 0, 0.02))
        wave = bpy.context.active_object
        wave.scale = (0.2, 0.7, 0.9)
        wave.data.materials.append(mat_white)
        smooth(wave)

    save_render("notification_bell_3d.png")


# ────────────────────────────────────────────────────────────────
# 9. Chunky Hexagonal Clay Pencil (`pencil_write_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_pencil_write():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_barrel = create_clay_material("MatBarrel", COLORS['mint_sage'], roughness=0.26)
    mat_wood = create_clay_material("MatWood", COLORS['natural_wood'], roughness=0.36)
    mat_lead = create_clay_material("MatLead", COLORS['dark_graphite'], roughness=0.45)
    mat_silver = create_clay_material("MatSilver", COLORS['soft_silver'], roughness=0.30)
    mat_eraser = create_clay_material("MatEraser", COLORS['coral_rose'], roughness=0.28)

    # Group Empty for single rotation
    rot_pencil = (math.radians(-32), math.radians(22), math.radians(40))

    # Lead Tip
    bpy.ops.mesh.primitive_cone_add(radius1=0.09, radius2=0.0, depth=0.20, location=(0, 0, -0.80))
    lead = bpy.context.active_object
    lead.data.materials.append(mat_lead)
    smooth(lead)

    # Wood Cone
    bpy.ops.mesh.primitive_cone_add(radius1=0.26, radius2=0.09, depth=0.40, location=(0, 0, -0.50))
    wood = bpy.context.active_object
    wood.data.materials.append(mat_wood)
    smooth(wood)

    # Barrel (6-sided)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.26, depth=1.10, location=(0, 0, 0.25))
    barrel = bpy.context.active_object
    barrel.data.materials.append(mat_barrel)
    add_bevel(barrel, width=0.025, segments=2)

    # Ferrule
    bpy.ops.mesh.primitive_cylinder_add(radius=0.27, depth=0.18, location=(0, 0, 0.88))
    ferrule = bpy.context.active_object
    ferrule.data.materials.append(mat_silver)
    add_bevel(ferrule, width=0.02, segments=2)

    # Eraser
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.28, location=(0, 0, 1.10))
    eraser = bpy.context.active_object
    eraser.data.materials.append(mat_eraser)
    add_bevel(eraser, width=0.06, segments=3)

    # Rotate all parts together via empty parent
    pencil_parent = bpy.data.objects.new("PencilParent", None)
    bpy.context.scene.collection.objects.link(pencil_parent)
    for part in [lead, wood, barrel, ferrule, eraser]:
        part.parent = pencil_parent
    pencil_parent.rotation_euler = (math.radians(-35), math.radians(22), math.radians(40))

    save_render("pencil_write_3d.png")


# ────────────────────────────────────────────────────────────────
# 10. Rising 3D Bar Columns with Star (`insight_chart_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_insight_chart():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_base = create_clay_material("MatBase", COLORS['creamy_white'], roughness=0.32)
    mat_b1 = create_clay_material("MatB1", COLORS['butter_gold'], roughness=0.26)
    mat_b2 = create_clay_material("MatB2", COLORS['coral_rose'], roughness=0.26)
    mat_b3 = create_clay_material("MatB3", COLORS['mint_sage'], roughness=0.26)
    mat_star = create_clay_material("MatStar", COLORS['butter_gold'], roughness=0.22)

    # Base Pedestal
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.55))
    base = bpy.context.active_object
    base.scale = (1.60, 0.85, 0.16)
    base.data.materials.append(mat_base)
    add_bevel(base, width=0.06, segments=4)

    # Bar 1 (Butter Gold)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.46, 0, -0.25))
    b1 = bpy.context.active_object
    b1.scale = (0.32, 0.32, 0.45)
    b1.data.materials.append(mat_b1)
    add_bevel(b1, width=0.05, segments=3)

    # Bar 2 (Coral Rose)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0, -0.05))
    b2 = bpy.context.active_object
    b2.scale = (0.32, 0.32, 0.85)
    b2.data.materials.append(mat_b2)
    add_bevel(b2, width=0.05, segments=3)

    # Bar 3 (Mint Sage)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.46, 0, 0.20))
    b3 = bpy.context.active_object
    b3.scale = (0.32, 0.32, 1.35)
    b3.data.materials.append(mat_b3)
    add_bevel(b3, width=0.05, segments=3)

    # Star floating on Bar 3
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.20, depth=0.08, location=(0.46, -0.04, 1.05))
    star = bpy.context.active_object
    star.rotation_euler = (math.radians(70), math.radians(15), 0)
    star.data.materials.append(mat_star)
    add_bevel(star, width=0.02, segments=2)

    save_render("insight_chart_3d.png")


# ────────────────────────────────────────────────────────────────
# 11. Scalloped Badge with 3D Checkmark (`check_stamp_3d.png`)
# ────────────────────────────────────────────────────────────────
def build_check_stamp():
    clean_scene()
    setup_render_engine(512)
    setup_lighting_and_camera()

    mat_badge = create_clay_material("MatBadge", COLORS['mint_sage'], roughness=0.26)
    mat_check = create_clay_material("MatCheck", COLORS['creamy_white'], roughness=0.24)
    mat_handle = create_clay_material("MatHandle", COLORS['warm_wood'], roughness=0.34)

    # Face tilted towards camera (looking up towards viewer)
    rot_badge = (math.radians(55), 0, math.radians(-10))

    # Badge Coin
    bpy.ops.mesh.primitive_cylinder_add(radius=0.76, depth=0.22, location=(0, 0, 0.0))
    coin = bpy.context.active_object
    coin.rotation_euler = rot_badge
    coin.data.materials.append(mat_badge)
    add_bevel(coin, width=0.06, segments=4)

    # Scallop Rim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.72, minor_radius=0.06, location=(0, -0.05, 0.08))
    rim = bpy.context.active_object
    rim.rotation_euler = rot_badge
    rim.data.materials.append(mat_badge)
    smooth(rim)

    # Checkmark Legs (Embossed on face)
    # Short Leg
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.20, -0.15, 0.12))
    l1 = bpy.context.active_object
    l1.scale = (0.13, 0.32, 0.12)
    l1.rotation_euler = (rot_badge[0], rot_badge[1], math.radians(45))
    l1.data.materials.append(mat_check)
    add_bevel(l1, width=0.03, segments=3)

    # Long Leg
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.12, -0.10, 0.18))
    l2 = bpy.context.active_object
    l2.scale = (0.13, 0.68, 0.12)
    l2.rotation_euler = (rot_badge[0], rot_badge[1], math.radians(-45))
    l2.data.materials.append(mat_check)
    add_bevel(l2, width=0.03, segments=3)

    # Handle behind stamp
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.50, location=(0, 0.28, -0.30))
    handle = bpy.context.active_object
    handle.rotation_euler = rot_badge
    handle.data.materials.append(mat_handle)
    add_bevel(handle, width=0.04, segments=3)

    save_render("check_stamp_3d.png")


# ────────────────────────────────────────────────────────────────
# Main Execution
# ────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("=" * 60)
    print("Starting Nest 3D Claymorphism Calibrated Batch Rendering...")
    print(f"Output directory: {ASSET_OUTPUT_DIR}")
    print("=" * 60)

    builders = [
        ("1. Home Nest", build_home_nest),
        ("2. Community Chat", build_community_chat),
        ("3. Term Setup Blocks", build_term_setup),
        ("4. System Gears", build_system_gear),
        ("5. Teacher Cap & Scroll", build_teacher_cap),
        ("6. Student Backpack", build_student_backpack),
        ("7. Family Nest", build_family_nest),
        ("8. Notification Bell", build_notification_bell),
        ("9. Chunky Pencil", build_pencil_write),
        ("10. Insight Chart", build_insight_chart),
        ("11. Check Stamp", build_check_stamp),
    ]

    for label, fn in builders:
        print(f"\n--> Rendering {label}...")
        fn()

    print("\n" + "=" * 60)
    print("All 11 calibrated 3D clay assets rendered successfully!")
    print("=" * 60)
