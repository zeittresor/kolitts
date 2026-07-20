; KolibriTTS 0.2

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
  je .sentence
  cmp al,'!'
  je .sentence
  cmp al,'?'
  je .question
  cmp al,','
  je .pause_mid
  cmp al,'A'
  jb .utf8
  cmp al,'Z'
  ja .utf8
  or al,20h
.utf8:
  cmp al,0C3h
  jne .digraph
  mov al,[esi]
  inc esi
  cmp al,0A4h
  je .a
  cmp al,0B6h
  je .o
  cmp al,0BCh
  je .u
  cmp al,09Fh
  je .s
  jmp .next
.digraph:
  mov ah,[esi]
  cmp ah,'A'
  jb @f
  cmp ah,'Z'
  ja @f
  or ah,20h
@@:
  cmp byte [language],0
  jne .english
  cmp al,'s'
  jne @f
  cmp ah,'c'
  jne .s
  mov ah,[esi+1]
  or ah,20h
  cmp ah,'h'
  jne .s
  add esi,2
  jmp .sh
@@:
  cmp al,'c'
  jne @f
  cmp ah,'h'
  jne .k
  inc esi
  jmp .ch
@@:
  cmp al,'e'
  jne @f
  cmp ah,'i'
  jne .e
  inc esi
  jmp .ai
@@:
  cmp al,'i'
  jne @f
  cmp ah,'e'
  jne .i
  inc esi
  jmp .ii
@@:
  cmp al,'e'
  jne @f
  cmp ah,'u'
  je .consume_oi
  cmp ah,'a'
  jne .e
.consume_oi:
  inc esi
  jmp .oi
@@:
  cmp al,'z'
  je .ts
  cmp al,'w'
  je .v
  cmp al,'v'
  je .f
  cmp al,'j'
  je .y
  jmp .single
.english:
  cmp al,'s'
  jne @f
  cmp ah,'h'
  jne .s
  inc esi
  jmp .sh
@@:
  cmp al,'c'
  jne @f
  cmp ah,'h'
  jne .k
  inc esi
  jmp .ch_stop
@@:
  cmp al,'t'
  jne @f
  cmp ah,'h'
  jne .t
  inc esi
  jmp .th
@@:
  cmp al,'n'
  jne @f
  cmp ah,'g'
  jne .n
  inc esi
  jmp .ng
@@:
  cmp al,'o'
  jne @f
  cmp ah,'o'
  jne .o
  inc esi
  jmp .u
@@:
  cmp al,'e'
  jne @f
  cmp ah,'e'
  jne .e
  inc esi
  jmp .ii
@@:
  cmp al,'q'
  jne @f
  cmp ah,'u'
  jne .k
  inc esi
  call phon_k
  jmp .w
@@:
.single:
  cmp al,'a'
  je .a
  cmp al,'e'
  je .e
  cmp al,'i'
  je .i
  cmp al,'o'
  je .o
  cmp al,'u'
  je .u
  cmp al,'y'
  je .y
  cmp al,'b'
  je .b
  cmp al,'c'
  je .k
  cmp al,'d'
  je .d
  cmp al,'f'
  je .f
  cmp al,'g'
  je .g
  cmp al,'h'
  je .h
  cmp al,'j'
  je .j
  cmp al,'k'
  je .k
  cmp al,'l'
  je .l
  cmp al,'m'
  je .m
  cmp al,'n'
  je .n
  cmp al,'p'
  je .p
  cmp al,'q'
  je .k
  cmp al,'r'
  je .r
  cmp al,'s'
  je .s
  cmp al,'t'
  je .t
  cmp al,'v'
  je .v
  cmp al,'w'
  je .w
  cmp al,'x'
  je .x
  cmp al,'z'
  je .z
  jmp .next

.a: mov al,0
  jmp .vowel
.e: mov al,1
  jmp .vowel
.i: mov al,2
  jmp .vowel
.o: mov al,3
  jmp .vowel
.u: mov al,4
  jmp .vowel
.y: mov al,2
  jmp .short_vowel
.ai:
  mov al,0
  call phon_vowel
  mov al,2
  jmp .short_vowel
.oi:
  mov al,3
  call phon_vowel
  mov al,2
  jmp .short_vowel
.ii:
  mov al,2
  mov ecx,900
  call emit_formant
  jmp .next
.vowel:
  mov ecx,650
  call emit_formant
  jmp .next
.short_vowel:
  mov ecx,420
  call emit_formant
  jmp .next

.b: call phon_b
  jmp .next
.d: call phon_d
  jmp .next
.g: call phon_g
  jmp .next
.p: call phon_p
  jmp .next
.t: call phon_t
  jmp .next
.k: call phon_k
  jmp .next
.f: mov ecx,420
  call emit_noise
  jmp .next
.s: mov ecx,500
  call emit_noise_hi
  jmp .next
.sh: mov ecx,620
  call emit_noise
  jmp .next
.ch: mov ecx,480
  call emit_noise
  jmp .next
.th: mov ecx,360
  call emit_noise
  jmp .next
