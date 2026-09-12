# Kern-Simulation: Laeufer-Physik + Hindernisse + hits()-Kollision +
# Autopilot ("Bot"), 1:1 aus web/index.html uebertragen.
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
#   SPEED_START/MAX/RAMP, RUNNER_X, AIR_TIME, CAVE_START, hits()-Formel,
#   BIRD/SNAKE/POISON_START/RAMP/TARGET, ROLL_ACCEL, MAX_ROLL_BONUS,
#   MOUNTAIN_LEN/GAP_MIN/GAP_RAND, CAVE_MIN/MAX_GAP, CAVE_WAVELEN,
#   STALACTITE/PILLAR_TIP_MIN/MAX, POISON_EXTRA, das Gift-Kopplungs-
#   Zwangsabstand (600-750, siehe web/README.md "Gift sichtbar an
#   Schlangen gekoppelt").
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

const BIRD_START := 120.0
const BIRD_RAMP := 280.0
const BIRD_TARGET := 0.22
const SNAKE_START := 380.0
const SNAKE_RAMP := 320.0
const SNAKE_TARGET := 0.20
const POISON_START := 520.0
const POISON_RAMP := 340.0
const POISON_TARGET := 0.13
# Siehe web/README.md ("Gift sichtbar an Schlangen gekoppelt", 1.30): 260-430
# liess den Autopiloten das Gift bei hohem Tempo verpassen (reagiert pro
# Frame nur auf das naechste Hindernis - der Sprung-Trigger der Schlange lag
# zeitlich zu nah am Duck/Sprung-Trigger des Gifts). 600-750 gab 0 Treffer in
# ueber 60 simulierten Minuten, unabhaengig vom Tempo (Abstand/Tempo ist
# tempounabhaengig, wenn beide dieselbe Schliessgeschwindigkeit haben).
const POISON_GAP_MIN := 600.0
const POISON_GAP_SPREAD := 150.0
const POISON_EXTRA := 0.0   # bewusst 0 - siehe web/index.html-Kommentar

const ROLL_ACCEL := 55.0
const MAX_ROLL_BONUS := 220.0

const MOUNTAIN_LEN := 12.0
const MOUNTAIN_GAP_MIN := 500.0
const MOUNTAIN_GAP_RAND := 400.0

const CAVE_MIN_GAP := 158.0
const CAVE_MAX_GAP := 210.0
const CAVE_WAVELEN := 3200.0
const STALACTITE_TIP_MIN := 65.0
const STALACTITE_TIP_MAX := 105.0
const PILLAR_TIP_MIN := 26.0
const PILLAR_TIP_MAX := 36.0

# Referenzhoehe der Bodenlinie fuer die Simulation - der absolute Wert ist
# irrelevant (Phase 1/2 rendern nichts), nur die KONSISTENTE Verwendung bei
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

var obstacles: Array = []   # Dictionaries, Feld "kind" bestimmt die uebrigen

# WICHTIG (Phase-2-Korrektur): "distance" ist der rohe, kontinuierlich
# akkumulierte Weg (state.distance in web/index.html: `distance += speed*dt`).
# "score" - die Groesse, gegen die ALLE Schwellenwerte (BIRD/SNAKE/POISON_START,
# CAVE_START, obstacleGap()-Dichtefaktor, Kaktus-Anzahl) tatsaechlich
# verglichen werden - ist NICHT dasselbe: `score = floor(distance/14) + bonus`
# (siehe web/index.html Zeile ~1197). Phase 1 hatte das uebersehen und
# "score" faelschlich = raw distance gesetzt - das liess z.B. CAVE_START=3000
# nach Sekunden statt nach einem ganzen Level erreicht wirken. Jetzt korrekt:
# distance ist der gespeicherte Zustand, score() ist abgeleitet.
var distance := 0.0
var bonus := 0.0

func score() -> float:
    return floor(distance / 14.0) + bonus

var speed := SPEED_START
var spawn_in := 90.0
var dead := false
# Wueste (cave_on=false) endet bei CAVE_START mit "geschafft", nicht mit dem
# Tod - wortgleiches Prinzip zu completeLevel() in web/index.html. Wird wie
# "dead" behandelt (step() haelt an), app.gd (Phase 6) reagiert auf beide
# Signale unterschiedlich (Game-Over-Bildschirm vs. "Level geschafft" mit
# Uebergang in einen NEUEN Hoehlen-Lauf statt nahtlosem Weiterspielen).
var cleared := false

