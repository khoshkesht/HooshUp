extends Node

const MAP_SCENE := "res://scenes/map.tscn"

func _ready() -> void:
	call_deferred("open_initial_scene")

func open_initial_scene() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
