extends Control

signal menu_action_requested(action_id: String)
signal hint_confirmed

const HINT_ICON := preload("res://assets/pics/ui/hint.png")

@onready var menu_button: TextureButton = $MenuButton
@onready var menu_panel: TextureRect = $MenuPanel
@onready var avatar: TextureRect = $MenuPanel/MenuContent/Avatar
@onready var user_name: Label = $MenuPanel/MenuContent/UserName
@onready var star_label: Label = $MenuPanel/MenuContent/StarLabel
@onready var star_value: Label = $MenuPanel/MenuContent/StarValue
@onready var score_label: Label = $MenuPanel/MenuContent/ScoreLabel
@onready var score_value: Label = $MenuPanel/MenuContent/ScoreValue
@onready var stage_label: Label = $MenuPanel/MenuContent/StageLabel
@onready var stage_value: Label = $MenuPanel/MenuContent/StageValue
@onready var exit_confirmation: Control = $ExitConfirmation
@onready var confirmation_text: Label = $ExitConfirmation/Panel/Margin/Content/Text
@onready var cancel_exit_button: Button = $ExitConfirmation/Panel/Margin/Content/Actions/CancelButton
@onready var confirm_exit_button: Button = $ExitConfirmation/Panel/Margin/Content/Actions/ConfirmButton

var is_open := false
var menu_tween: Tween
var safe_scale := 1.0
var safe_origin := Vector2.ZERO
var hint_button: TextureButton
var hint_confirmation: Control
var hint_available := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	menu_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	menu_panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	avatar.texture = GameSettings.get_avatar_texture()
	user_name.text = GameSettings.player_name
	GameSettings.settings_changed.connect(_on_game_settings_changed)
	ScoreStore.scores_changed.connect(refresh_progress_values)
	for label in [user_name, star_label, star_value, score_label, score_value, stage_label, stage_value]:
		label.layout_direction = Control.LAYOUT_DIRECTION_LTR
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_text.layout_direction = Control.LAYOUT_DIRECTION_LTR
	confirmation_text.text_direction = Control.TEXT_DIRECTION_RTL
	confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for button in [cancel_exit_button, confirm_exit_button]:
		button.layout_direction = Control.LAYOUT_DIRECTION_LTR
		button.text_direction = Control.TEXT_DIRECTION_RTL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button.pressed.connect(toggle_menu)
	build_hint_controls()
	resized.connect(refresh_layout)
	call_deferred("prepare_menu")
	refresh_progress_values()

func prepare_menu() -> void:
	refresh_layout()
	menu_panel.position = get_hidden_menu_position()
	menu_panel.hide()

func refresh_layout() -> void:
	safe_scale = ResponsiveLayout.contain_scale(size)
	safe_origin = ResponsiveLayout.safe_origin(size)
	menu_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_panel.size = ResponsiveLayout.DESIGN_SIZE
	menu_panel.scale = Vector2.ONE * safe_scale
	if not is_open:
		menu_panel.position = get_hidden_menu_position()
	menu_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_button.size = Vector2(88, 88)
	menu_button.scale = Vector2.ONE * safe_scale
	menu_button.position = safe_origin + Vector2(1172, 20) * safe_scale
	if is_instance_valid(hint_button):
		hint_button.size = Vector2(88, 88)
		hint_button.scale = Vector2.ONE * safe_scale
		hint_button.position = safe_origin + Vector2(1172, 116) * safe_scale
	refresh_hint_visibility()

func build_hint_controls() -> void:
	hint_button = TextureButton.new()
	hint_button.name = "HintButton"
	hint_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	hint_button.texture_normal = HINT_ICON
	hint_button.ignore_texture_size = true
	hint_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	hint_button.modulate.a = 0.7
	hint_button.tooltip_text = "راهنما"
	hint_button.pressed.connect(_on_hint_pressed)
	add_child(hint_button)

	hint_confirmation = build_hint_confirmation()
	add_child(hint_confirmation)

func _on_hint_pressed() -> void:
	if not hint_available or is_open:
		return
	hint_button.hide()
	hint_confirmation.show()