var cave_on := false          # von app.gd beim Start eines Laufs gesetzt
var mountain_on := false
var mountain_t := 0.0
var next_mountain_at := 0.0
var poison_queued := false
var scroll_ceiling := 0.0     # fuer ceiling_gap_at(), wie state.scrollCeiling

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
    distance = 0.0
    bonus = 0.0
    speed = SPEED_START
    spawn_in = 90.0
    dead = false
    cleared = false
    mountain_on = false
    mountain_t = 0.0
    next_mountain_at = 700.0 + rng.randf() * 200.0
    poison_queued = false
    scroll_ceiling = 0.0
    # cave_on bleibt unveraendert - Aufrufer (Test/Szene) setzt es explizit,
    # reset() ist ein Neustart INNERHALB desselben Levels, kein Level-Wechsel.

# ============================================================ Ein Tick =====
func step(dt: float, bot_mode: bool = true) -> void:
    if dead or cleared:
        return

    speed = min(SPEED_MAX, speed + SPEED_RAMP * dt)
    var dx := speed * dt
    distance += dx
    scroll_ceiling += dx

    # Wueste -> "Level geschafft" (kein Tod, kein nahtloser Uebergang - siehe
    # Kommentar bei "cleared" oben). Bewusst VOR dem Rest des Ticks geprueft,
    # damit ein Frame, der die Schwelle ueberschreitet, keine weiteren
    # Hindernisse mehr spawnt/bewegt.
    if not cave_on and score() >= CAVE_START:
        cleared = true
        return

    # ------------------------------------------------- Bergabschnitte -------
    if mountain_on:
        mountain_t += dt
        if mountain_t >= MOUNTAIN_LEN:
            mountain_on = false
            next_mountain_at = score() + _next_mountain_gap()
    elif not cave_on and score() >= next_mountain_at:
        mountain_on = true
        mountain_t = 0.0

    if bot_mode:
        _bot_decide()

    # ------------------------------------------------------------ Spawn ----
    spawn_in -= dx
    if spawn_in <= 0.0:
        var forced := _spawn_obstacle()
        spawn_in = forced if forced >= 0.0 else _obstacle_gap()

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
        runner_y = 0.0
        on_ground = true
        coyote = COYOTE_TIME
        runner_vy = 0.0
        if buffer > 0.0 and not ducking:
            _do_jump()

    # -------------------------------------------- Hindernisse bewegen/pruefen
    var i := obstacles.size() - 1
    while i >= 0:
        var o: Dictionary = obstacles[i]
        var extra := 0.0
        if o.kind == "rock":
            o.roll_extra = min(MAX_ROLL_BONUS, float(o.roll_extra) + ROLL_ACCEL * dt)
            extra = o.roll_extra
        elif o.kind == "poison":
            extra = POISON_EXTRA
        o.x -= dx + extra * dt
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

# ==================================================== Oeffentliche Eingabe ==
# Fuer Phase 3 (echte Spielersteuerung, siehe scripts/game_view.gd) - wie
# jump()/endJump()/setDuck() in web/index.html. Der Bot (_bot_decide()) ruft
# stattdessen _do_jump() direkt und setzt "ducking" direkt, weil er (wie das
# Original) IMMER den vollen Sprung macht, nie JUMP_CUT auf sich anwendet.
func jump() -> void:
    if coyote > 0.0:
        _do_jump()
    else:
        buffer = JUMP_BUFFER

func end_jump() -> void:
    if runner_vy < 0.0:
        runner_vy = max(runner_vy, min(runner_vy * JUMP_CUT, JUMP_CUT_MIN))

func set_ducking(on: bool) -> void:
    ducking = on

func _next_mountain_gap() -> float:
    # min()/max() geben statisch Variant zurueck (generische Builtins) -
    # deshalb hier explizit `: float =` statt `:=`, sonst derselbe
    # Parse-Fehler wie an anderer Stelle in dieser Datei (siehe Kommentar
    # oben bei _bot_decide()).
    var scale: float = (speed / SPEED_START) * (1.0 + min(1.2, score() / 2500.0))
    return (MOUNTAIN_GAP_MIN + rng.randf() * MOUNTAIN_GAP_RAND) * scale

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

