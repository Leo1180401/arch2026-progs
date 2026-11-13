# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    # Extract exponent
    srli    t0, a0, 23
    andi    t0, t0, 255

    # Check Infinity / NaN
    li      t1, 255
    beq     t0, t1, bf16_f32_done

    # Extract bit 16
    srli    t0, a0, 16
    andi    t0, t0, 1

    # Rounding bias = 0x7FFF + bit16
    li      t1, 0x7FFF
    add     t0, t0, t1

    # Apply rounding
    add     a0, a0, t0

bf16_f32_done:
    srli    a0, a0, 16
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2


bf16_mul_asm:
    # --------------------------------------------------
    # Step 1: Sign and exponent extraction
    # --------------------------------------------------

    xor     t0, a0, a1
    li      t6, 0x8000
    and     t0, t0, t6       # t0 = result sign

    srli    t1, a0, 7
    andi    t1, t1, 255      # t1 = exp_a

    srli    t2, a1, 7
    andi    t2, t2, 255      # t2 = exp_b

    # --------------------------------------------------
    # Step 2: Check special operand A
    # --------------------------------------------------

    li      t6, 255
    bne     t1, t6, bf16_mul_check_b

    andi    t6, a0, 127
    bnez    t6, bf16_mul_return_a

    li      t6, 0x7FFF
    and     t6, a1, t6
    beqz    t6, bf16_mul_nan

    j       bf16_mul_inf

bf16_mul_check_b:
    # --------------------------------------------------
    # Step 3: Check special operand B
    # --------------------------------------------------

    li      t6, 255
    bne     t2, t6, bf16_mul_check_zero

    andi    t6, a1, 127
    bnez    t6, bf16_mul_return_b

    li      t6, 0x7FFF
    and     t6, a0, t6
    beqz    t6, bf16_mul_nan

    j       bf16_mul_inf

bf16_mul_check_zero:
    # --------------------------------------------------
    # Step 4: Check zero operands
    # --------------------------------------------------

    li      t6, 0x7FFF
    and     t3, a0, t6
    beqz    t3, bf16_mul_return_sign

    and     t4, a1, t6
    beqz    t4, bf16_mul_return_sign

    # --------------------------------------------------
    # Step 5: Prepare significands
    # --------------------------------------------------

    andi    t3, a0, 127      # frac_a
    andi    t4, a1, 127      # frac_b

    # ea = exp_a ? exp_a : 1
    # t1 != 0, then jump to bf16_mul_a_normal
    bnez    t1, bf16_mul_a_normal
    li      t1, 1
    j       bf16_mul_a_ready

bf16_mul_a_normal:
    ori     t3, t3, 128

bf16_mul_a_ready:
    # eb = exp_b ? exp_b : 1
    bnez    t2, bf16_mul_b_normal
    li      t2, 1
    j       bf16_mul_b_ready

bf16_mul_b_normal:
    ori     t4, t4, 128

bf16_mul_b_ready:
    # --------------------------------------------------
    # Step 6: Normalize subnormal operands
    # --------------------------------------------------

    li      t6, 128

bf16_mul_norm_a:
    bgeu    t3, t6, bf16_mul_norm_b
    slli    t3, t3, 1
    addi    t1, t1, -1
    j       bf16_mul_norm_a

bf16_mul_norm_b:
    bgeu    t4, t6, bf16_mul_begin_product
    slli    t4, t4, 1
    addi    t2, t2, -1
    j       bf16_mul_norm_b

    # --------------------------------------------------
    # Step 7: Shift-and-add multiplication
    # --------------------------------------------------

bf16_mul_begin_product:
    li      t5, 0            # product = 0

bf16_mul_loop:
    beqz    t4, bf16_mul_product_done

    andi    t6, t4, 1
    beqz    t6, bf16_mul_skip_add

    add     t5, t5, t3

bf16_mul_skip_add:
    slli    t3, t3, 1
    srli    t4, t4, 1

    j       bf16_mul_loop

