# Phase 6: Bildschirm-/Menue-Zustandsmaschine, Garderobe, Einstellungen,
# Pause, Game-Over/Level-geschafft - das Godot-Aequivalent der DOM-Overlays
# in web/index.html (#menu/#wardrobe/#settings/#paused/#over). Haelt
# GameView (Phase 3+) als Kind und steuert es nur ueber dessen oeffentliche
# Schnittstelle (bot_mode/frozen/start_new_run()/die Signale died/cleared) -
# GameView selbst weiss nichts von Bildschirmen, hopper_sim.gd weiss nichts
# von beidem (siehe dortige Kommentare zur Schichtentrennung).
#
# UI wird per Code gebaut (keine .tscn-Handarbeit fuer Buttons/Label noetig)
# - bewusst schlicht (Standard-Theme, keine Kunst), Funktion vor Politur wie
# beim Rest dieser Migration bisher auch.
extends Node

const GameView = preload("res://scripts/game_view.gd")
const HopperSim = preload("res://scripts/hopper_sim.gd")

var game_view: GameView
var screen := "menu"
var selected_cave := false   # welches Level im Menue aktuell angezeigt/gewaehlt ist

var panels := {}     # screen-name -> Control (Wurzel des jeweiligen Bildschirms)
var labels := {}     # freier Text-Cache fuer dynamische Labels
var buttons := {}    # freier Button-Cache fuer dynamische Buttons
var checks := {}     # Einstellungen-Toggles

var _over_primary_cb: Callable = func(): pass

func _ready() -> void:
    game_view = GameView.new()
    add_child(game_view)
    game_view.bot_mode = true
    game_view.died.connect(_on_died)
    game_view.cleared.connect(_on_cleared)
    Sfx.sfx_enabled = bool(Save.settings.get("sfx", true))
    game_view.music_enabled_setting = bool(Save.settings.get("music", true))

    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)

    panels["menu"] = _build_menu(layer)
    panels["wardrobe"] = _build_wardrobe(layer)
    panels["settings"] = _build_settings(layer)
    panels["paused"] = _build_paused(layer)
    panels["over"] = _build_over(layer)

    _show("menu")

# ======================================================== Bildschirm-Wechsel
func _show(name: String) -> void:
    screen = name
    for k in panels.keys():
        panels[k].visible = (k == name)
    # "paused" muss den laufenden Zustand eingefroren LASSEN (auch wenn man
    # ueber Einstellungen zurueckkommt) - alle anderen Bildschirme laufen im
    # Bot-/Attract-Modus im Hintergrund weiter, nicht eingefroren.
    game_view.frozen = (name == "paused")
    game_view.bot_mode = (name != "game")
    if name == "menu":
        _refresh_menu()
    elif name == "settings":
        _refresh_settings()
    elif name == "paused":
        labels["paused_score"].text = GameView.fmt_score(game_view.sim.score(), game_view.sim.cave_on)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var ke := event as InputEventKey
        if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_P:
            if screen == "game":
                Sfx.ui()
                game_view.frozen = true
                _show("paused")
            elif screen == "paused":
                Sfx.ui()
                _resume()

func _resume() -> void:
    screen = "game"
    for k in panels.keys():
        panels[k].visible = false
    game_view.frozen = false
    game_view.bot_mode = false

func _play(cave: bool) -> void:
    Sfx.ui()
    game_view.start_new_run(cave)
    screen = "game"
    for k in panels.keys():
        panels[k].visible = false
    game_view.frozen = false
    game_view.bot_mode = false

func _on_died() -> void:
    var cave: bool = game_view.sim.cave_on
    var score: int = int(game_view.sim.score())
    var record: bool = Save.report_score(score, cave)
    _show_over(false, cave, score, record)

func _on_cleared() -> void:
    var score: int = int(game_view.sim.score())
    var record: bool = Save.report_score(score, false)
    Save.unlock_cave()
    _show_over(true, false, score, record)

func _show_over(is_cleared: bool, cave: bool, score: int, record: bool) -> void:
    labels["over_title"].text = "Level geschafft!" if is_cleared else "Game Over"
    var best: int = (Save.cave_highscore if cave else Save.highscore)
    labels["over_score"].text = "Punkte: %s" % GameView.fmt_score(float(score), cave)
    labels["over_best"].text = ("Neuer Rekord!" if record else "Bestwert: %s" % GameView.fmt_score(float(best), cave))
    if is_cleared:
        buttons["over_primary"].text = "Weiter zur Hoehle"
        _over_primary_cb = func(): _play(true)
    else:
        buttons["over_primary"].text = "Nochmal"
        _over_primary_cb = func(): _play(cave)
    screen = "over"
    for k in panels.keys():
        panels[k].visible = (k == "over")
    game_view.frozen = false
    game_view.bot_mode = true

