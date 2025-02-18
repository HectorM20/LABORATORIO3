//***************************************************************
//Universidad del Valle de Guatemala 
//IE2023: Programación de Microcontroladores
//Autor: Héctor Alejandro Martínez Guerra
//Hardware: ATMEGA328P
//PRE_LAB3
//***************************************************************

//***************************************************************
//ENCABEZADO
//***************************************************************
.include "M328PDEF.inc"
.def BIN_COUNTER = R20					;Contador binario
.def HEX_COUNTER = R21					;Contador hexadecimal
.def TICK_COUNTER = R22					;Contador de ticks para contar 1000ms
; Tabla de Vectores
.org 0x0000
    RJMP SET_UP							;Vector de reset: salta a la rutina de configuración

;Vector de interrupción para PCINT1 (PORTC: pines PCINT8 a PCINT14)
.org 0x0008
    RJMP PCINT1_ISR

; Vector de interrupción para Timer0 Compare Match A
.org 0x001C
    RJMP TIMER0_COMPA_ISR

;Configuración de la pila
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

//TABLA 7 SEG
SEG_TABLE:.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F,	0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71  

SET_UP:
    ;Configurar Prescaler: F_CPU = 1 MHz
    LDI     R16, (1<<CLKPCE)
    STS     CLKPR, R16					;Habilitar cambio de prescaler
    LDI     R16, 0b00000100				;Configurar Prescaler a 16 F_cpu = 1MHz 
    STS     CLKPR, R16

	;Configuración de E/S para contador binario
    LDI     R16, 0b00001111				;Configuración de PORTB: PB0-PB3 como salidas (LEDs)
    OUT     DDRB, R16
    ;Configuración de PORTC: Entrada para los pushbuttons
    LDI     R16, 0x00
    OUT     DDRC, R16					;Puerto C como entrada
    ;Activar pull-ups internos en PC2 y PC3
    LDI     R16, 0x0C					;0x0C = 0b00001100
    OUT     PORTC, R16

	;Configuración de E/S para contador hexadecimal (display)
	LDI		R16, 0b11111111						;Configura PORTD como salida
	OUT		DDRD, R16

    ;Deshabilitar el módulo serial (apaga otros LEDs del Arduino)
    LDI     R16, 0x00
    STS     UCSR0A, R16
    STS     UCSR0B, R16
    STS     UCSR0C, R16

    ;Inicializar el contadores a 0
    LDI     BIN_COUNTER, 0
	LDI		HEX_COUNTER, 0
	LDI		TICK_COUNTER, 0

    ;Configurar interrupciones por cambio (Pin Change Interrupt) para PORTC:
    ;Habilitar el grupo de interrupciones PCINT1 (PCINT8 a PCINT14)
    LDI     R16, (1<<PCIE1)
    STS     PCICR, R16
    ;Habilitar la interrupción en PC2 y PC3 (que corresponden a PCINT10 y PCINT11)
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16

	;Configurar el timer0 en modo CTC para generar una interrupción cada 20ms
	LDI		R16, (1<<WGM01)			;Configurar modo CTC
    OUT     TCCR0A, R16
	LDI		R16, (1<<CS02)			;Prescaler 256
    OUT     TCCR0B, R16
	LDI		R16, 77					;OCR0A = 77
	OUT		OCR0A, R16
	LDI		R16, (1<<OCIE0A)		;Habilitar interrupción Compare Match A de timer0
	STS		TIMSK0, R16

    SEI								;;Habilitar interrupciones globales

;Bucle principal (se queda aquí esperando la ISR)
MAIN_LOOP:
    rjmp MAIN_LOOP				;Bucle infinito


;ISR: Interrupción por cambio en PORTC (PCINT1)
PCINT1_ISR:
    ;Leer el estado actual de PORTC
    IN      R16, PINC
    ;Si PC2 (bit 2) está presionado (nivel 0), se incrementa el contador.
    SBRS    R16, 3						;Si PC2 = 1 (no presionado), salta la siguiente instrucción
    INC     BIN_COUNTER					;Si PC2 = 0 (presionado), incrementa el contador
    ;Si PC3 (bit 3) está presionado (nivel 0), se decrementa el contador.
    SBRS    R16, 2						;Si PC3 = 1, salta la siguiente instrucción
    DEC     BIN_COUNTER					;Si PC3 = 0, decrementa el contador
    ;Asegurar que el contador se mantenga en 4 bits (0 a 15)
    ANDI    BIN_COUNTER, 0x0F
    ;Actualizar los LEDs en PORTB (conectados a PB0-PB3)
    OUT     PORTB, BIN_COUNTER

    ;Deshabilitar la interrupción por cambio (anti-rebote):
    ;Se evita que se procesen nuevos eventos hasta que transcurran 20ms.
    LDI     R16, 0
    STS     PCMSK1, R16

	RETI

TIMER0_COMPA_ISR:
	;Contador de ticks para el contador hexadecimal
	INC		TICK_COUNTER		;Incrementar contador de ticks
	CPI		TICK_COUNTER, 50	;50*20ms = 1000ms (1 segundo)
	BRNE	NO_SEC				;no ha pasado un segundo, salta a anti rebote
	;Pasa 1 segundo
    LDI		TICK_COUNTER, 0      ;Reiniciar TICK_COUNTER
    INC		HEX_COUNTER          ;Incrementar HEX_COUNTER (de 0 a 15)
    CPI		HEX_COUNTER, 16      ;Si HEX_COUNTER == 16 (0x10)
    BRLO	UPDATE_DISPLAY       ;Si es menor, continúa
    LDI		HEX_COUNTER, 0       ;De lo contrario, reinicia a 0


UPDATE_DISPLAY:
	;Cargar la dirección base de SEG_TABLE en el puntero Z
	LDI		ZH, HIGH(SEG_TABLE<<1)
    LDI		ZL, LOW(SEG_TABLE<<1)
    ;Sumar el valor de HEX_COUNTER (R19) para obtener el desplazamiento
    ADD		ZL, HEX_COUNTER						;Suma el offset en la parte baja
    ;Leer el patrón de segmentos desde la tabla en R16
    LPM		R16, Z
    ;Enviar el patrón a PORTD para actualizar el display
    OUT		PORTD, R16


NO_SEC:
    IN      R16, PINC			;Leer estado del puerto
    ANDI    R16, 0x0C           ;Enmascarar para conservar solo PC2 y PC3 (ambos con pull-up, sin presionar = 1)
    ; Si ambos botones están liberados, R16 debe ser 0x0C.
    CPI     R16, 0x0C
    BRNE    SKIP_ENABLE          ;Si no están liberados, no reactivamos la PCINT
    ;Reactivar la interrupción por cambio para PC2 y PC3
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16
SKIP_ENABLE:
    RETI


