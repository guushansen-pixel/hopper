# Kern-Simulation (Phase 1): Laeufer-Physik + EIN Hindernis (Kaktus) +
# hits()-Kollision + Autopilot ("Bot"), 1:1 aus web/index.html uebertragen.
#
# Bewusst als reine, von der Szene/vom Rendering unabhaengige Klasse gebaut -
# genau wie im Original autoPilot()/update() dieselben Funktionen sind, die
# sowohl im echten Spiel ALS AUCH im Soak-Test laufen (siehe tests/soak_test.gd),
# nicht zwei getrennte Implementierungen. Rendering/Szene kommt erst in
# Phase 3 dazu und ruft nur step() auf.
#
# Werte NICHT "ungefaehr" uebernommen, sondern wortgleich aus web/index.html
# (siehe dortige Kommentare zur empirischen Herleitung/Verifikation):
#   GRAV_UP/DOWN/FAST, JUMP_V, JUMP_CUT/_MIN, COYOTE_TIME, JUMP_BUFFER,
#   SPEED_START/MAX/RAMP, RUNNER_X, AIR_TIME, CAVE_START, hits()-Formel.
extends RefCounted
class_name HopperSim

const GRAV_UP := 2350.0
const GRAV_DOWN := 3500.0
const GRAV_FAST := 7200.0
const JUMP_V := -770.0
const JUMP_CUT := 0.45
const JUMP_CUT_MIN := -520.0
const COYOTE_TIME := 0.09
const JUMP_BUFFER := 0.13
const SPEED_START := 330.0
const SPEED_MAX := 960.0
const SPEED_RAMP := 15.0
const RUNNER_X := 70.0
const AIR_TIME := 0.58
const CAVE_START := 3000.0

const RUNNER_W := 44.0
const RUNNER_H := 47.0
const DUCK_W := 59.0
const DUCK_H := 30.0

# Referenzhoehe der Bodenlinie fuer die Simulation - der absolute Wert ist
# irrelevant (Phase 1 rendert nichts), nur die KONSISTENTE Verwendung bei
# Hindernis-Platzierung UND Kollision zaehlt (wie in web/index.html: alles
# relativ zu groundY).
const GROUND_Y := 600.0

# Logische Bildschirmbreite (Spawn-Kante) - entspricht dem in dieser Sitzung
# tatsaechlich am echten WebView-Build gemessenen LW-Wert (siehe README/Chat-
# Verlauf: LW=620 bei diesem Geraet/Viewport). Wird in Phase 3 durch die
# echte Godot-Viewport-Breite ersetzt.
const LW := 620.0

var runner_y := 0.0
var runner_vy := 0.0
var ducking := false
var on_ground := true
var coyote := COYOTE_TIME
var buffer := 0.0

var obstacles: Array = []   # Dictionaries: {kind, x, y, w, h, count}
var speed := SPEED_START
var score := 0.0             # Platzhalter fuer die Distanz - echtes Punkte-
                              # Modell (Punkt pro passiertem Hindernis) folgt
                              # in Phase 2 zusammen mit dem vollen Spawn-System.
var spawn_in := 90.0
var dead := false

var rng := RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
    if seed_value >= 0:
        rng.seed = seed_value
    reset()

func reset() -> void:
    runner_y = 0.0
    runner_vy = 0.0
    ducking = false
    on_ground = true
    coyote = COYOTE_TIME
    buffer = 0.0
    obstacles.clear()
    speed = SPEED_START
    score = 0.0
    spawn_in = 90.0
    dead = false

