; KolibriTTS 0.1 - compact bilingual retro speech reader for KolibriOS
; FASM, 32-bit, i586.  UTF-8/CP1252 input (German umlauts are normalized).

use32
org 0

db 'MENUET01'
dd 1, start, image_end, memory_end, stack_top, params, 0

macro mcall a,b,c,d,e,f {
  mov eax,a
  if ~ b eq
    mov ebx,b
  end if
  if ~ c eq
    mov ecx,c
  end if
  if ~ d eq
    mov edx,d
  end if
  if ~ e eq
    mov esi,e
  end if
  if ~ f eq
    mov edi,f
  end if
  int 0x40
}

WIN_W=460
WIN_H=214
BTN_OPEN=2
BTN_SPEAK=3
BTN_LANG=4
BTN_STOP=5
TEXT_MAX=32768
PCM_MAX=1048576
PCM_FMT=18                 ; mono, 8 bit, 8 kHz
PCM_STATIC=20000000h

start:
  mcall 40,100111b         ; redraw,key,button,mouse
  call init_sound
  call init_dialog
.loop:
  mcall 10
  cmp eax,1
  je redraw
  cmp eax,2
  je key_event
  cmp eax,3
  je button_event
  jmp .loop

redraw:
  mcall 12,1
  mcall 0,80 shl 16+WIN_W,70 shl 16+WIN_H,034F7F7F7h,window_title
  mcall 13,12 shl 16+436,42 shl 16+26,00FFFFFFh
  mcall 38,12 shl 16+448,42 shl 16+42,00707070h
  mcall 4,18 shl 16+50,80000000h,file_label
  mcall 4,18 shl 16+70,00000000h,file_name
  mcall 4,18 shl 16+98,00000000h,status_label
  mcall 4,78 shl 16+98,00000000h,[status_text]
  mcall 8,12 shl 16+104,132 shl 16+30,BTN_OPEN,00D8D8D8h
  mcall 8,122 shl 16+104,132 shl 16+30,BTN_SPEAK,009BD19Bh
  mcall 8,232 shl 16+104,132 shl 16+30,BTN_LANG,00D8D8D8h
  mcall 8,342 shl 16+104,132 shl 16+30,BTN_STOP,00E0B0B0h
  mcall 4,25 shl 16+141,00000000h,txt_open
  mcall 4,135 shl 16+141,00000000h,txt_speak
  cmp byte [language],0
  jne .english
  mcall 4,250 shl 16+141,00000000h,txt_de
  jmp .lang_done
.english:
  mcall 4,250 shl 16+141,00000000h,txt_en
.lang_done:
  mcall 4,367 shl 16+141,00000000h,txt_stop
  mcall 4,14 shl 16+181,80000000h,hint
  mcall 12,2
  jmp start.loop

key_event:
  mcall 2
  cmp ah,27
  je quit
  jmp start.loop

button_event:
  mcall 17
  test ah,ah
  jz start.loop
  cmp ah,1
  je quit
  cmp ah,BTN_OPEN
  je open_text
  cmp ah,BTN_SPEAK
  je speak
  cmp ah,BTN_LANG
  je toggle_language
  cmp ah,BTN_STOP
  je stop_audio
  jmp start.loop

toggle_language:
  xor byte [language],1
  mov dword [status_text],status_ready
  jmp redraw

open_text:
  cmp dword [dialog_start],0
  je .dialog_error
  push od
  call [dialog_start]
  cmp dword [od_status],1
  jne redraw
  call load_file
  jmp redraw
.dialog_error:
  mov dword [status_text],status_no_dialog
  jmp redraw

load_file:
  mov eax,[od_openfile]
  mov [file_read_path],eax
  mcall 70,file_read
  test eax,eax
  jnz .failed
  mov [text_len],ebx
  cmp ebx,TEXT_MAX-1
  jbe @f
  mov ebx,TEXT_MAX-1
  mov [text_len],ebx
@@:
  mov byte [text_buffer+ebx],0
  call copy_basename
  mov dword [status_text],status_loaded
  ret
.failed:
  mov dword [status_text],status_read_error
  ret

copy_basename:
  mov esi,[od_openfile]
  mov edi,esi
.scan:
  lodsb
  test al,al
  jz .copy
  cmp al,'/'
  jne .scan
  mov edi,esi
  jmp .scan
.copy:
  mov esi,edi
  mov edi,file_name
  mov ecx,61
@@:
  lodsb
  stosb
  test al,al
  jz @f
  loop @b
  mov byte [edi-1],0
@@:
  ret

