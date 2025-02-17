//***************************************************************
//Universidad del Valle de Guatemala 
//IE2023: Programaci�n de Microcontroladores
//Autor: H�ctor Alejandro Mart�nez Guerra
//Hardware: ATMEGA328P
//PRE_LAB3
//***************************************************************

//***************************************************************
//ENCABEZADO
//***************************************************************
.include "M328PDEF.inc"
.def BIN_COUNTER = R20

; Tabla de Vectores
.org 0x0000
    RJMP SET_UP							;Vector de reset: salta a la rutina de configuraci�n

;Vector de interrupci�n para PCINT1 (PORTC: pines PCINT8 a PCINT14)
.org 0x0008
    RJMP PCINT1_ISR

; Vector de interrupci�n para Timer0 Compare Match A
.org 0x001C
    RJMP TIMER0_COMPA_ISR

;Configuraci�n de la pila
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16


SET_UP:
    ;Configurar Prescaler: F_CPU = 1 MHz
    LDI     R16, (1<<CLKPCE)
    STS     CLKPR, R16					;Habilitar cambio de prescaler
    LDI     R16, 0b00000100				;Configurar Prescaler a 16 F_cpu = 1MHz 
    STS     CLKPR, R16

    ;Configuraci�n de PORTB: PB0-PB3 como salidas (LEDs)
    LDI     R16, 0b00001111				;Configura bits 0 a 3 como salidas
    OUT     DDRB, R16

    ;Configuraci�n de PORTC: Entrada para los pushbuttons
    LDI     R16, 0x00
    OUT     DDRC, R16					;Puerto C como entrada

    ;Activar pull-ups internos en PC2 y PC3
    LDI     R16, 0x0C					;0x0C = 0b00001100
    OUT     PORTC, R16

    ;Deshabilitar el m�dulo serial (apaga otros LEDs del Arduino)
    LDI     R16, 0x00
    STS     UCSR0A, R16
    STS     UCSR0B, R16
    STS     UCSR0C, R16

    ; Inicializar el contador (R20) a 0
    LDI     BIN_COUNTER, 0

    ;Configurar interrupciones por cambio (Pin Change Interrupt) para PORTC:
    ;Habilitar el grupo de interrupciones PCINT1 (PCINT8 a PCINT14)
    LDI     R16, (1<<PCIE1)
    STS     PCICR, R16

    ;Habilitar la interrupci�n en PC2 y PC3 (que corresponden a PCINT10 y PCINT11)
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16

	;Configurar el timer0 en modo CTC para generar una interrupci�n cada 20ms
	LDI		R16, (1<<WGM01)			;Configurar modo CTC
    OUT     TCCR0A, R16
	LDI		R16, (1<<CS02)			;Prescaler 256
    OUT     TCCR0B, R16
	;OCR0A = 77
	LDI		R16, 77
	OUT		OCR0A, R16
	;Habilitar interrupci�n Compare Match A de timer0
	LDI		R16, (1<<OCIE0A)
	STS		TIMSK0, R16

    ;Habilitar interrupciones globales
    SEI

;Bucle principal (se queda aqu� esperando la ISR)
MAIN_LOOP:
    rjmp MAIN_LOOP				;Bucle infinito



;ISR: Interrupci�n por cambio en PORTC (PCINT1)
PCINT1_ISR:
    ;Leer el estado actual de PORTC
    IN      R16, PINC
    ;Si PC2 (bit 2) est� presionado (nivel 0), se incrementa el contador.
    SBRS    R16, 3						;Si PC2 = 1 (no presionado), salta la siguiente instrucci�n
    INC     BIN_COUNTER					;Si PC2 = 0 (presionado), incrementa el contador
    ;Si PC3 (bit 3) est� presionado (nivel 0), se decrementa el contador.
    SBRS    R16, 2						;Si PC3 = 1, salta la siguiente instrucci�n
    DEC     BIN_COUNTER					;Si PC3 = 0, decrementa el contador
    ;Asegurar que el contador se mantenga en 4 bits (0 a 15)
    ANDI    BIN_COUNTER, 0x0F
    ;Actualizar los LEDs en PORTB (conectados a PB0-PB3)
    OUT     PORTB, BIN_COUNTER

    ;Deshabilitar la interrupci�n por cambio (anti-rebote):
    ;Se evita que se procesen nuevos eventos hasta que transcurran 20ms.
    LDI     R16, 0
    STS     PCMSK1, R16

	RETI

TIMER0_COMPA_ISR:
    IN      R16, PINC			;Leer estado del puerto
    ANDI    R16, 0x0C           ;Enmascarar para conservar solo PC2 y PC3 (ambos con pull-up, sin presionar = 1)
    ; Si ambos botones est�n liberados, R16 debe ser 0x0C.
    CPI     R16, 0x0C
    BRNE    SKIP_ENABLE          ;Si no est�n liberados, no reactivamos la PCINT
    ;Reactivar la interrupci�n por cambio para PC2 y PC3
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16
SKIP_ENABLE:
    RETI


