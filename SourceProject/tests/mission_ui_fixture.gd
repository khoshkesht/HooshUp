extends "res://scripts/level_scene.gd"

# همان صحنه و سازنده‌های محصول، بدون اجرای خودکار روایت یا تغییر ذخیرهٔ بازی.
func _ready() -> void:
	layout_design_viewports()
	resized.connect(layout_design_viewports)
	build_mission_ui()
	level_data = {"stage": 1, "mission": 1, "views": {"laptop_chat": {"zoom": 1.2}, "laptop_empty": {"zoom": 1.0}}}
	level_image.texture = load("res://assets/pics/levels/1/g/l1-1.png")
