# Hopper - Entwicklungsprotokoll

Chronologisches Protokoll der WebView-Version (`web/index.html`), aelteste
Eintraege oben: was sich wann und warum geaendert hat, inklusive verworfener
Versuche und Mess-/Soak-Ergebnisse. Aus der README ausgelagert, damit diese
kurz bleibt - hier nur nachlesen, wenn es um die Herkunft einer konkreten
Entscheidung geht. Aktuelle Referenz: `README.md`, Arbeitsanleitung:
`CLAUDE.md`.

Versionen 1.31-1.55 (u.a. Muenzen, Shop, Level 3 Lavahoehle) sind hier nicht
eigens protokolliert - dafuer `git log` ansehen. Die ungekuerzte alte README
(inkl. Messwerten aus den heute gekuerzten Referenz-Abschnitten) steht in
Commit e2fdad4: `git show e2fdad4:README.md`.
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

## Fledermaeuse: realistischer + fliegen aktiv auf den Spieler zu (1.24)

**Optik.** `drawBat()` bekommt richtige Fluegel statt einer einzelnen
Dreiecksflaeche: `drawBatWing()` spannt drei "Finger" (Vorlage: echte
Fledermaus-Anatomie - eine Membran zwischen gespreizten Handknochen)
vom Handgelenk zu drei Membran-Punkten auf, mit duennen
halbtransparent-schwarzen Ritzen dazwischen (dunkelt zuverlaessig ab,
egal wie hell `theme.ground` gerade ist - kein zweiter Theme-Wert
noetig). Dazu eine kleine Schnauze und zwei helle Augen-Glanzpunkte.
Der Flap nutzt jetzt einen kontinuierlichen Winkel (`Math.sin(o.flap)`)
statt zweier hart geschalteter Posen - fluessigere Bewegung.

**Aktiver Flug.** Fledermaeuse hatten wie Voegel bisher nur die normale
Weltscroll-Bewegung. Jetzt: sobald eine Fledermaus naeher als 260
Weltdistanz an den Spieler herankommt, bekommt sie eine zusaetzliche
Schliessgeschwindigkeit (`o.diveExtra`, deckelt bei 150, waechst mit
300/s) - liest sich wie ein gezieltes Zuschwirren statt passivem
Vorbeitreiben. Der Autopilot rechnet das in seine `closingSpeed` mit
ein, dieselbe Loesung wie schon bei rollenden Felsen (`rollExtra`).

**Sicherheitslektion unterwegs:** der erste Versuch liess auch die
tatsaechliche Kollisionshoehe (`o.y`) im Sinus mitschwingen (+-9px,
fuer eine Flugwelle). Autopilot-Soak sprang danach von 2-9 auf 9-17
Abstuerze pro 5 Minuten, fast ausschliesslich Fledermaus-Treffer -
Ursache gefunden per direktem `hits()`-Nachrechnen: die mittlere
Hoehenstufe hatte beim Ducken nur ~5px Sicherheitsabstand
(`ry`=`groundY-25` vs. Fledermaus-Unterkante `groundY-30` bei
statischer Hoehe), die 9px-Amplitude riss diesen Abstand also klar.
Fix: `o.y` (Kollision) bleibt fest auf `baseY`, die Flugwelle
(`o.bobT`) bewegt nur noch die Zeichnung (`drawBat()`s lokaler
`bobOffset`, Amplitude 5px rein optisch) - Kollisionsverhalten seitdem
wieder exakt wie bei der urspruenglichen statischen Hoehe.

Verifiziert: isolierte Einzelfledermaus per Frame-fuer-Frame-Log
(Autopilot duckt korrekt, kein Trefferereignis); enger Schwarm
(3 Fledermaeuse, 46px Abstand) 10x wiederholt - 1 Treffer in 10
Durchlaeufen (im Rahmen der dokumentierten Autopilot-Grenze bei engen
Formationen, keine neue Regression); volle Autopilot-Soaks (6x 18000
Frames, danach 1x 36000 Frames) zurueck im Basiswert 1-4 Abstuerze;
kein Konsolenfehler; Screenshot mit Einzeltier und Dreiergruppe in
unterschiedlichen Flap-Phasen.

