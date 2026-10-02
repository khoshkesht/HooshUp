extends Control

@onready var level_image: TextureRect = $PanZoomViewport/World/LevelImage
@onready var hotspot_feedback: Label = $HotspotFeedback

func _ready() -> void:
	level_image.texture = GameSettings.get_level_texture("l1-0")

func _on_monitor_hotspot_activated() -> void:
	hotspot_feedback.show()