# ================================================================== Menue ===
func _refresh_menu() -> void:
    var cave := selected_cave
    labels["menu_best"].text = "Bestwert\n%s" % GameView.fmt_score(float(Save.cave_highscore if cave else Save.highscore), cave)
    labels["menu_last"].text = "Zuletzt\n%s" % GameView.fmt_score(float(Save.cave_last if cave else Save.last_score), cave)
    buttons["menu_cave"].disabled = not Save.cave_unlocked
    buttons["menu_cave"].text = "Hoehle" if Save.cave_unlocked else "Hoehle (gesperrt)"
    buttons["menu_desert"].modulate = Color(1, 1, 1) if not cave else Color(0.7, 0.7, 0.7)
    buttons["menu_cave"].modulate = Color(1, 1, 1) if cave else Color(0.7, 0.7, 0.7)

func _build_menu(layer: CanvasLayer) -> Control:
    var root := _screen_root()
    layer.add_child(root)
    var box := _center_box(root)

    var title := Label.new()
    title.text = "Hopper"
    title.add_theme_font_size_override("font_size", 40)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var stats := HBoxContainer.new()
    stats.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(stats)
    var best := Label.new(); best.name = "menu_best"; best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var last := Label.new(); last.name = "menu_last"; last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    labels["menu_best"] = best
    labels["menu_last"] = last
    stats.add_child(best)
    var sep := Control.new(); sep.custom_minimum_size = Vector2(24, 0); stats.add_child(sep)
    stats.add_child(last)

    var levels := HBoxContainer.new()
    levels.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(levels)
    var b_desert := Button.new(); b_desert.text = "Wueste"; b_desert.custom_minimum_size = Vector2(120, 44)
    var b_cave := Button.new(); b_cave.text = "Hoehle"; b_cave.custom_minimum_size = Vector2(120, 44)
    buttons["menu_desert"] = b_desert
    buttons["menu_cave"] = b_cave
    b_desert.pressed.connect(func(): Sfx.ui(); selected_cave = false; _refresh_menu())
    b_cave.pressed.connect(func():
        if Save.cave_unlocked:
            Sfx.ui(); selected_cave = true; _refresh_menu()
    )
    levels.add_child(b_desert)
    levels.add_child(b_cave)

    var play_btn := Button.new()
    play_btn.text = "Spielen"
    play_btn.custom_minimum_size = Vector2(220, 56)
    play_btn.pressed.connect(func(): _play(selected_cave))
    box.add_child(play_btn)

    var wardrobe_btn := Button.new()
    wardrobe_btn.text = "Garderobe"
    wardrobe_btn.pressed.connect(func(): Sfx.ui(); _show("wardrobe"))
    box.add_child(wardrobe_btn)

    var settings_btn := Button.new()
    settings_btn.text = "Einstellungen"
    settings_btn.pressed.connect(func(): Sfx.ui(); _settings_from = "menu"; _show("settings"))
    box.add_child(settings_btn)

    var hint := Label.new()
    hint.text = "Leertaste/Tippen: springen (halten = hoeher) - Pfeil runter/unteres Drittel: ducken"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 12)
    hint.modulate = Color(1, 1, 1, 0.7)
    box.add_child(hint)

    return root

# =============================================================== Garderobe =
const SHAPES := ["dog", "cat", "bunny"]
const SHAPE_LABELS := {"dog": "Hund", "cat": "Katze", "bunny": "Hase"}
const COLOR_KEYS := ["auto", "terra", "teal", "violet", "amber", "rose", "green", "blue"]
const HATS := ["none", "cap", "top", "band", "goggles"]
const HAT_LABELS := {"none": "Kein Hut", "cap": "Muetze", "top": "Zylinder", "band": "Stirnband", "goggles": "Brille"}

func _build_wardrobe(layer: CanvasLayer) -> Control:
    var root := _screen_root()
    layer.add_child(root)
    var box := _center_box(root)

    var title := Label.new(); title.text = "Garderobe"; title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)

    var shape_row := HBoxContainer.new(); shape_row.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(shape_row)
    for shape in SHAPES:
        var b := Button.new()
        b.text = String(SHAPE_LABELS[shape])
        b.pressed.connect(func():
            Sfx.equip(); Save.look["shape"] = shape; Save.save_data()
        )
        shape_row.add_child(b)

    var color_grid := GridContainer.new(); color_grid.columns = 4
    box.add_child(color_grid)
    for key in COLOR_KEYS:
        var b := Button.new()
        b.custom_minimum_size = Vector2(48, 36)
        b.text = String(key)
        b.pressed.connect(func():
            Sfx.equip(); Save.look["color"] = key; Save.save_data()
        )
        color_grid.add_child(b)

    var hat_row := HBoxContainer.new(); hat_row.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(hat_row)
    for hat in HATS:
        var b := Button.new()
        b.text = String(HAT_LABELS[hat])
        b.pressed.connect(func():
            Sfx.equip(); Save.look["hat"] = hat; Save.save_data()
        )
        hat_row.add_child(b)

    var hint := Label.new()
    hint.text = "Aenderungen sind sofort im Hintergrund sichtbar."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.modulate = Color(1, 1, 1, 0.7)
    box.add_child(hint)

    var back := Button.new(); back.text = "Zurueck"
    back.pressed.connect(func(): Sfx.ui(); _show("menu"))
    box.add_child(back)

    return root

