# Hopper - Godot-Version (archiviert)

Nicht die aktive App: seit V17 laeuft wieder die WebView-Version
(`../web/index.html`, siehe `../README.md`). Dieses Dokument ist das
Migrationsprotokoll (Phase 0-7), aus der Hopper-README ausgelagert. Offene
Punkte fuer einen spaeteren Wiedereinstieg stehen im Plan
`C:\Users\Daniel\.claude\plans\kannst-du-hier-direkt-indexed-pelican.md`
(Abschnitt "Visueller/UI-Vollausbau", Phase 8-13).
## Migrationsprotokoll (Phase 0-7, abgeschlossen)

`web/` blieb die ganze Migration ueber unveraendert als Fallback. Grund fuer
den Umstieg: der User wollte echte Partikel-/Glow-Effekte ("3D-Partikel"),
dabei aber das bestehende 2D-Gameplay/Physik/Fairness-Tuning unveraendert
lassen - Godot statt Unity, weil MIT-lizenziert und ohne Risiko kuenftiger
Lizenzaenderungen (siehe apk-builder/CLAUDE.md fuer die Toolchain-Seite).
Voller Plan:
`C:\Users\Daniel\.claude\plans\kannst-du-hier-direkt-indexed-pelican.md`.

**Phase 0 (Toolchain)**: fertig, verifiziert (siehe apk-builder-Commit
"Zweite Build-Faehigkeit").

**Phase 1 (Kern-Physik + ein Hindernis + Bot + Soak-Harness)**: begonnen.
`godot/scripts/hopper_sim.gd` portiert Laeufer-Physik (Sprung/Schwerkraft/
Coyote/Buffer), `hits()`-Kollision und den Kaktus-Spawn wortgleich aus
`web/index.html`; `godot/tests/soak_test.gd` ist das Godot-Aequivalent der
bisherigen Browser-Autopilot-Soaks (`godot --headless --path godot -s
res://tests/soak_test.gd -- --seconds=1800 --seed=1`).

Beim ersten echten Soak-Lauf direkt ein echter Fund (nicht nur Toolchain-
Kram): der deterministische Hoehen-/Breitentest zeigt jedes Kaktus-Cluster
(1-3, hoch/niedrig) bei jedem Tempo zwischen 330 und 960 als einzeln
ueberspringbar, UND das minimale Reaktionsfenster liegt bei >=267ms (JS-
Basiswert: 283ms, Differenz ist Frame-Rundung, kein echter Unterschied) -
trotzdem 139 Tode in 1800 simulierten Sekunden. Ursache: `obstacleGap()`s
Dichte-Untergrenze (Faktor 0.72, wortgleich aus dem JS-Original) laesst bei
manchen Zufallswerten zu wenig Abstand zwischen zwei AUFEINANDERFOLGENDEN
Kakteen, um vom ersten Sprung zum spaetesten Absprungpunkt des naechsten zu
kommen. Vermutlich kein Godot-spezifischer Bug, sondern eine Eigenschaft der
Formel, die im echten Spiel durch die Durchmischung mit Voegeln/Schlangen/
etc. verduennt wird - in der Kaktus-Monokultur von Phase 1 (bewusst nur ein
Hindernistyp) tritt sie viel deutlicher auf. Bewusst NICHT jetzt gefixt:
gehoert zum vollen Spawn-/Dichte-System, das laut Plan erst in Phase 2 (mit
der vollen Hindernis-Mischung) uebertragen und dort neu verifiziert wird.

Zwei GDScript-Eigenheiten beim Bauen gefunden, fuer spaetere Phasen wichtig:
`-s script.gd`-Kopflosmodus registriert offenbar keine globalen
`class_name`-Bezeichner (`preload()` stattdessen verwenden), und `:=`-Typinferenz
scheitert leise an Dictionary-Feldzugriffen (`o.x` ist Variant) - das
verursachte einen scheinbaren Absturz/Haenger (Godots Skript-Neulade-
Mechanismus versucht ein Skript mit Parse-Fehler endlos neu zu kompilieren,
statt sauber abzubrechen). Immer explizite `: float =`/`float(...)`
verwenden, nie `:=`, wenn ein Dictionary-Feld beteiligt ist.