func build_hint_confirmation() -> Control:
	var overlay := Control.new()
	overlay.name = "HintConfirmation"
	overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -150)
	panel.size = Vector2(640, 300)
	panel.add_theme_stylebox_override("panel", make_hint_panel_style())
	overlay.add_child(panel)
	var content := Control.new()
	content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(content)
	var title := make_hint_label("راهنما", 36)
	title.position = Vector2(38, 28)
	title.size = Vector2(564, 50)
	title.add_theme_color_override("font_color", Color("f6c766"))
	content.add_child(title)
	var text := make_hint_label("راهنما می‌خوای؟ با این انتخاب ۵ امتیاز کم می‌شود.", 29)
	text.position = Vector2(38, 92)
	text.size = Vector2(564, 82)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text)
	var cancel := make_hint_button("نه، فعلاً نه", Color("314b66"), Color("7190aa"))
	cancel.position = Vector2(38, 208)
	cancel.size = Vector2(210, 56)
	cancel.pressed.connect(func() -> void:
		overlay.hide()
		refresh_hint_visibility()
	)
	content.add_child(cancel)
	var confirm := make_hint_button("بله، راهنما را نشان بده", Color("c9792d"), Color("ffd27b"))
	confirm.position = Vector2(268, 208)
	confirm.size = Vector2(334, 56)
	confirm.pressed.connect(func() -> void:
		overlay.hide()
		hint_confirmed.emit()
		refresh_hint_visibility()
	)
	content.add_child(confirm)
	return overlay

func make_hint_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102944")
	style.border_color = Color("f1ba55")
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	return style

func make_hint_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("eff6ff"))
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text_value
	return label

func make_hint_button(text_value: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = text_value
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = background.lightened(0.10) if state == "hover" else background
		style.border_color = border
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		button.add_theme_stylebox_override(state, style)
	return button

func set_hint_available(is_available: bool) -> void:
	hint_available = is_available
	refresh_hint_visibility()

func refresh_hint_visibility() -> void:
	if not is_instance_valid(hint_button):
		return
	var is_confirmation_open := is_instance_valid(hint_confirmation) and hint_confirmation.visible
	hint_button.visible = hint_available and not is_open and not is_confirmation_open

func get_hidden_menu_position() -> Vector2:
	return safe_origin + Vector2(0, -ResponsiveLayout.DESIGN_SIZE.y * safe_scale)

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	refresh_progress_values()
	menu_button.hide()
	refresh_hint_visibility()
	menu_panel.show()
	animate_panel(safe_origin, false)

func close_menu() -> void:
	is_open = false
	exit_confirmation.hide()
	animate_panel(get_hidden_menu_position(), true)

func animate_panel(target_position: Vector2, hide_after_animation: bool) -> void:
	if menu_tween != null and menu_tween.is_valid():
		menu_tween.kill()
	menu_tween = create_tween()
	menu_tween.set_trans(Tween.TRANS_QUAD)
	menu_tween.set_ease(Tween.EASE_OUT)
	menu_tween.tween_property(menu_panel, "position", target_position, 0.28)
	if hide_after_animation:
		menu_tween.tween_callback(finish_close)

func finish_close() -> void:
	menu_panel.hide()
	menu_button.show()
	refresh_hint_visibility()

func _on_exit_pressed() -> void:
	exit_confirmation.show()

func _on_exit_confirmed() -> void:
	get_tree().quit()

func _on_exit_cancelled() -> void:
	exit_confirmation.hide()

func _on_menu_action_pressed(action_id: String) -> void:
	menu_action_requested.emit(action_id)
	close_menu()

func _on_game_settings_changed() -> void:
	user_name.text = GameSettings.player_name
	avatar.texture = GameSettings.get_avatar_texture()

func refresh_progress_values() -> void:
	score_value.text = to_persian_digits(ScoreStore.get_total_score())
	star_value.text = to_persian_digits(ScoreStore.get_total_stars())

func to_persian_digits(value: int) -> String:
	var result := str(value)
	var persian_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for digit in 10:
		result = result.replace(str(digit), persian_digits[digit])
	return result
