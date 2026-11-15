# test_all.S - directed test for every RV32I instruction the core implements,
# plus forwarding, load-use, branch-flush and reset behaviour.
.include "test_macros.h"
.section .text
.globl _start
_start:
    # ---------------- reset: first instruction runs at PC = 0 ----------
    auipc a0, 0
    CHECK 2, a0, 0

    # ---------------- ADDI / ADD / SUB ---------------------------------
    addi a0, x0, 5
    addi a1, x0, 7
    add  a2, a0, a1
    CHECK 3, a2, 12
    sub  a2, a0, a1
    CHECK 4, a2, -2
    addi a2, a0, -2048
    CHECK 5, a2, -2043

    # ---------------- logic --------------------------------------------
    li   a0, 0x0F0F00FF
    li   a1, 0x00FF0F0F
    and  a2, a0, a1
    CHECK 6, a2, 0x000F000F
    or   a2, a0, a1
    CHECK 7, a2, 0x0FFF0FFF
    xor  a2, a0, a1
    CHECK 8, a2, 0x0FF00FF0
    andi a2, a0, 0x0F0
    CHECK 9, a2, 0x0F0
    ori  a2, a0, -256
    CHECK 10, a2, 0xFFFFFFFF
    xori a2, a0, -1
    CHECK 11, a2, 0xF0F0FF00

    # ---------------- shifts -------------------------------------------
    li   a0, 0x80000010
    li   a1, 4
    sll  a2, a0, a1
    CHECK 12, a2, 0x00000100
    srl  a2, a0, a1
    CHECK 13, a2, 0x08000001
    sra  a2, a0, a1
    CHECK 14, a2, 0xF8000001
    slli a2, a0, 31
    CHECK 15, a2, 0
    srli a2, a0, 31
    CHECK 16, a2, 1
    srai a2, a0, 31
    CHECK 17, a2, -1

    # ---------------- compares -----------------------------------------
    li   a0, -1
    li   a1, 1
    slt  a2, a0, a1
    CHECK 18, a2, 1
    sltu a2, a0, a1
    CHECK 19, a2, 0
    slti a2, a0, 0
    CHECK 20, a2, 1
    sltiu a2, a1, -1
    CHECK 21, a2, 1

    # ---------------- LUI / AUIPC --------------------------------------
    lui  a2, 0xABCDE
    CHECK 22, a2, 0xABCDE000
pc_ref:
    auipc a2, 1
    la   a3, pc_ref
    sub  a2, a2, a3
    CHECK 23, a2, 0x1000

    # ---------------- LW / SW ------------------------------------------
    li   s0, 0x100               # data pointer
    li   a0, 0xDEADBEEF
    sw   a0, 0(s0)
    lw   a2, 0(s0)
    CHECK 24, a2, 0xDEADBEEF
    sw   a0, 8(s0)
    lw   a2, 8(s0)
    CHECK 25, a2, 0xDEADBEEF

    # ---------------- LB / LBU / LH / LHU ------------------------------
    lb   a2, 0(s0)
    CHECK 26, a2, 0xFFFFFFEF
    lbu  a2, 1(s0)
    CHECK 27, a2, 0xBE
    lb   a2, 3(s0)
    CHECK 28, a2, 0xFFFFFFDE
    lh   a2, 0(s0)
    CHECK 29, a2, 0xFFFFBEEF
    lhu  a2, 2(s0)
    CHECK 30, a2, 0xDEAD

    # ---------------- SB / SH ------------------------------------------
    sw   x0, 4(s0)
    li   a0, 0x11223344
    sb   a0, 5(s0)
    lw   a2, 4(s0)
    CHECK 31, a2, 0x00004400
    sh   a0, 6(s0)
    lw   a2, 4(s0)
    CHECK 32, a2, 0x33444400
    sb   a0, 4(s0)
    lw   a2, 4(s0)
    CHECK 33, a2, 0x33444444

    # ---------------- memory boundary: first and last RAM word ---------
    li   a0, 0x5A5A5A5A
    sw   a0, 0(x0)
    li   a3, 0xFFC
    li   a1, 0xA5A5A5A5
    sw   a1, 0(a3)
    lw   a2, 0(x0)
    CHECK 34, a2, 0x5A5A5A5A
    lw   a2, 0(a3)
    CHECK 35, a2, 0xA5A5A5A5

    # ---------------- branches: taken and not taken --------------------
    li   a0, 3
    li   a1, 3
    li   a2, 0
    beq  a0, a1, 1f
    addi a2, a2, 1               # must be flushed
    addi a2, a2, 1               # must be flushed
