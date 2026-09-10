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
              -VersionName "1.8" -VersionCode 11 -Force
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

## Liquid-Glass-Menue

Panel, Eckknoepfe, Schalter und Kacheln sind durchscheinendes Material statt
flacher Farbflaechen: `backdrop-filter: blur(26px) saturate(185%)`, dazu eine
helle Lichtkante oben (inset box-shadow), ein diagonaler Glanzstreifen
(`::after`, `mix-blend-mode: overlay`, `pointer-events: none`) und Knoepfe,
die auf demselben Prinzip aufbauen. Nur `.panel` traegt den vollen Blur - die
Eckknoepfe liegen bereits auf unscharfem Grund und sparen sich den eigenen
`backdrop-filter`, das waere bei einem 60fps-Canvas darunter ein zweiter,
spuerbar teurer Blur-Layer fuer kaum sichtbaren Zusatznutzen.

**Ein Fehlversuch unterwegs:** Die Glas-Fuellung (`--glassFill` etc.) sollte
zuerst themenunabhaengig bleiben, nach dem Gedanken "backdrop-filter zieht die
Farbe schon automatisch aus der Szene dahinter". Rechnerisch gepruefte, dann
verworfene Idee: derselbe halbtransparente Weissschleier ergab ueber dem sehr
dunklen Nachthimmel nur ein mittleres Grau (Panel-Luminanz ~0.42), und mit dem
hellen Nacht-Text blieb der Kontrast bei ~2,0:1 - unter brauchbaren 3:1. Die
Fuellung braucht bei Nacht also doch eine eigene, dunklere Farbe (weiterhin
durchscheinend, nur ein dunkler statt heller Schleier): `UI_DAY`/`UI_NIGHT`
tragen jetzt `glassFill`/`glassBtn`/`glassSoft`/`rimTop`/`rimBot`/`sheen`
zusaetzlich zu den bisherigen Werten. Nachkontrast damit rechnerisch ~7,9:1.

`@supports not (backdrop-filter: blur(1px))` faellt auf einen blickdichten
`--solidPanel` zurueck, der ebenfalls Tag/Nacht folgt - sonst waere der Text
in Browsern ohne Blur-Unterstuetzung bei Nacht unlesbar auf hellem Grund.

## Drei Lauffiguren

`look.shape` (`dog` / `cat` / `bunny`) waehlt eine von drei Silhouetten in
der Garderobe. Rumpf, Beine und Laufzyklus bleiben fuer alle drei identisch
(`LEGS`-Array, Koerper-Rechtecke) - nur Ohren und Schwanz unterscheiden sich,
gezeichnet von zwei eigenstaendigen Funktionen `drawEars`/`drawTail`, die
denselben Kopf- bzw. Ruecken-Referenzpunkt bekommen, den der Hund schon immer
benutzt hat. Dadurch passt jede Form ohne Sonderfaelle in beide Posen.

Zwei Luecken kamen als Feedback zurueck, nachdem die erste Fassung nur in
der stehenden Pose Ohren zeichnete:

- **Ohren fehlten komplett, sobald geduckt wurde** - das war schon beim
  urspruenglichen (einzigen) Hund so, nicht neu durch die drei Formen. Die
  Duck-Pose zeichnet jetzt fuer alle drei Formen auch Ohren.
- **Ohren/Schwanz reagierten auf nichts** - sie hatten nur den Zwei-Pixel-
  Bob aus dem Laufzyklus. Jetzt tragen sie zusaetzlich einen kleinen Ausschlag
  proportional zu `o.vy` (`Math.max(-3, Math.min(3, o.vy / 260))`), demselben
  Wert, der oben schon fuer Stauchen/Strecken benutzt wird - kein neuer
  Zustand, nur derselbe Wert an einer weiteren Stelle verwendet. Gilt auch
  fuer Ducken in der Luft (Schnellfall), das ist in diesem Spiel moeglich.

## Katzen-Redesign

