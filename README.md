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
              -VersionName "1.23" -VersionCode 26 -Force
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

## Bergabschnitte: selten, dann exklusiv Felsen

Vorher waren die Berge Dauerkulisse und Felsen einer von vier moeglichen
Hindernissen (16%). Jetzt sind Bergabschnitte ein seltenes Ereignis
(`state.mountainOn`, geplant per Score-Schwelle wie der Tag/Nachtwechsel,
Abstand 500-900 Punkte): waehrend eines Abschnitts spawnen **ausschliesslich**
Felsen, in drei Varianten (rund/glatt, kantig, rissig) und breiterer
Groessenstreuung (26-48 statt vorher 34-46). Ausserhalb eines Abschnitts
spawnt gar kein Felsen mehr. Die Bergkette blendet weich mit dem Abschnitt
ein/aus (`state.mountainVis`, unabhaengig von `running` aktualisiert, damit
sie nicht mitten im Uebergang einfriert, wenn die Figur waehrenddessen
stirbt).

**"Viele Felsen" kommt ueber die Dauer des Abschnitts (12s), nicht ueber
gefaehrlich engen Abstand.** Der erste Versuch (halber Normalabstand)
erzeugte in 10 Minuten 135 Autopilot-Abstuerze - zwei Felsen standen dann
teils naeher, als eine einzelne Sprungbahn Platz hat. Gesweept bis ein
sicherer Wert gefunden war: 0.70x Normalabstand (statt 0.60x ausserhalb)
haelt sich bei etwa 1 Absturz pro 10 Minuten, ueber die 12 Sekunden Dauer
kommen trotzdem bis zu 14 Felsen in einem Abschnitt zusammen.

Ein zweiter, unabhaengiger Fund dabei: `autoPilot()` berechnete Sprung-
Zeitpunkte bisher nur aus `state.speed`, ohne den Rollbonus eines Felsens
(`o.rollExtra`) einzurechnen. Bei einzelnen Felsen zwischen anderen
Hindernissen fiel das kaum auf; sobald **jedes** Hindernis in Folge ein
beschleunigender Fels war, summierte sich der systematische Timing-Fehler
zu wiederholten Abstuerzen. Behoben, indem die Trigger-Formel die
tatsaechliche Schliessgeschwindigkeit (`state.speed + rollExtra`) benutzt
statt nur `state.speed`.

**Ehrlich bleibt ein kleiner Rest:** Auch mit beiden Korrekturen zeigt ein
20-Minuten-Autopilotlauf noch vereinzelte Abstuerze (rund 1 pro 7
Abschnitte, ausschliesslich an Felsen) - vermutlich Restfaelle, in denen
der Autopilot (der immer nur das naechstgelegene Hindernis betrachtet,
siehe autoPilot()-Kommentar) durch Zufallsstreuung in der Taktung doch
zwei zu nah stehende Felsen erwischt. Das betrifft nur die Vorfuehrmodus-
Kulisse im Menue, nicht echte Spielsicherheit - die Kollisionsgrenze pro
Fels ist unabhaengig davon direkt vermessen (siehe oben). Weiter zu
verbessern waere ein zweites Hindernis in die Trigger-Berechnung
einzubeziehen statt nur das naechste; aktuell nicht umgesetzt.

## Schwierigkeit steigt schrittweise: erst Kaktus, dann Vogel, dann Schlange

Vorher waren Schlange (ab Score 0, 20%) und Vogel (ab Score 320, dann
sofort 24%) mit festen Schwellen gesetzt - Vogel sprang in einem Frame
von 0% auf 24%. Jetzt gibt es eine lineare Rampe (`rampChance()`): bis
`BIRD_START` (120) ausschliesslich Kaktus, danach waechst die Vogelquote
ueber `BIRD_RAMP` (280 Punkte) linear von 0 auf `BIRD_TARGET` (22%).
Schlange folgt genauso ab `SNAKE_START` (380, also nachdem der Vogel
schon eine Weile dabei ist) ueber `SNAKE_RAMP` (320) bis `SNAKE_TARGET`
(20%). Rock/Bergabschnitte sind davon unberuehrt - eigenes, exklusives
Ereignis-System (siehe oben).

Verifiziert per Stichprobe (`spawnObstacle()` viele Male bei fest
gesetztem `state.score` aufgerufen, ohne echte Zeit vergehen zu lassen):
bei Score 0 ausschliesslich Kaktus, Vogelanteil in der Rampenmitte nahe
der halben Zielquote, Schlange bleibt vor `SNAKE_START` bei 0, beide
Anteile erreichen spaeter ihre Zielquote, Vogelanteil waechst monoton
mit dem Score.

## Bergabschnitte seltener + Abstand waechst mit dem Tempo

Erster Abschnitt jetzt erst bei Score 700-900 statt 260. Wichtiger als der
Start: der Punkte-Abstand zwischen Abschnitten ist nicht mehr fest
(500-900), sondern skaliert mit `state.speed / SPEED_START` und zusaetzlich
mit einem von `state.score` abhaengigen Wachstumsfaktor (`nextMountainGap()`).

