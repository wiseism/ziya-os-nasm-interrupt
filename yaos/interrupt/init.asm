;======================================
; 中断模块
;======================================
; 导出函数：
;   void interrupt_init();
;   void enable_8259a();
;======================================

[SECTION .data]
IDT: times 255 dq 0
IDTR_INFO: times 6 db 0
interrupt_init_start_msg: db "start init IDT...", 10, 13, 0
interrupt_init_end_msg: db "complete init IDT...", 10, 13, 0
msg: db "interrupt_handler", 10, 13, 0

exception_msg: db "something goes wrong:", 10, 13, 0
exception_msg_1: db "==============================", 10, 13, 0
exception_msg_2: db " IRQ : 0x%02X", 10, 13, 0
exception_msg_3: db " ESP : 0x%08X", 10, 13, 0
exception_msg_4: db " EIP : 0x%08X", 10, 13, 0
exception_msg_5: db "  CS : 0x%02X", 10, 13, 0
exception_msg_6: db " EFLAGS : 0x%08X", 10, 13, 0

[SECTION .text]
[BITS 32]

extern printk
extern keymap_handler

; 初始化IDT
; 函数原型: void interrupt_init();
global interrupt_init
interrupt_init:
.start:
    push interrupt_init_start_msg
    call printk
    add esp, 4

; 填充IDT表
.fill_table:
    mov ecx, 255
    mov edi, IDT
    mov esi, interrupt_handler

.loop:

; 除零异常中断门描述符
.gate_0:
    cmp ecx, 255
    jne .gate_0x20

    ; 中断们描述符低4B
    mov eax, 0x0008_0000
    or eax, exception_interrupt_handler_0x00
    mov dword [edi], eax

    jmp .gate_continue

; 时钟中断
.gate_0x20:
    mov eax, 255 - 0x20
    cmp ecx, eax
    jne .gate_0x21

    ; 中断们描述符低4B
    mov eax, 0x0008_0000
    or eax, clock_interrupt_handler
    mov dword [edi], eax

    jmp .gate_continue

; 键盘中断
.gate_0x21:
    mov eax, 255 - 0x21
    cmp ecx, eax
    jne .gate_general

    ; 中断们描述符低4B
    mov eax, 0x0008_0000
    or eax, keymap_handler_entry
    mov dword [edi], eax

    jmp .gate_continue

; 通用中断们描述符
.gate_general:
    ; 中断们描述符低4B
    mov eax, 0x0008_0000
    or eax, esi
    mov dword [edi], eax

.gate_continue:
    ; 中断门描述符高4B
    mov eax, 0x0000_8e00
    mov dword [edi + 4], eax

    ; edi指向下一个中断门描述符
    add edi, 8

    dec ecx

    cmp ecx, 0
    jne .loop

; 生成写入idtr寄存器的数据并写入
.install:
    mov edi, IDTR_INFO

    ; limit
    xor ax, ax
    lea ax, [255 * 8 - 1]
    mov word [edi], ax

    ; addr base
    mov dword [edi + 2], IDT

    ; 写入idtr寄存器
xchg bx, bx

    lidt [IDTR_INFO]

.end:
    push interrupt_init_end_msg
    call printk
    add esp, 4

    ret

; 配置8259a中断控制芯片
; 函数原型: void enable_8259a();
global enable_8259a
enable_8259a:
    ; 向主发送ICW1
    mov al, 11h
    out 20h, al

    ; 向从发送ICW1
    out 0a0h, al

    ; 向主发送ICW2
    mov al, 20h
    out 21h, al

    ; 向从发送ICW2
    mov al, 28h
    out 0a1h, al

    ; 向主发送ICW3
    mov al, 04h
    out 21h, al

    ; 向从发送ICW3
    mov al, 02h
    out 0A1h , al

    ; 向主发送ICW4
    mov al, 003h
    out 021h, al

    ; 向从发送ICW4
    out 0A1h, al

; 控制主芯片所有中断响应
.control_8259a_main:
    mov al, 11111101b
    out 21h, al

; 控制从芯片所有中断响应
.control_8259a_slave:
    mov al, 11111111b
    out 0A1h, al

    ret

