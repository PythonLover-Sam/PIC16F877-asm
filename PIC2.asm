	list P=16F877
	#include p16f877.inc                ; Include register definition file
;====================================================================
; VARIABLES
;====================================================================
duration equ 20h  ; 检测到的持续段数： 2.4ms -25； 600us -8； 1.2ms -18
recording equ 21h  ; 是否记录数据
isDuration equ 28h 
record_num equ 22h ; 记录数据位数
data_l  equ 23h  ; 记录数据的低4位
data_h equ 24h  ; 记录数据的高8位
data_get_bit  equ 25h; 记录本次采样得到的逻辑
value1 equ 26h
value2 equ 27h
display_value equ 29h  ; 数码管显示查表码
temp equ 30h  ; 临时变量
temp2 equ 31h
temp3 equ 32h
count equ 33h
count2 equ 34h
beepMode equ 35h  ; 是否启动蜂鸣器模式标志  蜂鸣器模式： 接收到的12位信息即影响蜂鸣器发声频率
frequency equ 36h
;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================

      ; Reset Vector
RST   code  0x0
      goto  Start
		org 0x04
		goto int_serve

;====================================================================
; CODE SEGMENT
;====================================================================


int_serve
		btfsc PORTB, 4	;检测是否低电平
		goto stop_check_duration_time
		goto start_duration

start_duration  ; 开始检测

		bsf isDuration, 0
		clrw
		movwf duration
		call delay_120us
		goto ret
		
stop_check_duration_time
		bcf isDuration, 0
check_head
		movlw d'50' ; 检测是否开始标志持续时间过长
		subwf duration, W
		btfsc STATUS, C
		goto fault
		movlw d'25'  ; 检测是否是开始标志
		subwf duration, W
		

		btfsc STATUS, C  ; 检测是否发生借位，借位表示此次持续时长并不是开始标志
		goto	 start_record
		goto check_1
check_1  ; 检测是否是逻辑“1”
		movlw d'18'  ; 检测是否是1
		subwf duration, W

		btfsc STATUS, C  ; 检测是否发生借位，借位表示此次持续时长并不是1
		goto record_1  ; 判定此位为 1 跳转记录
		goto check_0
check_0 ; 检测是否是逻辑“0”
		movlw d'8'  ; 检测是否是0
		subwf duration, W

		btfsc STATUS, C  ; 检测是否发生借位，借位表示此次持续时长并不是0
		goto record_0
		goto fault  ; 此次记录的不是有效数据
record_1
		movlw 0x01
		movwf data_get_bit
		call record
		decfsz record_num, F
		goto ret
		goto finish

record_0 
		movlw 0x00
		movwf data_get_bit
		call record
		decfsz record_num, F
		goto ret
		goto finish
record
		bcf STATUS, C  ; 清除进位标志位
		rlf data_l, F
		movf data_get_bit, W
		iorwf data_l, F

		rlf data_h, F
		clrw 
		movwf duration
		bcf isDuration, 0
		return
fault
		btfss recording, 0
		goto ret
		goto Exception  ; 发生异常，进行异常处理
start_record  ; 开始记录数据
		clrw
		movwf duration
		bsf recording, 0
		movlw d'12'
		movwf record_num
		call delay_120us
		goto ret
finish
		bcf recording, 0
		clrw 
		movwf duration
		call handler  ; 接收到数据之后的处理程序
		goto ret
Exception  ; 接收到的数据异常或者不符合通信协议
		movlw 0x0e ; 显示最高位
		call decode
		movwf PORTC
		movlw 0x10
		call decode
		movwf PORTD
		movlw 0xff
		movwf PORTA
		movwf PORTE
		clrw 	
		movwf duration
		goto ret
ret
		bcf INTCON, RBIF
		retfie
PGM   code
Start

		movlw 0xff
		
		movwf data_h
		movwf PORTA
		movwf PORTB
		movwf PORTC
		movwf PORTD
		movwf PORTE
		movlw d'12'
		movwf record_num
		
		bsf STATUS, RP0

		movlw 02h		; 分频比给timer0
		movwf OPTION_REG	; 分频比设置为8
		clrf PIE1 ;禁止其它中断
		bsf INTCON, GIE  ; 使能全局中断
		bcf  INTCON, RBIF
		bsf INTCON, RBIE ; 允许RB口中断
		movlw 0xf0
		movwf TRISB  ; 设置rb4-7口为输入  rb0-3为输出
		clrw
		movwf TRISC
		movwf TRISD  ; 设置c口d口为输出口
		movwf TRISE
		movwf TRISA
		bcf beepMode, 0 ; 默认设置蜂鸣器模式为关闭状态
		bcf STATUS, RP0
		bcf PIE1, TMR1IE

		movf PORTB, F
		call delay_120us
lop
		btfss PIR1, TMR1IF
		goto lop

		bcf PIR1, TMR1IF
		btfss isDuration, 0  ; 检测是否正在记录数据
		goto lop
		call set_duration
		goto lop
