"""用 Blender 无头渲染 GLB 的四视图预览（正面 / 3/4 / 侧面 / 背面拼成一张图）。

用法:
  blender.exe --background --python tools/preview_glb.py -- <model.glb> <out.png>
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

glb, out = sys.argv[sys.argv.index("--") + 1:][:2]
SIZE = 640

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# 包围盒 → 中心和尺寸
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
center, dims = (lo + hi) / 2, hi - lo
radius = max(dims) * 0.5
print(f"PREVIEW dims(x,y,z)={tuple(round(d, 3) for d in dims)} meshes={len(meshes)} "
      f"tris={sum(len(o.data.polygons) for o in meshes)}")

scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.82, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scene.world = world

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(dims) * 1.15
scene.collection.objects.link(cam)
scene.camera = cam

# glTF 导入后 -Y 为模型正面
tiles = []
for i, deg in enumerate((0, 35, 90, 180)):
    a = math.radians(deg)
    cam.location = center + Vector((math.sin(a), -math.cos(a), 0.15)) * radius * 4
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}.{i}.png"
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(scene.render.filepath)
    tiles.append(np.array(img.pixels[:]).reshape(SIZE, SIZE, 4))

sheet = np.concatenate(tiles, axis=1)
res = bpy.data.images.new("sheet", SIZE * len(tiles), SIZE)
res.pixels = sheet.ravel()
res.filepath_raw = out
res.file_format = "PNG"
res.save()
print("PREVIEW saved", out)
