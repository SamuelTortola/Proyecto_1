;******************************************************************************
; Universidad Del Valle De Guatemala
; IE2023: Programación de Microcontroladores
; Autor: Samuel Tortola - 22094
; Proyecto: Proyecto reloj real
; Hardware: Atmega238p
; Creado: 16/02/2024
; Última modificación: 02/03/2024 
;******************************************************************************


;******************************************************************************
;ENCABEZADO
;******************************************************************************
.include "M328PDEF.inc"
.EQU T1VALUE = 0xBDC  //Variable constante

//enero = 31
//febrero = 28
//marzo = 31
//abril = 30
//mayo = 31
//junio = 30
//julio = 31
//agosto = 31
//septiembre = 30
//octubre = 31
//noviembre = 30
//diciembre = 31

.CSEG
.ORG 0x00
	JMP MAIN  //Vector RESET
.ORG 0X0006
	JMP ISR_PCINT0 //Vector de interrupciones de pulsadores

.ORG 0x001A
	JMP ISR_TIMER1_OVF  //Vector de interrupciones del timer1

.ORG 0X0020
	JMP ISR_TIMER0_OVF //Vector de interrupciones del timer0

MAIN:
	;******************************************************************************
	;STACK POINTER
	;******************************************************************************
	LDI R16, LOW(RAMEND)  
	OUT SPL, R16
	LDI R17, HIGH(RAMEND)
	OUT SPH, R17


;******************************************************************************
;CONFIGURACIÓN
;******************************************************************************

SETUP:
	LDI R16, 0b1000_0000
	LDI R16, (1 << CLKPCE) //Corrimiento a CLKPCE
	STS CLKPR, R16        // Habilitando el prescaler 

	LDI R16, 0b0000_0000
	STS CLKPR, R16   //Frecuencia del sistema de 16MHz

	LDI R16, (1 << PCIE0)
	STS PCICR, R16  //Habilitando PCINT 0-7 

	LDI R16, (1 << PCINT1)|(1 << PCINT2)
	STS PCMSK0, R16      //Registro de la mascara

	LDI R16, 0b11111111
    OUT DDRD, R16   //Configurar pin PD0 a PD7 Como salida 
	//conexiones de display a atmega: a=PD0, b=PD1, c=PD2, d=PD3, e=PD4, f= PD5, g=PD6, Alarma = PD7


	LDI R16, 0b00100000   //Configurar PB0 a PB4 para pulsadores, PB5 para LED de fecha
	//PB0 = display1 up, PB1 = display1 down, PB2 = display2 up, PB3 = display2 down, PB4 = Cambio de modo
	OUT DDRB, R16  
	LDI R16, 0b00011111
	OUT PORTB, R16    //Configurar PULLUP de pin PB0 a PB4

	LDI R16, 0b0111111  //Configurar PC0 a PC5 como salida
	// PC0 a PC3 para transistores, PC4 para LEDS puntos de display, PC5 para LED de hora
	OUT DDRC, R16

	LDI R16, (1 << PCIE0)
	STS PCICR, R16  //Habilitando PCINT 0-7 

	LDI R16, (1 << PCINT0)|(1 << PCINT1)|(1 << PCINT2)|(1 << PCINT3)|(1 << PCINT4)
	STS PCMSK0, R16      //Registro de la mascara timer0
	SEI  //Habilitar interrupciones Globales

	TABLA: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7C, 0x07, 0x7F, 0X6F  //Tabla de 0-9 numeros decimal
	
	LDI R19, 0  //Muestra display 1  HORA
	LDI R20, 0  //Muestra display 2  HORA
	LDI R21, 0  //Muestra display 3  HORA
	LDI R22, 0  //Muestra display 4  HORA

	LDI R31, 0 //Muestra display 1  FECHA
	LDI R27, 1  //Muestra display 2  FECHA   ((NO TOCAR VALOR DE 1))
	LDI R28, 0  //Muestra display 3  FECHA (MES)
	LDI R29, 1  //Muestra display 4  FECHA (MES)   ((NO TOCAR VALOR DE 1))

	MOV R2, R31  //Copiar datos de R31-R29, a R2-R5
	MOV R3, R27
	MOV R4, R28
	MOV R5, R29

	LDI R24, 0 //Contador de segundos
	LDI R31, 0 //Antirrebote 1

	CLR R13
	
	LDI R25, 1
	MOV R6, R25  //Contador de dias que pasan 
	MOV R9, R25  //Contador de meses que pasan 
	MOV R8, R25
	MOV R7, R31

	MOV R11, R31  //Registro 1  de alarma  
	MOV R12, R31  //Registro 2  de alarma 
	MOV R14, R31  //Registro 3  de alarma 
	MOV R15, R31  //Registro 4  de alarma 
	
	CALL INITTIMER0 //Arrancando timer0
	CALL INITTIMER1 //Arrancando el timer1
	

