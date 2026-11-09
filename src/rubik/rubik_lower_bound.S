    .text
    .balign 4

    .globl rubik_lower_bound_asm
    .type rubik_lower_bound_asm, @function

rubik_lower_bound_asm:

    # Input:
    # a0 = permutation rank
    # a1 = orientation rank
    #
    # Output:
    # a0 = max(perm_dist[p], orient_dist[o])

    # ---------------------------------------
    # Permutation Lower Bound
    # ---------------------------------------

    la      t0, rubik_perm_dist

    # Address = base + permutation rank
    add     t0, t0, a0

    # hp = perm_dist[p]
    lbu     t1, 0(t0)

    # ---------------------------------------
    # Orientation Lower Bound
    # ---------------------------------------

    la      t0, rubik_orient_dist

    # Address = base + orientation rank
    add     t0, t0, a1

    # ho = orient_dist[o]
    lbu     t2, 0(t0)

    # ---------------------------------------
    # Return max(hp, ho)
    # ---------------------------------------

    # Assume hp >= ho.
    mv      a0, t1

    # If hp >= ho, return hp.
    bgeu    t1, t2, lower_bound_done

    # Otherwise return ho.
    mv      a0, t2


lower_bound_done:

    ret

    .size rubik_lower_bound_asm, .-rubik_lower_bound_asm
