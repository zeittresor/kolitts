# KolibriTTS 0.1

Eine sehr kleine, native KolibriOS-Anwendung in FASM zum Öffnen und akustischen
Wiedergeben einfacher Textdateien. Die Oberfläche bietet Datei öffnen,
Deutsch/Englisch, Vorlesen und Stop.

## Ehrliche Einordnung

KolibriOS besitzt keinen eingebauten deutschen oder englischen TTS-Dienst.
Diese erste Version erzeugt deshalb selbst 8-kHz-Mono-PCM und übergibt es an den
KolibriOS-`INFINITY`/`SOUND`-Dienst. Der Synthesizer ist absichtlich extrem klein
und hat den Charakter eines frühen Heimcomputers. Er ist **keine natürlich
klingende TTS** und die Graphem-Synthese ist noch nicht so verständlich wie SAM,
Amiga `translator.device` oder eSpeak. Für wirklich verständliche Sprache wäre
als nächster Schritt ein vollständiger Graphem-zu-Phonem-Konverter plus
Phonem-/Diphon-Datenbank nötig.

## Bauen unter Windows

1. Offizielles FASM für Windows laden.
2. `fasm.exe` nach `tools\fasm.exe` legen (alternativ `FASM_HOME` setzen oder
   FASM in `PATH` aufnehmen).
3. `build_windows.bat` starten.
4. Das Ergebnis heißt `build\KOLITTS` (KolibriOS-Programme haben üblicherweise
   keine Dateiendung).

## Benutzung

`KOLITTS` in KolibriOS starten, `Oeffnen` wählen, eine TXT-Datei auswählen,
Sprache einstellen und `Vorlesen` anklicken. Unterstützt werden bis zu 32 KiB.
ASCII ist am zuverlässigsten; UTF-8-Umlaute werden in dieser kompakten Fassung
nur angenähert. Die Audioausgabe benötigt einen von KolibriOS unterstützten
Soundtreiber und den `INFINITY`-Sounddienst. Der Dateidialog benötigt das
standardmäßige `/sys/lib/proc_lib.obj` und `opendial`.

## Technische Eckdaten

- KolibriOS `MENUET01`, 32 Bit, i586
- FASM, keine Laufzeitbibliothek
- statischer Audiopuffer: maximal 1 MiB
- 8.000 Hz, 8 Bit, mono
- TXT: maximal 32 KiB
- keine externen Sprachdateien

## Teststatus

Der Quelltext orientiert sich an den aktuellen KolibriOS-Schnittstellen und den
offiziellen Beispielen für `proc_lib` sowie den `INFINITY`/`SOUND`-Dienst.
Ein echter Laufzeittest in KolibriOS bzw. auf konkreter Soundhardware bleibt
notwendig; fehlerfreie Funktion auf jeder Hardware kann bei einem
hardwareabhängigen Audiotreiber nicht seriös garantiert werden.

Lizenz: MIT (siehe `LICENSE`).
