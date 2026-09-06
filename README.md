# Hopper

Endless Runner als reine Web-App, die per [apk-builder](../apk-builder)
zu einer Android-APK wird. Laeuft komplett offline, ohne Abhaengigkeiten,
alles in einer Datei.

## Bauen

```powershell
cd "D:\claude code projects\apk-builder"
.\new-app.ps1 -Name Hopper -PackageId com.daniel.hopper `
              -WebRoot "D:\claude code projects\hopper\web" `
              -Icon "D:\claude code projects\hopper\icon.xml" `
              -IconBackground "#E4703A" `
              -VersionName "1.4" -VersionCode 5 -Force
.\build-apk.ps1 -App Hopper -Release
```

`-VersionCode` bei jeder Auslieferung hochzaehlen, sonst sind zwei
verschiedene APKs fuer Android nicht unterscheidbar.

Das Icon liegt bewusst **neben** `web\`, nicht darin - sonst wanderte es
zusaetzlich als Web-Asset in die APK.

## Steuerung

| | Handy | Tastatur |
|---|---|---|
| Springen | tippen, laenger halten = hoeher | Leertaste / Pfeil hoch |
| Ducken | unteres Drittel halten | Pfeil runter |
| Pause | Knopf oben links | Esc oder P |

## Physik

Die Werte stehen als Konstanten oben in `web/index.html`. Zwei davon sind
nicht frei waehlbar, sondern erprobt:

- `JUMP_CUT_MIN = -520` begrenzt, wie stark das Loslassen den Sprung
  abbricht. Ohne die Grenze kam ein sehr kurzer Tipp nur 43 Einheiten hoch
  und blieb am groessten Kaktus (50) haengen - ein schneller Tipper war
  garantiert toedlich. Mit der Grenze sind es 65. Wer den Wert aendert,
  sollte gegen die Gegnerhoehen nachmessen.
- `COYOTE_TIME` und `JUMP_BUFFER` erlauben den Sprung kurz nach dem
  Verlassen des Bodens bzw. kurz vor der Landung. Beide fallen nur auf,
  wenn sie fehlen.

Aufsteigen und Fallen nutzen unterschiedliche Schwerkraft (`GRAV_UP` /
`GRAV_DOWN`); symmetrische Schwerkraft fuehlt sich schwammig an.

## Ton

Sound und Musik werden zur Laufzeit mit der Web Audio API synthetisiert -
die App bringt **keine** Audiodateien mit. Das haelt die APK klein, passt
zur fehlenden INTERNET-Berechtigung und hat kein Lizenzproblem.

Die Musik ist ein kleiner Sequencer mit Vorausplanung: Noten werden anhand
der Audio-Uhr (`AC.currentTime`) 140 ms im Voraus gelegt, weil `setInterval`
allein fuer Timing zu ungenau ist. Vier Akkorde in A-Moll-Pentatonik, dazu
Bass, Kick, Hi-Hat und ein Arpeggio.

Browser starten Audio erst nach einer Nutzergeste - `audioInit()` haengt
deshalb an der ersten Beruehrung und an jedem Menueknopf.

## Menue

Das Menue ist ein HTML-Overlay ueber dem Canvas, kein gezeichnetes UI:
echte Touch-Ziele und kein Hit-Testing von Hand.

Die Oberflaeche wandert mit derselben Zahl (`night`) mit wie die Spielwelt.
Wichtig dabei: **jeder** Wert wird interpoliert, Deckkraft eingeschlossen
(`UI_DAY` / `UI_NIGHT` plus `mixRgba`). Eine frueher benutzte Schwelle
(`t > 0.5 ? dunkel : hell`) liess Panel, Rahmen und Knoepfe mitten im
1,8 Sekunden langen Uebergang hart umschlagen, waehrend der Hintergrund
schon halb gewechselt war.

`applyTheme` schreibt die CSS-Variablen nur bei einer Aenderung ueber
0,02 - sonst laeuft waehrend des Uebergangs 60-mal je Sekunde ein
Style-Recalc ueber das ganze Dokument.

## Garderobe

Acht Farben und fuenf Kopfbedeckungen, gesichert in `localStorage`. Die
Farbe `auto` folgt dem Tag- und Nachtthema; die sieben festen Farben haben
bewusst mittlere Helligkeit, damit sie auf hellem **und** dunklem Grund
lesbar bleiben.

Die Figur wird von genau einer Funktion gemalt (`paintRunner`), die ihren
Zielkontext als Argument bekommt - einmal ins Spielfeld, einmal in die
kleine Vorschau der Garderobe. Deshalb sitzen Muetzen in beiden Ansichten
gleich. Die Zeichenhelfer nutzen dafuer die Variable `G` als aktuellen
Kontext; wer eine neue Form ergaenzt, sollte `G` benutzen und nicht `ctx`.

Dahinter laeuft das Spiel im Vorfuehrmodus weiter. Der Autopilot in
`autoPilot()` hat zwei Eigenheiten, die nicht wegoptimiert werden sollten:

- Ein Hindernis bleibt relevant, bis es die Figur **ganz** passiert hat.
  Ein Abbruch nach der Vorderkante liess die Figur sich mitten im 38
  Einheiten breiten Vogel wieder aufrichten - das war die Ursache von 21
  der 30 Zusammenstoesse in vier Minuten.
- Der Absprungzeitpunkt haengt von Hindernisbreite und Tempo ab, nicht von
  einem festen Abstand. Bei einer Dreiergruppe reicht die Luftzeit sonst
  nicht bis zur Hinterkante.

Gemessen: 15 Minuten bis Hoechsttempo, 896 Spruenge, 0 Zusammenstoesse.

Die Android-Zurueck-Taste fuehrt ins Menue statt die App zu beenden. Dafuer
legt `startGame()` einen `history.pushState` an - die WebView-Activity ruft
dann `goBack()`, was `popstate` ausloest.

## Staffelung der Bedienelemente

`.overlay` deckt mit `inset: 0` den ganzen Bildschirm ab und steht im DOM
hinter den Eckknoepfen. Ohne `z-index` (Overlay 10, Knoepfe 20) faengt es
deren Klicks ab - das Zahnrad war dadurch sichtbar, aber tot.

Wer hier etwas ergaenzt, sollte den Klickweg pruefen und nicht nur den
Handler aufrufen. `document.elementFromPoint` auf die Mitte des Elements
zeigt, was dort tatsaechlich liegt:

```js
var r = el.getBoundingClientRect();
var hit = document.elementFromPoint(r.left + r.width/2, r.top + r.height/2);
// hit muss el oder ein Kind davon sein
```

Ein Test, der `openSettings()` direkt aufruft, laeuft an genau diesem
Fehler vorbei.

## Scrollen in den Menues

`touch-action` eines Elternelements **beschraenkt alle Nachkommen**. Solange
`body` auf `touch-action: none` stand, liess sich ein Menue auch mit eigenem
`pan-y` nicht scrollen - die Ausnahme im Kind hilft nicht gegen die Sperre im
Eltern. Die Sperre gehoert deshalb auf `canvas#c`, nicht auf `body`:

```css
html, body { overscroll-behavior: none; }      /* kein Ueberziehen */
canvas#c   { touch-action: none; }             /* Spielgesten abfangen */
.panel     { touch-action: pan-y; overflow-y: auto; }
```

Am Desktop faellt das nicht auf, weil dort mit dem Mausrad gescrollt wird.

## Was in den Einstellungen anhaelt

Nur ein echtes Spiel wird eingefroren. In der Lobby laeuft der Vorfuehrmodus
weiter, auch waehrend die Einstellungen offen sind - sonst steht die Szene
dahinter ploetzlich still, was wie ein Absturz aussieht:

```js
var frozen = !state.attract && (screen === "paused" || screen === "settings");
```

## Dunkler Modus des Systems

Die App faerbt sich selbst und laesst sich vom System nicht umfaerben; das
Template von `apk-builder` schaltet dafuer "Force Dark" ab. Der Tag- und
Nachtwechsel im Spiel ist davon unabhaengig. Wer stattdessen dem Systemmodus
folgen will, kann `matchMedia("(prefers-color-scheme: dark)")` auswerten und
`night` beim Start entsprechend setzen.
