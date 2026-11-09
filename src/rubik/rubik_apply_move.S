    .text
    .balign 4

    .globl rubik_apply_move_asm
    .type rubik_apply_move_asm, @function

rubik_apply_move_asm:

    # Input:
    # a0 = permutation rank
    # a1 = orientation rank
    # a2 = move ID (0..8)
    #
    # Output:
    # a0 = new permutation rank
    # a1 = new orientation rank

    # ---------------------------------------
    # Decode Move ID
    # ---------------------------------------

    # t0 = face index
    li      t0, 0

    # t1 = 3
    li      t1, 3

    # 找出 move = R, R2, R',...
    # R family: move 0..2
    bltu    a2, t1, move_face_ready

    # Move 3..8: subtract 3, advance face
    addi    a2, a2, -3
    addi    t0, t0, 1

    # B family: move 3..5
    bltu    a2, t1, move_face_ready

    # D family: move 6..8
    addi    a2, a2, -3
    addi    t0, t0, 1

move_face_ready:

    # turns = (move % 3) + 1(+1 因為 index 從0開始)
    addi    t2, a2, 1

    # ---------------------------------------
    # Compute Permutation Table Base
    # ---------------------------------------

    la      t3, rubik_pt3

    # Each face occupies 10080 bytes.
    li      t4, 10080

    # face 0: offset 0
    beq     t0, zero, perm_base_ready

    # face 1: offset 10080
    add     t3, t3, t4

    li      t5, 1
    beq     t0, t5, perm_base_ready

    # face 2: offset 20160
    add     t3, t3, t4

perm_base_ready:

    # ---------------------------------------
    # Compute Orientation Table Base
    # ---------------------------------------

    la      t4, rubik_ot3

    # Each face occupies 1458 bytes.
    li      t5, 1458

    beq     t0, zero, orient_base_ready

    add     t4, t4, t5

    li      t6, 1
    beq     t0, t6, orient_base_ready

    add     t4, t4, t5

orient_base_ready:

    # ---------------------------------------
    # Apply 1, 2, or 3 Quarter-Turns
    # ---------------------------------------

apply_turn_loop:

    # p = pt[face][p]
    # 因為 .half 代表每筆2 bytes，故*2
    slli    t5, a0, 1
    add     t5, t3, t5
    lhu     a0, 0(t5)

    # o = ot[face][o]
    slli    t5, a1, 1
    add     t5, t4, t5
    lhu     a1, 0(t5)

    # One turn completed
    addi    t2, t2, -1

    # Repeat until turns == 0
    bne     t2, zero, apply_turn_loop

    ret

    .size rubik_apply_move_asm, .-rubik_apply_move_asm