LOOP: 
	CPI R18, 125  //Retardo de 500ms para parpadeo de LEDs
    BREQ PAR
	
    CPI R24, 15  //Retardo de 1 minuto
	BREQ MI

	CPI R17, 0  //Si se requiere mostrar la hora
	BREQ HO1
	CPI R17, 1 //Si se requiere mostrar la Fecha
	BREQ FE
	CPI R17, 2  //Si se quiere cambiar la hora
	BREQ CAH

	CPI R17, 3  //Si se quiere cambiar la fecha
	BREQ CAF

	CPI R17, 4  //Si se quiere configurar la alarma
	BREQ CAAA

	CPI R17, 5  //Si se quiere Apagar la alarma
	BREQ APAGARR

	CPI R17, 6  //Cuando se llega al total de configuracion 
	BREQ REESETT

	CPI R17, 7  //Cuando se llega al total de configuracion 
	BREQ REESETT

	CPI R17, 17  //Cuando se llega al total de configuracion 
	BRSH REESETT

	CPI R17, 16  //Si esta activa la alarma
	BREQ HOLAAA

	JMP LOOP

REESETT:
	JMP REESET

CAAA:
	JMP CAMBIOALARMA
FE:
		CPSE R7, R17    //Hacer la función solo una vez
			SBI PINC, PC5  //Apagar el LED de hora

		CPSE R7, R17   //Hacer la función solo una vez
			SBI PINB, PB5   //Mostrar LED de fecha

		CPSE R7, R17   //Hacer la función solo una vez
			IN R10, PINC

		SBRS R10, 4    //En caso los LEDs del centro esten apagados
			SBI PINC, PC4   //Mostrar LEDS centrales

		LDI R25, 1       //Forzar al CPSE a no realizarse 
		MOV R7, R25
		LDI R25,0b0010000   //Forzar al SBRS a no realizarse
		MOV R10, R25
		
		CLR R8    //Limpiar registro 8
		
		JMP FECHA

	HO1:
	   
		CPSE R8, R17   //Hacer la función solo una vez
			SBI PINC, PC5   //Mostrar LED de  hora
			
		CPSE R7, R17
			SBI PINB, PB5   //Apagar LED de fecha

		CPSE R7, R17   //Hacer la función solo una vez
			SBI PINC, PC5   //encender LED hora de regreso de la vuelta

		LDI R26, 0  
		MOV R8, R26
		CLR R7   //Limpiar registro 7 

		JMP HORA
PAR:
	JMP PARPADEO

MI:
	JMP MINUTOS

CAH:
	JMP CAMBIOHORA

CAF:
	JMP CAMBIOFECHA

APAGARR:
	JMP APAGAR

HOLAAA:
	JMP ACTIVANO

CAMBIOHORA:   //Configuración cambio de hora
    CLR R24 //iniciar de 0 el contador de minutos
	SBRS R0, PB0 // Salta si el bit del registro es 0 
	INC R20     //Incrementa arreglo de display 1

	SBRS R0, PB2 // Salta si el bit del registro es 0 
	INC R22    //Incrementa arreglo de display 2

	SBRS R0, PB1 // Salta si el bit del registro es 0 
	DEC R20    //Decrementa arreglo de display 1

	SBRS R0, PB3 // Salta si el bit del registro es 0 
	DEC R22    //Decrementa arreglo de display 2


	LDI R25, 0b00001111   //Bloquear R0
	MOV R0, R25

	CPI R22, 10   //si display 4 llega a 9
	BREQ HH

	CPI R20, 10  //Si display 2 llega a 9
	BREQ INCR19

	CPI R19, 2   //Si display 1 llega a 2
	BRSH IINCR19

	CPI R20, 0  //display 2 llega a -1
	BRLT RES11  //Salta si es menor, con signo

	CPI R22, 0  //display 4 llega a -1
	BRLT RES111  //Salta si es menor, con signo

	JMP HORA

INCR19:
	INC R19   //Incrementar display 1
	CLR R20   //limpiar display 2
	JMP HORA

