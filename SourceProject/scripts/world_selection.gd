extends Control

const MAP_SCENE := "res://scenes/map.tscn"

@onready var title: Label = $Content/Title
@onready var subtitle: Label = $Content/Subtitle
@onready var girl_button: Button = $Content/Choices/GirlButton
@onready var boy_button: Button = $Content/Choices/BoyButton

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	$Content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	for control in [title, subtitle, girl_button, boy_button]:
		control.layout_direction = Control.LAYOUT_DIRECTION_LTR
		control.text_direction = Control.TEXT_DIRECTION_RTL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	girl_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	boy_button.alignment = HORIZONTAL_ALIGNMENT_CENTER

func _on_girl_pressed() -> void:
	select_world(GameSettings.World.GIRL)

func _on_boy_pressed() -> void:
	select_world(GameSettings.World.BOY)

func select_world(world: GameSettings.World) -> void:
	GameSettings.set_selected_world(world)
	get_tree().change_scene_to_file(MAP_SCENE)
