extends CanvasLayer

signal hint_requested

const MENU_OVERLAY_SCENE := preload("res://components/global_menu.tscn")
const SETTINGS_PANEL_SCENE := preload("res://components/settings_panel.tscn")
const STAGE_PROGRESS_PANEL_SCENE := preload("res://components/stage_progress_panel.tscn")
const BADGES_PANEL_SCENE := preload("res://components/badges_panel.tscn")
const MAP_SCENE := "res://scenes/map.tscn"
const LEVEL_1_SCENE := "res://scenes/level1.tscn"

var menu_overlay: Control
var settings_panel: SettingsPanel
var stage_progress_panel: StageProgressPanel
var badges_panel: BadgesPanel
var hint_available := false
var return_to_map_after_badges := false

func _ready() -> void:
	layer = 20
	menu_overlay = MENU_OVERLAY_SCENE.instantiate()
	add_child(menu_overlay)
	menu_overlay.menu_action_requested.connect(_on_menu_action_requested)
	menu_overlay.hint_confirmed.connect(_on_hint_confirmed)
	settings_panel = SETTINGS_PANEL_SCENE.instantiate()
	add_child(settings_panel)
	stage_progress_panel = STAGE_PROGRESS_PANEL_SCENE.instantiate()
	stage_progress_panel.hide()
	add_child(stage_progress_panel)
	stage_progress_panel.closed.connect(_on_stage_progress_closed)
	badges_panel = BADGES_PANEL_SCENE.instantiate()
	add_child(badges_panel)
	badges_panel.closed.connect(_on_badges_panel_closed)
	stage_progress_panel.badges_requested.connect(_on_stage_badges_requested)
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("refresh_hint_availability")

func _on_menu_action_requested(action_id: String) -> void:
	if action_id == "settings":
		settings_panel.open_settings()
	elif action_id == "home":
		get_tree().change_scene_to_file(MAP_SCENE)
	elif action_id == "stage":
		open_stage_progress()
	elif action_id == "badges":
		open_badges()

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

func _on_scene_changed(_scene: Node) -> void:
	refresh_hint_availability()

func refresh_hint_availability() -> void:
	var current_scene := get_tree().current_scene
	var is_level_scene := current_scene != null and current_scene.scene_file_path.begins_with("res://scenes/level")
	set_hint_available(is_level_scene)

func set_hint_available(is_available: bool) -> void:
	hint_available = is_available
	if is_instance_valid(menu_overlay):
		menu_overlay.set_hint_available(hint_available)