## Voegel aufgewertet + Level 1 zeigt ein kleineres, aber laengeres Ziel (1.25)

**Voegel.** Eigene Anatomie statt Fledermaus-Kopie: `drawBirdWing()`
staffelt drei Schwingen abnehmender Laenge/Deckkraft (Handschwingen
vorn, kuerzere Armschwingen dahinter, wie echtes Vogelgefieder) und
rotiert sie gemeinsam um die Schulter statt zwischen zwei Posen zu
springen - dieselbe Kontinuierlich-Winkel-Idee wie bei der Fledermaus
(1.24), aber Federn statt Lederfinger. Dazu ein spitzer Dreiecks-
Schnabel statt des alten Rechtecks und zwei kleine Schwanzfedern hinten.
Bewusst *keine* aktive Flugbewegung (kein `diveExtra`/Ansteuern des
Spielers wie bei Fledermaeuse) - nicht angefragt, und nach dem
Fledermaus-Kollisionsbug (siehe 1.24) ein guter Grund, hier nicht ohne
Anlass dasselbe Risiko einzugehen. Rein optisch, Spawn/Kollision
unveraendert.

**Level-1-Ziel.** Rueckmeldung: der angezeigte Zielwert sollte kleiner
wirken (1000 statt 2000), Level 1 soll aber laenger dauern - "so lange
wie es vorher bis 3000 gedauert haette". Zwei Groessen, die bisher
identisch waren (der interne Rohwert fuer alle Schwierigkeits-Trigger
UND die angezeigte Zahl), mussten dafuer entkoppelt werden:

- `CAVE_START` 2000 -> 3000 (weiterhin derselbe Rohwert, derselbe
  `state.score`, dieselbe Formel `distance/14` - Level 1 dauert dadurch
  laenger, ca. Faktor 1.3-1.4 in echten Frames gemessen, nicht linear
  zur Score-Erhoehung wegen der Tempo-Rampe am Anfang).
- Neue Funktion `dispScore(raw)` (= `Math.floor(raw/3)`), die NUR an
  den fuer den Spieler sichtbaren Stellen greift: HUD (`drawHud()`,
  nur wenn `!state.caveOn`), Pause-Screen, Game-Over/Levelabschluss-
  Bildschirm (`showGameOver()`/`showLevelComplete()`) und die Lobby
  (`refreshMenu()`, nur im Wueste-Zweig). `state.score`/`state.high`
  selbst bleiben unveraendert (Rohwert) - jede interne Schwierigkeits-
  Logik (`BIRD_START`, `SNAKE_START`, Bergabschnitte, Nachtzyklus) haengt
  exakt an dieser Rohgroesse und blieb dadurch **absichtlich** zeitlich
  komplett unangetastet, obwohl sie nicht angefragt war. Level 2 (Hoehle)
  zeigt weiterhin den echten Rohwert - dort wurde nichts geaendert,
  `state.caveOn` gated jede `dispScore()`-Anwendung.
- Persistierte Highscores (`HIGH_KEY`/`LAST_KEY`) speichern weiterhin
  den Rohwert, `dispScore()` wird erst beim Anzeigen angewendet - kein
  Migrations-/Formatwechsel fuer bestehende Speicherstaende noetig.

Verifiziert: Simulation von Score 0 bis zum Levelabschluss zeigt
`dispScore(3000)===1000` und der tatsaechliche Levelabschluss-Bildschirm
(`oScore`/`oHigh`) exakt diesen Wert; HUD-Screenshots in Level 1 (skaliert,
z.B. "00500"/"HI 01000") und Level 2 (unskaliert, "HI 05000") direkt
gegenuebergestellt; Autopilot-Soaks fuer Level 1 (4x, bis zu 2,5 Minuten
oder Hoehlen-Uebergang) mit 0 Abstuerzen, keine Regression durch die
neue Vogel-Zeichnung.