IINCR19:
	CPI R20, 4   //Si display 2 muestra un 3
	BREQ REE
	CPI R20, 0 //Si display 2 muestra un 0
	BRLT REA
	JMP HORA

REE:
	LDI R20, 0  //restear todo el arreglo de primer display
	LDI R19, 0
	JMP HORA

RES11:
	CPI R19, 1   //Si display 1 llega a 1
	BREQ IINCR199
	LDI R19, 2
	LDI R20, 3
	JMP HORA

REA:
	LDI R19, 1  //Colocar el valor 19 en el primer arreglo de displays
	LDI R20, 9
	JMP HORA

IINCR199:
	CPI R20,0    //Cuando el arreglo de display 1 llegue a 10
	BRLT IINCR1999
	JMP HORA

IINCR1999:
	LDI R19, 0  //Colocar el arreglo de display 1 a 09
	LDI R20, 9
	JMP HORA


HH:
	INC R21  //Incrementar valor en display 3
	CPI R21, 6  //si display 3 llega 5
	BRSH HHH
	CLR R22
	JMP HORA

HHH:
	CPI R22, 10  //Verificar si display 4 llegó a 9
	BREQ REH
	JMP HORA

REH:
	LDI R21, 0   //Resetear el arreglo de display 2
	LDI R22, 0
	JMP HORA

RES111:
    CPI R21, 5 
	BREQ RES22
    CPI R21, 4
	BREQ RES22
    CPI R21, 3
	BREQ RES22
	CPI R21, 2
	BREQ RES22
	CPI R21, 1
	BREQ RES22
	LDI R21, 5
	LDI R22, 9
	JMP HORA

RES22:
	DEC R21    //Decrementar valor de display 3
	LDI R22, 9  //Colocar display 4 en 9
	JMP HORA

REESET:
	LDI R17,0   //Limpiar registro 17
	MOV R13, R17  //Mover registro 17 a 13
	IN R26, PINC
	SBRC R26, PC5  //Salta si el bit esta en 1
		SBI PINC, PC5  //Apaga o enciende el LED de hora

	IN R25, PIND
	SBRC R25, PD7    //Si en dado caso la alarma esta encendida
		SBI PIND, PD7     //Apagar la alarma 

	SBRC R25, PD7    //Si en dado caso la alarma esta encendida
	    LDI R26, 2 

	SBRC R25, PD7    //Si en dado caso la alarma esta encendida
	    MOV R1, R26

	SBRC R25, PD7    //Si en dado caso la alarma esta encendida
		LDI R26, 0b0100000

	SBRC R25, PD7    //Si en dado caso la alarma esta encendida
		OUT PORTC, R26	
	 
	JMP LOOP

CAMBIOFECHA:
	MOV R26, R2 //Mover registro 2 a 26
	MOV R27, R3 //Mover registro 3 a 27
	MOV R28, R4 //Mover registro 4 a 28
	MOV R29, R5 //Mover registro 5 a 29

	CPSE R7, R17   //Hacer la función solo una vez
		IN R10, PINC

	SBRS R10, 4    //En caso los LEDs del centro esten apagados
		SBI PINC, PC4   //Mostrar LEDS centrales

   CPSE R7, R17
	    IN R31, PINC

   SBRS R31, 5
	SBI PINC, PC5  //Encender LED de hora
	

	LDI R25, 1       //Forzar al CPSE a no realizarse 
	MOV R7, R25
	LDI R25,0b0010000   //Forzar al SBRS a no realizarse
	MOV R10, R25
	LDI R25, 0b00100000
	MOV R31, R25

	SBRS R0, PB0 // Salta si el bit del registro es 0 
		JMP SPB0
	
	SBRS R0, PB2 // Salta si el bit del registro es 0 
		JMP SPB2

	SBRS R0, PB1 // Salta si el bit del registro es 0 
		JMP SPB1

	SBRS R0, PB3 // Salta si el bit del registro es 0 
		JMP SPB3

	JMP FECHA

	COMPA:
			LDI R25, 0b00001111   //Bloquear R0
			MOV R0, R25

			MOV R25, R9   //Meses que han pasado
			CPI R25, 1 //ENERO
			BREQ SS311

			CPI R25, 2 //FEBRERO
			BREQ SS288

			CPI R25, 3  //MARZO
			BREQ SS311

			CPI R25, 4  //ABRIL
			BREQ SS300

			CPI R25, 5   //MAYO
			BREQ SS311

			CPI R25, 6  //JUNIO
			BREQ SS300

			CPI R25, 7  //JULIO
			BREQ SS311

			CPI R25, 8  //AGOSTO
			BREQ SS311

			CPI R25, 9   //SEPTIEMBRE
			BREQ SS300

			CPI R25, 10   //OCTUBRE
			BREQ SS311

			CPI R25, 11    //NOVIEMBRE
			BREQ SS300

			CPI R25, 12  //DICIEMBRE
			BREQ SS311

			INTERFA:

				CPI R27, 10  //Si display 2 llega a mostrar 9
				BREQ FS11

				CPI R27, -1  //Si display 2 llega a mostrar 0
				BREQ F55 

				CPI R29, 10    //Si display 4  llega a mostrar 9
				BREQ F1sa

				CP R6, R30  //Cuando se llega al dia total del mes, desde enero hasta diciembre, dependiendo del dia final de cada mes
	            BREQ FFSS

				MOV R25, R6
				CPI R25, 33   //Limite para que los dias no pasen de 32, por si hay algun error
				BREQ FFSS

				CPI R25, 0
				BREQ MAYO

				CPI R28, 1  //Si display 3 llega a mostrar 1
				BREQ F288

				CPI R29, 0  //Si display 4 llega a mostrar 1
				BREQ F3rr

				
				MOV R3, R27 //Mover registro 27 a 3
				MOV R2, R26 //Mover registro 26 a 2
				MOV R4, R28  //Mover registro 28 a 4
				MOV R5, R29  //Mover registro 29 a 5
				JMP FECHA
