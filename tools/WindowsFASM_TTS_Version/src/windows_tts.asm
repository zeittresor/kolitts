format PE GUI 4.0
entry start

WM_CREATE=1
WM_DESTROY=2
WM_COMMAND=111h
WM_CLOSE=10h
WM_DROPFILES=233h
CW_USEDEFAULT=80000000h
WS_OVERLAPPEDWINDOW=00CF0000h
WS_VISIBLE=10000000h
WS_CHILD=40000000h
WS_TABSTOP=00010000h
BS_PUSHBUTTON=0
SS_LEFT=0
WS_BORDER=00800000h
WS_VSCROLL=00200000h
ES_MULTILINE=4
ES_AUTOVSCROLL=40h
ES_READONLY=800h
SW_SHOW=5
ID_OPEN=1001
ID_SPEAK=1002
ID_LANG=1003
ID_STOP=1004
GENERIC_READ=80000000h
OPEN_EXISTING=3
FILE_ATTRIBUTE_NORMAL=80h
GENERIC_WRITE=40000000h
CREATE_ALWAYS=2
INVALID_HANDLE_VALUE=-1
OFN_FILEMUSTEXIST=1000h
OFN_PATHMUSTEXIST=800h
WAVE_MAPPER=-1
CALLBACK_NULL=0
WHDR_DONE=1
PCM_MAX=1048576
TEXT_MAX=32768

section '.text' code readable executable

start:
  push 0
  call [GetModuleHandleA]
  mov [instance],eax
  call try_cli
  test eax,eax
  jz .gui
  push 0
  call [ExitProcess]
.gui:
  mov dword [wc+0],3
  mov dword [wc+4],wndproc
  mov dword [wc+8],0
  mov dword [wc+12],0
  mov [wc+16],eax
  push 7F00h
  push 0
  call [LoadIconA]
  mov [wc+20],eax
  push 7F00h
  push 0
  call [LoadCursorA]
  mov [wc+24],eax
  mov dword [wc+28],6
  mov dword [wc+32],0
  mov dword [wc+36],class_name
  push wc
  call [RegisterClassA]
  push 0
  push dword [instance]
  push 0
  push 0
  push 390
  push 560
  push CW_USEDEFAULT
  push CW_USEDEFAULT
  push WS_OVERLAPPEDWINDOW
  push app_title
  push class_name
  push 0
  call [CreateWindowExA]
  mov [main_window],eax
  push SW_SHOW
  push eax
  call [ShowWindow]
  push dword [main_window]
  call [UpdateWindow]
.loop:
  push 0
  push 0
  push 0
  push msg
  call [GetMessageA]
  test eax,eax
  jz .exit
  push msg
  call [TranslateMessage]
  push msg
  call [DispatchMessageA]
  jmp .loop
.exit:
  push dword [msg+8]
  call [ExitProcess]

try_cli:
  call [GetCommandLineA]
  mov esi,eax
  cmp byte [esi],'"'
  jne .plain_exe
  inc esi
@@: lodsb
  test al,al
  jz .no
  cmp al,'"'
  jne @b
  jmp .args
.plain_exe:
@@: lodsb
  test al,al
  jz .no
  cmp al,' '
  jne @b
.args:
  call skip_spaces
  mov edi,cli_nogui
  call match_token
  jc .no
  call skip_spaces
  mov edi,cli_speak
  call match_token
  jc .no
  call skip_spaces
  mov al,[esi]
  or al,20h
  cmp al,'d'
  jne @f
  mov byte [language],0
  jmp .lang_ok
@@:
  cmp al,'e'
  jne .no
  mov byte [language],1
.lang_ok:
  add esi,2
  call skip_spaces
  cmp byte [esi],'"'
  jne @f
  inc esi
@@:
  mov edi,text_buffer
  mov ecx,TEXT_MAX-1
  xor edx,edx
.copy:
  lodsb
  test al,al
  jz .copied
  cmp al,'"'
  je .copied
  stosb
  inc edx
  loop .copy