speak:
  cmp dword [text_len],0
  je .nothing
  cmp dword [sound_handle],0
  je .no_sound
  call stop_audio_raw
  call synth_text
  test eax,eax
  jz .nothing
  mov [pcm_len],eax
  ; create static buffer: input={format,size}, output=stream
  push stream_handle
  push eax
  push PCM_FMT+PCM_STATIC
  call sound_create
  test eax,eax
  jnz .no_sound
  push dword [pcm_len]
  push pcm_buffer
  push eax                    ; offset=0
  push dword [stream_handle]
  call sound_set
  push 0
  push dword [stream_handle]
  call sound_play
  mov dword [status_text],status_speaking
  jmp redraw
.nothing:
  mov dword [status_text],status_no_text
  jmp redraw
.no_sound:
  mov dword [status_text],status_no_sound
  jmp redraw

stop_audio:
  call stop_audio_raw
  mov dword [status_text],status_stopped
  jmp redraw

stop_audio_raw:
  cmp dword [stream_handle],0
  je .done
  push dword [stream_handle]
  call sound_stop
  push dword [stream_handle]
  call sound_destroy
  mov dword [stream_handle],0
.done:
  ret

quit:
  call stop_audio_raw
  mcall -1

; ---------------------------------------------------------------------------
; Tiny retro synthesizer. Each grapheme becomes a short voiced/noise gesture.
; DE and EN use different duration/pitch tables. This deliberately favours
; tiny size and old-PC character over naturalness.
synth_text:
  mov esi,text_buffer
  mov edi,pcm_buffer
  mov ebp,pcm_buffer+PCM_MAX
  mov dword [noise_seed],13579BDFh
.next:
  lodsb
  test al,al
  jz .done
  cmp edi,ebp
  jae .done
  cmp al,13
  je .next
  cmp al,10
  je .pause_long
  cmp al,' '
  je .pause_short
  cmp al,'.'
  je .pause_long
  cmp al,','
  je .pause_mid
  ; fold ASCII to lower case
  cmp al,'A'
  jb .classify
  cmp al,'Z'
  ja .classify
  or al,20h
.classify:
  ; German UTF-8 lead bytes are skipped; following byte still gives a gesture
  cmp al,0C0h
  jae .next
  mov bl,al
  ; vowels => voiced, consonants => noise/voiced alternating
  cmp al,'a'
  je .vowel
  cmp al,'e'
  je .vowel
  cmp al,'i'
  je .vowel_hi
  cmp al,'o'
  je .vowel_lo
  cmp al,'u'
  je .vowel_lo
  cmp al,'y'
  je .vowel_hi
  test al,1
  jz .noise
  mov ecx,420
  mov dl,17
  add dl,bl
  call emit_voiced
  jmp .next
.vowel:
  mov ecx,720
  mov dl,29
  cmp byte [language],0
  je @f
  mov dl,31
@@:
  call emit_voiced
  jmp .next
.vowel_hi:
  mov ecx,620
  mov dl,23
  call emit_voiced
  jmp .next
.vowel_lo:
  mov ecx,760
  mov dl,35
  call emit_voiced
  jmp .next
.noise:
  mov ecx,260
  call emit_noise
  jmp .next
.pause_short:
  mov ecx,280
  jmp .silence
.pause_mid:
  mov ecx,520
  jmp .silence
.pause_long:
  mov ecx,900
.silence:
  xor eax,eax
  rep stosb
  jmp .next
.done:
  mov eax,edi
  sub eax,pcm_buffer
  ret

; DL is pitch divider, ECX sample count, EDI destination.  Two square partials
; plus a gentle envelope make a compact, speech-like buzzer/formant timbre.
emit_voiced:
  xor ebx,ebx
  xor eax,eax
.loop:
  inc bl
  cmp bl,dl
  jb @f
  xor bh,1
  xor bl,bl
@@:
  mov al,112
  test bh,1
  jz @f
  mov al,144
@@:
  test bl,2
  jz @f
  add al,8
@@:
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out:
  ret

emit_noise:
.loop:
  mov eax,[noise_seed]
  imul eax,1103515245
  add eax,12345
  mov [noise_seed],eax
  shr eax,25
  add al,96
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out:
  ret

; ---------------------------------------------------------------------------
; Sound service wrapper (KolibriOS INFINITY/SOUND service, syscall 68/17).
init_sound:
  mcall 68,16,sound_service_name
  mov [sound_handle],eax
  ret

sound_ioctl:
  mcall 68,17,esp
  ret

sound_create:                 ; stdcall(format,size,out_handle)
  push ebx ecx
  lea eax,[esp+20]
  lea ebx,[esp+12]
  push 4 eax 8 ebx 1 dword [sound_handle]
  call sound_ioctl
  add esp,24
  pop ecx ebx
  ret 12

