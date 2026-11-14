# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2

# a0 = a, 回傳結果
# a1 = b
# a2 = &n
# t0 = 紀錄迴圈次數
# t1 = 暫存carry
op1_asm:
    li      t0, 0              # count = 0

    beqz    a1, op1_done       # if (b == 0), finish

op1_loop:
    and     t1, a0, a1         # t1 = a & b
    slli    t1, t1, 1          # carry = (a & b) << 1

    xor     a0, a0, a1         # a = a ^ b
    mv      a1, t1             # b = carry

    addi    t0, t0, 1          # count++

    bnez    a1, op1_loop       # while(b != 0)

op1_done:
    sw      t0, 0(a2)          # *n = count
    ret
    .size   op1_asm, .-op1_asm


    .globl  op2_asm
    .type   op2_asm, @function
    .align  2


op2_asm:
    sub     a0, a0, a1         # a - b
    ret
    .size   op2_asm, .-op2_asm


    .globl  op3_asm
    .type   op3_asm, @function
    .align  2


op3_asm:
    and     t0, a0, a1         # t0 = a & b
    xor     t1, a0, a1         # t1 = a ^ b

    srli    t1, t1, 1          # (a ^ b) >> 1
    add     a0, t0, t1         # result = (a & b) + ((a ^ b) >> 1)

    ret
    .size   op3_asm, .-op3_asm



    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
# a0 = original signed a
# a1 = original signed b
# a2 = carry
#
# t0 = product low 32 bits
# t1 = product high 32 bits
#
# t2 = multiplicand low 32 bits
# t3 = multiplicand high 32 bits
#
# t4 = multiplier
# t5 = loop counter
# t6 = temporary register

q_mul_asm:
    # --------------------------------------------------
    # Step 1: Initialize 64-bit product
    # --------------------------------------------------

    li      t0, 0              # product_low = 0
    li      t1, 0              # product_high = 0

    mv      t2, a0             # multiplicand_low = a
    li      t3, 0              # multiplicand_high = 0

    mv      t4, a1             # multiplier = b

    # If multiplier is zero, skip multiplication
    beqz    t4, qmul_sign_a


    # --------------------------------------------------
    # Step 2: Unsigned 32x32 -> 64-bit multiplication
    # --------------------------------------------------

qmul_loop:
    # Check multiplier's least significant bit
    andi    t6, t4, 1

    # If bit is zero, skip addition
    beqz    t6, qmul_skip_add


    # --------------------------------------------------
    # Step 3: 64-bit product += multiplicand
    # --------------------------------------------------

    # Add low 32 bits
    add     t6, t0, t2

    # Detect carry from low-word addition
    sltu    a2, t6, t0

    # Store new low word
    mv      t0, t6

    # Add high 32 bits and carry
    add     t1, t1, t3
    add     t1, t1, a2


qmul_skip_add:
    # --------------------------------------------------
    # Step 4: Shift multiplier right by one
    # --------------------------------------------------

    srli    t4, t4, 1


    # --------------------------------------------------
    # Step 5: Shift 64-bit multiplicand left by one
    # --------------------------------------------------

    # Capture bit 31 of multiplicand_low
    srli    t6, t2, 31

    # Shift low word left
    slli    t2, t2, 1

    # Shift high word left and insert carry bit
    slli    t3, t3, 1
    or      t3, t3, t6


    # --------------------------------------------------
    # Step 6: Repeat for 32 multiplier bits
    # --------------------------------------------------

    bnez    t4, qmul_loop


    # --------------------------------------------------
    # Step 7: Convert unsigned product to signed
    # --------------------------------------------------

qmul_sign_a:
    bgez    a0, qmul_check_b
    sub     t1, t1, a1

qmul_check_b:
    # If original b is negative:
    # product_high -= unsigned a

    bgez    a1, qmul_round
    sub     t1, t1, a0


    # --------------------------------------------------
    # Step 8: Add rounding bias (2^19)
    # --------------------------------------------------

qmul_round:
    li      t6, 0x80000

    # Add bias to low word
    add     t6, t0, t6

    # Detect carry
    sltu    a2, t6, t0

    # Update product
    mv      t0, t6
    add     t1, t1, a2


    # --------------------------------------------------
    # Step 9: Arithmetic right shift 64-bit by 20
    #
    # Only low 32 bits of the result are required.
    #
    # result = (low >> 20) | (high << 12)
    # --------------------------------------------------

    srli    t0, t0, 20
    slli    t1, t1, 12
    or      a0, t0, t1

    ret
    .size   q_mul_asm, .-q_mul_asm
