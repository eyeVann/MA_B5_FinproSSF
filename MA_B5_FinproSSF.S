#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

main:
  SBI DDRB, 1     ;pin PB1 as o/p (Trigger)
  CBI DDRB, 0     ;pin PB0 as i/p (Echo)
  RCALL init_serial ;subroutine untuk inisialisasi serial
  sei

loop:
  SBI   PORTB, 1
  RCALL delay_timer0_SENSOR
  CBI   PORTB, 1        ;send 10us high pulse to sensor

  RCALL echo_PW         ;compute Echo pulse width count

  RCALL byte2decimal    ;covert & display on serial
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
  
  echo_PW: Subroutine reading sensor
  ;---------------------------------
  LDI R20, 0b00000000
  STS TCCR1A, R20           ; Timer 1 Normal Mode
  LDI R20, 0b11000101       ; rising edge detection
  STS TCCR1A, R20           ; prescaler 1024, noise cancellation ON
  ;---------------------------------
  l1: 
  IN R21, TIFR1
  SBRS R21, ICF1
  RJMP l1                   ; loop until rising edge detected
  ;----------------------------------
  LDS R16, ICR1L            ; store count value at rising edge
  ;----------------------------------
  OUT TIFR1, R21            ; clear flag for falling edge detection
  LDI R20, 0b11000101       ;
  STS TCCR1B, R20           ; set falling edge detection
  ;----------------------------------
  l2:
  IN R21, TIFR1             
  SBRS R21, ICF1
  RJMP l2                   ; loop until falling edge detected
  ;----------------------------------
  LDS R28, R16              ; store count diff R28 = R28-R16
  ;----------------------------------
  SUB R28, R16               ;count diff R28 = R28-R16
  OUT TIFR1, R21            ; clear flag for sensor reading
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
  
