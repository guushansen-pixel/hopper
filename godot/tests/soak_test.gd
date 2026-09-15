# Kopfloser Soak-Test - das Godot-Aequivalent der bisherigen Browser-
# Autopilot-Soaks (siehe hopper/CHANGELOG.md). Laeuft ohne Fenster/Rendering:
#
#   godot --headless --path <projekt> -s res://tests/soak_test.gd -- --seconds=1800 --seed=1 --cave=0
#
# Prueft zwei Dinge, die unabhaengig vom JS-Original neu verifiziert werden
# muessen (NICHT einfach angenommen, weil die Konstanten uebernommen wurden -
# andere Engine, anderes Tick-Modell):
#   1. Deterministischer Hoehen-/Breiten-Test: kann der Autopilot einen
#      isolierten Kaktus-Cluster (count 1-3, hoch/niedrig) bei JEDEM Tempo
#      zwischen SPEED_START und SPEED_MAX ueberhaupt ueberspringen - reine
#      Sprungphysik, unabhaengig vom Timing. Genau dieser Test hatte im
#      WebView-Original den alten Hoehlen-Kurzsprung-Bug aufgedeckt.
#   2. Soak-Lauf mit echtem Zufalls-Spawn (voller Hindernis-Mix seit Phase 2):
#      Todesrate nach Hindernisart + minimales "wie lange war das Hindernis
#      sichtbar, bevor der Autopilot spaetestens reagieren muss"-
#      Reaktionsfenster (Basiswert im JS-Original: 283ms).
#
# FUND aus Phase 1 (cactus-only-Soak, zum Vergleich): die Dichte-Untergrenze
# (Faktor 0.72 in obstacleGap(), wortgleich aus web/index.html) erzeugte in
# der Kaktus-MONOKULTUR zu knappe Abstaende zwischen aufeinanderfolgenden
# Kakteen (139 Tode/1800s). Mit dem VOLLEN Hindernis-Mix aus Phase 2
# (Wueste: Kaktus/Vogel/Schlange+Gift/Fels; Hoehle zusaetzlich Tropfstein/
# -saeule) bestaetigt sich die Vermutung: die Rate faellt auf 20-22/1800s
# (seed 1 und 3, ausschliesslich bei Hoechsttempo 960, ueberwiegend Kaktus) -
# das liegt innerhalb der historisch akzeptierten Rate des JS-Originals
# ("2-9 Abstuerze pro 5 Minuten" als Normalfall, siehe hopper/CHANGELOG.md zum
# Fledermaus-Wobble-Bug 1.24). Hoehlen-Modus (cave=1): 0 Tode in 1800s bei
# allen 6 Hindernisarten inkl. Tropfstein/-saeule - dort greift NICHT die
# 0.72-Dichte-Untergrenze (die gilt nur ausserhalb der Hoehle), was die
# obige Diagnose zusaetzlich stuetzt. Bewertung: keine neue Regression,
# sondern eine bereits im JS-Original akzeptierte Grundrate, in der
# Kaktus-Monokultur von Phase 1 nur ueberproportional sichtbar geworden.
extends SceneTree

# WICHTIG: `-s script.gd`-Kopflosmodus fuehrt (anders als Editor/Export)
# offenbar keinen vollen Projekt-Scan aus, der globale `class_name`-Bezeichner
# registriert - "HopperSim" ist ohne expliziten preload() hier nicht bekannt,
# selbst obwohl hopper_sim.gd `class_name HopperSim` deklariert.
#
# ZWEITE FALLE (gefunden in Phase 1, siehe godot/README.md): GDScripts `:=`-
# Typinferenz scheitert leise an Dictionary-Feldzugriffen (o.x ist Variant) -
# UND ein Skript mit diesem Parse-Fehler haengt sich beim Laden scheinbar
# unendlich auf (Godots Skript-Neulade-Mechanismus rotiert), statt sauber
# abzubrechen. Deshalb hier ausnahmslos `: float =`/`float(...)`, nie `:=`,
# wo ein Dictionary-Feld beteiligt ist.
const HopperSim = preload("res://scripts/hopper_sim.gd")

