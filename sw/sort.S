# sort.S - bubble sort of 8 words in RAM, then checks the result.
# A longer program that mixes loads, stores, branches and loops.
.include "test_macros.h"
.section .text
.globl _start
_start:
    li   s0, 0x200               # array base
    li   t0, 37
    sw   t0, 0(s0)
    li   t0, -4
    sw   t0, 4(s0)
    li   t0, 12
    sw   t0, 8(s0)
    li   t0, 90
    sw   t0, 12(s0)
    li   t0, 0
    sw   t0, 16(s0)
    li   t0, 5
    sw   t0, 20(s0)
    li   t0, -77
    sw   t0, 24(s0)
    li   t0, 12
    sw   t0, 28(s0)

    li   s1, 8                   # n
outer:
    addi s1, s1, -1
    beqz s1, done
    mv   t0, s0                  # p = base
    mv   t1, s1                  # inner count
inner:
    lw   a0, 0(t0)
    lw   a1, 4(t0)
    bge  a1, a0, noswap          # signed compare
    sw   a1, 0(t0)
    sw   a0, 4(t0)
noswap:
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, inner
    j    outer

done:
    lw   a0, 0(s0)
    CHECK 2, a0, -77
    lw   a0, 4(s0)
    CHECK 3, a0, -4
    lw   a0, 8(s0)
    CHECK 4, a0, 0
    lw   a0, 12(s0)
    CHECK 5, a0, 5
    lw   a0, 16(s0)
    CHECK 6, a0, 12
    lw   a0, 20(s0)
    CHECK 7, a0, 12
    lw   a0, 24(s0)
    CHECK 8, a0, 37
    lw   a0, 28(s0)
    CHECK 9, a0, 90
    TEST_END
