# Verbindet die reine Simulation (hopper_sim.gd) mit Rendering + echter
# Spielereingabe. Bewusst schlichte Formen/Farben statt Kunst. Bildschirm-
# Zustand (Menue/Pause/Game-Over/...) und Persistenz gehoeren NICHT hierher,
# sondern zu scripts/app.gd (Phase 6), das dieses Node2D als Kind haelt und
# ueber bot_mode/frozen/das "died"-Signal steuert - GameView weiss selbst
# nichts von Bildschirmen, genau wie hopper_sim.gd nichts vom Rendering weiss.
extends Node2D

const HopperSim = preload("res://scripts/hopper_sim.gd")

signal died
signal cleared   # Wueste bei CAVE_START erreicht (siehe hopper_sim.gd) - kein Tod

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

const Music = preload("res://scripts/music.gd")

var sim: HopperSim
var bot_mode := false
var frozen := false            # Pause (Phase 6, von app.gd gesetzt) - Sim haelt an, Rendering laeuft weiter
var touch_duck_held := false   # siehe _handle_input()/_input() - einzige Ducken-Quelle fuer Touch
var was_on_ground := true      # fuer Sprung-/Landestaub + Sprung-/Land-SFX, siehe _physics_process()
var was_ducking := false       # fuer Duck-SFX (nur auf der steigenden Flanke)
var last_score_hundred := 0    # fuer Punkte-SFX, wortgleich zu web/index.html: Sound bei jeder vollen 100er-Schwelle
var dust_particles: GPUParticles2D
var music: Music
var music_enabled_setting := true   # Phase 6: Save.settings.music, von app.gd gehalten

func _ready() -> void:
    sim = HopperSim.new()
    was_on_ground = sim.on_ground
    _setup_environment()
    _setup_dust_particles()
    music = Music.new()
    add_child(music)
    Sfx.cave_on = sim.cave_on

# ============================================================== Phase 4 ====
# HDR2D + WorldEnvironment-Glow - der eigentliche Grund fuer den Godot-
# Umstieg (siehe Plan/godot/README.md): Farben mit Kanalwerten > 1.0 (siehe
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
    if sim.dead or sim.cleared or frozen:
        return  # step() no-op bei dead/cleared/pausiert - app.gd entscheidet, was als naechstes passiert
    if bot_mode:
        sim.step(delta, true)
    else:
        _handle_input()
        sim.step(delta, false)

    # Sprung-/Landestaub + -SFX (Phase 4/5): Flankenerkennung ueber
    # on_ground, da hopper_sim.gd selbst keine Events feuert (bewusst
    # renderunabhaengig, siehe Kommentar dort - Audio gehoert wie Rendering
    # in die View-Schicht, nicht in die Sim).
    if was_on_ground and not sim.on_ground:
        _burst_dust(Vector2(HopperSim.RUNNER_X + 20.0, HopperSim.GROUND_Y))
        Sfx.jump()
    elif not was_on_ground and sim.on_ground:
        _burst_dust(Vector2(HopperSim.RUNNER_X + 20.0, HopperSim.GROUND_Y))
        Sfx.land()
    was_on_ground = sim.on_ground

    # Ducken-SFX nur auf der steigenden Flanke (nicht jeden Frame, solange
    # gehalten wird) - wortgleich zum Original (SFX.duck() nur beim Ansetzen).
    if sim.ducking and not was_ducking:
        Sfx.duck()
    was_ducking = sim.ducking

    # Punkte-SFX bei jeder vollen 100er-Schwelle, wortgleich zu
    # web/index.html ("Math.floor(score/100) > Math.floor(prev/100)").
    var cur_hundred := int(sim.score() / 100.0)
    if cur_hundred > last_score_hundred:
        Sfx.point()
    last_score_hundred = cur_hundred

    Sfx.cave_on = sim.cave_on

    # Musik nur bei echter Spielersteuerung (wie im Original: nicht im
    # Attract-/Bot-Modus) - einmalig starten/stoppen, nicht jeden Frame neu
    # (das wuerde den Sequencer-Schritt jedesmal auf 0 zuruecksetzen).
    var want_music := (not bot_mode) and music_enabled_setting
    if not want_music and music.enabled:
        music.stop()
    elif want_music and not music.enabled:
        music.start()

    if sim.dead:
        Sfx.die()
        died.emit()   # app.gd faengt das ab und zeigt den Game-Over-Bildschirm
    elif sim.cleared:
        cleared.emit()   # app.gd faengt das ab und zeigt "Level geschafft"

    queue_redraw()

# Startet einen frischen Lauf - von app.gd beim Druecken von "Spielen"
# aufgerufen (Menue-Level-Wahl uebergibt cave_on).
func start_new_run(cave: bool) -> void:
    sim.reset()
    sim.cave_on = cave
    Sfx.cave_on = cave
    was_on_ground = sim.on_ground
    was_ducking = sim.ducking
    last_score_hundred = 0
    touch_duck_held = false

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
# Kollisionsbox - siehe hopper/CHANGELOG.md "Kristall-Skin"): facettierter
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

