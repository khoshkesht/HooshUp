extends Control

const LEVEL_1_SCENE := "res://scenes/level1.tscn"
const MAP_ZOOM := 1.3
const TAP_DRAG_THRESHOLD := 12.0
const LOCK_TEXTURE := preload("res://assets/pics/ui/lock.png")

const STAGE_LABELS := [
	Rect2(69, 153, 192, 37), Rect2(420, 153, 186, 37), Rect2(724, 153, 186, 37), Rect2(1045, 176, 186, 37),
	Rect2(202, 339, 188, 39), Rect2(552, 347, 188, 39), Rect2(914, 353, 180, 39),
	Rect2(69, 568, 188, 39), Rect2(478, 583, 188, 39), Rect2(963, 590, 195, 39)
]

@onready var map_content: Control = $MapContent

var is_dragging := false
var press_position := Vector2.ZERO
var did_pan := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	map_content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	map_content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_content.size = ResponsiveLayout.DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	for stage_index in STAGE_LABELS.size():
		add_stage_button(stage_index + 1, STAGE_LABELS[stage_index])
	call_deferred("reset_view")

func add_stage_button(stage_number: int, target_rect: Rect2) -> void:
	var stage: Dictionary = GameContent.get_stage(stage_number)
	var button := Button.new()
	button.name = "Stage%d" % stage_number
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.flat = true
	button.text = str(stage.get("title", ""))
	var is_unlocked := is_stage_unlocked(stage_number)
	button.add_theme_color_override("font_color", Color(0.18, 0.08, 0.05, 1.0) if is_unlocked else Color(0.38, 0.38, 0.4, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.42, 0.16, 0.08, 1.0) if is_unlocked else Color(0.38, 0.38, 0.4, 1.0))
	button.add_theme_font_size_override("font_size", 20)
	if is_unlocked:
		button.pressed.connect(open_stage.bind(stage_number))
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	map_content.add_child(button)
	# Set coordinates after parenting: Android can resolve inherited layout direction then.
	button.position = target_rect.position
	button.size = target_rect.size
	if not is_unlocked:
		add_lock_icon(target_rect)

func is_stage_unlocked(stage_number: int) -> bool:
	return ProgressStore.is_stage_unlocked(stage_number)

func add_lock_icon(target_rect: Rect2) -> void:
	var lock_icon := TextureRect.new()
	lock_icon.layout_direction = Control.LAYOUT_DIRECTION_LTR
	lock_icon.texture = LOCK_TEXTURE
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(lock_icon)
	lock_icon.position = target_rect.position + Vector2(10, 6)
	lock_icon.size = Vector2(22, 27)

func open_stage(stage_number: int) -> void:
	if stage_number == 1:
		get_tree().change_scene_to_file(LEVEL_1_SCENE)
		return
	push_error("No scene has been created for stage %d yet." % stage_number)

func reset_view() -> void:
	var cover_scale := ResponsiveLayout.cover_scale(size)
	map_content.scale = Vector2.ONE * cover_scale * MAP_ZOOM
	# Keep the campaign's first stages visible when entering the map.
	map_content.position = ResponsiveLayout.centered_position(size, ResponsiveLayout.DESIGN_SIZE, cover_scale)

func clamp_map_position() -> void:
	var minimum_position := size - map_content.size * map_content.scale.x
	map_content.position.x = clamp(map_content.position.x, minimum_position.x, 0.0)
	map_content.position.y = clamp(map_content.position.y, minimum_position.y, 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			is_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		map_content.position += event.relative
		clamp_map_position()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			is_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		map_content.position += event.relative
		clamp_map_position()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(map_content):
		call_deferred("reset_view")