FS11:
	JMP FS1

F55:
	JMP F5
FFSS:
	JMP RETRA

SS311:
	LDI R30, 32
	JMP INTERFA

SS300:
	LDI R30, 31
	JMP INTERFA

SS288:
	LDI R30, 29
	JMP INTERFA

F3rr:
	JMP F3

MAYO:
	JMP MAYOR

F1sa:
	JMP F1

F288:
	JMP F2

SPB0:
	INC R27     //Incrementa arreglo de display 1
	INC R6    //Incrementa dias que van pasando 
	MOV R3, R27 //Mover registro 27 a 3

	JMP COMPA

SPB1:
	DEC R27    //Decrementa arreglo de display 1
	DEC R6   //Decrementa dias que van pasando 
	MOV R3, R27 //Mover registro 27 a 3

	JMP COMPA

SPB2:
	INC R29    //Incrementa arreglo de display 2
	INC R9  //Incrementa meses que van pasando

	JMP COMPA

SPB3:
	DEC R29    //Decrementa arreglo de display 2
	DEC R9    //Decrementa meses que van pasando 

	JMP COMPA


F1:
	INC R28
	CLR R29
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5
	JMP FECHA

F2:
	CPI R29, 3  //Si se llega al mes 12
	BREQ FR
	CPI R29, -1
	BREQ F4
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5
	JMP FECHA

FR:
	CLR R28
	LDI R29, 1
	MOV R9, R29  //Reiniciar conteo de meses
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5
	JMP FECHA

F3:
	LDI R28, 1
	LDI R29, 2
	LDI R25, 12
	MOV R9, R25   //Los meses deben de ser 12
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5
	JMP FECHA

F4:
	LDI R28, 0
	LDI R29, 9
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5
	JMP FECHA

FS1:
	INC R26   //Aumentar el valor en display 1
	CLR R27
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA

F5:
	DEC R26
	LDI R27, 9
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA

RETRA:
	LDI R26, 0
	LDI R27, 1
	MOV R6, R27
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA

MAYOR:
	CPI R30, 29
	BREQ MAYO1

	CPI R30, 31
	BREQ MAYO2

	CPI R30, 32
	BREQ MAYO3

	JMP FECHA

MAYO1:
	LDI R26, 2
	LDI R27, 8
	LDI R29, 28
	MOV R6, R29 //Mover registro 29 a 6
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA

MAYO2:
	LDI R26, 3
	LDI R27, 0
	LDI R29, 30
	MOV R6, R29  //Mover registro 29 a 6
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA


MAYO3:
	LDI R26, 3
	LDI R27, 1
	LDI R29, 31
	MOV R6, R29  //Mover registro 29 a 6
	MOV R2, R26 //Mover registro 26 a 2
	MOV R3, R27 //Mover registro 27 a 3
	JMP FECHA