.copied:
  mov byte [edi],0
  mov [bytes_read],edx
  test edx,edx
  jz .no
  call speak_text
  cmp dword [wave_handle],0
  je .yes
.wait:
  test dword [wavehdr+16],WHDR_DONE
  jnz .finished
  push 25
  call [Sleep]
  jmp .wait
.finished:
  call stop_audio
.yes:
  mov eax,1
  ret
.no:
  xor eax,eax
  ret

skip_spaces:
  cmp byte [esi],' '
  jne @f
  inc esi
  jmp skip_spaces
@@: ret

match_token:
.loop:
  mov al,[edi]
  test al,al
  jz .ok
  mov ah,[esi]
  or ah,20h
  cmp al,ah
  jne .bad
  inc esi
  inc edi
  jmp .loop
.ok:
  clc
  ret
.bad:
  stc
  ret

wndproc:
  push ebp
  mov ebp,esp
  mov eax,[ebp+12]
  cmp eax,WM_CREATE
  je .create
  cmp eax,WM_COMMAND
  je .command
  cmp eax,WM_DROPFILES
  je .drop
  cmp eax,WM_CLOSE
  je .close
  cmp eax,WM_DESTROY
  je .destroy
.default:
  push dword [ebp+20]
  push dword [ebp+16]
  push dword [ebp+12]
  push dword [ebp+8]
  call [DefWindowProcA]
  jmp .done
.create:
  mov eax,[ebp+8]
  mov [main_window],eax
  call create_controls
  push 1
  push dword [main_window]
  call [DragAcceptFiles]
  xor eax,eax
  jmp .done
.command:
  mov eax,[ebp+16]
  and eax,0FFFFh
  cmp eax,ID_OPEN
  je .open
  cmp eax,ID_SPEAK
  je .speak
  cmp eax,ID_LANG
  je .lang
  cmp eax,ID_STOP
  je .stop
  xor eax,eax
  jmp .done
.open:
  call open_text
  xor eax,eax
  jmp .done
.speak:
  call speak_text
  xor eax,eax
  jmp .done
.lang:
  xor byte [language],1
  cmp byte [language],0
  jne @f
  mov eax,label_german
  jmp .setlang
@@:
  mov eax,label_english
.setlang:
  push eax
  push dword [button_lang]
  call [SetWindowTextA]
  xor eax,eax
  jmp .done
.stop:
  call stop_audio
  mov eax,status_stopped
  call set_status
  xor eax,eax
  jmp .done
.drop:
  push 260
  push file_path
  push 0
  push dword [ebp+16]
  call [DragQueryFileA]
  push dword [ebp+16]
  call [DragFinish]
  call load_text_path
  xor eax,eax
  jmp .done
.close:
  call stop_audio
  push dword [ebp+8]
  call [DestroyWindow]
  xor eax,eax
  jmp .done
.destroy:
  push 0
  call [PostQuitMessage]
  xor eax,eax
.done:
  mov esp,ebp
  pop ebp
  ret 16