; 通用的中断处理例程
interrupt_handler:
xchg bx, bx
    push msg
    call printk
    add esp, 4

    iret

; 时钟中断
clock_interrupt_handler:
    push msg
    call printk
    add esp, 4

    iret

; 键盘中断
global keymap_handler_entry
keymap_handler_entry:
    push 0x21
    call keymap_handler
    add esp, 4

    iret

%macro INTERRUPT_HANDLER 1
global interrupt_handler_%1
interrupt_handler_%1:
    xchg bx, bx

    push msg
    call printk
    add esp, 4

    iret
%endmacro

%macro EXCEPTION_INTERRUPT_HANDLER 1
global exception_interrupt_handler_%1
exception_interrupt_handler_%1:
    push exception_msg_1
    call printk
    add esp, 4

    push exception_msg
    call printk
    add esp, 4

    ; 中断号
    push 0
    push exception_msg_2
    call printk
    add esp, 8

    ; esp
    push esp
    push exception_msg_3
    call printk
    add esp, 8

    ; eip
    mov eax, [esp]
    push eax
    push exception_msg_4
    call printk
    add esp, 8

    ; cs
    mov eax, [esp + 4]
    push eax
    push exception_msg_5
    call printk
    add esp, 8

    ; eflags
    mov eax, [esp + 8]
    push eax
    push exception_msg_6
    call printk
    add esp, 8

    push exception_msg_1
    call printk
    add esp, 4

.hlt
    hlt
    jmp .hlt

    iret
%endmacro

EXCEPTION_INTERRUPT_HANDLER 0x00; divide by zero
INTERRUPT_HANDLER 0x01; debug
INTERRUPT_HANDLER 0x02; non maskable interrupt
INTERRUPT_HANDLER 0x03; breakpoint
INTERRUPT_HANDLER 0x04; overflow
INTERRUPT_HANDLER 0x05; bound range exceeded
INTERRUPT_HANDLER 0x06; invalid opcode
INTERRUPT_HANDLER 0x07; device not avilable
INTERRUPT_HANDLER 0x08; double fault
INTERRUPT_HANDLER 0x09; coprocessor segment overrun
INTERRUPT_HANDLER 0x0a; invalid TSS
INTERRUPT_HANDLER 0x0b; segment not present
INTERRUPT_HANDLER 0x0c; stack segment fault
INTERRUPT_HANDLER 0x0d; general protection fault
INTERRUPT_HANDLER 0x0e; page fault
INTERRUPT_HANDLER 0x0f; reserved
INTERRUPT_HANDLER 0x10; x87 floating point exception
INTERRUPT_HANDLER 0x11; alignment check
INTERRUPT_HANDLER 0x12; machine check
INTERRUPT_HANDLER 0x13; SIMD Floating - Point Exception
INTERRUPT_HANDLER 0x14; Virtualization Exception
INTERRUPT_HANDLER 0x15; Control Protection Exception
INTERRUPT_HANDLER 0x16; reserved
INTERRUPT_HANDLER 0x17; reserved
INTERRUPT_HANDLER 0x18; reserved
INTERRUPT_HANDLER 0x19; reserved
INTERRUPT_HANDLER 0x1a; reserved
INTERRUPT_HANDLER 0x1b; reserved
INTERRUPT_HANDLER 0x1c; reserved
INTERRUPT_HANDLER 0x1d; reserved
INTERRUPT_HANDLER 0x1e; reserved
INTERRUPT_HANDLER 0x1f; reserved
INTERRUPT_HANDLER 0x20; clock 时钟中断
INTERRUPT_HANDLER 0x21; 键盘中断
INTERRUPT_HANDLER 0x22
INTERRUPT_HANDLER 0x23
INTERRUPT_HANDLER 0x24
INTERRUPT_HANDLER 0x25
INTERRUPT_HANDLER 0x26
INTERRUPT_HANDLER 0x27
INTERRUPT_HANDLER 0x28; rtc 实时时钟
INTERRUPT_HANDLER 0x29
INTERRUPT_HANDLER 0x2a
INTERRUPT_HANDLER 0x2b
INTERRUPT_HANDLER 0x2c
INTERRUPT_HANDLER 0x2d
INTERRUPT_HANDLER 0x2e
INTERRUPT_HANDLER 0x2f