bf16_mul_product_done:
    # --------------------------------------------------
    # Step 8: Calculate exponent
    # --------------------------------------------------

    add     t1, t1, t2
    addi    t1, t1, -127

    # --------------------------------------------------
    # Step 9: Normalize product
    # --------------------------------------------------

    li      t6, 0x8000
    and     t6, t5, t6

    beqz    t6, bf16_mul_shift7

    srli    t5, t5, 8
    addi    t1, t1, 1
    j       bf16_mul_exponent_check

bf16_mul_shift7:
    srli    t5, t5, 7

bf16_mul_exponent_check:
    # --------------------------------------------------
    # Step 10: Overflow
    # --------------------------------------------------

    li      t6, 255
    bge     t1, t6, bf16_mul_inf

    # --------------------------------------------------
    # Step 11: Underflow
    # --------------------------------------------------

    bge     x0, t1, bf16_mul_underflow

    # Normal BF16 result
    andi    t5, t5, 127
    slli    t1, t1, 7
    or      a0, t0, t1
    or      a0, a0, t5
    ret

bf16_mul_underflow:
    li      t6, -6
    blt     t1, t6, bf16_mul_return_sign

    li      t6, 1
    sub     t6, t6, t1       # shift = 1 - exponent

    andi    t5, t5, 127      # remove hidden bit
    srl     t5, t5, t6

    or      a0, t0, t5
    ret

    # --------------------------------------------------
    # Special return values
    # --------------------------------------------------

bf16_mul_return_a:
    ret

bf16_mul_return_b:
    mv      a0, a1
    ret

bf16_mul_return_sign:
    mv      a0, t0
    ret

bf16_mul_nan:
    li      a0, 0x7FC0
    ret

bf16_mul_inf:
    li      t6, 0x7F80
    or      a0, t0, t6
    ret


    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2

# a0: a, 原始BF16輸入，最後回傳結果
# a1: mid, Binary search 中間值
# a2: square = mid * mid
# a3: shift and add 被乘數
# a4: shift and add 乘數
# a5: 暫存值
# t0: sign bit
# t1: 原始exponent
# t2: m, 整數significant
# t3: e, 無偏移指數，之後存結果指數
# t4: lo, Binary下界
# t5: hi, Binary上界
# t6: best, 目前找到的最佳平方根
bf16_sqrt_asm:
    # --------------------------------------------------
    # Step 1: Extract sign, exponent, fraction
    # --------------------------------------------------

    li      t0, 0x8000
    and     t0, a0, t0       # sign

    srli    t1, a0, 7
    andi    t1, t1, 255      # exponent

    andi    t2, a0, 127      # fraction

    # --------------------------------------------------
    # Step 2: Handle NaN and Infinity
    # --------------------------------------------------

    li      a5, 255
    bne     t1, a5, bf16_sqrt_check_zero

    # Exponent == 255

    bnez    t2, bf16_sqrt_return_input

    # -Infinity -> quiet NaN
    bnez    t0, bf16_sqrt_return_nan

    # +Infinity -> unchanged
    j       bf16_sqrt_return_input

    # --------------------------------------------------
    # Step 3: Handle zero
    # --------------------------------------------------

bf16_sqrt_check_zero:
    li      a5, 0x7FFF
    and     a5, a0, a5

    beqz    a5, bf16_sqrt_return_zero

    # --------------------------------------------------
    # Step 4: Handle negative numbers
    # --------------------------------------------------

    bnez    t0, bf16_sqrt_return_nan

    # --------------------------------------------------
    # Step 5: Handle subnormal
    # --------------------------------------------------

    beqz    t1, bf16_sqrt_return_zero

    # --------------------------------------------------
    # Step 6: Prepare significand and exponent
    # --------------------------------------------------

    ori     t2, t2, 128      # m = 128 | fraction
    addi    t3, t1, -127    # e = exponent - 127

    # --------------------------------------------------
    # Step 7: Make exponent even
    # --------------------------------------------------

    andi    a5, t3, 1
    beqz    a5, bf16_sqrt_search_init

    slli    t2, t2, 1       # m *= 2
    addi    t3, t3, -1      # e--

    # --------------------------------------------------
    # Step 8: Initialize binary search
    # --------------------------------------------------

