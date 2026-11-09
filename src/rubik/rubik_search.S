    .text
    .balign 4

    .globl rubik_search_asm
    .type rubik_search_asm, @function

# --------------------------------------------------
# rubik_search_asm
#
# Input:
#   a0 = initial permutation rank
#   a1 = initial orientation rank
#   a2 = path buffer (at least 11 bytes)
#
# Output:
#   a0 = solution length (6..11), or -1
#
# Uses:
#   Hybrid IDA* + PDB + Distance-5 Table
# --------------------------------------------------

rubik_search_asm:

    # 128-byte stack frame
    addi    sp, sp, -128

    # Save callee-saved registers
    sw      s0, 76(sp)
    sw      s1, 80(sp)
    sw      s2, 84(sp)
    sw      s3, 88(sp)
    sw      s4, 92(sp)
    sw      s5, 96(sp)
    sw      s6, 100(sp)
    sw      s7, 104(sp)
    sw      s8, 108(sp)
    sw      s9, 112(sp)
    sw      s10, 116(sp)
    sw      s11, 120(sp)
    sw      ra, 124(sp)

    # Register usage:
    #
    # s0  = path buffer pointer
    # s1  = total depth limit
    # s2  = prefix search depth limit
    # s3  = current depth
    # s4  = current permutation rank
    # s5  = current orientation rank
    # s6  = current coordinate frame pointer
    # s7  = next_move array pointer
    # s8  = initial permutation rank
    # s9  = initial orientation rank
    # s10 = child permutation rank
    # s11 = child orientation rank

    mv      s8, a0
    mv      s9, a1
    mv      s0, a2

    # Start with limit = 6
    li      s1, 6


# --------------------------------------------------
# Begin a new IDA* iteration
# --------------------------------------------------

search_begin_limit:

    # Prefix depth = limit - 5
    addi    s2, s1, -5

    # Start at depth 0
    li      s3, 0

    # Restore initial ranks
    mv      s4, s8
    mv      s5, s9

    # coordinate_stack begins at sp + 0
    mv      s6, sp

    # next_move begins at sp + 28
    addi    s7, sp, 28

    # Store initial coordinate
    sh      s4, 0(s6)
    sh      s5, 2(s6)

    # First move to try = 0
    sb      zero, 0(s7)


# --------------------------------------------------
# Enter current search node
# --------------------------------------------------

search_enter:

    # At prefix boundary, check Distance-5 Table
    beq     s3, s2, search_leaf


# --------------------------------------------------
# Try next move
# --------------------------------------------------

search_try:

    # Load next_move[depth]
    add     t0, s7, s3
    lbu     t1, 0(t0)

    # No moves left?
    li      t2, 9
    bgeu    t1, t2, search_backtrack

    # Increment next_move[depth]
    addi    t2, t1, 1
    sb      t2, 0(t0)

    # At depth 0, no previous face exists
    beq     s3, zero, search_expand

    # ---------------------------------------
    # Same-face pruning
    # ---------------------------------------

    # Previous move = path[depth - 1]
    add     t0, s0, s3
    lbu     t2, -1(t0)

    # Determine previous face
    la      t3, rubik_search_move_faces
    add     t4, t3, t2
    lbu     t5, 0(t4)

    # Determine candidate face
    add     t4, t3, t1
    lbu     t6, 0(t4)

    # Skip consecutive moves of same face
    beq     t5, t6, search_try


# --------------------------------------------------
# Expand candidate move
# --------------------------------------------------

search_expand:

    # Store candidate move in path[depth]
    add     t0, s0, s3
    sb      t1, 0(t0)

    # Apply move to current state
    mv      a0, s4
    mv      a1, s5
    mv      a2, t1

    jal     ra, rubik_apply_move_asm

    # Save child ranks
    mv      s10, a0
    mv      s11, a1

    # ---------------------------------------
    # Calculate PDB heuristic
    # ---------------------------------------

    mv      a0, s10
    mv      a1, s11

    jal     ra, rubik_lower_bound_asm

    # f = depth + 1 + heuristic
    addi    t0, s3, 1
    add     t0, t0, a0

    # If f > limit, prune
    blt     s1, t0, search_try

    # ---------------------------------------
    # Accept child state
    # ---------------------------------------

    # Advance depth
    addi    s3, s3, 1

    # Advance coordinate stack by 4 bytes
    addi    s6, s6, 4

    # Save child ranks
    sh      s10, 0(s6)
    sh      s11, 2(s6)

    # Update current ranks
    mv      s4, s10
    mv      s5, s11

    # Initialize next_move[new_depth]
    add     t0, s7, s3
    sb      zero, 0(t0)

    j       search_enter