# Garderobe (Phase 6, siehe Save.look/scripts/ui.gd): Farbe faerbt den
# Koerper, "shape" veraendert Ohren/Schwanz-Andeutung, "hat" zeichnet einen
# Hut auf den Kopf - bewusst schlicht (Formen, keine Kunst), aber alle drei
# Achsen aus web/index.html sind vertreten (3 Formen, 8 Farben, 5 Huete).
const LOOK_COLORS := {
    "auto": null, "terra": Color("#e4703a"), "teal": Color("#2a9d8f"),
    "violet": Color("#7c6bd9"), "amber": Color("#dfa22b"), "rose": Color("#dc5a78"),
    "green": Color("#4c9a5a"), "blue": Color("#4a90d9"),
}

func _draw_runner() -> void:
    var w: float = HopperSim.DUCK_W if sim.ducking else HopperSim.RUNNER_W
    var h: float = HopperSim.DUCK_H if sim.ducking else HopperSim.RUNNER_H
    var top := HopperSim.GROUND_Y - h + sim.runner_y
    # WICHTIG: LOOK_COLORS["auto"] ist absichtlich null (Variant) - eine
    # Color-typisierte Variable darf NIE null zugewiesen bekommen (Absturz),
    # deshalb hier zuerst untypisiert abholen und erst danach in Color casten.
    var body_color_raw = LOOK_COLORS.get(Save.look.get("color", "auto"), RUNNER_COLOR)
    var body_color: Color = body_color_raw if body_color_raw != null else RUNNER_COLOR
    draw_rect(Rect2(Vector2(HopperSim.RUNNER_X, top), Vector2(w, h)), body_color)

    if not sim.ducking:
        _draw_ears(String(Save.look.get("shape", "dog")), top, w, body_color)
    _draw_hat(String(Save.look.get("hat", "none")), top, w)

    # Auge, damit Blickrichtung/"vorne" erkennbar ist.
    draw_circle(Vector2(HopperSim.RUNNER_X + w - 8.0, top + 10.0), 3.0, INK)

func _draw_ears(shape: String, top: float, w: float, body_color: Color) -> void:
    var base := Vector2(HopperSim.RUNNER_X + w * 0.65, top)
    match shape:
        "cat":
            draw_colored_polygon(PackedVector2Array([
                base + Vector2(-6, 0), base + Vector2(-1, -12), base + Vector2(4, 0),
            ]), body_color)
            draw_colored_polygon(PackedVector2Array([
                base + Vector2(2, 0), base + Vector2(7, -12), base + Vector2(12, 0),
            ]), body_color)
        "bunny":
            draw_rect(Rect2(base + Vector2(-6, -22), Vector2(5, 22)), body_color)
            draw_rect(Rect2(base + Vector2(4, -22), Vector2(5, 22)), body_color)
        _:  # "dog" - Schlappohr
            draw_colored_polygon(PackedVector2Array([
                base + Vector2(-4, -2), base + Vector2(-10, -14), base + Vector2(-2, -10),
            ]), body_color)

func _draw_hat(hat: String, top: float, w: float) -> void:
    var hx := HopperSim.RUNNER_X + w * 0.25
    match hat:
        "cap":
            draw_rect(Rect2(Vector2(hx, top - 6.0), Vector2(w * 0.6, 6.0)), Color(0.2, 0.2, 0.25))
        "top":
            draw_rect(Rect2(Vector2(hx + 2.0, top - 16.0), Vector2(w * 0.4, 16.0)), Color(0.12, 0.12, 0.15))
            draw_rect(Rect2(Vector2(hx - 4.0, top - 2.0), Vector2(w * 0.5, 3.0)), Color(0.12, 0.12, 0.15))
        "band":
            draw_rect(Rect2(Vector2(hx, top + 2.0), Vector2(w * 0.6, 3.0)), Color(0.8, 0.2, 0.3))
        "goggles":
            draw_circle(Vector2(hx + 3.0, top + 8.0), 4.0, Color(0.6, 0.8, 0.9, 0.85))
            draw_circle(Vector2(hx + 12.0, top + 8.0), 4.0, Color(0.6, 0.8, 0.9, 0.85))
        _:
            pass  # "none"

# Wortgleich zu pctScore()/fmtScore() in web/index.html: in der Wueste
# Prozent-Fortschritt bis CAVE_START (Geometry-Dash-Stil), in der Hoehle
# roher, 5-stellig gepolsterter Punktestand.
static func fmt_score(raw: float, cave: bool) -> String:
    if cave:
        return "%05d" % int(raw)
    var pct: int = int(min(100.0, floor(raw / HopperSim.CAVE_START * 100.0)))
    return "%d%%" % pct

func _draw_hud() -> void:
    var f := ThemeDB.fallback_font
    var ink: Color = INK_ON_CAVE if sim.cave_on else INK
    var txt := fmt_score(sim.score(), sim.cave_on)
    draw_string(f, Vector2(16.0, 28.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