## Vogel-Blickrichtung korrigiert (1.26)

Rueckmeldung direkt nach 1.25: die Voegel fliegen "in die falsche
Richtung". Kopf/Schnabel sassen rechts, Schwanz links - der Vogel
bewegt sich aber (wie alle Hindernisse) mit dem Weltscroll nach links
auf die Figur zu, sah also aus, als fliege er rueckwaerts. Beim alten
Rechteck-Fluegel (vor 1.25) war das kaum sichtbar, mit dem neuen
spitzen Dreiecks-Schnabel fiel es sofort auf.

`drawBird()` horizontal gespiegelt: Kopf/Schnabel jetzt vorn links
(Flugrichtung), Schwanzfedern hinten rechts, Fluegel-Drehpunkt
entsprechend mitverschoben. Reine Koordinaten-Aenderung, `drawBirdWing()`
selbst unangetastet. Die Fledermaus war davon nicht betroffen - ihre
Schnauze zeigt nach unten, nicht seitlich, es gibt also keine Links/
Rechts-Asymmetrie, die falsch herum sitzen koennte.

Verifiziert: Screenshot mit drei Voegeln in unterschiedlichen Flap-
Phasen - Schnabel zeigt jetzt in Bewegungsrichtung; Autopilot-Soak
(9000 Frames) weiterhin 0 Abstuerze; kein Konsolenfehler.

## Level 1: Prozent-Fortschritt statt Punktzahl (1.27)

Wunsch: "ein Counting System % so wie in Geometry Dash" statt der
1.25-Skalierung (Rohpunkte/3, Ziel zeigte "1000").

`pctScore(raw)` ersetzt `dispScore()` vollstaendig -
`Math.min(100, Math.floor(raw / CAVE_START * 100))` statt einer festen
Division. Neue Helper-Funktion `fmtScore(raw, caveOn)` buendelt die
Formatwahl an allen fuenf Anzeige-Stellen (HUD, Pause, Game-Over,
Levelabschluss, Lobby): Level 1 "NN%", Level 2 weiterhin `pad5()` - in
der endlosen Hoehle gibt es kein definiertes Ziel, ein Prozentwert
ergaebe keinen Sinn. `state.score`/`state.high` bleiben unveraendert
Rohwerte, genau wie in 1.25 - nur die Formatierung an der Anzeige
aendert sich.

Das "Punkte"-Label auf dem Pause- und dem Game-Over-Bildschirm wechselt
jetzt dynamisch zu "Fortschritt", wenn ein Prozentwert statt einer
Punktzahl angezeigt wird (`pScoreLabel`/`oScoreLabel`, neue IDs) - "Punkte:
74%" waere sonst eine falsche Bezeichnung fuer das, was da eigentlich
steht. Der Levelabschluss-Bildschirm zeigt planmaessig immer "100%"
(die `pctScore()`-Deckelung faengt ab, dass `state.score` im exakten
Trigger-Frame minimal ueber `CAVE_START` liegen kann).

Verifiziert: HUD/Pause/Levelabschluss/Lobby je per direktem
Funktionsaufruf und Screenshot geprueft (u.a. "HI 100%"/"50%" waehrend
des Laufs, "Fortschritt: 100%" beim echten Levelabschluss ueber
Autopilot-Steuerung, Level 2 weiterhin unveraendert "04500"/"05000");
Autopilot-Soak (9000 Frames) ohne Regression; kein Konsolenfehler.

## Level 1: mehr Tempo und Dichte zum Levelabschluss hin (1.28)