**Phase 2 (restliche Hindernisse + volles Spawn-/Dichte-System)**: fertig.
`hopper_sim.gd` erweitert um Vogel (3 Hoehenbahnen), Schlange+Gift-Kopplung
(mit dem bereits im WebView-Original verifizierten 600-750-Zwangsabstand),
Felsen (Bergabschnitte, `rollExtra`-Beschleunigung), Tropfstein/-saeule
(Hoehlendecke als reine Sinuswelle, `cave_on`-Flag), sowie den kompletten
`spawnObstacle()`-Dispatcher samt Prioritaetsreihenfolge und der
"Forced-Gap"-Konvention (Rueckgabewert statt normaler `obstacleGap()`).

**Wichtige Korrektur dabei gefunden**: Phase 1 hatte `score` faelschlich mit
der rohen, kontinuierlichen Distanz gleichgesetzt. Im JS-Original ist
`state.score = floor(state.distance/14) + state.bonus` - eine ABGELEITETE,
14x langsamer wachsende Groesse, gegen die ALLE Schwellenwerte (Vogel/
Schlange/Gift-Start, CAVE_START, Dichtefaktor) verglichen werden. Ohne die
Korrektur waere in Phase 2 z.B. `CAVE_START=3000` nach Sekunden statt nach
einem ganzen Level "erreicht" gewesen. Jetzt: `distance` ist der gespeicherte
Rohwert, `score()` eine abgeleitete Funktion - wortgleich zum JS-Original.

**Dritte GDScript-Falle**: `min()`/`max()` sind generische Builtins und geben
bei `:=`-Deklaration ebenfalls einen nicht inferierbaren Variant-Typ zurueck
(exakt derselbe stille Haenger wie bei Dictionary-Feldern) - auch hier immer
`: float =` statt `:=`.

**Soak-Ergebnis (voller Mix, siehe `godot/tests/soak_test.gd`)**: der in
Phase 1 isolierte Kaktus-Dichte-Fund bestaetigt sich als Ursache, aber die
tatsaechliche Rate faellt mit dem vollen Hindernis-Mix auf 20-22 Tode pro
1800 simulierten Sekunden (zwei Seeds, ausschliesslich bei Hoechsttempo
960, ueberwiegend Kaktus) - das liegt innerhalb der historisch akzeptierten
Rate des JS-Originals ("2-9 Abstuerze pro 5 Minuten" als Normalfall, siehe
Fledermaus-Wobble-Bug 1.24 in ../CHANGELOG.md). Hoehlen-Modus
(`cave_on=true`): **0 Tode in 1800s** bei allen 6 Hindernisarten inkl.
Tropfstein/-saeule - dort gilt die 0.72-Dichte-Untergrenze nicht (nur
ausserhalb der Hoehle), was die Diagnose zusaetzlich stuetzt. Bewertung:
keine neue Regression durch die Portierung, sondern eine bereits im
JS-Original akzeptierte Grundrate, die in der Kaktus-Monokultur von Phase 1
nur ueberproportional sichtbar wurde.

**Phase 3 (Rendering + echte Steuerung)**: fertig - **das erste tatsaechlich
spielbare Godot-Build**. `godot/scripts/game_view.gd` verbindet `hopper_sim.gd`
erstmals mit echtem Rendering (`_draw()`, schlichte Formen/Farben statt
Kunst - Grafik-Feinschliff ist Phase 4) und echter Eingabe (Tastatur:
Leertaste/Hoch/W springen inkl. `JUMP_CUT`-Kurztipp-Verhalten, Runter/S
ducken; Touch: oberes Drittel tippen = springen, unteres Drittel halten =
ducken, analog zum Original). Wueste/Hoehle wechseln automatisch bei
Erreichen von `CAVE_START` (vereinfacht: sofortiger Wechsel statt der
Cutscene/Torbogen-Optik aus dem Original - das ist reine Optik, spaeter
nachrollbar). `rockNoise()` (deterministische Ganzzahl-Hash-Funktion fuers
Nicht-Schwimmen von Hoehlentexturen beim Scrollen) ist portiert, aber noch
nicht fuer Detailtexturen verdrahtet - das kommt mit dem Grafik-Feinschliff
in Phase 4.

