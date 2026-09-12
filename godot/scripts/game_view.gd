# Phase 3: verbindet die reine Simulation (hopper_sim.gd) erstmals mit
# Rendering + echter Spielereingabe. Bewusst noch schlichte Formen/Farben
# statt Kunst - Grafik-Feinschliff (Glow/Partikel) ist Phase 4, Menues/
# Game-Over-UI sind eine spaetere Phase. Ziel hier: das erste tatsaechlich
# ANSPIELBARE Ding, mit korrekter Physik/Kollision (siehe hopper_sim.gd,
# in Phase 1+2 bereits per Kopflos-Soak verifiziert).
extends Node2D

const HopperSim = preload("res://scripts/hopper_sim.gd")

# Farbschema Wueste/Hoehle - vereinfachte Variante von CAVE_SKY_TOP/BOT/ROCK
# aus web/index.html (kein Tag/Nacht-Zyklus, das ist eine spaetere Phase).
const DESERT_SKY := Color(0.80, 0.86, 0.93)
const DESERT_GROUND := Color(0.82, 0.70, 0.48)
const DESERT_GROUND_LINE := Color(0.55, 0.42, 0.26)
const CAVE_SKY := Color(0.02, 0.024, 0.04)
const CAVE_GROUND := Color(0.29, 0.32, 0.36)
const CAVE_GROUND_LINE := Color(0.14, 0.16, 0.19)
const RUNNER_COLOR := Color(0.9, 0.35, 0.2)
const INK := Color(0.15, 0.15, 0.18)
const INK_ON_CAVE := Color(0.85, 0.87, 0.9)   # HUD-Text braucht auf dunklem Hoehlenhimmel hellen Kontrast

var sim: HopperSim
var bot_mode := false
var was_cave_on := false

func _ready() -> void:
    sim = HopperSim.new()
    was_cave_on = sim.cave_on

func _physics_process(delta: float) -> void:
    if sim.dead:
        return  # step() no-opt bei dead - Neustart uebernimmt _on_death_timeout()
    if bot_mode:
        sim.step(delta, true)
    else:
        _handle_input()
        sim.step(delta, false)

    # Wueste -> Hoehle: vereinfachter, sofortiger Uebergang (kein Cutscene-
    # Wipe/Torbogen wie im Original - das ist reine Optik, spaetere Phase).
    if not sim.cave_on and sim.score() >= HopperSim.CAVE_START:
        sim.cave_on = true

    if sim.dead:
        _on_death()

    queue_redraw()

func _on_death() -> void:
    await get_tree().create_timer(0.6).timeout
    var keep_cave := sim.cave_on
    sim.reset()
    sim.cave_on = keep_cave

# =============================================================== Eingabe ===
# Tastatur zuerst (Desktop-Test); Touch analog zum Original (unteres Drittel
# halten = ducken, sonst tippen = springen) folgt, sobald das auf einem
# echten Geraet getestet werden kann.
func _handle_input() -> void:
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        sim.set_ducking(true)
    else:
        sim.set_ducking(false)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var ke := event as InputEventKey
        if ke.keycode == KEY_SPACE or ke.keycode == KEY_UP or ke.keycode == KEY_W:
            if ke.pressed and not ke.echo:
                if not bot_mode:
                    sim.jump()
            elif not ke.pressed:
                if not bot_mode:
                    sim.end_jump()
        elif ke.keycode == KEY_B and ke.pressed and not ke.echo:
            bot_mode = not bot_mode

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed and not bot_mode:
            var h := get_viewport_rect().size.y
            if t.position.y > h * 0.66:
                sim.set_ducking(true)
            else:
                sim.jump()
        elif not t.pressed:
            sim.set_ducking(false)
            if not bot_mode:
                sim.end_jump()

# =============================================================== Rendering =
func _draw() -> void:
    var sky: Color = CAVE_SKY if sim.cave_on else DESERT_SKY
    var ground_col: Color = CAVE_GROUND if sim.cave_on else DESERT_GROUND
    var ground_line: Color = CAVE_GROUND_LINE if sim.cave_on else DESERT_GROUND_LINE
    var size := get_viewport_rect().size

    draw_rect(Rect2(Vector2.ZERO, size), sky)
    draw_rect(Rect2(Vector2(0.0, HopperSim.GROUND_Y), Vector2(size.x, size.y - HopperSim.GROUND_Y)), ground_col)
    draw_line(Vector2(0.0, HopperSim.GROUND_Y), Vector2(size.x, HopperSim.GROUND_Y), ground_line, 3.0)

    if sim.cave_on:
        _draw_ceiling()

    for o in sim.obstacles:
        _draw_obstacle(o)

    _draw_runner()
    _draw_hud()

func _draw_ceiling() -> void:
    var size := get_viewport_rect().size
    var points := PackedVector2Array()
    var step := 20.0
    var x := 0.0
    while x <= size.x:
        var gap: float = sim.ceiling_gap_at(sim.scroll_ceiling + x)
        points.append(Vector2(x, HopperSim.GROUND_Y - gap))
        x += step
    points.append(Vector2(size.x, 0.0))
    points.append(Vector2(0.0, 0.0))
    draw_colored_polygon(points, Color(0.16, 0.17, 0.20))

func _draw_obstacle(o: Dictionary) -> void:
    var x: float = o.x
    var y: float = o.y
    var w: float = o.w
    var h: float = o.h
    match String(o.kind):
        "cactus":
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.25, 0.55, 0.3))
        "bird":
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.35, 0.55, 0.85))
        "snake":
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.55, 0.4, 0.2))
        "poison":
            draw_circle(Vector2(x + w * 0.5, y + h * 0.5), w * 0.5, Color(0.22, 1.0, 0.42))
        "rock":
            draw_circle(Vector2(x + w * 0.5, y + h * 0.5), w * 0.5, Color(0.5, 0.5, 0.52))
        "stalactite":
            var tri := PackedVector2Array([
                Vector2(x, y), Vector2(x + w, y), Vector2(x + w * 0.5, y + h),
            ])
            draw_colored_polygon(tri, Color(0.42, 0.44, 0.48))
        "pillar":
            var tri2 := PackedVector2Array([
                Vector2(x, y), Vector2(x + w, y), Vector2(x + w * 0.5, y + h),
            ])
            draw_colored_polygon(tri2, Color(0.42, 0.44, 0.48))
        _:
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color.MAGENTA)  # unbekannt -> auffaellig

func _draw_runner() -> void:
    var w: float = HopperSim.DUCK_W if sim.ducking else HopperSim.RUNNER_W
    var h: float = HopperSim.DUCK_H if sim.ducking else HopperSim.RUNNER_H
    var top := HopperSim.GROUND_Y - h + sim.runner_y
    draw_rect(Rect2(Vector2(HopperSim.RUNNER_X, top), Vector2(w, h)), RUNNER_COLOR)
    # Auge, damit Blickrichtung/"vorne" erkennbar ist.
    draw_circle(Vector2(HopperSim.RUNNER_X + w - 8.0, top + 10.0), 3.0, INK)

func _draw_hud() -> void:
    var f := ThemeDB.fallback_font
    var ink: Color = INK_ON_CAVE if sim.cave_on else INK
    var txt := "%d" % int(sim.score())
    draw_string(f, Vector2(16.0, 28.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
    if bot_mode:
        draw_string(f, Vector2(16.0, 52.0), "BOT (B zum Umschalten)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