Die erste Fassung der Katzenohren hatte Basis und Spitze vertauscht: das
breite Ende zeigte nach oben, die Spitze nach unten zum Kopf - ein
umgedrehtes Dreieck statt spitzer Ohren. `tri()` nimmt drei Punkte ohne
eingebaute Vorstellung von "oben"/"unten", der Fehler fiel deshalb erst beim
Hinsehen auf, nicht beim Pixel-Signatur-Test (der nur "zeichnet ohne Fehler"
und "unterscheidet sich von den anderen Formen" pruefte, nicht "sieht richtig
aus"). Jetzt liegt die breite Basis am Kopf, die Spitze zeigt weg davon.
Der Schwanz bekam denselben Blick: die Kruemmung am Ende sitzt jetzt sichtbar
versetzt ueber der Linie statt mittig draufgesetzt, damit sie wie eine
Kruemmung aussieht statt wie eine Beule.

## Zwei weitere Hindernisse: Felsen und Schlange

Spawn-Gewichtung: 16% Felsen, 16% Schlange, Rest Kaktus/Vogel wie bisher.
Kollision und Autopilot brauchten keine Aenderung - `hits()` ist eine
generische AABB-Pruefung gegen `x/y/w/h`, und `autoPilot()` behandelt jedes
Bodenhindernis, das nicht `kind === "bird"` ist, bereits gleich (Sprung,
Breiten- und tempoabhaengig ausgeloest). Neu waren nur `spawnObstacle()`
(zwei weitere Zweige), `drawRock`/`drawSnake` und die Dispatch-Zeile in
`render()`.

**Groessen sind vermessen, nicht geschaetzt** - dieselbe Methode wie bei
`JUMP_CUT_MIN`: der Autopilot ueberstand beide neuen Typen ohne einen
einzigen Abstuerze, aber er springt nie kurz ab (`doJump(true)` ohne
`endJump()`), das haette eine zu hohe/breite Kollisionsbox nie aufgedeckt.
Direkt gemessen, welche Groesse der kuerzeste Tipp (16ms) noch raeumt:

| | raeumt bis | trifft ab | Spawn-Bereich |
|---|---|---|---|
| Felsenhoehe | 54 | 56 | 40-52 |
| Schlangenbreite | 55 | 58 | 42-52 |

Wer diese Werte aendert, sollte mit derselben Methode nachmessen - ein
Hindernis natuerlich scrollen lassen (`obstacles.push(...)` einmal, dann
mehrfach `update(1/60)`, kein `x` pro Frame neu setzen), nicht die
Sprung-Scheitelhoehe mit der Hindernishoehe vergleichen. Ein erster Versuch
dazu hat genau diesen Fehler gemacht und faelschlich "trifft" gemeldet, wo
tatsaechlich "raeumt" galt.

## Rollender Fels und Bergkette

Der Fels ist jetzt ein Kreis (Bounding-Box weiterhin die Kollisionsbox) mit
zwei halbtransparenten Facetten, die sich mit ihm drehen (`o.rot`, aus
zurueckgelegter Strecke berechnet: `rot += bewegung / radius` - ein reiner
Kreis ohne Facette stuende beim Rollen optisch still).

Zusaetzlich zum normalen Weltscroll bekommt jeder Fels ein eigenes, mit der
Rollzeit wachsendes Extratempo (`ROLL_ACCEL`, gedeckelt durch
`MAX_ROLL_BONUS`) - er wird schneller, je laenger er unterwegs ist. Die
Bergkette (`drawMountains`) ist eine eigene, noch langsamere Parallaxe
(`scrollPeaks`) hinter den Duenen, mit spitzeren Gipfeln statt der weichen
Duenenkurve. Sie ist reine Kulisse - der Fels spawnt weiterhin am normalen
Hindernis-Spawnpunkt, es gibt keine animierte Bahn von einem Berggipfel
herunter in die Spur.

**Der Rollbonus veraendert die sichere Kollisionsgrenze**, deshalb war die
alte Vermessung (Blockform, keine Beschleunigung) hinfaellig und musste neu
gemacht werden - diesmal mit dem *realistischen* Rollbonus, den ein Fels
schon hat, wenn er in Spielernaehe ankommt (er startet an der echten
Spawnkante, nicht direkt neben der Figur). Kuerzester Tipp raeumt bis
Durchmesser 52, ab 56 trifft es; Spawn-Bereich 34-46 haelt Abstand.

Ein erster Messversuch ohne realistischen Rollbonus (rollT=0 direkt neben
der Figur) meldete faelschlich schon "trifft" bei Werten, die in der
echten Anfahrt sicher waren - weil ein Fels, der schon eine Weile rollt,
bis zur Naehe des Spielers bereits Bonus-Tempo aufgebaut hat und dadurch
zufaellig fast exakt im Sprungscheitel ankommt (per Trajektorien-Log
bestaetigt: Kollisionszone und Sprunghoehepunkt trafen bei t~0.22s
zusammen), nicht spaeter und ungeschuetzter wie beim Start-bei-0-Test.