# ==================================================== Ramp-Wahrscheinlichkeit
# Wortgleich zu rampChance() in web/index.html: 0 unterhalb start, linear bis
# target ueber "len" Score-Punkte, danach konstant target.
func _ramp_chance(start: float, len: float, target: float) -> float:
    var s := score()
    if s < start:
        return 0.0
    if s >= start + len:
        return target
    return target * (s - start) / len

# =========================================================== Hindernis-Dispatcher
# Prioritaetsreihenfolge wortgleich zu spawnObstacle() in web/index.html.
# Rueckgabe: erzwungener naechster Abstand (>=0), oder -1.0 fuer "normale
# obstacleGap() verwenden" - dieselbe "Forced-Gap"-Konvention wie im Original
# (dort per Funktions-Rueckgabewert statt eines Sentinels, hier -1.0 als
# Sentinel, weil GDScript keinen "kein Rueckgabewert"-Fall ohne das hat).
func _spawn_obstacle() -> float:
    if mountain_on:
        _spawn_rock()
        return -1.0
    if poison_queued:
        poison_queued = false
        _spawn_poison()
        return -1.0
    if cave_on:
        var cr0 := rng.randf()
        if cr0 < 0.34:
            return _spawn_stalactite()
        if cr0 < 0.44:
            return _spawn_pillar()
    if rng.randf() < _ramp_chance(BIRD_START, BIRD_RAMP, BIRD_TARGET):
        _spawn_bird()
        return -1.0
    if rng.randf() < _ramp_chance(SNAKE_START, SNAKE_RAMP, SNAKE_TARGET):
        _spawn_snake()
        if rng.randf() < _ramp_chance(POISON_START, POISON_RAMP, POISON_TARGET):
            poison_queued = true
            return POISON_GAP_MIN + rng.randf() * POISON_GAP_SPREAD
        return -1.0
    _spawn_cactus()
    return -1.0

func _spawn_cactus() -> void:
    var tall := rng.randf() < 0.45
    var max_count := 3 if score() > 180.0 else 2
    var count := 1 + rng.randi_range(0, max_count - 1)
    var cw := 17.0 if tall else 15.0
    var ch := 50.0 if tall else 36.0
    var gap := 4.0
    var w := count * cw + (count - 1) * gap
    obstacles.append({
        "kind": "cactus", "x": LW + 20.0, "y": GROUND_Y - ch,
        "w": w, "h": ch, "count": count,
    })

func _spawn_bird() -> void:
    var lanes := [GROUND_Y - 80.0, GROUND_Y - 54.0, GROUND_Y - 26.0]
    var base_y: float = lanes[rng.randi_range(0, 2)]
    # Schwarm/aktives Zufliegen (nur Hoehle) bewusst noch nicht portiert -
    # gehoert an die Cave-Visuals in Phase 3, siehe README. Hier immer eine
    # einzelne "bird"/"bat"-Hitbox (kind-Name kosmetisch, Kollision identisch).
    obstacles.append({
        "kind": "bird", "x": LW + 20.0, "y": base_y, "w": 38.0, "h": 26.0,
    })

func _spawn_snake() -> void:
    var sw := 42.0 + rng.randf() * 10.0
    obstacles.append({"kind": "snake", "x": LW + 20.0, "y": GROUND_Y - 16.0, "w": sw, "h": 16.0})

func _poison_target_y() -> float:
    return GROUND_Y - 26.0 if ducking else GROUND_Y - 54.0

func _spawn_poison() -> void:
    obstacles.append({
        "kind": "poison", "x": LW + 20.0, "y": _poison_target_y(), "w": 16.0, "h": 16.0,
    })

func _spawn_rock() -> void:
    var rd := 26.0 + rng.randf() * 22.0
    obstacles.append({
        "kind": "rock", "x": LW + 20.0, "y": GROUND_Y - rd, "w": rd, "h": rd,
        "roll_extra": 0.0,
    })

