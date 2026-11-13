#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    uint32_t exponent = (f32bits >> 23) & 0xFFu;

    // Preserve Infinity and NaN
    if (exponent == 0xFFu)
        return (uint16_t)(f32bits >> 16);

    // Round to nearest, ties to even(RNE)
    uint32_t rounding_bias =
        0x7FFFu + ((f32bits >> 16) & 1u);

    return (uint16_t)((f32bits + rounding_bias) >> 16);
}

 uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    /* Step 1: Extract sign, exponent and fraction */

    uint32_t sign = (a ^ b) & 0x8000u;

    uint32_t exp_a = (a >> 7) & 0xFFu;
    uint32_t exp_b = (b >> 7) & 0xFFu;

    uint32_t frac_a = a & 0x7Fu;
    uint32_t frac_b = b & 0x7Fu;


    /* Step 2: Handle NaN and Infinity, a first */
    // check special number，exponent = 255?
    if (exp_a == 0xFFu) {
        if (frac_a != 0)
            return a;

        if ((b & 0x7FFFu) == 0)
            return 0x7FC0u;

        return (uint16_t)(sign | 0x7F80u);
    }

    if (exp_b == 0xFFu) {
        if (frac_b != 0)
            return b;

        if ((a & 0x7FFFu) == 0)
            return 0x7FC0u;

        return (uint16_t)(sign | 0x7F80u);
    }


    /* Step 3: Handle zero */

    if ((a & 0x7FFFu) == 0 ||
        (b & 0x7FFFu) == 0)
        return (uint16_t)sign;


    /* Step 4: Prepare significands and exponents */
    // 若exp_a != 0(true)，則(int32_t)exp_a；若否，則1
    int32_t ea = exp_a ? (int32_t)exp_a : 1;
    int32_t eb = exp_b ? (int32_t)exp_b : 1;

    uint32_t ma = exp_a ? (0x80u | frac_a) : frac_a;
    uint32_t mb = exp_b ? (0x80u | frac_b) : frac_b;


    /* Step 5: Normalize subnormal operands */

    while (ma < 128u) {
        ma <<= 1;
        ea--;
    }

    while (mb < 128u) {
        mb <<= 1;
        eb--;
    }


    /* Step 6: Multiply using shift-and-add */
    // 計算相乘後兩個fraction乘積的結果
    uint32_t product = 0;

    uint32_t x = ma;
    uint32_t y = mb;

    while (y != 0) {
        if (y & 1u)
            product += x;

        x <<= 1;
        y >>= 1;
    }


    /* Step 7: Calculate result exponent */

    int32_t exponent = ea + eb - 127;


    /* Step 8: Normalize product */

    uint32_t mantissa;

    // check if the product exceed 32768(0x8000u)
    // if yes, do the extra right shift(8) then, and do the addition to the exponent; if not, right shift the product of 7.
    if (product & 0x8000u) {
        mantissa = product >> 8;
        exponent++;
    } else {
        mantissa = product >> 7;
    }


    /* Step 9: Handle overflow */
    //if the exponent bigger than 255(11111111)，the return "Infinity"(0x7F80u = 11111111 0000000),sign is determined by sign bit.
    if (exponent >= 255)
        return (uint16_t)(sign | 0x7F80u);


    /* Step 10: Handle underflow / subnormal */
    // If the exponent of O/P <= 0(subnormal)
    if (exponent <= 0) {

        if (exponent < -6)
            return (uint16_t)sign;

        uint32_t shift = (uint32_t)(1 - exponent);
        uint32_t fraction = (mantissa & 0x7Fu) >> shift;

        return (uint16_t)(sign | fraction);
    }


    /* Step 11: Assemble normal BF16 result */

    uint32_t fraction = mantissa & 0x7Fu;

    return (uint16_t)(sign |
                      ((uint32_t)exponent << 7) |
                      fraction);
}


uint16_t bf16_sqrt(uint16_t a)
{
    /* Step 1: Extract BF16 fields */

    uint32_t sign = a & 0x8000u;
    uint32_t exponent = (a >> 7) & 0xFFu;
    uint32_t fraction = a & 0x7Fu;


    /* Step 2: Handle NaN and Infinity */

    if (exponent == 0xFFu) {

        /* Preserve NaN */
        if (fraction != 0)
            return a;

        /* sqrt(-Infinity) = NaN */
        if (sign != 0)
            return 0x7FC0u;

        /* sqrt(+Infinity) = +Infinity */
        return a;
    }


    /* Step 3: Handle positive and negative zero */

    if ((a & 0x7FFFu) == 0)
        return 0x0000u;


    /* Step 4: Negative nonzero values produce NaN */
    // 複數一律為 NaN
    if (sign != 0)
        return 0x7FC0u;


    /* Step 5: Positive subnormals produce +0 */
    // 作業要求不處理 subnormal 的平方根
    if (exponent == 0)
        return 0x0000u;


    /* Step 6: Prepare significand and unbiased exponent */
    // m = 128 + F
    uint32_t m = 0x80u | fraction;
    int32_t e = (int32_t)exponent - 127;


    /* Step 7: Make exponent even */
    // 開根號時，指數項變為e/2，為了避免處理奇數/2產3生的小數點，故將mantissa左移1，指數項減一
    // 判斷指數項是否為奇數(1結尾)，若是，mantissa左移1，指數項減1
    if (e & 1) {
        m <<= 1;
        e--;
    }


    /* Step 8: Integer square root using binary search */
    // 90 <= mid <= 256，且需找到最大整數mid，滿足 floor[(mid^2)/128] <= 128
    uint32_t lo = 90;
    uint32_t hi = 256;

    // 目前找到、符合條件的最大候選值
    uint32_t best = 90;

    // 利用 binary search 搜尋 mid
    while (lo <= hi) {

        uint32_t mid = (lo + hi) >> 1;

        uint32_t square = mid * mid;

        if ((square >> 7) <= m) {
            best = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }


    /* Step 9: Calculate the result exponent */

    int32_t result_exp = (e >> 1) + 127;


    /* Step 10: Normalize result significand */
    // BF16 Normal 數值的整數significant應該落在128 <= best <= 256
    // 若尾數太大，右移一位，同時讓 Exponent 增加1
    while (best >= 256u) {
        best >>= 1;
        result_exp++;
    }

    // 若尾數太小，左移一位，同時讓 Exponent 減少1
    while (best < 128u) {
        best <<= 1;
        result_exp--;
    }


    /* Step 11: Handle exponent overflow(>=255) / underflow */

    // 若結果的exponent超過255，BF16 Normal的範圍，return 0x7F80(無限大)
    if (result_exp >= 255)
        return 0x7F80u;

    // 若結果的exponent <= 0，return 0
    if (result_exp <= 0)
        return 0x0000u;


    /* Step 12: Assemble BF16 result */

    uint32_t result_frac = best & 0x7Fu;

    return (uint16_t)(((uint32_t)result_exp << 7) |
                      result_frac);
}
