class_name StageProgressPanel
extends Control

signal closed(next_stage: int, next_mission: int)
signal badges_requested

const PANEL_TEXTURE := preload("res://assets/pics/ui/level.png")
const PASSED_MISSION_TEXTURE := preload("res://assets/pics/ui/passlevel.png")
# The artwork and all interactive content share this canvas.  Controls use
# explicit scaled coordinates because Control children do not reliably inherit
# their parent's scale on every Android viewport.
const DESIGN_SIZE := Vector2(1672, 941)
const PANEL_BASE_SCALE := 1200.0 / DESIGN_SIZE.x
# This correction is in artwork coordinates so it scales identically on both
# canvases.
const MISSION_TITLE_VERTICAL_CORRECTION := Vector2(0, -10)

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
	add_text("StageTitle", "مرحله %s از %s" % [to_persian_digits(stage_number), to_persian_digits(GameContent.STAGES.size())], Vector2(470, 100), Vector2(730, 88), 52, HORIZONTAL_ALIGNMENT_CENTER)
	add_text("StageName", str(stage.get("progress_title", stage.get("title", ""))), Vector2(480, 158), Vector2(680, 56), 30, HORIZONTAL_ALIGNMENT_CENTER)
	var centers := [Vector2(214, 349), Vector2(535, 349), Vector2(842, 349), Vector2(1150, 349), Vector2(1450, 349)]
	var missions: Array = stage.get("missions", [])
	for mission_index in centers.size():
		var number := mission_index + 1
		if completed_missions.has(number):
			add_pass_mark(number, centers[mission_index])
		add_text("MissionNumber%d" % number, to_persian_digits(number), centers[mission_index] - Vector2(46, 75), Vector2(92, 84), 42, HORIZONTAL_ALIGNMENT_CENTER)
		add_text("MissionTitle%d" % number, str(missions[mission_index]), Vector2(centers[mission_index].x - 127, 588) + MISSION_TITLE_VERTICAL_CORRECTION, Vector2(254, 68), 28, HORIZONTAL_ALIGNMENT_CENTER, true)
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
	action.add_theme_color_override("font_color", Color.WHITE)
	action.add_theme_font_size_override("font_size", roundi(36 * panel_scale))
	if not stage_completed:
		action.pressed.connect(close_and_continue.bind(next_stage, next_mission))
	else:
		action.pressed.connect(show_badges)
	content.add_child(action)
	action.position = scale_position(Vector2(605, 735))
	action.size = scale_position(Vector2(465, 75))
	ArtUiFrame.anchor(action, Rect2(Vector2(605, 735), Vector2(465, 75)), DESIGN_SIZE)

func add_text(node_name: String, text_value: String, design_position: Vector2, design_size: Vector2, font_size: int, alignment := HORIZONTAL_ALIGNMENT_RIGHT, single_line := false) -> void:
	var label := Label.new()
	label.name = node_name
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if single_line else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
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
	mark.size = scale_position(Vector2(360, 470))
	mark.position = scale_position(design_center - Vector2(175, 95))
	ArtUiFrame.anchor(mark, Rect2(design_center - Vector2(175, 95), Vector2(360, 470)), DESIGN_SIZE)

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
