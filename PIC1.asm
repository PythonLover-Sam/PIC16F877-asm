	list P=16F877
	#include p16f877.inc                ; Include register definition file
;====================================================================
; VARIABLES
;====================================================================
delay_1 equ 20h
delay_2 equ 21h 
count equ 22h
bit_data equ 23h  ; 记录发送位数据信息： 0 发送间隔 1 发送数据
send_data_h equ 24h  ; 记录发送的高8位信息
send_data_l equ 25h ; 记录发送的低4位信息:存储格式：0xX0, 即有效信息位于寄存器高四位
send_count equ 26h ; 发送位计数
send_end equ 27h  ; 记录是否发送完毕1位信息
key_pressed_value equ 28h ; 记录按下按键的键值码
MIAO EQU 50H
XUN  EQU 60H      ;计数三次，按下三个按键
ROW  EQU 61H      ;行值寄存器
COLUMN EQU 62H      ;列值寄存器
NUM EQU 63H 

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================

      ; Reset Vector
		org 0x0 
      goto  Start
		org  0x4
		goto int_serv

;====================================================================
; CODE SEGMENT
;====================================================================
int_serv
	btfss PIR1, TMR2IF
	goto retn
	bcf PIR1, TMR2IF  ;清除TMR2溢出标志

	decfsz count, F
	goto out	;定时时间未到
	goto out1	;定时时间已到
out 
	bcf send_end, 0
	btfss bit_data, 0  ; 判断是发送数据还是发送间隔
	goto reset_D ;发送间隔
	call change  ;发送数据
	goto retn

out1	
	bsf send_end, 0
	bcf T2CON, 2
reset_D
	movlw 0x00
	movwf PORTD
retn

		retfie


PGM   code
Start
		movlw 0x01
		movwf count

		movlw 0x00
		movwf PORTB
		movwf PORTD
		movwf PORTC
		movlw 0xc0
		movwf INTCON
		movlw 0x00	; 配置TMR2
		movwf T2CON
		bsf STATUS, RP0
		movlw 0x17	;设置TMR2 PR值
		movwf PR2
		movlw 0x00
		movwf TRISD ; d端口设置为输出——驱动红外二极管
		movlw 0xff
		movwf TRISC
		bsf 	PIE1, TMR2IE ; 开启tmr2中断
		bcf STATUS, RP0
		MOVLW 03H
		MOVWF XUN

lop
		call check_key
		movwf key_pressed_value
		sublw 0xff  ; 判断是否没有按键按下
		btfss STATUS, Z
		goto send_msg
		goto JZKEY  ; 没有按键按下   开始检测矩阵键盘
up			; 检测按键抬起
		movf PORTC, W
		sublw 0x07
		btfss STATUS, Z  ; 判断按键是否抬起
		goto up
		goto lop
up2
		
		movf PORTB,W
		sublw 0xF0
		btfss STATUS,Z
		goto up2
		goto lop
send_msg  ; 判断发送子过程
;========================三个功能按键按下检测==================================
		movf key_pressed_value, W
		sublw 0x00
		btfss STATUS, Z  ; 判断是否是按键0被按下
		goto s1
		movlw 0x10
		movwf send_data_l
		movlw 0x11
		movwf send_data_h
		call send_data  ;==================================第一个指令：0x111
		goto up  ; 检测按键抬起
s1
		movf key_pressed_value, W
		sublw 0x01
		btfss STATUS, Z  ; 判断是否是按键1被按下
		goto s2
		movlw 0x40
		movwf send_data_l
		movlw 0x23
		movwf send_data_h
		call send_data  ;==================================第二个指令：0x234
		goto up  ; 检测按键抬起
s2
		movf key_pressed_value, W
		sublw 0x02
		btfss STATUS, Z  ; 判断是否是按键2被按下
		goto lop
		movlw 0xc0
		movwf send_data_l
		movlw 0xab
		movwf send_data_h
		call send_data  ;==================================第三个指令：0xabc
		goto up  ; 检测按键抬起
check_key
		btfsc PORTC, 0
		goto c1
		retlw 0x00  ; 表示按键0被按下
c1
		btfsc PORTC, 1
		goto c2
		retlw 0x01  ; 表示按键1被按下
c2
		btfsc PORTC, 2
		retlw 0xff  ; 表示没有按键按下
		retlw 0x02  ; 表示按键2被按下