Zur Selbstverifikation (ich kann kein natives Fenster sehen): ein Kopflos-
JA-aber-mit-echtem-Rendering-Trick - `godot --path <projekt> -s
res://tests/screenshot_test.gd` (ohne `--headless`, das deaktiviert die
GPU-Rendering-Pipeline komplett) laesst das Spiel ein paar hundert Frames
laufen und speichert `get_viewport().get_texture().get_image()` als PNG.
Damit direkt einen echten, kleinen Darstellungsfehler gefunden: die
HUD-Schrift war in der Hoehle dunkel auf dunklem Himmel praktisch
unsichtbar (fixed: heller Kontrastwert, wenn `cave_on`). Ausserdem verifiziert:
`jump()`/`end_jump()` (neue, echte Spieler-Eingabe-API neben dem bisherigen
internen Bot-Pfad) reproduzieren exakt die im JS-Original dokumentierten
Sprunghoehen (voller Sprung ~120, kuerzester Tipp ~65 - Basiswert im
JS-Kommentar: "kuerzester Tipp erreicht 65").

**Nachtrag (echtes Geraet):** Ducken per Touch funktionierte auf dem
Handy nicht. Ursache: `_handle_input()` rief JEDEN Physik-Frame
bedingungslos `sim.set_ducking(false)`, sobald keine Taste gedrueckt war -
das ueberschrieb den Touch-Zustand aus dem Touch-Event-Handler sofort
wieder, weil `InputEventScreenTouch` nur einmal beim Druecken/Loslassen
feuert, nicht laufend waehrend des Haltens (Event-basiert vs. Poll-basiert
schrieben in dieselbe Variable). Fix: Touch setzt nur noch ein
`touch_duck_held`-Flag, `_handle_input()` ist die EINZIGE Stelle, die
`sim.ducking` setzt (als ODER aus Tastatur- und Touch-Zustand), einmal pro
Frame. Lehre fuer kuenftigen Godot-Eingabecode hier: nie Event- und
Poll-basierte Schreibzugriffe auf denselben gehaltenen Zustand mischen.

**Phase 4 (HDR2D + Glow - der eigentliche Grund fuer den Umstieg)**: fertig.
`_setup_environment()` in `game_view.gd` aktiviert `Environment.BG_CANVAS` +
Glow (`viewport/hdr_2d=true` zusaetzlich in `project.godot` noetig, sonst
wirkungslos). Gift-Geschoss und Kristall-Kaktus (Hoehle) bekommen HDR-Farben
(Kanalwerte &gt; 1.0 - loesen den Bloom tatsaechlich aus) statt der bisherigen
flachen Farben: `_draw_poison()` zeichnet einen weichen neongruenen
Glow-Halo + Kometenschweif + hellen Kern, `_draw_crystal()` einen
facettierten, blau leuchtenden Diamanten statt der flachen gruenen Box aus
Phase 3. Per Screenshot-Trick verifiziert - beide zeigen einen klar
sichtbaren, weichen Leucht-Halo um die Form. Zusaetzlich: ein echtes
`GPUParticles2D` fuer Sprung-/Landestaub (statt selbst gemalter Partikel -
lohnt sich hier, weil ein einzelner wiederverwendeter Knoten reicht, kein
Verwaltungsaufwand pro Hindernis wie bei Gift/Kristall). Funktioniert,
sichtbar aber noch klein/schlicht (6x6-Platzhaltertextur) - Feinschliff
bei Bedarf spaeter.

Bewusste Design-Entscheidung (siehe Recherche vor der Migration): Glow via
HDR2D+WorldEnvironment statt eines SubViewport mit echter 3D-Szene - liefert
denselben "leuchtet wirklich"-Eindruck bei deutlich weniger Aufwand/
Verwaltung, ohne die 2D-Physik/Kollision anzufassen.