create_controls:
  push 0
  push dword [instance]
  push 0
  push dword [main_window]
  push 24
  push 520
  push 18
  push 18
  push WS_CHILD+WS_VISIBLE+SS_LEFT
  push heading
  push class_static
  push 0
  call [CreateWindowExA]
  push 0
  push dword [instance]
  push 0
  push dword [main_window]
  push 20
  push 520
  push 18
  push 43
  push WS_CHILD+WS_VISIBLE+SS_LEFT
  push instructions
  push class_static
  push 0
  call [CreateWindowExA]
  push 0
  push dword [instance]
  push ID_OPEN
  push dword [main_window]
  push 32
  push 120
  push 76
  push 18
  push WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  push label_open
  push class_button
  push 0
  call [CreateWindowExA]
  push 0
  push dword [instance]
  push ID_SPEAK
  push dword [main_window]
  push 32
  push 120
  push 76
  push 148
  push WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  push label_speak
  push class_button
  push 0
  call [CreateWindowExA]
  push 0
  push dword [instance]
  push ID_LANG
  push dword [main_window]
  push 32
  push 120
  push 76
  push 278
  push WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  push label_german
  push class_button
  push 0
  call [CreateWindowExA]
  mov [button_lang],eax
  push 0
  push dword [instance]
  push ID_STOP
  push dword [main_window]
  push 32
  push 110
  push 76
  push 408
  push WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  push label_stop
  push class_button
  push 0
  call [CreateWindowExA]
  push 0
  push dword [instance]
  push 0
  push dword [main_window]
  push 20
  push 520
  push 18
  push 118
  push WS_CHILD+WS_VISIBLE+SS_LEFT
  push no_file
  push class_static
  push 0
  call [CreateWindowExA]
  mov [file_label],eax
  push 0
  push dword [instance]
  push 0
  push dword [main_window]
  push 20
  push 520
  push 18
  push 142
  push WS_CHILD+WS_VISIBLE+SS_LEFT
  push status_ready
  push class_static
  push 0
  call [CreateWindowExA]
  mov [status_label],eax
  push 0
  push dword [instance]
  push 0
  push dword [main_window]
  push 154
  push 520
  push 174
  push 18
  push WS_CHILD+WS_VISIBLE+WS_BORDER+WS_VSCROLL+ES_MULTILINE+ES_AUTOVSCROLL+ES_READONLY
  push preview_empty
  push class_edit
  push 00000200h
  call [CreateWindowExA]
  mov [preview_box],eax
  ret

open_text:
  mov dword [ofn+0],76
  mov eax,[main_window]
  mov [ofn+4],eax
  mov eax,[instance]
  mov [ofn+8],eax
  mov dword [ofn+12],text_filter
  mov dword [ofn+28],file_path
  mov dword [ofn+32],260
  mov dword [ofn+52],OFN_FILEMUSTEXIST+OFN_PATHMUSTEXIST
  push ofn
  call [GetOpenFileNameA]
  test eax,eax
  jz .done
  call load_text_path
.done:
  ret

load_text_path:
  push 0
  push FILE_ATTRIBUTE_NORMAL
  push OPEN_EXISTING
  push 0
  push 1
  push GENERIC_READ
  push file_path
  call [CreateFileA]
  cmp eax,INVALID_HANDLE_VALUE
  je .error
  mov [file_handle],eax
  push 0
  push bytes_read
  push TEXT_MAX-1
  push text_buffer
  push eax
  call [ReadFile]
  mov [read_ok],eax
  push dword [file_handle]
  call [CloseHandle]
  cmp dword [read_ok],0
  jz .error
  mov eax,[bytes_read]
  mov byte [text_buffer+eax],0
  push file_path
  push dword [file_label]
  call [SetWindowTextA]
  push text_buffer
  push dword [preview_box]
  call [SetWindowTextA]
  mov eax,status_loaded
  call set_status
  ret
.error:
  mov eax,status_error
  call set_status
  ret

speak_text:
  cmp dword [bytes_read],0
  jne @f
  mov eax,status_no_text
  call set_status
  ret
@@:
  call stop_audio
  mov esi,log_synth
  mov ecx,log_synth_len
  call write_log
  call synth_text
  test eax,eax
  jz .fail
  mov [pcm_len],eax
  mov esi,log_pcm
  mov ecx,log_pcm_len
  call write_log
  mov dword [wavehdr+0],pcm_buffer
  mov [wavehdr+4],eax
  push CALLBACK_NULL
  push 0
  push 0
  push wavefmt
  push WAVE_MAPPER
  push wave_handle
  call [waveOutOpen]
  test eax,eax
  jnz .fail
  push 32
  push wavehdr
  push dword [wave_handle]
  call [waveOutPrepareHeader]
  test eax,eax
  jnz .fail
  push 32
  push wavehdr
  push dword [wave_handle]
  call [waveOutWrite]
  test eax,eax
  jnz .fail
  mov esi,log_play
  mov ecx,log_play_len
  call write_log
  mov eax,status_speaking
  call set_status
  ret
