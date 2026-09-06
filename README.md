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
              -VersionName "1.1" -VersionCode 2 -Force
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
echte Touch-Ziele und kein Hit-Testing von Hand. Die Farben ziehen ueber
CSS-Variablen beim Tag- und Nachtwechsel mit.

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