# ============================================================ Einstellungen
func _refresh_settings() -> void:
    checks["music"].button_pressed = bool(Save.settings.get("music", true))
    checks["sfx"].button_pressed = bool(Save.settings.get("sfx", true))

func _build_settings(layer: CanvasLayer) -> Control:
    var root := _screen_root()
    layer.add_child(root)
    var box := _center_box(root)

    var title := Label.new(); title.text = "Einstellungen"; title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)

    var c_music := CheckButton.new(); c_music.text = "Musik"
    c_music.toggled.connect(func(on: bool):
        Save.settings["music"] = on; Save.save_data()
        game_view.music_enabled_setting = on
        if not on:
            game_view.music.stop()
    )
    checks["music"] = c_music
    box.add_child(c_music)

    var c_sfx := CheckButton.new(); c_sfx.text = "Soundeffekte"
    c_sfx.toggled.connect(func(on: bool):
        Save.settings["sfx"] = on; Save.save_data()
        Sfx.sfx_enabled = on
    )
    checks["sfx"] = c_sfx
    box.add_child(c_sfx)

    var reset_btn := Button.new(); reset_btn.text = "Highscore zuruecksetzen"
    reset_btn.pressed.connect(func():
        Sfx.ui(); Save.reset_highscores(); _refresh_menu()
    )
    box.add_child(reset_btn)

    var back := Button.new(); back.text = "Zurueck"
    back.pressed.connect(func(): Sfx.ui(); _show(_settings_return_screen()))
    box.add_child(back)

    return root

# Von Menue ODER Pause aus erreichbar - "Zurueck" muss zum jeweils richtigen
# Bildschirm zurueckgehen, nicht immer zum Menue (Original: settingsFrom).
var _settings_from := "menu"
func _settings_return_screen() -> String:
    return _settings_from

# =================================================================== Pause =
func _build_paused(layer: CanvasLayer) -> Control:
    var root := _screen_root()
    layer.add_child(root)
    var box := _center_box(root)

    var title := Label.new(); title.text = "Pausiert"; title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)

    var score_label := Label.new(); score_label.name = "paused_score"
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    labels["paused_score"] = score_label
    box.add_child(score_label)

    var resume_btn := Button.new(); resume_btn.text = "Weiter"
    resume_btn.pressed.connect(func(): Sfx.ui(); _resume())
    box.add_child(resume_btn)

    var settings_btn := Button.new(); settings_btn.text = "Einstellungen"
    settings_btn.pressed.connect(func(): Sfx.ui(); _settings_from = "paused"; _show("settings"))
    box.add_child(settings_btn)

    var menu_btn := Button.new(); menu_btn.text = "Hauptmenue"
    menu_btn.pressed.connect(func(): Sfx.ui(); _show("menu"))
    box.add_child(menu_btn)

    return root

# ============================================================== Game Over ==
func _build_over(layer: CanvasLayer) -> Control:
    var root := _screen_root()
    layer.add_child(root)
    var box := _center_box(root)

    var title := Label.new(); title.name = "over_title"; title.add_theme_font_size_override("font_size", 32)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    labels["over_title"] = title
    box.add_child(title)

    var score_label := Label.new(); score_label.name = "over_score"
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    labels["over_score"] = score_label
    box.add_child(score_label)

    var best_label := Label.new(); best_label.name = "over_best"
    best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    labels["over_best"] = best_label
    box.add_child(best_label)

    var primary := Button.new()
    primary.custom_minimum_size = Vector2(220, 56)
    primary.pressed.connect(func(): _over_primary_cb.call())
    buttons["over_primary"] = primary
    box.add_child(primary)

    var menu_btn := Button.new(); menu_btn.text = "Hauptmenue"
    menu_btn.pressed.connect(func(): Sfx.ui(); _show("menu"))
    box.add_child(menu_btn)

    return root

# ============================================================= UI-Helfer ===
func _screen_root() -> Control:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.05, 0.07, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    return root

func _center_box(root: Control) -> VBoxContainer:
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.custom_minimum_size = Vector2(320, 0)
    panel.add_child(box)
    return box