.fail:
  mov eax,status_audio_error
  call set_status
  ret

stop_audio:
  cmp dword [wave_handle],0
  je .done
  push dword [wave_handle]
  call [waveOutReset]
  push 32
  push wavehdr
  push dword [wave_handle]
  call [waveOutUnprepareHeader]
  push dword [wave_handle]
  call [waveOutClose]
  mov dword [wave_handle],0
.done: ret

set_status:
  push eax
  push dword [status_label]
  call [SetWindowTextA]
  ret

write_log:
  push eax
  push ebx
  push ecx
  push edx
  push esi
  mov [log_length],ecx
  mov [log_buffer],esi
  push 0
  push FILE_ATTRIBUTE_NORMAL
  push CREATE_ALWAYS
  push 0
  push 1
  push GENERIC_WRITE
  push log_path
  call [CreateFileA]
  cmp eax,INVALID_HANDLE_VALUE
  je .done
  mov ebx,eax
  push 0
  push log_written
  push dword [log_length]
  push dword [log_buffer]
  push ebx
  call [WriteFile]
  push ebx
  call [CloseHandle]
.done:
  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  ret

; compact DE/EN rule synthesizer
synth_text:
  push ebx
  push esi
  push edi
  push ebp
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
  je .long_pause
  cmp al,' '
  je .short_pause
  cmp al,'.'
  je .long_pause
  cmp al,'!'
  je .long_pause
  cmp al,'?'
  je .long_pause
  cmp al,','
  je .mid_pause
  cmp al,'A'
  jb .utf
  cmp al,'Z'
  ja .utf
  or al,20h
.utf:
  cmp al,0C3h
  jne .rules
  mov al,[esi]
  inc esi
  cmp al,0A4h
  je .a
  cmp al,0B6h
  je .oev
  cmp al,0BCh
  je .uev
  cmp al,09Fh
  je .s
  jmp .next
.rules:
  mov ah,[esi]
  cmp ah,'A'
  jb @f
  cmp ah,'Z'
  ja @f
  or ah,20h
@@:
  cmp byte [language],0
  jne .en
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
  call vowel_a
  jmp .i
@@:
  cmp al,'i'
  jne @f
  cmp ah,'e'
  jne .i
  inc esi
  jmp .long_i
@@:
  cmp al,'z'
  je .ts
  cmp al,'w'
  je .v
  cmp al,'v'
  je .f
  cmp al,'j'
  je .i
  jmp .single
.en:
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
  mov al,10
  call emit_sample
  jmp .sh
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
  jmp .long_i
@@:
  cmp al,'q'
  jne @f
  cmp ah,'u'
  jne .k
  inc esi
  mov al,12
  call emit_sample
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
  cmp al,'b'
  je .b
  cmp al,'d'
  je .d
  cmp al,'g'
  je .g
  cmp al,'p'
  je .p
  cmp al,'t'
  je .t
  cmp al,'k'
  je .k
  cmp al,'c'
  je .k
  cmp al,'q'
  je .k
  cmp al,'f'
  je .f
  cmp al,'h'
  je .h
  cmp al,'s'
  je .s
  cmp al,'x'
  je .x
  cmp al,'z'
  je .z
  cmp al,'m'
  je .m
  cmp al,'n'
  je .n
  cmp al,'l'
  je .l
  cmp al,'r'
  je .r
  cmp al,'v'
  je .v
  cmp al,'w'
  je .w
  cmp al,'y'
  je .i
  jmp .next
.a: call vowel_a
  jmp .next
.e: mov al,1
  jmp .vowel
.i: mov al,2
  jmp .vowel
.o: mov al,3
  jmp .vowel
.u: mov al,4
.vowel:
  mov ecx,620
  call emit_formant
  jmp .next
.oev: mov al,5
  jmp .vowel
.uev: mov al,6
  jmp .vowel
.long_i:
  mov al,2
  mov ecx,900
  call emit_formant
  jmp .next
.p: mov al,8
  call emit_sample
  jmp .next
.t: mov al,10
  call emit_sample
  jmp .next