Der Grund ist nicht nur Geschmack: Score waechst proportional zum Tempo
(`score = distance/14`, `distance += speed*dt`), und das Tempo steigt uebers
Spiel von 330 auf 960. Ein **fester** Punkte-Abstand haette also spaeter im
Spiel, wo pro Sekunde mehr Punkte anfallen, einen **kuerzeren** Realzeit-
Abstand ergeben - Bergabschnitte waeren dann gegen Ende fast durchgehend
gekommen, ohne dass sich am Punkte-Abstand selbst etwas geaendert haette.
Der `speedFactor` gleicht das aus, `growth` macht den Realzeit-Abstand
zusaetzlich noch groesser statt nur konstant zu halten.

Gemessen statt angenommen: 28 Minuten Autopilot-Soak, Realzeit-Abstand
zwischen 22 aufgezeichneten Abschnitten protokolliert. Ergebnis 47.7s bis
94.7s, im Schnitt von ~74s (fruehe Haelfte) auf ~78s (spaete Haelfte)
wachsend - keine Verkuerzung, kein "nur noch Berge" am Ende.

## Zweite Stufe: die Hoehle (ab Score 2000, dauerhaft)

Anders als die Bergabschnitte kein wiederkehrendes Ereignis, sondern ein
dauerhafter Zustandswechsel (`state.caveOn`), der ab `CAVE_START` (2000)
einmal umschaltet und nie zurueck. Eine Deckenflaeche (`ceilingGapAt()`,
eine durchgehende Sinuswelle statt Segmenten wie die Duenen) schraenkt die
Sprunghoehe streckenweise ein; Stalaktiten haengen als eigener
Hindernis-Typ mit echter Kollision zusaetzlich herab. Ab Score 2000 werden
keine neuen Bergabschnitte mehr angesetzt (rollende Felsen von fernen
Gipfeln passen nicht mehr ins Bild einer Hoehle) - ein bereits laufender
Abschnitt endet aber ganz normal.

**Die Grenzwerte sind aus der Kollisionsgeometrie abgeleitet, nicht
geraten.** `hits()` misst die Kopfhoehe eines Sprungs nicht an `runner.y`
allein, sondern an `rh - runner.y` (rh = Koerperhoehe: 47 stehend, 30
geduckt) - ein erster Rechenansatz uebersah dieses `rh` und haette die
Decke faelschlich viel zu niedrig gesetzt. Real gemessene Kopfhoehen:

| Zustand | Kopfhoehe ueber Boden |
|---|---|
| Stehen/Ducken (kein Sprung) | 30-47 |
| Kuerzester Tipp-Sprung | ~112 |
| Voll gehaltener Sprung | ~169 |

`CAVE_MIN_GAP` (136) liegt bewusst zwischen 112 und 169: ein kurzer Tipp
bleibt an jeder Stelle sicher (Bodenhindernisse bleiben ueberspringbar),
ein voller Sprung nicht mehr. `CAVE_MAX_GAP` (210) liegt ueber 169 - offene
Abschnitte schraenken also gar nichts ein. Stalaktiten-Spitzen (65-105)
liegen unter 112: im Stehen/Ducken immer sicher, jeder Sprung trifft sie -
eine reine "hier nicht springen"-Zone.

**Der Autopilot haette die Hoehle unspielbar gemacht.** Er haelt Spruenge
immer voll durch (`doJump(true)` ohne `endJump()`) - Kopfhoehe ~169, ueber
`CAVE_MIN_GAP`. Erster Soak-Test: 2583 Abstuerze in 8 Minuten,
ausschliesslich an der Decke. Da ein kurzer Tipp Bodenhindernisse ebenso
sicher raeumt und unter jeder Deckenhoehe bleibt, tippt der Autopilot
jetzt in der Hoehle immer kurz statt die Deckenhoehe erst vorherzusagen
(`runner.capAt`, loest `endJump()` automatisch aus). Ergebnis: 0 Abstuerze
in einem anschliessenden 40-Minuten-Lauf durch Wueste, Berge und Hoehle.

Drei eigene Testfehler auf dem Weg, alle beim Nachpruefen aufgefallen,
nicht beim Ausliefern: eine Reihenfolge-Race (Bergabschnitt konnte im
selben Frame noch starten, in dem `caveOn` gesetzt wurde - behoben durch
Vertauschen der Pruefreihenfolge), ein Stalaktiten-Test, der das Objekt
direkt in die Kollisionszone setzte und es dann sofort wegscrollte statt
natuerlich ankommen zu lassen, und derselbe Fehler ein zweites Mal mit
falschem Zeitpunkt fuer den Sprung.

**Zeichenreihenfolge:** `drawCeiling()` muss nach Wolken/Bergen/Duenen
laufen, sonst schweben Wolken sichtbar durch massiven Fels - beim ersten
Screenshot direkt aufgefallen.

## Hoehlenstart: dauerhafte Freischaltung + Wahl in der Lobby

Sobald die Hoehle einmal in einem echten Spiel (nicht im Vorfuehrmodus)
erreicht wurde, ruft `unlockCave()` einmalig `localStorage.setItem` auf
(`hopper.caveUnlocked`). Danach erscheint in der Lobby ein Schalter
"Hoehlenstart" (`settings.startCave`, ueber den bestehenden Settings-
Speicherpfad persistiert, kein eigener Schluessel noetig).