# Deterministische Ganzzahl-Hash-Pseudozufallsfunktion, wortgleich aus
# web/index.html (rockNoise()) - liefert fuer dasselbe n IMMER denselben
# 0-1-Wert. Fuer Hoehlentexturen (Speckel/Risse/Moos), die beim Scrollen
# NICHT "schwimmen" duerfen, weil sie an Weltkoordinaten haengen statt an der
# Framezahl. Bewusst NICHT bit-exakt zur JS-Version (JS truncatiert bei jeder
# Bitoperation auf 32-Bit-Integer, `*`/`+` bleiben aber Gleitkomma-Doubles -
# GDScripts `int` ist 64-Bit und wraps anders). Rein kosmetisch, nicht
# fairness-relevant, daher unkritisch: dieselbe Formel, mit derselben
# abschliessenden Maskierung/Normalisierung, liefert fuer den hier
# tatsaechlich genutzten Eingabebereich weiterhin ein deterministisches,
# gleichmaessig verteilt wirkendes Ergebnis.
static func rock_noise(n: int) -> float:
    var h: int = (n << 13) ^ n
    h = h * (h * h * 15731 + 789221) + 1376312589
    return float(h & 0x7fffffff) / 1073741824.0

# Oeffentlich (kein "_"-Praefix): auch von game_view.gd fuers Zeichnen der
# Deckenkontur gebraucht, nicht nur intern beim Spawnen.
func ceiling_gap_at(world_x: float) -> float:
    var wave := 0.5 + 0.5 * sin((world_x / CAVE_WAVELEN) * TAU)
    return CAVE_MIN_GAP + wave * (CAVE_MAX_GAP - CAVE_MIN_GAP)

func _spawn_stalactite() -> float:
    var spawn_x := LW + 20.0
    var gap := ceiling_gap_at(scroll_ceiling + spawn_x)
    var tip := STALACTITE_TIP_MIN + rng.randf() * (STALACTITE_TIP_MAX - STALACTITE_TIP_MIN)
    var h: float = max(10.0, gap - tip)
    obstacles.append({"kind": "stalactite", "x": spawn_x, "y": GROUND_Y - gap, "w": 34.0, "h": h})
    return 170.0 + rng.randf() * 80.0

func _spawn_pillar() -> float:
    var spawn_x := LW + 20.0
    var gap := ceiling_gap_at(scroll_ceiling + spawn_x)
    var tip := PILLAR_TIP_MIN + rng.randf() * (PILLAR_TIP_MAX - PILLAR_TIP_MIN)
    var h: float = max(10.0, gap - tip)
    obstacles.append({"kind": "pillar", "x": spawn_x, "y": GROUND_Y - gap, "w": 30.0, "h": h})
    return 220.0 + rng.randf() * 100.0

func _obstacle_gap() -> float:
    var base := speed * (0.70 if mountain_on else 0.60)
    if not cave_on:
        base *= max(0.72, 1.0 - (score() / CAVE_START) * 0.28)
    return base + rng.randf() * base * 0.80

# ============================================================== Autopilot ==
# Wortgleich zur Entscheidungslogik von autoPilot() in web/index.html: reagiert
# pro Aufruf nur auf das jeweils NAECHSTE Hindernis (nicht fertig passiert),
# bricht danach ab. "want" bleibt unveraendert, wenn ein Hindernis in der
# "ignorierbaren" oberen Vogel-/Gift-Bahn liegt (kein "duck"/"jump" noetig) -
# die Schleife prueft dann das naechste Hindernis dahinter weiter, statt
# abzubrechen.
func _bot_decide() -> void:
    var want := "none"
    for o in obstacles:
        if float(o.x) + float(o.w) < RUNNER_X:
            continue
        var closing_speed: float = speed
        if o.kind == "rock":
            closing_speed += float(o.roll_extra)
        elif o.kind == "poison":
            closing_speed += POISON_EXTRA
        var t_contact: float = (float(o.x) - (RUNNER_X + 46.0)) / closing_speed
        var t_pass: float = (float(o.w) + 50.0) / closing_speed
        var t_trigger: float = max(0.05, (AIR_TIME - t_pass) / 2.0)
        if t_contact > t_trigger + 0.25:
            continue
        if o.kind == "bird" or o.kind == "poison":
            if float(o.y) <= GROUND_Y - 70.0:
                continue
            want = "duck" if float(o.y) <= GROUND_Y - 40.0 else "jump"
        elif o.kind == "stalactite" or o.kind == "pillar":
            want = "duck"
        else:
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