1:  CHECK 36, a2, 0
    bne  a0, a1, 2f              # not taken
    addi a2, a2, 5
2:  CHECK 37, a2, 5
    li   a0, -5
    li   a1, 2
    li   a2, 0
    blt  a0, a1, 3f
    addi a2, a2, 1
3:  bge  a0, a1, 4f              # not taken
    addi a2, a2, 2
4:  bltu a0, a1, 5f              # not taken: 0xFFFFFFFB > 2 unsigned
    addi a2, a2, 4
5:  bgeu a0, a1, 6f              # taken
    addi a2, a2, 8
6:  CHECK 38, a2, 6

    # ---------------- backward branch loop: sum 1..10 ------------------
    li   a0, 0
    li   a1, 10
loop:
    add  a0, a0, a1
    addi a1, a1, -1
    bnez a1, loop
    CHECK 39, a0, 55

    # ---------------- JAL / JALR ---------------------------------------
    li   a2, 0
    jal  ra, func
ret_here:
    addi a2, a2, 1
    CHECK 40, a2, 101
    la   a3, ret_here
    CHECK 41, s1, 0              # s1 = ra - ret_here, computed in func
    la   a3, target2 + 1         # JALR must clear bit 0 of the target
    jalr t0, 0(a3)
    li   a2, 999                 # skipped
target2:
    CHECK 42, a2, 101
    j    hazards

func:
    addi a2, a2, 100
    la   a3, ret_here
    sub  s1, ra, a3
    ret

    # ---------------- data hazards: forwarding -------------------------
hazards:
    li   a0, 1
    add  a1, a0, a0              # EX/MEM -> EX (a0)
    add  a2, a1, a0              # EX/MEM (a1), MEM/WB (a0)
    add  a3, a2, a1              # EX/MEM (a2), MEM/WB (a1)
    add  a4, a3, a0              # a0 now comes from the register file
    CHECK 43, a4, 6
    addi a0, x0, 1               # newest value must win
    addi a0, a0, 1
    addi a0, a0, 1
    addi a0, a0, 1
    CHECK 44, a0, 4
    addi x0, x0, 99              # writes to x0 are ignored, never forwarded
    add  a0, x0, x0
    CHECK 45, a0, 0

    # ---------------- load-use hazard (stall + forward) ----------------
    li   a0, 40
    sw   a0, 16(s0)
    lw   a1, 16(s0)
    addi a2, a1, 2               # uses the load result immediately
    CHECK 46, a2, 42
    lw   a1, 16(s0)
    sw   a1, 20(s0)              # store data straight from a load
    lw   a2, 20(s0)
    CHECK 47, a2, 40
    lw   a3, 16(s0)
    lw   a2, -24(a3)             # load address from a load: 40-24 = 16 -> 0x10
    sw   a0, 0x10(x0)
    lw   a3, 16(s0)
    lw   a2, -24(a3)
    CHECK 48, a2, 40

    # ---------------- hazard into a branch -----------------------------
    lw   a1, 16(s0)
    beq  a1, a0, 7f              # branch operand from a load
    li   t6, 49
    j    fail
7:  addi a1, a1, 1
    bne  a1, a0, 8f              # branch operand forwarded from EX/MEM
    li   t6, 50
    j    fail
8:
    # ---------------- load in the shadow of a taken branch -------------
    li   a2, 7
    j    9f
    lw   a2, 16(s0)              # flushed, must not stall or write
    addi a2, a2, 1
9:  CHECK 51, a2, 7

    TEST_END