Eigene Einschaetzung nach 1.27 bestaetigt bekommen: Level 1 kam in
Autopilot-Soaks durchgehend auf 0 Abstuerze, und Voegel/Schlangen sind
schon bei Fortschritt ~15-25% voll eingefuehrt - der laengere Rest des
Levels brachte nichts Neues mehr. Zwei unabhaengige Stellschrauben,
beide **nur in Level 1** (Level 2/die Hoehle hat ihr eigenes, bereits
verifiziertes Tuning und war nicht angefragt):

- **Tempo.** Neue Konstante `SPEED_MAX_L1 = 1400` (Level 1) getrennt von
  `SPEED_MAX = 960` (weiterhin die Hoehle) - `state.speed = Math.min(
  state.caveOn ? SPEED_MAX : SPEED_MAX_L1, ...)`. Die alte Obergrenze 960
  wurde nach 42s erreicht und blieb fuer den Rest des (jetzt laengeren)
  Levels flach; 1400 wird bei gleichem `SPEED_RAMP` erst nach 71s
  erreicht - laenger als Level 1 dauert (per Simulation: 56s bis
  Levelabschluss, Tempo dort bei 1170 und weiter steigend). Das Tempo
  eskaliert jetzt durchgehend bis zum Ende statt vorher zu plateauen.
- **Dichte.** `obstacleGap()` bekommt in Level 1 einen zusaetzlichen
  Faktor `Math.max(0.72, 1 - state.score/CAVE_START*0.28)`, der den
  Basis-Abstand zum Levelende hin um bis zu 28% verkuerzt. Wichtig: der
  Abstand skaliert schon mit `state.speed` (Zeit zwischen Hindernissen =
  Abstand/Tempo = reiner Koeffizient, unabhaengig vom Tempo selbst) -
  der neue Faktor kuerzt also wirklich die Reaktionszeit zwischen
  Hindernissen, nicht nur die Distanz am Bildschirm. Die Untergrenze
  0.72 (nicht 0.5 oder tiefer) haelt das im per Autopilot-Soak
  verifizierten fairen Rahmen.

Verifiziert: sechs Autopilot-Soaks fuer Level 1 - 0-2 Abstuerze pro
Lauf (vorher durchgehend 0), Todesfaelle liegen bei Fortschritt-Werten
zwischen 25% und 69%, keine Haeufung ganz am Levelende trotz hoechster
Dichte/hoechstem Tempo dort - keine unfaire Spitze. Level-2-Soak
(18000 Frames) zeigt weiterhin `maxSpeed === 960` (Obergrenze
unveraendert) und dieselbe Abstuerzerate wie vor der Aenderung; kein
Konsolenfehler.

## Eigentest deckt Fairness-Luecke auf: SPEED_MAX_L1 wieder entfernt (1.29)

Wunsch: selbst testen, ob sich 1.28 fair anfuehlt - nicht nur per
Autopilot-Abstuerzerate (die reagiert immer exakt im letztmoeglichen
Frame, ohne jede Verzoegerung, und hatte deshalb schon immer eine
optimistischere Fairness-Aussage als ein echter Mensch sie bekommt).
Neue Messgroesse: wie lange ist ein Hindernis sichtbar, bevor
`autoPilot()`s eigene `tTrigger`-Formel "jetzt handeln" sagt (= der
spaeteste noch sichere Moment)? Das ist das tatsaechliche
Reaktionsfenster, das ein Mensch fuer EIN Hindernis hat.

Ergebnis: das Minimum liegt schon beim unveraenderten Basiswert
(`SPEED_MAX=960`, keine Dichte-Aenderung) bei 283ms - eher knapp,
aber seit jeher so und nie beanstandet. Mit `SPEED_MAX_L1=1400`
faellt das Minimum auf 183-233ms, und zwar **allein durchs Tempo**:
ein Test mit reiner Dichte-Aenderung bei unveraendertem Tempo (960)
unterschreitet in keinem Fall die 283ms, weil Dichte nur den Abstand
ZWISCHEN Hindernissen aendert, nicht die Vorlaufzeit fuer eines davon
(die haengt einzig an `state.speed`, ueber `tContact`/`tPass` in der
`tTrigger`-Formel). Schon `SPEED_MAX_L1=1050` (nur 9% ueber 960) drueckt
das Minimum bereits unter 283ms. Mit der aktuellen `tTrigger`-Formel
(kein eingebauter Sicherheitspuffer, sie berechnet den spaetest-
moeglichen Moment) ist mehr Tempo also nicht ohne Fairness-Verlust zu
haben.

