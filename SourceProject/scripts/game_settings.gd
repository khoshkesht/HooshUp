extends Node

signal settings_changed
signal background_music_changed(is_enabled: bool)

enum World { GIRL, BOY }

const SETTINGS_PATH := "user://settings.cfg"
const AVATAR_CONFIG_PATH := "res://data/avatars.json"
const GIRL_LEVELS_DIRECTORY := "g"
const BOY_LEVELS_DIRECTORY := "b"
const DEFAULT_GIRL_AVATAR_ID := 1
const DEFAULT_BOY_AVATAR_ID := 6
const AVATAR_IDS := [1, 2, 6, 7]

var selected_world: World = World.GIRL
var selected_avatar_id := DEFAULT_GIRL_AVATAR_ID
var world_has_been_selected := false
var player_name := "بازیکن"
var background_music_enabled := true
var avatar_configs: Dictionary = {}

func _ready() -> void:
	load_avatar_configs()
	load_settings()

func set_selected_world(world: World) -> void:
	selected_world = world
	selected_avatar_id = get_default_avatar_id(world)
	world_has_been_selected = true
	save_settings()
	settings_changed.emit()

func save_player_settings(new_player_name: String, avatar_id: int, music_enabled: bool) -> void:
	player_name = new_player_name.strip_edges()
	if player_name.is_empty():
		player_name = "بازیکن"
	selected_avatar_id = avatar_id if AVATAR_IDS.has(avatar_id) else DEFAULT_GIRL_AVATAR_ID
	selected_world = get_avatar_world(selected_avatar_id)
	world_has_been_selected = true
	background_music_enabled = music_enabled
	save_settings()
	settings_changed.emit()
	background_music_changed.emit(background_music_enabled)

func has_world_selection() -> bool:
	return world_has_been_selected

func get_levels_directory() -> String:
	return GIRL_LEVELS_DIRECTORY if selected_world == World.GIRL else BOY_LEVELS_DIRECTORY

func get_default_avatar_id(world: World) -> int:
	return DEFAULT_GIRL_AVATAR_ID if world == World.GIRL else DEFAULT_BOY_AVATAR_ID

func get_avatar_world(avatar_id: int) -> World:
	return World.GIRL if avatar_id == 1 or avatar_id == 2 else World.BOY

func get_level_directory(level_id: String) -> String:
	var directory := level_id.trim_prefix("level")
	return directory if directory.is_valid_int() else "1"

func get_level_asset_path(asset_name: String, level_id := "level1") -> String:
	return "res://assets/pics/levels/%s/%s/%s.png" % [get_levels_directory(), get_level_directory(level_id), asset_name]

func get_level_texture(asset_name: String, level_id := "level1") -> Texture2D:
	var path := get_level_asset_path(asset_name, level_id)
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Level image is missing: %s" % path)
	return texture

func get_avatar_asset_path(asset_name := "avatar") -> String:
	return "res://assets/pics/characters/%s/%d/%s.png" % [get_levels_directory(), selected_avatar_id, asset_name]

func get_avatar_texture(asset_name := "avatar") -> Texture2D:
	var path := get_avatar_asset_path(asset_name)
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Avatar image is missing: %s" % path)
	return texture

func get_avatar_idle_frame_offsets(sprite_sheet: String) -> Array:
	var avatar_config: Dictionary = avatar_configs.get(str(selected_avatar_id), {}) as Dictionary
	var offsets_by_sheet: Dictionary = avatar_config.get("idle_frame_offsets", {}) as Dictionary
	return offsets_by_sheet.get(sprite_sheet, []) as Array

func get_avatar_idle_frame_size(sprite_sheet: String) -> Array:
	var avatar_config: Dictionary = avatar_configs.get(str(selected_avatar_id), {}) as Dictionary
	var sizes_by_sheet: Dictionary = avatar_config.get("idle_frame_sizes", {}) as Dictionary
	return sizes_by_sheet.get(sprite_sheet, []) as Array

func load_avatar_configs() -> void:
	var file := FileAccess.open(AVATAR_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Avatar configuration is missing: %s" % AVATAR_CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		avatar_configs = parsed.get("avatars", {}) as Dictionary
	else:
		push_error("Avatar configuration is invalid: %s" % AVATAR_CONFIG_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_world := config.get_value("player", "world", "") as String
	if saved_world == "girl" or saved_world == "boy":
		selected_world = World.BOY if saved_world == "boy" else World.GIRL
		world_has_been_selected = true
	var saved_avatar_id := int(config.get_value("player", "avatar_id", 0))
	if AVATAR_IDS.has(saved_avatar_id):
		selected_avatar_id = saved_avatar_id
		selected_world = get_avatar_world(selected_avatar_id)
	elif world_has_been_selected:
		selected_avatar_id = get_default_avatar_id(selected_world)
	player_name = str(config.get_value("player", "name", player_name))
	background_music_enabled = bool(config.get_value("audio", "background_music_enabled", background_music_enabled))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "world", "girl" if selected_world == World.GIRL else "boy")
	config.set_value("player", "avatar_id", selected_avatar_id)
	config.set_value("player", "name", player_name)
	config.set_value("audio", "background_music_enabled", background_music_enabled)
	config.save(SETTINGS_PATH)