CAMBIOALARMA:
	SBRS R0, PB0 // Salta si el bit del registro es 0 
	INC R12     //Incrementa arreglo de display 1

	SBRS R0, PB2 // Salta si el bit del registro es 0 
	INC R15    //Incrementa arreglo de display 2

	SBRS R0, PB1 // Salta si el bit del registro es 0 
	DEC R12    //Decrementa arreglo de display 1

	SBRS R0, PB3 // Salta si el bit del registro es 0 
	DEC R15    //Decrementa arreglo de display 2

	LDI R25, 0b00001111   //Bloquear R0
	MOV R0, R25

	MOV R25, R11  //Mover registros
	MOV R26, R12
	MOV R27, R14
	MOV R28, R15

	CPI R26, 10   //Si display 2 llega a 9
	BREQ SUMA

	CPI R28, 10  //Si display 4 llega a 9
	BREQ SUMA1

	CPI R26, -1   //Si display 2 llega a 0
	BREQ RESTA

	CPI R28, -1   //Si display 4 llega a 0
	BREQ RESTA1

	CPI R25, 2  //Si display 1 llega a 2
	BRSH REW

	JMP ALARMA

SUMA:
	INC R11       //Incrementar valor de display 1
	CLR R12
	JMP ALARMA

SUMA1:
	INC R14    //Incrementar valor de display 3
	CPI R27, 5   //Si display 3 llega a 5
	BRSH RREW
	CLR R15
	JMP ALARMA

RESTA:
	CPI R25, 0      //Si display 1 esta en 0
	BREQ RESTA2
	DEC R11
	LDI R26, 9
	MOV R12, R26
	JMP ALARMA

RESTA1:
	CPI R27, 0   //Si display 3 esta en 0
	BREQ RESTA3
	DEC R14
	LDI R28, 9
	MOV R15, R28
	JMP ALARMA

RESTA2:
	LDI R25, 2     //Colocar limite inferior
	LDI R26, 3
	MOV R11, R25
	MOV R12, R26
	JMP ALARMA

RESTA3:
	LDI R25, 5    //Colocar limite inferior
	LDI R26, 9
	MOV R14, R25
	MOV R15, R26
	JMP ALARMA

REW:
	CPI R26, 4 //Si display 2 llega a 3
	BRSH  REW1
	JMP ALARMA

REW1:
	CLR R11   //Colocar limite superior
	CLR R12
	JMP ALARMA
	
RREW:
	CLR R14    //Colocar limite superior
	CLR R15
	JMP ALARMA
	

//*********************************MOSTRAR HORA********************************
	HORA: 
	   //Hacer la multiplexación
		CALL RETARDO
		SBI PINC, PC0  //Activar el 1er display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R19
		LPM R25,Z
		OUT PORTD, R25
		CALL RETARDO
		SBI PINC, PC0  //Apagar el 1er display
		SBI PINC, PC1   //Encender el 2do display
	

		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R20
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC1  //Apagar el 2do display
		SBI PINC, PC2   //Encender el 3er display
	

		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R21
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC2  //Apagar el 3er display
		SBI PINC, PC3   //Encender el 4to display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R22
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC3  //Apagar el 4to display
		
JMP LOOPP


RETARDO:
	CPI R23, 1
	BRNE RETARDO
	CLR R23
	RET

PARPADEO:
	SBI PINC, PC4
	CLR R18
	CPSE R13, R17   //Hacer la función solo una vez
		SBI PINC, PC5

	JMP LOOP


MINUTOS:  
	INC R22   //Incrementar minutos del display 4
	CLR R24  //Resetear valor de R24
	CPI R22, 10  
	BREQ MINUTOS2

	LDI R26, 3
	MOV R1, R26  //Permitir la activación de la alarma otra vez
	JMP LOOP

MINUTOS2:
	INC R21  //Incrementar minutos del display 3
	CLR R22  //Poner a 0 el display 1
	CPI R21, 6
	BREQ HORAS

	JMP LOOP

HORAS:
	INC R20  //Incrementar horas de display 2
	CLR R21  //Resetear display 3
	CPI R20, 10 
	BREQ HORAS2
	CPI R19, 2
	BREQ HORAS24

	JMP LOOP

HORAS2:
	INC R19  //Incrementar horas de display 1 
	CLR R20

	JMP LOOP

HORAS24:
	CPI R20, 4 
	BREQ FIN

	JMP LOOP
	

