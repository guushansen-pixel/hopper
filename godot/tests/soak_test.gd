# Kopfloser Soak-Test - das Godot-Aequivalent der bisherigen Browser-
# Autopilot-Soaks (siehe web/README.md). Laeuft ohne Fenster/Rendering:
#
#   godot --headless --path <projekt> -s res://tests/soak_test.gd -- --seconds=1800 --seed=1
#
# Prueft zwei Dinge, die in Phase 1 unabhaengig vom JS-Original neu
# verifiziert werden muessen (NICHT einfach angenommen, weil die Konstanten
# uebernommen wurden - andere Engine, anderes Tick-Modell):
#   1. Deterministischer Hoehen-/Breiten-Test: kann der Autopilot einen
#      isolierten Kaktus-Cluster (count 1-3, hoch/niedrig) bei JEDEM Tempo
#      zwischen SPEED_START und SPEED_MAX ueberhaupt ueberspringen - reine
#      Sprungphysik, unabhaengig vom Timing. Genau dieser Test hatte im
#      WebView-Original den alten Hoehlen-Kurzsprung-Bug aufgedeckt.
#   2. Soak-Lauf mit echtem Zufalls-Spawn: Todesrate + minimales
#      "wie lange war das Hindernis sichtbar, bevor der Autopilot spaetestens
#      reagieren muss"-Reaktionsfenster (Basiswert im JS-Original: 283ms).
#
# FUND (Phase 1, cactus-only): Test 2 zeigt eine hoehere Todesrate (~44 in
# 600s bei seed=1) als im JS-Original je gemessen, obwohl Test 1 (jedes
# Cluster bei jedem Tempo einzeln ueberspringbar) durchgehend "ok" liefert
# und das minimale Reaktionsfenster (>=400ms) SICHERER ist als der JS-
# Basiswert. Ursache isoliert: `obstacleGap()`s Dichte-Untergrenze (Faktor
# 0.72, wortgleich aus web/index.html uebernommen) erzeugt bei manchen
# Zufallswerten einen Abstand zwischen zwei aufeinanderfolgenden Kakteen, der
# knapp NICHT ausreicht, um von der Landung des ersten Sprungs bis zum
# spaetesten Absprungpunkt des naechsten zu kommen - der Autopilot reagiert
# ja pro Frame nur auf das jeweils naechste Hindernis (siehe autoPilot()-
# Kommentar). Das ist vermutlich KEIN Godot-spezifischer Bug, sondern eine
# Eigenschaft der uebernommenen Formel, die im echten Spiel durch die
# Durchmischung mit Voegeln/Schlangen/etc. verduennt und darum nie so klar
# aufgefallen ist wie hier in der Kaktus-Monokultur von Phase 1. NICHT jetzt
# gefixt: die Formel gehoert zum vollen Spawn-/Dichte-System, das laut Plan
# erst in Phase 2 (mit der vollen Hindernis-Mischung) uebertragen und dort
# neu verifiziert wird - eine Aenderung jetzt, isoliert am Kaktus-Fall,
# waere reine Spekulation ohne die Gesamtsituation zu sehen.
extends SceneTree

# WICHTIG: `-s script.gd`-Kopflosmodus fuehrt (anders als Editor/Export)
# offenbar keinen vollen Projekt-Scan aus, der globale `class_name`-Bezeichner
# registriert - "HopperSim" ist ohne expliziten preload() hier nicht bekannt,
# selbst obwohl hopper_sim.gd `class_name HopperSim` deklariert.
const HopperSim = preload("res://scripts/hopper_sim.gd")

func _init() -> void:
    var args := _parse_args()
    var seconds: float = args.get("seconds", 1800.0)
    var seed_value: int = args.get("seed", 1)

    print("=== Phase 1 Godot-Sim: deterministischer Hoehen-/Breitentest ===")
    var shape_results := _test_shape_clearance(seed_value)
    for line in shape_results:
        print(line)

    print("")
    print("=== Phase 1 Godot-Sim: Soak-Test (%.0fs, seed=%d) ===" % [seconds, seed_value])
    var soak := _soak(seconds, seed_value)
    print("Sekunden simuliert: %.1f" % soak.seconds)
    print("Tode gesamt:        %d" % soak.deaths)
    print("Minimales Reaktionsfenster (s): %s" % str(soak.min_window))
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
# vollstaendig passiert hat. Deterministisch bis auf die (hier irrelevante)
# RNG-Nutzung von HopperSim, die fuer diesen Test nicht gebraucht wird.
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
        sim.spawn_in = 1.0e9   # jeden Frame neu erzwingen, falls _spawn_cactus() doch greift
        sim.step(dt, true)
        sim.speed = speed      # SPEED_RAMP innerhalb des Tests unterdruecken - konstantes Tempo
        t += dt
        if sim.dead:
            return true    # HIT
        if sim.obstacles.is_empty():
            return false   # ok, durchgekommen
    return false

func _test_shape_clearance(_seed_value: int) -> Array:
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
func _soak(seconds: float, seed_value: int) -> Dictionary:
    var sim := HopperSim.new(seed_value)
    var dt := 1.0 / 60.0
    var t := 0.0
    var deaths := 0
    var death_log := []
    var min_window := {}       # kind -> Sekunden
    var first_seen := {}       # Objekt-Identitaet (per Index-Workaround) -> t
    # Da Dictionaries in obstacles keine stabile Identitaet ueber remove_at()
    # hinweg garantieren, wird hier zusaetzlich ein "_seen_at"/"_marked" Feld
    # direkt ins Hindernis-Dictionary geschrieben (wie im JS-Original mit
    # o._firstT/o._deadlineMarked) statt eines externen Lookups.
    while t < seconds:
        sim.step(dt, true)
        t += dt
        for o in sim.obstacles:
            if o.x > HopperSim.LW:
                continue
            if not o.has("_first_t"):
                o["_first_t"] = t
            var closing_speed: float = sim.speed
            var t_contact: float = (float(o.x) - (HopperSim.RUNNER_X + 46.0)) / closing_speed
            var t_pass: float = (float(o.w) + 50.0) / closing_speed
            var t_trigger: float = max(0.05, (HopperSim.AIR_TIME - t_pass) / 2.0)
            if t_contact <= t_trigger and not o.has("_deadline_marked"):
                o["_deadline_marked"] = true
                var visible_time: float = t - o["_first_t"]
                var kind: String = o.kind
                if not min_window.has(kind) or visible_time < min_window[kind]:
                    min_window[kind] = visible_time
        if sim.dead:
            deaths += 1
            if death_log.size() < 50:
                var obs_snapshot := []
                for o in sim.obstacles:
                    obs_snapshot.append({"x": o.x, "w": o.w, "count": o.count})
                death_log.append({"t": t, "score": sim.score, "speed": sim.speed, "obstacles": obs_snapshot})
            sim.reset()
    return {"seconds": t, "deaths": deaths, "min_window": min_window, "death_log": death_log}
