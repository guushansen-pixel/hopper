# Phase 5: Sound-Effekte - 100% synthetisiert (siehe audio_synth.gd), kein
# Audiofile. Klangdesign wortgleich zu web/index.html SFX-Objekt (Wellenform,
# Frequenzen, Dauer je Sound). Als Autoload registriert (project.godot
# [autoload]), damit jede Szene einfach "Sfx.jump()" etc. rufen kann.
#
# Alle Clips werden EINMAL bei Programmstart generiert (nicht bei jedem
# Abspielen neu synthetisiert) und ueber einen kleinen AudioStreamPlayer-Pool
# abgespielt, damit sich ueberlappende Sounds (z.B. mehrere Punkte-Sounds
# kurz hintereinander) nicht gegenseitig abschneiden.
extends Node

const AudioSynth = preload("res://scripts/audio_synth.gd")

# In der Hoehle: von game_view.gd aktuell gehalten (sim.cave_on), fuer
# with_cave_echo() - Hoehlen-Echo ist eine Optik-/Akustik-Eigenschaft der
# Sim-unabhaengigen Szene, gehoert hier rein wie bei Sfx generell.
var cave_on := false

const POOL_SIZE := 8
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

var _clip := {}
# Lautstaerken 1:1 aus web/index.html SFX-Definitionen uebernommen (siehe
# dortige tone()/noise()-Aufrufe je Sound).
const VOL := {
    "jump": 0.5, "land": 0.45, "land_noise": 0.16, "duck": 0.5,
    "point1": 0.22, "point2": 0.20, "die": 0.42, "die_noise": 0.22,
    "ui": 0.4, "equip": 0.5, "enter": 0.5,
}

func _ready() -> void:
    _clip["jump"] = AudioSynth.make_tone("triangle", 330.0, 700.0, 0.13)
    _clip["land"] = AudioSynth.make_tone("sine", 190.0, 70.0, 0.10)
    _clip["land_noise"] = AudioSynth.make_noise(0.07, 900.0, 0.8)
    _clip["duck"] = AudioSynth.make_tone("square", 260.0, 150.0, 0.07)
    _clip["point1"] = AudioSynth.make_tone("square", 880.0, 880.0, 0.07)
    _clip["point2"] = AudioSynth.make_tone("square", 1320.0, 1320.0, 0.09)
    _clip["die"] = AudioSynth.make_tone("sawtooth", 420.0, 70.0, 0.55)
    _clip["die_noise"] = AudioSynth.make_noise(0.35, 420.0, 0.6)
    _clip["ui"] = AudioSynth.make_tone("square", 620.0, 620.0, 0.045)
    _clip["equip"] = AudioSynth.make_tone("triangle", 520.0, 780.0, 0.09)
    _clip["enter"] = AudioSynth.make_tone("sine", 520.0, 130.0, 1.0)
    for i in range(POOL_SIZE):
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

func _play(name: String, scale: float = 1.0) -> void:
    var p := _players[_next_player]
    _next_player = (_next_player + 1) % POOL_SIZE
    p.stream = _clip[name]
    var v: float = float(VOL[name]) * scale
    p.volume_db = linear_to_db(clampf(v, 0.001, 1.0))
    p.play()

# Wortgleich zu withCaveEcho() in web/index.html: einmal bei voller
# Lautstaerke, und - nur in der Hoehle - 110ms spaeter nochmal bei 32%
# ("Echo"-Effekt, bewusst ein billiger zweiter Abspielvorgang statt echtem
# Convolution-Hall, siehe dortiger Kommentar).
func _with_cave_echo(play_fn: Callable) -> void:
    play_fn.call(1.0)
    if cave_on:
        get_tree().create_timer(0.11).timeout.connect(func(): play_fn.call(0.32))

func jump() -> void:
    _with_cave_echo(func(s: float): _play("jump", s))

func land() -> void:
    _with_cave_echo(func(s: float):
        _play("land", s)
        _play("land_noise", s)
    )

func duck() -> void:
    _play("duck")

func point() -> void:
    _play("point1")
    get_tree().create_timer(0.075).timeout.connect(func(): _play("point2"))

func die() -> void:
    _with_cave_echo(func(s: float):
        _play("die", s)
        _play("die_noise", s)
    )

func ui() -> void:
    _play("ui")

func equip() -> void:
    _play("equip")

func enter() -> void:
    _play("enter")
