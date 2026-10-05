extends Control

signal mission_advance_requested(stage_number: int, mission_number: int)

@export var level_id := "level1"

const HOTSPOT_SCENE := preload("res://components/hotspot.tscn")
const ANIMATED_LOGO_SCENE := preload("res://components/animated_logo.tscn")
const PLAYER_MOVEMENT_SCRIPT := preload("res://components/player_movement.gd")
const CHECK_ICON := preload("res://assets/pics/ui/check.png")
const DOCUMENT_ICON := preload("res://assets/pics/ui/document.png")
const NOTEPAD_TEXTURE := preload("res://assets/pics/ui/notepad.png")
const COUNTDOWN_SCENE := preload("res://components/countdown.tscn")
const BACKGROUND_MUSIC := preload("res://assets/sounds/music1.mp3")
const PRESENTATION_PATH_GAME_SCRIPT := preload("res://components/presentation_path_game.gd")
const MARS_PRESENTATION_TEXTURE := preload("res://assets/pics/ui/mars-presentation.png")
const CHAT_BUTTON_COLOR := Color("3badae")
const CHAT_BUTTON_HOVER_COLOR := Color("54c3c1")
const CHAT_BUTTON_BORDER_COLOR := Color("8bd8d2")
const CHAT_BUTTON_DONE_COLOR := Color("6fae9c")

@onready var level_image: TextureRect = $PanZoomViewport/World/LevelImage
@onready var pan_zoom_viewport: PanZoomViewport = $PanZoomViewport
@onready var stretch_to_fit_viewport: StretchToFitViewport = $StretchToFitViewport
@onready var hotspots: Control = $PanZoomViewport/World/LevelImage/Hotspots
@onready var effects: Control = $PanZoomViewport/World/LevelImage/Effects
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var phone_message_overlay: PhoneMessageOverlay = $PhoneMessageOverlay
@onready var notification_sound: AudioStreamPlayer = $NotificationSound
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var laptop_sound: AudioStreamPlayer = $LaptopSound
@onready var player_typing_sound: AudioStreamPlayer = $PlayerTypingSound
@onready var stage_progress_panel: StageProgressPanel = $StageProgressPanel

var level_data: Dictionary
var found_clues: Dictionary = {}
var active_hotspot_index := -1
var current_hotspot: Hotspot
var hotspots_started := false
var checkpoint_loaded := false
var player_movement: PlayerMovement
var intro_is_open := false
var unlocked_hotspot_ids: Dictionary = {}
var monitor_app_rect := Rect2()
var monitor_app_data: Dictionary = {}
var read_monitor_tool_ids: Dictionary = {}
var all_monitor_tools_read := false
var pending_dialogue_sequence: Array = []
var pending_dialogue_sequence_index := -1
var pending_dialogue_sequence_completes_mission := false
var dialogue_sequence_completion_ready := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	background_music.stream = BACKGROUND_MUSIC
	var background_music_stream := background_music.stream as AudioStreamMP3
	if background_music_stream != null:
		background_music_stream.loop = true
	var typing_stream := player_typing_sound.stream as AudioStreamMP3
	if typing_stream != null:
		typing_stream.loop = true
	GlobalMenu.set_hint_available(true)
	if not GlobalMenu.hint_requested.is_connected(_on_hint_requested):
		GlobalMenu.hint_requested.connect(_on_hint_requested)
	if not GameSettings.has_player_profile():
		GlobalMenu.open_initial_player_setup()
		await GlobalMenu.settings_panel.settings_saved
	load_level_data()
	if level_data.is_empty():
		return
	pan_zoom_viewport.zoom = float(level_data.get("zoom", pan_zoom_viewport.zoom))
	dialogue_panel.choice_selected.connect(_on_dialogue_choice_selected)
	dialogue_panel.dismiss_requested.connect(_on_dialogue_dismiss_requested)
	phone_message_overlay.closed.connect(_on_phone_message_closed)
	phone_message_overlay.sending_finished.connect(_on_phone_sending_finished)
	stage_progress_panel.closed.connect(_on_stage_progress_closed)
	stage_progress_panel.badges_requested.connect(_on_stage_badges_requested)
	GameSettings.background_music_changed.connect(_on_background_music_changed)
	_sync_background_music()
	pan_zoom_viewport.world_tapped.connect(_on_world_tapped)
	level_image.texture = GameSettings.get_level_texture(str(level_data.get("background_asset", "")), level_id)
	var stage_number := int(level_data.get("stage", 0))
	var mission_number := int(level_data.get("mission", 0))
	if not ProgressStore.is_test_mission(stage_number, mission_number) and ProgressStore.is_mission_complete(stage_number, mission_number):
		await get_tree().process_frame
		show_stage_progress()
		return
	var saved_checkpoint := ProgressStore.get_checkpoint(stage_number, mission_number)
	# Direct test selection only bypasses the initial completion/checkpoint checks.
	# From this point the mission uses normal progress and score persistence.
	ProgressStore.consume_test_mission(stage_number, mission_number)
	if saved_checkpoint > 0:
		await load_checkpoint(saved_checkpoint)
		return
	pan_zoom_viewport.set_pan_enabled(true)
	pan_zoom_viewport.reset_view()
	create_player()
	create_hotspots()
	var intro_data: Dictionary = level_data.get("intro", {})
	if not intro_data.is_empty():
		await play_intro(intro_data)
	elif level_data.has("dialogue"):
		dialogue_panel.show_dialogue(level_data.get("dialogue", {}))
	await get_tree().process_frame

func _on_hint_requested() -> void:
	if level_data.is_empty():
		return
	var stage_number := int(level_data.get("stage", 0))
	var mission_number := int(level_data.get("mission", 0))
	if ProgressStore.is_mission_complete(stage_number, mission_number):
		return
	var hint_text := ScoreStore.get_mission_hint(stage_number, mission_number)
	if hint_text.is_empty():
		return
	ScoreStore.record_hint_used(stage_number, mission_number)
	dialogue_panel.show_dialogue({
		"presentation": "hint",
		"dismiss_on_tap": true,
		"text": hint_text
	})

func play_intro(intro_data: Dictionary) -> void:
	var scripted_monitor_chat: Dictionary = intro_data.get("scripted_monitor_chat", {})
	if not scripted_monitor_chat.is_empty():
		await show_intro_scripted_monitor_chat(scripted_monitor_chat)
	var monitor_chat: Dictionary = intro_data.get("monitor_chat", {})
	if not monitor_chat.is_empty():
		await show_intro_monitor_chat(monitor_chat)
	var alert_hotspot_id := str(intro_data.get("alert_hotspot_id", ""))
	var alert_hotspot_matches := not alert_hotspot_id.is_empty() and is_instance_valid(current_hotspot) and str(current_hotspot.get_meta("hotspot_id", "")) == alert_hotspot_id
	if alert_hotspot_matches:
		current_hotspot.hide()
	var delay_seconds: float = float(intro_data.get("delay_seconds", 0.0))
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	var sound_path := str(intro_data.get("notification_sound", ""))
	if not sound_path.is_empty():
		notification_sound.stream = load(sound_path) as AudioStream
	if notification_sound.stream != null:
		notification_sound.play()
	if alert_hotspot_matches and is_instance_valid(current_hotspot):
		current_hotspot.show()
		current_hotspot.set_alerting(true)
	var intro_dialogue: Dictionary = intro_data.get("dialogue", {})
	if not intro_dialogue.is_empty():
		intro_is_open = true
		if str(intro_dialogue.get("presentation", "")) == "phone_message":
			phone_message_overlay.show_message(
				str(intro_dialogue.get("text", "")),
				str(intro_dialogue.get("close_text", "بستن"))
			)
		else:
			dialogue_panel.show_dialogue(intro_dialogue)

func show_intro_scripted_monitor_chat(chat_data: Dictionary) -> void:
	pan_zoom_viewport.hide()
	pan_zoom_viewport.set_pan_enabled(false)
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(
		GameSettings.get_level_texture(str(chat_data.get("background_asset", "l1-1")), level_id),
		float(chat_data.get("zoom", 1.2))
	)
	await get_tree().process_frame
	await show_scripted_monitor_chat(chat_data)
	close_intro_monitor_scene()

func show_scripted_monitor_chat(chat_data: Dictionary) -> void:
	DragGestureHint.show_once(self, "laptop_chat")
	var chat_surface := create_perspective_chat_surface(chat_data)
	var chat: TextureRect = chat_surface.get_meta("chat") as TextureRect
	var response_box := add_monitor_chat_boxes(chat, {}, Callable(), false)
	var question_box := chat.get_node("Question") as Label
	var character_delay := float(chat_data.get("character_delay", 0.025))
	for step_value in chat_data.get("steps", []):
		var step: Dictionary = step_value as Dictionary
		var is_assistant := str(step.get("role", "assistant")) == "assistant"
		var target_box := response_box if is_assistant else question_box
		target_box.text = ""
		var thinking_delay := float(step.get("thinking_delay", 1.5 if is_assistant else 0.0))
		if thinking_delay > 0.0:
			response_box.text = "..."
			await get_tree().create_timer(thinking_delay).timeout
			response_box.text = ""
		await type_chat_text(target_box, str(step.get("text", "")), character_delay, not is_assistant)
		var thinking_after_delay := float(step.get("thinking_after_delay", 0.0))
		if thinking_after_delay > 0.0:
			response_box.text = "..."
			await get_tree().create_timer(thinking_after_delay).timeout
			response_box.text = ""
		await get_tree().create_timer(float(step.get("after_delay", 0.45))).timeout
	var research_progress: Dictionary = chat_data.get("research_progress", {})
	if not research_progress.is_empty():
		await show_research_progress(chat, response_box, research_progress)
	if is_instance_valid(chat_surface):
		chat_surface.queue_free()

