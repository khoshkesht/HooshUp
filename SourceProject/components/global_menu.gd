extends Node

signal hint_requested

const MENU_OVERLAY_SCENE := preload("res://components/global_menu.tscn")
const SETTINGS_PANEL_SCENE := preload("res://components/settings_panel.tscn")
const STAGE_PROGRESS_PANEL_SCENE := preload("res://components/stage_progress_panel.tscn")
const BADGES_PANEL_SCENE := preload("res://components/badges_panel.tscn")
const DEVELOPMENT_MISSION_SELECTOR_SCRIPT := preload("res://components/development_mission_selector.gd")
const MAP_SCENE := "res://scenes/map.tscn"
const LEVEL_1_SCENE := "res://scenes/level1.tscn"

var menu_overlay: Control
var settings_panel: SettingsPanel
var stage_progress_panel: StageProgressPanel
var badges_panel: BadgesPanel
var hint_available := false
var return_to_map_after_badges := false
var toolbar_requested_visible := true
var hud_root: MobileUiRoot
var overlay_root: MobileUiRoot
var diagnostics_root: MobileUiRoot
var development_mission_selector: DevelopmentMissionSelector

func _ready() -> void:
	get_tree().root.gui_embed_subwindows = true
	hud_root = create_ui_layer("HUDLayer", "RootHUD", MobileUiRoot.HUD_LAYER)
	overlay_root = create_ui_layer("OverlayLayer", "OverlayRoot", MobileUiRoot.OVERLAY_LAYER)
	menu_overlay = MENU_OVERLAY_SCENE.instantiate()
	overlay_root.add_child(menu_overlay)
	# جای‌گذاری قدیمی تولبار در مرحلهٔ مهاجرت HUD بازسازی می‌شود.
	menu_overlay.toolbar.reparent(hud_root, false)
	menu_overlay.menu_action_requested.connect(_on_menu_action_requested)
	menu_overlay.hint_confirmed.connect(_on_hint_confirmed)
	settings_panel = SETTINGS_PANEL_SCENE.instantiate()
	overlay_root.add_child(settings_panel)
	settings_panel.visibility_changed.connect(refresh_gameplay_ui_visibility)
	stage_progress_panel = STAGE_PROGRESS_PANEL_SCENE.instantiate()
	stage_progress_panel.hide()
	overlay_root.add_child(stage_progress_panel)
	stage_progress_panel.visibility_changed.connect(refresh_gameplay_ui_visibility)
	stage_progress_panel.closed.connect(_on_stage_progress_closed)
	badges_panel = BADGES_PANEL_SCENE.instantiate()
	overlay_root.add_child(badges_panel)
	badges_panel.visibility_changed.connect(refresh_gameplay_ui_visibility)
	badges_panel.closed.connect(_on_badges_panel_closed)
	stage_progress_panel.badges_requested.connect(_on_stage_badges_requested)
	# DEVELOPMENT ONLY: remove this block and development_mission_selector.gd before release.
	if OS.is_debug_build():
		diagnostics_root = create_ui_layer("DiagnosticsLayer", "DiagnosticsRoot", MobileUiRoot.DIAGNOSTICS_LAYER)
		development_mission_selector = DEVELOPMENT_MISSION_SELECTOR_SCRIPT.new() as DevelopmentMissionSelector
		development_mission_selector.hud_root = hud_root
		development_mission_selector.overlay_root = overlay_root
		development_mission_selector.diagnostics_root = diagnostics_root
		overlay_root.safe_margin.add_child(development_mission_selector)
		development_mission_selector.modal_visibility_changed.connect(refresh_gameplay_ui_visibility)
	for overlay in [menu_overlay.menu_panel, menu_overlay.exit_confirmation, menu_overlay.hint_confirmation]:
		overlay.visibility_changed.connect(refresh_gameplay_ui_visibility)
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("refresh_hint_availability")

