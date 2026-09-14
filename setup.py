# Environment-artist startup. Run once: `bin/blender --python setup.py` (opens a window briefly), then commit portable/config.
import bpy, os

# preferences
kc = os.path.join(bpy.utils.system_resource('SCRIPTS'), 'presets', 'keyconfig', 'Industry_Compatible.py')
bpy.ops.preferences.keyconfig_activate(filepath=kc)
p = bpy.context.preferences
p.view.show_splash = False
p.inputs.use_zoom_to_mouse = True
p.edit.undo_steps = 128

# scene: metric, no default cube
sc = bpy.context.scene
sc.unit_settings.system, sc.unit_settings.scale_length = 'METRIC', 1.0
if 'Cube' in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects['Cube'])

# workspaces not needed for environment art
bpy.data.batch_remove([ws for ws in bpy.data.workspaces if ws.name in ('Animation', 'Compositing', 'Scripting')])

# area edits need the workspace live in the window, so visit each one per event-loop tick
todo = list(bpy.data.workspaces)
def step():
    win = bpy.context.window_manager.windows[0]
    for area in win.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces[0].overlay.show_stats = True   # poly/vert counts in viewport
    for area in [a for a in win.screen.areas if a.ui_type == 'TIMELINE']:
        with bpy.context.temp_override(window=win, area=area):
            bpy.ops.screen.area_close()
    if todo:
        win.workspace = todo.pop()
        return 0.1
    win.workspace = bpy.data.workspaces['Layout']
    bpy.ops.wm.save_userpref()
    bpy.ops.wm.save_homefile()
    os._exit(0)  # skip the "unsaved changes" quit prompt
bpy.app.timers.register(step, first_interval=0.5)
