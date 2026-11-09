#!/usr/bin/env python3

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SOURCE = ROOT / "src/rubik/rubik_pdb.h"
OUTPUT = ROOT / "src/rubik/rubik_pdb.inc"


def read_array(text, name, expected_size):

    pattern = (
        r"static\s+const\s+uint8_t\s+"
        + re.escape(name)
        + r"\s*\[\s*"
        + str(expected_size)
        + r"\s*\]\s*=\s*\{(.*?)\};"
    )

    match = re.search(pattern, text, re.DOTALL)

    if match is None:
        raise ValueError(f"Cannot find {name}")

    body = match.group(1)

    # Remove C comments.
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    body = re.sub(r"//[^\n]*", "", body)

    values = [
        int(x, 0)
        for x in re.findall(r"0[xX][0-9a-fA-F]+|\d+", body)
    ]

    if len(values) != expected_size:
        raise ValueError(
            f"{name}: expected {expected_size}, got {len(values)}"
        )

    if any(x < 0 or x > 255 for x in values):
        raise ValueError(f"{name}: value outside uint8_t range")

    return values


def write_array(out, symbol, values):

    out.write(f"    .globl {symbol}\n")
    out.write(f"{symbol}:\n")

    for i in range(0, len(values), 20):

        row = values[i:i + 20]

        out.write(
            "    .byte "
            + ", ".join(str(x) for x in row)
            + "\n"
        )

    out.write("\n")


def main():

    text = SOURCE.read_text(encoding="utf-8")

    perm = read_array(text, "perm_dist", 5040)
    orient = read_array(text, "orient_dist", 729)

    with OUTPUT.open("w", encoding="utf-8") as out:

        out.write("# Auto-generated Rubik PDB tables.\n")
        out.write("# Source: src/rubik/rubik_pdb.h\n\n")

        out.write("    .section .rodata\n")
        out.write("    .balign 4\n\n")

        write_array(out, "rubik_perm_dist", perm)
        write_array(out, "rubik_orient_dist", orient)

    print("Generated:", OUTPUT)
    print("Permutation PDB:", len(perm), "bytes")
    print("Orientation PDB:", len(orient), "bytes")
    print("Total PDB:", len(perm) + len(orient), "bytes")

    print("Solved permutation distance:", perm[0])
    print("Solved orientation distance:", orient[0])

    assert perm[0] == 0
    assert orient[0] == 0


if __name__ == "__main__":
    main()
