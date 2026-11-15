# test_macros.h - helpers for self-checking assembly tests
# CHECK compares a register with an expected constant. On mismatch the test
# number is written to tohost (0xFFFFFFFC) and the testbench reports FAIL.
# x30 (t5) and x31 (t6) are reserved for the macros.

.macro CHECK num, reg, expected
    li   t5, \expected
    li   t6, \num
    bne  \reg, t5, fail
.endm

.macro TEST_END
    li   t6, 1
    sw   t6, -4(x0)          # tohost = 1  -> PASS
1:  j    1b
fail:
    sw   t6, -4(x0)          # tohost = failing check number
2:  j    2b
.endm