**Phase 5 (Audio - 100% synthetisiert, keine Audiodatei)**: fertig.
`scripts/audio_synth.gd` erzeugt Wellenformen (Sinus/Rechteck/Saegezahn/
Dreieck mit exponentiellem Frequenz-Sweep, plus gefiltertes Rauschen per
Biquad-Bandpass) als `AudioStreamWAV` im Speicher - wortgleiches Prinzip zu
web/index.html (`tone()`/`noise()` ueber WebAudio), aber als einmal
generierte Clips statt Echtzeit-Oszillatoren. `scripts/sfx.gd` (Autoload
"Sfx") haelt alle 8 Sounds aus dem Original (jump/land/duck/point/die/ui/
equip/enter, gleiche Frequenzen/Dauer/Lautstaerken) plus den
Hoehlen-Echo-Effekt (`withCaveEcho()`-Aequivalent: zweites, leiseres
Abspielen 110ms spaeter, nur wenn `cave_on`). `scripts/music.gd` ist ein
einfacher Sequencer (126bpm, 4 Akkorde + Bass + Hi-Hat) - bewusst NICHT
notengetreu zum Original (die exakte Notenfolge liess sich aus dem
archivierten Kommentar nicht rekonstruieren, nur der Stil), rein kosmetisch
also unkritisch. `game_view.gd` loest die Sounds ueber Flankenerkennung aus
(Sprung/Landung ueber `on_ground`-Wechsel, Ducken nur auf der steigenden
Flanke, Punkte-Sound bei jeder vollen 100er-Schwelle, Musik nur bei echter
Steuerung wie im Original - nicht im Bot-/Testmodus).

**Neue Testmodus-Falle gefunden**: Autoloads (hier "Sfx") werden im
`-s script.gd`-Kopflosmodus NICHT initialisiert - anders als beim normalen
Start ueber `run/main_scene`. Ein Testskript, das `game_view.gd` direkt
instanziiert, bekommt einen COMPILE-Fehler ("Identifier not found: Sfx"),
nicht nur einen leeren Autoload. Verifiziert wurde das echte Bootstrapping
deshalb mit `godot --path <projekt> --quit-after 200` (kein `-s`, laedt
main.tscn ganz normal inkl. Autoloads) - lief fehlerfrei durch. Fuer
kuenftige Phasen mit Autoload-Abhaengigkeiten (z.B. Menues in Phase 6)
denselben `--quit-after`-Trick statt `-s` verwenden, sobald Autoloads
gebraucht werden.

Da ich selbst nichts hoeren kann: die Sounds sind per Code-Review + einer
Bytegroessen-/Fehlerfreiheits-Pruefung verifiziert (korrekte Sample-Anzahl,
kein Absturz beim echten Abspielen), nicht per Gehoer. Rueckmeldung vom
User noetig, ob sich das auf dem Geraet gut anhoert.

**Phase 6 (Garderobe/Menues/Persistenz/Attract-Modus-UI)**: fertig.
Neue Schicht `scripts/app.gd` (Screen-/Menue-Zustandsmaschine: menu/
wardrobe/settings/paused/over/game), sitzt strikt ueber `game_view.gd`
(das nichts von Bildschirmen/Menues weiss) und steuert es nur ueber dessen
oeffentliche API/Signale. `scripts/save_data.gd` (Autoload "Save")
persistiert Highscores (Wueste/Hoehle getrennt), Einstellungen (Musik/SFX/
Shake/Tageszyklus/Start-in-Hoehle) und Garderobe (Form/Farbe/Hut) als JSON
unter `user://save.json`. **Bewusste Produktentscheidung**: keine Migration
alter WebView-`localStorage`-Spielstaende - anderes Paket, andere Speicher-
form, fuer ein paar Ganzzahlen nicht lohnend (User-Entscheidung, nicht
stillschweigend festgelegt).

Dabei einen echten Modellierungsfehler aus Phase 3 korrigiert: die Wueste
ging bisher nahtlos/automatisch in die Hoehle ueber (`cave_on` wurde einfach
bei Erreichen von `CAVE_START` umgeflippt). Im JS-Original endet die Wueste
dort stattdessen distinkt ("Level geschafft", `completeLevel()`), und die
Hoehle ist ein SEPARATER Lauf mit zurueckgesetztem Tempo/Score. Jetzt hat
`hopper_sim.gd` ein `cleared`-Feld (analog zu `dead`, `step()` haelt darauf
an), `game_view.gd` sendet ein `cleared`-Signal, `app.gd` zeigt einen
eigenen "Level geschafft"-Bildschirm (statt Game Over) und schaltet die
Hoehle frei (`Save.unlock_cave()`).

