# Hopper

Endless Runner als reine Web-App, die per [apk-builder](../apk-builder)
zu einer Android-APK wird. Laeuft komplett offline, ohne Abhaengigkeiten,
alles in einer Datei (`web/index.html`). Stand: **1.56** (versionCode 61).

Diese README ist die **aktuelle Referenz**. Weitere Dokumente:

- [CLAUDE.md](CLAUDE.md) - Arbeitsanleitung (Bauen, Testen, Konventionen)
- [CHANGELOG.md](CHANGELOG.md) - chronologisches Entwicklungsprotokoll mit
  allen Begruendungen, verworfenen Versuchen und Soak-Messungen
- [godot/README.md](godot/README.md) - archivierte Godot-Portierung
  (Phase 0-7). Seit V17 ist wieder die WebView-Version aktiv, Godot wirkte
  im Vergleich "wie aus der Steinzeit"; der Code bleibt im Repo.

## Spielinhalt

Drei getrennte Level mit je eigenem Bestwert. Ein Level wird im Menue
gewaehlt, sobald es freigeschaltet ist:

| Level | Ziel | Hindernisse |
|---|---|---|
| 1 Wueste | Fortschritt in Prozent, 100% bei Rohscore 3000 (`CAVE_START`) -> schaltet die Hoehle frei | Kaktus-Gruppen, Voegel (drei Hoehen), Schlangen; seltene Bergabschnitte nur mit rollenden Felsen |
| 2 Hoehle | Punkte; bei 4000 (`LAVA_START`) -> schaltet die Lavahoehle frei | Kristallzacken (Kaktus-Hitbox), Fledermaeuse (Schwarm, fliegen aktiv zu), Haengespinne (Duck-Fenster), Stalaktit (nicht springen), Tropfsteinsaeule (ducken) |
| 3 Lavahoehle | Punkte, offenes Ende | wie Level 2, mit Glut-/Lava-Optik |

Die Schwierigkeit steigt ueber Rampen statt harter Schwellen (`rampChance`).
Die Hoehlendecke ist reine Optik ohne Kollision. Ein Levelabschluss laeuft
ueber eine Einlauf-Sequenz (Torbogen, schwarze Blende), in der man nicht
sterben kann.

**Test-Trick**: 5x schnell (< 1,5 s) auf eine gesperrte Level-Kachel tippen
schaltet sie frei.

## Muenzen und Shop

Muenzen liegen immer auf dem Boden (nie in Sprunghoehe) und kommen etwa alle
1800-3000 Welteinheiten. Eine Muenze gibt +25 auf den Lauf-Score und +1 auf
die dauerhafte Waehrung `totalCoins` - nur im echten Spiel, nicht im
Vorfuehrmodus des Menues.

Im Shop werden Garderobe-Teile freigeschaltet (`unlocked`), getragen wird
dann ueber die Garderobe (`look`). Von Anfang an frei: Hund, Farbe
"Standard", ohne Kopfbedeckung. Preise: Katze 35, Hase 55, jede Farbe 20,
jede Kopfbedeckung 25.

## Speicher (localStorage)

| Key | Inhalt |
|---|---|
| `hopper.settings` | Musik, SFX, Ruckeln, Tag/Nacht, gewaehltes Level (`startCave`/`startLava`) |
| `hopper.look` | getragene Form, Farbe, Kopfbedeckung |
| `hopper.unlocked` | im Shop freigeschaltete Teile |
| `hopper.coins` | Muenzstand |
| `hopper.highscore` / `hopper.last` | Level 1 |
| `hopper.cave.highscore` / `hopper.cave.last` | Level 2 |
| `hopper.lava.highscore` / `hopper.lava.last` | Level 3 |
| `hopper.caveUnlocked` / `hopper.lavaUnlocked` | Freischaltungen |

"Bestwerte zuruecksetzen" in den Einstellungen setzt alle sechs
Highscore-/Last-Keys zurueck, nicht aber Muenzen oder Freischaltungen.

## Bauen