set_duration
		incf duration
		call delay_120us
		return 
delay_120us
		bcf  T1CON,  TMR1ON
		movlw 0xff			; TMR1赋初值
		movwf TMR1H
		movlw 0xf4
		movwf TMR1L
		movlw 0x21	; 配置TMR1
		movwf T1CON
		return
handler  ; 接收到数据之后的处理子程序
		movf data_l, W
		movwf frequency  ;  保留原始信息低八位作为蜂鸣器模式下的频率基准
		movf data_h, W  ; 判断指令
		sublw 0x01
		btfss STATUS, Z  
		goto check_234
		movf data_l, W
		
		sublw 0x11
		btfss STATUS, Z
		goto show_number  ; 本条指令不是感兴趣的指令
		call ctrl_light ; 开灯/关灯指令
		goto show_number
ctrl_light  ;  灯泡控制
		btfss PORTB, 0
		goto light1
		goto light0
light1
		bsf PORTB, 0
		return
light0
		bcf PORTB, 0
		return
check_234  ; 检测指令234
		movf data_h, W
		sublw 0x02
		btfss STATUS, Z
		goto check_abc
		movf data_l, W
		sublw 0x34
		btfss STATUS, Z
		goto show_number
		call ctrl_beepMode ;启动/关闭蜂鸣器频率播放模式  
		goto show_number
ctrl_beepMode
		btfss beepMode, 0
		goto beep1
		goto beep0
beep1
		bsf beepMode, 0
		return
beep0
		bcf beepMode, 0
		return

check_abc
		movf data_h, W
		sublw 0x0a
		btfss STATUS, Z
		goto show_number
		movf data_l, W
		sublw 0xbc
		btfss STATUS, Z
		goto show_number
		call play_beep  ;蜂鸣器指令
		goto show_number
		

		
show_number
		
		movf data_h, W ; 显示最高位
		call decode
		movwf PORTC

			; 显示中间位	
		movlw 0x04
		movwf temp  ; 记录移位次数
		clrf temp2 

first		rlf data_l, F
		btfss STATUS, C  ; 检测移出的位是0还是1
		goto set_0
		goto set_1 ; 是1
next		rlf temp2, F
		iorwf temp2, F
		decfsz temp, F
		goto first

nextt

		movf temp2, W
		call decode
		movwf PORTD
		goto ff
set_0
		movlw 0x00
		bcf temp3, 0
		goto next
set_1
		bsf temp3, 0
		movlw 0x01
		goto next 


			; 显示最后位
ff		movlw 0x04
		movwf temp  ; 记录移位次数
		clrf temp2 
first1		rlf data_l, F
		btfss STATUS, C  ; 检测移出的位是0还是1
		goto set_00
		goto set_11 ; 是1
next1		rlf temp2, F
		iorwf temp2, F
		decfsz temp, F
		goto first1

		movf temp2, W
		call decode
		movwf temp2
		movwf PORTA
		goto next2
set_00
		movlw 0x00
		goto next1
set_11
		movlw 0x01
		goto next1
next2		
		
		rlf temp2, F
		rlf temp2, F
		btfss STATUS, C
		goto show0
		goto show1
final
		btfss beepMode, 0
		return
		call play_beep
		return
show0
		bcf PORTE, 0
		goto final
show1
		bsf PORTE, 0
		goto final
decode  ; 七段数码管查表子程序
		addwf PCL, F
		retlw b'01000000'  ; 0
		retlw b'01111001'  ; 1
		retlw b'00100100'  ; 2
		retlw b'00110000'  ; 3
		retlw b'00011001'  ; 4
		retlw b'00010010'  ; 5
		retlw b'00000010'  ; 6
		retlw b'11111000'  ; 7
		retlw b'00000000'  ; 8
		retlw b'00010000'  ; 9
		retlw b'00001000'  ; a
		retlw b'00000011'  ; b
		retlw b'01000110'  ; c
		retlw b'00100001'  ; d
		retlw b'00000110'  ; e
		retlw b'00001110'  ; f
		retlw b'00101111'  ; r  异常提示符

;=====================蜂鸣器模式================
  ; 开始蜂鸣器模式播放
delay_n	; 延迟一段的子程序
		bcf INTCON, 2  ;清除TMR0溢出标志
		movf frequency, W	
		movwf TMR0     ; TMR0赋初值
tmr_loopn 
		btfss INTCON, 2	; 检测TMR0溢出标志
		goto tmr_loopn
		return

play_beep	; 报警铃声播放
		movlw d'5'
		movwf count2
lpn		movlw d'100'
		movwf count
tmr_looppn 
		call delay_n
		decfsz count, F
		goto chgn
		decfsz count2, F
		goto lpn
		return
chgn
		btfss PORTB, 1
		goto chg1n
		goto chg0n
		
chg1n
		bsf PORTB, 1
		goto tmr_looppn
chg0n
		bcf PORTB, 1
		goto tmr_looppn
;====================================================================
      END