Konsequenz: `SPEED_MAX_L1` komplett entfernt, Level 1 nutzt wieder
`SPEED_MAX=960` wie die Hoehle. Die Dichte-Erhoehung aus 1.28
(`obstacleGap()`) bleibt unveraendert bestehen, weil sie nachweislich
keinen Einfluss auf dieses Reaktionsfenster hat.

Verifiziert: Messung des Reaktionsfensters bei `SPEED_MAX_L1` in
{960, 1050, 1100, 1150, 1250, 1400} zeigt einen klaren Zusammenhang
(hoeher = kuerzeres Minimum, durchgehend unter 283ms sobald ueber
960); dieselbe Messung nur mit Dichte-Variation (Boden bei 1.0/0.9/
0.85/0.8, Tempo fest bei 960) zeigt durchgehend 283ms, 0 kurze
Fenster; finaler Soak (Tempo zurueckgesetzt, Dichte behalten) 0-1
Abstuerze pro Lauf, Reaktionsfenster wieder bei 283ms.

## Schlangen-Ueberarbeitung: neongruenes Gift, das auf die Spielerhaltung zielt (1.29)

Wunsch: Schlangen sollen neongruenes Gift schiessen, das den Spieler
verfolgt. Bewusst NICHT als echtes Dauer-Tracking umgesetzt, direkt im
Anschluss an die obige Fairness-Lektion: ein Geschoss, das jeden Frame
neu auf die aktuelle Spielerposition nachlenkt, haette dieselbe Art
Verifikationsarbeit gebraucht wie oben (und mehr) - mit echtem Risiko,
am Ende ein technisch unmoegliches Ausweich-Szenario zu bauen. Stattdessen:
das Geschoss zielt GENAU EINMAL beim Abschuss auf die aktuelle Haltung der
Figur (`poisonTargetY()`) und fliegt danach schnurgerade auf dieser
Bahn - technisch identisch zu einem Vogel (dieselbe `hits()`/
`autoPilot()`-Hoehenlogik, dieselben zwei unteren Hoehenstufen), nur
die Zielwahl kommt von der Spielerhaltung statt vom Zufall. Neongruener
Glimmer-Halo + Kometenschweif (`drawPoison()`) tragen den "gezielter
Schuss"-Eindruck optisch.

Zwei echte Bugs beim Bauen gefunden und behoben (nicht nur Tuning):

1. **Fehlendes `*dt`.** Die Bonusgeschwindigkeit wurde anfangs als
   `move = dx + POISON_EXTRA` statt `dx + POISON_EXTRA*dt` addiert -
   bei `POISON_EXTRA=260` waren das ~15600px/s zusaetzlich statt 260px/s,
   das Geschoss war praktisch sofort da (Reaktionsfenster 0ms).
2. **Falsche "harmlose" Hoehe.** `poisonTargetY()` zielte anfangs auf
   die hohe/ignorierbare Vogel-Bahn, wenn die Figur beim Abschuss
   gerade in der Luft war ("dann ist da oben ja niemand"). Falsch:
   `hits()` zeigt, dass die Kollisionsbox waehrend des Steig-/Fallteils
   eines Sprungs (`runner.y` zwischen ca. -77 und -14) trotzdem in die
   obere Bahn hineinreicht - und da das Geschoss mehrere Sekunden
   unterwegs ist, kann die Figur in der Zwischenzeit fuer ein ganz
   anderes Hindernis laengst wieder gesprungen sein. Soak-Test: 2 von 10
   Laeufen ein Treffer, obwohl das Reaktionsfenster dem sonst ueberall
   sicheren Basiswert entsprach. Fix: nur noch die beiden unteren, aktiv
   zu konternden Bahnen (ducken/springen), nie "einfach nichts tun".