# --------------------------------------------------
# Prefix boundary: query Distance-5 Table
# --------------------------------------------------

search_leaf:

    # State ID = p * 729 + o

    # p * 9
    slli    t0, s4, 3
    add     t0, t0, s4

    # p * 81
    slli    t1, t0, 3
    add     t0, t1, t0

    # p * 729
    slli    t1, t0, 3
    add     t0, t1, t0

    add     a0, t0, s5

    # Lookup State ID
    jal     ra, rubik_depth5_lookup_asm

    # Not in Distance-5 Table
    blt     a0, zero, search_backtrack

    # Save metadata
    sw      a0, 36(sp)

    # Verify prefix + suffix <= limit
    srli    t0, a0, 4
    add     t0, t0, s3

    blt     s1, t0, search_backtrack

    # Found a valid suffix
    j       search_suffix


# --------------------------------------------------
# Append Distance-5 suffix
# --------------------------------------------------

search_suffix:

    # Load metadata
    lw      t0, 36(sp)

    # Extract remaining distance
    srli    t1, t0, 4

    # Distance == 0: solved
    beq     t1, zero, search_found

    # Extract next move
    andi    t1, t0, 15

    # Validate move ID
    li      t2, 9
    bgeu    t1, t2, search_bad_table

    # Store move ID
    add     t2, s0, s3
    sb      t1, 0(t2)

    # Apply suffix move
    mv      a0, s4
    mv      a1, s5
    mv      a2, t1

    jal     ra, rubik_apply_move_asm

    # Update ranks
    mv      s4, a0
    mv      s5, a1

    # Increase solution length
    addi    s3, s3, 1

    # ---------------------------------------
    # Compute new State ID
    # ---------------------------------------

    slli    t0, s4, 3
    add     t0, t0, s4

    slli    t1, t0, 3
    add     t0, t1, t0

    slli    t1, t0, 3
    add     t0, t1, t0

    add     a0, t0, s5

    jal     ra, rubik_depth5_lookup_asm

    # Unexpected missing state
    blt     a0, zero, search_bad_table

    # Save new metadata
    sw      a0, 36(sp)

    j       search_suffix


# --------------------------------------------------
# Search success
# --------------------------------------------------

search_found:

    # Return solution length
    mv      a0, s3
    j       search_return


# --------------------------------------------------
# Backtracking
# --------------------------------------------------

search_backtrack:

    # Back at root?
    beq     s3, zero, search_next_limit

    # Move to parent depth
    addi    s3, s3, -1

    # Restore parent coordinate frame
    addi    s6, s6, -4

    lhu     s4, 0(s6)
    lhu     s5, 2(s6)

    # Continue with next move
    j       search_try


# --------------------------------------------------
# Increase IDA* limit
# --------------------------------------------------

search_next_limit:

    addi    s1, s1, 1

    li      t0, 11
    blt     t0, s1, search_failed

    j       search_begin_limit


search_bad_table:
search_failed:

    li      a0, -1


# --------------------------------------------------
# Restore registers and return
# --------------------------------------------------

search_return:

    lw      s0, 76(sp)
    lw      s1, 80(sp)
    lw      s2, 84(sp)
    lw      s3, 88(sp)
    lw      s4, 92(sp)
    lw      s5, 96(sp)
    lw      s6, 100(sp)
    lw      s7, 104(sp)
    lw      s8, 108(sp)
    lw      s9, 112(sp)
    lw      s10, 116(sp)
    lw      s11, 120(sp)
    lw      ra, 124(sp)

    addi    sp, sp, 128
    ret

    .size rubik_search_asm, .-rubik_search_asm


# --------------------------------------------------
# Move face lookup
# --------------------------------------------------

    .section .rodata
    .balign 4

rubik_search_move_faces:
    .byte 0, 0, 0
    .byte 1, 1, 1
    .byte 2, 2, 2
