//***************************************************************
//Universidad del Valle de Guatemala 
//IE2023: Programación de Microcontroladores
//Autor: Héctor Alejandro Martínez Guerra
//Hardware: ATMEGA328P
//POST_LAB3
//***************************************************************

//***************************************************************
//ENCABEZADO
//***************************************************************
.include "M328PDEF.inc"
.def BIN_COUNTER = R20					;Contador binario
.def SEC_COUNTER = R21					;Contador hexadecimal (Segundos)
.def TICK_COUNTER = R22					;Contador de ticks para contar 1000ms
.def DEC_COUNTER = R23					;Contador de decenas
.def MULTIPLEX_STATE = R24				;Estado para multiplexar (0: segundos, 1: decenas)

;Tabla de Vectores
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

//TABLA 7 SEG (Catodo comun)
SEG_TABLE:.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F,	0x6F ;(0-9)
;0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71  (A-F)

SET_UP:
    ;Configurar Prescaler: F_CPU = 1 MHz
    LDI     R16, (1<<CLKPCE)
    STS     CLKPR, R16					;Habilitar cambio de prescaler
    LDI     R16, 0b00000100				;Configurar Prescaler a 16 F_cpu = 1MHz 
    STS     CLKPR, R16

	;Configuración de E/S para contador binario
    LDI     R16, 0b00111111				;Configuración de PORTB: PB0-PB3 como salidas (LEDs), PB4 (Decenas) y PB5 (segundos) para multiplexar
    OUT     DDRB, R16
    ;Configuración de PORTC: Entrada para los pushbuttons
    LDI     R16, 0x00
    OUT     DDRC, R16					;Puerto C como entrada
    ;Activar pull-ups internos en PC2 y PC3
    LDI     R16, 0x0C					;0x0C = 0b00001100
    OUT     PORTC, R16

	;Configuración de E/S para contador hexadecimal (display)
	LDI		R16, 0b11111111				;Configura PORTD como salida
	OUT		DDRD, R16

    ;Deshabilitar el módulo serial (apaga otros LEDs del Arduino)
    LDI     R16, 0x00
    STS     UCSR0A, R16
    STS     UCSR0B, R16
    STS     UCSR0C, R16

    ;Inicializar el contadores a 0
    LDI     BIN_COUNTER, 0
	LDI		SEC_COUNTER, 0
	LDI		TICK_COUNTER, 0
	LDI		DEC_COUNTER, 0
	LDI		MULTIPLEX_STATE, 0

    ;Configurar interrupciones por cambio (Pin Change Interrupt) para PORTC:
    ;Habilitar el grupo de interrupciones PCINT1 (PCINT8 a PCINT14)
    LDI     R16, (1<<PCIE1)
    STS     PCICR, R16
    ;Habilitar la interrupción en PC2 y PC3 (que corresponden a PCINT10 y PCINT11)
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16

	;Configurar el timer0 en modo CTC para generar una interrupción cada 10ms
	LDI		R16, (1<<WGM01)				;Configurar modo CTC
    OUT     TCCR0A, R16
	LDI		R16, (1<<CS00) | (1<<CS01)	;Prescaler 64
    OUT     TCCR0B, R16
	LDI		R16, 155					;OCR0A = 155
	OUT		OCR0A, R16
	LDI		R16, (1<<OCIE0A)			;Habilitar interrupción Compare Match A de timer0
	STS		TIMSK0, R16

    SEI									;Habilitar interrupciones globales

;Bucle principal (se queda esperando la ISR)
MAIN_LOOP:
    RJMP MAIN_LOOP						;Bucle infinito


;ISR: Interrupción por cambio en PORTC (PCINT1)
PCINT1_ISR:
    ;Leer el estado actual de PORTC
    IN      R16, PINC
    ;Si PC3 (bit 3) está presionado (nivel 0), se incrementa el contador.
    SBRS    R16, 3						;Si PC3 = 1 (no presionado), salta la siguiente instrucción
    INC     BIN_COUNTER					;Si PC3 = 0 (presionado), incrementa el contador
    ;Si PC2 (bit 2) está presionado (nivel 0), se decrementa el contador.
    SBRS    R16, 2						;Si PC2 = 1, salta la siguiente instrucción
    DEC     BIN_COUNTER					;Si PC2 = 0, decrementa el contador
    ;Asegurar que el contador se mantenga en 4 bits (0 a 15)
    ANDI    BIN_COUNTER, 0x0F
    ;Actualizar los LEDs en PORTB (conectados a PB0-PB3)
    OUT     PORTB, BIN_COUNTER

    ;Deshabilitar la interrupción por cambio (anti-rebote):
    ;Se evita que se procesen nuevos eventos hasta que transcurran 10ms.
    LDI     R16, 0
    STS     PCMSK1, R16

	RETI