3. **Unloesbare Kombination mit der Schlange selbst.** Erste Fassung
   feuerte das Geschoss von derselben Position UND Geschwindigkeit wie
   die ausloesende Schlange ab - beide kommen dann zwangslaeufig
   gleichzeitig an. Verlangte das Geschoss dabei "ducken", waehrend die
   Schlange (wie immer) "springen" verlangt, war das ein garantierter,
   unloesbarer Treffer. Fix: eigener Spawn-Zweig (`POISON_START/RAMP/
   TARGET`, ab Score 520) statt an den Schlangen-Spawn gehaengt - laeuft
   dadurch durch `obstacleGap()` wie jedes andere Hindernis und bekommt
   denselben garantierten Abstand zu allem anderen, inklusive Schlangen.

`POISON_EXTRA` bleibt am Ende bei 0 (keine Zusatzgeschwindigkeit) -
schon 45px/s zusaetzlich draengten das Reaktionsfenster von 283ms auf
250ms und erzeugten im Soak echte Treffer. Die neongruene Optik traegt
den "Schuss"-Eindruck bereits ausreichend, ohne zusaetzliches Risiko.

Verifiziert: 20 Autopilot-Soaks (9000 Frames) nach beiden Fixes - 0
Gift-Treffer (vorher 2-3 pro 10 Laeufe je nach Bug), Reaktionsfenster
283ms (Basiswert); Screenshot mit beiden Zielbahnen (Stehen -> mittel,
Ducken -> tief); kein Konsolenfehler.

## Gift sichtbar an die Schlange gekoppelt + Hoehlen-Sprunghoehe korrigiert (1.30)

Feedback nach 1.29: "die projektile fliegen nicht von den schlangen weg
sondern irgendwann danach oder davor". Der eigene Spawn-Zweig aus 1.29
loeste Fairness-Probleme, aber der Preis war ein komplett unabhaengiger
Zeitplan (`obstacleGap()`-Abstand zu IRGENDEINEM vorherigen Hindernis) -
das Geschoss hatte optisch keinerlei erkennbare Verbindung mehr zu einer
bestimmten Schlange.

**Fix:** eine Schlange "queued" das Gift jetzt bei ihrem eigenen Spawn
(`state.poisonQueued`), und `spawnObstacle()` loest es garantiert als
naechstes Hindernis aus - immer von derselben Kante (`LW+20`) wie die
Schlange kurz zuvor, und bei gleicher Schliessgeschwindigkeit
(`POISON_EXTRA=0`) bleibt es die ganze Zeit im festen Abstand HINTER ihr,
wie ausgespuckt. Ein kleiner Partikel-Spuckeffekt an der Schlangen-Position
markiert den Abschuss zusaetzlich.

Der erzwungene Abstand brauchte zwei Anlaeufe:

1. **260-430** (klein, damit die Schlange bei `LW~620` noch im Bild ist,
   wenn das Gift spawnt). Autopilot-Soak mit echter Treffer-Zuordnung (statt
   nur dem Reaktionsfenster-Mass) zeigte aber 5 von 43 Gift-Treffern bei
   Hoechsttempo: `autoPilot()` reagiert pro Frame nur auf das jeweils
   naechste Hindernis (die Schleife bricht nach dem ersten passenden ab).
   Bei kleinem Abstand liegt der Sprung-Trigger der Schlange zeitlich zu
   nah am Duck/Sprung-Trigger des Gifts - Letzteres wird dabei uebersprungen,
   bis es zu spaet ist. Da beide Objekte dieselbe Schliessgeschwindigkeit
   haben, ist der zeitliche Abstand ihrer Trigger-Momente = Abstand/Tempo,
   unabhaengig vom Tempo selbst.
