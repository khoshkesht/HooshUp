extends Node

var checks := 0
var failures: Array[String] = []
var level: Control

func _ready() -> void:
	scene_file_path = "res://scenes/level1.tscn"
	GlobalMenu.set_toolbar_visible(true)
	await settle()
	level = load("res://scenes/level1.tscn").instantiate()
	level.set_script(load("res://tests/mission_ui_fixture.gd"))
	add_child(level)
	await settle()
	var games := [
		["level1_mission2", "tool_match_game", "show_tool_match_game"],
		["level1_mission3", "choice_game", "show_choice_game"],
		["level1_mission4", "response_comparison_game", "show_response_comparison_game"],
		["level1_mission5", "presentation_path_game", "show_presentation_path_game"],
		["level2_mission1", "paper_sort_game", "show_paper_sort_game"],
		["level2_mission2", "clue_connection_game", "show_clue_connection_game"]
	]
	for game_spec in games:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % game_spec[0]))
		var payload := find_payload(data, game_spec[1])
		check(not payload.is_empty(), game_spec[1] + " real mission data")
		level.level_id = "level2" if game_spec[0].begins_with("level2") else "level1"
		var is_laptop_chat_game: bool = game_spec[1] == "tool_match_game" or game_spec[1] == "choice_game"
		if is_laptop_chat_game:
			level.pan_zoom_viewport.hide()
			level.level_image = level.stretch_to_fit_viewport.scene_image
			level.effects = level.get_node("StretchToFitViewport/SceneImage/Effects")
			level.stretch_to_fit_viewport.show_scene(load("res://assets/pics/levels/1/g/l1-1.png"), 1.1)
			await settle()
		level.call(game_spec[2], payload)
		await settle()
		var surface: MissionUiSurface
		for candidate in level.mission_surfaces:
			if is_instance_valid(candidate):
				surface = candidate
		check(surface != null, game_spec[1] + " surface")
		if surface == null:
			continue
		for resolution in [Vector2i(1920, 1080), Vector2i(2258, 1080), Vector2i(2400, 1080), Vector2i(2280, 1080), Vector2i(1920, 1200), Vector2i(2340, 1080)]:
			get_tree().root.size = resolution
			await settle()
			var root: MobileUiRoot = level.mission_ui_root
			root.preview_display_safe_rect = root.get_screen_transform() * Rect2(Vector2(80, 12), root.size - Vector2(104, 36))
			root.refresh_safe_area()
			await settle()
			var bounds: Rect2 = root.get_global_transform() * root.get_content_rect()
			if is_laptop_chat_game:
				check_image_alignment(surface, game_spec[1] + " laptop chat")
				if game_spec[1] == "tool_match_game":
					check_tool_choices(surface)
			else:
				check(bounds.grow(1).encloses(surface.frame.artwork.get_global_rect()), game_spec[1] + " safe canvas")
			if game_spec[1] == "presentation_path_game":
				var board: Panel = surface.content.board
				check(surface.design_size == PresentationPathGame.DESIGN_SIZE, "Presentation uses its own design size")
				check(board.get_global_rect().size.x >= minf(bounds.size.x, 1800.0) * 0.75, "Presentation board remains readable")
			check(surface.content.scale == Vector2.ONE, game_spec[1] + " no root scale")
			check_controls(surface.content, bounds)
			if DisplayServer.get_name() != "headless" and is_laptop_chat_game and resolution == Vector2i(1920, 1080):
				await capture("tool-match-monitor" if game_spec[1] == "tool_match_game" else "choice-monitor")
			if DisplayServer.get_name() != "headless" and game_spec[1] == "tool_match_game" and resolution == Vector2i(2258, 1080):
				await capture("tool-match-phone-aspect")
			if DisplayServer.get_name() != "headless" and game_spec[1] == "tool_match_game" and resolution == Vector2i(2258, 1080):
				await capture("tool-match-phone-aspect")
			var before: Vector2 = surface.content.global_position
			level.level_image.position += Vector2(200, 100)
			level.level_image.scale = Vector2(2, 2)
			await settle()
			if is_laptop_chat_game:
				check_image_alignment(surface, game_spec[1] + " after image pan and zoom")
				if game_spec[1] == "tool_match_game":
					check_tool_choices(surface)
				check(not surface.content.global_position.is_equal_approx(before), game_spec[1] + " moves with image")
			else:
				check(surface.content.global_position.is_equal_approx(before), game_spec[1] + " independent from image pan/zoom")
			level.level_image.scale = Vector2.ONE
			if DisplayServer.get_name() != "headless" and resolution == Vector2i(2340, 1080):
				await capture(game_spec[1])
		if game_spec[1] == "clue_connection_game":
			var clue: Button = surface.content.find_child("Clue0", true, false)
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = clue.get_global_transform() * (clue.size * 0.5)
			event.pressed = true
			get_viewport().push_input(event)
			event.pressed = false
			get_viewport().push_input(event)
			await settle()
			check(surface.content.get_meta("selected_clue", null) == clue, "Displayed clue receives viewport input")
		if game_spec[1] == "paper_sort_game":
			var game := surface.content
			var piece: TextureRect = game.find_child("PaperPiece*", true, false)
			var slot: Panel
			for child in game.get_children():
				if child is Panel and child.get_meta("expected_piece", "") == piece.get_meta("piece_id"):
					slot = child
			if slot != null:
				var touch := InputEventScreenTouch.new()
				touch.pressed = true
				piece.gui_input.emit(touch)
				piece.position = slot.position
				touch.pressed = false
				piece.gui_input.emit(touch)
				check(piece.get_meta("placed", false), "Paper touch drops into matching slot")
				check(piece.get_rect().is_equal_approx(slot.get_rect()), "Paper touch uses displayed coordinates")
		for child in level.mission_ui_root.get_children():
			if child is MissionUiSurface or child.name == "ToolMatchGame":
				child.queue_free()
		await settle()
		if is_laptop_chat_game:
			level.stretch_to_fit_viewport.hide()
			level.level_image = level.get_node("PanZoomViewport/World/LevelImage")
			level.effects = level.get_node("PanZoomViewport/World/LevelImage/Effects")
			level.pan_zoom_viewport.show()
	# کارت‌های هنری، بازگشت از چت، و کنترل‌هایی که بعد از Await ساخته می‌شوند.
	var mission_one: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level1_mission1.json"))
	get_tree().root.size = Vector2i(1920, 1080)
	level.pan_zoom_viewport.hide()
	level.level_image = level.stretch_to_fit_viewport.scene_image
	level.effects = level.get_node("StretchToFitViewport/SceneImage/Effects")
	level.stretch_to_fit_viewport.show_scene(load("res://assets/pics/levels/1/g/l1-1.png"), 1.1)
	await settle()
	level.level_id = "level1"
	level.show_monitor_app(find_payload(mission_one, "monitor_app"))
	await settle()
	var app: TextureRect
	for candidate in level.mission_surfaces:
		if is_instance_valid(candidate):
			app = candidate.content as TextureRect
	check(app.texture.resource_path == "res://assets/pics/ui/hooshup1.png", "Original tool cards artwork")
	var image_surface := app.get_meta("mission_surface") as MissionUiSurface
	check_image_alignment(image_surface, "Monitor cards")
	if DisplayServer.get_name() != "headless":
		await capture("monitor-image")
	get_tree().root.size = Vector2i(2280, 1080)
	await settle()
	check_image_alignment(image_surface, "Monitor cards after viewport resize")
	level.level_image.position += Vector2(113, 47)
	await settle()
	check_image_alignment(image_surface, "Monitor cards after image pan")
	app.queue_free()
	await settle()
	level.show_monitor_app_from_rect()
	await settle()
	check(level.get_mission_effects().any(func(node: Node) -> bool: return node.name == "MonitorApp"), "Return to cards retains independent UI")
	for effect in level.get_mission_effects():
		if effect.name == "MonitorApp":
			check_image_alignment(effect.get_meta("mission_surface") as MissionUiSurface, "Returned monitor cards")
	for effect in level.get_mission_effects():
		effect.queue_free()
	await settle()
	level.show_response_comparison_final_chat({"final_question": "پرسش پایانی", "character_delay": 0.001, "responses": [{"prompt": "انتخاب", "correct": false}]})
	await get_tree().create_timer(1.8).timeout
	await settle()
	var final_chat: TextureRect
	for candidate in level.mission_surfaces:
		if is_instance_valid(candidate):
			final_chat = candidate.content as TextureRect
	check(final_chat != null and final_chat.find_child("FeedbackScroll", true, false) != null, "Dynamic chat feedback registered")
	var answer: Label = final_chat.find_child("ChatResponse", true, false)
	answer.text = "پاسخ بلند آزمایشی\n".repeat(40)
	await settle()
	check((answer.get_parent() as ScrollContainer).get_v_scroll_bar().max_value > answer.get_parent().size.y, "Long AI answer scrolls within original frame")
	final_chat.queue_free()
	await settle()
	var perspective: Node2D = level.create_perspective_chat_surface({})
	var projected_chat: TextureRect = perspective.get_meta("chat")
	var projected_response: Label = level.add_monitor_chat_boxes(projected_chat, {}, Callable(), false)
	projected_response.get_parent().size.y = 30
	await level.type_chat_text(projected_response, "متن\n".repeat(12), 0.001)
	await settle()
	check(projected_response.get_parent().scroll_vertical > 0, "Scripted perspective text follows typing")
	check(perspective.get_parent() == level.effects, "Original perspective artwork remains attached to world")
	perspective.queue_free()
	await settle()
	var mission_three: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level1_mission3.json"))
	level.show_completion_side_story(find_payload(mission_three, "completion_side_story"))
	await settle()
	var story: Control
	for candidate in level.mission_surfaces:
		if is_instance_valid(candidate):
			story = candidate.content
	story.find_child("Project28File", true, false).pressed.emit()
	await settle()
	var notepad: TextureRect = story.find_child("Project28Notepad", true, false)
	check(notepad.texture == level.NOTEPAD_TEXTURE, "Original notepad artwork")
	check(notepad.find_children("*Scroll", "ScrollContainer", true, false).size() == 1, "Notepad document scrolls")
	story.queue_free()
	await settle()
	var small_button := MissionButton.new()
	level.mission_ui_root.add_child(small_button)
	small_button.position = Vector2(1000, 800)
	small_button.size = Vector2(100, 30)
	var touch_state := {"pressed": false}
	small_button.pressed.connect(func() -> void: touch_state.pressed = true)
	click_at(small_button.global_position + Vector2(50, small_button.size.y + 5))
	await settle()
	check(touch_state.pressed, "Expanded touch area receives actual viewport input")
	small_button.queue_free()
	level.dialogue_panel.show_dialogue({"presentation": "thought", "text": "متن فکر برای بررسی چیدمان", "choices": [{"id": "next", "text": "ادامه"}]})
	await settle()
	var dialogue: DialoguePanel = level.dialogue_panel
	var root: MobileUiRoot = level.mission_ui_root
	var bounds: Rect2 = root.get_global_transform() * root.get_content_rect()
	check(bounds.grow(1).encloses(dialogue.panel.get_global_rect()), "Thought bubble inside safe area")
	check(dialogue.panel.size.y < 330, "Short bubble keeps artwork proportions")
	check(dialogue.panel.position.y >= GlobalMenu.menu_overlay.toolbar.get_global_rect().end.y + 15, "Thought below toolbar")
	check(dialogue.panel.scale == Vector2.ONE, "Dialogue no scale")
	check(is_equal_approx(dialogue.panel.modulate.a, 0.85), "Original bubble opacity")
	check(dialogue.text_label.text_direction == Control.TEXT_DIRECTION_RTL, "Dialogue RTL")
	level.phone_message_overlay.show_message("پیام آزمایشی بلند\n".repeat(30))
	await settle()
	var phone: PhoneMessageOverlay = level.phone_message_overlay
	check(bounds.grow(1).encloses(phone.phone.get_global_rect()), "Original phone inside safe area")
	check(phone.phone.texture == PhoneMessageOverlay.DEFAULT_PHONE_TEXTURE, "Original phone artwork")
	check(phone.message_scroll.get_v_scroll_bar().max_value > phone.message_scroll.size.y, "Long phone message can scroll")
	if DisplayServer.get_name() != "headless":
		await capture("phone")
	phone.hide()
	if DisplayServer.get_name() != "headless":
		await capture("dialogue")
	for resolution in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2280, 1080), Vector2i(1920, 1200), Vector2i(2340, 1080)]:
		get_tree().root.size = resolution
		await settle()
		root.preview_display_safe_rect = root.get_screen_transform() * Rect2(Vector2(80, 12), root.size - Vector2(104, 36))
		root.preview_keyboard_height = 180
		root.refresh_safe_area()
		level.dialogue_panel.show_dialogue({"presentation": "hint", "text": "راهنمای آزمایشی\n".repeat(30), "dismiss_on_tap": true})
		phone.show_message("متن پیام\n".repeat(30))
		await settle()
		bounds = root.get_global_transform() * root.get_content_rect()
		check(bounds.grow(1).encloses(dialogue.panel.get_global_rect()), "Long hint with keyboard inside safe area")
		check(bounds.grow(1).encloses(phone.phone.get_global_rect()), "Phone with keyboard inside safe area")
		check(dialogue.content_scroll.get_v_scroll_bar().max_value > dialogue.content_scroll.size.y, "Long hint scrolls")
		var before := phone.phone.position
		TranslationServer.set_locale("en")
		await settle()
		check(phone.phone.position.is_equal_approx(before), "Locale does not move phone")
		TranslationServer.set_locale("fa")
	phone.hide()
	root.preview_keyboard_height = 0
	root.refresh_safe_area()
	dialogue.show_dialogue({"presentation": "thought", "text": "برای ادامه بزن", "dismiss_on_tap": true})
	await settle()
	var dismiss_state := {"dismissed": false}
	dialogue.dismiss_requested.connect(func() -> void: dismiss_state.dismissed = true)
	click_at(dialogue.content_scroll.get_global_rect().get_center())
	await settle()
	check(dismiss_state.dismissed, "Tap inside thought bubble dismisses")
	level.queue_free()
	await settle()
	print("MISSION_UI_TEST checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func check_controls(parent: Control, bounds: Rect2) -> void:
	for child in parent.get_children():
		if not child is Control:
			continue
		if child is Button:
			check(bounds.grow(1).encloses(child.get_global_rect()), parent.name + "/" + child.name + " touch visible")
			if child is MissionButton:
				check(child.get_touch_rect().size.x >= 72 and child.get_touch_rect().size.y >= 72, child.name + " minimum touch area")
			check(child.layout_direction == Control.LAYOUT_DIRECTION_LTR, child.name + " physical LTR")
		if not child is ScrollContainer:
			check_controls(child, bounds)

func check_image_alignment(surface: MissionUiSurface, label: String) -> void:
	check(surface != null and surface.source_image == level.level_image, label + " bound to scene image")
	if surface == null:
		return
	var image_rect: Rect2 = level.level_image.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, level.level_image.size)
	var canvas_rect: Rect2 = surface.image_canvas.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, surface.image_canvas.size)
	check(image_rect.is_equal_approx(canvas_rect), label + " follows image transform")
	if surface.content.name == "MonitorApp":
		var expected_rect: Rect2 = level.level_image.get_global_transform_with_canvas() * level.get_monitor_app_rect()
		var actual_rect: Rect2 = surface.content.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, surface.content.size)
		check(expected_rect.is_equal_approx(actual_rect), label + " artwork matches monitor coordinates")
	if surface.content.name == "LaptopCanvas" or surface.content.name == "ChoiceGame":
		var chat: TextureRect = surface.content.get_node("ToolMatchChat") if surface.content.name == "LaptopCanvas" else surface.content.get_child(0) as TextureRect
		var chat_rect := Rect2(level.level_image.size * Vector2(0.15, 0.145), level.level_image.size * Vector2(0.70, 0.63))
		var expected_chat: Rect2 = level.level_image.get_global_transform_with_canvas() * chat_rect
		var actual_chat: Rect2 = chat.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, chat.size)
		check(expected_chat.is_equal_approx(actual_chat), label + " artwork matches laptop monitor")

