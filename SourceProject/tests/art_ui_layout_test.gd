extends Node

var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	await settle()
	var window := get_tree().root
	check(window.content_scale_size == Vector2i(1920, 1080), "1920 viewport")
	check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "expand viewport")
	var menu: Control = GlobalMenu.menu_overlay
	var completed: Array[int] = []
	check(menu.menu_panel.texture.resource_path == "res://assets/pics/ui/topmenu.png", "Original menu artwork")
	check(menu.toolbar.get_node("Background").texture == GameToolbar.TOOLBAR_TEXTURE, "Original toolbar artwork")
	for resolution in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2280, 1080), Vector2i(1920, 1200), Vector2i(2340, 1080)]:
		window.size = resolution
		await settle()
		for use_insets in [false, true]:
			for ui_root in [GlobalMenu.hud_root, GlobalMenu.overlay_root]:
				var expected := Rect2(Vector2(80, 12), ui_root.size - Vector2(104, 36))
				ui_root.preview_display_safe_rect = ui_root.get_screen_transform() * expected if use_insets else Rect2()
				ui_root.refresh_safe_area()
			await settle()
			menu.toolbar.show()
			await settle()
			check_frame(menu.toolbar, GlobalMenu.hud_root, "toolbar")
			check_frame(GlobalMenu.map_menu_button, GlobalMenu.hud_root, "map menu")
			for control in [menu.toolbar.avatar, menu.toolbar.menu_button, menu.toolbar.hint_button]:
				check(menu.toolbar.get_global_rect().grow(1).encloses(control.get_global_rect()), "Toolbar controls follow artwork")
			if DisplayServer.get_name() != "headless" and resolution == Vector2i(1920, 1080) and not use_insets:
				await capture("toolbar")
			for modal in [GlobalMenu.settings_panel, GlobalMenu.stage_progress_panel, GlobalMenu.badges_panel]:
				if modal is SettingsPanel:
					modal.open_settings()
				elif modal is StageProgressPanel:
					modal.show_stage(1, completed)
				else:
					modal.open_badges()
				await settle()
				var artwork: Control = modal.background if modal is BadgesPanel else modal.panel
				check_frame(artwork, GlobalMenu.overlay_root, modal.name)
				check(artwork.texture != null, "Original panel texture exists")
				if DisplayServer.get_name() != "headless" and resolution == Vector2i(1920, 1080) and not use_insets:
					await capture(modal.name)
				if modal is StageProgressPanel:
					check(artwork.get_global_rect().encloses(modal.content.get_node("StageTitle").get_global_rect()), "Progress title on screen")
					check(artwork.get_global_rect().encloses(modal.content.get_node("StageName").get_global_rect()), "Progress name on screen")
				modal.hide()
			menu.open_menu()
			await get_tree().create_timer(0.35).timeout
			await settle()
			check_frame(menu.menu_panel, GlobalMenu.overlay_root, "menu")
			check_menu_art_targets(menu)
			var original: Vector2 = menu.user_name.global_position
			TranslationServer.set_locale("ar")
			await settle()
			check(menu.user_name.global_position.is_equal_approx(original), "Locale does not mirror artwork controls")
			TranslationServer.set_locale("fa")
			if DisplayServer.get_name() != "headless" and resolution == Vector2i(1920, 1080) and not use_insets:
				await capture("menu")
			menu.close_menu()
			await get_tree().create_timer(0.35).timeout
			await settle()
	check(GlobalMenu.stage_progress_panel.get_parent() == GlobalMenu.overlay_root, "Single progress panel in Overlay")
	print("ART_UI_TEST checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func check_frame(control: Control, ui_root: MobileUiRoot, label: String) -> void:
	var bounds := ui_root.get_global_transform() * ui_root.get_content_rect()
	check(bounds.grow(1).encloses(control.get_global_rect()), label + " safe bounds")
	check(control.scale.is_equal_approx(Vector2.ONE), label + " no manual scale")

func check_menu_art_targets(menu: Control) -> void:
	var image: TextureRect = menu.menu_panel
	check(image.texture.get_size() == Vector2i(1774, 887), "Menu art uses native geometry")
	var controls := image.get_node("MenuContent") as Control
	var target_centers := {
		"HomeButton": Vector2(204, 608),
		"BadgesButton": Vector2(479, 608),
		"SettingsButton": Vector2(751, 608),
		"ProfileButton": Vector2(1020, 608),
		"BackButton": Vector2(1292, 608),
		"ExitButton": Vector2(1567, 608),
		"StageButton": Vector2(1360, 352),
		"CloseButton": Vector2(1645, 144),
	}
	for node_name in target_centers:
		var button := controls.get_node(node_name) as Button
		var image_point := image.get_global_transform_with_canvas().affine_inverse() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
		check(image_point.distance_to(target_centers[node_name]) < 8.0, node_name + " touch center matches image")
		check(button.size.x >= 100 and button.size.y >= 100, node_name + " touch size")
	var dark_brown := Color(0.29, 0.16, 0.09, 1)
	for label_name in ["UserName", "StarLabel", "StarValue", "ScoreLabel", "ScoreValue", "StageLabel", "StageValue"]:
		var label := controls.get_node(label_name) as Label
		check(label.get_theme_color("font_color").is_equal_approx(dark_brown), label_name + " uses dark brown")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func settle() -> void:
	for frame in 12:
		await get_tree().process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/art-ui-%s.png" % label)