;====================================矩阵键盘检测===================================
JZKEY                ;矩阵键盘线反转法
    BCF STATUS,RP1
    BSF STATUS,RP0
    MOVLW 0x0F
    MOVWF TRISB    ;RB0-RB3为输入，RB4-RB7为输出，行扫描
    BCF STATUS,RP0
    MOVLW 0xFF
    MOVWF MIAO
    MOVLW 0
    MOVWF PORTB     ;高四位输出0
    MOVF PORTB,W    ;读此时的B口状态
    ANDLW 0X0F      ;保留低四位的值到ROW，高四位清零
    MOVWF ROW        
    XORLW 0x0F      ;无键按下时，继续扫描
    BTFSC STATUS,Z
    GOTO  lop  
    BSF STATUS,RP0   ;有键按下时进行列扫描
    MOVLW 0xF0
    MOVWF TRISB
    BCF STATUS,RP0
    MOVF ROW,W
    MOVWF PORTB
    MOVF PORTB,W    
    ANDLW 0xF0      ;保留高四位的值到COLUMN,低四位清零
    MOVWF COLUMN
    IORWF ROW,W     ;列值和行值综合后存入W
    MOVWF NUM
    XORLW 0xEE      ;比较W中的值，进行键码对应的操作
    BTFSS STATUS,Z
    GOTO JUMP1      
    MOVLW 00H       ;将对应数据存入寄存器
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP1                
    MOVF NUM,W
    XORLW 0xDE
    BTFSS STATUS,Z
    GOTO JUMP2
    MOVLW 01H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP2
    MOVF NUM,W
    XORLW 0xBE
    BTFSS STATUS,Z
    GOTO JUMP3
    MOVLW 02H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP3
    MOVF NUM,W
    XORLW 0x7E
    BTFSS STATUS,Z
    GOTO JUMP4
    MOVLW 03H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP4
    MOVF NUM,W
    XORLW 0xED
    BTFSS STATUS,Z
    GOTO JUMP5
    MOVLW 04H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP5
    MOVF NUM,W
    XORLW 0xDD
    BTFSS STATUS,Z
    GOTO JUMP6
    MOVLW 05H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP6
    MOVF NUM,W
    XORLW 0xBD
    BTFSS STATUS,Z
    GOTO JUMP7
    MOVLW 06H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP7
    MOVF NUM,W
    XORLW 0x7D
    BTFSS STATUS,Z
    GOTO JUMP8
    MOVLW 07H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP8
    MOVF NUM,W
    XORLW 0xEB
    BTFSS STATUS,Z
    GOTO JUMP9
    MOVLW 08H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP9
    MOVF NUM,W
    XORLW 0xDB
    BTFSS STATUS,Z
    GOTO JUMP10
    MOVLW 09H
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP10
    MOVF NUM,W
    XORLW 0xBB
    BTFSS STATUS,Z
    GOTO JUMP11
    MOVLW 0AH
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP11
    MOVF NUM,W
    XORLW 0x7B
    BTFSS STATUS,Z
    GOTO JUMP12
    MOVLW 0BH
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP12
    MOVF NUM,W
    XORLW 0xE7
    BTFSS STATUS,Z
    GOTO JUMP13
    MOVLW 0CH
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP13
    MOVF NUM,W
    XORLW 0xD7
    BTFSS STATUS,Z
    GOTO JUMP14
    MOVLW 0DH
    MOVWF MIAO 
    movlw 00h
    movwf PORTB
JUMP14
    MOVF NUM,W
    XORLW 0xB7
    BTFSS STATUS,Z
    GOTO JUMP15
    MOVLW 0EH
    MOVWF MIAO
    movlw 00h
    movwf PORTB
JUMP15
    MOVF NUM,W
    XORLW 0x77
    BTFSS STATUS,Z
    GOTO FINISH
    MOVLW 0FH
    MOVWF MIAO
    movlw 00h
    movwf PORTB
FINISH  
    MOVF MIAO,W
    XORLW 0xFF
    BTFSS STATUS,Z
    DECF XUN,1     ;按下一个键后循环减一
    MOVLW 02H       
    XORWF XUN,0
    BTFSC STATUS,Z
    GOTO ONE
    MOVLW 01H
    XORWF XUN,0
    BTFSC STATUS,Z
    GOTO TWO
    MOVLW 00H
    XORWF XUN,0
    BTFSC STATUS,Z
    GOTO THREE
    GOTO JZKEY
ONE 
    MOVF MIAO,W
    MOVWF send_data_h
    SWAPF send_data_h,1
    goto up2  ; 检测按键抬起
    
TWO
    MOVF MIAO,W
    IORWF send_data_h,1
    goto up2  ; 检测按键抬起
    
THREE 
    MOVF MIAO,W
    MOVWF send_data_l
    SWAPF send_data_l,1
    call  send_data
    MOVLW 03H
    MOVWF XUN
    goto up2  ; 检测按键抬起	



change
		comf PORTD
		return
;======================
; 发送12位信息子程序
;======================
send_data
		movlw 0x0c  ; 12
		movwf send_count
		movlw d'200'
		movwf count ; 发送2.4ms头信息
		bsf bit_data, 0
		bsf T2CON, 2  ; 使能tmr2
		bcf send_end, 0
lop4
		btfss send_end, 0  ; 判断是否发送完成
		goto lop4
		bcf bit_data, 0
		movlw d'50'
		movwf count ; 发送600us间隔信息
		bsf T2CON, 2  ; 使能tmr2
		bcf send_end, 0
lop5
		btfss send_end, 0  ; 判断是否发送完成
		goto lop5
send	
		btfss send_data_h, 7  ; 检测发送信息的最高位，是1则跳
		btfsc send_data_h , 7  ; 检测发送信息的最高位，是0则跳
		goto send_1
		goto send_0
next
		bcf bit_data, 0  ; 设置发送间隔
		movlw d'50'
		movwf count ; 发送600us间隔信息
		bsf T2CON, 2  ; 使能tmr2
		bcf send_end, 0
lop3
		btfss send_end, 0  ; 判断是否发送完成
		goto lop3
		rlf send_data_l, F ; 循环左移发送信息低4位,将最高位存放到C中
		rlf send_data_h, F ;循环左移发送信息高八位
		decfsz send_count, F ; 如果没有发送完毕
		goto send
		bcf T2CON, 2  ; 发送完毕 关闭tmr2
		return
send_1
		bsf bit_data, 0
		movlw d'100'
		movwf count ; 发送1.2ms逻辑1信息
		bsf T2CON, 2  ; 使能tmr2
		bcf send_end, 0
lop0
		btfss send_end, 0  ; 判断是否发送完成
		goto lop0
		goto next
send_0
		bsf bit_data, 0
		movlw d'50'
		movwf count ; 发送600us逻辑0信息
		bsf T2CON, 2  ; 使能tmr2
		bcf send_end, 0
lop1
		btfss send_end, 0  ; 判断是否发送完成
		goto lop1
		goto next
	

;====================================================================
      END
