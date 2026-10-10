extends Control
class_name DialoguePanel

signal choice_selected(choice_id: String)
signal dismiss_requested

const BUBBLE_TEXTURE := preload("res://assets/pics/ui/bubble.png")
const HINT_BUBBLE_TEXTURE := preload("res://assets/pics/ui/bubble2.png")
const THOUGHT_BUBBLE_SIZE := Vector2(1005, 136.8)
const THOUGHT_BUBBLE_TOP_LEFT := Vector2(257, 140)
const THOUGHT_BUBBLE_OPACITY := 0.85

@onready var speaker_label: Label = $Panel/Margin/Content/MessageHeader/Speaker
@onready var text_label: Label = $Panel/Margin/Content/Text
@onready var choices: VBoxContainer = $Panel/Margin/Content/Choices
@onready var message_header: Control = $Panel/Margin/Content/MessageHeader
@onready var message_icon: Control = $Panel/Margin/Content/MessageHeader/MessageIcon
@onready var panel: PanelContainer = $Panel

var default_panel_style: StyleBox
var is_thought := false
var is_hint := false
var dismiss_on_tap := false
var flipped_bubble_texture: Texture2D
var flipped_hint_bubble_texture: Texture2D

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	flipped_bubble_texture = make_flipped_texture(BUBBLE_TEXTURE)
	flipped_hint_bubble_texture = make_flipped_texture(HINT_BUBBLE_TEXTURE)
	$Panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	for label in [speaker_label, text_label]:
		label.layout_direction = Control.LAYOUT_DIRECTION_LTR
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	default_panel_style = panel.get_theme_stylebox("panel")
	resized.connect(_refresh_layout)
	hide()

func show_dialogue(dialogue: Dictionary) -> void:
	var presentation := str(dialogue.get("presentation", ""))
	is_thought = presentation == "thought"
	is_hint = presentation == "hint"
	dismiss_on_tap = bool(dialogue.get("dismiss_on_tap", false))
	mouse_filter = Control.MOUSE_FILTER_STOP if dismiss_on_tap else Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if dismiss_on_tap else Control.MOUSE_FILTER_STOP
	apply_presentation_style()
	apply_layout(dialogue.get("layout", {}))
	var speaker := str(dialogue.get("speaker", ""))
	speaker_label.text = speaker
	text_label.text = str(dialogue.get("text", ""))
	var is_message := str(dialogue.get("presentation", "")) == "message"
	message_header.visible = not speaker.is_empty() or is_message
	message_icon.visible = is_message
	clear_choices()

	var choice_data: Array = dialogue.get("choices", [])
	for choice in choice_data:
		add_choice(choice)
	show()

func apply_presentation_style() -> void:
	if not uses_bubble_presentation():
		panel.modulate.a = 1.0
		panel.add_theme_stylebox_override("panel", default_panel_style)
		text_label.add_theme_color_override("font_color", Color(0.93, 0.96, 1, 1))
		text_label.add_theme_font_size_override("font_size", 44)
		return
	var bubble_style := StyleBoxTexture.new()
	panel.modulate.a = THOUGHT_BUBBLE_OPACITY
	bubble_style.texture = flipped_hint_bubble_texture if is_hint else flipped_bubble_texture
	# The bubble assets are already cropped. Use their full texture so their
	# existing 1005px display width and top-left placement remain unchanged.
	bubble_style.set_content_margin(SIDE_LEFT, 120.0)
	bubble_style.set_content_margin(SIDE_TOP, 20.0)
	bubble_style.set_content_margin(SIDE_RIGHT, 50.0)
	bubble_style.set_content_margin(SIDE_BOTTOM, 20.0)
	panel.add_theme_stylebox_override("panel", bubble_style)
	text_label.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07, 1.0))
	text_label.add_theme_font_size_override("font_size", 30)

func _gui_input(event: InputEvent) -> void:
	if dismiss_on_tap and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss_requested.emit()
	elif dismiss_on_tap and event is InputEventScreenTouch and event.pressed:
		dismiss_requested.emit()

func apply_layout(layout: Dictionary) -> void:
	if layout.is_empty() and not uses_bubble_presentation():
		return
	var panel_size: Array = [THOUGHT_BUBBLE_SIZE.x, THOUGHT_BUBBLE_SIZE.y] if uses_bubble_presentation() else layout.get("size", [1040.0, 300.0])
	var center_position: Array = [
		THOUGHT_BUBBLE_TOP_LEFT.x + THOUGHT_BUBBLE_SIZE.x * 0.5,
		THOUGHT_BUBBLE_TOP_LEFT.y + THOUGHT_BUBBLE_SIZE.y * 0.5
	] if uses_bubble_presentation() else layout.get("position", [640.0, 530.0])
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.size = Vector2(float(panel_size[0]), float(panel_size[1]))
	panel.set_meta("design_center", Vector2(float(center_position[0]), float(center_position[1])))
	_refresh_layout()

func _refresh_layout() -> void:
	if not is_instance_valid(panel) or not panel.has_meta("design_center"):
		return
	var design_center: Vector2 = panel.get_meta("design_center")
	var scale := ResponsiveLayout.contain_scale(size)
	panel.scale = Vector2.ONE * scale
	panel.position = ResponsiveLayout.design_to_safe(size, design_center - panel.size * 0.5)

func hide_dialogue() -> void:
	hide()

func clear_choices() -> void:
	for choice in choices.get_children():
		choice.queue_free()

func add_choice(choice: Dictionary) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if uses_bubble_presentation():
		button.flat = true
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var choice_color := Color(0.16, 0.11, 0.07, 1.0) if uses_bubble_presentation() else Color(1.0, 0.91, 0.62, 1.0)
	button.add_theme_color_override("font_color", choice_color)
	button.add_theme_color_override("font_hover_color", choice_color)
	button.add_theme_font_size_override("font_size", 28 if uses_bubble_presentation() else 30)
	button.text = str(choice.get("text", "ادامه"))
	button.pressed.connect(func() -> void: choice_selected.emit(str(choice.get("id", "continue"))))
	choices.add_child(button)

func uses_bubble_presentation() -> bool:
	return is_thought or is_hint

func make_flipped_texture(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	image.flip_x()
	return ImageTexture.create_from_image(image)
