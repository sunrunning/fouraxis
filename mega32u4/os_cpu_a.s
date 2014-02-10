/*
******************************************************************************************************
*                                       Project Fouraxis
*                   
*                    (c) Copyright 2014-2018; Micrium, Inc.; Li Jun, Freescale
*
*               All rights reserved.  Protected by international copyright laws.
*               Knowledge of the source code may NOT be used to develop a similar product.
*               Please help us continue to provide the Embedded community with the finest
*               software available.  Your honesty is greatly appreciated.
*                               Email: lijun4running@gmail.com
******************************************************************************************************
*/

#include  "os_cpu_i.h"
#include  "../src/ucos_ii.h"
;.area     text(rel)

;/*$PAGE*/.
;********************************************************************************************************
;                            DISABLE/ENABLE INTERRUPTS USING OS_CRITICAL_METHOD #3
;
; Description : These functions are used to disable and enable interrupts using OS_CRITICAL_METHOD #3.
;
;               OS_CPU_SR  OSCPUSaveSR (void)
;                     Get current value of SREG
;                     Disable interrupts
;                     Return original value of SREG
;
;               void  OSCPURestoreSR (OS_CPU_SR cpu_sr)
;                     Set SREG to cpu_sr
;                     Return
;********************************************************************************************************

OS_CPU_SR_Save:
                IN      R16,SREG                    ; Get current state of interrupts disable flag
                CLI                                 ; Disable interrupts
                RET                                 ; Return original SREG value in R16


OS_CPU_SR_Restore:
                OUT     SREG,R16                    ; Restore SREG
                RET                                 ; Return

;/*$PAGE*/.
;********************************************************************************************************
;                               START HIGHEST PRIORITY TASK READY-TO-RUN
;
; Description : This function is called by OSStart() to start the highest priority task that was created
;               by your application before calling OSStart().
;
; Note(s)     : 1) The (data)stack frame is assumed to look as follows:
;
;                  OSTCBHighRdy->OSTCBStkPtr --> SPL of (return) stack pointer           (Low memory)
;                                                SPH of (return) stack pointer
;                                                Flags to load in status register
;                                                RAMPZ
;                                                R31
;                                                R30
;                                                R27
;                                                .
;                                                .
;                                                R0
;                                                PCH
;                                                PCL                                     (High memory)
;
;                  where the stack pointer points to the task start address.
;
;
;               2) OSStartHighRdy() MUST:
;                      a) Call OSTaskSwHook() then,
;                      b) Set OSRunning to TRUE,
;                      c) Switch to the highest priority task.
;********************************************************************************************************

OSStartHighRdy:
                CALL    OSTaskSwHook               ; Invoke user defined context switch hook
                LDS     R16,OSRunning              ; Indicate that we are multitasking
                INC     R16                         ;
                STS     OSRunning,R16              ;

                LDS     R30,OSTCBHighRdy           ; Let Z point to TCB of highest priority task
                LDS     R31,OSTCBHighRdy+1         ; ready to run
                LD      R28,Z+                      ; Load Y (R29:R28) pointer
                LD      R29,Z+                      ;

                POP_SP                              ; Restore stack pointer
                POP_SREG_INT                        ; Restore status register (Disable Interrupts)
                POP_ALL                             ; Restore all registers
                RETI                                ; Start task

;/*$PAGE*/.
;********************************************************************************************************
;                                       TASK LEVEL CONTEXT SWITCH
;
; Description : This function is called when a task makes a higher priority task ready-to-run.
;
; Note(s)     : 1) Upon entry,
;                  OSTCBCur     points to the OS_TCB of the task to suspend
;                  OSTCBHighRdy points to the OS_TCB of the task to resume
;
;               2) The stack frame of the task to suspend looks as follows:
;
;                                       SP+0 --> LSB of task code address
;                                         +1     MSB of task code address                (High memory)
;
;               3) The saved context of the task to resume looks as follows:
;
;                  OSTCBHighRdy->OSTCBStkPtr --> SPL of (return) stack pointer           (Low memory)
;                                                SPH of (return) stack pointer
;                                                Flags to load in status register
;                                                RAMPZ
;                                                R31
;                                                R30
;                                                R27
;                                                .
;                                                .
;                                                R0
;                                                PCH
;                                                PCL                                     (High memory)
;********************************************************************************************************