func _init() -> void:
    var args := _parse_args()
    var seconds: float = args.get("seconds", 1800.0)
    var seed_value: int = args.get("seed", 1)
    var cave: bool = args.get("cave", 0.0) > 0.5

    print("=== Godot-Sim: deterministischer Hoehen-/Breitentest (Kaktus) ===")
    var shape_results := _test_shape_clearance()
    for line in shape_results:
        print(line)

    print("")
    print("=== Godot-Sim: Soak-Test (%.0fs, seed=%d, cave=%s) ===" % [seconds, seed_value, str(cave)])
    var soak := _soak(seconds, seed_value, cave)
    print("Sekunden simuliert: %.1f" % soak.seconds)
    print("Wueste 'geschafft' (Neustarts, kein Tod): %d" % soak.cleared_count)
    print("Tode gesamt:        %d" % soak.deaths)
    print("Tode nach Art:      %s" % str(soak.deaths_by_kind))
    print("Hindernisse gesamt nach Art: %s" % str(soak.spawn_counts))
    print("Minimales Reaktionsfenster (s) nach Art: %s" % str(soak.min_window))
    print("Todes-Details (erste 10): %s" % str(soak.death_log.slice(0, 10)))

    quit()

func _parse_args() -> Dictionary:
    var result := {}
    for raw in OS.get_cmdline_user_args():
        var s: String = raw
        if s.begins_with("--"):
            s = s.substr(2)
        var parts := s.split("=", true, 1)
        if parts.size() == 2:
            if parts[1].is_valid_float():
                result[parts[0]] = parts[1].to_float()
            else:
                result[parts[0]] = parts[1]
    return result

# ---------------------------------------------------- Hoehen-/Breitentest --
# Spawnt GENAU EIN Hindernis in Isolation bei konstantem Tempo und laesst den
# Autopilot so lange laufen, bis er entweder trifft oder das Hindernis
# vollstaendig passiert hat.
func _test_one_shape(count: int, tall: bool, speed: float) -> bool:
    var sim := HopperSim.new()
    sim.speed = speed
    sim.spawn_in = 1.0e9   # normalen Zufalls-Spawn komplett unterdruecken
    var cw: float = 17.0 if tall else 15.0
    var ch: float = 50.0 if tall else 36.0
    var gap: float = 4.0
    var w: float = count * cw + (count - 1.0) * gap
    sim.obstacles = [{
        "kind": "cactus", "x": HopperSim.LW + 20.0, "y": HopperSim.GROUND_Y - ch,
        "w": w, "h": ch, "count": count,
    }]
    var dt := 1.0 / 60.0
    var t := 0.0
    while t < 6.0:
        sim.spawn_in = 1.0e9   # jeden Frame neu erzwingen, falls _spawn_obstacle() doch greift
        sim.step(dt, true)
        sim.speed = speed      # SPEED_RAMP innerhalb des Tests unterdruecken - konstantes Tempo
        t += dt
        if sim.dead:
            return true    # HIT
        if sim.obstacles.is_empty():
            return false   # ok, durchgekommen
    return false

func _test_shape_clearance() -> Array:
    var lines := []
    var shapes := [
        {"label": "count1_tall", "count": 1, "tall": true},
        {"label": "count2_tall", "count": 2, "tall": true},
        {"label": "count3_tall", "count": 3, "tall": true},
        {"label": "count1_short", "count": 1, "tall": false},
        {"label": "count2_short", "count": 2, "tall": false},
        {"label": "count3_short", "count": 3, "tall": false},
    ]
    var speeds := [330.0, 400.0, 500.0, 600.0, 700.0, 800.0, 900.0, 960.0]
    for shape in shapes:
        var row := "%-14s " % shape.label
        var any_hit := false
        for sp in speeds:
            var hit: bool = _test_one_shape(shape.count, shape.tall, sp)
            if hit:
                any_hit = true
            row += ("HIT " if hit else "ok  ")
        if any_hit:
            row += "  <-- UNCLEARABLE BEI MINDESTENS EINEM TEMPO"
        lines.append(row)
    return lines