.k: mov al,12
  call emit_sample
  jmp .next
.b: mov al,9
  call emit_sample
  jmp .next
.d: mov al,11
  call emit_sample
  jmp .next
.g: mov al,13
  call emit_sample
  jmp .next
.f: mov al,14
  call emit_sample
  jmp .next
.v: mov al,15
  call emit_sample
  jmp .next
.s: mov al,16
  call emit_sample
  jmp .next
.z: mov al,17
  call emit_sample
  jmp .next
.sh: mov al,18
  call emit_sample
  jmp .next
.ch: mov al,19
  call emit_sample
  jmp .next
.h: mov al,20
  call emit_sample
  jmp .next
.m: mov al,21
  call emit_sample
  jmp .next
.n: mov al,22
  call emit_sample
  jmp .next
.ng: mov al,23
  call emit_sample
  jmp .next
.l: mov al,24
  call emit_sample
  jmp .next
.r: mov al,25
  call emit_sample
  jmp .next
.w: mov al,27
  call emit_sample
  jmp .next
.th: mov al,28
  call emit_sample
  jmp .next
.x: mov al,12
  call emit_sample
  jmp .s
.ts: mov al,10
  call emit_sample
  jmp .s
.short_pause: mov ecx,180
  jmp .silence
.mid_pause: mov ecx,400
  jmp .silence
.long_pause: mov ecx,720
.silence:
  call emit_silence
  jmp .next
.done:
  mov eax,edi
  sub eax,pcm_buffer
  pop ebp
  pop edi
  pop esi
  pop ebx
  ret

vowel_a:
  mov al,0
  mov ecx,620
  jmp emit_formant

emit_formant:
  movzx eax,al
  jmp emit_sample

emit_sample:
  push esi
  push ecx
  movzx eax,al
  shl eax,3
  mov edx,voice_table_de
  cmp byte [language],0
  je @f
  mov edx,voice_table_en
@@:
  mov esi,[edx+eax]
  mov ecx,[edx+eax+4]
  mov eax,ebp
  sub eax,edi
  cmp ecx,eax
  jbe @f
  mov ecx,eax
@@:
  rep movsb
  pop ecx
  pop esi
  ret

emit_noise:
.loop:
  call random
  shr eax,26
  add al,96
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out: ret
emit_noise_hi:
.loop:
  call random
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
  call random
  shr eax,28
  add al,120
  stosb
  cmp edi,ebp
  jae .out
  loop .loop
.out: ret
random:
  mov eax,[noise_seed]
  imul eax,1103515245
  add eax,12345
  mov [noise_seed],eax
  ret
stop_p:
  mov ecx,80
  call emit_silence
  mov ecx,80
  jmp emit_noise
stop_t:
  mov ecx,60
  call emit_silence
  mov ecx,100
  jmp emit_noise_hi
stop_k:
  mov ecx,90
  call emit_silence
  mov ecx,120
  jmp emit_noise
emit_silence:
  mov eax,ebp
  sub eax,edi
  cmp ecx,eax
  jbe @f
  mov ecx,eax
@@: mov al,128
  rep stosb
  ret

section '.data' data readable writeable

class_name db 'KolibriTTSWinClass',0
app_title db 'KolibriTTS for Windows 0.5',0
class_button db 'BUTTON',0
class_static db 'STATIC',0
class_edit db 'EDIT',0
heading db 'Offline German / English Retro Speech',0
instructions db 'Open or drag a TXT file here, select pronunciation, then press Speak.',0
label_open db 'Open',0
label_speak db 'Speak',0
label_german db 'German',0
label_english db 'English',0
label_stop db 'Stop',0
no_file db 'No text file loaded.',0
preview_empty db 'The loaded text will appear here.',0
status_ready db 'Ready.',0
status_loaded db 'Text loaded.',0
status_speaking db 'Speaking.',0
status_stopped db 'Stopped.',0
status_no_text db 'Open a text file first.',0
status_error db 'The text file could not be read.',0
status_audio_error db 'Windows audio output failed.',0
log_path db 'KolibriTTS.log',0
log_synth db 'Speak: synthesizing text',13,10
log_synth_len=$-log_synth
log_pcm db 'Speak: PCM generation completed',13,10
log_pcm_len=$-log_pcm
log_play db 'Speak: waveOut playback started',13,10
log_play_len=$-log_play
text_filter db 'Text files (*.txt)',0,'*.txt',0,'All files (*.*)',0,'*.*',0,0
cli_nogui db '-nogui',0
cli_speak db 'speak',0

