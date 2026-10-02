class_name DragGestureHint
extends Control

const DRAG_ICON := preload("res://assets/pics/ui/drag.png")
const ICON_SIZE := Vector2(88, 88)

var drag_icon: TextureRect

static func show_once(parent: Control, hint_id: String) -> void:
	if not GameSettings.consume_drag_gesture_hint(hint_id):
		return
	var hint := DragGestureHint.new()
	parent.add_child(hint)
	hint.play()

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	modulate.a = 0.0
	drag_icon = TextureRect.new()
	drag_icon.layout_direction = Control.LAYOUT_DIRECTION_LTR
	drag_icon.texture = DRAG_ICON
	drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.size = ICON_SIZE
	add_child(drag_icon)

func play() -> void:
	await get_tree().process_frame
	var start_position := (size - drag_icon.size) * 0.5
	drag_icon.position = start_position
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(drag_icon, "position", start_position + Vector2(90, 0), 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(drag_icon, "position", start_position - Vector2(90, 0), 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(drag_icon, "position", start_position + Vector2(0, 75), 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.40)
	await tween.finished
	queue_free()
