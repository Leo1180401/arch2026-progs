#include "fixed.h"
#define Q 20


/*
 * op1: Bitwise addition
 * a + b = (a XOR b) + 2 * (a & b)
 *
 * Sum   = a XOR b
 * Carry = (a AND b) << 1
 *
 * Repeat until carry becomes zero.
 * Store the number of passes in *n.
 */
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int count = 0;

    while (b != 0) {
        uint32_t carry = (a & b) << 1;

        a = a ^ b;
        b = carry;

        count++;
    }

    *n = count;

    return a;
}


/*
 * op2: Unsigned subtraction modulo 2^32.
 */
uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}


/*
 * op3: Overflow-free average
 *
 * floor((a + b) / 2) = (a & b) + ((a ^ b) >> 1)
 */
uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}


/*
 * int32_t a, int32_t b
 * A = A_H * 2^16 + A_L；A_H 為高 16bits
 * B = B_H * 2^16 + B_L
 * AB = A_L * B_L + (A_L * B_H) * 2^16 + A_H * B_H * 2^32
 * If negative number, caculate the number, then add the sign bit back to result
 */
int32_t q_mul(int32_t a, int32_t b)
{
    /* Step 1: Determine the sign */
    // (a < 0) & (b < 0), 若"是"則為1,若否,則為0；兩邊(a < 0) != (b < 0)不一樣才會得到1
    int negative = (a < 0) != (b < 0);

    /* Step 2: Convert operands to unsigned magnitudes */
    uint32_t ma = (a < 0) ? 0u - (uint32_t)a : (uint32_t)a;
    uint32_t mb = (b < 0) ? 0u - (uint32_t)b : (uint32_t)b;

    /* Step 3: Split each operand into high and low 16-bit parts */
    uint32_t al = ma & 0xFFFFu;
    uint32_t ah = ma >> 16;

    uint32_t bl = mb & 0xFFFFu;
    uint32_t bh = mb >> 16;

    /* Step 4: Compute four 16-bit partial products */
    uint32_t p0 = al * bl;
    uint32_t p1 = al * bh;
    uint32_t p2 = ah * bl;
    uint32_t p3 = ah * bh;

    /* Step 5: Combine into a full unsigned 64-bit product */
    uint64_t magnitude =
        (uint64_t)p0 +
        ((uint64_t)p1 << 16) +
        ((uint64_t)p2 << 16) +
        ((uint64_t)p3 << 32);

    /* Step 6: Restore the sign */
    int64_t product = negative
        ? -(int64_t)magnitude
        :  (int64_t)magnitude;

    /* Step 7: Add rounding bias */
    product += (int64_t)1 << (Q - 1);

    /* Step 8: Arithmetic right shift and retain low 32 bits */
    return (int32_t)(product >> Q);
}
