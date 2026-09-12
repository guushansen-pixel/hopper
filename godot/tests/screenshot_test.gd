extends SceneTree

const GameView = preload("res://scripts/game_view.gd")
const HopperSim = preload("res://scripts/hopper_sim.gd")

var view

func _init() -> void:
    view = GameView.new()
    root.add_child(view)
    view.bot_mode = true

func _process(_delta: float) -> bool:
    var f := Engine.get_process_frames()
    if f == 5:
        # Wueste-Frame mit sichtbaren Hindernissen erzwingen (statt auf
        # Zufalls-Spawn zu warten) - fuer eine verlaessliche Momentaufnahme.
        view.sim.obstacles = [
            {"kind": "cactus", "x": 300.0, "y": HopperSim.GROUND_Y - 36.0, "w": 34.0, "h": 36.0, "count": 2},
            {"kind": "bird", "x": 480.0, "y": HopperSim.GROUND_Y - 80.0, "w": 38.0, "h": 26.0},
        ]
    if f == 10:
        root.get_texture().get_image().save_png("res://tests/screenshot_desert.png")
        view.sim.cave_on = true
    if f == 15:
        # Hoehle: Kristall-Kaktus + Gift-Geschoss (beide Duck-Bahn und
        # Sprung-Bahn) + Tropfstein sichtbar erzwingen.
        view.sim.obstacles = [
            {"kind": "cactus", "x": 260.0, "y": HopperSim.GROUND_Y - 36.0, "w": 34.0, "h": 36.0, "count": 2},
            {"kind": "poison", "x": 420.0, "y": HopperSim.GROUND_Y - 54.0, "w": 16.0, "h": 16.0},
            {"kind": "stalactite", "x": 560.0, "y": 40.0, "w": 34.0, "h": 120.0},
        ]
    if f == 20:
        root.get_texture().get_image().save_png("res://tests/screenshot_cave.png")
    if f == 21:
        view._burst_dust(Vector2(150.0, HopperSim.GROUND_Y))
    if f == 24:
        root.get_texture().get_image().save_png("res://tests/screenshot_dust.png")
        quit()
        return true
    return false
