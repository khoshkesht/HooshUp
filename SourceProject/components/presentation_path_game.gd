class_name PresentationPathGame
extends Control

signal completed
signal incorrect_route_attempted

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const ROTOR_NAMES := ["پرسش دقیق", "پاسخ هوش آپ", "بازبینی من", "ارائهٔ نهایی"]
# An upright illustration is always the visually correct state. Starting angles
# are randomized below, so the number and order of turns changes every round.
const TARGET_ROTATIONS := [0, 0, 0, 0]
const NODE_TEXTURES := [
	preload("res://assets/pics/ui/path-question.png"),
	preload("res://assets/pics/ui/path-ai-answer.png"),
	preload("res://assets/pics/ui/path-review.png"),
	preload("res://assets/pics/ui/path-presentation.png")
]
const MARS_PRESENTATION_TEXTURE := preload("res://assets/pics/ui/mars-presentation.png")

var rotations := [0, 0, 0, 0]
var route_points: Array[Vector2] = []
var route_lines: Array[ColorRect] = []
var status_label: Label
var launch_button: Button
var has_completed := false
var rotation_in_progress := false
var board: Panel
var rotation_rng := RandomNumberGenerator.new()

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = DESIGN_SIZE
	rotation_rng.randomize()
	resized.connect(center_board)
	build_interface()

