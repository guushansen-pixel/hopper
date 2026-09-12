extends Node2D

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.16)
	bg.size = get_viewport_rect().size
	bg.z_index = -10
	add_child(bg)

	var label := Label.new()
	label.text = "Hopper - Godot Bootstrap OK"
	label.position = Vector2(40, 80)
	label.add_theme_font_size_override("font_size", 32)
	add_child(label)
