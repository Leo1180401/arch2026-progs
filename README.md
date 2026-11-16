# Bare-Metal RV32I Applications

## 1. Overview

The assignment focuses on implementing and optimizing four applications using both **C and hand-written RISC-V RV32I assembly**, running in a bare-metal environment through the `rv32emu` system emulator.

The primary objective is to understand how algorithms are translated into machine-level operations and to improve execution efficiency while maintaining correctness and satisfying instruction and memory constraints.

### Implemented Programs

| Program | Description | C | RV32I Assembly |
|---|---|---|---|
| MiniRubik | Optimal 2×2×2 Rubik's Cube Solver | ✅ | ✅ |
| Binary GCD | Greatest Common Divisor using binary operations | ✅ | ✅ |
| BFloat16 | Floating-point conversion, multiplication, and square root | ✅ | ✅ |
| Fixed-Point | Bitwise arithmetic and Q11.20 multiplication | ✅ | ✅ |

All four implementations successfully passed the assignment's automated grading framework.

---

## 2. Implementations & Algorithms

### 2.1 MiniRubik — Optimal Cube Solver

**Source files:**
- `src/rubik/rubik.c`
- `src/rubik/rubik.S`

The MiniRubik program solves a 2×2×2 Rubik's Cube with one fixed corner.

The cube is represented using seven movable corner cubies, with each state consisting of a permutation and an orientation.

The number of reachable states in this representation is:

\[
7! \times 3^6 = 3,674,160
\]

The solver supports nine moves based on the R, B, and D faces.

**Algorithm and Optimization**

The implementation uses a rank-based search approach with the following techniques:

- **Rank-Based State Representation:** Encodes permutations and orientations into compact integer coordinates.
- **Iterative Deepening A\* (IDA\*):** Searches for an optimal solution while progressively increasing the search depth.
- **Pattern Databases (PDB):** Provides admissible lower bounds for pruning unnecessary search branches.
- **Transition Tables:** Replaces repeated state transformations with precomputed rank transitions.
- **Depth-5 Lookup:** Accelerates the search by using precomputed information for states near the solved position.

The RV32I assembly implementation further optimizes state transitions, table lookups, and search operations.

**Result:** The assembly solver achieves a **2.85× speedup** over the best optimized C build.

### 2.2 Binary GCD

**Source files:**
- `src/gcd/gcd.c`
- `src/gcd/gcd.S`

This implementation calculates the Greatest Common Divisor (GCD) using the **Binary GCD Algorithm**, also known as Stein's algorithm.

Unlike the traditional Euclidean algorithm, Binary GCD avoids division and modulo operations by using:

- Bitwise operations to determine whether operands are even or odd.
- Right shifts to remove factors of two.
- Subtraction to reduce the remaining operands.
- Left shifts to restore the common factors of two.

These operations are particularly suitable for RV32I processors, which do not include hardware integer multiplication or division instructions in the base ISA.

The assembly implementation focuses on reducing unnecessary branches and simplifying arithmetic operations.

**Result:** The assembly implementation achieves a **1.07× speedup** over the best optimized C build.

### 2.3 BFloat16 Arithmetic

**Source files:**
- `src/bf16/bf16.c`
- `src/bf16/bf16.S`

BFloat16 is a 16-bit floating-point format consisting of:

| Component | Bits |
|---|---:|
| Sign | 1 |
| Exponent | 8 |
| Fraction | 7 |

The implementation supports three major operations.

**FP32 to BFloat16 Conversion**

Converts a 32-bit IEEE 754 floating-point bit pattern into BFloat16 using round-to-nearest, ties-to-even (RNE), with handling for special values.

**BFloat16 Multiplication**

Performs floating-point multiplication through integer and bitwise operations, including:

- Sign, exponent, and fraction extraction.
- Special-value handling.
- Significand multiplication using shift-and-add.
- Normalization and exponent adjustment.
- Result reconstruction.

**BFloat16 Square Root**

Uses integer arithmetic and a search-based approach to compute square-root results without relying on hardware floating-point instructions.

The C and assembly implementations are tested against the assignment's expected behavior, including special-value cases.

**Results:**

- BFloat16 Multiplication: **1.04× speedup**
- BFloat16 Square Root: **1.12× speedup**

### 2.4 Fixed-Point Arithmetic

**Source files:**
- `src/fixed/fixed.c`
- `src/fixed/fixed.S`

This program implements four arithmetic operations.

| Function | Description |
|---|---|
| `op1()` | Bitwise addition using XOR and carry propagation |
| `op2()` | Unsigned subtraction modulo \(2^{32}\) |
| `op3()` | Overflow-free integer average |
| `q_mul()` | Signed Q11.20 fixed-point multiplication |

**Bitwise Addition**

Addition is implemented through repeated XOR and carry operations:

\[
Sum = a \oplus b
\]

\[
Carry = (a \land b) \ll 1
\]

The process repeats until the carry becomes zero.

**Overflow-Free Average**

To avoid overflow when calculating the average of two unsigned integers, the following identity is used:

\[
\left\lfloor\frac{a+b}{2}\right\rfloor
=
(a \land b)+((a\oplus b)\gg1)
\]

**Q11.20 Fixed-Point Multiplication**

The multiplication implementation computes a full signed 64-bit intermediate product, applies the required rounding bias, and shifts the result right by 20 bits.

