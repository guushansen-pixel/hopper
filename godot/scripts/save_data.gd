# Phase 6: Persistenz - Godot-Aequivalent von web/index.html localStorage.
# Autoload "Save" (project.godot [autoload]). Eine einzige JSON-Datei unter
# user:// statt einzelner localStorage-Keys - inhaltlich dieselben Felder
# wie im Original (settings/look/highscore/last/caveHighscore/caveLast/
# caveUnlocked), nur als ein zusammenhaengendes Dokument statt getrennter
# Keys, weil Godot kein localStorage-Aequivalent mit einzelnen String-Keys
# hat, aber ConfigFile/JSON unter user:// dafuer sehr gut geeignet ist.
#
# BEWUSSTE ENTSCHEIDUNG (User gefragt, nicht angenommen): alte WebView-
# Highscores werden NICHT uebernommen - andere App (eigene Paket-ID
# com.daniel.hopper.godot), anderer Speicherort/anderes Format. Diese Datei
# startet also bei jedem Spieler bei 0, nicht aus web/index.html importiert.
extends Node

const SAVE_PATH := "user://save.json"

var settings := {
    "music": true, "sfx": true, "shake": true, "cycle": true, "start_cave": false,
}
var look := {"shape": "dog", "color": "auto", "hat": "none"}
var highscore := 0
var last_score := 0
var cave_highscore := 0
var cave_last := 0
var cave_unlocked := false

func _ready() -> void:
    load_data()

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var text := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var d: Dictionary = parsed
    if d.has("settings") and typeof(d.settings) == TYPE_DICTIONARY:
        for k in settings.keys():
            if d.settings.has(k):
                settings[k] = d.settings[k]
    if d.has("look") and typeof(d.look) == TYPE_DICTIONARY:
        for k in look.keys():
            if d.look.has(k):
                look[k] = d.look[k]
    highscore = int(d.get("highscore", 0))
    last_score = int(d.get("last_score", 0))
    cave_highscore = int(d.get("cave_highscore", 0))
    cave_last = int(d.get("cave_last", 0))
    cave_unlocked = bool(d.get("cave_unlocked", false))

func save_data() -> void:
    var d := {
        "settings": settings, "look": look,
        "highscore": highscore, "last_score": last_score,
        "cave_highscore": cave_highscore, "cave_last": cave_last,
        "cave_unlocked": cave_unlocked,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(d))
    f.close()

# Meldet einen Rundenabschluss und aktualisiert ggf. den Highscore -
# wortgleiches Prinzip zu web/index.html (record = score > high).
func report_score(score: int, cave: bool) -> bool:
    var record := false
    if cave:
        if score > cave_highscore:
            cave_highscore = score
            record = true
        cave_last = score
    else:
        if score > highscore:
            highscore = score
            record = true
        last_score = score
    save_data()
    return record

func unlock_cave() -> void:
    if not cave_unlocked:
        cave_unlocked = true
        save_data()

func reset_highscores() -> void:
    highscore = 0
    last_score = 0
    cave_highscore = 0
    cave_last = 0
    save_data()