FIN:
	MOV R27, R3 //Mover registro 3 a 27
	MOV R25, R9   //Meses que han pasado

	CLR R19  //Resetea todo el reloj 
	CLR R20 
	INC R27   //Incrementar el display de dias
	INC R6   //Incrementar el contador de días totales
	 
	CPI R25, 1 //ENERO
	BREQ SS31

	CPI R25, 2 //FEBRERO
	BREQ SS28

	CPI R25, 3  //MARZO
	BREQ SS31

	CPI R25, 4  //ABRIL
	BREQ SS30

	CPI R25, 5   //MAYO
	BREQ SS31

	CPI R25, 6  //JUNIO
	BREQ SS30

	CPI R25, 7  //JULIO
	BREQ SS31

	CPI R25, 8  //AGOSTO
	BREQ SS31

	CPI R25, 9   //SEPTIEMBRE
	BREQ SS30

	CPI R25, 10   //OCTUBRE
	BREQ SS31

	CPI R25, 11    //NOVIEMBRE
	BREQ SS30

	CPI R25, 12  //DICIEMBRE
	BREQ SS31

	JMP LOOP

	INTERF:
		CP R6, R29  //Cuando se llega al dia total del mes, desde enero hasta diciembre, dependiendo del dia final de cada mes
	    BREQ FINN
		CPI R27, 10  //Cuando el display de dias llegue a 10 
		BREQ FECHA1	

		MOV R3, R27 //Mover registro 27 a 3

		JMP LOOP

SS31:
	LDI R29, 32
	JMP INTERF

SS30:
	LDI R29, 31
	JMP INTERF

SS28:
	LDI R29, 29
	JMP INTERF


FECHA1:
	MOV R26, R2 //Mover registro 2 a 26

	INC R26  //Incrementar display 2 de dias
	LDI R27, 0 //Resetear el display 1 de dias

	MOV R3, R27 //Mover registro 27 a 3
	MOV R2, R26 //Mover registro 26 a 2

	JMP LOOP

FINN:
	MOV R26, R2 //Mover registro 2 a 26
	MOV R27, R3 //Mover registro 3 a 27
	MOV R29, R5 //Mover registro 5 a 29
	MOV R28, R4 //Mover registro 4 a 28

	LDI R25, 1
	MOV R6, R25 //Limpia registro de conteo de dia total
	CLR R26
	LDI R27, 1
	INC R29  //Incrementa los meses  display 4
	INC R9 //Incrementa contador de meses
	CPI R29, 10
	BREQ MESES
	CPI R28, 1  //Cuando llegue el display 3 a mostar su maximo valor
	BREQ FINMES

	MOV R3, R27 //Mover registro 27 a 3
	MOV R2, R26 //Mover registro 26 a 2
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5

	JMP LOOP




FINMES:
	CPI R29, 3  //Cuando los meses lleguen a diciembre
	BRSH FINTOTAL

	MOV R3, R27 //Mover registro 27 a 3
	MOV R2, R26 //Mover registro 26 a 2
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5

	JMP LOOP

MESES:
	INC R28 //Incrementar contador de meses display 3
	CLR R29 

	MOV R3, R27 //Mover registro 27 a 3
	MOV R2, R26 //Mover registro 26 a 2
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5

	JMP LOOP

FINTOTAL:   //Si el reloj en general llega a 23:59, dia-mes:12
	MOV R26, R2 //Mover registro 2 a 26
	MOV R27, R3 //Mover registro 3 a 27
	MOV R29, R5 //Mover registro 5 a 29
	MOV R28, R4 //Mover registro 4 a 28

	CLR R28
	CLR R26
	LDI R29, 1
	LDI R27, 1
	MOV R9, R27 //Resetear los meses
	MOV R6, R27 //Limpia registro de conteo de dia total
	MOV R25, R27
	MOV R3, R27 //Mover registro 27 a 3
	MOV R2, R26 //Mover registro 26 a 2
	MOV R4, R28  //Mover registro 28 a 4
	MOV R5, R29  //Mover registro 29 a 5

	JMP LOOP

LOOPP:
	
    MOV R25, R12
	MOV R26, R15
	MOV R27, R11
	MOV R28, R14

	CPI R25, 1  //Alarma encendida
	BRSH APAGAR2 

	CPI R26, 1   //Alarma encendida
	BRSH APAGAR2

	CPI R27, 1  //Alarma encendida
	BRSH APAGAR2   

	CPI R28, 1   //Alarma encendida
	BRSH APAGAR2

	JMP LOOP

