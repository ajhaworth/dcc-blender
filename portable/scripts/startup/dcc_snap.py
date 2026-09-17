# Maya-style snap holds: bound on PRESS and RELEASE in dcc.py (X grid, V vertex, C edge, Shift+V surface).
# One operator because a hold must set several snap settings at once and restore them; wm.context_set_* sets only one.
import bpy

KEYS = ('use_snap', 'snap_elements', 'use_snap_align_rotation', 'snap_target')
saved = {}  # settings from before the key went down; empty = no hold active

class VIEW3D_OT_dcc_snap_hold(bpy.types.Operator):
    bl_idname, bl_label = 'view3d.dcc_snap_hold', 'Snap Hold'
    elements: bpy.props.EnumProperty(items=[(i.identifier, i.name, '') for i in bpy.types.ToolSettings.bl_rna.properties['snap_elements'].enum_items], options={'ENUM_FLAG'})
    align: bpy.props.BoolProperty()
    target: bpy.props.StringProperty()  # '' keeps the current snap target
    release: bpy.props.BoolProperty()

    def execute(self, context):
        ts = context.tool_settings
        if self.release:
            for k, v in saved.items():
                setattr(ts, k, v)
            saved.clear()
        else:
            if not saved:  # guard: a second press (key repeat) must not overwrite the original state
                saved.update({k: getattr(ts, k) for k in KEYS})
            ts.use_snap, ts.snap_elements, ts.use_snap_align_rotation = True, self.elements, self.align
            if self.target:
                ts.snap_target = self.target
        return {'FINISHED'}

def register():
    bpy.utils.register_class(VIEW3D_OT_dcc_snap_hold)

def unregister():
    bpy.utils.unregister_class(VIEW3D_OT_dcc_snap_hold)