2. **600-750** behebt das: 0 Gift-Treffer in ueber 60 simulierten Minuten
   (Wueste und Hoehle, Autopilot-Soak mit echter Treffer-Zuordnung). Die
   Schlange ist dadurch bei hohem Tempo oft schon aus dem Bild (620 LW),
   aber noch oft genug sichtbar - Sicherheit geht hier vor perfekter
   optischer Naehe bei jedem Tempo.

**Nebenfund beim Eigentest (aelterer, von diesem Feature unabhaengiger
Bug):** der Autopilot machte in der Hoehle seit jeher einen kurzen
"Tipp"-Sprung (`runner.capAt=0.02`, Scheitelhoehe ~65 statt ~126 beim
vollen Sprung) - ein Relikt aus der Zeit, als die Decke selbst noch
toedlich war (siehe 1.17). Ein deterministischer Hoehen-Test pro
Kristall-Cluster-Breite und Tempo (kein Zufall, reine Sprungphysik) zeigt:
dieser kurze Sprung reicht bei niedrigem Hoehlentempo (nahe `SPEED_START`)
NICHT, um breite Kristall-Cluster (2-3 zusammenstehende Boden-Hindernisse)
zu ueberspringen - unabhaengig davon, wann genau gesprungen wird (reine
Geometrie: zu wenig Bodenstrecke oberhalb der Hindernishoehe waehrend der
kurzen Flugzeit). Ein Stalaktit/eine Saeule wird davon nicht sicherer -
beide treffen ohnehin jeden Sprung, kurz oder lang. Also gab es keinen
Sicherheitsgrund mehr fuer den kurzen Tipp; er ist jetzt entfernt, die
Hoehle springt genauso voll wie die Wueste. Verifiziert: derselbe
Hoehen-Test zeigt danach "ok" fuer alle Cluster-Breiten ab `SPEED_START`.

**Testmethodik-Faussfalle bei diesem Eigentest:** die im Browser-Tool
geladene Seite laeuft weiter mit ihrer eigenen `requestAnimationFrame`-
Schleife (echte Wanduhrzeit), auch waehrend ein Skript zusaetzlich manuell
`update(dt)` aufruft - beide kaempften unbemerkt um denselben Zustand und
erzeugten voellig unplausible Ergebnisse (u.a. 83% Fruehtod-Rate in einem
ersten, falschen Testlauf). Fix fuer kuenftige Eigentests: vor jeder
manuellen Simulation `window.requestAnimationFrame` auf eine No-Op-Funktion
setzen, damit nur noch die manuellen `update()`-Aufrufe zaehlen.

## Review-Fixes (1.56)

Code-Review aller Apps (2026-09-15), alle Punkte im Browser verifiziert:

- **Auto-Pause beim Verlassen der App**: `visibilitychange` mit
  `document.hidden` ruft `pauseGame(true)` auf (still, ohne UI-Klick, der
  sonst im gerade suspendierten AudioContext haengen bliebe). Vorher lief ein
  Lauf nach Home-Taste/Anruf bei der Rueckkehr sofort weiter, oft mit
  direktem Tod.
- **Kein Muenz-Klang mehr im Menue**: der Vorfuehr-Bot sammelte Muenzen und
  spielte dabei `SFX.equip()` ab - jetzt wie `addCoins()` nur im echten Spiel.
- **"Bestwerte zuruecksetzen" gilt fuer alle drei Level**: vorher nur fuer
  die Wueste, bei gewaehlter Hoehle/Lava passierte sichtbar nichts.
- **Lava-Bodenzacken nutzen `LAVA_HAZARD_COLORS`**: die Palette war definiert,
  aber nie verwendet - Level 3 zeigte blaue Hoehlenkristalle.
- **Zurueck-Navigation**: siehe Abschnitt "Garderobe" (hoechstens ein
  Verlaufseintrag, `pushAway()`/`leaveToMenu()`).