sound_set:                    ; stdcall(stream,offset,src,size)
  push ebx ecx
  xor eax,eax
  lea ebx,[esp+12]
  push eax eax 16 ebx 8 dword [sound_handle]
  call sound_ioctl
  add esp,24
  pop ecx ebx
  ret 16

sound_play:                   ; stdcall(stream,flags)
  push ebx ecx
  xor eax,eax
  lea ebx,[esp+12]
  push eax eax 8 ebx 10 dword [sound_handle]
  call sound_ioctl
  add esp,24
  pop ecx ebx
  ret 8

sound_stop:
  push ebx ecx
  xor eax,eax
  lea ebx,[esp+12]
  push eax eax 4 ebx 11 dword [sound_handle]
  call sound_ioctl
  add esp,24
  pop ecx ebx
  ret 4

sound_destroy:
  push ebx ecx
  xor eax,eax
  lea ebx,[esp+12]
  push eax eax 4 ebx 2 dword [sound_handle]
  call sound_ioctl
  add esp,24
  pop ecx ebx
  ret 4


; ---------------------------------------------------------------------------
; proc_lib OpenDialog setup.
init_dialog:
  mcall 68,16,proc_lib_name
  test eax,eax
  jz .done
  mov [proc_lib],eax
  push eax opendialog_init_name
  call get_proc
  mov [dialog_init],eax
  push dword [proc_lib] opendialog_start_name
  call get_proc
  mov [dialog_start],eax
  test eax,eax
  jz .done
  push od
  call [dialog_init]
.done:
  ret

get_proc:
  mov edx,[esp+8]
.next:
  test edx,edx
  jz .fail
  cmp dword [edx],0
  je .fail
  mov esi,[edx]
  mov edi,[esp+4]
.cmp:
  lodsb
  scasb
  jne .skip
  test al,al
  jnz .cmp
  mov eax,[edx+4]
  ret 8
.skip:
  add edx,8
  jmp .next
.fail:
  xor eax,eax
  ret 8

dialog_redraw:
  mcall 12,1
  mcall 0,20 shl 16+420,20 shl 16+220,013F0F0F0h,window_title
  mcall 12,2
  ret

align 4
file_read:
  dd 0,0,0,TEXT_MAX-1,text_buffer
file_read_path dd 0

; OpenDialog data (procinfo etc. are statically reserved below).
od:
  dd 0
  dd dialog_procinfo
  dd dialog_com_name
  dd dialog_com_area
  dd dialog_open_dir
  dd default_dir
  dd dialog_program
  dd dialog_redraw
od_status dd 0
od_openfile dd dialog_open_file
  dd dialog_filename
  dd filter_area
  dw 430,0,390,0

filter_area dd 9
  db 'txt',0,'text',0,0
sound_service_name db 'INFINITY',0
proc_lib_name db '/sys/lib/proc_lib.obj',0
opendialog_init_name db 'OpenDialog_init',0
opendialog_start_name db 'OpenDialog_start',0
dialog_com_name db 'KTT00001_open_dialog',0
default_dir db '/tmp0/1',0
dialog_program db '/sys/File managers/opendial',0

window_title db 'KolibriTTS 0.1 - Deutsch / English',0
file_label db 'Textdatei:',0
file_name db '(keine Datei geladen)',0, 64 dup 0
status_label db 'Status:',0
status_ready db 'Bereit',0
status_loaded db 'Text geladen',0
status_speaking db 'Wiedergabe laeuft',0
status_stopped db 'Gestoppt',0
status_no_text db 'Bitte zuerst eine Textdatei laden',0
status_no_sound db 'KolibriOS-Sounddienst nicht verfuegbar',0
status_no_dialog db 'OpenDialog nicht verfuegbar',0
status_read_error db 'Datei konnte nicht gelesen werden',0
status_text dd status_ready
txt_open db 'Oeffnen',0
txt_speak db 'Vorlesen',0
txt_de db 'Deutsch',0
txt_en db 'English',0
txt_stop db 'Stop',0
hint db 'TXT bis 32 KiB | Retro-Stimme | ESC beendet',0

language db 0
align 4
text_len dd 0
pcm_len dd 0
noise_seed dd 0
sound_handle dd 0
stream_handle dd 0
proc_lib dd 0
dialog_init dd 0
dialog_start dd 0
params rb 256
image_end:

align 16
dialog_procinfo rb 1024
dialog_filename rb 256
dialog_open_dir rb 4096
dialog_open_file rb 4096
dialog_com_area rb 1024
text_buffer rb TEXT_MAX
pcm_buffer rb PCM_MAX
rb 4096
stack_top:
memory_end:
