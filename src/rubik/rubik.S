# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions, no heap, no recursion. Tests: tests/trubik.c.

#資料唯獨區
    .section .rodata
    .align  4

solved_state:
    .asciz "12345671111111"

    .balign 4

move_names:
    .ascii "R\0\0"
    .ascii "R2\0"
    .ascii "R'\0"
    .ascii "B\0\0"
    .ascii "B2\0"
    .ascii "B'\0"
    .ascii "D\0\0"
    .ascii "D2\0"
    .ascii "D'\0"

# 切換回程式碼區
    .text
    .global rubik_solve_asm
    .type rubik_solve_asm, @function
    .balign 4

rubik_solve_asm:

    # a0 = state
    # a1 = out
    # a2 = cap

    # ---------------------------------------
    # Stack Frame
    # ---------------------------------------

    addi    sp, sp, -48
    sw      ra, 44(sp)
    sw      a0, 40(sp)
    sw      a1, 36(sp)
    sw      a2, 32(sp)

    # Stack Layout:
    # sp+0  ~ sp+6  : permutation[7]
    # sp+7  ~ sp+13 : orientation[7]
    # sp+28         : saved return address

    beq     a0, zero, invalid_state

    # ---------------------------------------
    # Input length validation
    # ---------------------------------------

    # t0 = input pointer
    mv      t0, a0

    # t1 = number of characters checked
    li      t1, 0

check_length_loop:

    # Read current character
    lbu     t2, 0(t0)

    # A NUL before position 14 is invalid
    beq     t2, zero, invalid_state

    # Move to next character
    addi    t0, t0, 1
    addi    t1, t1, 1

    # Continue until 14 characters have been checked
    li      t3, 14
    blt     t1, t3, check_length_loop

    # The 15th byte must be NUL
    lbu     t2, 0(t0)
    bne     t2, zero, invalid_state

    # ---------------------------------------
    # Permutation Validation
    # ---------------------------------------

    # t0 = address of input state
    mv      t0, a0

    # t1 = number of cubies checked
    li      t1, 0

    # t3 = bitmask of seen cubies
    li      t3, 0

    # t6 = ASCII '1'
    li      t6, 49

check_perm_loop:

    # Read the current permutation digit
    lbu     t2, 0(t0)

    # Convert ASCII '1'..'7' to integer 0..6
    sub     t4, t2, t6

    # Reject values outside 0..6
    li      t5, 6
    bltu    t5, t4, invalid_state

    # Generate the bit corresponding to this cubie
    li      t5, 1
    sll     t5, t5, t4

    # Check whether this cubie appeared before
    and     t2, t3, t5
    bne     t2, zero, invalid_state

    # Mark this cubie as seen
    or      t3, t3, t5

    # ---------------------------------------
    # Save decoded permutation digit
    # ---------------------------------------

    add     t2, sp, t1
    sb      t4, 0(t2)

    # Advance to the next permutation digit
    addi    t0, t0, 1
    addi    t1, t1, 1

    # Repeat until all seven cubies are checked
    li      t5, 7
    blt     t1, t5, check_perm_loop

    # ---------------------------------------
    # Orientation Validation
    # ---------------------------------------

    # t0 currently points to state[7],
    # the first orientation character.

    # t1 = number of orientations checked
    li t1, 0

    # t3 = orientation sum modulo 3
    li      t3, 0

    # t6 = ASCII '1'
    li      t6, 49

check_orient_loop:

    # Read the current orientation digit
    lbu     t2, 0(t0)

    # Convert ASCII '1'..'3' to 0..2
    sub     t4, t2, t6

    # Reject values outside 0..2
    li      t5, 2
    bltu    t5, t4, invalid_state

    # ---------------------------------------
    # Save decoded orientation digit
    # ---------------------------------------

    addi    t2, t1, 7
    add     t2, sp, t2
    sb      t4, 0(t2)

    # Add the current orientation
    add     t3, t3, t4

    # Keep sum in the range 0..2
    li      t5, 3
    bltu    t3, t5, orient_no_reduce

    # If sum >= 3, subtract 3
    addi    t3, t3, -3

orient_no_reduce:

    # Advance to the next orientation
    addi    t0, t0, 1
    addi    t1, t1, 1

    # Repeat until seven orientations are checked
    li      t5, 7
    blt     t1, t5, check_orient_loop

    # Final sum must be divisible by 3
    bne     t3, zero, invalid_state

    # ---------------------------------------
    # State Ranking
    # ---------------------------------------

    # a0 = &permutation[0]
    mv      a0, sp

    jal     ra, rank_perm_asm

    # Save permutation rank
    sw      a0, 16(sp)

    # a0 = &orientation[0]
    addi    a0, sp, 7

    jal     ra, rank_orient_asm

    # Save orientation rank
    sw      a0, 20(sp)

    # ---------------------------------------
    # State ID Calculation
    # ---------------------------------------

    # t0 = permutation rank
    lw      t0, 16(sp)

    # t1 = orientation rank
    lw      t1, 20(sp)

    # Multiply permutation rank by 9
    slli    t2, t0, 3
    add     t2, t2, t0

    # Multiply by 9 again: p * 81
    slli    t3, t2, 3
    add     t2, t3, t2

    # Multiply by 9 again: p * 729
    slli    t3, t2, 3
    add     t2, t3, t2

    # State ID = p * 729 + o
    add     t0, t2, t1

    # Save State ID
    sw      t0, 24(sp)

    # ---------------------------------------
    # Distance-5 Lookup
    # ---------------------------------------

    # a0 = State ID
    mv      a0, t0

    # Search Distance-5 Lookup Table
    jal     ra, rubik_depth5_lookup_asm

    # Save Metadata
    # -1 means State ID was not found
    sw      a0, 28(sp)

    # ---------------------------------------
    # Distance-5 Solver
    # ---------------------------------------

    # Load the initial metadata.
    lw      t0, 28(sp)

    # Not found in Distance-5 Table.
    # use Hybrid IDA* search
    blt     t0, zero, search_deep_state

    # Extract initial distance.
    srli    t1, t0, 4

    # Distance zero: already solved.
    beq     t1, zero, solved_found

    # Preserve the optimal solution length.
    sw      t1, 24(sp)

    # Output position = 0.
    # Original input pointer is no longer needed.
    sw      zero, 40(sp)


distance5_loop:

    # Load current metadata.
    lw      t0, 28(sp)

    # Extract current distance.
    srli    t1, t0, 4

    # Stop when the cube is solved.
    beq     t1, zero, distance5_done

    # Extract Next Move (0..8).
    andi    t2, t0, 15

    # ---------------------------------------
    # Find the Move Name
    # ---------------------------------------

    # Offset = move * 3.
    slli    t3, t2, 1
    add     t3, t3, t2

    # t4 = address of move name.
    la      t4, move_names
    add     t4, t4, t3

    # t3 = current output position.
    lw      t3, 40(sp)

    # ---------------------------------------
    # Write First Character
    # ---------------------------------------

    add     t5, sp, t3

    lbu     t6, 0(t4)
    sb      t6, 0(t5)

    addi    t3, t3, 1

    # ---------------------------------------
    # Write Optional Second Character
    # ---------------------------------------

    lbu     t6, 1(t4)

    beq     t6, zero, distance5_no_suffix

    add     t5, sp, t3
    sb      t6, 0(t5)

    addi    t3, t3, 1


distance5_no_suffix:

    # Append a space after the move.
    # The final space will become NUL.
    add     t5, sp, t3

    li      t6, 32
    sb      t6, 0(t5)

    addi    t3, t3, 1

    # Save updated output position.
    sw      t3, 40(sp)

    # ---------------------------------------
    # Apply Move
    # ---------------------------------------

    # a0 = current permutation rank
    lw      a0, 16(sp)

    # a1 = current orientation rank
    lw      a1, 20(sp)

    # a2 = move ID
    mv      a2, t2

    jal     ra, rubik_apply_move_asm

    # Save updated ranks.
    sw      a0, 16(sp)
    sw      a1, 20(sp)

    # ---------------------------------------
    # Calculate New State ID
    # ---------------------------------------

    # p * 9
    slli    t0, a0, 3
    add     t0, t0, a0

    # p * 81
    slli    t1, t0, 3
    add     t0, t1, t0

    # p * 729
    slli    t1, t0, 3
    add     t0, t1, t0

    # State ID = p * 729 + o
    add     a0, t0, a1

    # ---------------------------------------
    # Lookup Updated State
    # ---------------------------------------

    jal     ra, rubik_depth5_lookup_asm

    # Every next state must exist in the table.
    blt     a0, zero, invalid_state

    # Save updated metadata.
    sw      a0, 28(sp)

    j       distance5_loop


distance5_done:

    # ---------------------------------------
    # Check Output Buffer Capacity
    # ---------------------------------------

    # t0 = total bytes written, including
    # the trailing space.
    lw      t0, 40(sp)

    # t1 = capacity
    lw      t1, 32(sp)

    # Required bytes equal t0:
    # trailing space will be replaced by NUL.
    bltu    t1, t0, buffer_too_small

    # ---------------------------------------
    # Replace Final Space with NUL
    # ---------------------------------------

    addi    t2, t0, -1
    add     t3, sp, t2

    sb      zero, 0(t3)

    # ---------------------------------------
    # Copy Solution to Output Buffer
    # ---------------------------------------

    # t4 = destination pointer
    lw      t4, 36(sp)

    # t5 = copy index
    li      t5, 0


distance5_copy_loop:

    bgeu    t5, t0, distance5_return

    # Read temporary solution byte.
    add     t2, sp, t5
    lbu     t3, 0(t2)

    # Write to output buffer.
    add     t2, t4, t5
    sb      t3, 0(t2)

    addi    t5, t5, 1

    j       distance5_copy_loop


distance5_return:

    # Return original optimal distance.
    lw      a0, 24(sp)

    j       function_epilogue


solved_found:

    # Restore output pointer and capacity.
    lw      a1, 36(sp)
    lw      a2, 32(sp)

    beq     a2, zero, buffer_too_small

    sb      zero, 0(a1)

    li      a0, 0
    j       function_epilogue

# --------------------------------------------------
# Search for states beyond Distance-5
# --------------------------------------------------

search_deep_state:

    # ---------------------------------------
    # Prepare Hybrid IDA* arguments
    # ---------------------------------------

    # a0 = initial permutation rank
    lw      a0, 16(sp)

    # a1 = initial orientation rank
    lw      a1, 20(sp)

    # a2 = path buffer
    #
    # Use sp+0..10 to store Move IDs.
    # Ranking is already finished.
    mv      a2, sp

    # Search optimal solution
    jal     ra, rubik_search_asm

    # Search failed?
    blt     a0, zero, invalid_state

    # Save optimal solution length
    sw      a0, 24(sp)


# --------------------------------------------------
# Calculate required output buffer size
# --------------------------------------------------

    # t0 = required bytes
    # Include terminating NUL.
    li      t0, 1

    # t1 = path index
    li      t1, 0

    # t2 = solution length
    lw      t2, 24(sp)


search_count_loop:

    # Finished counting all moves?
    bgeu    t1, t2, search_check_capacity

    # ---------------------------------------
    # Read Move ID
    # ---------------------------------------

    add     t3, sp, t1
    lbu     t3, 0(t3)

    # Validate Move ID
    li      t4, 9
    bgeu    t3, t4, invalid_state

    # ---------------------------------------
    # Count separator
    # ---------------------------------------

    # Every move except the first needs a space.
    beq     t1, zero, search_count_name

    addi    t0, t0, 1


search_count_name:

    # Each move contains at least one character.
    addi    t0, t0, 1

    # Address = move_names + move*3
    slli    t4, t3, 1
    add     t4, t4, t3

    la      t5, move_names
    add     t5, t5, t4

    # Does the move have a second character?
    lbu     t6, 1(t5)

    beq     t6, zero, search_count_next

    # R2, R', B2, B', D2, D' have two characters.
    addi    t0, t0, 1


search_count_next:

    addi    t1, t1, 1
    j       search_count_loop


# --------------------------------------------------
# Verify output buffer capacity
# --------------------------------------------------

search_check_capacity:

    # t0 = required bytes including NUL
    # t1 = user-provided capacity
    lw      t1, 32(sp)

    # If cap < required, buffer is too small.
    bltu    t1, t0, buffer_too_small

    # Check output pointer.
    lw      t1, 36(sp)

    # A NULL pointer cannot receive the solution.
    beq     t1, zero, buffer_too_small


# --------------------------------------------------
# Convert Move IDs into output string
# --------------------------------------------------

    # t0 = output position
    li      t0, 0

    # t1 = path index
    li      t1, 0

    # t2 = solution length
    lw      t2, 24(sp)


search_format_loop:

    bgeu    t1, t2, search_format_done

    # ---------------------------------------
    # Read Move ID
    # ---------------------------------------

    add     t3, sp, t1
    lbu     t3, 0(t3)

    # ---------------------------------------
    # Calculate Move Name Address
    # ---------------------------------------

    slli    t4, t3, 1
    add     t4, t4, t3

    la      t5, move_names
    add     t4, t5, t4

    # ---------------------------------------
    # Add separator before move
    # ---------------------------------------

    beq     t1, zero, search_write_first_char

    lw      t6, 36(sp)
    add     t6, t6, t0

    li      t5, 32
    sb      t5, 0(t6)

    addi    t0, t0, 1


# --------------------------------------------------
# Write first move character
# --------------------------------------------------

search_write_first_char:

    lbu     t5, 0(t4)

    lw      t6, 36(sp)
    add     t6, t6, t0

    sb      t5, 0(t6)

    addi    t0, t0, 1


