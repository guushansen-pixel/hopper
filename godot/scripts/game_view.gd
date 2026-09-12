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
var touch_duck_held := false   # siehe _handle_input()/_input() - einzige Ducken-Quelle fuer Touch
var was_on_ground := true      # fuer Sprung-/Landestaub, siehe _physics_process()
var dust_particles: GPUParticles2D

func _ready() -> void:
    sim = HopperSim.new()
    was_on_ground = sim.on_ground
    _setup_environment()
    _setup_dust_particles()

# ============================================================== Phase 4 ====
# HDR2D + WorldEnvironment-Glow - der eigentliche Grund fuer den Godot-
# Umstieg (siehe Plan/README): Farben mit Kanalwerten > 1.0 (siehe
# _draw_poison()/_draw_crystal()) leuchten damit sichtbar, statt bei 1.0
# geclamped zu werden. "viewport/hdr_2d=true" muss zusaetzlich in
# project.godot gesetzt sein, sonst hat HDR-Farbe keine Wirkung.
func _setup_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_CANVAS
    env.glow_enabled = true
    env.glow_intensity = 1.1
    env.glow_strength = 1.2
    env.glow_bloom = 0.18
    env.glow_hdr_threshold = 1.0
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

# Ein einziger, wiederverwendeter Partikel-Knoten fuer Sprung-/Landestaub
# (siehe _burst_dust()) - echtes GPUParticles2D statt selbst gemaltem
# Behelf, wo es sich anbietet (viele kleine, kurzlebige Punkte). Der
# Gift-Glow/Kristall-Glow dagegen bleibt bewusst _draw()-basiert (siehe
# _draw_poison()/_draw_crystal()): dort ist die Form pro Hindernis fix und
# an dessen Position/Groesse gebunden, ein eigener Partikel-Knoten pro
# Hindernis waere unnoetiger Verwaltungsaufwand fuer denselben visuellen
# Effekt (HDR-Glow-Halo).
func _setup_dust_particles() -> void:
    dust_particles = GPUParticles2D.new()
    dust_particles.amount = 14
    dust_particles.lifetime = 0.45
    dust_particles.one_shot = true
    dust_particles.explosiveness = 0.85
    dust_particles.emitting = false
    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0.0, -1.0, 0.0)
    mat.spread = 65.0
    mat.initial_velocity_min = 40.0
    mat.initial_velocity_max = 100.0
    mat.gravity = Vector3(0.0, 260.0, 0.0)
    mat.scale_min = 1.5
    mat.scale_max = 3.2
    mat.color = Color(0.55, 0.47, 0.35, 0.75)
    dust_particles.process_material = mat
    dust_particles.texture = _make_dot_texture()
    add_child(dust_particles)

func _make_dot_texture() -> ImageTexture:
    var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
    img.fill(Color(1.0, 1.0, 1.0, 1.0))
    return ImageTexture.create_from_image(img)

func _burst_dust(pos: Vector2) -> void:
    dust_particles.position = pos
    dust_particles.restart()
    dust_particles.emitting = true