```powershell
cd "D:\claude code projects\apk-builder"
.\new-app.ps1 -Name Hopper -PackageId com.daniel.hopper `
              -WebRoot "D:\claude code projects\hopper\web" `
              -Icon "D:\claude code projects\hopper\icon.xml" `
              -IconBackground "#E4703A" `
              -VersionName "1.56" -VersionCode 61 -Force
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

Verlaesst man die App waehrend eines Laufs (Home-Taste, Anruf), pausiert er
automatisch (`visibilitychange`).

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

Hindernis-Groessen und -Hoehen (Stalaktit-/Saeulenspitzen, Schlangenbreite,
Felsdurchmesser, Fledermaus-Hoehenstufen) sind aus `hits()` und der
Sprungphysik hergeleitet und per Autopilot-Soak verifiziert - die Grenzwerte
stehen jeweils im Kommentar an der Konstante. Tempo oder Dichte nie
aendern, ohne erneut zu messen (siehe CLAUDE.md, "Fairness").

## Ton

Sound und Musik werden zur Laufzeit mit der Web Audio API synthetisiert -
die App bringt **keine** Audiodateien mit. Das haelt die APK klein, passt
zur fehlenden INTERNET-Berechtigung und hat kein Lizenzproblem.

Die Musik ist ein kleiner Sequencer mit Vorausplanung: Noten werden anhand
der Audio-Uhr (`AC.currentTime`) 140 ms im Voraus gelegt, weil `setInterval`
allein fuer Timing zu ungenau ist. Vier Akkorde in A-Moll-Pentatonik, dazu
Bass, Kick, Hi-Hat und ein Arpeggio. In der Hoehle bekommen Sprung, Landung
und Tod ein leises Echo (`withCaveEcho`).

Browser starten Audio erst nach einer Nutzergeste - `audioInit()` haengt
deshalb an der ersten Beruehrung und an jedem Menueknopf.

## Menue

Das Menue ist ein HTML-Overlay ueber dem Canvas, kein gezeichnetes UI:
echte Touch-Ziele und kein Hit-Testing von Hand.

Die Oberflaeche wandert mit derselben Zahl (`night`) mit wie die Spielwelt.
Wichtig dabei: **jeder** Wert wird interpoliert, Deckkraft eingeschlossen
(`UI_DAY` / `UI_NIGHT` plus `mixRgba`). Eine frueher benutzte Schwelle
(`t > 0.5 ? dunkel : hell`) liess Panel, Rahmen und Knoepfe mitten im
Uebergang hart umschlagen. In der Hoehle ist es immer Nacht.

`applyTheme` schreibt die CSS-Variablen nur bei einer Aenderung ueber
0,02 - sonst laeuft waehrend des Uebergangs 60-mal je Sekunde ein
Style-Recalc ueber das ganze Dokument.

### Liquid-Glass

Panel, Eckknoepfe, Schalter und Kacheln sind durchscheinendes Material:
`backdrop-filter: blur(26px) saturate(185%)`, eine helle Lichtkante oben
(inset box-shadow) und ein diagonaler Glanzstreifen (`::after`,
`mix-blend-mode: overlay`, `pointer-events: none`). Nur `.panel` traegt den
vollen Blur - ein zweiter Blur-Layer ueber dem 60fps-Canvas waere spuerbar
teuer. Die Glas-Fuellung braucht nachts eine eigene, dunklere Farbe (ein
heller Schleier ergab ueber dem Nachthimmel nur ~2:1 Kontrast), deshalb
tragen `UI_DAY`/`UI_NIGHT` auch `glassFill`/`glassBtn`/`glassSoft`/`rimTop`/
`rimBot`/`sheen`. `@supports not (backdrop-filter: blur(1px))` faellt auf
einen blickdichten `--solidPanel` zurueck, der ebenfalls Tag/Nacht folgt.

## Garderobe

Drei Formen (Hund, Katze, Hase - nur Ohren und Schwanz unterscheiden sich),
acht Farben und fuenf Kopfbedeckungen. Die Farbe `auto` folgt dem Tag- und
Nachtthema; die sieben festen Farben haben bewusst mittlere Helligkeit, damit
sie auf hellem **und** dunklem Grund lesbar bleiben. Gesperrte Teile sind
gedimmt und tragen ein Schloss.

Die Figur wird von genau einer Funktion gemalt (`paintRunner`), die ihren
Zielkontext als Argument bekommt - einmal ins Spielfeld, einmal in die
kleine Vorschau der Garderobe. Deshalb sitzen Muetzen in beiden Ansichten
gleich. Die Zeichenhelfer nutzen dafuer die Variable `G` als aktuellen
Kontext; wer eine neue Form ergaenzt, sollte `G` benutzen und nicht `ctx`.

## Vorfuehrmodus

Hinter dem Menue laeuft das Spiel mit Autopilot weiter (`state.attract`).
Der Vorfuehrmodus darf nichts Dauerhaftes veraendern (keine Muenzen, keine
Bestwerte, keine Freischaltungen) und keine Spiel-Sounds abspielen.
`autoPilot()` hat zwei Eigenheiten, die nicht wegoptimiert werden sollten:

- Ein Hindernis bleibt relevant, bis es die Figur **ganz** passiert hat.
  Ein Abbruch nach der Vorderkante liess die Figur sich mitten im 38
  Einheiten breiten Vogel wieder aufrichten.
- Der Absprungzeitpunkt haengt von Hindernisbreite und Tempo ab, nicht von
  einem festen Abstand. Bei einer Dreiergruppe reicht die Luftzeit sonst
  nicht bis zur Hinterkante.

Der Autopilot ist zugleich das Messwerkzeug fuer Fairness-Soaks (siehe
CLAUDE.md).

## Zurueck-Taste

Die Android-Zurueck-Taste fuehrt ins Menue statt die App zu beenden. Dafuer
legt `pushAway()` einen `history.pushState` an - die WebView-Activity ruft
dann `goBack()`, was `popstate` ausloest. Es gibt hoechstens EINEN solchen
Eintrag (Spiel, Garderobe, Shop, Einstellungen teilen ihn), und die
In-App-Zurueck-Knoepfe bauen ihn ueber `leaveToMenu()` -> `history.back()`
wieder ab. Einstellungen aus der Pause heraus: Zurueck fuehrt wieder in die
Pause.

Offen: Die Zurueck-**Wischgeste** (Predictive Back, targetSdk 36) umgeht
`onKeyDown` und schliesst die App direkt. Der Fix aus breathe-well/ice-breath
braucht einen eigenen `build.ps1`-Wrapper, den Hopper nicht hat (siehe
`apk-builder/CLAUDE.md`, "Bekannte Stolperstellen").

## Stolperfallen im Menue-Code

**Staffelung der Bedienelemente.** `.overlay` deckt mit `inset: 0` den ganzen
Bildschirm ab und steht im DOM hinter den Eckknoepfen. Ohne `z-index`
(Overlay 10, Knoepfe 20) faengt es deren Klicks ab - das Zahnrad war dadurch
sichtbar, aber tot. Wer hier etwas ergaenzt, sollte den Klickweg pruefen und
nicht nur den Handler aufrufen:

```js
var r = el.getBoundingClientRect();
var hit = document.elementFromPoint(r.left + r.width/2, r.top + r.height/2);
// hit muss el oder ein Kind davon sein
```

**Scrollen in den Menues.** `touch-action` eines Elternelements
**beschraenkt alle Nachkommen**. Solange `body` auf `touch-action: none`
stand, liess sich ein Menue auch mit eigenem `pan-y` nicht scrollen. Die
Sperre gehoert deshalb auf `canvas#c`, nicht auf `body`:

```css
html, body { overscroll-behavior: none; }      /* kein Ueberziehen */
canvas#c   { touch-action: none; }             /* Spielgesten abfangen */
.panel     { touch-action: pan-y; overflow-y: auto; }
```

Am Desktop faellt das nicht auf, weil dort mit dem Mausrad gescrollt wird.

**Was in den Einstellungen anhaelt.** Nur ein echtes Spiel wird eingefroren.
In der Lobby laeuft der Vorfuehrmodus weiter, auch waehrend die
Einstellungen offen sind - sonst steht die Szene dahinter ploetzlich still,
was wie ein Absturz aussieht:

```js
var frozen = !state.attract && (screen === "paused" || screen === "settings");
```

**Dunkler Modus des Systems.** Die App faerbt sich selbst und laesst sich vom
System nicht umfaerben; das Template von `apk-builder` schaltet dafuer "Force
Dark" ab. Der Tag- und Nachtwechsel im Spiel ist davon unabhaengig.
