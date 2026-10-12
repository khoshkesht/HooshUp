class_name StageProgressPanel
extends Control

signal closed(next_stage: int, next_mission: int)
signal badges_requested

const PANEL_TEXTURE := preload("res://assets/pics/ui/level.png")
const PASSED_MISSION_TEXTURE := preload("res://assets/pics/ui/level-pessed.png")
# The artwork and all interactive content share this canvas.  Controls use
# explicit scaled coordinates because Control children do not reliably inherit
# their parent's scale on every Android viewport.
const DESIGN_SIZE := Vector2(1672, 941)
const PANEL_BASE_SCALE := 1200.0 / DESIGN_SIZE.x
const TEXT_COLOR := Color("4a2917")
const MISSION_NUMBER_CENTERS := [Vector2(220, 337), Vector2(534, 337), Vector2(835, 337), Vector2(1140, 337), Vector2(1452, 337)]
const MISSION_CIRCLE_CENTERS := [Vector2(220, 488), Vector2(534, 488), Vector2(835, 488), Vector2(1140, 488), Vector2(1452, 488)]

var stage_number := 1
var completed_missions: Array[int] = []
var panel: TextureRect
var content: Control
var close_tween: Tween
var panel_scale := 1.0
var art_frame: ArtUiFrame

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_panel()
	art_frame = ArtUiFrame.wrap(self, panel, DESIGN_SIZE, Vector2(1800, 1012.5))
	content.reparent(panel, false)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(refresh_layout)

func show_stage(stage_value: int, completed: Array[int]) -> void:
	stage_number = stage_value
	completed_missions = completed
	if is_node_ready():
		refresh()
	show()

func build_panel() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	panel = TextureRect.new()
	panel.name = "StagePanel"
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.texture = PANEL_TEXTURE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.size = DESIGN_SIZE
	panel.position = Vector2(40, -panel.size.y)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	content = Control.new()
	content.name = "StageContent"
	content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(content)
	refresh_layout()
	refresh()

func refresh_layout() -> void:
	if art_frame != null:
		art_frame.refresh_layout()

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var stage: Dictionary = GameContent.get_stage(stage_number)
	add_text("StageTitle", "مرحله %s از %s" % [to_persian_digits(stage_number), to_persian_digits(GameContent.STAGES.size())], Vector2(560, 123), Vector2(400, 66), 54)
	add_text("StageName", str(stage.get("progress_title", stage.get("title", ""))), Vector2(535, 184), Vector2(425, 48), 34)
	var missions: Array = stage.get("missions", [])
	for mission_index in MISSION_NUMBER_CENTERS.size():
		var number := mission_index + 1
		if completed_missions.has(number):
			add_pass_mark(number, MISSION_CIRCLE_CENTERS[mission_index])
		add_text("MissionNumber%d" % number, to_persian_digits(number), MISSION_NUMBER_CENTERS[mission_index] - Vector2(44, 40), Vector2(88, 80), 52, HORIZONTAL_ALIGNMENT_CENTER)
		(content.get_node("MissionNumber%d" % number) as Label).add_theme_color_override("font_color", Color.WHITE)
		add_text("MissionTitle%d" % number, str(missions[mission_index]), Vector2(MISSION_CIRCLE_CENTERS[mission_index].x - 117, 584), Vector2(234, 76), 30)
	var next_stage := stage_number
	var next_mission := ProgressStore.get_next_mission(stage_number)
	var stage_completed := next_mission == 0
	if stage_completed and stage_number < GameContent.STAGES.size():
		next_stage += 1
		next_mission = 1
	var action := Button.new()
	action.name = "ContinueButton"
	action.flat = true
	action.layout_direction = Control.LAYOUT_DIRECTION_LTR
	action.text_direction = Control.TEXT_DIRECTION_RTL
	action.text = "ادامه..." if stage_completed else GameContent.get_mission_title(next_stage, next_mission)
	action.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		action.add_theme_color_override(color_name, TEXT_COLOR)
	action.add_theme_font_size_override("font_size", roundi(36 * panel_scale))
	if not stage_completed:
		action.pressed.connect(close_and_continue.bind(next_stage, next_mission))
	else:
		action.pressed.connect(show_badges)
	content.add_child(action)
	action.position = scale_position(Vector2(608, 730))
	action.size = scale_position(Vector2(458, 94))
	ArtUiFrame.anchor(action, Rect2(Vector2(608, 730), Vector2(458, 94)), DESIGN_SIZE)

func add_text(node_name: String, text_value: String, design_position: Vector2, design_size: Vector2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER, single_line := false) -> void:
	var label := Label.new()
	label.name = node_name
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if single_line else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", roundi(font_size * panel_scale))
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	label.position = scale_position(design_position)
	label.size = scale_position(design_size)
	ArtUiFrame.anchor(label, Rect2(design_position, design_size), DESIGN_SIZE)

func add_pass_mark(mission_number: int, design_center: Vector2) -> void:
	var mark := TextureRect.new()
	mark.name = "PassedMission%d" % mission_number
	mark.layout_direction = Control.LAYOUT_DIRECTION_LTR
	mark.texture = PASSED_MISSION_TEXTURE
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(mark)
	var mark_size := Vector2(187, 185)
	var mark_rect := Rect2(design_center - mark_size * 0.5, mark_size)
	mark.size = scale_position(mark_size)
	mark.position = scale_position(mark_rect.position)
	ArtUiFrame.anchor(mark, mark_rect, DESIGN_SIZE)

func scale_position(design_value: Vector2) -> Vector2:
	return design_value * panel_scale

func to_persian_digits(value: Variant) -> String:
	var latin := str(value)
	var persian_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for digit in 10:
		latin = latin.replace(str(digit), persian_digits[digit])
	return latin

func close_and_continue(next_stage: int, next_mission: int) -> void:
	hide()
	closed.emit(next_stage, next_mission)

func show_badges() -> void:
	badges_requested.emit()