The RV32I assembly implementation uses a shift-and-add multiplication algorithm without relying on the M extension.

An important optimization is **early termination**: the multiplication loop stops once all remaining multiplier bits become zero, instead of always executing 32 iterations.

**Result:** The optimized assembly implementation achieves a **1.45× speedup** over the best optimized C build.

---

## 3. Repository Structure

```text
arch2026-progs/
├── Makefile
├── README.md
├── common/
│   ├── start.S
│   ├── linker.ld
│   ├── perf.S
│   └── ...
├── src/
│   ├── rubik/
│   │   ├── rubik.c
│   │   ├── rubik.S
│   │   └── ...
│   ├── gcd/
│   │   ├── gcd.c
│   │   ├── gcd.S
│   │   └── gcd.h
│   ├── bf16/
│   │   ├── bf16.c
│   │   ├── bf16.S
│   │   └── bf16.h
│   └── fixed/
│       ├── fixed.c
│       ├── fixed.S
│       └── fixed.h
├── tests/
├── scripts/
├── mk/
├── tools/
└── results/
```

### Directory Description

| Directory | Purpose |
|---|---|
| `src/` | C and RV32I assembly implementations |
| `common/` | Bare-metal runtime, linker script, and benchmarking utilities |
| `tests/` | Micro-tests and reference test vectors |
| `scripts/` | Automated testing, grading, and validation scripts |
| `mk/` | Build system configuration |
| `tools/` | Supporting utilities |
| `results/` | Generated performance measurements and reports |

---

## 4. Build & Execution

### 4.1 Development Environment

The project was developed and tested using:

| Component | Environment |
|---|---|
| Operating System | Ubuntu 20.04 LTS (WSL) |
| Architecture | x86-64 host |
| RISC-V Toolchain | xPack RISC-V GNU Toolchain 14.2.0 |
| Target ISA | RV32I + Zicsr |
| Emulator | rv32emu |
| Build System | GNU Make |
| Optimization Levels | `-O1`, `-O2`, `-O3`, `-Os` |

The implementations do not rely on the RISC-V M or F extensions.

### 4.2 Clone Repository

```bash
git clone https://github.com/Leo1180401/arch2026-progs.git

cd arch2026-progs
```

### 4.3 Build Programs

Build the project using the default optimization level:

```bash
make
```

The build system validates the toolchain, prepares the emulator, and compiles the programs.

To generate the supported optimization-level builds:

```bash
make elfs
```

### 4.4 Run Individual Programs

The generated ELF files can be executed through rv32emu.

For example:

```bash
third_party/rv32emu/build/rv32emu build/rubik/O2/rubik.elf
```

Similarly:

```bash
third_party/rv32emu/build/rv32emu build/gcd/O2/gcd.elf

third_party/rv32emu/build/rv32emu build/bf16/O2/bf16.elf

third_party/rv32emu/build/rv32emu build/fixed/O2/fixed.elf
```

These ELF files execute the corresponding bare-metal test and benchmark programs.

### 4.5 Run Automated Tests

To run the repository's combined checks:

```bash
make test
```

To run the automated grading driver directly:

```bash
make grade
```

To grade an individual program:

```bash
make grade DRIVER_ARGS="--prog rubik"
```

Replace `rubik` with `gcd`, `bf16`, or `fixed` as needed.

### 4.6 Performance Measurement

Generate cycle measurements:

```bash
make cycles
```

Generate disassembly listings:

```bash
make dump
```

Inspect implementation sizes:

```bash
make size
```

The performance measurements are based on RISC-V execution in `rv32emu`.

---

## 5. Verification & Performance Analysis

### 5.1 Correctness Verification

The implementations were validated using the assignment's automated test framework.

The verification process includes:

- Functional correctness tests.
- C and assembly result comparisons.
- Edge-case and special-value tests.
- Instruction-budget checks.
- RV32I ISA restrictions.
- Cycle-count measurements.
- Memory-footprint validation.

### 5.2 Performance Comparison

The following results were reported by the assignment grading driver.

Speedups compare the assembly implementation against the fastest C build among the tested optimization levels.

| Program | Function | Assembly Speedup |
|---|---|---:|
| MiniRubik | `solve()` | **2.85×** |
| Binary GCD | `gcd()` | **1.07×** |
| BFloat16 | `from_f32()` | 0.90× |
| BFloat16 | `mul()` | **1.04×** |
| BFloat16 | `sqrt()` | **1.12×** |
| Fixed-Point | `op1()` | 0.99× |
| Fixed-Point | `op2()` | 1.00× |
| Fixed-Point | `op3()` | 1.00× |
| Fixed-Point | `q_mul()` | **1.45×** |

Values greater than 1.00× indicate that assembly is faster than the best C implementation.

The most significant improvements were observed in the MiniRubik solver and Q11.20 fixed-point multiplication.
---

## 6. References

- [Computer Architecture Assignment 2 — Complete Applications](https://hackmd.io/@sysprog/2026-arch-homework2)
- [Original Assignment Repository — sysprog21/arch2026-progs](https://github.com/sysprog21/arch2026-progs)
- [rv32emu — RISC-V Emulator](https://github.com/sysprog21/rv32emu)
- [RISC-V International](https://riscv.org/)

---

**Project:** Computer Architecture HW2 (2026)  
**University:** National Cheng Kung University  
**Implementation:** C and RV32I Assembly
