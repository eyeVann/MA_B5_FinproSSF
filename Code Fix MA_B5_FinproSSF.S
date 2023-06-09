#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

main:
  SBI DDRB, 1     ; Mengatur Pin PB1 (Pin 9 pada arduino) sebagai output
  CBI DDRB, 0     ; Mengatur pin PB0 (Pin 8 pada arduino) sebagai input
  RCALL init_serial ;subroutine untuk inisialisasi serial
  sei

loop: ; Subroutine yang akan dilakukan berulang-ulang

; Proses mendapatkan jarak dari sensor HC-SR04
  SBI   PORTB, 1
  RCALL delay_timer0_SENSOR
  CBI   PORTB, 1        ;send 10us high pulse to sensor

  RCALL echo_PW         ;Subroutine untuk membaca sensor

  RCALL byte2decimal    ;Subroutine untuk menghitung jarak yang terbaca
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0
  LDI R26, 0x0A
  STS UDR0, R26 ;print newline
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0
  LDI R26, 0x0D
  STS UDR0, R26 ;print carriage return
  RJMP  loop

init_serial:
  CLR R24 ; Meng-clear R24 untuk meng-clear UCSR0A dan UBRR0H
  STS UCSR0A, R24 ; Menyimpan isi dari R24 yang sudah di-clear ke UCSR04
  STS UBRR0H, R24 ; Menyimpan isi dari R24 yang sudah di-clear ke UBRR0H
  LDI R24, 103 ; Mengisi R24 untuk mengisi UBRR0L
  STS UBRR0L, R24 ; Menetapkan baud rate dengan menyimpan isi dari R24
  LDI R24, 1<<RXEN0 | 1<<TXEN0 ; Meng-enable RXB dan TXB
  STS UCSR0B, R24 ; Menyimpan isi dari R24
  LDI R24, 1<<UCSZ00 | 1<<UCSZ01 ; Async, no parity, 1 stop, 8 bits
  STS UCSR0C, R24; Menyimpan isi dari R24
  RET

echo_PW: Subroutine untuk membaca sensor
;-------
  LDI   R20, 0b00000000
  STS   TCCR1A, R20     ;Timer 1 normal mode
  LDI   R20, 0b11000101 ;set for rising edge detection &
  STS   TCCR1B, R20     ;prescaler=1024, noise cancellation ON
  ;-----------------------------------------------------------
l1: IN    R21, TIFR1
  SBRS  R21, ICF1
  RJMP  l1              ;loop until rising edge is detected
  ;-----------------------------------------------------------
  LDS   R16, ICR1L      ;store count value at rising edge
  ;-----------------------------------------------------------
  OUT   TIFR1, R21      ;clear flag for falling edge detection
  LDI   R20, 0b10000101
  STS   TCCR1B, R20     ;set for falling edge detection
  ;-----------------------------------------------------------
l2: IN    R21, TIFR1
  SBRS  R21, ICF1
  RJMP  l2              ;loop until falling edge is detected
  ;-----------------------------------------------------------
  LDS   R28, ICR1L      ;store count value at falling edge
  ;-----------------------------------------------------------
  SUB   R28, R16        ;count diff R22 = R22 - R16
  OUT   TIFR1, R21      ;clear flag for next sensor reading
    RET

byte2decimal: ;Subroutine untuk menghitung jarak yang terbaca pada sensor
;------------
    CLR   R26             ;set counter1, initial value 0
    CLR   R27             ;set counter2, initial value 0
    ;--------------------------------------------------------
l70:  CPI   R28, 100        ;compare R28 with 100
Ret:  BRMI  l80             ;jump when R28 < 100
    INC   R26             ;increment counter1 by 1
    SUBI  R28, 100        ;R28 = R28 - 100
    RJMP  l70
    ;--------------------------------------------------------
l80:  CPI   R28, 10         ;compare R28 with 10
    BRMI  dsp             ;jump when R28 < 10
    INC   R27             ;increment counter2 by 1
    SUBI  R28, 10         ;R28 = R28 - 10
    RJMP  l80
    ;--------------------------------------------------------  
dsp:  
  CPI R27, 1
  BRSH close   ;Jika jarak lebih dari 10 cm, branch ke close
  CPI R27, 0
  BREQ open ;Jika jarak kurang dari 10 cm, branch ke open
  RET

close: ;Subroutine yang dijalankan ketika jarak < 10 cm
  LDI R30, lo8(message_close) ; Me-load low-byte dari pesan yang diinginkan ke Z
  LDI R31, hi8(message_close) ; Me-load high-byte dari pesan yang diinginkan ke Z
  RCALL agn
  LDI R26, 1
  LDI   ZL, lo8(rotate_pos_close) ;Berisi derajat dari perputaran servo
  LDI   ZH, hi8(rotate_pos_close)
  RCALL loop_servo ;Subroutine untuk memutar servo
  RET
 
open: ;Subroutine yang dijalankan ketika jarak > 10 cm
  LDI R30, lo8(message_open) ; Me-load low-byte dari pesan yang diinginkan ke Z
  LDI R31, hi8(message_open) ; Me-load high-byte dari pesan yang diinginkan ke Z
  RCALL agn
  LDI R26, 1
  LDI   ZL, lo8(rotate_pos_open);Berisi derajat dari perputaran servo
  LDI   ZH, hi8(rotate_pos_open)
  RCALL loop_servo
  RET