# --------------------------------------------------
# Write optional second character
# --------------------------------------------------

    lbu     t5, 1(t4)

    beq     t5, zero, search_format_next

    lw      t6, 36(sp)
    add     t6, t6, t0

    sb      t5, 0(t6)

    addi    t0, t0, 1


search_format_next:

    addi    t1, t1, 1

    j       search_format_loop


# --------------------------------------------------
# Terminate string and return solution length
# --------------------------------------------------

search_format_done:

    # out[position] = '\0'
    lw      t1, 36(sp)
    add     t1, t1, t0

    sb      zero, 0(t1)

    # Return optimal solution length
    lw      a0, 24(sp)

    j       function_epilogue

buffer_too_small:

    # Load original capacity.
    lw      t0, 32(sp)

    # cap == 0: nothing can be written.
    beq     t0, zero, buffer_too_small_return

    # Load original output pointer.
    lw      t1, 36(sp)

    # out == NULL: cannot clear the buffer.
    beq     t1, zero, buffer_too_small_return

    # If possible, clear the first byte.
    sb      zero, 0(t1)


buffer_too_small_return:

    li      a0, -2
    j       function_epilogue

invalid_state:
    li      a0, -1
    j       function_epilogue

function_epilogue:

    lw      ra, 44(sp)
    addi    sp, sp, 48
    ret


    .size rubik_solve_asm, .-rubik_solve_asm


    #先建立資料唯獨區
    .section .rodata
    .balign 4

factorial_table:
    .word 720, 120, 24, 6, 2, 1, 1

    .text
    .balign 4
    .globl rank_perm_asm

rank_perm_asm:

    # a0 = address of p[7]
    # Return a0 = permutation rank
    # t0 = 外層迴圈索引
    # t1 = 累積 ranking 結果
    # t2 = facorial table 的起始位址
    # t3 = 暫存位址或比較值
    # t4 = 目前角塊
    # t5 = 內層迴圈索引
    # t6 = 特定狀態右邊較小元素數量
    # a1 = 暫存 p[i] 或 factoraial 權重

    li      t0, 0          # i
    li      t1, 0          # rank

    la      t2, factorial_table

# 外層迴圈，判斷是否處理七個角塊
rank_outer:

    li      t3, 7
    bge     t0, t3, rank_done

    # 讀取p[i]
    add     t3, a0, t0
    lbu     t4, 0(t3)

    # j = i + 1
    addi    t5, t0, 1

    # 初始化smaller = 0，用於計數特地定狀態右邊較小狀態
    li      t6, 0

# 內層迴圈，Permutation -> rank
rank_inner:

    li      a1, 7
    bge     t5, a1, rank_weight

    # p[j]
    add     a1, a0, t5
    lbu     a1, 0(a1)

    # if p[j] < p[i], smaller++
    bgeu    a1, t4, rank_skip

    addi    t6, t6, 1

rank_skip:

    addi    t5, t5, 1
    j       rank_inner

rank_weight:

    # Load factorial[i]
    slli    a1, t0, 2
    add     a1, t2, a1
    lw      a1, 0(a1)



# rank += smaller * factorial[i]
# Use repeated addition instead of MUL.
rank_add_loop:

    beq     t6, zero, rank_next

    add     t1, t1, a1
    addi    t6, t6, -1

    j       rank_add_loop

# 前往下一個角塊
rank_next:

    addi    t0, t0, 1
    j       rank_outer

# return rank
rank_done:

    mv      a0, t1
    ret



    .text
    .balign 4
    .globl rank_orient_asm
    .type rank_orient_asm, @function


# orientation -> rank
rank_orient_asm:

    # a0 = address of o[7], each element is 0..2
    # return a0 = orientation rank (0..728)
    # t0 = 目前處理第幾個 Orientation
    # t1 = 累積計算的 Rank
    # t2 = 迴圈結束條件
    # t3 = o[i] 的記憶體位址
    # t4 = 從記憶體讀出的 o[i]
    # t5 = 暫存 Rank * 2

    li      t0, 0          # i = 0
    li      t1, 0          # rank = 0

rank_orient_loop:

    # Stop after processing six orientations，因為第七個角塊可已從前面6個判斷出來
    li      t2, 6
    bge     t0, t2, rank_orient_done

    # Load o[i]
    add     t3, a0, t0
    lbu     t4, 0(t3)

    # rank = rank * 3 + o[i]
    # Multiplication by 3 = (rank << 1) + rank
    slli    t5, t1, 1      # t5 = rank * 2
    add     t1, t5, t1     # t1 = rank * 3
    add     t1, t1, t4     # t1 += o[i]

    # i++
    addi    t0, t0, 1

    j       rank_orient_loop

rank_orient_done:

    mv      a0, t1
    ret

    .size rank_orient_asm, .-rank_orient_asm