func create_perspective_chat_surface(chat_data: Dictionary) -> Node2D:
	var normalized_size: Array = chat_data.get("size", [0.7, 0.63])
	var chat_size := Vector2(
		float(normalized_size[0]) * level_image.size.x,
		float(normalized_size[1]) * level_image.size.y
	)
	var surface := Node2D.new()
	surface.name = "ScriptedMonitorChatSurface"
	effects.add_child(surface)

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(maxi(1, roundi(chat_size.x)), maxi(1, roundi(chat_size.y)))
	surface.add_child(viewport)

	var chat := TextureRect.new()
	chat.name = "ScriptedMonitorChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.size = Vector2(viewport.size)
	viewport.add_child(chat)

	var normalized_quad: Array = chat_data.get("perspective_quad", [])
	if normalized_quad.size() != 4:
		var normalized_position: Array = chat_data.get("position", [0.5, 0.5])
		var left := float(normalized_position[0]) - float(normalized_size[0]) * 0.5
		var top := float(normalized_position[1]) - float(normalized_size[1]) * 0.5
		normalized_quad = [[left, top], [left + float(normalized_size[0]), top], [left + float(normalized_size[0]), top + float(normalized_size[1])], [left, top + float(normalized_size[1])]]
	var polygon := Polygon2D.new()
	polygon.texture = viewport.get_texture()
	polygon.polygon = PackedVector2Array([
		Vector2(float(normalized_quad[0][0]) * level_image.size.x, float(normalized_quad[0][1]) * level_image.size.y),
		Vector2(float(normalized_quad[1][0]) * level_image.size.x, float(normalized_quad[1][1]) * level_image.size.y),
		Vector2(float(normalized_quad[2][0]) * level_image.size.x, float(normalized_quad[2][1]) * level_image.size.y),
		Vector2(float(normalized_quad[3][0]) * level_image.size.x, float(normalized_quad[3][1]) * level_image.size.y)
	])
	polygon.uv = PackedVector2Array([
		Vector2.ZERO,
		Vector2(viewport.size.x, 0.0),
		Vector2(viewport.size),
		Vector2(0.0, viewport.size.y)
	])
	surface.add_child(polygon)
	surface.set_meta("chat", chat)
	return surface

func show_research_progress(chat: TextureRect, response_box: Label, progress_data: Dictionary) -> void:
	response_box.hide()
	var progress_label := Label.new()
	progress_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	progress_label.text_direction = Control.TEXT_DIRECTION_RTL
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.042))
	progress_label.add_theme_color_override("font_color", Color("142d4e"))
	progress_label.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.43)
	progress_label.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.24)
	chat.add_child(progress_label)
	var statuses: Array = progress_data.get("statuses", [])
	var status_delay := float(progress_data.get("status_delay", 2.5))
	for status_value in statuses:
		progress_label.text = "در حال بررسی تحقیق...\n%s" % str(status_value)
		await get_tree().create_timer(status_delay).timeout

func show_intro_monitor_chat(chat_data: Dictionary) -> void:
	DragGestureHint.show_once(self, "laptop_chat")
	pan_zoom_viewport.hide()
	pan_zoom_viewport.set_pan_enabled(false)
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(
		GameSettings.get_level_texture(str(chat_data.get("background_asset", "l1-1")), level_id),
		float(chat_data.get("zoom", 1.2))
	)
	await get_tree().process_frame
	var chat := TextureRect.new()
	chat.name = "IntroMonitorChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load(str(chat_data.get("asset", "res://assets/pics/ui/hooshup-back.png"))) as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	var normalized_position: Array = chat_data.get("position", [0.5, 0.5])
	var normalized_size: Array = chat_data.get("size", [0.7, 0.63])
	effects.add_child(chat)
	chat.size = Vector2(float(normalized_size[0]) * level_image.size.x, float(normalized_size[1]) * level_image.size.y)
	chat.position = Vector2(
		float(normalized_position[0]) * level_image.size.x - chat.size.x * 0.5,
		float(normalized_position[1]) * level_image.size.y - chat.size.y * 0.5
	)
	var response_box := add_monitor_chat_boxes(chat, chat_data, Callable(), false)
	var question_box := chat.get_node("Question") as Label
	var send_button := Button.new()
	send_button.name = "Send"
	send_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	send_button.flat = true
	send_button.disabled = true
	send_button.tooltip_text = str(chat_data.get("send_tooltip", ""))
	chat.add_child(send_button)
	send_button.position = Vector2(chat.size.x * 0.89, chat.size.y * 0.82)
	send_button.size = Vector2(chat.size.x * 0.08, chat.size.y * 0.12)
	var send_hint := Label.new()
	send_hint.name = "SendHint"
	send_hint.layout_direction = Control.LAYOUT_DIRECTION_LTR
	send_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	send_hint.text = str(chat_data.get("send_indicator", ""))
	send_hint.add_theme_color_override("font_color", Color("fda22c"))
	send_hint.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.05))
	send_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_child(send_hint)
	send_hint.position = Vector2(chat.size.x * 0.90, chat.size.y * 0.8)
	send_hint.size = Vector2(chat.size.x * 0.06, chat.size.y * 0.06)
	var hint_tween := send_hint.create_tween().set_loops()
	hint_tween.tween_property(send_hint, "modulate:a", 0.2, 0.55)
	hint_tween.tween_property(send_hint, "modulate:a", 1.0, 0.55)
	await type_chat_text(question_box, str(chat_data.get("title", "")), float(chat_data.get("question_character_delay", 0.06)), true)
	send_button.disabled = false
	await send_button.pressed
	send_hint.hide()
	send_button.hide()
	response_box.text = "..."
	await get_tree().create_timer(float(chat_data.get("response_wait", 1.5))).timeout
	response_box.text = ""
	await type_chat_text(response_box, str(chat_data.get("response", "")), float(chat_data.get("response_character_delay", 0.02)))
	var follow_up: Dictionary = chat_data.get("follow_up", {})
	if not follow_up.is_empty():
		await get_tree().create_timer(float(follow_up.get("before_delay", 1.0))).timeout
		question_box.text = ""
		await type_chat_text(question_box, str(follow_up.get("text", "")), float(follow_up.get("character_delay", 0.05)), true)
		await get_tree().create_timer(float(follow_up.get("after_delay", 2.0))).timeout
	chat.queue_free()
	var tool_match_game: Dictionary = chat_data.get("tool_match_game", {})
	if not tool_match_game.is_empty():
		show_tool_match_game(tool_match_game)
		return
	close_intro_monitor_scene()

func close_intro_monitor_scene() -> void:
	stretch_to_fit_viewport.hide()
	level_image = $PanZoomViewport/World/LevelImage
	effects = $PanZoomViewport/World/LevelImage/Effects
	pan_zoom_viewport.show()
	pan_zoom_viewport.set_pan_enabled(true)
	pan_zoom_viewport.reset_view()

func show_tool_match_game(game_data: Dictionary) -> void:
	var game := Control.new()
	game.name = "ToolMatchGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(game)
	await get_tree().process_frame

	var chat := TextureRect.new()
	chat.name = "ToolMatchChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.size = Vector2(game.size.x * 0.70, game.size.y * 0.63)
	chat.position = Vector2(game.size.x * 0.15, game.size.y * 0.145)
	game.add_child(chat)

	var title := make_game_label(str(game_data.get("title", "")), roundi(chat.size.y * 0.055), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color("142d4e"))
	title.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.12)
	title.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.08)
	chat.add_child(title)
	var question_box := make_game_label("", roundi(chat.size.y * 0.048), HORIZONTAL_ALIGNMENT_RIGHT)
	question_box.add_theme_color_override("font_color", Color("142d4e"))
	question_box.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.21)
	question_box.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.16)
	chat.add_child(question_box)
	var feedback := make_game_label("", roundi(chat.size.y * 0.035), HORIZONTAL_ALIGNMENT_RIGHT)
	feedback.add_theme_color_override("font_color", Color("1b5d45"))
	feedback.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.70)
	feedback.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.07)
	chat.add_child(feedback)

	var tools: Array = game_data.get("tools", [])
	var tasks: Array = game_data.get("tasks", [])
	var tool_buttons: Array[Button] = []
	for index in tools.size():
		var tool: Dictionary = tools[index]
		var button := Button.new()
		button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		button.text_direction = Control.TEXT_DIRECTION_RTL
		button.text = "%s  %s" % [str(tool.get("icon", "")), str(tool.get("text", ""))]
		button.set_meta("tool_id", str(tool.get("id", "")))
		button.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.045))
		button.add_theme_color_override("font_color", Color("ecf7ff"))
		button.position = Vector2(chat.size.x * (0.16 + 0.38 * (index % 2)), chat.size.y * (0.40 + 0.15 * (index / 2)))
		button.size = Vector2(chat.size.x * 0.36, chat.size.y * 0.12)
		chat.add_child(button)
		tool_buttons.append(button)
		button.pressed.connect(_on_tool_match_answer_pressed.bind(game, button, question_box, feedback, tool_buttons, tasks))
	if tasks.is_empty():
		return
	game.set_meta("tool_match_current_task", 0)
	game.set_meta("tool_match_transitioning", false)
	game.set_meta("tool_match_data", game_data)
	render_tool_match_question(game, question_box, feedback, tool_buttons, tasks)

func render_tool_match_question(game: Control, question_box: Label, feedback: Label, tool_buttons: Array[Button], tasks: Array) -> void:
	var current_task := int(game.get_meta("tool_match_current_task", 0))
	question_box.text = str((tasks[current_task] as Dictionary).get("text", ""))
	feedback.text = ""
	for tool_button in tool_buttons:
		tool_button.disabled = false
		tool_button.add_theme_stylebox_override("normal", make_game_style(CHAT_BUTTON_COLOR, CHAT_BUTTON_BORDER_COLOR))
		tool_button.add_theme_stylebox_override("hover", make_game_style(CHAT_BUTTON_HOVER_COLOR, CHAT_BUTTON_BORDER_COLOR))

func _on_tool_match_answer_pressed(game: Control, button: Button, question_box: Label, feedback: Label, tool_buttons: Array[Button], tasks: Array) -> void:
	if bool(game.get_meta("tool_match_transitioning", false)):
		return
	var current_task := int(game.get_meta("tool_match_current_task", 0))
	var task: Dictionary = tasks[current_task] as Dictionary
	var game_data: Dictionary = game.get_meta("tool_match_data", {})
	if str(button.get_meta("tool_id", "")) != str(task.get("tool", "")):
		ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		feedback.add_theme_color_override("font_color", Color("a33c32"))
		feedback.text = str(game_data.get("wrong_feedback", ""))
		return
	game.set_meta("tool_match_transitioning", true)
	button.disabled = true
	button.add_theme_stylebox_override("normal", make_game_style(CHAT_BUTTON_DONE_COLOR, CHAT_BUTTON_BORDER_COLOR))
	feedback.add_theme_color_override("font_color", Color("1b5d45"))
	feedback.text = str(game_data.get("correct_feedback", ""))
	await get_tree().create_timer(float(game_data.get("answer_feedback_delay", 0.9))).timeout
	current_task += 1
	if current_task >= tasks.size():
		for tool_button in tool_buttons:
			tool_button.hide()
		question_box.text = ""
		feedback.text = ""
		ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		question_box.text = "..."
		await get_tree().create_timer(1.5).timeout
		question_box.text = ""
		await type_chat_text(question_box, str(game_data.get("completion_response", "")), float(game_data.get("completion_character_delay", 0.025)))
		await get_tree().create_timer(float(game_data.get("completion_delay", 2.0))).timeout
		if is_instance_valid(game):
			game.queue_free()
		close_intro_monitor_scene()
		show_stage_progress()
		return
	game.set_meta("tool_match_current_task", current_task)
	game.set_meta("tool_match_transitioning", false)
	render_tool_match_question(game, question_box, feedback, tool_buttons, tasks)

