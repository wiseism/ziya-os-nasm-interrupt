;======================================
; 内核模块,由setup模块,即loader模块,载入内核
;   硬盘中的位置: 0柱面0磁道3扇区开始,占60个扇区(见Makefile)
;   内存中的位置: 0x1200处
;======================================

[SECTION .data]
msg: db "protected mode", 10, 13, 0

[SECTION .text]
[BITS 32]

extern console_init
extern printk
extern interrupt_init
extern enable_8259a

global _start
_start:
    cli

    ; 加载屏幕驱动
    call console_init

    ; 接管中断
    call interrupt_init

    ; 激活8259a中断控制芯片
    call enable_8259a

    sti

    jmp $