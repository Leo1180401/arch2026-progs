# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2


# a0 = Input a / Return value
# a1 = Input b
# t0 = Number of common factors of two
# t1 = Temporary register
# 若是a = b = 0，直接return 0
gcd_u32_asm:
    # ---------------------------------------
    # Step 1: Handle zero inputs
    # ---------------------------------------
    beq      a0, zero, gcd_return_b
    beq      a1, zero, gcd_return_a


    # ---------------------------------------
    # Step 2: Initialize common factor count
    # ---------------------------------------
    li       t0, 0
    j        gcd_common_loop

gcd_return_a:
    ret

gcd_return_b:
    mv       a0, a1
    ret

# ---------------------------------------
# Step 3: Remove common factors of two
# ---------------------------------------

gcd_common_loop:
    # Check both a,  b is odd or even
    or      t1, a0, a1
    andi    t1, t1, 1
    bne     t1, zero, gcd_make_a_odd

    # Both operands are even
    srli    a0, a0, 1
    srli    a1, a1, 1

    # Record one common factor of two
    addi    t0, t0, 1

    j       gcd_common_loop

# ---------------------------------------
# Step 4: Make a odd
# ---------------------------------------

gcd_make_a_odd:
    andi    t1, a0, 1
    bne     t1, zero, gcd_process_b

    srli    a0, a0, 1
    j       gcd_make_a_odd


# ---------------------------------------
# Step 5: Process b
# ---------------------------------------

gcd_process_b:
    # check if b is odd
    andi    t1, a1, 1
    bne     t1, zero, gcd_compare

gcd_shift_b:
    # 重覆移除2
    srli    a1, a1, 1
    andi    t1, a1, 1
    beq     t1, zero, gcd_shift_b


# ---------------------------------------
# Step 6: Compare and swap
# ---------------------------------------
gcd_compare:
    # If a > b, go to special subtraction path
    bltu    a1, a0, gcd_a_greater

    # a <= b: b = b - a
    sub     a1, a1, a0
    j       gcd_reduce_b


gcd_a_greater:
    # a > b:
    # a_new = b_old
    # b_new = a_old - b_old
    sub     t2, a0, a1
    mv      a0, a1
    mv      a1, t2


gcd_reduce_b:
    beq     a1, zero, gcd_done

    # a, b must be odd, thus, a - b / b - a must be even
    srli    a1, a1, 1
    j       gcd_process_b


# ---------------------------------------
# Step 7: Restore common factors
# ---------------------------------------

gcd_done:
    sll      a0, a0, t0
    ret

    .size   gcd_u32_asm, .-gcd_u32_asm