wavefmt:
  dw 1,1
  dd 8000,8000
  dw 1,8,0
vowels db 6,3,2,0, 9,3,1,0, 13,2,1,0, 7,5,2,0, 11,7,2,0
language db 0
div1 db 0
div2 db 0
div3 db 0
align 4
instance dd 0
main_window dd 0
button_lang dd 0
file_label dd 0
status_label dd 0
preview_box dd 0
file_handle dd 0
read_ok dd 0
log_written dd 0
log_length dd 0
log_buffer dd 0
wave_handle dd 0
bytes_read dd 0
pcm_len dd 0
noise_seed dd 0
wc rd 10
msg rd 7
ofn rd 22
wavehdr rd 8
include 'src/voice_bank.inc'
file_path rb 260
text_buffer rb TEXT_MAX
pcm_buffer rb PCM_MAX

section '.idata' import data readable writeable

dd RVA kernel_lookup,0,0,RVA kernel_name,RVA kernel_iat
dd RVA user_lookup,0,0,RVA user_name,RVA user_iat
dd RVA dialog_lookup,0,0,RVA dialog_name,RVA dialog_iat
dd RVA winmm_lookup,0,0,RVA winmm_name,RVA winmm_iat
dd RVA shell_lookup,0,0,RVA shell_name,RVA shell_iat
dd 0,0,0,0,0

kernel_lookup:
 dd RVA hn_GetModuleHandleA,RVA hn_GetCommandLineA,RVA hn_ExitProcess,RVA hn_Sleep
 dd RVA hn_CreateFileA,RVA hn_ReadFile,RVA hn_WriteFile,RVA hn_CloseHandle,0
user_lookup:
 dd RVA hn_RegisterClassA,RVA hn_CreateWindowExA,RVA hn_ShowWindow,RVA hn_UpdateWindow
 dd RVA hn_GetMessageA,RVA hn_TranslateMessage,RVA hn_DispatchMessageA,RVA hn_DefWindowProcA
 dd RVA hn_PostQuitMessage,RVA hn_DestroyWindow,RVA hn_LoadIconA,RVA hn_LoadCursorA,RVA hn_SetWindowTextA,0
dialog_lookup: dd RVA hn_GetOpenFileNameA,0
winmm_lookup:
 dd RVA hn_waveOutOpen,RVA hn_waveOutPrepareHeader,RVA hn_waveOutWrite,RVA hn_waveOutReset
 dd RVA hn_waveOutUnprepareHeader,RVA hn_waveOutClose,0
shell_lookup: dd RVA hn_DragAcceptFiles,RVA hn_DragQueryFileA,RVA hn_DragFinish,0

kernel_iat:
 GetModuleHandleA dd RVA hn_GetModuleHandleA
 GetCommandLineA dd RVA hn_GetCommandLineA
 ExitProcess dd RVA hn_ExitProcess
 Sleep dd RVA hn_Sleep
 CreateFileA dd RVA hn_CreateFileA
 ReadFile dd RVA hn_ReadFile
 WriteFile dd RVA hn_WriteFile
 CloseHandle dd RVA hn_CloseHandle
 dd 0