OSCtxSw:
                PUSH_ALL                            ; Save current task's context
                PUSH_SREG
                PUSH_SP

                LDS     R30,OSTCBCur               ; Z = OSTCBCur->OSTCBStkPtr
                LDS     R31,OSTCBCur+1             ;
                ST      Z+,R28                      ; Save Y (R29:R28) pointer
                ST      Z+,R29                      ;

                CALL    OSTaskSwHook               ; Call user defined task switch hook

                LDS     R16,OSPrioHighRdy          ; OSPrioCur = OSPrioHighRdy
                STS     OSPrioCur,R16

                LDS     R30,OSTCBHighRdy           ; Let Z point to TCB of highest priority task
                LDS     R31,OSTCBHighRdy+1         ; ready to run
                STS     OSTCBCur,R30               ; OSTCBCur = OSTCBHighRdy
                STS     OSTCBCur+1,R31             ;

                LD      R28,Z+                      ; Restore Y pointer
                LD      R29,Z+                      ;

                POP_SP                              ; Restore stack pointer
                LD      R16,Y+                      ; Restore status register
                SBRC    R16,7                       ; Skip next instruction if interrupts DISABLED
                RJMP    OSCtxSw_1
                
                OUT     SREG,R16                    ; Interrupts of task to return to are DISABLED
                POP_ALL
                RET
                
OSCtxSw_1:     
		CBR     R16,BIT07                   ; Interrupts of task to return to are ENABLED
                OUT     SREG,R16
                POP_ALL                             ; Restore all registers
                RETI

;/*$PAGE*/.
;*********************************************************************************************************
;                                INTERRUPT LEVEL CONTEXT SWITCH
;
; Description : This function is called by OSIntExit() to perform a context switch to a task that has
;               been made ready-to-run by an ISR.
;
; Note(s)     : 1) Upon entry,
;                  OSTCBCur     points to the OS_TCB of the task to suspend
;                  OSTCBHighRdy points to the OS_TCB of the task to resume
;
;               2) The stack frame of the task to suspend looks as follows:
;
;                  OSTCBCur->OSTCBStkPtr ------> SPL of (return) stack pointer           (Low memory)
;                                                SPH of (return) stack pointer
;                                                Flags to load in status register
;                                                RAMPZ
;                                                R31
;                                                R30
;                                                R27
;                                                .
;                                                .
;                                                R0
;                                                PCH
;                                                PCL                                     (High memory)
;
;               3) The saved context of the task to resume looks as follows:
;
;                  OSTCBHighRdy->OSTCBStkPtr --> SPL of (return) stack pointer           (Low memory)
;                                                SPH of (return) stack pointer
;                                                Flags to load in status register
;                                                RAMPZ
;                                                R31
;                                                R30
;                                                R27
;                                                .
;                                                .
;                                                R0
;                                                PCH
;                                                PCL                                     (High memory)
;*********************************************************************************************************

OSIntCtxSw:
                CALL    OSTaskSwHook               ; Call user defined task switch hook

                LDS     R16,OSPrioHighRdy          ; OSPrioCur = OSPrioHighRdy
                STS     OSPrioCur,R16              ;

                LDS     R30,OSTCBHighRdy           ; Z = OSTCBHighRdy->OSTCBStkPtr
                LDS     R31,OSTCBHighRdy+1         ;
                STS     OSTCBCur,R30               ; OSTCBCur = OSTCBHighRdy
                STS     OSTCBCur+1,R31             ;

                LD      R28,Z+                      ; Restore Y pointer
                LD      R29,Z+                      ;

                POP_SP                              ; Restore stack pointer
                LD      R16,Y+                      ; Restore status register
                SBRC    R16,7                       ; Skip next instruction if interrupts DISABLED
                RJMP    OSIntCtxSw_1
                
                OUT     SREG,R16                    ; Interrupts of task to return to are DISABLED
                POP_ALL
                RET
                
OSIntCtxSw_1:  
		CBR     R16,BIT07                   ; Interrupts of task to return to are ENABLED
                OUT     SREG,R16
                POP_ALL                             ; Restore all registers
                RETI


;/*Add by Li Jun*/
;//Email: lijun4running@gmail.com
;**********************************************************************************************************
OSTickISR::    
                PUSH_ALL
                LDI     R19,0xF1                     ;0xB2
                OUT     TCNT,R19

                LDS     R16,OSIntNesting            ; OSIntNesting++
                INC     R16
                STS     OSIntNesting,R16

                CPI     