func build_interface() -> void:
	var shade := ColorRect.new()
	shade.layout_direction = Control.LAYOUT_DIRECTION_LTR
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("071326e8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	board = Panel.new()
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.size = Vector2(1096, 592)
	board.add_theme_stylebox_override("panel", make_style(Color("102741b8"), Color("73d8d0"), 26))
	add_child(board)
	call_deferred("center_board")
	var mars_preview := TextureRect.new()
	mars_preview.layout_direction = Control.LAYOUT_DIRECTION_LTR
	mars_preview.texture = MARS_PRESENTATION_TEXTURE
	mars_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mars_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mars_preview.modulate = Color(1.0, 1.0, 1.0, 0.4)
	mars_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mars_preview.position = Vector2(24, 118)
	mars_preview.size = Vector2(1048, 330)
	board.add_child(mars_preview)

	var title := make_label("مسیر ارائه را کامل کن", 38, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(120, 24)
	title.size = Vector2(1040, 46)
	board.add_child(title)
	var guide := make_label("هر گره را بچرخان تا نور از پرسش دقیق، پاسخ هوش آپ و بازبینی تو عبور کند.", 24, HORIZONTAL_ALIGNMENT_CENTER)
	guide.add_theme_color_override("font_color", Color("b9dbe6"))
	guide.position = Vector2(110, 73)
	guide.size = Vector2(876, 35)
	board.add_child(guide)

	status_label = make_label("میان‌برِ AI به‌تنهایی، ارائه را کامل نمی‌کند.", 25, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.add_theme_color_override("font_color", Color("f4c875"))
	status_label.position = Vector2(110, 488)
	status_label.size = Vector2(876, 42)
	board.add_child(status_label)

	route_points = [Vector2(138, 306), Vector2(347, 306), Vector2(556, 306), Vector2(765, 306), Vector2(960, 306)]
	for index in route_points.size() - 1:
		var line := ColorRect.new()
		line.layout_direction = Control.LAYOUT_DIRECTION_LTR
		line.color = Color("24394f")
		line.position = Vector2(route_points[index].x + 65, route_points[index].y - 5)
		line.size = Vector2(route_points[index + 1].x - route_points[index].x - 130, 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(line)
		route_lines.append(line)
	for index in ROTOR_NAMES.size():
		var rotor := Button.new()
		rotor.name = "Rotor%d" % index
		rotor.layout_direction = Control.LAYOUT_DIRECTION_LTR
		rotor.tooltip_text = "چرخاندن گره"
		rotor.text = ""
		rotor.add_theme_color_override("font_color", Color("e9fbff"))
		rotor.add_theme_stylebox_override("normal", make_style(Color("285c7a"), Color("9be8df"), 52))
		rotor.add_theme_stylebox_override("hover", make_style(Color("367c96"), Color("d2fffa"), 52))
		rotor.position = route_points[index] - Vector2(65, 65)
		rotor.size = Vector2(130, 130)
		rotor.pivot_offset = rotor.size * 0.5
		# Keep every node out of its solved orientation at the start of a round.
		rotations[index] = (int(TARGET_ROTATIONS[index]) + rotation_rng.randi_range(1, 3)) % 4
		rotor.rotation = float(rotations[index]) * PI * 0.5
		board.add_child(rotor)
		rotor.pressed.connect(_on_rotor_pressed.bind(index, rotor))
		var image := TextureRect.new()
		image.layout_direction = Control.LAYOUT_DIRECTION_LTR
		image.texture = NODE_TEXTURES[index] as Texture2D
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.position = Vector2(13, 13)
		image.size = Vector2(104, 104)
		rotor.add_child(image)
		var turn_mark := Label.new()
		turn_mark.layout_direction = Control.LAYOUT_DIRECTION_LTR
		turn_mark.text = "↻"
		turn_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		turn_mark.add_theme_font_size_override("font_size", 20)
		turn_mark.add_theme_color_override("font_color", Color("e9fbff"))
		turn_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		turn_mark.position = Vector2(96, 5)
		turn_mark.size = Vector2(29, 29)
		rotor.add_child(turn_mark)
		var name_label := make_label(ROTOR_NAMES[index], 23, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.position = Vector2(route_points[index].x - 84, 366)
		name_label.size = Vector2(168, 48)
		board.add_child(name_label)

	launch_button = Button.new()
	launch_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	launch_button.text_direction = Control.TEXT_DIRECTION_RTL
	launch_button.text = "پیش‌نمایش ارائه"
	launch_button.add_theme_font_size_override("font_size", 27)
	launch_button.add_theme_color_override("font_color", Color("efffff"))
	launch_button.add_theme_stylebox_override("normal", make_style(Color("3badae"), Color("8bd8d2"), 15))
	launch_button.add_theme_stylebox_override("hover", make_style(Color("54c3c1"), Color("d4fffa"), 15))
	launch_button.position = Vector2(876, 486)
	launch_button.size = Vector2(190, 47)
	board.add_child(launch_button)
	launch_button.pressed.connect(_on_launch_pressed)

func _on_rotor_pressed(index: int, rotor: Button) -> void:
	if has_completed or rotation_in_progress:
		return
	rotation_in_progress = true
	rotor.disabled = true
	rotations[index] = (int(rotations[index]) + 1) % 4
	var turn_tween := create_tween()
	turn_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(rotor, "rotation", rotor.rotation + PI * 0.5, 0.32)
	await turn_tween.finished
	rotor.rotation = float(rotations[index]) * PI * 0.5
	rotor.disabled = false
	rotation_in_progress = false
	update_status()
	update_route_lines()

func center_board() -> void:
	if is_instance_valid(board):
		board.position = (size - board.size) * 0.5

func _on_launch_pressed() -> void:
	if has_completed or rotation_in_progress:
		return
	if rotations == TARGET_ROTATIONS:
		has_completed = true
		launch_button.disabled = true
		status_label.text = "اتصال پایدار شد؛ این ارائه مسیر فکر کردن خودت را نشان می‌دهد."
		status_label.add_theme_color_override("font_color", Color("9ce8c6"))
		update_route_lines()
		await get_tree().create_timer(1.0).timeout
		completed.emit()
		return
	incorrect_route_attempted.emit()
	status_label.text = "پروژکتور فقط یک متن کلی نشان داد. یک گره از مسیرِ بازبینی جا مانده است."
	status_label.add_theme_color_override("font_color", Color("f08b77"))

func update_status() -> void:
	var matched := 0
	for index in TARGET_ROTATIONS.size():
		if rotations[index] == TARGET_ROTATIONS[index]:
			matched += 1
	status_label.text = "%d از ۴ گره در جهت درست قرار گرفته‌اند." % matched
	status_label.add_theme_color_override("font_color", Color("b9dbe6"))

func update_route_lines() -> void:
	for index in route_lines.size():
		var is_linked: bool = int(rotations[index]) == int(TARGET_ROTATIONS[index])
		route_lines[index].color = Color("9ce8c6") if has_completed else (Color("65d8ce") if is_linked else Color("24394f"))

func make_label(text_value: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text_value
	label.add_theme_color_override("font_color", Color("edf8ff"))
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func make_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