func make_game_label(text_value: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text_value
	label.add_theme_color_override("font_color", Color("f4f8ff"))
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_game_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style

func load_checkpoint(checkpoint_id: int) -> void:
	var checkpoints: Dictionary = level_data.get("checkpoints", {})
	var checkpoint_data: Dictionary = checkpoints.get(str(checkpoint_id), {})
	if checkpoint_data.is_empty():
		push_error("Checkpoint is missing: %s" % checkpoint_id)
		return
	pan_zoom_viewport.hide()
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(
		GameSettings.get_level_texture(str(checkpoint_data.get("background_asset", "")), level_id),
		float(checkpoint_data.get("zoom", 1.0))
	)
	DragGestureHint.show_once(self, "laptop")
	checkpoint_loaded = true
	if is_instance_valid(player_movement):
		player_movement.hide_player()
	pan_zoom_viewport.set_pan_enabled(false)
	for hotspot in hotspots.get_children():
		hotspot.queue_free()
	current_hotspot = null
	for effect in effects.get_children():
		effect.queue_free()
	await get_tree().process_frame
	if checkpoint_data.has("animated_logo"):
		show_animated_logo(checkpoint_data.get("animated_logo", {}))
	play_laptop_sound(str(checkpoint_data.get("loop_sound", "")))
	var checkpoint_dialogue: Dictionary = checkpoint_data.get("dialogue", {})
	if not checkpoint_dialogue.is_empty():
		dialogue_panel.show_dialogue(checkpoint_dialogue)

func play_laptop_sound(sound_path: String) -> void:
	laptop_sound.stop()
	if sound_path.is_empty() or not GameSettings.background_music_enabled:
		return
	laptop_sound.stream = load(sound_path) as AudioStream
	if laptop_sound.stream != null:
		laptop_sound.play()

func _on_laptop_sound_finished() -> void:
	if checkpoint_loaded and GameSettings.background_music_enabled and laptop_sound.stream != null:
		laptop_sound.play()

func _on_background_music_changed(is_enabled: bool) -> void:
	if not is_enabled:
		background_music.stop()
		laptop_sound.stop()
		return
	_sync_background_music()

func _sync_background_music() -> void:
	if GameSettings.background_music_enabled and not background_music.playing:
		background_music.play()

func show_animated_logo(logo_data: Dictionary) -> void:
	var logo: Node2D = ANIMATED_LOGO_SCENE.instantiate()
	var normalized_position: Array = logo_data.get("position", [0.5, 0.5])
	logo.position = Vector2(
		float(normalized_position[0]) * level_image.size.x,
		float(normalized_position[1]) * level_image.size.y
	)
	logo.scale = Vector2.ONE * float(logo_data.get("scale", 0.25))
	logo.connect("activated", _on_animated_logo_activated.bind(logo, logo_data))
	effects.add_child(logo)

func _on_animated_logo_activated(logo: Node2D, logo_data: Dictionary) -> void:
	laptop_sound.stop()
	if is_instance_valid(logo):
		logo.queue_free()
	var monitor_app: Dictionary = logo_data.get("monitor_app", {})
	show_monitor_app(monitor_app)

func show_monitor_app(app_data: Dictionary) -> void:
	DragGestureHint.show_once(self, "laptop")
	monitor_app_data = app_data
	var asset_path := str(app_data.get("asset", ""))
	var texture := load(asset_path) as Texture2D
	if texture == null:
		push_error("Monitor app asset is missing: %s" % asset_path)
		return
	var app := TextureRect.new()
	app.name = "MonitorApp"
	app.layout_direction = Control.LAYOUT_DIRECTION_LTR
	app.texture = texture
	app.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app.stretch_mode = TextureRect.STRETCH_SCALE
	app.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var normalized_position: Array = app_data.get("position", [0.5, 0.5])
	var normalized_size: Array = app_data.get("size", [0.7, 0.63])
	effects.add_child(app)
	app.size = Vector2(float(normalized_size[0]) * level_image.size.x, float(normalized_size[1]) * level_image.size.y)
	app.position = Vector2(
		float(normalized_position[0]) * level_image.size.x - app.size.x * 0.5,
		float(normalized_position[1]) * level_image.size.y - app.size.y * 0.5
	)
	monitor_app_rect = Rect2(app.position, app.size)
	add_monitor_card_buttons(app)

func add_monitor_card_buttons(app: TextureRect) -> void:
	var card_order := ["idea", "write", "image", "explain", "plan"]
	var tools_by_id: Dictionary = {}
	for tool_data in monitor_app_data.get("tools", []):
		var tool_data_dictionary: Dictionary = tool_data as Dictionary
		tools_by_id[str(tool_data_dictionary.get("id", ""))] = tool_data_dictionary
	for card_index in card_order.size():
		var tool: Dictionary = tools_by_id.get(str(card_order[card_index]), {})
		if tool.is_empty():
			continue
		var card := Button.new()
		var tool_id := str(tool.get("id", ""))
		card.name = "Card_%s" % tool_id
		card.flat = true
		card.tooltip_text = str(tool.get("title", ""))
		card.layout_direction = Control.LAYOUT_DIRECTION_LTR
		card.pressed.connect(_on_monitor_card_pressed.bind(tool))
		app.add_child(card)
		card.position = Vector2(app.size.x * (0.127 + 0.110 * card_index), app.size.y * 0.680)
		card.size = Vector2(app.size.x * 0.108, app.size.y * 0.255)
		add_monitor_card_check(card, read_monitor_tool_ids.has(tool_id))

func _on_monitor_card_pressed(tool: Dictionary) -> void:
	mark_monitor_tool_read(str(tool.get("id", "")))
	for effect in effects.get_children():
		if effect.name == "MonitorApp":
			effect.queue_free()
	show_monitor_chat(tool)

func mark_monitor_tool_read(tool_id: String) -> void:
	if tool_id.is_empty():
		return
	read_monitor_tool_ids[tool_id] = true
	var all_tools: Array = monitor_app_data.get("tools", [])
	all_monitor_tools_read = not all_tools.is_empty() and read_monitor_tool_ids.size() >= all_tools.size()
	if all_monitor_tools_read:
		ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))

func add_monitor_card_check(card: Button, is_read: bool) -> void:
	if card.has_node("Check"):
		return
	if not is_read:
		var hint := Label.new()
		hint.name = "Check"
		hint.layout_direction = Control.LAYOUT_DIRECTION_LTR
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.text = "●"
		hint.add_theme_color_override("font_color", Color("fda22c"))
		hint.add_theme_font_size_override("font_size", roundi(card.size.y * 0.25))
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hint)
		hint.size = Vector2(card.size.x * 0.30, card.size.y * 0.22)
		hint.position = Vector2((card.size.x - hint.size.x) * 0.5, card.size.y * 0.80)
		var blink := hint.create_tween().set_loops()
		blink.tween_property(hint, "modulate:a", 0.25, 0.55)
		blink.tween_property(hint, "modulate:a", 1.0, 0.55)
		return
	var check := TextureRect.new()
	check.name = "Check"
	check.layout_direction = Control.LAYOUT_DIRECTION_LTR
	check.texture = CHECK_ICON
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(check)
	check.size = Vector2(card.size.x * 0.30, card.size.y * 0.22)
	check.position = Vector2((card.size.x - check.size.x) * 0.5, card.size.y * 0.80)

func has_read_all_monitor_tools() -> bool:
	return all_monitor_tools_read

func show_monitor_chat(tool: Dictionary) -> void:
	DragGestureHint.show_once(self, "laptop_chat")
	var chat := TextureRect.new()
	chat.name = "MonitorChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(chat)
	chat.position = monitor_app_rect.position
	chat.size = monitor_app_rect.size
	var response_box := add_monitor_chat_boxes(chat, tool)
	var question_box := chat.get_node("Question") as Label
	type_chat_sequence(question_box, str(tool.get("title", "#")), response_box, str(tool.get("response", "#")))

func add_monitor_chat_boxes(chat: TextureRect, tool: Dictionary, close_callback := Callable(), show_close := true) -> Label:
	var response_box := Label.new()
	response_box.name = "ChatResponse"
	response_box.layout_direction = Control.LAYOUT_DIRECTION_LTR
	response_box.text_direction = Control.TEXT_DIRECTION_RTL
	response_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	response_box.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	response_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response_box.add_theme_color_override("font_color", Color(0.04, 0.12, 0.28, 1.0))
	response_box.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.055) + 2)
	response_box.text = ""
	chat.add_child(response_box)
	response_box.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.15)
	response_box.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.54)

	var question_box := Label.new()
	question_box.name = "Question"
	question_box.layout_direction = Control.LAYOUT_DIRECTION_LTR
	question_box.text_direction = Control.TEXT_DIRECTION_RTL
	question_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	question_box.add_theme_color_override("font_color", Color(0.04, 0.12, 0.28, 1.0))
	question_box.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.038) + 2)
	question_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_box.text = ""
	chat.add_child(question_box)
	question_box.position = Vector2(chat.size.x * 0.18, chat.size.y * 0.82)
	question_box.size = Vector2(chat.size.x * 0.65, chat.size.y * 0.10)
	if not show_close:
		return response_box

	var close_button := Button.new()
	close_button.name = "Close"
	close_button.flat = true
	close_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	close_button.text = "×"
	close_button.add_theme_color_override("font_color", Color(0.04, 0.12, 0.28, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(0.04, 0.12, 0.28, 1.0))
	close_button.add_theme_color_override("font_pressed_color", Color(0.04, 0.12, 0.28, 1.0))
	close_button.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.095))
	close_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var close_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]:
		close_button.add_theme_stylebox_override(state, close_style)
	if close_callback.is_valid():
		close_button.pressed.connect(close_callback.bind(chat))
	else:
		close_button.pressed.connect(_on_monitor_chat_closed.bind(chat))
	chat.add_child(close_button)
	close_button.position = Vector2(chat.size.x * 0.90, chat.size.y * 0.048)
	close_button.size = Vector2(chat.size.x * 0.075, chat.size.y * 0.105)
	return response_box