func create_ui_layer(layer_name: String, root_name: String, layer_number: int) -> MobileUiRoot:
	var canvas := CanvasLayer.new()
	canvas.name = layer_name
	canvas.layer = layer_number
	add_child(canvas)
	var ui_root := MobileUiRoot.new()
	ui_root.name = root_name
	canvas.add_child(ui_root)
	return ui_root

func _on_menu_action_requested(action_id: String) -> void:
	if action_id == "settings":
		settings_panel.open_settings()
	elif action_id == "home":
		get_tree().change_scene_to_file(MAP_SCENE)
	elif action_id == "stage":
		open_stage_progress()
	elif action_id == "badges":
		open_badges()

func open_initial_player_setup() -> void:
	settings_panel.open_settings(true)

func open_badges(return_to_map_on_close := false) -> void:
	return_to_map_after_badges = return_to_map_on_close
	badges_panel.open_badges()

func _on_badges_panel_closed() -> void:
	if not return_to_map_after_badges:
		return
	return_to_map_after_badges = false
	get_tree().change_scene_to_file(MAP_SCENE)

func _on_hint_confirmed() -> void:
	hint_requested.emit()

func open_stage_progress() -> void:
	set_hint_available(false)
	var active_mission := ProgressStore.get_active_mission()
	var stage_number := active_mission.x
	stage_progress_panel.show()
	stage_progress_panel.show_stage(stage_number, ProgressStore.get_completed_missions(stage_number))

func _on_stage_progress_closed(next_stage: int, next_mission: int) -> void:
	stage_progress_panel.hide()
	refresh_hint_availability()
	ProgressStore.set_active_mission(next_stage, next_mission)
	if next_stage == 1:
		get_tree().change_scene_to_file(LEVEL_1_SCENE)
	else:
		get_tree().change_scene_to_file(MAP_SCENE)

func _on_stage_badges_requested() -> void:
	stage_progress_panel.hide()
	open_badges(true)

func _on_scene_changed() -> void:
	toolbar_requested_visible = true
	refresh_hint_availability()

func refresh_hint_availability() -> void:
	var current_scene := get_tree().current_scene
	var is_level_scene := current_scene != null and current_scene.scene_file_path.begins_with("res://scenes/level")
	set_hint_available(is_level_scene)
	refresh_gameplay_ui_visibility()

func set_hint_available(is_available: bool) -> void:
	hint_available = is_available
	if is_instance_valid(menu_overlay):
		menu_overlay.set_hint_available(hint_available)

func set_toolbar_visible(is_visible: bool) -> void:
	toolbar_requested_visible = is_visible
	refresh_gameplay_ui_visibility()

func toggle_menu() -> void:
	if is_instance_valid(menu_overlay):
		menu_overlay.toggle_menu()

func refresh_gameplay_ui_visibility() -> void:
	if not is_instance_valid(menu_overlay):
		return
	var current_scene := get_tree().current_scene
	var is_level_scene := current_scene != null and current_scene.scene_file_path.begins_with("res://scenes/level")
	var legacy_modal_is_open: bool = (
		(is_instance_valid(settings_panel) and settings_panel.visible)
		or (is_instance_valid(stage_progress_panel) and stage_progress_panel.visible)
		or (is_instance_valid(badges_panel) and badges_panel.visible)
		or menu_overlay.menu_panel.visible
		or menu_overlay.exit_confirmation.visible
		or (is_instance_valid(menu_overlay.hint_confirmation) and menu_overlay.hint_confirmation.visible)
	)
	var selector_is_open := false
	if is_instance_valid(development_mission_selector):
		development_mission_selector.set_available(not legacy_modal_is_open)
		selector_is_open = development_mission_selector.is_panel_open()
	var modal_is_open: bool = legacy_modal_is_open or selector_is_open
	menu_overlay.set_gameplay_available(is_level_scene and toolbar_requested_visible and not modal_is_open)
