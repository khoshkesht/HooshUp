class_name DevelopmentMissionSelector
extends Control

signal modal_visibility_changed

const LEVEL_1_SCENE := "res://scenes/level1.tscn"
const PANEL_MAX_SIZE := Vector2(640, 560)

var hud_root: MobileUiRoot
var overlay_root: MobileUiRoot
var diagnostics_root: MobileUiRoot
var stage_picker: OptionButton
var mission_picker: OptionButton
var launch_button: Button
var availability_label: Label
var panel: PanelContainer
var toggle: Button
var diagnostic_label: Label
var modal_center: CenterContainer
var modal_shade: ColorRect
var toggle_host: Control
var diagnostic_host: Control
var _diagnostic_elapsed := 0.0
var _last_layout_log := ""

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_controls()
	resized.connect(layout_controls)
	overlay_root.safe_area_changed.connect(_on_safe_area_changed)
	call_deferred("layout_controls")

func _process(delta: float) -> void:
	_diagnostic_elapsed += delta
	if _diagnostic_elapsed >= MobileUiRoot.REFRESH_INTERVAL:
		_diagnostic_elapsed = 0.0
		update_diagnostics()

func build_controls() -> void:
	toggle_host = make_host(hud_root.safe_margin, "DevelopmentMissionToggleHost")
	toggle = make_button("تست مأموریت")
	toggle.name = "DevelopmentMissionToggle"
	toggle_host.add_child(toggle)
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toggle.offset_top = -72
	toggle.offset_right = 220
	toggle.pressed.connect(toggle_panel)

	modal_shade = ColorRect.new()
	modal_shade.name = "DevelopmentMissionShade"
	modal_shade.layout_direction = Control.LAYOUT_DIRECTION_LTR
	modal_shade.color = Color("071326b8")
	modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(modal_shade)
	overlay_root.move_child(modal_shade, 0)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.gui_input.connect(_on_shade_input)
	modal_shade.hide()

	modal_center = CenterContainer.new()
	modal_center.name = "MissionPickerCenter"
	modal_center.layout_direction = Control.LAYOUT_DIRECTION_LTR
	modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_center)
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "DevelopmentMissionPanel"
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	panel.theme_type_variation = &"MobilePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.name = "MissionPickerScroll"
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "MissionPickerContent"
	content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var header := HBoxContainer.new()
	header.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content.add_child(header)
	var close := make_button("بستن")
	header.add_child(close)
	close.pressed.connect(set_panel_open.bind(false))
	var title := make_label("انتخاب مرحله و مأموریت")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	content.add_child(make_label("مرحله"))
	stage_picker = make_picker("StagePicker")
	content.add_child(stage_picker)
	for stage_number in range(1, GameContent.STAGES.size() + 1):
		stage_picker.add_item("مرحله %d: %s" % [stage_number, str(GameContent.get_stage(stage_number).get("title", ""))], stage_number)
	stage_picker.select(mini(1, stage_picker.item_count - 1))
	stage_picker.item_selected.connect(_on_stage_selected)

	content.add_child(make_label("مأموریت"))
	mission_picker = make_picker("MissionPicker")
	content.add_child(mission_picker)
	mission_picker.item_selected.connect(_on_mission_selected)
	availability_label = make_label("")
	availability_label.name = "Availability"
	content.add_child(availability_label)
	launch_button = make_button("اجرای مأموریت انتخاب‌شده")
	launch_button.name = "LaunchSelectedMission"
	content.add_child(launch_button)
	launch_button.pressed.connect(launch_selected_mission)
	refresh_mission_picker()
	mission_picker.select(mini(1, mission_picker.item_count - 1))
	refresh_availability()
	modal_center.hide()

	diagnostic_host = make_host(diagnostics_root.safe_margin, "DevelopmentMissionDiagnosticsHost")
	diagnostic_label = make_label("")
	diagnostic_label.name = "DevelopmentMissionDiagnostics"
	diagnostic_label.add_theme_font_size_override("font_size", 16)
	diagnostic_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	diagnostic_label.add_theme_constant_override("shadow_offset_x", 1)
	diagnostic_label.add_theme_constant_override("shadow_offset_y", 1)
	diagnostic_host.add_child(diagnostic_label)
	diagnostic_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	diagnostic_label.offset_bottom = 80
	diagnostic_host.resized.connect(update_diagnostics)

func make_host(parent: Node, node_name: String) -> Control:
	var host := Control.new()
	host.name = node_name
	host.layout_direction = Control.LAYOUT_DIRECTION_LTR
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(host)
	return host

func make_label(value: String) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	return label

func make_button(value: String) -> Button:
	var button := Button.new()
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.theme_type_variation = &"MobileButton"
	button.custom_minimum_size = Vector2(72, 72)
	button.text = value
	return button