func type_chat_sequence(question_box: Label, question: String, response_box: Label, response: String) -> void:
	await type_chat_text(question_box, question, 0.012, true)
	if not is_instance_valid(response_box):
		return
	response_box.text = "..."
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(response_box):
		return
	response_box.text = ""
	await type_chat_text(response_box, response)

func type_chat_text(text_box: Label, text: String, character_delay := 0.012, is_player_typing := false) -> void:
	if is_player_typing:
		player_typing_sound.play()
	for character_index in text.length():
		if not is_instance_valid(text_box):
			if is_player_typing:
				player_typing_sound.stop()
			return
		text_box.text = text.substr(0, character_index + 1)
		await get_tree().create_timer(character_delay).timeout
	if is_player_typing:
		player_typing_sound.stop()

func _on_monitor_chat_closed(chat: TextureRect) -> void:
	if is_instance_valid(chat):
		chat.queue_free()
	if all_monitor_tools_read:
		show_stage_progress()
		return
	show_monitor_app_from_rect()

func show_stage_progress() -> void:
	GlobalMenu.set_hint_available(false)
	var stage_number := int(level_data.get("stage", 1))
	stage_progress_panel.show_stage(stage_number, ProgressStore.get_completed_missions(stage_number))
	stage_progress_panel.show()

func _on_stage_progress_closed(next_stage: int, next_mission: int) -> void:
	stage_progress_panel.hide()
	GlobalMenu.set_hint_available(true)
	ProgressStore.set_active_mission(next_stage, next_mission)
	mission_advance_requested.emit(next_stage, next_mission)
	if next_stage == int(level_data.get("stage", 0)):
		get_tree().reload_current_scene()

func _on_stage_badges_requested() -> void:
	stage_progress_panel.hide()
	GlobalMenu.open_badges(true)

func show_monitor_app_from_rect() -> void:
	var app := TextureRect.new()
	app.name = "MonitorApp"
	app.layout_direction = Control.LAYOUT_DIRECTION_LTR
	app.texture = load("res://assets/pics/ui/hooshup1.png") as Texture2D
	app.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app.stretch_mode = TextureRect.STRETCH_SCALE
	app.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(app)
	app.position = monitor_app_rect.position
	app.size = monitor_app_rect.size
	add_monitor_card_buttons(app)

func load_level_data() -> void:
	var active_mission := ProgressStore.get_active_mission()
	var mission_path := "res://data/levels/level%d_mission%d.json" % [active_mission.x, active_mission.y]
	if not FileAccess.file_exists(mission_path):
		push_error("Mission data is missing: %s" % mission_path)
		return
	var path := mission_path
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		level_data = parsed
		level_id = "level%d" % int(level_data.get("stage", 1))
	else:
		push_error("Level data is invalid: %s" % path)

func _on_world_tapped(world_position: Vector2) -> void:
	if checkpoint_loaded or dialogue_panel.visible or not is_instance_valid(player_movement):
		return
	var normalized_target := Vector2(
		world_position.x / level_image.size.x,
		world_position.y / level_image.size.y
	)
	await player_movement.move_to_requested_position(normalized_target)

func create_hotspots() -> void:
	if hotspots_started:
		return
	hotspots.layout_direction = Control.LAYOUT_DIRECTION_LTR
	hotspots.size = ResponsiveLayout.DESIGN_SIZE
	hotspots_started = true
	show_next_hotspot()

func create_player() -> void:
	var player_data: Dictionary = level_data.get("player", {})
	var move_area_texture := GameSettings.get_level_texture(str(level_data.get("move_area_asset", "")), level_id)
	player_movement = PLAYER_MOVEMENT_SCRIPT.new() as PlayerMovement
	add_child(player_movement)
	player_movement.configure(player_data, effects, level_image.size, level_image.texture, move_area_texture, Callable(GameSettings, "get_level_asset_path"), Callable(GameSettings, "get_avatar_asset_path"))

func get_enabled_hotspots() -> Array:
	var enabled_hotspots: Array = []
	for hotspot_data in level_data.get("hotspots", []):
		var hotspot: Dictionary = hotspot_data as Dictionary
		var hotspot_id := str(hotspot.get("id", ""))
		if bool(hotspot.get("enabled", true)) or unlocked_hotspot_ids.has(hotspot_id):
			enabled_hotspots.append(hotspot_data)
	return enabled_hotspots

func unlock_hotspots(hotspot_ids: Array) -> void:
	for hotspot_id in hotspot_ids:
		unlocked_hotspot_ids[str(hotspot_id)] = true

func show_next_hotspot() -> void:
	if is_instance_valid(current_hotspot):
		current_hotspot.queue_free()
		current_hotspot = null
	active_hotspot_index += 1
	var hotspot_sequence := get_enabled_hotspots()
	if active_hotspot_index >= hotspot_sequence.size():
		return
	var minimum_dimension: float = minf(ResponsiveLayout.DESIGN_SIZE.x, ResponsiveLayout.DESIGN_SIZE.y)
	var hotspot_data: Dictionary = hotspot_sequence[active_hotspot_index] as Dictionary
	var radius: float = minimum_dimension * float(hotspot_data.get("radius", 0.03))
	var normalized_position: Array = hotspot_data.get("position", [0.5, 0.5])
	current_hotspot = HOTSPOT_SCENE.instantiate()
	current_hotspot.radius = radius
	current_hotspot.set_meta("hotspot_id", str(hotspot_data.get("id", "")))
	current_hotspot.activated.connect(_on_hotspot_activated.bind(hotspot_data))
	hotspots.add_child(current_hotspot)
	# Keep dynamic controls in the LTR design canvas and place them only after
	# parenting, so their coordinates inherit the world's cover transform.
	current_hotspot.layout_direction = Control.LAYOUT_DIRECTION_LTR
	current_hotspot.position = Vector2(
		float(normalized_position[0]) * ResponsiveLayout.DESIGN_SIZE.x - radius,
		float(normalized_position[1]) * ResponsiveLayout.DESIGN_SIZE.y - radius
	)

func _on_hotspot_activated(hotspot_data: Dictionary) -> void:
	if not is_instance_valid(player_movement) or player_movement.is_walking:
		return
	var hotspot_id := str(hotspot_data.get("id", ""))
	if bool(hotspot_data.get("is_clue", false)):
		found_clues[hotspot_id] = true
	if is_instance_valid(current_hotspot):
		current_hotspot.set_alerting(false)
	var player_target: Array = hotspot_data.get("player_target", [])
	if not player_target.is_empty():
		await player_movement.move_to_normalized_position(player_target, str(hotspot_data.get("movement_animation", "")))
	unlock_hotspots(hotspot_data.get("unlocks", []))
	var dialogue_sequence: Array = hotspot_data.get("dialogue_sequence", [])
	if not dialogue_sequence.is_empty():
		show_dialogue_sequence(dialogue_sequence)
		return
	var tool_match_game: Dictionary = hotspot_data.get("tool_match_game", {})
	if not tool_match_game.is_empty():
		await show_hotspot_tool_match_game(tool_match_game)
		return
	var paper_sort_game: Dictionary = hotspot_data.get("paper_sort_game", {})
	if not paper_sort_game.is_empty():
		await show_paper_sort_game(paper_sort_game)
		close_intro_monitor_scene()
		var after_paper_sort_dialogue_sequence: Array = hotspot_data.get("after_paper_sort_dialogue_sequence", [])
		if not after_paper_sort_dialogue_sequence.is_empty():
			show_dialogue_sequence(
				after_paper_sort_dialogue_sequence,
				bool(hotspot_data.get("complete_mission_after_paper_sort_dialogue_sequence", false))
			)
			return
		show_next_hotspot()
		return
	var scripted_monitor_chat: Dictionary = hotspot_data.get("scripted_monitor_chat", {})
	if not scripted_monitor_chat.is_empty():
		await show_hotspot_scripted_monitor_chat(scripted_monitor_chat)
		if bool(hotspot_data.get("complete_mission_after_scripted_monitor_chat", false)):
			close_intro_monitor_scene()
			ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
			show_stage_progress()
			return
		if bool(hotspot_data.get("return_to_room", false)):
			var return_delay := float(hotspot_data.get("return_to_room_delay", 0.0))
			if return_delay > 0.0:
				await get_tree().create_timer(return_delay).timeout
			var return_position: Array = hotspot_data.get("return_player_position", [])
			if str(hotspot_data.get("return_transition", "")) == "fade":
				await fade_to_room(return_position)
			else:
				close_intro_monitor_scene()
				if not return_position.is_empty():
					player_movement.place_at_normalized_position(return_position)
			show_next_hotspot()
			return
		var response_comparison_game: Dictionary = hotspot_data.get("response_comparison_game", {})
		if not response_comparison_game.is_empty():
			await show_response_comparison_game(response_comparison_game)
			return
		var choice_game: Dictionary = hotspot_data.get("choice_game", {})
		if not choice_game.is_empty():
			await show_choice_game(choice_game)
		var presentation_path_game: Dictionary = hotspot_data.get("presentation_path_game", {})
		if not presentation_path_game.is_empty():
			await show_presentation_path_game(presentation_path_game)
		return
	var clue_connection_game: Dictionary = hotspot_data.get("clue_connection_game", {})
	if not clue_connection_game.is_empty():
		if is_instance_valid(current_hotspot):
			current_hotspot.hide()
		await show_clue_connection_game(clue_connection_game)
		if not bool(clue_connection_game.get("complete_mission", false)):
			show_next_hotspot()
		return
	var dialogue: Dictionary = hotspot_data.get("dialogue", {})
	if dialogue.is_empty():
		call_deferred("_on_dialogue_choice_selected", "no_dialogue")
	elif str(dialogue.get("presentation", "")) == "phone_message":
		phone_message_overlay.show_message(
			str(dialogue.get("text", "")),
			str(dialogue.get("close_text", "بستن"))
		)
	else:
		dialogue_panel.show_dialogue(dialogue)
	check_completion()

func show_hotspot_tool_match_game(game_data: Dictionary) -> void:
	pan_zoom_viewport.hide()
	pan_zoom_viewport.set_pan_enabled(false)
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(
		GameSettings.get_level_texture(str(game_data.get("background_asset", "l1-1")), level_id),
		float(game_data.get("zoom", 1.2))
	)
	await get_tree().process_frame
	var monitor_chat: Dictionary = game_data.get("monitor_chat", {})
	if not monitor_chat.is_empty():
		await show_tool_match_intro_chat(monitor_chat)
	show_tool_match_game(game_data)