Zwei echte Bugs beim Schreiben gefunden und behoben (nicht erst beim
Testen): (1) `LOOK_COLORS["auto"]` ist absichtlich `null` - eine direkte
Zuweisung in eine `Color`-typisierte Variable haette bei "auto"-Farbe zum
Absturz gefuehrt, gefixt durch einen Zwischenschritt mit expliziter
Null-Pruefung. (2) `_show()` setzte `frozen` anfangs unbedingt auf `false`,
was den laufenden Lauf faelschlich entpausiert haette, sobald man aus den
Einstellungen zurueck zur Pause navigiert - jetzt `frozen = (name ==
"paused")`.

Verifiziert: Regressions-Soak (1800s Wueste, 900s Hoehle) bestaetigt, dass
der neue `cleared`-Mechanismus die Fairness nicht veraendert (28
"geschafft"-Ereignisse + nur 3 Tode in der Wueste, 0 Tode in der Hoehle -
im Rahmen der bisherigen Werte). Echter Bootstrap-Lauf
(`godot --path godot --quit-after 200`, keine Autoload-Compile-Fehler) und
eine visuelle Pruefung aller 6 Bildschirme per Screenshot-Trick (Menue,
Garderobe, Einstellungen, laufendes Spiel, Pause, Game Over/"geschafft")
zeigen korrektes Layout, lesbaren Text und richtige dynamische Inhalte
(Sperrzustand des Hoehlen-Buttons, "Neuer Rekord!"-Anzeige, Button-Text-
Wechsel je nach Kontext).

**Phase 7 (finaler Soak-Test + echte Paket-ID-Umstellung + erster echter
Release)**: fertig. Finaler Regressions-Soak vor der Umstellung: je 3600s
Wueste UND Hoehle, drei Seeds (1/2/3) - Wueste 7-11 Tode/3600s (deutlich
unter der historisch akzeptierten Rate), Hoehle 0 Tode/3600s bei allen
Seeds, "geschafft"-Mechanik feuert stabil (52-55x/Lauf) ohne die Fairness
zu beeinflussen, Reaktionsfenster/Hoehen-Clearance unveraendert gegenueber
allen frueheren Phasen - keine Regression durch Phase 6.

**Paket-ID-Umstellung**: `com.daniel.hopper.godot` -> `com.daniel.hopper`
(dieselbe ID wie die aktuell shippende WebView-App), Label
"HopperBootstrap" -> "Hopper", Version 0.6(7) -> 2.0(34) - bewusst ueber
der WebView-Versionscode 33, damit eine Installation als Update ueber die
bestehende App funktioniert statt als Downgrade abgelehnt zu werden.
Verifiziert per `apksigner verify --print-certs`: identisches
Signatur-Zertifikat (SHA-256-Fingerabdruck) wie die WebView-APK, da
beide denselben geteilten `apk-builder`-Release-Keystore nutzen -
**diese Godot-APK installiert sich auf einem Geraet mit der bestehenden
Hopper-App als direktes Update, nicht parallel** (siehe Warnhinweis beim
Ausliefern).

**App-Icon nachgezogen** (explizite Nutzer-Entscheidung: jetzt statt
spaeter): Godots Android-Export ohne Custom-Gradle-Build akzeptiert nur
Raster-PNGs fuer `launcher_icons/*`, kein Vector-Drawable-XML wie beim
WebView-Build. Das bestehende `hopper/icon.xml` (Android Vector Drawable)
wurde 1:1 als SVG uebertragen (Android-`pathData` und SVG-Pfadsyntax sind
kompatibel, reine Attribut-Umbenennung) und per einmaligem Dev-Skript
(`godot/tests/render_icon.gd`, nutzt `Image.load_svg_from_string()` -
reine CPU-Rasterung, funktioniert auch `--headless`) zu den drei von Godot
geforderten PNGs gerendert (Vordergrund/Hintergrund fuer das adaptive
Icon, plus ein zusammengesetztes Legacy-Icon). Verifiziert durch
Entpacken der fertig gebauten APK und Sichtpruefung des tatsaechlich
gepackten Icons (nicht nur der Quelldateien) - zeigt korrekt die
Laeufer-Silhouette auf orangem Grund, kein Godot-Standard-Icon mehr.
`export_filter`/`exclude_filter` in `export_presets.cfg` zusaetzlich
verschaerft, damit `tests/` (Dev-/Soak-Skripte) und die SVG-Icon-Quelle
nicht mehr mit in die shippende APK gepackt werden.