.h: mov ecx,260
  call emit_noise_soft
  jmp .next
.v: mov ecx,250
  call emit_noise
  mov al,1
  jmp .nasal
.z: mov ecx,240
  call emit_noise_hi
  mov al,1
  jmp .nasal
.j: mov ecx,180
  call emit_noise
  mov al,1
  jmp .nasal
.m: mov al,4
  jmp .nasal
.n: mov al,1
  jmp .nasal
.ng: mov al,3
  jmp .nasal
.l: mov al,2
  jmp .nasal
.r: mov al,0
.nasal:
  mov ecx,360
  call emit_murmur
  jmp .next
.w:
  mov al,4
  mov ecx,300
  call emit_formant
  jmp .next
.x:
  call phon_k
  jmp .s
.ts:
  call phon_t
  jmp .s
.ch_stop:
  call phon_t
  jmp .sh
.pause_short:
  mov ecx,180
  jmp .silence
.pause_mid:
  mov ecx,420
  jmp .silence
.pause_long:
  mov ecx,760
  jmp .silence
.sentence:
  mov byte [pitch_bias],0
  jmp .pause_long
.question:
  mov byte [pitch_bias],2
  jmp .pause_long
.silence:
  mov eax,ebp
  sub eax,edi
  cmp ecx,eax
  jbe @f
  mov ecx,eax
@@:
  mov al,128
  rep stosb
  jmp .next
.done:
  mov eax,edi
  sub eax,pcm_buffer
  ret

phon_vowel:
  mov ecx,520
emit_formant:
  push esi
  movzx eax,al
  shl eax,2
  lea esi,[vowel_table+eax]
  mov al,[esi]
  mov [div1],al
  mov al,[esi+1]
  mov [div2],al
  mov al,[esi+2]
  mov [div3],al
  xor eax,eax
  xor ebx,ebx
  xor edx,edx
.loop:
  inc al
  cmp al,[div1]
  jb @f
  xor ah,1
  xor al,al
@@:
  inc bl
  cmp bl,[div2]
  jb @f
  xor bh,1
  xor bl,bl
@@:
  inc dl
  cmp dl,[div3]
  jb @f
  xor dh,1
  xor dl,dl
@@:
  push eax
  mov al,96
  test ah,1
  jz @f
  add al,30
@@:
  test bh,1
  jz @f
  add al,18
@@:
  test dh,1
  jz @f
  add al,10
@@:
  stosb
  pop eax
  cmp edi,ebp
  jae .out
  loop .loop
.out:
  pop esi
  ret

emit_noise:
.loop:
  mov eax,[noise_seed]
  imul eax,1103515245
  add eax,12345
  mov [noise_seed],eax
  shr eax,26
  add al,96
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out:
  ret

emit_noise_hi:
.loop:
  mov eax,[noise_seed]
  imul eax,1103515245
  add eax,12345
  mov [noise_seed],eax
  shr eax,26
  xor al,3Fh
  add al,96
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out: ret

emit_noise_soft:
.loop:
  mov eax,[noise_seed]
  imul eax,1103515245
  add eax,12345
  mov [noise_seed],eax
  shr eax,28
  add al,120
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out: ret

emit_murmur:
  push eax
  mov ecx,ecx
  call emit_formant
  pop eax
  ret

phon_p:
  mov ecx,90
  call emit_silence
  mov ecx,90
  jmp emit_noise
phon_t:
  mov ecx,70
  call emit_silence
  mov ecx,110
  jmp emit_noise_hi
phon_k:
  mov ecx,100
  call emit_silence
  mov ecx,130
  jmp emit_noise
phon_b:
  call phon_p
  mov al,4
  mov ecx,170
  jmp emit_formant
phon_d:
  call phon_t
  mov al,1
  mov ecx,170
  jmp emit_formant
phon_g:
  call phon_k
  mov al,3
  mov ecx,180
  jmp emit_formant
emit_silence:
  mov eax,ebp
  sub eax,edi
  cmp ecx,eax
  jbe @f
  mov ecx,eax
@@:
  mov al,128
  rep stosb
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

window_title db 'KolibriTTS 0.2 - German / English Speech',0
file_label db 'Text file:',0
file_name db '(no file loaded)',0, 64 dup 0
status_label db 'Status:',0
status_ready db 'Ready',0
status_loaded db 'Text loaded',0
status_speaking db 'Speaking',0
status_stopped db 'Stopped',0
status_no_text db 'Open a text file first',0
status_no_sound db 'KolibriOS sound service unavailable',0
status_no_dialog db 'OpenDialog unavailable',0
status_read_error db 'Could not read file',0
status_text dd status_ready
txt_open db 'Open',0
txt_speak db 'Speak',0
txt_de db 'German',0
txt_en db 'English',0
txt_stop db 'Stop',0
hint db 'TXT up to 32 KiB | ESC exits',0

language db 0
pitch_bias db 0
div1 db 0
div2 db 0
div3 db 0
vowel_table:
  db 6,3,2,0
  db 9,3,1,0
  db 13,2,1,0
  db 7,5,2,0
  db 11,7,2,0
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