func show_hotspot_scripted_monitor_chat(chat_data: Dictionary) -> void:
	pan_zoom_viewport.hide()
	pan_zoom_viewport.set_pan_enabled(false)
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(
		GameSettings.get_level_texture(str(chat_data.get("background_asset", "l1-1")), level_id),
		float(chat_data.get("zoom", 1.2))
	)
	await get_tree().process_frame
	await show_scripted_monitor_chat(chat_data)

func fade_to_room(return_position: Array) -> void:
	var fade := ColorRect.new()
	fade.name = "ReturnFromDinnerFade"
	fade.layout_direction = Control.LAYOUT_DIRECTION_LTR
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.01, 0.02, 0.06, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 100
	add_child(fade)
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.9)
	await fade_out.finished
	close_intro_monitor_scene()
	if not return_position.is_empty():
		player_movement.place_at_normalized_position(return_position)
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 1.1)
	await fade_in.finished
	if is_instance_valid(fade):
		fade.queue_free()

func show_choice_game(game_data: Dictionary) -> void:
	var game := Control.new()
	game.name = "ChoiceGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(game)
	await get_tree().process_frame

	var chat := TextureRect.new()
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.size = Vector2(game.size.x * 0.70, game.size.y * 0.63)
	chat.position = Vector2(game.size.x * 0.15, game.size.y * 0.145)
	game.add_child(chat)

	var title := make_game_label(str(game_data.get("title", "")), roundi(chat.size.y * 0.052), HORIZONTAL_ALIGNMENT_RIGHT)
	title.add_theme_color_override("font_color", Color("142d4e"))
	title.position = Vector2(chat.size.x * 0.14, chat.size.y * 0.11)
	title.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.15)
	chat.add_child(title)
	var feedback := make_game_label("", roundi(chat.size.y * 0.034), HORIZONTAL_ALIGNMENT_RIGHT)
	feedback.add_theme_color_override("font_color", Color("a33c32"))
	feedback.position = Vector2(chat.size.x * 0.14, chat.size.y * 0.73)
	feedback.size = Vector2(chat.size.x * 0.72, chat.size.y * 0.07)
	chat.add_child(feedback)

	var answer_buttons: Array[Button] = []
	var choices: Array = game_data.get("choices", [])
	for index in choices.size():
		var choice: Dictionary = choices[index] as Dictionary
		var button := Button.new()
		button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		button.text_direction = Control.TEXT_DIRECTION_RTL
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%d. %s" % [index + 1, str(choice.get("text", ""))]
		button.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.035))
		button.add_theme_color_override("font_color", Color("ecf7ff"))
		button.add_theme_stylebox_override("normal", make_choice_game_style(CHAT_BUTTON_COLOR, CHAT_BUTTON_BORDER_COLOR))
		button.add_theme_stylebox_override("hover", make_choice_game_style(CHAT_BUTTON_HOVER_COLOR, CHAT_BUTTON_BORDER_COLOR))
		button.position = Vector2(chat.size.x * 0.16, chat.size.y * (0.29 + 0.11 * index))
		button.size = Vector2(chat.size.x * 0.72, chat.size.y * 0.09)
		button.set_meta("choice_data", choice)
		chat.add_child(button)
		answer_buttons.append(button)
		button.pressed.connect(_on_choice_game_answer_pressed.bind(game, game_data, button, title, feedback, answer_buttons))
	await game.tree_exited

func show_presentation_path_game(game_data: Dictionary) -> void:
	var game := PRESENTATION_PATH_GAME_SCRIPT.new() as PresentationPathGame
	game.name = "PresentationPathGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	effects.add_child(game)
	game.incorrect_route_attempted.connect(_on_presentation_path_incorrect_route)
	await game.completed
	if is_instance_valid(game):
		game.queue_free()
	await show_presentation_success(game_data)
	ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
	await get_tree().create_timer(1.5).timeout
	close_intro_monitor_scene()
	show_stage_progress()

func _on_presentation_path_incorrect_route() -> void:
	ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))

func show_presentation_success(game_data: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "PresentationSuccess"
	overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(overlay)
	var shade := ColorRect.new()
	shade.layout_direction = Control.LAYOUT_DIRECTION_LTR
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("061326dc")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.position = Vector2(overlay.size.x * 0.15, overlay.size.y * 0.10)
	panel.size = Vector2(overlay.size.x * 0.70, overlay.size.y * 0.80)
	panel.add_theme_stylebox_override("panel", make_game_style(Color("102741"), Color("73d8d0")))
	overlay.add_child(panel)
	var art := TextureRect.new()
	art.layout_direction = Control.LAYOUT_DIRECTION_LTR
	art.texture = MARS_PRESENTATION_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(panel.size.x * 0.08, panel.size.y * 0.18)
	art.size = Vector2(panel.size.x * 0.84, panel.size.y * 0.45)
	panel.add_child(art)
	var title := make_game_label("ارائهٔ من: زندگی در مریخ", roundi(panel.size.y * 0.064), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(panel.size.x * 0.08, panel.size.y * 0.05)
	title.size = Vector2(panel.size.x * 0.84, panel.size.y * 0.10)
	panel.add_child(title)
	var message := make_game_label(str(game_data.get("success_message", "")), roundi(panel.size.y * 0.038), HORIZONTAL_ALIGNMENT_CENTER)
	message.add_theme_color_override("font_color", Color("b9dbe6"))
	message.position = Vector2(panel.size.x * 0.10, panel.size.y * 0.67)
	message.size = Vector2(panel.size.x * 0.80, panel.size.y * 0.11)
	panel.add_child(message)
	var p28 := make_game_label(str(game_data.get("project28_message", "")), roundi(panel.size.y * 0.030), HORIZONTAL_ALIGNMENT_CENTER)
	p28.add_theme_color_override("font_color", Color("f4c875"))
	p28.position = Vector2(panel.size.x * 0.10, panel.size.y * 0.79)
	p28.size = Vector2(panel.size.x * 0.80, panel.size.y * 0.08)
	panel.add_child(p28)
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()

func show_response_comparison_game(game_data: Dictionary) -> void:
	var game := Control.new()
	game.name = "ResponseComparisonGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(game)
	await get_tree().process_frame

	var dim := ColorRect.new()
	dim.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.025, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(dim)
	var board := Panel.new()
	board.name = "ResponseComparisonBoard"
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.add_theme_stylebox_override("panel", make_choice_game_style(Color("f2faf9"), CHAT_BUTTON_BORDER_COLOR))
	board.size = Vector2(game.size.x * 0.72, game.size.y * 0.72)
	board.position = (game.size - board.size) * 0.5
	game.add_child(board)
	var title := make_game_label(str(game_data.get("title", "")), roundi(board.size.y * 0.055) + 3, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.add_theme_color_override("font_color", Color("294368"))
	title.position = Vector2(board.size.x * 0.10, board.size.y * 0.07)
	title.size = Vector2(board.size.x * 0.80, board.size.y * 0.12)
	board.add_child(title)

	var response_buttons: Array[Button] = []
	for index in (game_data.get("responses", []) as Array).size():
		var response: Dictionary = (game_data.get("responses", []) as Array)[index] as Dictionary
		var button := Button.new()
		button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		button.text_direction = Control.TEXT_DIRECTION_RTL
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(response.get("prompt", ""))
		button.add_theme_font_size_override("font_size", roundi(board.size.y * 0.046))
		button.add_theme_color_override("font_color", Color("ecf7ff"))
		button.add_theme_stylebox_override("normal", make_choice_game_style(CHAT_BUTTON_COLOR, CHAT_BUTTON_BORDER_COLOR))
		button.add_theme_stylebox_override("hover", make_choice_game_style(CHAT_BUTTON_HOVER_COLOR, CHAT_BUTTON_BORDER_COLOR))
		button.position = Vector2(board.size.x * 0.12, board.size.y * (0.23 + 0.22 * index))
		button.size = Vector2(board.size.x * 0.76, board.size.y * 0.17)
		button.set_meta("response_id", str(response.get("id", "")))
		board.add_child(button)
		response_buttons.append(button)
		button.pressed.connect(_on_response_card_pressed.bind(game, button, response_buttons, title, game_data))
	await game.tree_exited

func _on_response_card_pressed(game: Control, button: Button, response_buttons: Array[Button], title: Label, game_data: Dictionary) -> void:
	if bool(game.get_meta("comparison_transitioning", false)):
		return
	game.set_meta("comparison_transitioning", true)
	var response_id := str(button.get_meta("response_id", ""))
	var selected_response: Dictionary = {}
	for response_value in game_data.get("responses", []) as Array:
		var candidate: Dictionary = response_value as Dictionary
		if str(candidate.get("id", "")) == response_id:
			selected_response = candidate
			break
	if selected_response.is_empty():
		game.set_meta("comparison_transitioning", false)
		return
	game.hide()
	await show_scripted_monitor_chat({
		"background_asset": str(game_data.get("background_asset", "l1-1")),
		"zoom": float(game_data.get("zoom", 1.2)),
		"position": [0.50, 0.46],
		"size": [0.70, 0.63],
		"character_delay": float(game_data.get("character_delay", 0.025)),
		"steps": [
			{ "role": "player", "text": str(selected_response.get("prompt", "")) },
			{ "role": "assistant", "thinking_delay": 1.5, "text": str(selected_response.get("answer", "")), "after_delay": 1.0 }
		]
	})
	if not is_instance_valid(game):
		return
	game.show()
	button.disabled = true
	button.add_theme_stylebox_override("disabled", make_choice_game_style(CHAT_BUTTON_DONE_COLOR, CHAT_BUTTON_BORDER_COLOR))
	var inspected: Dictionary = game.get_meta("inspected_responses", {}) as Dictionary
	inspected[response_id] = true
	game.set_meta("inspected_responses", inspected)
	if inspected.size() < response_buttons.size():
		game.set_meta("comparison_transitioning", false)
		return
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame
	await show_response_comparison_final_chat(game_data)

func show_response_comparison_chat_message(message: String, game_data: Dictionary) -> void:
	await show_scripted_monitor_chat({
		"background_asset": str(game_data.get("background_asset", "l1-1")),
		"zoom": float(game_data.get("zoom", 1.2)),
		"position": [0.50, 0.46],
		"size": [0.70, 0.63],
		"character_delay": float(game_data.get("character_delay", 0.025)),
		"steps": [
			{ "role": "assistant", "thinking_delay": 1.5, "text": message, "after_delay": 0.45 }
		]
	})

func show_response_comparison_final_chat(game_data: Dictionary) -> void:
	var chat := TextureRect.new()
	chat.name = "ResponseComparisonFinalChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(chat)
	chat.size = Vector2(level_image.size.x * 0.70, level_image.size.y * 0.63)
	chat.position = Vector2(level_image.size.x * 0.15, level_image.size.y * 0.145)
	var response_box := add_monitor_chat_boxes(chat, {}, Callable(), false)
	var question_box := chat.get_node("Question") as Label
	question_box.hide()
	response_box.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.15)
	response_box.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.22)
	response_box.text = "..."
	await get_tree().create_timer(1.5).timeout
	response_box.text = ""
	await type_chat_text(response_box, str(game_data.get("final_question", "")), float(game_data.get("character_delay", 0.025)))
	var feedback := make_game_label("", roundi(chat.size.y * 0.032), HORIZONTAL_ALIGNMENT_RIGHT)
	feedback.name = "Feedback"
	feedback.add_theme_color_override("font_color", Color("a33c32"))
	feedback.position = Vector2(chat.size.x * 0.16, chat.size.y * 0.39)
	feedback.size = Vector2(chat.size.x * 0.74, chat.size.y * 0.09)
	chat.add_child(feedback)
	var choices: Array[Button] = []
	for index in (game_data.get("responses", []) as Array).size():
		var response: Dictionary = (game_data.get("responses", []) as Array)[index] as Dictionary
		var choice := Button.new()
		choice.layout_direction = Control.LAYOUT_DIRECTION_LTR
		choice.text_direction = Control.TEXT_DIRECTION_RTL
		choice.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		choice.text = str(response.get("prompt", ""))
		choice.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.035))
		choice.add_theme_color_override("font_color", Color("f4f8ff"))
		choice.add_theme_stylebox_override("normal", make_choice_game_style(CHAT_BUTTON_COLOR, CHAT_BUTTON_BORDER_COLOR))
		choice.add_theme_stylebox_override("hover", make_choice_game_style(CHAT_BUTTON_HOVER_COLOR, CHAT_BUTTON_BORDER_COLOR))
		choice.position = Vector2(chat.size.x * 0.16, chat.size.y * (0.50 + 0.10 * index))
		choice.size = Vector2(chat.size.x * 0.72, chat.size.y * 0.08)
		choice.set_meta("correct", bool(response.get("correct", false)))
		chat.add_child(choice)
		choices.append(choice)
		choice.pressed.connect(_on_response_comparison_final_choice_pressed.bind(chat, choice, feedback, choices, game_data))
	await chat.tree_exited

