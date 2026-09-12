# Einmaliges Dev-Tool: rendert assets/icon/icon_source.svg (1:1 aus
# hopper/icon.xml uebertragen, siehe dortiger Kommentar) zu den drei PNGs,
# die Godots Android-Export ohne Gradle-Custom-Build braucht
# (launcher_icons/* akzeptiert nur Raster-PNG, kein Vector-XML wie beim
# WebView-Build). Reine CPU-Bildbearbeitung (Image.load_svg_from_string(),
# ThorVG-basiert seit Godot 4.2) - laeuft auch mit --headless, kein
# Viewport/Rendering noetig.
#
#   godot --headless --path <projekt> -s res://tests/render_icon.gd
#
# IconBackground uebernommen aus dem WebView-Build-Befehl in README.md
# (-IconBackground "#E4703A").
extends SceneTree

const BG_COLOR := Color("#E4703A")
const SVG_PATH := "res://assets/icon/icon_source.svg"
const OUT_DIR := "res://assets/icon/"

func _init() -> void:
    var svg_text := FileAccess.get_file_as_string(SVG_PATH)
    if svg_text.is_empty():
        push_error("SVG nicht lesbar: %s" % SVG_PATH)
        quit(1)
        return

    # adaptive_foreground_432x432: nur die Vektor-Grafik, transparenter
    # Hintergrund (SVG selbst hat keinen Hintergrund-Rect).
    var fg := Image.new()
    var err := fg.load_svg_from_string(svg_text, 432.0 / 108.0)
    if err != OK:
        push_error("SVG-Rasterung fehlgeschlagen: %s" % err)
        quit(1)
        return
    fg.save_png(OUT_DIR + "adaptive_foreground_432.png")

    # adaptive_background_432x432: einfarbige Flaeche.
    var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
    bg.fill(BG_COLOR)
    bg.save_png(OUT_DIR + "adaptive_background_432.png")

    # main_192x192: Legacy-Icon (vor Android 8 / Icon-Vorschau) - Hintergrund
    # + Vordergrund zusammengesetzt, da hier keine separaten Ebenen erlaubt
    # sind.
    var main := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    main.fill(BG_COLOR)
    var fg192 := Image.new()
    fg192.load_svg_from_string(svg_text, 192.0 / 108.0)
    main.blend_rect(fg192, Rect2i(Vector2i.ZERO, fg192.get_size()), Vector2i.ZERO)
    main.save_png(OUT_DIR + "main_192.png")

    print("Icon-PNGs geschrieben: adaptive_foreground_432.png (%dx%d), adaptive_background_432.png (%dx%d), main_192.png (%dx%d)" % [
        fg.get_width(), fg.get_height(), bg.get_width(), bg.get_height(), main.get_width(), main.get_height(),
    ])
    quit()
