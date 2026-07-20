# Embedded voice bank

`src/voice_bank.inc` contains compact 8 kHz unsigned PCM allophones for the
German and English offline voices. The samples were generated during
development with the open-source eSpeak NG synthesizer and converted to an
embedded FASM data table. eSpeak NG is available under GPL-3.0-or-later.

The finished application does not load or call eSpeak or another TTS runtime.
Text analysis, allophone selection, concatenation and PCM playback are
performed by the FASM application.