func _on_response_comparison_final_choice_pressed(chat: TextureRect, choice: Button, feedback: Label, choices: Array[Button], game_data: Dictionary) -> void:
	if bool(chat.get_meta("transitioning", false)):
		return
	if not bool(choice.get_meta("correct", false)):
		chat.set_meta("transitioning", true)
		ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		feedback.text = "..."
		await get_tree().create_timer(1.5).timeout
		feedback.text = ""
		await type_chat_text(feedback, str(game_data.get("wrong_feedback", "")), float(game_data.get("character_delay", 0.025)))
		chat.set_meta("transitioning", false)
		return
	chat.set_meta("transitioning", true)
	for answer_button in choices:
		answer_button.hide()
	feedback.add_theme_color_override("font_color", Color("1b5d45"))
	feedback.text = "..."
	await get_tree().create_timer(1.5).timeout
	feedback.text = ""
	await type_chat_text(feedback, "%s\n%s" % [str(game_data.get("correct_feedback", "")), str(game_data.get("completion_response", ""))], float(game_data.get("character_delay", 0.025)))
	ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
	await get_tree().create_timer(float(game_data.get("completion_delay", 2.0))).timeout
	if is_instance_valid(chat):
		chat.queue_free()
	close_intro_monitor_scene()
	show_stage_progress()

func _on_choice_game_answer_pressed(game: Control, game_data: Dictionary, button: Button, title: Label, feedback: Label, answer_buttons: Array[Button]) -> void:
	if bool(game.get_meta("transitioning", false)):
		return
	var choice: Dictionary = button.get_meta("choice_data", {}) as Dictionary
	if not bool(choice.get("correct", false)):
		ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		feedback.text = str(game_data.get("wrong_feedback", ""))
		return
	game.set_meta("transitioning", true)
	for answer_button in answer_buttons:
		answer_button.hide()
	feedback.add_theme_color_override("font_color", Color("1b5d45"))
	feedback.text = str(game_data.get("correct_feedback", ""))
	await get_tree().create_timer(0.8).timeout
	feedback.text = ""
	title.text = ""
	title.position = Vector2(title.get_parent().size.x * 0.14, title.get_parent().size.y * 0.20)
	title.size = Vector2(title.get_parent().size.x * 0.72, title.get_parent().size.y * 0.48)
	title.text = "..."
	await get_tree().create_timer(1.5).timeout
	title.text = ""
	await type_chat_text(title, str(game_data.get("completion_response", "")), 0.025)
	await get_tree().create_timer(float(game_data.get("completion_response_delay", 2.0))).timeout
	var completion_side_story: Dictionary = game_data.get("completion_side_story", {})
	if not completion_side_story.is_empty():
		if is_instance_valid(game):
			game.queue_free()
		await get_tree().process_frame
		await show_completion_side_story(completion_side_story)
	ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
	await get_tree().create_timer(float(game_data.get("completion_delay", 2.0))).timeout
	if is_instance_valid(game):
		game.queue_free()
	close_intro_monitor_scene()
	show_stage_progress()

func show_completion_side_story(story_data: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "CompletionSideStory"
	overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(overlay)
	await get_tree().process_frame

	var file_button := Button.new()
	file_button.name = "Project28File"
	file_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	file_button.flat = true
	file_button.tooltip_text = str(story_data.get("file_tooltip", ""))
	for state in ["normal", "hover", "pressed"]:
		file_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	overlay.add_child(file_button)
	file_button.position = Vector2(overlay.size.x * 0.43, overlay.size.y * 0.30)
	file_button.size = Vector2(overlay.size.x * 0.14, overlay.size.y * 0.27)
	var reveal_sound_path := str(story_data.get("reveal_sound", ""))
	if not reveal_sound_path.is_empty() and GameSettings.background_music_enabled:
		notification_sound.stop()
		notification_sound.stream = load(reveal_sound_path) as AudioStream
		if notification_sound.stream != null:
			notification_sound.play()

	var file_icon := TextureRect.new()
	file_icon.texture = DOCUMENT_ICON
	file_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	file_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	file_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	file_button.add_child(file_icon)
	file_icon.position = Vector2(file_button.size.x * 0.20, 0)
	file_icon.size = Vector2(file_button.size.x * 0.60, file_button.size.y * 0.68)
	var file_name := Label.new()
	file_name.layout_direction = Control.LAYOUT_DIRECTION_LTR
	file_name.text_direction = Control.TEXT_DIRECTION_RTL
	file_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	file_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	file_name.add_theme_color_override("font_color", Color.WHITE)
	file_name.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.12, 0.9))
	file_name.add_theme_constant_override("shadow_offset_x", 2)
	file_name.add_theme_constant_override("shadow_offset_y", 2)
	file_name.add_theme_font_size_override("font_size", roundi(overlay.size.y * 0.035))
	file_name.text = str(story_data.get("file_name", "پروژه28.dat"))
	file_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	file_button.add_child(file_name)
	file_name.position = Vector2(0, file_button.size.y * 0.69)
	file_name.size = Vector2(file_button.size.x, file_button.size.y * 0.25)

	await file_button.pressed
	file_button.hide()
	var notepad := TextureRect.new()
	notepad.name = "Project28Notepad"
	notepad.layout_direction = Control.LAYOUT_DIRECTION_LTR
	notepad.texture = NOTEPAD_TEXTURE
	notepad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	notepad.stretch_mode = TextureRect.STRETCH_SCALE
	notepad.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(notepad)
	notepad.size = Vector2(overlay.size.x * 0.511, overlay.size.y * 0.476)
	notepad.position = (overlay.size - notepad.size) * 0.5
	var document_text := Label.new()
	document_text.layout_direction = Control.LAYOUT_DIRECTION_LTR
	document_text.text_direction = Control.TEXT_DIRECTION_AUTO
	document_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	document_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	document_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	document_text.add_theme_color_override("font_color", Color("1d2633"))
	document_text.add_theme_font_size_override("font_size", roundi(notepad.size.y * 0.040))
	document_text.text = str(story_data.get("document_text", ""))
	document_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notepad.add_child(document_text)
	document_text.position = Vector2(notepad.size.x * 0.05, notepad.size.y * 0.24)
	document_text.size = Vector2(notepad.size.x * 0.87, notepad.size.y * 0.66)
	var countdown := COUNTDOWN_SCENE.instantiate() as Countdown
	overlay.add_child(countdown)
	countdown.place_bottom_right(overlay.size, Vector2(overlay.size.x * 0.17, overlay.size.y * 0.19))
	countdown.start(int(story_data.get("notepad_timeout_seconds", 10)))
	await countdown.finished
	countdown.stop()
	countdown.queue_free()
	overlay.queue_free()

func make_choice_game_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := make_game_style(background, border)
	style.set_content_margin(SIDE_RIGHT, 5.0)
	return style

func make_sticky_note_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.14, 0.08, 0.04, 0.38)
	style.shadow_size = 5
	style.shadow_offset = Vector2(3, 4)
	style.set_content_margin_all(12.0)
	return style