`newGame()` prueft `settings.startCave && caveUnlocked` (beide, nicht nur
einer - ein veraltet "an" gespeicherter Schalter ohne echte Freischaltung
darf nicht wirken) und initialisiert bei Hoehlenstart direkt:
`score = CAVE_START`, `distance` passend dazu, `speed = SPEED_MAX`,
`caveOn = true`, `caveVis = 1` (kein Einblenden noetig - man startet
bewusst schon drin). Bergabschnitte bleiben dabei aus (caveOn blockiert
sie von Anfang an), Vogel-/Schlangenrampen stehen durch den hohen Score
sofort auf Zielwert - konsistent mit "man ist schon mitten im Lauf".

Der Umschalter wirkt bewusst auch auf den Vorfuehrmodus im Hintergrund
der Lobby - dadurch zeigt die Lobby-Kulisse selbst, was die Einstellung
bewirkt, statt dass man es erst im echten Spiel sieht.

Verifiziert: Freischaltung nur bei echtem Spiel (nicht im Vorfuehrmodus),
Schalter erscheint erst danach und ist anklickbar, Zustand persistiert
ueber den bestehenden Settings-Pfad, ein Hoehlenstart initialisiert
tatsaechlich mit caveOn/caveVis/Score/Tempo wie oben beschrieben, 8
Minuten Autopilot-Soak direkt ab Hoehlenstart ohne neue Abstuerze
(nutzt den bereits fuer 1.12 verifizierten Autopilot-Kurztipp-Fix von
Anfang an, nicht erst nach Erreichen der Hoehle).

## Zwei getrennte Level statt einer durchgehenden Runde

Grundlegende Umstellung: Level 1 (Wueste) endet jetzt bei Erreichen von
`CAVE_START`, statt nahtlos in Hoehleninhalte ueberzugehen - kein
`caveOn`-Umschalten mehr mitten im Lauf. `completeLevel()` ersetzt den
alten Trigger: schaltet Level 2 dauerhaft frei (`unlockCave()`, wie schon
in 1.13), schreibt Level 1s Highscore (`HIGH_KEY`/`LAST_KEY`) und setzt
`settings.startCave = true`, damit "Level 2 spielen" sofort funktioniert.
Level 2 ist ein eigener, spaeter separat gestarteter Lauf (`newGame()`
mit `settings.startCave && caveUnlocked`), der wieder bei Score 0 und
`SPEED_START` beginnt - "am Anfang wieder langsam", nicht die Fortsetzung
von Level 1s Tempo. Eigene Highscore-Schluessel (`CAVE_HIGH_KEY`/
`CAVE_LAST_KEY`), damit die beiden Level sich nicht gegenseitig
ueberschreiben.

Das Game-Over-Overlay wird fuer beide Faelle wiederverwendet (dynamischer
Titel/Button-Text: "Vorbei"/"Nochmal" bei Tod, "Level 1 geschafft!"/
"Level 2 spielen" bei Levelabschluss) statt ein zweites, fast identisches
Overlay zu pflegen.

**Sonderfall Vorfuehrmodus:** Im Hintergrund der Lobby soll kein Overlay
die Kulisse unterbrechen. `completeLevel()` prueft `state.attract` zuerst
und setzt dort weiterhin nur `caveOn = true` (die alte 1.12-Mechanik,
nur fuer die Demo reserviert) - die Lobby-Kulisse geht sichtbar von der
Wueste in die Hoehle ueber, ohne dass ein echter Levelwechsel stattfindet
oder ein Overlay aufploppt.

Vier eigene Testfehler beim Verifizieren, alle Zustandslecks zwischen
Testlaeufen in derselben Browser-Seite (keine Spielfehler): Score nur
einen statt zwei Frames vor der Schwelle gesetzt (ein Frame reichte nicht
zum Ueberschreiten), `settings.startCave`/`caveUnlocked` aus einem
vorherigen Testblock nicht zurueckgesetzt (liess `newGame(false)`
faelschlich `caveOn=true` liefern), und der `setTimeout(...,420)` in
`showLevelComplete()` (identisch zu `showGameOver()`) kann in einem rein
synchronen Testskript nicht feuern - erst mit echtem `await` im Test
bestaetigt.

## Einlauf-Sequenz statt hartem Schnitt bei Levelabschluss

Bei Erreichen von `CAVE_START` (echtes Spiel, nicht Vorfuehrmodus) springt
`completeLevel()` nicht mehr sofort auf den Levelabschluss-Bildschirm.
Stattdessen ein neuer Uebergangszustand `state.entering`
(`ENTER_DURATION` = 1,3s): eine dunkle Torbogen-Silhouette
(`drawCaveArch`) scrollt normal mit der Welt heran, die Figur laeuft
sichtbar weiter darauf zu, danach waechst eine schwarze Blende
(`drawEnterWipe`) kubisch (`t*t*t`) ueber den Bildschirm - bleibt die
ersten ~60% der Sequenz klein genug, um den Torbogen noch zu sehen, und
deckt erst in den letzten Momenten den ganzen Bildschirm ab. Ein linearer
erster Versuch (`t * 1.25`) war bei der Haelfte der Sequenz schon fast
komplett schwarz und liess kaum Zeit, den Torbogen ueberhaupt
wahrzunehmen - per Screenshot bei mehreren Zeitpunkten der Sequenz
nachjustiert.