func _physics_process(delta: float) -> void:
    if sim.dead:
        return  # step() no-opt bei dead - Neustart uebernimmt _on_death_timeout()
    if bot_mode:
        sim.step(delta, true)
    else:
        _handle_input()
        sim.step(delta, false)

    # Sprung-/Landestaub (Phase 4): Flankenerkennung ueber on_ground, da
    # hopper_sim.gd selbst keine Events feuert (bewusst renderunabhaengig,
    # siehe Kommentar dort).
    if was_on_ground and not sim.on_ground:
        _burst_dust(Vector2(HopperSim.RUNNER_X + 20.0, HopperSim.GROUND_Y))
    elif not was_on_ground and sim.on_ground:
        _burst_dust(Vector2(HopperSim.RUNNER_X + 20.0, HopperSim.GROUND_Y))
    was_on_ground = sim.on_ground

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
# Ducken hat ZWEI Quellen (Tastatur, dauerhaft abgefragt; Touch, per Event in
# touch_duck_held gemerkt - siehe _input()) - deshalb hier EINZIGE Stelle,
# die sim.ducking tatsaechlich setzt (als ODER beider Quellen), einmal pro
# Physik-Frame. BUG gefunden (Feedback: "ducken funktioniert auf dem handy
# nicht"): diese Funktion rief vorher IMMER sim.set_ducking(false), sobald
# keine Taste gedrueckt war - das ueberschrieb touch_duck_held aus _input()
# im naechsten Frame sofort wieder, ganz gleich ob der Finger noch unten
# gehalten wurde (ScreenTouch-Events feuern nur einmal bei Druck/Loslassen,
# nicht laufend waehrend des Haltens).
func _handle_input() -> void:
    var kb_duck := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
    sim.set_ducking(kb_duck or touch_duck_held)

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
                touch_duck_held = true
            else:
                touch_duck_held = false
                sim.jump()
        elif not t.pressed:
            touch_duck_held = false
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
            if sim.cave_on:
                _draw_crystal(x, y, w, h)
            else:
                draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.25, 0.55, 0.3))
        "bird":
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.35, 0.55, 0.85))
        "snake":
            draw_rect(Rect2(Vector2(x, y), Vector2(w, h)), Color(0.55, 0.4, 0.2))
        "poison":
            _draw_poison(x, y, w, h)
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

# Neongruener Glow-Halo (mehrere weiche, ueberlagerte HDR-Kreise) + Kometen-
# schweif nach hinten (rechts, da nach links geflogen wird) + heller Kern -
# entspricht dem Original-Design (siehe web/index.html drawPoison()), aber
# mit echtem HDR-Bloom statt eines gemalten radialen Gradienten. Kanalwerte
# > 1.0 sind hier der Punkt: die loesen den in _setup_environment()
# aktivierten Glow tatsaechlich aus.
func _draw_poison(x: float, y: float, w: float, h: float) -> void:
    var c := Vector2(x + w * 0.5, y + h * 0.5)
    for i in range(4, 0, -1):
        var r: float = w * (0.5 + i * 0.35)
        draw_circle(c, r, Color(0.3, 3.0, 0.9, 0.10 / i))
    var tail := PackedVector2Array([
        c + Vector2(w * 0.3, -h * 0.28), c + Vector2(w * 1.6, 0.0), c + Vector2(w * 0.3, h * 0.28),
    ])
    draw_colored_polygon(tail, Color(0.15, 1.2, 0.4, 0.55))
    draw_circle(c, w * 0.5, Color(0.4, 3.5, 1.0))
    draw_circle(c - Vector2(w * 0.12, h * 0.12), w * 0.14, Color(1.6, 3.5, 2.0))

# Kristall-Reskin des Kaktus in der Hoehle (rein optisch, dieselbe
# Kollisionsbox - siehe web/README.md "Kristall-Skin"): facettierter
# Diamant mit HDR-Glow statt der flachen gruenen Wueste-Box.
func _draw_crystal(x: float, y: float, w: float, h: float) -> void:
    var cx := x + w * 0.5
    for i in range(3, 0, -1):
        draw_circle(Vector2(cx, y + h * 0.65), w * (0.5 + i * 0.3), Color(0.3, 0.5, 1.8, 0.07))
    var body := PackedVector2Array([
        Vector2(cx, y), Vector2(x + w, y + h * 0.55), Vector2(x + w * 0.7, y + h),
        Vector2(x + w * 0.3, y + h), Vector2(x, y + h * 0.55),
    ])
    draw_colored_polygon(body, Color(0.4, 0.7, 2.6))
    draw_line(Vector2(cx, y), Vector2(cx, y + h), Color(1.0, 1.4, 3.0, 0.8), 1.5)

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
