extends Node

var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	await settle()
	var window := get_tree().root
	window.unresizable = false
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var selector := GlobalMenu.development_mission_selector
	check(selector != null, "Debug selector exists")
	check(GlobalMenu.hud_root.get_parent().layer == 10, "HUD layer")
	check(GlobalMenu.overlay_root.get_parent().layer == 20, "Overlay layer")
	check(GlobalMenu.diagnostics_root.get_parent().layer == 30, "Diagnostics layer")
	check(selector.stage_picker.get_theme_font("font").has_char(0x067E), "Packaged font has Persian pe")
	check(selector.modal_shade.mouse_filter == Control.MOUSE_FILTER_STOP, "Modal shade blocks world input")
	check(selector.diagnostic_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Diagnostics pass input through")
	for future_layout in [false, true]:
		window.content_scale_size = Vector2i(1920, 1080) if future_layout else Vector2i(1280, 720)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if future_layout else Window.CONTENT_SCALE_ASPECT_KEEP
		for resolution in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2280, 1080), Vector2i(1920, 1200), Vector2i(2340, 1080)]:
			window.size = resolution
			await settle()
			for use_insets in [false, true]:
				for ui_root in [GlobalMenu.hud_root, GlobalMenu.overlay_root, GlobalMenu.diagnostics_root]:
					var expected := Rect2(Vector2(80, 12), ui_root.size - Vector2(104, 36))
					ui_root.preview_display_safe_rect = ui_root.get_screen_transform() * expected if use_insets else Rect2()
					ui_root.refresh_safe_area()
					if use_insets:
						check(ui_root.safe_rect.is_equal_approx(expected), "Physical safe-area conversion")
				selector.set_panel_open(true)
				await settle()
				var context := "%s/%s/insets=%s" % [resolution, future_layout, use_insets]
				var bounds := GlobalMenu.overlay_root.get_content_rect()
				check(encloses(bounds, selector.panel.get_global_rect()), context + " panel bounds")
				for control in [selector.stage_picker, selector.mission_picker, selector.launch_button]:
					check(control.is_visible_in_tree() and encloses(selector.panel.get_global_rect(), control.get_global_rect()), context + " visible control " + control.name)
					check(control.size.y >= 72, context + " touch height")
				check(encloses(GlobalMenu.diagnostics_root.get_content_rect(), selector.diagnostic_label.get_global_rect()), context + " diagnostics bounds")
				check(encloses(GlobalMenu.hud_root.get_content_rect(), selector.toggle.get_global_rect()), context + " toggle bounds")
				check(encloses(selector.modal_shade.get_global_rect(), Rect2(Vector2.ZERO, GlobalMenu.overlay_root.size)), context + " full screen shade")
				var initial_position := selector.stage_picker.global_position
				TranslationServer.set_locale("ar")
				await settle()
				check(selector.stage_picker.global_position.is_equal_approx(initial_position), context + " locale keeps physical placement")
				TranslationServer.set_locale("fa")
				selector.stage_picker.show_popup()
				await settle()
				var popup := selector.stage_picker.get_popup()
				check(popup.visible and popup.is_embedded(), context + " embedded popup")
				check(encloses(selector.get_popup_bounds(popup), Rect2(Vector2(popup.position), Vector2(popup.size))), context + " popup bounds")
				popup.index_pressed.emit(popup.item_count - 1)
				check(selector.get_selected_stage() == GameContent.STAGES.size(), context + " last stage selection")
				popup.hide()
				selector.stage_picker.select(0)
				selector._on_stage_selected(0)
				selector.mission_picker.show_popup()
				await settle()
				popup = selector.mission_picker.get_popup()
				check(encloses(selector.get_popup_bounds(popup), Rect2(Vector2(popup.position), Vector2(popup.size))), context + " mission popup bounds")
				popup.index_pressed.emit(popup.item_count - 1)
				check(selector.get_selected_mission() == ProgressStore.MISSIONS_PER_STAGE, context + " last mission selection")
				popup.hide()
	selector.stage_picker.select(selector.stage_picker.item_count - 1)
	selector._on_stage_selected(selector.stage_picker.selected)
	check(selector.launch_button.disabled, "Missing mission cannot launch")
	GlobalMenu.settings_panel.show()
	await settle()
	check(not selector.is_panel_open() and not selector.toggle.visible, "Legacy modal closes selector")
	GlobalMenu.settings_panel.hide()
	await settle()
	check(selector.toggle.visible, "Selector returns after modal")
	selector.set_panel_open(true)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	selector.modal_shade.gui_input.emit(touch)
	check(not selector.is_panel_open(), "Outside touch closes modal")
	selector.stage_picker.select(0)
	selector._on_stage_selected(0)
	selector.mission_picker.select(0)
	selector._on_mission_selected(0)
	check(not selector.launch_button.disabled, "Existing mission can launch")
	# حفظ اجراکننده هنگام تعویض صحنه؛ دادهٔ ذخیره در دسکتاپ فقط در حافظه است.
	get_tree().current_scene = null
	selector.launch_selected_mission()
	await settle()
	check(get_tree().current_scene.scene_file_path == selector.LEVEL_1_SCENE, "Mission launch scene")
	check(ProgressStore.get_active_mission() == Vector2i(1, 1), "Selected mission preserved")
	get_tree().current_scene.queue_free()
	await settle()
	print("MOBILE_UI_TEST checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for frame in 12:
		await get_tree().process_frame

func encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1).encloses(inner)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
