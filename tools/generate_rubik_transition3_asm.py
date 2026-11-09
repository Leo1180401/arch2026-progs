#!/usr/bin/env python3

from pathlib import Path

from generate_rubik_transition9 import (
    read_table,
    PERM_SIZE,
    ORIENT_SIZE,
    SOURCE,
)

ROOT = Path(__file__).resolve().parent.parent

OUTPUT = ROOT / "src/rubik/rubik_transition3.inc"


def write_array(out, name, tables):

    out.write("    .globl " + name + "\n")
    out.write(name + ":\n")

    for face, row in enumerate(tables):

        out.write(f"    # Face {face}\n")

        for i in range(0, len(row), 16):

            values = row[i:i + 16]

            out.write(
                "    .half "
                + ", ".join(str(x) for x in values)
                + "\n"
            )

    out.write("\n")


def main():

    text = SOURCE.read_text(encoding="utf-8")

    pt = read_table(text, "pt", PERM_SIZE)
    ot = read_table(text, "ot", ORIENT_SIZE)

    with OUTPUT.open("w", encoding="utf-8") as out:

        out.write(
            "# Auto-generated 3-face Rubik transition tables.\n"
        )

        out.write(
            "# Faces: R, B, D\n\n"
        )

        out.write("    .section .rodata\n")
        out.write("    .balign 4\n\n")

        write_array(out, "rubik_pt3", pt)

        out.write("    .balign 2\n\n")

        write_array(out, "rubik_ot3", ot)

    total = (
        3 * PERM_SIZE * 2
        + 3 * ORIENT_SIZE * 2
    )

    print("Generated:", OUTPUT)
    print("Permutation entries:", 3 * PERM_SIZE)
    print("Orientation entries:", 3 * ORIENT_SIZE)
    print("Transition bytes:", total)


if __name__ == "__main__":
    main()