APAGAR2:
	CP R11, R19   //Si los registros son iguales
	BREQ SEGUIR1
	JMP LOOP

SEGUIR1:
	CP R12, R20  
	BREQ SEGUIR2
	JMP LOOP

SEGUIR2:
	CP R14, R21
	BREQ SEGUIR3
	JMP LOOP

SEGUIR3:
	CP R15, R22
	BREQ ACTIVANO
	JMP LOOP

ACTIVANO:
	CPI R16, 1    //Ver si la alarma esta encendida 
		BREQ SEGUIR47
	JMP LOOP

SEGUIR47:
	MOV R25, R1
	CPI R25, 2
	BREQ QQQ 

SEGUIR41:	 
	LDI R17, 16    
    LDI R25, 0b11001001   //Encender la alarma 
	OUT PORTD, R25
	LDI R25, 0b0001111
	OUT PORTC, R25
	JMP LOOP

QQQ:
	JMP LOOP
	
//********************************MOSTRAR FECHA********************************
FECHA:
  //Hacer la multiplexación
		CALL RETARDO
		LDI R18, 0  //Impedir que aumente
		SBI PINC, PC0  //Activar el 1er display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R2
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC0  //Apagar el 1er display
		SBI PINC, PC1   //Encender el 2do display
	

		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R3
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC1  //Apagar el 2do display
		SBI PINC, PC2   //Encender el 3er display
	

		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R4
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC2  //Apagar el 3er display
		SBI PINC, PC3   //Encender el 4to display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R5
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC3  //Apagar el 4to display

	
JMP LOOP//Regresa al LOOP


//*********************************MOSTRAR Alarma********************************
ALARMA: 
	   //Hacer la multiplexación
		CALL RETARDO
		SBI PINC, PC0  //Activar el 1er display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R11
		LPM R25,Z
		OUT PORTD, R25
		CALL RETARDO
		SBI PINC, PC0  //Apagar el 1er display
		SBI PINC, PC1   //Encender el 2do display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R12
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC1  //Apagar el 2do display
		SBI PINC, PC2   //Encender el 3er display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R14
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC2  //Apagar el 3er display
		SBI PINC, PC3   //Encender el 4to display
	
		LDI ZH, HIGH(TABLA <<1)  //da el byte mas significativo
		LDI ZL, LOW(TABLA <<1) //va la dirección de TABLA
		ADD ZL, R15
		LPM R25,Z
		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC3  //Apagar el 4to display
	
JMP LOOP//Regresa al LOOP


APAGAR:
	CPI R16, 1   //Comprobar si la alarma ya esta activada
		BREQ SALTO1

	CPSE R26, R17   //Hacer la función solo una vez
			LDI R16, 0

	CPSE R26, R17   //Hacer la función solo una vez
			MOV R26, R17 //Mover registro 17 a 25

	SALTO1:
		SBRS R0, PB0 // Salta si el bit del registro es 0 
			JMP ALARMAON

		SBRS R0, PB1 // Salta si el bit del registro es 0 
			JMP ALARMAOFF

		CPI R16, 1     //Si la alarma esta encendida
			BREQ ALARMAON

		CPI R16, 0    //Si la alarma esta apagada
		BREQ ALARMAOFF

	JMP MOSTRARALARMA


MOSTRARALARMA:
	 //Hacer la multiplexación
		CALL RETARDO
		SBI PINC, PC0  //Activar el 1er display

		LDI R28, 0b00111111
		OUT PORTD, R28
	
		CALL RETARDO
		SBI PINC, PC0  //Apagar el 1er display
		SBI PINC, PC1   //Encender el 2do display

		OUT PORTD, R25

		CALL RETARDO
		SBI PINC, PC1  //Apagar el 2do display
		SBI PINC, PC2   //Encender el 3er display
		
		OUT PORTD, R29

		CALL RETARDO
		SBI PINC, PC2  //Apagar el 3er display
		SBI PINC, PC3   //Encender el 4to display

		LDI R25, 0b00001000
		OUT PORTD, R25
		
		CALL RETARDO
		SBI PINC, PC3  //Apagar el 4to display
	
JMP LOOP//Regresa al LOOP

ALARMAON:        //Alarma encendida
	LDI R16, 1
	LDI R25, 0b00110111 
	LDI R29, 0b00001000
	JMP MOSTRARALARMA