agn: ;Subroutine untuk menampilkan pesan di Serial Monitor
  LPM R29, Z+ ; Me-load satu char dari strings yang disimpan di program memory Z
  CPI 29, 0 ; Meng-compare apakah R19 berisi 0
  BREQ ext ; Jika nol, program akan branch ke ext
  RCALL LCD_buffer
  STS UDR0, R29 ; Menyimpan char ke  UDR0 yang akan ditampilkan di serial monitor
  RJMP agn ; kembali ke agn sampai R19 bernilai 0
ext:
  RET

loop_servo: ;Subroutine untuk memutar Servo
  LPM   R24, Z+         ;load rotation pos
  RCALL rotate_servo    ;& rotate servo
  DEC R26
  BRNE loop_servo
  RET ; kembali

rotate_servo: 
;------------
    LDI   R20, 10         ;count to give enough cycles of PWM
l3: SBI   PORTB, 4
    RCALL delay_timer0_SERVO
    CBI   PORTB, 4        ;send msec pulse to rotate servo
    RCALL delay_20ms      ;wait 20ms before re-sending pulse
    DEC   R20
    BRNE  l3           ;go back & repeat PWM signal
    RCALL delay_ms        ;0.5s delay
    RET                   ;& return to main subroutine

message_close: ;Pesan ketika jarak < 10 cm
  .ascii "Pintu Tertutup..." ; Pesan yang diinginkan
  .byte 0

rotate_pos_close: ;Besar derajat servo ketika jarak < 10 cm
.byte 40,40  ;Derajat yang diinginkan

message_open: ;Pesan ketika jarak > 10 cm
  .ascii "Pintu Terbuka.." ; Pesan yang diinginkan
  .byte 0

rotate_pos_open: ;Besar derajat servo ketika jarak > 10 cm
.byte 100,100 ;Derajat yang diinginkan

;============================================
; Subroutine2 yang berhubungan dengan delay
;============================================

delay_timer0_SENSOR:             ;10 usec delay via Timer 0
;------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 20
    OUT   OCR0A, R20      ;OCR0 = 20
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 8
    ;-----------------------------------------------------------
l0: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l0              ;else, loop back & check OCF0 flag
    ;-----------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;-----------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET

;===============================================================
delay_timer0_SERVO:             ;delay via Timer0
    ;-----------------------------------------------------------
    CLR   R21
    OUT   TCNT0, R21      ;initialize timer0 with count=0
    MOV   R21, R24
    OUT   OCR0A, R21
    LDI   R21, 0b00001100
    OUT   TCCR0B, R21     ;timer0: CTC mode, prescaler 256
    ;-----------------------------------------------------------
loop2: IN    R21, TIFR0      ;get TIFR0 byte & check
    SBRS  R21, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  loop2             ;else, loop back & check OCF0 flag
    ;-----------------------------------------------------------
    CLR   R21
    OUT   TCCR0B, R21     ;stop timer0
    ;-----------------------------------------------------------
    LDI   R21, (1<<OCF0A)
    OUT   TIFR0, R21      ;clear OCF0 flag
    RET

delay_20ms:               ;delay 20ms
    LDI   R21, 255
l7: LDI   R22, 210
l5: LDI   R23, 2
l6: DEC   R23
    BRNE  l6
    DEC   R22
    BRNE  l5
    DEC   R21
    BRNE  l7
    RET

delay_ms:
;--------
ldi r25, hi8(200) ; Memasukkan nilai delay dalam satuan ms ke r25
  ldi r24, lo8(200) ; Memasukkan nilai delay dalam satuan ms ke r24
outerLoop:
; karena innerLoop berjalan selama 4 cycle, maka di-loop 4000x sehingga menghasilkan
; 1 millisecond (4 x 4000 : 16Mhz = 10^-3)
  ldi r31, hi8(4000) ; mengisi r30 dan r31 dengan 4000
  ldi r30, lo8(4000)
innerLoop:
  sbiw r30,1 ; Mengurangi isi r30 dan r31 sebanyak 1
  brne innerLoop ; Jika hasil pengurangan baris sebelumnya tidak menghasilkan nol,
; innerLoop akan terus diulang
;------------------------------(end of innerLoop)
  
  sbiw r24, 1 ; Mengurangi r24 dan r25 sebanyak 1
  brne outerLoop; Jika hasil pengurangan baris sebelumnya tidak menghasilkan nol,
; maka outerLoop akan terus diulang dan innerLoop akan dijalankan kembali
RET
;==============================================

;==============================================================================
;Subroutine2 yang berhubungan dengan proses menampilkan pesan di Serial monitor
;==============================================================================
LCD_buffer:
  LDS R17, UCSR0A
  SBRS R17, UDRE0 ;test data buffer if data can be sent
  RJMP LCD_buffer
  RET

ASCII_MSD: ; Proses mendapatkan ASCII dari MSD
  MOV R23, R16 ;save copy of result
  ANDI R16, 0xF0 ; extract & swap high-nibble
  SWAP R16
  SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48
  MOV R28, R16 ;save a copy of high-byte result
  SUBI R28, 58 ;if +ve
  BRPL A_F_D1 ;branch & add 7 to get ASCII A to F
l4: RET

ASCII_LSD: ; Proses mendapatkan ASCII dari LSD
MOV R16, R23 ;restore copy of result
ANDI R16, 0x0F ;extract low-nibble
SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48
MOV R28, R16 ;save a copy of high-byte result
SUBI R28, 58 ;if +ve
BRPL A_F_D0 ;branch & add 7 to get ASCII A to F

l9: RET
A_F_D1:
SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7
RJMP l4
A_F_D0:
SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7
RJMP l9