TIMER0_COMPA_ISR:
	;Contador de ticks para el contador hexadecimal
	INC		TICK_COUNTER			;Incrementar contador de ticks
	CPI		TICK_COUNTER, 100		;100*10ms = 1000ms (1 segundo)
	BRNE	MULTIPLEXING			;no ha pasado un segundo, salta a MULTIPLEXING
	;Pasa 1 segundo
    LDI		TICK_COUNTER, 0			;Reiniciar TICK_COUNTER
    INC		SEC_COUNTER				;Incrementar SEC_COUNTER (de 0 a 9)
    CPI		SEC_COUNTER, 10			;Si SEC_COUNTER == 10
    BRLO	MULTIPLEXING			;Si es menor, salta MULTIPEXING
	;Si Pasa 10 segundos (SEC_COUNTER es 10)  
	LDI		SEC_COUNTER, 0			;De lo contrario, reinicia SEC_COUNTER a 0
	INC		DEC_COUNTER				;Incrementa decenas (DEC_COUNTER)
	CPI		DEC_COUNTER, 6			;DEC_COUNTER llego a 6 (60s)?
	BRLO	MULTIPLEXING			;Si es menor, continua
	;Si llego a 6 (60s), reiniciar ambos contadores (segundos+decenas)
	LDI		DEC_COUNTER, 0
	LDI		SEC_COUNTER, 0

MULTIPLEXING:	
	CPI		MULTIPLEX_STATE, 0		;Comparar MULTIPLEX_STATE con 0
	BRNE	MOSTRAR_DECENAS			;si no es cero, mostrar decenas
	;Si es 0 muestra segundos
	;Cargar la dirección base de SEG_TABLE en el puntero Z
	LDI		ZH, HIGH(SEG_TABLE<<1)
    LDI		ZL, LOW(SEG_TABLE<<1)
    ;Sumar el valor de SEC_COUNTER (R21) para obtener el desplazamiento
    ADD		ZL, SEC_COUNTER			;Desplazar segun el estado de SEC_COUNTER (0-9)
    LPM		R16, Z					;Carga el valor en R16
    OUT		PORTD, R16				;Mostrar valor en puerto D

	;Activar PB5 (segundos) y desactivar PB4 (decenas)
	IN		R17, PORTB				;Leer PORTB
	LDI		R18, 0xCF				;0xCF = 1100 1111, para limpiar PB4 y PB5
	AND		R17, R18				;Limpiar PB4 y PB5
	LDI		R18, 0x20				;0x20 = 0010 0000 (PB5)
	OR		R17, R18				;Activar PB5
	OUT		PORTB, R17
	RJMP	TOGGLE_MUX

MOSTRAR_DECENAS:
    ;Mostrar dígito de decenas (DEC_COUNTER)
    LDI     ZH, HIGH(SEG_TABLE<<1)
    LDI     ZL, LOW(SEG_TABLE<<1)
    ADD     ZL, DEC_COUNTER			;Usar DEC_COUNTER (0-5)
    LPM     R16, Z
    OUT     PORTD, R16

	;desactivar PB5 (segundos) y activar PB4 (decenas)
	IN		R17, PORTB				;Leer PORTB
	LDI		R18, 0xCF				;Limpiar PB4 y PB5
	AND		R17, R18
	LDI		R18, 0x10				;0x10 = 0001 0000 (PB4)
	OR		R17, R18
	OUT		PORTB, R17

	;Si MULTIPLEX_STATE es 0, se cambia a 1, si es 1, se cambia a 0.
TOGGLE_MUX:
	LDI		R16, 0x10				;Carga en R16 el valor 0x10 (0001 0000 binario)
	EOR		MULTIPLEX_STATE, R16	;Alterna el estado de MULTIPLEX_STATE

	;Reactivación de anti rebote
    IN      R16, PINC				;Leer estado del puerto
    ANDI    R16, 0x0C				;Enmascarar para conservar solo PC2 y PC3 (ambos con pull-up, sin presionar = 1)
    ;Si ambos botones están liberados, R16 debe ser 0x0C.
    CPI     R16, 0x0C
    BRNE    SKIP_ENABLE				;Si no están liberados, no reactivamos la PCINT
    ;Si R16 es igual a 0x0C, Reactivar la PCINT para PC2 y PC3
    LDI     R16, (1<<PCINT10) | (1<<PCINT11)
    STS     PCMSK1, R16
SKIP_ENABLE:
    RETI