ALARMAOFF:
	LDI R16, 0      //Alarma apagada
	LDI R25, 0b01110001
	LDI R29, 0b01110001
	JMP MOSTRARALARMA

;**************************Inicio TIMER0***************************************		
INITTIMER0:     //Arrancar el TIMER0
	LDI R17, 0
	OUT TCCR0A, R17 //trabajar de forma normal con el temporizador

	LDI R17, (1<<CS02)|(1<<CS00)
	OUT TCCR0B, R17  //Configurar el temporizador con prescaler de 1024

	LDI R17, 194
	OUT TCNT0, R17 //Iniciar timer en 100 para conteo

	LDI R17, (1 << TOIE0)
	STS TIMSK0, R17 //Activar interrupción del TIMER0 de mascara por overflow

	LDI R17, 0
	RET

;********************************SUBRUTINA DE TIMER0***************************
ISR_TIMER0_OVF:

	PUSH R17   //Se guarda R17 En la pila 
	IN R17, SREG  
	PUSH R17      //Se guarda SREG actual en R17

	LDI R17, 194  //Cagar el valor de desbordamiento
	OUT TCNT0, R17  //Cargar el valor inicial del contador
	SBI TIFR0, TOV0   //Borrar la bandera de TOV0
	INC R23    //Incrementar el contador de 4ms
	INC R18  //Incrementar el contador de los LEDs parpadeantes
	
	
	POP R17    //Obtener el valor del SREG
	OUT SREG, R17   //Restaurar antiguos valores del SREG
	POP R17    //Obtener el valor de R16    

	RETI //Retornar al LOOP


;**************************Inicio TIMER1***************************************		
INITTIMER1:     //Arrancar el TIMER1

	// TCNT1= T1VALUE = 0xBDC Tiempo de 4s 

	LDI R17, HIGH(T1VALUE)  //Cargar el valor de desbordamiento
	STS TCNT1H, R17  //Valor inicial del temporizador
	LDI R17, LOW(T1VALUE)  //Cargar el valor de desbordamiento
	STS TCNT1L, R17  //Cargar el valor inicial

	CLR R17
	STS TCCR1A, R17  //Trabajar de modo normal 
	
	LDI R17, (1 << CS12) | (1 << CS10)  //Configurar prescaler de 1024
	STS TCCR1B, R17

	LDI R17, (1 << TOIE1) 
	STS TIMSK1, R17  //Activar interrupción del TIMER0 de mascara por overflow

	LDI R17, 0
	RET



;********************************SUBRUTINA DE TIMER1***************************
ISR_TIMER1_OVF:	
    PUSH R16   //Se guarda R16 En la pila 
	IN R16, SREG  
	PUSH R16      //Se guarda SREG actual en R16

	LDI R16, HIGH(T1VALUE)  //Cargar el valor de desbordamiento
	STS TCNT1H, R16  //Valor inicial del temporizador
	LDI R16, LOW(T1VALUE)  //Cargar el valor de desbordamiento
	STS TCNT1L, R16  //Cargar el valor inicial
	SBI TIFR1, TOV1  //Borrar bandera de TOV1

	INC R24 //Incremento cada 4s

	POP R16    //Obtener el valor del SREG
	OUT SREG, R16   //Restaurar antiguos valores del SREG
	POP R16    //Obtener el valor de R16    

	RETI //Retornar al LOOP



;********************************SUBRUTINA DE PULSADORES***********************
ISR_PCINT0:
	PUSH R27
	PUSH R31
	IN R31, SREG
	PUSH R31

	//*********ANTIRREBOTE*******
	INC R31
	MOV R28, R31
	CPI R28, 1
	BRSH continuar
	//****************************

	SBI PCIFR, PCIF0  //Apagar la bandera de ISR PCINT0


	POP R31 //SREG -> R31
	OUT SREG, R31
	POP R31 // Restablecer R31 antes de int
	POP R27 // Restablecer R27 antes de int
	RETI      //Retorna de la ISR

continuar:
	IN R0, PINB  //Leer  el puerto B

    SBRS R0, PB4 // Salta si el bit del registro es 0 (pulsador de cambio de configuración)
	INC R17

	CLR R31
	SBI PCIFR, PCIF0  //Apagar la bandera de ISR PCINT0

    POP R31 //SREG -> R31
	OUT SREG, R31
	POP R31 // Restablecer R31 antes de int
	POP R27 // Restablecer R27 antes de int
	RETI      //Retorna de la ISR
	