func make_picker(node_name: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = node_name
	picker.layout_direction = Control.LAYOUT_DIRECTION_LTR
	picker.text_direction = Control.TEXT_DIRECTION_RTL
	picker.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	picker.theme_type_variation = &"MobileOptionButton"
	picker.fit_to_longest_item = false
	picker.clip_text = false
	picker.custom_minimum_size = Vector2(72, 72)
	var popup := picker.get_popup()
	# جهت ردیف‌های پنجرهٔ داخلی برای راست‌چین متن؛ بوم و Anchorها همچنان LTR.
	popup.set_layout_direction(Window.LAYOUT_DIRECTION_RTL)
	popup.theme = MobileUiRoot.UI_THEME
	popup.prefer_native_menu = false
	popup.about_to_popup.connect(_prepare_popup.bind(picker))
	return picker

func layout_controls() -> void:
	if not is_instance_valid(panel):
		return
	panel.custom_minimum_size = size.min(PANEL_MAX_SIZE)
	call_deferred("update_diagnostics")

func _on_safe_area_changed(_rect: Rect2) -> void:
	call_deferred("layout_controls")

func _prepare_popup(picker: OptionButton) -> void:
	var popup := picker.get_popup()
	var bounds := get_popup_bounds(popup)
	popup.max_size = Vector2i(bounds.size.floor())
	for index in popup.item_count:
		popup.set_item_text_direction(index, Control.TEXT_DIRECTION_RTL)
	call_deferred("_clamp_popup", popup)

func get_popup_bounds(popup: PopupMenu) -> Rect2:
	var rect := overlay_root.get_content_rect()
	if popup.is_embedded():
		return overlay_root.get_global_transform_with_canvas() * rect
	return overlay_root.get_screen_transform() * rect

func _clamp_popup(popup: PopupMenu) -> void:
	if not popup.visible:
		return
	var bounds := get_popup_bounds(popup)
	popup.size = popup.size.min(Vector2i(bounds.size.floor()))
	var maximum_position := bounds.end - Vector2(popup.size)
	popup.position = Vector2i(Vector2(popup.position).clamp(bounds.position, maximum_position).ceil())

func is_panel_open() -> bool:
	return is_instance_valid(modal_center) and modal_center.visible

func toggle_panel() -> void:
	set_panel_open(not is_panel_open())

func set_panel_open(is_open: bool) -> void:
	if is_open == is_panel_open():
		return
	if not is_open:
		stage_picker.get_popup().hide()
		mission_picker.get_popup().hide()
	modal_shade.visible = is_open
	modal_center.visible = is_open
	call_deferred("update_diagnostics")
	modal_visibility_changed.emit()

func set_available(is_available: bool) -> void:
	toggle.visible = is_available
	if not is_available:
		set_panel_open(false)

func _on_shade_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		set_panel_open(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_panel_open() and event.is_action_pressed("ui_cancel"):
		set_panel_open(false)
		get_viewport().set_input_as_handled()

func update_diagnostics() -> void:
	if not is_instance_valid(diagnostic_label):
		return
	diagnostic_label.offset_left = -minf(560, diagnostic_host.size.x)
	var stage_rect := stage_picker.get_global_rect()
	diagnostic_label.text = "پنل تست: %s | انتخاب مرحله: %d، %d\nناحیهٔ امن: %d × %d" % [
		"باز" if is_panel_open() else "بسته",
		roundi(stage_rect.position.x), roundi(stage_rect.position.y),
		roundi(overlay_root.safe_rect.size.x), roundi(overlay_root.safe_rect.size.y)
	]
	var layout_log := "DEV_SELECTOR_LAYOUT safe_source=%s safe=%s panel=%s stage=%s mission=%s launch=%s" % [
		overlay_root.safe_area_source, overlay_root.safe_rect, panel.get_global_rect(),
		stage_picker.get_global_rect(), mission_picker.get_global_rect(), launch_button.get_global_rect()
	]
	if layout_log != _last_layout_log:
		_last_layout_log = layout_log
		print(layout_log)

func _on_stage_selected(_index: int) -> void:
	refresh_mission_picker()

func _on_mission_selected(_index: int) -> void:
	refresh_availability()

func refresh_mission_picker() -> void:
	mission_picker.clear()
	for mission_number in range(1, ProgressStore.MISSIONS_PER_STAGE + 1):
		mission_picker.add_item("مأموریت %d: %s" % [mission_number, GameContent.get_mission_title(get_selected_stage(), mission_number)], mission_number)
	refresh_availability()

func refresh_availability() -> void:
	var is_available := FileAccess.file_exists(get_selected_mission_path())
	launch_button.disabled = not is_available
	availability_label.add_theme_color_override("font_color", Color("8bd8d2") if is_available else Color("f3b6a3"))
	availability_label.text = "دادهٔ این مأموریت آماده است." if is_available else "دادهٔ این مأموریت هنوز در پروژه وجود ندارد."

func launch_selected_mission() -> void:
	if launch_button.disabled:
		return
	set_panel_open(false)
	ProgressStore.begin_test_mission(get_selected_stage(), get_selected_mission())
	get_tree().change_scene_to_file(LEVEL_1_SCENE)

func get_selected_stage() -> int:
	return stage_picker.get_item_id(stage_picker.selected)

func get_selected_mission() -> int:
	return mission_picker.get_item_id(mission_picker.selected)

func get_selected_mission_path() -> String:
	return "res://data/levels/level%d_mission%d.json" % [get_selected_stage(), get_selected_mission()]