`state.phase` bleibt waehrend der ganzen Sequenz `"running"` (Lauf-
Animation und Weltscroll laufen normal weiter, fuer den Eindruck "die
Figur laeuft tatsaechlich hinein"), nur `state.entering` sperrt Spawnen
und Kollision ab - man kann waehrend der Sequenz garantiert nicht sterben,
verifiziert mit einem absichtlich in die Kollisionszone gelegten
Hindernis. Erst nach `ENTER_DURATION` ruft es `completeLevel()` wie
zuvor auf.

Vorfuehrmodus bleibt unveraendert beim sofortigen, unauffaelligen
Uebergang (`caveOn = true` ohne Sequenz) - eine 1,3-Sekunden-Verdunklung
mitten in der Lobby-Kulisse waere dort nur eine Ablenkung.

## Hoehlentextur, Deckenhoehe entschaerft, richtiges Level-Menue (1.16)

Drei Rueckmeldungen nach 1.15 auf einmal umgesetzt.

**Textur.** `drawCeiling()` und `drawCaveArch()` waren bisher eine
einzige flache Farbe (`theme.ground`). Beide bekommen jetzt Tiefe: ein
per `ctx.clip()` auf die exakte Kontur begrenzter Tiefen-Gradient
(schwarz-transparent, oben dunkler), dazu Speckel und Risslinien aus
einer deterministischen Ganzzahl-Hash-Funktion (`rockNoise(n)`) statt
`Math.random()` - haengen an Weltkoordinaten (wie `ceilingGapAt()`
selbst), flackern also beim Scrollen nicht. Die Torbogen-Tuer bekam
zusaetzlich eine zweite Ebene: ein texturierter Steinrahmen aussen, eine
eigene dunkle Oeffnung (`#0a0c10`) innen, statt einer einzigen Flaeche.
Bewusst *nicht* `theme.groundFill` fuer den Gradienten verwendet - die
Rolle kehrt sich zwischen Tag/Nacht um (tags fast weiss, nachts fast
schwarz), waere also tags als ausgewaschen helle Deckenkante
aufgefallen. Schwarze Transparenz obendrauf auf der bewaehrten
`theme.ground`-Basis funktioniert unabhaengig vom Theme. Verifiziert per
Screenshot (Lobby-Level-Menue, Deckentextur, Torbogen waehrend der
Einlauf-Sequenz).

**Deckenhoehe.** Rueckmeldung: Hoehle fuehlt sich unfair an, man stoesst
staendig an. Ursache per Simulation der echten Sprungphysik gefunden
(nicht geraten): `CAVE_MIN_GAP = 136` hielt nur einem wirklich
frame-genauen kuerzesten Tipp (~20ms, Kopfhoehe ~115) stand - ein ganz
normaler schneller Tipp von 60-80ms erreicht bereits Kopfhoehe 143-153
und traf die Decke an den engsten Stellen. Der sichere Spielraum
zwischen "kuerzester Tipp" und "voll gehalten" (170) war mit nur 24px
viel zu knapp fuer echtes menschliches Timing. `CAVE_MIN_GAP` auf 158
angehoben: ein schneller Tipp bleibt jetzt zuverlaessig sicher, nur
laengeres Halten (ab ~100ms) trifft noch an den engsten Stellen -
genau das soll weiter bestraft werden. `CAVE_MAX_GAP` unveraendert.
Autopilot-Soak (20000 Frames, durchgehend `caveOn`) danach erneut mit
0 unerwarteten Regressionen: 3 Abstuerze in ~5,5 simulierten Minuten,
im Rahmen der schon dokumentierten Vorfuehrmodus-Grenze (Autopilot
prüft nur das naechste Hindernis).

**Level-Menue.** Der einzelne Schalter "Level 2: Hoehle" (nur sichtbar
nach Freischaltung) wird durch zwei Karten ersetzt (`.levels`-Grid,
Stil wie die bereits vorhandene Garderobe-Formauswahl): Level 1
(Wueste) und Level 2 (Hoehle) stehen immer nebeneinander, die
ausgewaehlte hat einen Rahmen (`aria-pressed`), Level 2 zeigt vor der
Freischaltung ein Schloss-Badge und ist gedimmt, Klicks darauf bleiben
dann wirkungslos. `elCaveStartRow`/`elSwCaveStart` durch
`elLvlDesert`/`elLvlCave`/`elLvlCaveLock` ersetzt, `refreshMenu()`
und die Klick-Handler entsprechend angepasst. Ein Bug dabei gefunden
und behoben: `.level .lock { display:flex }` hatte hoehere Spezifitaet
als die UA-Default-Regel fuer `[hidden]` und ueberstimmte sie, das
Schloss blieb nach Freischaltung sichtbar - behoben mit einer
expliziten `.level .lock[hidden] { display:none }`-Regel.

## Decke ist reine Optik, Stalaktiten sind die echte Gefahr (1.17)

Rueckmeldung nach 1.16: die Deckenhoehe trotz hoeherem `CAVE_MIN_GAP`
immer noch schwierig. Grundproblem war nicht mehr die Zahl, sondern das
Prinzip: die Deckenhoehe aendert sich kontinuierlich waehrend man zum
Sprung ansetzt (Sinuswelle, kein fester Wert), man stirbt also an einer
Stelle, die im Moment des Absprungs noch anders aussah - ein bewegliches
Zeitfenster statt einer sichtbaren, vorhersehbaren Gefahr. Entscheidung:
die Decke wird komplett unschaedlich, nur noch Kulisse.

Die eigene Deckenkollision in `update()` (der `state.caveVis > 0.9`-Block)
ist ersatzlos entfernt. `ceilingGapAt()` bestimmt weiterhin die Zeichnung
(`drawCeiling()`) und die Haengeposition der Stalaktiten, hat aber keine
Kollisionsbedeutung mehr - `CAVE_MIN_GAP`/`CAVE_MAX_GAP` sind jetzt reine
Optik-Werte.

Stalaktiten uebernehmen die komplette Hoehlen-eigene Gefahr: anders als
die alte Decke sind sie ortsfest und sichtbar, bevor man zum Sprung
ansetzt - man sieht sie kommen, keine Ueberraschung durch ein
Zeitfenster, das sich waehrend des Sprungs weiterbewegt. Spawn-Chance
von 0.22 auf 0.38 angehoben (frueher war die Decke selbst schon die
Hauptgefahr, jetzt tragen die Stalaktiten das allein). `STALACTITE_TIP_MAX`
bleibt bei 105, bewusst unter der Kopfhoehe des kuerzestmoeglichen Tipps
(~115) - jeder Sprung darunter ist weiterhin garantiert toedlich, kein
Entkommen durch besonders kurzes Antippen.

Verifiziert: voller Sprung unter der engsten Deckenstelle ohne
Stalaktiten bleibt am Leben (vorher toedlich); ein Stalaktit toetet
weiterhin bei jedem Sprung darunter, auch beim kuerzestmoeglichen Tipp;
Stehen/Ducken unter einem Stalaktiten bleibt sicher; Autopilot-Soak
(20000 Frames, durchgehend `caveOn`, hoehere Stalaktiten-Dichte) zeigt
mit 2 Abstuerzen in 5,6 simulierten Minuten keine Verschlechterung
gegenueber vorher.

## Grosses Hoehlen-Redesign: Wueste raus, Fledermaeuse, Stalagmiten (1.18)

Wunsch: die Hoehle soll "viel mehr wie eine Hoehle aussehen" - Wuesten-
Kulisse raus, Voegel durch Fledermaeuse ersetzen, Kaktus-Skin
ueberarbeiten.

**Kulisse.** `drawDunes()` (beide Parallax-Ebenen) und `drawMountains()`
laufen in `render()` jetzt nur noch ausserhalb der Hoehle - vorher
schauten Duenenhuegel unten aus dem "massiven Fels" heraus, weil sie
naeher am Boden liegen als die Deckenkontur reicht. `drawClouds()` und
`drawOrb()` (Sonne/Mond) waren durch die Deckenflaeche zwar schon
unsichtbar (liegen hoeher im Bild als die engste Deckenkante je reicht),
werden in der Hoehle aber trotzdem uebersprungen statt sinnlos gezeichnet.

**Feste Hoehlen-Palette statt Tag/Nacht-Zyklus.** Bisher folgten Himmel
und Boden in der Hoehle weiter `theme.skyTop/skyBot/groundFill` - bei
"Tag" draussen also ein fast weisser Boden und ein hellblauer Himmel
mitten in einer angeblich dunklen Hoehle. `CAVE_SKY_TOP`/`CAVE_SKY_BOT`
(Himmel, `drawSky()`) und ein fixer Bodenton (`drawGround()`) sorgen
jetzt dafuer, dass die Hoehle immer gleich dunkel aussieht, unabhaengig
davon, was draussen gerade scheint. Aus demselben Grund bekommen
`drawCeiling()`/`drawCaveArch()` einen neuen festen Grundton
(`CAVE_ROCK`) statt `theme.ground` - das tauscht zwischen Tag/Nacht sogar
die Rolle (tags mittelgrau, nachts hellgrau), die Decke waere also je
nach Tageszeit unterschiedlich hell gewesen. Kiesel/Trennlinie am Boden
bekommen aus demselben Grund einen fixen hellen Ton statt
`theme.dust`/`theme.soft` - die waeren nachts fast so dunkel wie der neue
feste Boden und darin verschwunden. Die "Sterne" (`drawStars()`) sind in
der Hoehle immer sichtbar statt nur nachts - lesen sich dort als Glimmer
im Gestein statt als Sternenhimmel, mit derselben Funktion/denselben
Positionen wiederverwendet statt einer zweiten Partikelart.

**Boden-Textur.** `drawGround()` bekommt in der Hoehle dieselbe
`rockNoise()`-Speckel-Technik wie die Decke (siehe 1.16), an dieselbe
Weltkoordinate (`scrollCeiling`) gehaengt, damit Boden und Decke beim
Scrollen sichtbar zusammengehoeren statt nur die Decke texturiert
auszusehen.

**Fledermaeuse statt Voegel.** `spawnObstacle()` markiert den
Vogel-Zweig in der Hoehle als `kind: "bat"` statt `"bird"` (gleiche
Spawn-Rampe/Groesse/Hoehenraster, nur die Zeichnung `drawBat()` ist neu:
spitze Lederfluegel statt Federn, kleine Ohren statt Schnabel). Die
beiden anderen `kind === "bird"`-Stellen (Flap-Timer in `update()`,
Autopilot-Klassifikation) pruefen jetzt `"bird" || "bat"`.

**Kaktus-Skin.** `drawCactus()` zeichnet in der Hoehle spitze
Felszacken/Kristallzacken statt der gruenen Kaktus-Arme - liest sich wie
ein Stalagmit, passend zu den haengenden Stalaktiten. Spawn-Logik,
Gruppierung (`count`/`cw`/`ch`/`gap`) und Kollisionsbox bleiben
unveraendert, nur `drawCactus()` verzweigt auf `state.caveOn`.

Verifiziert: Screenshot-Vergleich mit erzwungener "Nacht" draussen zeigt
eine optisch identische Hoehle (Beweis, dass die feste Palette wirklich
unabhaengig vom Zyklus ist); Autopilot-Soak (20000 Frames) zeigt alle
vier Hoehlen-Hindernisarten (`stalactite`, `cactus`, `bat`, `snake`) und
mit 2 Abstuerzen in 5,6 Minuten keine Verschlechterung; Level 1 (Wueste)
per Screenshot gegengeprueft - Sonne/Wolken/Duenen und der originale
Vogel/Kaktus-Skin unveraendert.

## Zehn weitere Hoehlen-Ideen auf einmal (1.19)

Nach dem Redesign in 1.18 alle zehn vorgeschlagenen Ideen umgesetzt statt
einzeln nachzufragen.

**Wassertropfen von der Decke.** Reine Deko, kein neues System - nutzt
das vorhandene `particles`-Array/`spawnParticle()` wieder. Ein Timer
(`state.dripIn`, Weltdistanz wie `state.spawnIn`) laesst gelegentlich
einen Tropfen an einer zufaelligen Bildschirm-x-Position genau auf der
sichtbaren Deckenkante (`ceilingGapAt()`) entstehen. Neue Partikelfarbe
`"drip"` in `drawParticles()`, mit festem Ton statt `theme.dust` (siehe
Begruendung bei `CAVE_SKY_TOP`) - ein Wassertropfen soll nicht je nach
Tageszeit draussen die Farbe wechseln.

**Tropfsteinsaeulen.** Neues Hindernis `"pillar"` - wie ein Stalaktit,
aber mit deutlich tieferer Spitze (`PILLAR_TIP_MIN/MAX` 26-36 statt
65-105). Aus der `hits()`-Formel hergeleitet: die Luecke zwischen
Steh-Kopfhoehe (47) und Duck-Kopfhoehe (30) ergibt eine Sicherheitsspanne
23-40, in der Stehen IMMER trifft und Ducken IMMER sicher ist - anders
als beim normalen Stalaktiten (sicher bei Stehen UND Ducken, nur Springen
gefaehrlich) erzwingt die Saeule also wirklich das Ducken. Nicht nur
hergeleitet, sondern mit `hits()` bei Tip-Werten 20-44 durchgetestet:
die Duck-Grenze liegt exakt bei 23, die Steh-Grenze bei 40 - der gewaehlte
Bereich 26-36 haelt zu beiden je 3-4px Abstand. Rein dekorativer
Boden-Stumpf (`o.stubH`) direkt darunter lässt es wie eine fast
geschlossene Saeule mit schmalem Spalt aussehen, ohne eine zweite
Kollisionsbox zu brauchen. Spawn ueber denselben Wuerfelwurf wie
Stalaktiten (`spawnObstacle()`), 10 Prozentpunkte davon abgezweigt.

**Leuchtmoos.** Kleine gruene Punkte direkt auf der Bodenlinie in
`drawGround()`, eigener Zufalls-Seed (`rockNoise(n*2237)`, Schritt 48)
statt des Fels-Speckel-Seeds, damit die Muster nicht synchron laufen -
einziger Farbakzent am Boden.

**Fledermausschwaerme.** `spawnObstacle()` spawnt in der Hoehle mit 30%
Chance 2-3 Fledermaeuse statt einer, alle auf derselben Hoehe (nicht
versetzt) - eine Hoehenvarianz haette die Autopilot-Klassifikation
(`o.y`-Schwellen fuer duck/jump) pro Tier unterschiedlich ausfallen
lassen koennen.

**Echo.** `withCaveEcho()` spielt denselben Klang nochmal bei 32%
Lautstaerke, 110ms verzoegert (kein echter Convolver - haette den
winzigen Synth-Ansatz gesprengt). Nur an Sprung/Landung/Tod, den drei
staendig wiederkehrenden Spiel-SFX - nicht an Menue-Klaengen.

**Kristalle.** Eigenes Array `collectibles`, nicht `obstacles` -
`hits()` ist generisch (prueft nur x/y/w/h) und laesst sich direkt
wiederverwenden, bei Treffer aber `state.bonus += 25` statt `die()`.
`state.score` ist jetzt `Math.floor(distance/14) + state.bonus` statt
nur der Distanz-Formel. Immer auf dem Boden platziert (nie in
Sprunghoehe) - ein Bonus darf niemals eine Risiko-Entscheidung
erzwingen. Erster Anlauf (Intervall 420-800 Weltdistanz) spawnte 539
Kristalle in 8 Minuten Autopilot-Soak - fuehlte sich wie ein
Dauerzustand an, nicht wie ein Fund. Grund: das Intervall ist eine feste
Distanz, aber `state.speed` waechst uebers Spiel, dieselbe Distanz kommt
also in echter Zeit immer schneller wieder (derselbe Effekt wie bei
`nextMountainGap()`, nur hier nicht extra kompensiert). Nach zwei
weiteren Messungen (900-1600 → 632 in 20 Minuten, immer noch zu dicht)
auf 1800-3000 angehoben - 335 in 20 Minuten (~alle 3,6s), fuehlt sich
nach einem echten Fund an.

**Vignette.** `drawCaveVignette()`, ein Radialverlauf zentriert auf die
Bildschirmmitte (nicht auf die Figur - die steht nah am linken Rand,
ein Kegel dort haette den ganzen rechten Bildschirmbereich mit den
Hindernissen abgedunkelt und die Fairness-Grundregel verletzt, dass man
jede Gefahr rechtzeitig sehen muss). Nur die Ecken werden dunkler, der
komplette Spielbereich bleibt hell genug.

**Lavaschein.** `drawCaveGlow()`, ein langsam pulsierender
(`state.time`-basiert) warmer Gradient am unteren Bildrand - einziger
Warmton in einer sonst reinen Grau/Schwarz-Palette.

**Hoehlenmalereien.** Seltene, blasse Strich-Glyphen direkt in
`drawCeiling()` ergaenzt (dieselbe geclippte Flaeche, dieselbe
`rockNoise()`-Technik wie Speckel/Risse, aber mit deutlich groesserem
Schritt/niedrigerer Wahrscheinlichkeit, damit sie selten bleiben).

**Spinnennetze.** `drawCobwebs()`, feste Bildschirmposition in den
oberen Ecken (kein Weltbezug, scrollt nicht mit).

Alle zehn greifen ausschliesslich bei `state.caveOn` - Level 1 (Wueste)
unveraendert. Verifiziert: `hits()`-Direkttest der Saeule bei Tip-Werten
20-44 fuer Stehen/Ducken/Springen (siehe oben); Kristall-Aufnahme per
direktem `update()`-Aufruf (Bonus/Score korrekt, kein Tod, Objekt
entfernt); Autopilot-Soak 30000 Frames (8,3 Minuten) mit allen Funden
gleichzeitig - 4 Abstuerze, alle fuenf Hoehlen-Hindernisarten
(`cactus`, `pillar`, `stalactite`, `snake`, `bat`) vertreten, keine
Verschlechterung gegenueber 1.18; Level-1-Soak zur Gegenprobe (nur
Wuesten-Hindernisse, bis die im Vorfuehrmodus laengst bestehende
automatische Wueste-zu-Hoehle-Umschaltung ab Score 2000 einsetzt -
das ist keine neue Aenderung, sondern dieselbe seit 1.12 bestehende
Vorfuehrmodus-Kulisse); kein Konsolenfehler ueber rund 183000
`update()`-Aufrufe in Summe.

## Kristall-Skin: Zacken-Cluster statt flacher Raute (1.20)

Vorlage: ein Foto eines echten blauen Kristallstocks (mehrere spitze
Zacken unterschiedlicher Hoehe von einer gemeinsamen Basis aus, jede
Flaeche mit hellerer Kante fuer den Glas-Eindruck). `drawCrystal()`
zeichnet jetzt so einen Cluster statt der bisherigen einzelnen flachen
Raute: pro Zacke zwei Formen uebereinander (dunklerer Koerper `#2f9fc9`
+ helle Facette `#d8f7fb`), dazu eine kleine dunkle Ellipse als
Fels-Basis. Drei Cluster-Layouts (`CRYSTAL_VARIANTS`, 2-4 Zacken je
Variante) fuer sichtbare Abwechslung, dieselbe Idee wie die drei
`drawRock()`-Varianten. `variant` wird beim Spawnen zufaellig gewaehlt
und im Objekt gespeichert (wie bei Felsen). Kollisionsbox minimal
vergroessert (14x16 -> 20x24) fuer den breiteren Cluster-Umriss - reine
Optik-Anpassung, Aufnahme bleibt wie zuvor "einfach durchlaufen reicht".

Nebenbei einen Dokumentationsfehler behoben: der Kommentar bei
`state.crystalIn` nannte noch "236" Funde aus einem fruehen,
ungetesteten Kommentarentwurf - der tatsaechlich gemessene Wert war
335 (siehe 1.19). Zahl im Code-Kommentar korrigiert, README war
bereits korrekt.

Verifiziert: alle drei Varianten nebeneinander gerendert und per
Screenshot geprueft; Aufnahme per direktem `update()`-Aufruf weiterhin
korrekt (Bonus +25, Objekt entfernt, kein Tod); Autopilot-Soak (18000
Frames) ohne Regression.

## Missverstaendnis korrigiert: Kristalltextur galt den Boden-Hindernissen (1.21)

"Mit den Kristallen habe ich die Hindernisse auf dem Boden gemeint" -
1.20 hatte das falsche Objekt umgebaut. Gemeint war das in 1.18 auf
graue Felszacken umgestellte `drawCactus()` (Hoehle) - das sollte die
Kristalltextur aus der Referenz bekommen, nicht das Sammelobjekt.

`drawCrystalSpike()` (aus 1.20) um zwei Farbparameter erweitert
(`body`/`facet`, vorher fest verdrahtet auf `#2f9fc9`/`#d8f7fb`) und
direkt in `drawCactus()`s Hoehlen-Zweig wiederverwendet: pro Cluster
zwei Zacken (eine grosse, eine kleine) statt der bisherigen grauen
Dreiecke, in `theme.ground`. Drei Farbvarianten (`CRYSTAL_HAZARD_COLORS`
- Blau, Tuerkis, Violett), eine pro Hindernis (nicht pro Zacke, damit
ein Cluster wie eine zusammenhaengende Formation wirkt), gewaehlt beim
Spawnen wie bei den Felsen-Varianten.

Bewusst *nicht* dieselben Farben/dieselbe Groesse wie das
Sammelobjekt: das Hindernis ist deutlich groesser (ganze
Kaktus-Hoehe, 36-50px) und hat keinen Glimmer-Halo/Puls - Farbe allein
sollte nicht der einzige Unterschied zwischen "toedlich" und
"harmlos aufsammelbar" sein. Kollisionsbox/Spawn-Logik unveraendert,
nur die Zeichnung wechselt (wie schon beim Rock-Skin in 1.18).

Verifiziert: drei Farbvarianten nebeneinander gerendert und per
Screenshot geprueft (deutlich von Stalaktiten/Stalagmiten UND vom
kleinen Sammelobjekt unterscheidbar); Autopilot-Soak (18000 Frames,
5 Minuten) - 3 Abstuerze, keine Verschlechterung, alle Hoehlen-
Hindernisarten weiterhin vertreten.

## Kristalle: Glow + glasigere Optik (1.22)

Rueckmeldung: die Boden-Kristalle sollten einen Schein-Effekt bekommen
und realistischer aussehen.

`drawCrystalSpike()` (Sammelobjekt UND Hindernis nutzen dieselbe
Funktion) zeichnet den Zacken-Koerper jetzt mit einem Farbverlauf
(hell zur Spitze, dunkler zur Basis - wirkt, als faengt die Spitze
Licht) statt einer flachen Farbe, dazu eine duenne halbtransparente
weisse Glanzkante an einer Seite. Neue Funktion `drawCrystalGlow()`
(Radialverlauf, Hex+Alpha-Farbe statt `rgba()` - dieselbe Farbvariable
reicht dann fuer Fuellung und Schein) aus dem bisherigen
Sammelobjekt-Glimmer herausgezogen, damit auch `drawCactus()`s
Hoehlen-Zweig sie nutzen kann - vorher hatte nur das Sammelobjekt einen
Schein.

Die in 1.21 begruendete Abgrenzung (Hindernis bewusst ohne
Glimmer/Puls, damit "toedlich" und "harmlos" unterscheidbar bleiben)
gilt jetzt anders: Groesse ist der Haupt-Unterschied (das Hindernis
ist ueber die ganze Kaktus-Hoehe/Cluster-Breite gross, das
Sammelobjekt bleibt ein kleiner einzelner Fund), Glow allein war
ohnehin nie das tragende Unterscheidungsmerkmal.

Verifiziert: Screenshot mit allen drei Hindernis-Farbvarianten plus
Sammelobjekt nebeneinander; Autopilot-Soak (18000 Frames) ohne
Regression; kein Konsolenfehler.

## Passende Fels-Textur fuer Stalaktiten/-saeulen (1.23)

Rueckmeldung mit einem Icon-Set als Vorlage: mehrfarbige, gesprenkelte
Gesteinsflecken statt einer einzelnen Flaechenfarbe.

Neue Funktion `drawIcicleTexture(x, y, w, h, seed)`: mehrere
halbtransparente helle/dunkle Kreis-Patches (`ICICLE_LIGHT`/`ICICLE_DARK`,
per `shadeColor()` aus `CAVE_ROCK` aufgehellt/abgedunkelt) auf die
bereits gefuellte Dreieckskontur geclippt, plus ein duenner dunkler
Grat in der Mitte fuer die Rippenoptik der Vorlage. `drawStalactite()`
und `drawPillar()` (der haengende Teil) rufen sie nach der Basisfuellung
auf. Patch-Positionen haengen an einem neuen `o.seed` (bei `spawnStalactite()`/
`spawnPillar()` gesetzt), nicht an `o.x` - sonst haette das Muster beim
Scrollen "gewandert" statt am Objekt zu haften, dieselbe Ueberlegung wie
bei den Decken-Speckeln (dort ist die Weltkoordinate selbst der Seed,
hier ein gespeicherter Zufallswert, weil ein einzelner Stalaktit anders
als die durchgehende Decke keine feste Weltposition zum Verankern hat).

Nebenbei: `theme.ground` (folgt dem Tag/Nacht-Zyklus) durch `CAVE_ROCK`
(fest, dieselbe Farbe wie Decke/Torbogen) ersetzt - Stalaktiten/-saeulen
sind reine Hoehlen-Hindernisse, sollen also derselben "immer gleich
dunkel"-Logik folgen wie der Rest des Gesteins (siehe 1.18).

Der dekorative Boden-Stumpf der Saeule bleibt bewusst ohne Textur: die
Funktion nimmt eine nach unten zeigende Kontur an (breite Basis oben,
Spitze unten, wie beim haengenden Teil), der Stumpf zeigt aber nach
oben - waere falsch geclippt worden. Bei seiner Groesse faellt die
einfarbige Flaeche nicht auf.

Verifiziert: per Screenshot bei vergroesserter Testgroesse (Textur
deutlich sichtbar) und bei echter Spielgroesse (Textur subtil, aber
vorhanden - dieselbe Erwartung wie bei den Decken-Speckeln, die auf
einem richtigen Geraet mit hoeherer Aufloesung besser lesbar sind als
in der 800px-Vorschau); sechs Autopilot-Soaks (18000 Frames) je
2-9 Abstuerze - erhoehte Streuung, aber nicht systematisch schlechter,
sondern dieselbe bekannte Autopilot-Grenze (prueft nur das naechste
Hindernis) bei mehreren gleichzeitig aktiven Hoehlen-Gefahrenarten.