bf16_sqrt_search_init:
    li      t4, 90          # lo = 90
    li      t5, 256         # hi = 256
    li      t6, 90          # best = 90

    # --------------------------------------------------
    # Step 9: Binary search loop
    # --------------------------------------------------

bf16_sqrt_search_loop:
    # while (lo <= hi)

    bltu    t5, t4, bf16_sqrt_search_done

    # mid = (lo + hi) >> 1

    add     a1, t4, t5
    srli    a1, a1, 1

    # --------------------------------------------------
    # Step 10: Calculate square = mid * mid
    #          using shift-and-add
    # --------------------------------------------------

    li      a2, 0           # square = 0

    mv      a3, a1          # x = mid
    mv      a4, a1          # y = mid

bf16_sqrt_mul_loop:
    beqz    a4, bf16_sqrt_mul_done

    andi    a5, a4, 1
    beqz    a5, bf16_sqrt_skip_add

    add     a2, a2, a3      # square += x

bf16_sqrt_skip_add:
    slli    a3, a3, 1       # x <<= 1
    srli    a4, a4, 1       # y >>= 1

    j       bf16_sqrt_mul_loop

bf16_sqrt_mul_done:
    # --------------------------------------------------
    # Step 11: Compare square / 128 with m
    # --------------------------------------------------

    srli    a2, a2, 7

    # C: if ((square >> 7) <= m)
    bgeu    t2, a2, bf16_sqrt_mid_valid

    # mid is too large
    addi    t5, a1, -1      # hi = mid - 1

    j       bf16_sqrt_search_loop

bf16_sqrt_mid_valid:
    # mid is valid

    mv      t6, a1          # best = mid
    addi    t4, a1, 1       # lo = mid + 1

    j       bf16_sqrt_search_loop

    # --------------------------------------------------
    # Step 12: Calculate result exponent
    # --------------------------------------------------

bf16_sqrt_search_done:
    srai    t3, t3, 1       # e / 2
    addi    t3, t3, 127     # result_exp

    # --------------------------------------------------
    # Step 13: Normalize result significand
    # --------------------------------------------------

bf16_sqrt_norm_high:
    li      a5, 256
    bltu    t6, a5, bf16_sqrt_norm_low

    srli    t6, t6, 1       # best >>= 1
    addi    t3, t3, 1       # result_exp++

    j       bf16_sqrt_norm_high

bf16_sqrt_norm_low:
    li      a5, 128
    bgeu    t6, a5, bf16_sqrt_check_exp

    slli    t6, t6, 1       # best <<= 1
    addi    t3, t3, -1      # result_exp--

    j       bf16_sqrt_norm_low

    # --------------------------------------------------
    # Step 14: Check overflow / underflow
    # --------------------------------------------------

bf16_sqrt_check_exp:
    li      a5, 255
    bge     t3, a5, bf16_sqrt_return_inf

    bge     zero, t3, bf16_sqrt_return_zero

    # --------------------------------------------------
    # Step 15: Assemble BF16 result
    # --------------------------------------------------

    slli    t3, t3, 7       # exponent << 7
    andi    t6, t6, 127     # fraction

    or      a0, t3, t6

    ret

    # --------------------------------------------------
    # Special return values
    # --------------------------------------------------

bf16_sqrt_return_input:
    ret

bf16_sqrt_return_nan:
    li      a0, 0x7FC0
    ret

bf16_sqrt_return_zero:
    li      a0, 0
    ret

bf16_sqrt_return_inf:
    li      a0, 0x7F80
    ret

    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
