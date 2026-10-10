extends Control
class_name GameToolbar

signal menu_requested
signal hint_requested

const TOOLBAR_TEXTURE := preload("res://assets/pics/ui/toolbar.png")
const STAR_TEXTURE := preload("res://assets/pics/ui/star.png")
const LOCK_TEXTURE := preload("res://assets/pics/ui/toolbar-lock.png")
const TOOLBAR_SIZE := Vector2(1050, 273)
const TOOLBAR_OPACITY := 0.9
const SOURCE_SCALE := TOOLBAR_SIZE.x / 2093.0
const MISSION_CENTERS: Array[Vector2] = [
	Vector2(610, 263),
	Vector2(808, 263),
	Vector2(995, 263),
	Vector2(1181, 263),
	Vector2(1367, 263),
]
const LOCK_VISUAL_CENTER_OFFSET := Vector2(1, 1)

var avatar: TextureRect
var stage_value: Label
var score_value: Label
var mission_slots: Array[Control] = []
var menu_button: Button
var hint_button: Button

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	modulate.a = TOOLBAR_OPACITY
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TOOLBAR_SIZE
	build_background()
	build_avatar()
	build_values()
	build_mission_slots()
	build_action_buttons()

func build_background() -> void:
	var background := TextureRect.new()
	background.name = "Background"
	background.layout_direction = Control.LAYOUT_DIRECTION_LTR
	background.texture = TOOLBAR_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.position = Vector2.ZERO
	background.size = TOOLBAR_SIZE

func build_avatar() -> void:
	avatar = TextureRect.new()
	avatar.name = "Avatar"
	avatar.layout_direction = Control.LAYOUT_DIRECTION_LTR
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar)
	avatar.position = source_position(Vector2(68, 30))
	avatar.size = source_size(Vector2(370, 338))

func build_values() -> void:
	stage_value = make_value_label(38)
	stage_value.name = "StageValue"
	add_child(stage_value)
	stage_value.position = source_position(Vector2(23, 365))
	stage_value.size = source_size(Vector2(145, 135))

	score_value = make_value_label(27)
	score_value.name = "ScoreValue"
	add_child(score_value)
	score_value.position = source_position(Vector2(172, 400))
	score_value.size = source_size(Vector2(405, 96))

func make_value_label(font_size: int) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("613817"))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func build_mission_slots() -> void:
	for mission_index in MISSION_CENTERS.size():
		var slot := Control.new()
		slot.name = "Mission%d" % (mission_index + 1)
		slot.layout_direction = Control.LAYOUT_DIRECTION_LTR
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var slot_size := source_size(Vector2(188, 188))
		slot.position = source_position(MISSION_CENTERS[mission_index]) - slot_size * 0.5
		slot.size = slot_size
		mission_slots.append(slot)

func build_action_buttons() -> void:
	menu_button = make_action_button("منو")
	menu_button.name = "MenuButton"
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(menu_button)
	menu_button.position = source_position(Vector2(1510, 135))
	menu_button.size = source_size(Vector2(250, 245))

	hint_button = make_action_button("راهنما")
	hint_button.name = "HintButton"
	hint_button.pressed.connect(func() -> void: hint_requested.emit())
	add_child(hint_button)
	hint_button.position = source_position(Vector2(1780, 135))
	hint_button.size = source_size(Vector2(260, 245))

func make_action_button(tooltip: String) -> Button:
	var button := Button.new()
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.flat = true
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, empty_style)
	return button

func set_status(stage_number: int, score: int, completed_missions: Array[int], avatar_texture: Texture2D) -> void:
	avatar.texture = make_avatar_head_texture(avatar_texture)
	stage_value.text = to_persian_digits(stage_number)
	score_value.text = to_persian_digits(score)
	for mission_index in mission_slots.size():
		set_mission_complete(mission_index, completed_missions.has(mission_index + 1))

func set_mission_complete(mission_index: int, is_complete: bool) -> void:
	var slot := mission_slots[mission_index]
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	if is_complete:
		var star := TextureRect.new()
		star.layout_direction = Control.LAYOUT_DIRECTION_LTR
		star.texture = STAR_TEXTURE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(star)
		var star_size := source_size(Vector2(174, 174))
		star.position = (slot.size - star_size) * 0.5
		star.size = star_size
		return
	var lock_icon := TextureRect.new()
	lock_icon.layout_direction = Control.LAYOUT_DIRECTION_LTR
	lock_icon.texture = LOCK_TEXTURE
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(lock_icon)
	var lock_size := source_size(Vector2(73, 94))
	lock_icon.position = (slot.size - lock_size) * 0.5 + source_position(LOCK_VISUAL_CENTER_OFFSET)
	lock_icon.size = lock_size

func make_avatar_head_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var texture_size := texture.get_size()
	var crop_size := minf(texture_size.x, texture_size.y) * 0.78
	var head_texture := AtlasTexture.new()
	head_texture.atlas = texture
	head_texture.region = Rect2(
		Vector2((texture_size.x - crop_size) * 0.5, texture_size.y * 0.02),
		Vector2.ONE * crop_size
	)
	return head_texture

func set_hint_enabled(enabled: bool) -> void:
	hint_button.disabled = not enabled
	hint_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	hint_button.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.45)

func source_position(value: Vector2) -> Vector2:
	return value * SOURCE_SCALE

func source_size(value: Vector2) -> Vector2:
	return value * SOURCE_SCALE

func to_persian_digits(value: int) -> String:
	var result := str(value)
	var persian_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for digit in 10:
		result = result.replace(str(digit), persian_digits[digit])
	return result
