    .text
    .balign 4

    .globl rubik_depth5_lookup_asm
    .type rubik_depth5_lookup_asm, @function

# 做 binary search[0,12224)
rubik_depth5_lookup_asm:

    # Input:
    # a0 = target State ID
    #
    # Output:
    # a0 = metadata (0..95), or -1 if not found

    # t0 = low
    li      t0, 0

    # t1 = high (exclusive)
    li      t1, 12224

    # t2 = base address of State IDs
    la      t2, rubik_depth5_ids

lookup_loop:

    # while (low < high)
    bgeu    t0, t1, lookup_not_found

    # mid = low + (high - low) / 2
    sub     t3, t1, t0
    srli    t3, t3, 1
    add     t3, t3, t0

    # address = base + mid * 4(每元素佔 4bytes)
    slli    t4, t3, 2
    add     t4, t2, t4

    # ids[mid]
    lw      t5, 0(t4)

    # 若target = ids[mid]，跳到lookup_found
    beq     t5, a0, lookup_found

    # 若target < ids[mid]，跳到lookup_found_right(找右邊區塊)
    bltu    t5, a0, lookup_search_right

    # high = mid
    mv      t1, t3
    j       lookup_loop

lookup_search_right:

    # low = mid + 1
    addi    t0, t3, 1
    j       lookup_loop

lookup_found:

    # metadata is stored as one byte per state
    la      t4, rubik_depth5_meta

    # metadata address = base + mid
    add     t4, t4, t3

    # Load metadata
    lbu     a0, 0(t4)
    ret

lookup_not_found:

    li      a0, -1
    ret

    .size rubik_depth5_lookup_asm, .-rubik_depth5_lookup_asm
