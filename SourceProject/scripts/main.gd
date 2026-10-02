extends Node

const WORLD_SELECTION_SCENE := "res://scenes/world_selection.tscn"
const MAP_SCENE := "res://scenes/map.tscn"

func _ready() -> void:
	call_deferred("open_initial_scene")

func open_initial_scene() -> void:
	var next_scene := MAP_SCENE if GameSettings.has_world_selection() else WORLD_SELECTION_SCENE
	get_tree().change_scene_to_file(next_scene)
