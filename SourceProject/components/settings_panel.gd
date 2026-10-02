class_name SettingsPanel
extends Control

const PANEL_TEXTURE := preload("res://assets/pics/ui/menu-settings.png")
const CLOSE_TEXTURE := preload("res://assets/pics/ui/close.png")
const MUSIC_ON_TEXTURE := preload("res://assets/pics/ui/mudic-on.png")
const MUSIC_OFF_TEXTURE := preload("res://assets/pics/ui/mudic-off.png")

var panel: TextureRect
var name_input: LineEdit
var avatar_buttons: Dictionary = {}
var music_toggle: Button
var music_icon: TextureRect
var selected_avatar_id := GameSettings.DEFAULT_GIRL_AVATAR_ID
var music_enabled := true

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build()
	resized.connect(refresh_layout)
	hide()

func open_settings() -> void:
	selected_avatar_id = GameSettings.selected_avatar_id
	name_input.text = GameSettings.player_name
	music_enabled = GameSettings.background_music_enabled
	update_avatar_buttons()
	update_music_buttons()
	show()

func build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.06, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	panel = TextureRect.new()
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.texture = PANEL_TEXTURE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.size = Vector2(1200, 675)
	panel.position = Vector2(40, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	refresh_layout()
	add_label("Title", "تنظیمات", Vector2(500, 33), Vector2(200, 62), 34, HORIZONTAL_ALIGNMENT_CENTER)
	add_label("NameLabel", "نام بازیکن", Vector2(948, 150), Vector2(164, 55), 27, HORIZONTAL_ALIGNMENT_CENTER)
	name_input = LineEdit.new()
	name_input.layout_direction = Control.LAYOUT_DIRECTION_LTR
	name_input.text_direction = Control.TEXT_DIRECTION_RTL
	name_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_input.placeholder_text = "نام خودت را بنویس"
	name_input.add_theme_font_size_override("font_size", 25)
	name_input.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.64, 0.7, 0.85))
	var input_style := StyleBoxEmpty.new()
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_stylebox_override("focus", input_style)
	panel.add_child(name_input)
	name_input.position = Vector2(155, 151)
	name_input.size = Vector2(723, 65)
	var avatar_slots := [Vector2(225, 250), Vector2(398, 250), Vector2(225, 404), Vector2(398, 404)]
	add_avatar_button(1, avatar_slots[0])
	add_avatar_button(2, avatar_slots[1])
	add_avatar_button(6, avatar_slots[2])
	add_avatar_button(7, avatar_slots[3])
	add_label("MusicLabel", "موسیقی", Vector2(835, 334), Vector2(245, 60), 27, HORIZONTAL_ALIGNMENT_CENTER)
	music_toggle = Button.new()
	music_toggle.name = "MusicToggle"
	music_toggle.layout_direction = Control.LAYOUT_DIRECTION_LTR
	music_toggle.flat = true
	music_toggle.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	music_toggle.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	music_toggle.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	panel.add_child(music_toggle)
	music_toggle.position = Vector2(675, 315)
	music_toggle.size = Vector2(115, 110)
	music_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	music_toggle.pressed.connect(toggle_music)
	music_icon = TextureRect.new()
	music_icon.name = "MusicIcon"
	music_icon.layout_direction = Control.LAYOUT_DIRECTION_LTR
	music_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	music_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	music_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(music_icon)
	music_icon.position = Vector2(709, 350)
	music_icon.size = Vector2(47, 39)
	var save_button := add_button("Save", "", Vector2(430, 535), Vector2(340, 92))
	save_button.flat = true
	save_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	save_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	save_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	save_button.pressed.connect(save_settings)
	add_label("SaveLabel", "ذخیره", Vector2(430, 535), Vector2(340, 92), 32, HORIZONTAL_ALIGNMENT_CENTER)
	var close_button := TextureButton.new()
	close_button.name = "Close"
	close_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	close_button.texture_normal = CLOSE_TEXTURE
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(close_button)
	close_button.position = Vector2(1080, 38)
	close_button.size = Vector2(68, 64)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(hide)

func refresh_layout() -> void:
	if not is_instance_valid(panel):
		return
	var scale := ResponsiveLayout.contain_scale(size)
	panel.scale = Vector2.ONE * scale
	panel.position = ResponsiveLayout.design_to_safe(size, Vector2(40, 22))

func add_label(node_name: String, text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	var label := Label.new()
	label.name = node_name
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	label.position = position_value
	label.size = size_value

func add_button(node_name: String, text_value: String, position_value: Vector2, size_value: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 24)
	button.text = text_value
	panel.add_child(button)
	button.position = position_value
	button.size = size_value
	return button

func add_avatar_button(avatar_id: int, position_value: Vector2) -> void:
	var button := TextureButton.new()
	button.name = "Avatar%d" % avatar_id
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.texture_normal = load("res://assets/pics/characters/%s/%d/avatar.png" % ["g" if avatar_id < 6 else "b", avatar_id]) as Texture2D
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.tooltip_text = "آواتار %d" % avatar_id
	panel.add_child(button)
	button.position = position_value
	button.size = Vector2(115, 115)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(select_avatar.bind(avatar_id))
	avatar_buttons[avatar_id] = button

func select_avatar(avatar_id: int) -> void:
	selected_avatar_id = avatar_id
	update_avatar_buttons()

func update_avatar_buttons() -> void:
	for avatar_id in avatar_buttons:
		var button := avatar_buttons[avatar_id] as TextureButton
		if not is_instance_valid(button):
			continue
		button.modulate = Color.WHITE if avatar_id == selected_avatar_id else Color(0.35, 0.35, 0.35, 1.0)
		button.scale = Vector2.ONE

func toggle_music() -> void:
	music_enabled = not music_enabled
	update_music_buttons()

func update_music_buttons() -> void:
	if not is_instance_valid(music_toggle):
		return
	music_icon.texture = MUSIC_ON_TEXTURE if music_enabled else MUSIC_OFF_TEXTURE
	music_toggle.tooltip_text = "روشن" if music_enabled else "خاموش"

func save_settings() -> void:
	GameSettings.save_player_settings(name_input.text, selected_avatar_id, music_enabled)
	hide()
