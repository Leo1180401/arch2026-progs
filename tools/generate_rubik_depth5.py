from collections import deque
from pathlib import Path

from generate_distance11 import build_tables, N_ORIENT

MAX_DEPTH = 5

EXPECTED_COUNTS = [1, 9, 54, 321, 1847, 9992]

OUTPUT = Path("src/rubik/rubik_depth5.inc")


# --------------------------------------------------
# Apply one of the nine moves
# --------------------------------------------------

def apply_move(state, move, pt, ot):

    p = state // N_ORIENT
    o = state % N_ORIENT

    face = move // 3
    turns = move % 3 + 1

    for _ in range(turns):
        p = pt[face][p]
        o = ot[face][o]

    return p * N_ORIENT + o


# --------------------------------------------------
# Inverse move
# --------------------------------------------------

def inverse_move(move):

    face = move // 3
    turn = move % 3

    return face * 3 + (2 - turn)


# --------------------------------------------------
# Distance-5 BFS
# --------------------------------------------------

def build_depth5(pt, ot):

    # state -> (distance, next_move)
    table = {0: (0, 15)}

    queue = deque([0])

    counts = [0] * (MAX_DEPTH + 1)
    counts[0] = 1

    while queue:

        state = queue.popleft()

        depth, _ = table[state]

        if depth == MAX_DEPTH:
            continue

        for move in range(9):

            new_state = apply_move(state, move, pt, ot)

            if new_state in table:
                continue

            new_depth = depth + 1

            # BFS: return from child to parent
            next_move = inverse_move(move)

            table[new_state] = (new_depth, next_move)

            counts[new_depth] += 1

            queue.append(new_state)

    return table, counts


# --------------------------------------------------
# Verify table
# --------------------------------------------------

def verify_table(table, counts, pt, ot):

    assert counts == EXPECTED_COUNTS, (
        "Incorrect distance distribution: {}".format(counts)
    )

    assert len(table) == 12224

    assert table[0] == (0, 15)

    for state, (depth, move) in table.items():

        if depth == 0:
            assert state == 0
            continue

        assert 0 <= move < 9

        next_state = apply_move(state, move, pt, ot)

        assert next_state in table

        next_depth, _ = table[next_state]

        # Following next_move must decrease distance
        assert next_depth == depth - 1

    print("Distance-5 verification: PASS")


# --------------------------------------------------
# Write Assembly data
# --------------------------------------------------

def write_table(table):

    entries = sorted(table.items())

    with OUTPUT.open("w") as f:

        f.write("# Auto-generated Distance-5 Lookup Table\n")
        f.write("# Do not edit manually.\n\n")

        f.write("    .section .rodata\n")
        f.write("    .balign 4\n\n")

        # Sorted State IDs
        f.write("    .globl rubik_depth5_ids\n")
        f.write("rubik_depth5_ids:\n")

        for i in range(0, len(entries), 8):

            chunk = entries[i:i + 8]

            values = [str(state) for state, _ in chunk]

            f.write("    .word " + ", ".join(values) + "\n")

        f.write("\n")

        # Metadata
        f.write("    .globl rubik_depth5_meta\n")
        f.write("rubik_depth5_meta:\n")

        for i in range(0, len(entries), 20):

            chunk = entries[i:i + 20]

            values = []

            for state, (depth, move) in chunk:

                metadata = (depth << 4) | move

                values.append(str(metadata))

            f.write("    .byte " + ", ".join(values) + "\n")

    print("Saved:", OUTPUT)


# --------------------------------------------------
# Main
# --------------------------------------------------

def main():

    print("Building transition tables...")

    pt, ot = build_tables()

    print("Running Distance-5 BFS...")

    table, counts = build_depth5(pt, ot)

    print("\nDistance distribution:")

    for depth, count in enumerate(counts):
        print("Depth {}: {}".format(depth, count))

    print("\nTotal states:", len(table))

    print("\nVerifying table...")

    verify_table(table, counts, pt, ot)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    write_table(table)

    print("\nDone.")


if __name__ == "__main__":
    main()