# ============================================================ Ein Tick =====
func step(dt: float, bot_mode: bool = true) -> void:
    if dead:
        return

    speed = min(SPEED_MAX, speed + SPEED_RAMP * dt)
    var dx := speed * dt
    score += dx

    if bot_mode:
        _bot_decide()

    # ------------------------------------------------------------ Spawn ----
    spawn_in -= dx
    if spawn_in <= 0.0:
        _spawn_cactus()
        spawn_in = _obstacle_gap()

    # ----------------------------------------------------- Laeufer-Physik --
    if on_ground:
        coyote = COYOTE_TIME
    elif coyote > 0.0:
        coyote -= dt
    if buffer > 0.0:
        buffer -= dt

    var g := GRAV_UP
    if runner_vy > 0.0:
        g = GRAV_FAST if ducking else GRAV_DOWN
    runner_vy += g * dt
    runner_y += runner_vy * dt

    if runner_y >= 0.0:
        var landing := not on_ground
        runner_y = 0.0
        on_ground = true
        coyote = COYOTE_TIME
        runner_vy = 0.0
        if buffer > 0.0 and not ducking:
            _do_jump()
        # "landing" nur fuer spaeter (Staubwolke/SFX in Phase 3) vorgemerkt -
        # in Phase 1 ohne Wirkung, absichtlich nicht weiter verdrahtet.
        var _unused_landing := landing

    # -------------------------------------------- Hindernisse bewegen/pruefen
    var i := obstacles.size() - 1
    while i >= 0:
        var o: Dictionary = obstacles[i]
        o.x -= dx
        if o.x + o.w < -20.0:
            obstacles.remove_at(i)
        elif _hits(o):
            dead = true
            return
        i -= 1

func _do_jump() -> void:
    runner_vy = JUMP_V
    on_ground = false
    coyote = 0.0
    buffer = 0.0

# =========================================================== Kollision =====
# Wortgleich zu hits(o) in web/index.html: pad=5 Inset auf die Laeufer-Box,
# PLUS 2px Toleranz direkt im AABB-Vergleich (zwei getrennte Toleranzen,
# keine Verwechslung).
func _hits(o: Dictionary) -> bool:
    var pad := 5.0
    var rw: float = DUCK_W if ducking else RUNNER_W
    var rh: float = DUCK_H if ducking else RUNNER_H
    var rx := RUNNER_X + pad
    var ry := GROUND_Y - rh + runner_y + pad
    rw -= pad * 2.0
    rh -= pad * 2.0
    return rx < o.x + o.w - 2.0 and rx + rw > o.x + 2.0 \
       and ry < o.y + o.h - 2.0 and ry + rh > o.y + 2.0

# =========================================================== Hindernis =====
func _spawn_cactus() -> void:
    var tall := rng.randf() < 0.45
    var max_count := 3 if score > 180.0 else 2
    var count := 1 + rng.randi_range(0, max_count - 1)
    var cw := 17.0 if tall else 15.0
    var ch := 50.0 if tall else 36.0
    var gap := 4.0
    var w := count * cw + (count - 1) * gap
    obstacles.append({
        "kind": "cactus", "x": LW + 20.0, "y": GROUND_Y - ch,
        "w": w, "h": ch, "count": count,
    })

func _obstacle_gap() -> float:
    var base := speed * 0.60
    base *= max(0.72, 1.0 - (score / CAVE_START) * 0.28)
    return base + rng.randf() * base * 0.80

# ============================================================== Autopilot ==
# Wortgleich zur Entscheidungslogik von autoPilot() in web/index.html - siehe
# dortigen Kommentar: reagiert pro Aufruf nur auf das jeweils NAECHSTE
# Hindernis, bricht danach ab. Fuer Phase 1 (nur Kaktus) ist "want" immer
# entweder "jump" oder "wait"/"none" - duck/bird/poison-Zweige kommen in
# Phase 2 dazu.
func _bot_decide() -> void:
    var want := "none"
    for o in obstacles:
        if o.x + o.w < RUNNER_X:
            continue
        var closing_speed: float = speed
        var t_contact: float = (float(o.x) - (RUNNER_X + 46.0)) / closing_speed
        var t_pass: float = (float(o.w) + 50.0) / closing_speed
        var t_trigger: float = max(0.05, (AIR_TIME - t_pass) / 2.0)
        if t_contact > t_trigger + 0.25:
            continue
        want = "jump"
        if want == "jump" and t_contact > t_trigger:
            want = "wait"
        break

    if want == "jump":
        ducking = false
        if coyote > 0.0:
            _do_jump()
    elif want == "duck":
        ducking = true
    elif want == "none":
        ducking = false