func check_tool_choices(surface: MissionUiSurface) -> void:
	var chat: TextureRect = surface.content.get_node("ToolMatchChat")
	var grid: GridContainer = chat.get_node("ToolChoices")
	var chat_rect := chat.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, chat.size)
	var grid_rect := grid.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, grid.size)
	check(chat_rect.grow(1).encloses(grid_rect), "Tool choices grid stays in laptop chat")
	check(grid.layout_direction == Control.LAYOUT_DIRECTION_LTR, "Tool choices geometry stays LTR")
	check(grid.get_child_count() == 4, "Tool choices has four buttons")
	for child in grid.get_children():
		var button := child as Button
		check(button != null, "Tool choice is a button")
		if button != null:
			var button_rect := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
			check(grid_rect.grow(1).encloses(button_rect), "Tool choice remains inside grid")

func find_payload(value: Variant, key: String) -> Dictionary:
	if value is Dictionary:
		if value.has(key):
			return value[key]
		for nested in value.values():
			var result := find_payload(nested, key)
			if not result.is_empty():
				return result
	elif value is Array:
		for nested in value:
			var result := find_payload(nested, key)
			if not result.is_empty():
				return result
	return {}

func settle() -> void:
	for frame in 16:
		await get_tree().process_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/mission-ui-%s.png" % label)

func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	get_viewport().push_input(event)
	event.pressed = false
	get_viewport().push_input(event)
