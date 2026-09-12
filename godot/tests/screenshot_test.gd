extends Node

const App = preload("res://scripts/app.gd")

var app

func _ready() -> void:
    app = App.new()
    add_child(app)

func _process(_delta: float) -> void:
    var f := Engine.get_process_frames()
    if f == 10:
        app._show("wardrobe")
    if f == 20:
        get_viewport().get_texture().get_image().save_png("res://tests/screenshot_wardrobe.png")
        # Etwas anziehen, damit die Garderobe sichtbar etwas veraendert.
        Save.look["shape"] = "cat"
        Save.look["color"] = "violet"
        Save.look["hat"] = "top"
    if f == 30:
        app._show("settings")
    if f == 40:
        get_viewport().get_texture().get_image().save_png("res://tests/screenshot_settings.png")
        app._play(false)
    if f == 100:
        get_viewport().get_texture().get_image().save_png("res://tests/screenshot_game.png")
        app.game_view.frozen = true
        app._show("paused")
    if f == 110:
        get_viewport().get_texture().get_image().save_png("res://tests/screenshot_paused.png")
        app._show_over(false, false, 1234, true)
    if f == 120:
        get_viewport().get_texture().get_image().save_png("res://tests/screenshot_over.png")
        get_tree().quit()
