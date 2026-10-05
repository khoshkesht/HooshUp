class_name DevelopmentMissionSelector
extends Control

## Temporary debug-only mission picker. It only forces the selected mission's
## initial load; normal progress, checkpoints, and score saving remain active.
## Remove its instantiation from global_menu.gd (and this file) before release.

const LEVEL_1_SCENE := "res://scenes/level1.tscn"
const PANEL_SIZE := Vector2(580, 330)

var stage_picker: OptionButton
var mission_picker: OptionButton
var launch_button: Button
var availability_label: Label
var panel: Panel

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_controls()

func build_controls() -> void:
	var toggle := Button.new()
	toggle.name = "DevelopmentMissionToggle"
	toggle.layout_direction = Control.LAYOUT_DIRECTION_LTR
	toggle.text_direction = Control.TEXT_DIRECTION_RTL
	toggle.text = "تست مأموریت"
	toggle.tooltip_text = "انتخاب مستقیم مرحله و مأموریت برای تست"
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.position = Vector2(20, 650)
	toggle.size = Vector2(150, 48)
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(toggle)
	toggle.pressed.connect(toggle_panel)

	panel = Panel.new()
	panel.name = "DevelopmentMissionPanel"
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.position = Vector2(20, 300)
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", make_panel_style())
	add_child(panel)
	panel.hide()

	add_label("عنوان", Vector2(36, 28), Vector2(508, 34), 24)
	add_label("مرحله", Vector2(36, 94), Vector2(130, 32), 20)
	stage_picker = OptionButton.new()
	stage_picker.name = "StagePicker"
	stage_picker.layout_direction = Control.LAYOUT_DIRECTION_LTR
	stage_picker.text_direction = Control.TEXT_DIRECTION_RTL
	stage_picker.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_picker.position = Vector2(178, 88)
	stage_picker.size = Vector2(366, 42)
	panel.add_child(stage_picker)
	for stage_number in range(1, GameContent.STAGES.size() + 1):
		stage_picker.add_item("مرحله %d: %s" % [stage_number, str(GameContent.get_stage(stage_number).get("title", ""))], stage_number)
	stage_picker.item_selected.connect(_on_stage_selected)
	# Start the temporary test picker on the level currently under development.
	stage_picker.select(1)

	add_label("مأموریت", Vector2(36, 150), Vector2(130, 32), 20)
	mission_picker = OptionButton.new()
	mission_picker.name = "MissionPicker"
	mission_picker.layout_direction = Control.LAYOUT_DIRECTION_LTR
	mission_picker.text_direction = Control.TEXT_DIRECTION_RTL
	mission_picker.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_picker.position = Vector2(178, 144)
	mission_picker.size = Vector2(366, 42)
	panel.add_child(mission_picker)
	mission_picker.item_selected.connect(_on_mission_selected)

	availability_label = Label.new()
	availability_label.name = "Availability"
	availability_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	availability_label.text_direction = Control.TEXT_DIRECTION_RTL
	availability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	availability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	availability_label.add_theme_font_size_override("font_size", 17)
	availability_label.position = Vector2(36, 204)
	availability_label.size = Vector2(508, 48)
	panel.add_child(availability_label)

	launch_button = Button.new()
	launch_button.name = "LaunchSelectedMission"
	launch_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	launch_button.text_direction = Control.TEXT_DIRECTION_RTL
	launch_button.text = "اجرای مأموریت انتخاب‌شده"
	launch_button.add_theme_font_size_override("font_size", 20)
	launch_button.position = Vector2(178, 268)
	launch_button.size = Vector2(366, 44)
	panel.add_child(launch_button)
	launch_button.pressed.connect(launch_selected_mission)
	refresh_mission_picker()
	mission_picker.select(1)
	refresh_availability()

func add_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	panel.add_child(label)
	label.position = position_value
	label.size = size_value

func toggle_panel() -> void:
	panel.visible = not panel.visible

func _on_stage_selected(_index: int) -> void:
	refresh_mission_picker()

func _on_mission_selected(_index: int) -> void:
	refresh_availability()

func refresh_mission_picker() -> void:
	mission_picker.clear()
	var stage_number := get_selected_stage()
	for mission_number in range(1, ProgressStore.MISSIONS_PER_STAGE + 1):
		mission_picker.add_item("مأموریت %d: %s" % [mission_number, GameContent.get_mission_title(stage_number, mission_number)], mission_number)
	refresh_availability()

func refresh_availability() -> void:
	var mission_path := get_selected_mission_path()
	var is_available := FileAccess.file_exists(mission_path)
	launch_button.disabled = not is_available
	availability_label.add_theme_color_override("font_color", Color("1b5d45") if is_available else Color("9a4036"))
	availability_label.text = "دادهٔ این مأموریت آماده است." if is_available else "دادهٔ این مأموریت هنوز در پروژه وجود ندارد."

func launch_selected_mission() -> void:
	if launch_button.disabled:
		return
	panel.hide()
	ProgressStore.begin_test_mission(get_selected_stage(), get_selected_mission())
	get_tree().change_scene_to_file(LEVEL_1_SCENE)

func get_selected_stage() -> int:
	return stage_picker.get_item_id(stage_picker.selected)

func get_selected_mission() -> int:
	return mission_picker.get_item_id(mission_picker.selected)

func get_selected_mission_path() -> String:
	return "res://data/levels/level%d_mission%d.json" % [get_selected_stage(), get_selected_mission()]

func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17233be8")
	style.border_color = Color("8bd8d2")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style