user_iat:
 RegisterClassA dd RVA hn_RegisterClassA
 CreateWindowExA dd RVA hn_CreateWindowExA
 ShowWindow dd RVA hn_ShowWindow
 UpdateWindow dd RVA hn_UpdateWindow
 GetMessageA dd RVA hn_GetMessageA
 TranslateMessage dd RVA hn_TranslateMessage
 DispatchMessageA dd RVA hn_DispatchMessageA
 DefWindowProcA dd RVA hn_DefWindowProcA
 PostQuitMessage dd RVA hn_PostQuitMessage
 DestroyWindow dd RVA hn_DestroyWindow
 LoadIconA dd RVA hn_LoadIconA
 LoadCursorA dd RVA hn_LoadCursorA
 SetWindowTextA dd RVA hn_SetWindowTextA
 dd 0
dialog_iat: GetOpenFileNameA dd RVA hn_GetOpenFileNameA
 dd 0
winmm_iat:
 waveOutOpen dd RVA hn_waveOutOpen
 waveOutPrepareHeader dd RVA hn_waveOutPrepareHeader
 waveOutWrite dd RVA hn_waveOutWrite
 waveOutReset dd RVA hn_waveOutReset
 waveOutUnprepareHeader dd RVA hn_waveOutUnprepareHeader
 waveOutClose dd RVA hn_waveOutClose
 dd 0
shell_iat:
 DragAcceptFiles dd RVA hn_DragAcceptFiles
 DragQueryFileA dd RVA hn_DragQueryFileA
 DragFinish dd RVA hn_DragFinish
 dd 0

kernel_name db 'KERNEL32.DLL',0
user_name db 'USER32.DLL',0
dialog_name db 'COMDLG32.DLL',0
winmm_name db 'WINMM.DLL',0
shell_name db 'SHELL32.DLL',0

align 2
hn_GetModuleHandleA dw 0
db 'GetModuleHandleA',0
align 2
hn_GetCommandLineA dw 0
db 'GetCommandLineA',0
align 2
hn_ExitProcess dw 0
db 'ExitProcess',0
align 2
hn_Sleep dw 0
db 'Sleep',0
align 2
hn_CreateFileA dw 0
db 'CreateFileA',0
align 2
hn_ReadFile dw 0
db 'ReadFile',0
align 2
hn_WriteFile dw 0
db 'WriteFile',0
align 2
hn_CloseHandle dw 0
db 'CloseHandle',0
align 2
hn_RegisterClassA dw 0
db 'RegisterClassA',0
align 2
hn_CreateWindowExA dw 0
db 'CreateWindowExA',0
align 2
hn_ShowWindow dw 0
db 'ShowWindow',0
align 2
hn_UpdateWindow dw 0
db 'UpdateWindow',0
align 2
hn_GetMessageA dw 0
db 'GetMessageA',0
align 2
hn_TranslateMessage dw 0
db 'TranslateMessage',0
align 2
hn_DispatchMessageA dw 0
db 'DispatchMessageA',0
align 2
hn_DefWindowProcA dw 0
db 'DefWindowProcA',0
align 2
hn_PostQuitMessage dw 0
db 'PostQuitMessage',0
align 2
hn_DestroyWindow dw 0
db 'DestroyWindow',0
align 2
hn_LoadIconA dw 0
db 'LoadIconA',0
align 2
hn_LoadCursorA dw 0
db 'LoadCursorA',0
align 2
hn_SetWindowTextA dw 0
db 'SetWindowTextA',0
align 2
hn_GetOpenFileNameA dw 0
db 'GetOpenFileNameA',0
align 2
hn_waveOutOpen dw 0
db 'waveOutOpen',0
align 2
hn_waveOutPrepareHeader dw 0
db 'waveOutPrepareHeader',0
align 2
hn_waveOutWrite dw 0
db 'waveOutWrite',0
align 2
hn_waveOutReset dw 0
db 'waveOutReset',0
align 2
hn_waveOutUnprepareHeader dw 0
db 'waveOutUnprepareHeader',0
align 2
hn_waveOutClose dw 0
db 'waveOutClose',0
align 2
hn_DragAcceptFiles dw 0
db 'DragAcceptFiles',0
align 2
hn_DragQueryFileA dw 0
db 'DragQueryFileA',0
align 2
hn_DragFinish dw 0
db 'DragFinish',0
