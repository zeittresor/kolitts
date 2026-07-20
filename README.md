# KolibriTTS 0.2

KolibriTTS is a compact native text-to-speech reader for KolibriOS, written in
32-bit FASM assembly. It opens plain text files and speaks them using selectable
German or English pronunciation.

## Features

- Native KolibriOS `MENUET01` application
- English user interface
- German and English pronunciation modes
- KolibriOS OpenDialog file selection
- Plain-text input up to 32 KiB
- Rule-based grapheme and digraph processing
- German rules for `sch`, `ch`, `ei`, `ie`, `eu`, `ä`, `ö`, `ü` and `ß`
- English rules for `sh`, `ch`, `th`, `ng`, `oo`, `ee` and `qu`
- Distinct vowel formants, fricatives, plosives and nasal sounds
- Punctuation pauses and sentence phrasing
- Direct 8 kHz, 8-bit mono PCM output through the KolibriOS sound service
- No runtime libraries or external voice files

## Build on Windows

1. Download the official Windows release of FASM.
2. Place `fasm.exe` in `tools\fasm.exe`, set `FASM_HOME`, or add FASM to `PATH`.
3. Run `build_windows.bat`.
4. Copy `build\KOLITTS` to a drive accessible from KolibriOS.

The build script also copies the German and English example files into the
`build` directory.

## Use

1. Start `KOLITTS` in KolibriOS.
2. Select **Open** and choose a `.txt` file.
3. Select **German** or **English**.
4. Select **Speak**.
5. Select **Stop** to stop playback. Press `Esc` to exit.

Short sentences with normal punctuation produce the clearest result. UTF-8
German umlauts and `ß` are recognized.

## Requirements

- KolibriOS with `/sys/lib/proc_lib.obj` and OpenDialog
- An active KolibriOS sound driver providing the `INFINITY` sound service
- FASM for rebuilding the application

## Project layout

- `src/main.asm` — application and speech synthesizer
- `build_windows.bat` — Windows compiler script
- `build/KOLITTS` — ready-to-run KolibriOS binary
- `examples/` — German and English sample text

License: MIT.