func show_tool_match_intro_chat(chat_data: Dictionary) -> void:
	var chat := TextureRect.new()
	chat.name = "ToolMatchIntroChat"
	chat.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chat.texture = load("res://assets/pics/ui/hooshup-back.png") as Texture2D
	chat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat.stretch_mode = TextureRect.STRETCH_SCALE
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	effects.add_child(chat)
	chat.size = Vector2(level_image.size.x * 0.70, level_image.size.y * 0.63)
	chat.position = Vector2(level_image.size.x * 0.15, level_image.size.y * 0.145)
	var response_box := add_monitor_chat_boxes(chat, chat_data, Callable(), false)
	var question_box := chat.get_node("Question") as Label
	var send_button := Button.new()
	send_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	send_button.flat = true
	send_button.disabled = true
	send_button.tooltip_text = str(chat_data.get("send_tooltip", ""))
	chat.add_child(send_button)
	send_button.position = Vector2(chat.size.x * 0.89, chat.size.y * 0.82)
	send_button.size = Vector2(chat.size.x * 0.08, chat.size.y * 0.12)
	var send_hint := Label.new()
	send_hint.layout_direction = Control.LAYOUT_DIRECTION_LTR
	send_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_hint.text = str(chat_data.get("send_indicator", ""))
	send_hint.add_theme_color_override("font_color", Color("fda22c"))
	send_hint.add_theme_font_size_override("font_size", roundi(chat.size.y * 0.05))
	send_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_child(send_hint)
	send_hint.position = Vector2(chat.size.x * 0.90, chat.size.y * 0.8)
	send_hint.size = Vector2(chat.size.x * 0.06, chat.size.y * 0.06)
	var hint_tween := send_hint.create_tween().set_loops()
	hint_tween.tween_property(send_hint, "modulate:a", 0.2, 0.55)
	hint_tween.tween_property(send_hint, "modulate:a", 1.0, 0.55)
	await type_chat_text(question_box, str(chat_data.get("title", "")), float(chat_data.get("question_character_delay", 0.04)), true)
	send_button.disabled = false
	await send_button.pressed
	send_hint.hide()
	send_button.hide()
	response_box.text = "..."
	await get_tree().create_timer(float(chat_data.get("response_wait", 1.5))).timeout
	response_box.text = ""
	await type_chat_text(response_box, str(chat_data.get("response", "")), float(chat_data.get("response_character_delay", 0.02)))
	await get_tree().create_timer(float(chat_data.get("after_delay", 0.8))).timeout
	if is_instance_valid(chat):
		chat.queue_free()

func _on_phone_message_closed() -> void:
	_on_dialogue_choice_selected("phone_message_closed")

func _on_phone_sending_finished() -> void:
	notification_sound.stream = load("res://assets/sounds/message.mp3") as AudioStream
	notification_sound.play()
	_on_dialogue_choice_selected("phone_sending_finished")

func _on_dialogue_dismiss_requested() -> void:
	_on_dialogue_choice_selected("dismiss")

func _on_dialogue_choice_selected(_choice_id: String) -> void:
	dialogue_panel.hide_dialogue()
	if show_next_dialogue_sequence_entry():
		return
	if dialogue_sequence_completion_ready:
		dialogue_sequence_completion_ready = false
		ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		show_stage_progress()
		return
	if intro_is_open:
		intro_is_open = false
		return
	if checkpoint_loaded:
		return
	if not hotspots_started:
		create_hotspots()
	elif is_instance_valid(current_hotspot):
		var hotspot_sequence := get_enabled_hotspots()
		if active_hotspot_index >= hotspot_sequence.size() - 1:
			var checkpoint_id := int(level_data.get("checkpoint_after_hotspots", 0))
			var scene_checkpoint_id := int(level_data.get("scene_checkpoint_after_hotspots", checkpoint_id))
			if scene_checkpoint_id > 0:
				if checkpoint_id > 0:
					ProgressStore.set_checkpoint(
						int(level_data.get("stage", 0)),
						int(level_data.get("mission", 0)),
						checkpoint_id
					)
				await load_checkpoint(scene_checkpoint_id)
			else:
				show_next_hotspot()
		else:
			show_next_hotspot()

func show_dialogue_sequence(sequence: Array, completes_mission := false) -> void:
	pending_dialogue_sequence = sequence
	pending_dialogue_sequence_index = -1
	pending_dialogue_sequence_completes_mission = completes_mission
	dialogue_sequence_completion_ready = false
	show_next_dialogue_sequence_entry()

func show_next_dialogue_sequence_entry() -> bool:
	if pending_dialogue_sequence.is_empty():
		return false
	pending_dialogue_sequence_index += 1
	if pending_dialogue_sequence_index >= pending_dialogue_sequence.size():
		dialogue_sequence_completion_ready = pending_dialogue_sequence_completes_mission
		pending_dialogue_sequence_completes_mission = false
		pending_dialogue_sequence.clear()
		pending_dialogue_sequence_index = -1
		return false
	var dialogue: Dictionary = pending_dialogue_sequence[pending_dialogue_sequence_index] as Dictionary
	if str(dialogue.get("presentation", "")) == "phone_message":
		phone_message_overlay.show_message(
			str(dialogue.get("text", "")),
			str(dialogue.get("close_text", "بستن"))
		)
	elif str(dialogue.get("presentation", "")) == "phone_send_message":
		phone_message_overlay.show_sending_message(
			str(dialogue.get("text", "")),
			float(dialogue.get("message_visible_seconds", 1.0)),
			float(dialogue.get("receive_delay_seconds", 3.0))
		)
	else:
		dialogue_panel.show_dialogue(dialogue)
	return true

func check_completion() -> void:
	if not level_data.has("completion_dialogue"):
		return
	var total_clues := 0
	for hotspot_data in level_data.get("hotspots", []):
		if bool(hotspot_data.get("is_clue", false)):
			total_clues += 1
	if total_clues > 0 and found_clues.size() >= total_clues:
		dialogue_panel.show_dialogue(level_data.get("completion_dialogue", {}))

