#!/usr/bin/env python3

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SOURCE = ROOT / "src/rubik/rubik_transition.h"
OUTPUT = ROOT / "src/rubik/rubik_transition9.h"

PERM_SIZE = 5040
ORIENT_SIZE = 729


def read_table(text, name, row_size):
    """Read a 3-face transition table from the original header."""

    pattern = (
        r"static\s+const\s+uint16_t\s+"
        + re.escape(name)
        + r"\s*\[\s*3\s*\]\s*\[\s*"
        + str(row_size)
        + r"\s*\]\s*=\s*\{(.*?)\};"
    )

    match = re.search(pattern, text, re.DOTALL)

    if match is None:
        raise ValueError(f"Cannot find table: {name}")

    body = match.group(1)

    # Remove C comments before extracting numbers.
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    body = re.sub(r"//[^\n]*", "", body)

    values = [
        int(x, 0)
        for x in re.findall(r"0[xX][0-9a-fA-F]+|\d+", body)
    ]

    expected = 3 * row_size

    if len(values) != expected:
        raise ValueError(
            f"{name}: expected {expected} values, "
            f"got {len(values)}"
        )

    if any(x < 0 or x >= row_size for x in values):
        raise ValueError(f"{name}: invalid transition index")

    return [
        values[i * row_size:(i + 1) * row_size]
        for i in range(3)
    ]


def expand_moves(base_tables):
    """Generate quarter-turn, half-turn and inverse tables."""

    result = []

    for face in range(3):
        base = base_tables[face]
        current = list(range(len(base)))

        for turns in range(1, 4):

            current = [base[x] for x in current]

            # Move order:
            # R, R2, R', B, B2, B', D, D2, D'
            result.append(current[:])

        # Four quarter-turns must restore every rank.
        restored = [base[x] for x in current]

        if restored != list(range(len(base))):
            raise ValueError(
                f"Face {face}: four-turn identity failed"
            )

    return result


def write_table(out, name, tables, row_size):
    out.write(
        f"static const uint16_t "
        f"{name}[9][{row_size}] = {{\n"
    )

    for move, row in enumerate(tables):

        out.write(f"    /* Move {move} */\n")
        out.write("    {\n")

        for i in range(0, row_size, 16):
            values = row[i:i + 16]

            out.write(
                "        "
                + ", ".join(str(x) for x in values)
                + ",\n"
            )

        out.write("    },\n")

    out.write("};\n\n")


def main():
    text = SOURCE.read_text(encoding="utf-8")

    pt = read_table(text, "pt", PERM_SIZE)
    ot = read_table(text, "ot", ORIENT_SIZE)

    pt9 = expand_moves(pt)
    ot9 = expand_moves(ot)

    with OUTPUT.open("w", encoding="utf-8") as out:

        out.write(
            "/* Auto-generated nine-move transition tables. */\n"
        )
        out.write(
            "/* Generated from rubik_transition.h. */\n\n"
        )
        out.write("#ifndef RUBIK_TRANSITION9_H\n")
        out.write("#define RUBIK_TRANSITION9_H\n\n")
        out.write("#include <stdint.h>\n\n")

        write_table(out, "pt9", pt9, PERM_SIZE)
        write_table(out, "ot9", ot9, ORIENT_SIZE)

        out.write("#endif\n")

    total_bytes = (
        9 * PERM_SIZE * 2
        + 9 * ORIENT_SIZE * 2
    )

    print("Generated:", OUTPUT)
    print("Permutation tables:", len(pt9))
    print("Orientation tables:", len(ot9))
    print("Transition bytes:", total_bytes)
    print("Four-turn identity: PASS")


if __name__ == "__main__":
    main()