# ------------------------------------------------------------- Soak-Test ---
func _soak(seconds: float, seed_value: int, cave: bool) -> Dictionary:
    var sim := HopperSim.new(seed_value)
    sim.cave_on = cave
    var dt := 1.0 / 60.0
    var t := 0.0
    var deaths := 0
    var cleared_count := 0
    var deaths_by_kind := {}
    var spawn_counts := {}
    var death_log := []
    var min_window := {}       # kind -> Sekunden
    var seen_kinds := {}       # welche Hindernis-Objekte (per _counted-Flag) schon gezaehlt wurden
    while t < seconds:
        sim.step(dt, true)
        t += dt
        for o in sim.obstacles:
            if not o.has("_counted"):
                o["_counted"] = true
                var k0: String = o.kind
                spawn_counts[k0] = int(spawn_counts.get(k0, 0)) + 1
            if float(o.x) > HopperSim.LW:
                continue
            if not o.has("_first_t"):
                o["_first_t"] = t
            var closing_speed: float = sim.speed
            if o.kind == "rock":
                closing_speed += float(o.roll_extra)
            elif o.kind == "poison":
                closing_speed += HopperSim.POISON_EXTRA
            var t_contact: float = (float(o.x) - (HopperSim.RUNNER_X + 46.0)) / closing_speed
            var t_pass: float = (float(o.w) + 50.0) / closing_speed
            var t_trigger: float = max(0.05, (HopperSim.AIR_TIME - t_pass) / 2.0)
            if t_contact <= t_trigger and not o.has("_deadline_marked"):
                o["_deadline_marked"] = true
                var visible_time: float = t - float(o["_first_t"])
                var kind: String = o.kind
                if not min_window.has(kind) or visible_time < min_window[kind]:
                    min_window[kind] = visible_time
        if sim.dead:
            deaths += 1
            var culprit := "?"
            for o in sim.obstacles:
                if _hits_snapshot(sim, o):
                    culprit = o.kind
                    break
            deaths_by_kind[culprit] = int(deaths_by_kind.get(culprit, 0)) + 1
            if death_log.size() < 20:
                death_log.append({
                    "t": t, "score": sim.score(), "speed": sim.speed,
                    "cave_on": sim.cave_on, "culprit": culprit,
                })
            sim.reset()
            sim.cave_on = cave
        elif sim.cleared:
            # Wueste bei CAVE_START "geschafft" (siehe hopper_sim.gd) - kein
            # Tod, aber step() ist ab jetzt ein No-Op; fuer den Soak-Test
            # einfach neu starten, damit der restliche Zeitraum weiter
            # sinnvoll Hindernisse/Fairness prueft statt leerzulaufen.
            cleared_count += 1
            sim.reset()
            sim.cave_on = cave
    return {
        "seconds": t, "deaths": deaths, "deaths_by_kind": deaths_by_kind,
        "cleared_count": cleared_count,
        "spawn_counts": spawn_counts, "min_window": min_window, "death_log": death_log,
    }

# Re-implementiert dieselbe Kollisionspruefung wie HopperSim._hits() (privat,
# daher hier dupliziert statt aufgerufen) - nur zur Diagnose, WELCHES
# Hindernis im Todesmoment ueberlappt.
func _hits_snapshot(sim: HopperSim, o: Dictionary) -> bool:
    var pad := 5.0
    var rw: float = HopperSim.DUCK_W if sim.ducking else HopperSim.RUNNER_W
    var rh: float = HopperSim.DUCK_H if sim.ducking else HopperSim.RUNNER_H
    var rx := HopperSim.RUNNER_X + pad
    var ry := HopperSim.GROUND_Y - rh + sim.runner_y + pad
    rw -= pad * 2.0
    rh -= pad * 2.0
    return rx < float(o.x) + float(o.w) - 2.0 and rx + rw > float(o.x) + 2.0 \
       and ry < float(o.y) + float(o.h) - 2.0 and ry + rh > float(o.y) + 2.0
