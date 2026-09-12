extends SceneTree

const GameView = preload("res://scripts/game_view.gd")

var view

func _init() -> void:
    view = GameView.new()
    root.add_child(view)
    view.bot_mode = true

func _process(_delta: float) -> bool:
    var f := Engine.get_process_frames()
    if f == 200:
        root.get_texture().get_image().save_png("res://tests/screenshot_desert.png")
    if f == 201:
        view.sim.cave_on = true
    if f == 500:
        root.get_texture().get_image().save_png("res://tests/screenshot_cave.png")
        quit()
        return true
    return false
