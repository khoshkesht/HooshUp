extends Control
class_name DialoguePanel

signal choice_selected(choice_id: String)
signal dismiss_requested

const BUBBLE_TEXTURE := preload("res://assets/pics/ui/bubble.png")
const HINT_BUBBLE_TEXTURE := preload("res://assets/pics/ui/bubble2.png")
const THOUGHT_BUBBLE_SIZE := Vector2(1005, 136.8)
const PROMPT_BUBBLE_SIZE := Vector2(1005, 129.96)
const THOUGHT_BUBBLE_OPACITY := 0.85

@onready var speaker_label: Label = $Panel/Margin/Content/MessageHeader/Speaker
@onready var text_label: Label = $Panel/Margin/Content/Text
@onready var choices: VBoxContainer = $Panel/Margin/Content/Choices
@onready var message_header: Control = $Panel/Margin/Content/MessageHeader
@onready var message_icon: Control = $Panel/Margin/Content/MessageHeader/MessageIcon
@onready var panel: PanelContainer = $Panel

var content_scroll: ScrollContainer
var requested_size := Vector2(1040, 300)
var layout_pending := false
var content_press_position := Vector2.ZERO
var content_pressed := false
var default_panel_style: StyleBox
var is_thought := false
var is_hint := false
var dismiss_on_tap := false
var thought_bubble_texture: Texture2D
var prompt_bubble_texture: Texture2D

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	thought_bubble_texture = make_flipped_texture(BUBBLE_TEXTURE)
	prompt_bubble_texture = make_flipped_texture(HINT_BUBBLE_TEXTURE, true)
	$Panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	for label in [speaker_label, text_label]:
		label.layout_direction = Control.LAYOUT_DIRECTION_LTR
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	default_panel_style = panel.get_theme_stylebox("panel")
	content_scroll = ScrollContainer.new()
	content_scroll.name = "DialogueScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	content_scroll.gui_input.connect(_on_content_input)
	var content: VBoxContainer = $Panel/Margin/Content
	$Panel/Margin.add_child(content_scroll)
	content.reparent(content_scroll, false)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.minimum_size_changed.connect(queue_layout)
	$Panel/Margin.mouse_filter = Control.MOUSE_FILTER_PASS
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	message_header.mouse_filter = Control.MOUSE_FILTER_PASS
	choices.mouse_filter = Control.MOUSE_FILTER_PASS
	message_header.get_node("Spacer").mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_layout)
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
	queue_layout()

func apply_presentation_style() -> void:
	if not uses_bubble_presentation():
		panel.modulate.a = 1.0
		panel.add_theme_stylebox_override("panel", default_panel_style)
		text_label.add_theme_color_override("font_color", Color(0.93, 0.96, 1, 1))
		text_label.add_theme_font_size_override("font_size", 44)
		return
	var bubble_style := StyleBoxTexture.new()
	panel.modulate.a = THOUGHT_BUBBLE_OPACITY
	bubble_style.texture = prompt_bubble_texture if is_hint else thought_bubble_texture
	# تصویر و حاشیهٔ هنری موجود حفظ می‌شوند؛ جای‌گذاری از SafeArea می‌آید.
	bubble_style.set_content_margin(SIDE_LEFT, 50.0 if is_hint else 120.0)
	bubble_style.set_content_margin(SIDE_TOP, 24.0 if is_hint else 20.0)
	bubble_style.set_content_margin(SIDE_RIGHT, 120.0 if is_hint else 50.0)
	bubble_style.set_content_margin(SIDE_BOTTOM, 14.0 if is_hint else 20.0)
	panel.add_theme_stylebox_override("panel", bubble_style)
	text_label.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07, 1.0))
	text_label.add_theme_font_size_override("font_size", 30)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventScreenTouch:
		if panel.get_rect().has_point(event.position):
			return
	if dismiss_on_tap and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss_requested.emit()
	elif dismiss_on_tap and event is InputEventScreenTouch and event.pressed:
		dismiss_requested.emit()

func _on_content_input(event: InputEvent) -> void:
	if not dismiss_on_tap:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch:
		if event.pressed:
			content_press_position = event.position
			content_pressed = true
		else:
			if content_pressed and event.position.distance_to(content_press_position) <= 12:
				dismiss_requested.emit()
			content_pressed = false
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if event.position.distance_to(content_press_position) > 12:
			content_pressed = false

func apply_layout(layout: Dictionary) -> void:
	var value: Array = layout.get("size", [1040.0, 300.0])
	requested_size = Vector2(float(value[0]), float(value[1]))
	queue_layout()

func queue_layout() -> void:
	if not layout_pending:
		layout_pending = true
		call_deferred("refresh_layout")

func refresh_layout() -> void:
	layout_pending = false
	if not is_instance_valid(panel):
		return
	var root := get_parent() as MobileUiRoot
	var bounds := root.get_content_rect() if root != null else Rect2(Vector2.ZERO, size)
	var bubble_size := PROMPT_BUBBLE_SIZE if is_hint else THOUGHT_BUBBLE_SIZE
	var width := minf(bounds.size.x, (bubble_size.x if uses_bubble_presentation() else requested_size.x) * 1.5)
	var ratio := width / (bubble_size.x if uses_bubble_presentation() else requested_size.x)
	text_label.add_theme_font_size_override("font_size", roundi((30 if uses_bubble_presentation() else 44) * ratio))
	speaker_label.add_theme_font_size_override("font_size", roundi(44 * ratio))
	for button in choices.get_children():
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", roundi((28 if uses_bubble_presentation() else 30) * ratio))
	var top := bounds.position.y
	if uses_bubble_presentation() and is_instance_valid(GlobalMenu.menu_overlay.toolbar) and GlobalMenu.menu_overlay.toolbar.is_visible_in_tree():
		top = maxf(top, GlobalMenu.menu_overlay.toolbar.get_global_rect().end.y + 16)
	var available_height := maxf(0, bounds.end.y - top)
	var desired_height := bubble_size.y * ratio if uses_bubble_presentation() else requested_size.y * ratio
	var content: Control = content_scroll.get_child(0)
	var style := panel.get_theme_stylebox("panel")
	desired_height = maxf(desired_height, content.get_combined_minimum_size().y + style.get_minimum_size().y + 48)
	panel.scale = Vector2.ONE
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(width, minf(available_height, desired_height))
	panel.position = Vector2(bounds.end.x - width, top if uses_bubble_presentation() else bounds.end.y - panel.size.y)

func hide_dialogue() -> void:
	hide()

func clear_choices() -> void:
	for choice in choices.get_children():
		choices.remove_child(choice)
		choice.queue_free()

func add_choice(choice: Dictionary) -> void:
	var button := MissionButton.new()
	button.custom_minimum_size = Vector2(72, 72)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF if uses_bubble_presentation() else TextServer.AUTOWRAP_WORD_SMART
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

func make_flipped_texture(texture: Texture2D, flip_vertical := false) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	image.flip_x()
	if flip_vertical:
		image.flip_y()
	return ImageTexture.create_from_image(image)
