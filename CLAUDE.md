# Hopper

Endless Runner (3 Level, Muenzen, Shop) als Offline-Web-App in einer Datei,
per [apk-builder](../apk-builder) zur Android-APK. Spielinhalt, Datenmodell
und Design-Details stehen in [README.md](README.md) - dort nachlesen statt
hier duplizieren.

## Was lesen - und was nicht

Die Dateien sind gross; unnoetiges Lesen kostet viel Kontext.

- `web/index.html` (~155 KB, ~3500 Zeilen, ein Drittel Kommentare) **nie
  komplett lesen**. Stattdessen per Grep den Funktions- oder Konstantennamen
  suchen und nur den Bereich drumherum lesen. Die Abschnitte sind mit
  `// ===== Name =====`-Zeilen markiert (Grep auf `^// ===` liefert die
  aktuellen Zeilennummern), in dieser Reihenfolge: CSS/HTML-Overlays ->
  Canvas -> Farben (`DAY`/`NIGHT`, `applyTheme`) -> Einstellungen
  (localStorage-Keys, Muenzen, `unlocked`, `SHAPES`/`COLORS`/`HATS`) -> Audio
  (`SFX`) -> Musik -> Spielwerte (Physik, `newGame`) -> Hoehle (Level-
  Konstanten, `ceilingGapAt`) -> Partikel -> Hindernisse (`spawn*`,
  `obstacleGap`) -> Vorfuehrmodus (`autoPilot`) -> Update (`update`, `hits`,
  `die`, `completeLevel`) -> Zeichnen (`draw*`, `paintRunner`, `render`) ->
  Steuerung (Tastatur/Touch) -> Screens (`show`, `toMenu`, `pushAway`,
  Garderobe/Shop/Schalter, Level-Kacheln, `popstate`) -> Loop (`frame`).
- `CHANGELOG.md` (~57 KB) nur lesen, wenn die Herkunft einer konkreten
  Entscheidung gebraucht wird - dann per Grep auf Stichwort/Version.
- `godot/` ist die archivierte Godot-Portierung, fuer die aktive App
  irrelevant. Nicht anfassen, ausser der Nutzer will Godot wieder aufgreifen.

## Build & Test

Kein Build-Step fuer die Web-App. Getestet wird im Browser-Pane, aber **nur
ueber http** - `file://`/`data:` hat dort kein localStorage. Ein kleiner
Static-Server (z.B. PowerShell-`HttpListener`-Skript im Scratchpad plus
`.claude/launch.json`, danach wieder entfernen) auf `D:\claude code projects`
reicht. Es gibt keinen `?fast=1`-Modus.

Alle Top-Level-`var`s und Funktionen sind global (klassisches Script) und
per JS direkt erreichbar (`state`, `obstacles`, `SFX`, `totalCoins`, ...).
Hintergrund-Tabs pausieren `requestAnimationFrame` - Tests mit laufendem
Spiel im Vordergrund-Tab machen.

**Fairness**: Aenderungen an Tempo, Dichte, Hitboxen oder Hindernis-Groessen
per Autopilot-Soak gegenpruefen (Absturzrate nach Hindernisart, minimales
Reaktionsfenster). Vorher `window.requestAnimationFrame` auf eine No-Op
setzen, sonst kaempft die echte Spielschleife mit den manuellen
`update(dt)`-Aufrufen um denselben Zustand.

APK bauen: Befehl in README "Bauen"; `-VersionName`/`-VersionCode` bei jeder
Auslieferung hochzaehlen (Stand 1.57 / 62, siehe auch
`apk-builder\apps\Hopper\app\build.gradle.kts`) und das Beispiel in der README
mitziehen. Ergebnis landet in `apk-builder\out\`.

Nur auf dem echten Geraet (Pixel 11 Pro) pruefbar: Ruckeln/Performance,
Touch-Ducken, Zurueck-Taste und -Wischgeste, Klang.

## Konventionen

- Alles in `web/index.html` (HTML+CSS+JS inline), kein Framework, keine
  externen Abhaengigkeiten, kein Netzwerk. `icon.xml` liegt bewusst neben
  `web/`.
- **Kein WebGL** - lief im Desktop-Test sauber, ruckelte auf dem Geraet stark.
- Kommentare auf Deutsch, Umlaute als ae/oe/ue, und sie erklaeren das
  **Warum** (inkl. verworfener Varianten). Diesen Stil beibehalten.
- Zeichenhelfer malen ueber `G` (aktueller Kontext), nicht fest ueber `ctx`.
- Der Vorfuehrmodus (`state.attract`) darf nichts Dauerhaftes aendern und
  keine Spiel-Sounds abspielen.
- Neue localStorage-Felder additiv mit Default einfuehren (`loadJson` uebernimmt
  nur Felder mit passendem Typ), keine stillen Migrationen.
- Doku: README bleibt die aktuelle Referenz (bei Verhaltensaenderungen
  mitziehen), nennenswerte Aenderungen zusaetzlich als kurzer Eintrag unten
  in `CHANGELOG.md`.

## Git & Release

- Jede Aenderung committen **und pushen** (`origin` = GitHub
  guushansen-pixel/hopper), Autor `guushansen`.
- Commit-Messages mit Anfuehrungszeichen ueber `git commit -F <datei>`, nicht
  `-m` (PowerShell 5.1 zerlegt sie sonst still).
- Die APK kommt als GitHub-Release-Asset, nicht ins Repo - den Upload macht
  der Nutzer selbst.