func show_paper_sort_game(game_data: Dictionary) -> void:
	pan_zoom_viewport.hide()
	pan_zoom_viewport.set_pan_enabled(false)
	level_image = stretch_to_fit_viewport.scene_image
	effects = $StretchToFitViewport/SceneImage/Effects
	stretch_to_fit_viewport.show_scene(GameSettings.get_level_texture(str(game_data.get("background_asset", "l2-computer")), level_id), float(game_data.get("zoom", 1.0)))
	await get_tree().process_frame
	var game := Control.new()
	game.name = "PaperSortGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter = Control.MOUSE_FILTER_STOP
	game.set_meta("dragging_piece", null)
	game.set_meta("completed", false)
	effects.add_child(game)
	await get_tree().process_frame
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.12, 0.50)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.add_child(shade)
	var title := make_game_label(str(game_data.get("title", "")), roundi(game.size.y * 0.052), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.08, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(game.size.x * 0.26, game.size.y * 0.035)
	title.size = Vector2(game.size.x * 0.48, game.size.y * 0.07)
	game.add_child(title)
	var feedback := make_game_label(str(game_data.get("instruction", "")), roundi(game.size.y * 0.038), HORIZONTAL_ALIGNMENT_CENTER)
	feedback.name = "Feedback"
	feedback.position = Vector2(game.size.x * 0.28, game.size.y * 0.105)
	feedback.size = Vector2(game.size.x * 0.44, game.size.y * 0.055)
	game.add_child(feedback)
	var target_positions := [Vector2(0.30, 0.24), Vector2(0.52, 0.24), Vector2(0.30, 0.54), Vector2(0.52, 0.54)]
	var correct_ids: Array = game_data.get("correct_pieces", ["p1", "p2", "p3", "p4"])
	for index in correct_ids.size():
		var slot := Panel.new()
		slot.name = "PaperSlot%d" % index
		slot.set_meta("expected_piece", str(correct_ids[index]))
		slot.set_meta("filled", false)
		slot.position = Vector2(game.size.x * target_positions[index].x, game.size.y * target_positions[index].y)
		slot.size = Vector2(game.size.x * 0.21, game.size.y * 0.25)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel", make_game_style(Color("edf5ffb8"), Color("75d7e1")))
		game.add_child(slot)
	var piece_ids: Array = game_data.get("pieces", ["p1", "p2", "p3", "p4", "p5", "p6"])
	piece_ids.shuffle()
	game.gui_input.connect(_on_paper_game_input.bind(game, feedback, correct_ids.size(), game_data))
	var piece_positions := [Vector2(0.02, 0.17), Vector2(0.12, 0.66), Vector2(0.79, 0.17), Vector2(0.79, 0.66), Vector2(0.02, 0.43), Vector2(0.79, 0.43)]
	for index in piece_ids.size():
		var piece := TextureRect.new()
		piece.name = "PaperPiece%s" % str(piece_ids[index])
		piece.texture = load("res://assets/pics/levels/2/%s.png" % str(piece_ids[index])) as Texture2D
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		piece.mouse_filter = Control.MOUSE_FILTER_STOP
		piece.set_meta("piece_id", str(piece_ids[index]))
		piece.set_meta("home_position", Vector2(game.size.x * piece_positions[index].x, game.size.y * piece_positions[index].y))
		piece.position = piece.get_meta("home_position") as Vector2
		piece.size = Vector2(game.size.x * 0.20, game.size.y * 0.24)
		game.add_child(piece)
		piece.gui_input.connect(_on_paper_piece_input.bind(game, piece, feedback, correct_ids.size(), game_data))
	await game.tree_exited

func _on_paper_piece_input(event: InputEvent, game: Control, piece: TextureRect, feedback: Label, required_count: int, game_data: Dictionary) -> void:
	if bool(game.get_meta("completed", false)) or bool(piece.get_meta("placed", false)):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			game.set_meta("dragging_piece", piece)
			piece.z_index = 5
		else:
			finish_paper_piece_drop(game, piece, feedback, required_count, game_data)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			game.set_meta("dragging_piece", piece)
			piece.z_index = 5
		else:
			finish_paper_piece_drop(game, piece, feedback, required_count, game_data)
		accept_event()
	elif event is InputEventMouseMotion and game.get_meta("dragging_piece", null) == piece:
		piece.position += event.relative
		accept_event()
	elif event is InputEventScreenDrag and game.get_meta("dragging_piece", null) == piece:
		piece.position += event.relative
		accept_event()

func _on_paper_game_input(event: InputEvent, game: Control, feedback: Label, required_count: int, game_data: Dictionary) -> void:
	var piece := game.get_meta("dragging_piece", null) as TextureRect
	if piece == null or bool(game.get_meta("completed", false)):
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		piece.position += event.relative
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_paper_piece_drop(game, piece, feedback, required_count, game_data)
		accept_event()
	elif event is InputEventScreenTouch and not event.pressed:
		finish_paper_piece_drop(game, piece, feedback, required_count, game_data)
		accept_event()

func finish_paper_piece_drop(game: Control, piece: TextureRect, feedback: Label, required_count: int, game_data: Dictionary) -> void:
	game.set_meta("dragging_piece", null)
	var piece_center := piece.position + piece.size * 0.5
	for child in game.get_children():
		if not child is Panel or not str(child.name).begins_with("PaperSlot"):
			continue
		var slot := child as Panel
		if not slot.get_rect().has_point(piece_center):
			continue
		if bool(slot.get_meta("filled", false)) or str(slot.get_meta("expected_piece", "")) != str(piece.get_meta("piece_id", "")):
			ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
			feedback.add_theme_color_override("font_color", Color("f2a09a"))
			feedback.text = str(game_data.get("wrong_feedback", ""))
			reset_paper_piece(piece)
			return
		slot.set_meta("filled", true)
		piece.set_meta("placed", true)
		piece.position = slot.position
		piece.size = slot.size
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 1
		feedback.add_theme_color_override("font_color", Color("c9f0d8"))
		feedback.text = str(game_data.get("correct_feedback", ""))
		if get_paper_piece_count(game) >= required_count:
			game.set_meta("completed", true)
			feedback.text = str(game_data.get("completion_feedback", ""))
			await get_tree().create_timer(float(game_data.get("completion_delay", 1.2))).timeout
			if is_instance_valid(game):
				game.queue_free()
		return
	reset_paper_piece(piece)

func reset_paper_piece(piece: TextureRect) -> void:
	piece.z_index = 0
	piece.create_tween().tween_property(piece, "position", piece.get_meta("home_position") as Vector2, 0.18)

func get_paper_piece_count(game: Control) -> int:
	var count := 0
	for child in game.get_children():
		if child is TextureRect and bool(child.get_meta("placed", false)):
			count += 1
	return count

func show_clue_connection_game(game_data: Dictionary) -> void:
	var game := Control.new()
	game.name = "ClueConnectionGame"
	game.layout_direction = Control.LAYOUT_DIRECTION_LTR
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.mouse_filter = Control.MOUSE_FILTER_STOP
	game.z_index = 10
	game.set_meta("selected_clue", null)
	game.set_meta("completed", false)
	# This is a screen minigame, not part of the zoomable room.  Adding it to
	# the room effects would scale and crop the board with the camera zoom.
	add_child(game)
	await get_tree().process_frame

	var dim := ColorRect.new()
	dim.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.035, 0.06, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(dim)
	var board := Panel.new()
	board.name = "ClueBoard"
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	# Keep the whole board inside the visible play area, including on shorter screens.
	board.size = Vector2(game.size.x * 0.90, game.size.y * 0.88)
	board.position = (game.size - board.size) * 0.5
	board.add_theme_stylebox_override("panel", make_game_style(Color("6e4932cc"), Color("e8c77d")))
	game.add_child(board)
	var title := make_game_label(str(game_data.get("title", "")), roundi(board.size.y * 0.055) + 3, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", Color("fff3cf"))
	title.position = Vector2(board.size.x * 0.05, board.size.y * 0.04)
	title.size = Vector2(board.size.x * 0.90, board.size.y * 0.09)
	board.add_child(title)
	var instruction := make_game_label(str(game_data.get("instruction", "")), roundi(board.size.y * 0.032) + 3, HORIZONTAL_ALIGNMENT_CENTER)
	instruction.add_theme_color_override("font_color", Color("f9e6bd"))
	instruction.position = Vector2(board.size.x * 0.08, board.size.y * 0.13)
	instruction.size = Vector2(board.size.x * 0.84, board.size.y * 0.07)
	board.add_child(instruction)
	var feedback := make_game_label("", roundi(board.size.y * 0.030) + 3, HORIZONTAL_ALIGNMENT_CENTER)
	feedback.name = "Feedback"
	feedback.position = Vector2(board.size.x * 0.08, board.size.y * 0.89)
	feedback.size = Vector2(board.size.x * 0.84, board.size.y * 0.06)
	board.add_child(feedback)

	var clues: Array = game_data.get("clues", [])
	var shuffled_clues := clues.duplicate()
	shuffled_clues.shuffle()
	var note_colors: Array[Color] = [Color("f7df72"), Color("cce6a4"), Color("aadceb"), Color("f4bd9c")]
	var note_rotations := [-2.0, 1.5, -1.0, 2.0, 1.0, -1.5, 2.0, -2.0]
	for index in shuffled_clues.size():
		var clue: Dictionary = shuffled_clues[index] as Dictionary
		var clue_button := Button.new()
		clue_button.name = "Clue%d" % index
		clue_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		clue_button.text_direction = Control.TEXT_DIRECTION_RTL
		clue_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		clue_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clue_button.text = str(clue.get("text", ""))
		clue_button.add_theme_font_size_override("font_size", roundi(board.size.y * 0.030) + 3)
		clue_button.add_theme_color_override("font_color", Color("33251e"))
		clue_button.add_theme_color_override("font_hover_color", Color("33251e"))
		clue_button.add_theme_color_override("font_disabled_color", Color("42604a"))
		var note_color: Color = note_colors[index % note_colors.size()]
		clue_button.add_theme_stylebox_override("normal", make_sticky_note_style(note_color, Color("bc9053")))
		clue_button.add_theme_stylebox_override("hover", make_sticky_note_style(note_color.lightened(0.10), Color("8c6135")))
		clue_button.position = Vector2(board.size.x * (0.05 + 0.20 * (index % 2)), board.size.y * (0.24 + 0.155 * (index / 2)))
		clue_button.size = Vector2(board.size.x * 0.18, board.size.y * 0.125)
		clue_button.pivot_offset = clue_button.size * 0.5
		clue_button.rotation = deg_to_rad(float(note_rotations[index % note_rotations.size()]))
		clue_button.set_meta("clue_data", clue)
		board.add_child(clue_button)
		clue_button.pressed.connect(_on_clue_connection_clue_pressed.bind(game, board, clue_button, instruction))

	var invitation := Panel.new()
	invitation.layout_direction = Control.LAYOUT_DIRECTION_LTR
	invitation.position = Vector2(board.size.x * 0.49, board.size.y * 0.23)
	invitation.size = Vector2(board.size.x * 0.46, board.size.y * 0.61)
	invitation.add_theme_stylebox_override("panel", make_game_style(Color("fffaf0"), Color("d7b56b")))
	board.add_child(invitation)
	var invitation_title := make_game_label("دعوت‌نامهٔ شب ایده‌ها", roundi(invitation.size.y * 0.065) + 3, HORIZONTAL_ALIGNMENT_CENTER)
	invitation_title.add_theme_color_override("font_color", Color("5b3a28"))
	invitation_title.position = Vector2(invitation.size.x * 0.08, invitation.size.y * 0.05)
	invitation_title.size = Vector2(invitation.size.x * 0.84, invitation.size.y * 0.10)
	invitation.add_child(invitation_title)
	var slots: Array = game_data.get("slots", [])
	for index in slots.size():
		var slot_data: Dictionary = slots[index] as Dictionary
		var slot_button := Button.new()
		slot_button.name = "InvitationSlot%d" % index
		slot_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		slot_button.text_direction = Control.TEXT_DIRECTION_RTL
		slot_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_button.text = "%s: ؟" % str(slot_data.get("label", ""))
		slot_button.add_theme_font_size_override("font_size", roundi(invitation.size.y * 0.050) + 3)
		slot_button.add_theme_color_override("font_color", Color("674535"))
		slot_button.add_theme_color_override("font_hover_color", Color("674535"))
		slot_button.add_theme_color_override("font_disabled_color", Color("42604a"))
		slot_button.add_theme_stylebox_override("normal", make_sticky_note_style(Color("fff0a8"), Color("cda96a")))
		slot_button.add_theme_stylebox_override("hover", make_sticky_note_style(Color("fff6c6"), Color("a87b3c")))
		slot_button.position = Vector2(invitation.size.x * 0.08, invitation.size.y * (0.19 + 0.145 * index))
		slot_button.size = Vector2(invitation.size.x * 0.84, invitation.size.y * 0.115)
		slot_button.set_meta("slot_data", slot_data)
		invitation.add_child(slot_button)
		slot_button.pressed.connect(_on_clue_connection_slot_pressed.bind(game, board, slot_button, feedback, instruction, game_data))
	await game.tree_exited

func _on_clue_connection_clue_pressed(game: Control, board: Panel, clue_button: Button, instruction: Label) -> void:
	if bool(game.get_meta("completed", false)) or clue_button.disabled:
		return
	var previous := game.get_meta("selected_clue", null) as Button
	if is_instance_valid(previous):
		previous.modulate = Color.WHITE
	game.set_meta("selected_clue", clue_button)
	clue_button.modulate = Color("ffd66f")
	instruction.text = "حالا بخش درستِ دعوت‌نامه رو انتخاب کن."

func _on_clue_connection_slot_pressed(game: Control, board: Panel, slot_button: Button, feedback: Label, instruction: Label, game_data: Dictionary) -> void:
	if bool(game.get_meta("completed", false)) or slot_button.disabled:
		return
	var clue_button := game.get_meta("selected_clue", null) as Button
	if not is_instance_valid(clue_button):
		feedback.add_theme_color_override("font_color", Color("ffd1c4"))
		feedback.text = "اول یه یادداشت رو انتخاب کن."
		return
	var clue_data: Dictionary = clue_button.get_meta("clue_data", {}) as Dictionary
	var slot_data: Dictionary = slot_button.get_meta("slot_data", {}) as Dictionary
	if str(clue_data.get("target_id", "")) != str(slot_data.get("id", "")):
		ScoreStore.record_wrong_answer(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		feedback.add_theme_color_override("font_color", Color("ffd1c4"))
		feedback.text = str(game_data.get("wrong_feedback", ""))
		clue_button.modulate = Color.WHITE
		game.set_meta("selected_clue", null)
		instruction.text = str(game_data.get("instruction", ""))
		return
	clue_button.disabled = true
	clue_button.modulate = Color("9fd8b0")
	slot_button.disabled = true
	slot_button.text = "%s: %s" % [str(slot_data.get("label", "")), str(clue_data.get("value", ""))]
	slot_button.add_theme_stylebox_override("disabled", make_sticky_note_style(Color("cde6c9"), Color("76ae7a")))
	feedback.add_theme_color_override("font_color", Color("d6f1cd"))
	feedback.text = str(game_data.get("correct_feedback", ""))
	instruction.text = str(game_data.get("instruction", ""))
	game.set_meta("selected_clue", null)
	var filled_count := int(game.get_meta("filled_count", 0)) + 1
	game.set_meta("filled_count", filled_count)
	var slots: Array = game_data.get("slots", [])
	if filled_count < slots.size():
		return
	game.set_meta("completed", true)
	feedback.text = str(game_data.get("completion_feedback", ""))
	await get_tree().create_timer(float(game_data.get("completion_delay", 1.8))).timeout
	if is_instance_valid(game):
		game.queue_free()
	if bool(game_data.get("complete_mission", false)):
		ProgressStore.complete_mission(int(level_data.get("stage", 0)), int(level_data.get("mission", 0)))
		show_stage_progress()
